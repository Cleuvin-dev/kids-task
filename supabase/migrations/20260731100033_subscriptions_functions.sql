-- Marco 7 — Assinaturas e Entitlements (parte 2/4)
-- Funções: verificação de compra, webhooks de loja, restauração, transição
-- de entitlement e downgrade seguro (docs/13, docs/14 seção 7, docs/02
-- seção 5).

-- ---------------------------------------------------------------------
-- resolve_effective_plan_code: único ponto que decide se um status de
-- assinatura conta como Premium (docs/13 seção 4).
-- ---------------------------------------------------------------------
create or replace function public.resolve_effective_plan_code(p_status text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_status in (
      'trialing', 'active', 'grace_period', 'billing_retry',
      'cancelled_active_until_end', 'support_override'
    ) then 'premium'
    else 'free'
  end;
$$;

-- ---------------------------------------------------------------------
-- verify_purchase: valida o recibo e aplica o estado. BLOQUEIO CONHECIDO
-- (docs/18 seção 5): nenhuma conta de desenvolvedor Apple/Google existe
-- ainda, então não há chamada de rede real à loja para validar
-- p_receipt_data criptograficamente. Esta função implementa a máquina de
-- estados real (idempotência, mapeamento de produto, vínculo à família) e
-- isola a lacuna externa no bloco comentado abaixo — mesmo padrão já usado
-- em send-guardian-invite (Marco 1) quando o provedor de e-mail não
-- existia: constrói a lógica real, documenta o que falta plugar depois.
-- Quando existir integração real (App Store Server API / Google Play
-- Developer API), trocar só o bloco entre os comentários BEGIN/END STORE
-- CALL por uma chamada HTTP verdadeira (numa Edge Function, não aqui).
-- Só service_role: chamada internamente por submit_purchase_receipt.
-- ---------------------------------------------------------------------
create or replace function public.verify_purchase(
  p_family_id uuid,
  p_store text,
  p_product_id text,
  p_receipt_data text,
  p_original_transaction_id text,
  p_purchased_by uuid
)
returns table (subscription_status text, verified boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_product record;
  v_period interval;
  v_now timestamptz := timezone('utc', now());
begin
  if p_receipt_data is null or length(trim(p_receipt_data)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'receipt_data is required';
  end if;

  select sp.plan_code, sp.billing_period into v_product
  from public.subscription_products sp
  where sp.store = p_store and sp.product_id = p_product_id and sp.active;

  if not found then
    -- Comprovante inválido (produto desconhecido): não liberar
    -- (docs/13 seção 9).
    return query select 'free'::text, false;
    return;
  end if;

  -- BEGIN STORE CALL (stub — ver comentário da função)
  v_period := case
    when v_product.billing_period = 'yearly' then interval '1 year'
    else interval '1 month'
  end;
  -- END STORE CALL (stub)

  insert into public.subscriptions (
    family_id, store, product_id, original_transaction_id, status,
    current_period_end, auto_renew, purchased_by, last_verified_at,
    pending_verification
  ) values (
    p_family_id, p_store, p_product_id, p_original_transaction_id, 'active',
    v_now + v_period, true, p_purchased_by, v_now, false
  )
  on conflict (family_id) do update set
    store = excluded.store,
    product_id = excluded.product_id,
    original_transaction_id = excluded.original_transaction_id,
    status = 'active',
    current_period_end = excluded.current_period_end,
    auto_renew = true,
    purchased_by = excluded.purchased_by,
    last_verified_at = v_now,
    pending_verification = false;

  perform public.apply_subscription_transition(p_family_id);

  insert into public.subscription_events (
    family_id, store, event_type, store_event_id, store_event_at, payload
  ) values (
    p_family_id, p_store, 'verification',
    coalesce(p_original_transaction_id, p_family_id::text) || ':' || extract(epoch from v_now)::text,
    v_now, jsonb_build_object('product_id', p_product_id)
  );

  return query select 'active'::text, true;
end;
$$;

-- ---------------------------------------------------------------------
-- submit_purchase_receipt: entrada client-facing, logo após a loja
-- retornar o resultado da compra para o app (docs/13 seção 3). O callback
-- local não é suficiente para liberar Premium de forma permanente — quem
-- decide é verify_purchase.
-- ---------------------------------------------------------------------
create or replace function public.submit_purchase_receipt(
  p_family_id uuid,
  p_store text,
  p_product_id text,
  p_receipt_data text,
  p_original_transaction_id text default null
)
returns table (subscription_status text, verified boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  -- Só responsável, nunca criança (docs/13 seção 10) — a criança não tem
  -- vínculo em family_members.
  if not exists (
    select 1 from public.family_members fm
    where fm.family_id = p_family_id and fm.profile_id = v_profile_id and fm.status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  if p_store not in ('apple', 'google') then
    raise exception 'VALIDATION_ERROR' using detail = 'invalid store';
  end if;

  return query select * from public.verify_purchase(
    p_family_id, p_store, p_product_id, p_receipt_data, p_original_transaction_id, v_profile_id
  );
end;
$$;

-- ---------------------------------------------------------------------
-- handle_store_notification: núcleo de processamento de webhook,
-- parametrizado por loja. Pressupõe que uma Edge Function futura já
-- validou a assinatura/autenticidade do webhook (JWS da Apple / Pub/Sub da
-- Google, docs/14 seção 7: "Webhooks validam assinatura/autenticidade
-- conforme documentação oficial da loja") antes de chamar esta função —
-- nenhuma Edge Function é criada nesta leva. Só service_role.
-- ---------------------------------------------------------------------
create or replace function public.handle_store_notification(
  p_store text,
  p_store_event_id text,
  p_event_type text,
  p_original_transaction_id text,
  p_new_status text,
  p_current_period_end timestamptz,
  p_grace_period_end timestamptz,
  p_store_event_at timestamptz,
  p_payload jsonb
)
returns table (family_id uuid, applied boolean)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_family_id uuid;
  v_current record;
begin
  if p_store not in ('apple', 'google') then
    raise exception 'VALIDATION_ERROR' using detail = 'invalid store';
  end if;

  select s.family_id, s.status, s.last_verified_at into v_current
  from public.subscriptions s
  where s.original_transaction_id = p_original_transaction_id and s.store = p_store;

  if not found then
    -- Loja notificou uma transação que este backend nunca viu (ex.: compra
    -- direta na loja sem passar por submit_purchase_receipt ainda, ou
    -- reinstalação). Persiste o evento órfão para auditoria/revisão
    -- (docs/13 seção 6: "cada evento... é persistido antes do processamento"),
    -- sem família para aplicar.
    insert into public.subscription_events (
      family_id, store, event_type, store_event_id, store_event_at, payload, processing_status
    ) values (
      null, p_store, p_event_type, p_store_event_id, p_store_event_at, p_payload, 'pending_review'
    )
    on conflict (store, store_event_id) do nothing;

    return query select null::uuid, false;
    return;
  end if;

  v_family_id := v_current.family_id;

  -- Idempotência: evento já processado é no-op (docs/13 seção 6/9).
  insert into public.subscription_events (
    family_id, store, event_type, store_event_id, store_event_at, payload
  ) values (
    v_family_id, p_store, p_event_type, p_store_event_id, p_store_event_at, p_payload
  )
  on conflict (store, store_event_id) do nothing;

  if not found then
    return query select v_family_id, false;
    return;
  end if;

  -- Webhook fora de ordem: comparar timestamp da loja contra a última
  -- verificação já aplicada (docs/13 seção 9). last_verified_at só avança
  -- quando um evento é de fato aplicado, então serve de marca d'água.
  if p_store_event_at is not null and v_current.last_verified_at is not null
     and p_store_event_at < v_current.last_verified_at then
    update public.subscription_events
    set processing_status = 'ignored_out_of_order'
    where store = p_store and store_event_id = p_store_event_id;

    return query select v_family_id, false;
    return;
  end if;

  update public.subscriptions
  set status = p_new_status,
      current_period_end = coalesce(p_current_period_end, current_period_end),
      grace_period_end = p_grace_period_end,
      auto_renew = (p_event_type not in ('cancellation', 'expiration', 'revocation')),
      last_verified_at = coalesce(p_store_event_at, timezone('utc', now()))
  where public.subscriptions.family_id = v_family_id;

  perform public.apply_subscription_transition(v_family_id);

  return query select v_family_id, true;
end;
$$;

create or replace function public.handle_apple_notification(
  p_store_event_id text,
  p_event_type text,
  p_original_transaction_id text,
  p_new_status text,
  p_current_period_end timestamptz,
  p_grace_period_end timestamptz,
  p_store_event_at timestamptz,
  p_payload jsonb
)
returns table (family_id uuid, applied boolean)
language sql
security definer
set search_path = ''
as $$
  select * from public.handle_store_notification(
    'apple', p_store_event_id, p_event_type, p_original_transaction_id,
    p_new_status, p_current_period_end, p_grace_period_end, p_store_event_at, p_payload
  );
$$;

create or replace function public.handle_google_notification(
  p_store_event_id text,
  p_event_type text,
  p_original_transaction_id text,
  p_new_status text,
  p_current_period_end timestamptz,
  p_grace_period_end timestamptz,
  p_store_event_at timestamptz,
  p_payload jsonb
)
returns table (family_id uuid, applied boolean)
language sql
security definer
set search_path = ''
as $$
  select * from public.handle_store_notification(
    'google', p_store_event_id, p_event_type, p_original_transaction_id,
    p_new_status, p_current_period_end, p_grace_period_end, p_store_event_at, p_payload
  );
$$;

-- ---------------------------------------------------------------------
-- restore_entitlements: disponível na área do responsável (docs/13 seção
-- 7). Sem chamada real à loja ainda, restaurar revalida o snapshot já
-- existente contra a própria tabela — "não duplica assinatura" é garantido
-- estruturalmente pelo unique(family_id).
-- ---------------------------------------------------------------------
create or replace function public.restore_entitlements(p_family_id uuid)
returns table (subscription_status text, restored boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_sub record;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if not exists (
    select 1 from public.family_members fm
    where fm.family_id = p_family_id and fm.profile_id = v_profile_id and fm.status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  select * into v_sub from public.subscriptions where family_id = p_family_id;

  if v_sub.original_transaction_id is null then
    return query select 'free'::text, false;
    return;
  end if;

  update public.subscriptions
  set last_verified_at = timezone('utc', now()), pending_verification = false
  where family_id = p_family_id;

  perform public.apply_subscription_transition(p_family_id);

  insert into public.subscription_events (
    family_id, store, event_type, store_event_id, payload
  ) values (
    p_family_id, v_sub.store, 'restore',
    'restore:' || p_family_id::text || ':' || extract(epoch from timezone('utc', now()))::text,
    '{}'::jsonb
  );

  select status into v_sub from public.subscriptions where family_id = p_family_id;

  return query select v_sub.status, true;
end;
$$;

-- ---------------------------------------------------------------------
-- apply_subscription_transition: recalcula families.plan_id a partir do
-- status da assinatura e dispara downgrade/reativação quando o plano
-- efetivo muda de nível. Interna — chamada por verify_purchase,
-- handle_store_notification e restore_entitlements.
-- ---------------------------------------------------------------------
create or replace function public.apply_subscription_transition(p_family_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_old_plan_code text;
  v_new_plan_code text;
  v_new_plan_id uuid;
begin
  select s.status into v_status
  from public.subscriptions s
  where s.family_id = p_family_id
  for update;

  select p.code into v_old_plan_code
  from public.families f
  join public.plans p on p.id = f.plan_id
  where f.id = p_family_id;

  v_new_plan_code := public.resolve_effective_plan_code(coalesce(v_status, 'free'));

  select id into v_new_plan_id from public.plans where code = v_new_plan_code and active;

  update public.families set plan_id = v_new_plan_id where id = p_family_id;

  if v_old_plan_code = 'premium' and v_new_plan_code = 'free' then
    perform public.apply_safe_downgrade(p_family_id);
  elsif v_old_plan_code = 'free' and v_new_plan_code = 'premium' then
    perform public.restore_paused_entitlements(p_family_id);
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- apply_safe_downgrade: núcleo das regras de docs/02 seção 5. Nunca apaga
-- dados — só pausa o que excede o novo limite. Interna.
-- ---------------------------------------------------------------------
create or replace function public.apply_safe_downgrade(p_family_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_max_children int;
  v_max_daily int;
  v_primary_child uuid;
  v_child record;
  v_date record;
  v_kept int;
  v_occ record;
begin
  select p.max_active_children, p.max_daily_occurrences into v_max_children, v_max_daily
  from public.families f
  join public.plans p on p.id = f.plan_id
  where f.id = p_family_id;

  select primary_child_id into v_primary_child from public.families where id = p_family_id;

  -- docs/02 seção 5, item 3: se não escolhida, mantém a primeira criança
  -- criada. "Solicita confirmação" é responsabilidade da UI/notificação
  -- futura — o backend não bloqueia nisso, só registra a escolha.
  if v_primary_child is null then
    select id into v_primary_child
    from public.child_profiles
    where family_id = p_family_id and status = 'active'
    order by created_at asc
    limit 1;

    update public.families set primary_child_id = v_primary_child where id = p_family_id;
  end if;

  -- 1) Pausa crianças ativas além do novo limite, sempre preservando a
  --    primary_child_id primeiro.
  for v_child in
    select id from public.child_profiles
    where family_id = p_family_id and status = 'active'
    order by (id = v_primary_child) desc, created_at asc
    offset v_max_children
  loop
    update public.child_profiles set status = 'plan_paused' where id = v_child.id;
  end loop;

  -- Reverte tema Premium para o padrão gratuito em qualquer criança da
  -- família (inclusive a que permanece ativa — ela também perde Premium).
  -- Simplificação assumida: sem histórico de "último tema gratuito"
  -- persistido, sempre volta para kids_default (docs/02 seção 5, item 6,
  -- não especifica qual tema gratuito).
  update public.child_profiles
  set theme_slug = 'kids_default'
  where family_id = p_family_id
    and theme_slug in (select slug from public.themes where plan_tier = 'premium');

  -- 2) A partir de amanhã, no máximo v_max_daily ocorrências ficam ativas
  --    por dia, por criança ainda ativa (docs/02 seção 5, itens 4-5).
  --    Critério de desempate (quais ficam): mais antigas por created_at —
  --    não especificado no doc, assumido como padrão razoável.
  for v_child in
    select id from public.child_profiles where family_id = p_family_id and status = 'active'
  loop
    for v_date in
      select distinct occurrence_date from public.task_occurrences
      where child_id = v_child.id
        and occurrence_date >= current_date + 1
        and status = 'pending'
    loop
      v_kept := 0;

      for v_occ in
        select id from public.task_occurrences
        where child_id = v_child.id
          and occurrence_date = v_date.occurrence_date
          and status = 'pending'
        order by created_at asc
      loop
        v_kept := v_kept + 1;

        if v_kept > v_max_daily then
          update public.task_occurrences
          set status = 'plan_paused', version = version + 1
          where id = v_occ.id;
        end if;
      end loop;
    end loop;
  end loop;

  insert into public.subscription_events (family_id, store, event_type, store_event_id, payload)
  values (
    p_family_id, 'internal', 'safe_downgrade_applied',
    'downgrade:' || p_family_id::text || ':' || extract(epoch from timezone('utc', now()))::text,
    jsonb_build_object('primary_child_id', v_primary_child)
  );
end;
$$;

-- ---------------------------------------------------------------------
-- restore_paused_entitlements: espelho de apply_safe_downgrade em sentido
-- inverso, até o novo limite (maior) do plano premium. Interna.
-- ---------------------------------------------------------------------
create or replace function public.restore_paused_entitlements(p_family_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_max_children int;
  v_max_daily int;
  v_active_children int;
  v_child record;
  v_date record;
  v_active_count int;
  v_occ record;
begin
  select p.max_active_children, p.max_daily_occurrences into v_max_children, v_max_daily
  from public.families f
  join public.plans p on p.id = f.plan_id
  where f.id = p_family_id;

  select count(*) into v_active_children
  from public.child_profiles
  where family_id = p_family_id and status = 'active';

  -- 1) Reativa crianças pausadas por limite de plano até o novo teto,
  --    da mais antiga para a mais nova.
  for v_child in
    select id from public.child_profiles
    where family_id = p_family_id and status = 'plan_paused'
    order by created_at asc
    limit greatest(v_max_children - v_active_children, 0)
  loop
    update public.child_profiles set status = 'active' where id = v_child.id;
  end loop;

  -- 2) Reativa ocorrências pausadas por limite de plano (futuras), até o
  --    novo limite diário, por criança ativa e por data.
  for v_child in
    select id from public.child_profiles where family_id = p_family_id and status = 'active'
  loop
    for v_date in
      select distinct occurrence_date from public.task_occurrences
      where child_id = v_child.id
        and occurrence_date >= current_date + 1
        and status in ('pending', 'plan_paused')
    loop
      select count(*) into v_active_count
      from public.task_occurrences
      where child_id = v_child.id
        and occurrence_date = v_date.occurrence_date
        and status = 'pending';

      for v_occ in
        select id from public.task_occurrences
        where child_id = v_child.id
          and occurrence_date = v_date.occurrence_date
          and status = 'plan_paused'
        order by created_at asc
        limit greatest(v_max_daily - v_active_count, 0)
      loop
        update public.task_occurrences
        set status = 'pending', version = version + 1
        where id = v_occ.id;
      end loop;
    end loop;
  end loop;
end;
$$;
