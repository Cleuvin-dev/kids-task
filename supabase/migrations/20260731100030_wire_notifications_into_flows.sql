-- Marco 6 — Notificações (parte 3/4)
-- Liga emit_notification aos fluxos mais centrais do dia a dia: tarefas
-- (Marco 2/4), resgates (Marco 3) e progressão (Marco 4). Redefine por
-- completo as funções já commitadas (mesmo princípio das migrations
-- anteriores: nunca editar o arquivo antigo, sempre um novo
-- `create or replace function`).
--
-- Escopo deste marco: cobre a matriz de eventos de docs/11 seção 2-3 nos
-- pontos de maior tráfego (tarefa enviada/aprovada/rejeitada, resgate
-- solicitado/aprovado/rejeitado, subida de nível, aniversário). Não cobre
-- ainda: tarefa próxima/atrasada (dependem de um job de varredura que
-- ainda não existe), convite aceito/novo aparelho/exclusão/assinatura
-- (funções do Marco 1 e de marcos futuros, fora do escopo desta passada).
-- Ver docs/IMPLEMENTATION_STATUS.md para o registro completo.

create or replace function public.complete_task_occurrence(
  p_occurrence_id uuid,
  p_idempotency_key text,
  p_expected_version integer,
  p_completed_by_guardian boolean default false
)
returns table (
  occurrence_id uuid,
  status text,
  coin_balance integer,
  total_xp integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_occ record;
  v_is_child boolean;
  v_is_guardian boolean;
  v_new_status text;
  v_wallet record;
  v_guardian record;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_idempotency_key is null or length(trim(p_idempotency_key)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'idempotency_key is required';
  end if;

  select * into v_occ from public.task_occurrences where id = p_occurrence_id for update;

  if not found then
    raise exception 'VALIDATION_ERROR' using detail = 'occurrence not found';
  end if;

  -- Idempotência: se essa chave já foi processada, retorna o resultado
  -- atual sem reprocessar (docs/04 seção 8).
  if exists (
    select 1 from public.task_events
    where occurrence_id = p_occurrence_id and idempotency_key = p_idempotency_key
  ) then
    select w.coin_balance, w.total_xp into v_wallet
    from public.child_wallets w where w.child_id = v_occ.child_id;
    return query select v_occ.id, v_occ.status, v_wallet.coin_balance, v_wallet.total_xp;
    return;
  end if;

  v_is_child := exists (
    select 1 from public.child_device_bindings cdb
    where cdb.child_id = v_occ.child_id
      and cdb.auth_user_id = v_profile_id
      and cdb.revoked_at is null
  );

  v_is_guardian := exists (
    select 1 from public.family_members fm
    where fm.family_id = v_occ.family_id
      and fm.profile_id = v_profile_id
      and fm.status = 'active'
  );

  if p_completed_by_guardian then
    if not v_is_guardian then
      raise exception 'FORBIDDEN';
    end if;
  else
    if not v_is_child then
      raise exception 'FORBIDDEN';
    end if;
  end if;

  if v_occ.version <> p_expected_version then
    raise exception 'VERSION_CONFLICT';
  end if;

  -- Já expirada (pelo job expire_due_task_occurrences ou por uma chamada
  -- anterior): erro específico, mais preciso que o genérico não-completável.
  if v_occ.status = 'expired' then
    raise exception 'TASK_EXPIRED';
  end if;

  if v_occ.status not in ('pending', 'late', 'needs_correction') then
    raise exception 'TASK_NOT_COMPLETABLE';
  end if;

  -- Ainda pending/late mas o prazo já passou e o job de expiração não
  -- rodou ainda: expira agora mesmo, na própria chamada de conclusão.
  if v_occ.due_at is not null and v_occ.due_at < timezone('utc', now())
     and v_occ.late_policy_snapshot = 'expire_no_reward' then
    update public.task_occurrences
    set status = 'expired', expired_at = timezone('utc', now()), version = version + 1
    where id = p_occurrence_id;
    raise exception 'TASK_EXPIRED';
  end if;

  if v_occ.approval_mode_snapshot = 'manual' then
    v_new_status := 'awaiting_approval';
    update public.task_occurrences
    set status = v_new_status, submitted_at = timezone('utc', now()), version = version + 1
    where id = p_occurrence_id;

    insert into public.task_events (occurrence_id, event_type, actor, actor_role, idempotency_key)
    values (
      p_occurrence_id, 'submitted', v_profile_id,
      case when p_completed_by_guardian then 'guardian' else 'child' end,
      p_idempotency_key
    );

    for v_guardian in
      select fm.profile_id from public.family_members fm
      where fm.family_id = v_occ.family_id and fm.status = 'active'
    loop
      perform public.emit_notification(
        v_occ.family_id, 'task.occurrence_submitted', 'task_occurrence', p_occurrence_id,
        'guardian', v_guardian.profile_id, null,
        'Tarefa aguardando aprovação', v_occ.title_snapshot,
        jsonb_build_object('occurrence_id', p_occurrence_id), '/guardian/approvals',
        'task_submitted:' || p_idempotency_key || ':' || v_guardian.profile_id::text
      );
    end loop;
  else
    v_new_status := 'approved';
    update public.task_occurrences
    set status = v_new_status,
        submitted_at = timezone('utc', now()),
        approved_at = timezone('utc', now()),
        approved_by = case when p_completed_by_guardian then v_profile_id else null end,
        version = version + 1
    where id = p_occurrence_id;

    insert into public.task_events (occurrence_id, event_type, actor, actor_role, idempotency_key)
    values (
      p_occurrence_id, 'auto_approved', v_profile_id,
      case when p_completed_by_guardian then 'guardian' else 'child' end,
      p_idempotency_key
    );

    perform public.grant_task_rewards(p_occurrence_id);
    perform public.process_level_changes(v_occ.child_id);
    perform public.recalculate_daily_progress(v_occ.child_id, v_occ.occurrence_date);
    perform public.advance_streak(v_occ.child_id, v_occ.occurrence_date);

    perform public.emit_notification(
      v_occ.family_id, 'task.occurrence_approved', 'task_occurrence', p_occurrence_id,
      'child', null, v_occ.child_id,
      'Tarefa aprovada!', v_occ.title_snapshot,
      jsonb_build_object('occurrence_id', p_occurrence_id, 'coin_reward', v_occ.coin_reward_snapshot),
      '/child/home', 'task_approved:' || p_occurrence_id::text
    );
  end if;

  select w.coin_balance, w.total_xp into v_wallet
  from public.child_wallets w where w.child_id = v_occ.child_id;

  return query select p_occurrence_id, v_new_status, v_wallet.coin_balance, v_wallet.total_xp;
end;
$$;

create or replace function public.review_task_occurrence(
  p_occurrence_id uuid,
  p_decision text,
  p_idempotency_key text,
  p_expected_version integer,
  p_rejection_reason text default null
)
returns table (
  occurrence_id uuid,
  status text,
  coin_balance integer,
  total_xp integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_occ record;
  v_new_status text;
  v_wallet record;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_idempotency_key is null or length(trim(p_idempotency_key)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'idempotency_key is required';
  end if;

  if p_decision not in ('approve', 'reject') then
    raise exception 'VALIDATION_ERROR' using detail = 'decision must be approve or reject';
  end if;

  select * into v_occ from public.task_occurrences where id = p_occurrence_id for update;

  if not found then
    raise exception 'VALIDATION_ERROR' using detail = 'occurrence not found';
  end if;

  if not exists (
    select 1 from public.family_members fm
    where fm.family_id = v_occ.family_id and fm.profile_id = v_profile_id and fm.status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  if exists (
    select 1 from public.task_events
    where occurrence_id = p_occurrence_id and idempotency_key = p_idempotency_key
  ) then
    select w.coin_balance, w.total_xp into v_wallet
    from public.child_wallets w where w.child_id = v_occ.child_id;
    return query select v_occ.id, v_occ.status, v_wallet.coin_balance, v_wallet.total_xp;
    return;
  end if;

  -- Segunda aprovação/rejeição simultânea (dois responsáveis): a primeira
  -- já tirou a ocorrência de awaiting_approval, então a segunda encontra
  -- estado incompatível e é tratada como já processada, nunca credita de
  -- novo (docs/04 seção 8, docs/15 critérios de aceite).
  if v_occ.status <> 'awaiting_approval' then
    raise exception 'ALREADY_PROCESSED';
  end if;

  if v_occ.version <> p_expected_version then
    raise exception 'VERSION_CONFLICT';
  end if;

  if p_decision = 'reject' then
    if p_rejection_reason is null or length(trim(p_rejection_reason)) = 0 then
      raise exception 'VALIDATION_ERROR' using detail = 'rejection_reason is required';
    end if;

    v_new_status := 'needs_correction';
    update public.task_occurrences
    set status = v_new_status, rejection_reason = p_rejection_reason, version = version + 1
    where id = p_occurrence_id;

    insert into public.task_events (occurrence_id, event_type, actor, actor_role, payload, idempotency_key)
    values (
      p_occurrence_id, 'rejected', v_profile_id, 'guardian',
      jsonb_build_object('reason', p_rejection_reason), p_idempotency_key
    );

    perform public.emit_notification(
      v_occ.family_id, 'task.occurrence_rejected', 'task_occurrence', p_occurrence_id,
      'child', null, v_occ.child_id,
      'Sua tarefa precisa de um ajuste', v_occ.title_snapshot,
      jsonb_build_object('occurrence_id', p_occurrence_id, 'reason', p_rejection_reason),
      '/child/home', 'task_rejected:' || p_idempotency_key
    );
  else
    v_new_status := 'approved';
    update public.task_occurrences
    set status = v_new_status, approved_at = timezone('utc', now()), approved_by = v_profile_id, version = version + 1
    where id = p_occurrence_id;

    insert into public.task_events (occurrence_id, event_type, actor, actor_role, idempotency_key)
    values (p_occurrence_id, 'approved', v_profile_id, 'guardian', p_idempotency_key);

    perform public.grant_task_rewards(p_occurrence_id);
    perform public.process_level_changes(v_occ.child_id);
    perform public.recalculate_daily_progress(v_occ.child_id, v_occ.occurrence_date);
    perform public.advance_streak(v_occ.child_id, v_occ.occurrence_date);

    perform public.emit_notification(
      v_occ.family_id, 'task.occurrence_approved', 'task_occurrence', p_occurrence_id,
      'child', null, v_occ.child_id,
      'Tarefa aprovada!', v_occ.title_snapshot,
      jsonb_build_object('occurrence_id', p_occurrence_id, 'coin_reward', v_occ.coin_reward_snapshot),
      '/child/home', 'task_approved:' || p_occurrence_id::text
    );
  end if;

  select w.coin_balance, w.total_xp into v_wallet
  from public.child_wallets w where w.child_id = v_occ.child_id;

  return query select p_occurrence_id, v_new_status, v_wallet.coin_balance, v_wallet.total_xp;
end;
$$;

create or replace function public.request_redemption(
  p_reward_id uuid,
  p_idempotency_key text
)
returns table (redemption_id uuid, status text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_child_id uuid;
  v_reward record;
  v_balance int;
  v_existing record;
  v_redemption_id uuid;
  v_guardian record;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_idempotency_key is null or length(trim(p_idempotency_key)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'idempotency_key is required';
  end if;

  select r.id, r.status into v_existing
  from public.redemption_requests r
  where r.idempotency_key = p_idempotency_key;

  if found then
    return query select v_existing.id, v_existing.status;
    return;
  end if;

  select cdb.child_id into v_child_id
  from public.child_device_bindings cdb
  where cdb.auth_user_id = v_profile_id and cdb.revoked_at is null;

  if v_child_id is null then
    raise exception 'FORBIDDEN';
  end if;

  select r.id, r.family_id, r.child_id, r.title, r.cost_coins, r.active
  into v_reward
  from public.rewards r
  where r.id = p_reward_id;

  if not found or not v_reward.active then
    raise exception 'VALIDATION_ERROR' using detail = 'reward not available';
  end if;

  if v_reward.child_id is not null and v_reward.child_id <> v_child_id then
    raise exception 'FORBIDDEN';
  end if;

  if not exists (
    select 1 from public.child_profiles cp
    where cp.id = v_child_id and cp.family_id = v_reward.family_id
  ) then
    raise exception 'FORBIDDEN';
  end if;

  -- Valida saldo já na solicitação (a aprovação valida de novo, porque o
  -- saldo pode mudar entre os dois momentos — docs/05 seção 5).
  select w.coin_balance into v_balance
  from public.child_wallets w where w.child_id = v_child_id;

  if coalesce(v_balance, 0) < v_reward.cost_coins then
    raise exception 'INSUFFICIENT_COINS';
  end if;

  insert into public.redemption_requests (
    family_id, child_id, reward_id, title_snapshot, cost_snapshot, idempotency_key
  ) values (
    v_reward.family_id, v_child_id, v_reward.id, v_reward.title, v_reward.cost_coins,
    p_idempotency_key
  )
  returning id into v_redemption_id;

  for v_guardian in
    select fm.profile_id from public.family_members fm
    where fm.family_id = v_reward.family_id and fm.status = 'active'
  loop
    perform public.emit_notification(
      v_reward.family_id, 'redemption.requested', 'redemption_request', v_redemption_id,
      'guardian', v_guardian.profile_id, null,
      'Pedido de recompensa', v_reward.title,
      jsonb_build_object('redemption_id', v_redemption_id), '/guardian/redemptions',
      'redemption_requested:' || v_redemption_id::text || ':' || v_guardian.profile_id::text
    );
  end loop;

  return query select v_redemption_id, 'requested'::text;
end;
$$;

create or replace function public.review_redemption(
  p_redemption_id uuid,
  p_decision text,
  p_idempotency_key text,
  p_expected_version integer,
  p_rejection_reason text default null
)
returns table (redemption_id uuid, status text, coin_balance integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_redemption record;
  v_new_status text;
  v_balance int;
  v_new_balance int;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_idempotency_key is null or length(trim(p_idempotency_key)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'idempotency_key is required';
  end if;

  if p_decision not in ('approve', 'reject') then
    raise exception 'VALIDATION_ERROR' using detail = 'decision must be approve or reject';
  end if;

  select * into v_redemption
  from public.redemption_requests
  where id = p_redemption_id
  for update;

  if not found then
    raise exception 'VALIDATION_ERROR' using detail = 'redemption not found';
  end if;

  if not exists (
    select 1 from public.family_members fm
    where fm.family_id = v_redemption.family_id and fm.profile_id = v_profile_id and fm.status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  if exists (
    select 1 from public.redemption_events
    where redemption_id = p_redemption_id and idempotency_key = p_idempotency_key
  ) then
    select w.coin_balance into v_balance
    from public.child_wallets w where w.child_id = v_redemption.child_id;
    return query select v_redemption.id, v_redemption.status, v_balance;
    return;
  end if;

  if v_redemption.status <> 'requested' then
    raise exception 'REDEMPTION_NOT_PENDING';
  end if;

  if v_redemption.version <> p_expected_version then
    raise exception 'VERSION_CONFLICT';
  end if;

  if p_decision = 'reject' then
    v_new_status := 'rejected';
    update public.redemption_requests
    set status = v_new_status, reviewed_at = timezone('utc', now()), reviewed_by = v_profile_id,
        rejection_reason = p_rejection_reason, version = version + 1
    where id = p_redemption_id;

    insert into public.redemption_events (redemption_id, event_type, actor, actor_role, payload, idempotency_key)
    values (p_redemption_id, 'rejected', v_profile_id, 'guardian',
            jsonb_build_object('reason', p_rejection_reason), p_idempotency_key);

    perform public.emit_notification(
      v_redemption.family_id, 'redemption.rejected', 'redemption_request', p_redemption_id,
      'child', null, v_redemption.child_id,
      'Pedido não aprovado desta vez', v_redemption.title_snapshot,
      jsonb_build_object('redemption_id', p_redemption_id, 'reason', p_rejection_reason),
      '/child/rewards', 'redemption_rejected:' || p_redemption_id::text
    );

    select w.coin_balance into v_balance
    from public.child_wallets w where w.child_id = v_redemption.child_id;
    return query select p_redemption_id, v_new_status, v_balance;
    return;
  end if;

  -- Aprovação: revalida saldo (pode ter mudado desde a solicitação),
  -- debita atomicamente e credita o ledger exatamente uma vez
  -- (docs/05 seção 5, docs/15 seção 7).
  select coin_balance into v_balance
  from public.child_wallets
  where child_id = v_redemption.child_id
  for update;

  if coalesce(v_balance, 0) < v_redemption.cost_snapshot then
    raise exception 'INSUFFICIENT_COINS';
  end if;

  v_new_balance := v_balance - v_redemption.cost_snapshot;
  v_new_status := 'approved';

  update public.redemption_requests
  set status = v_new_status, reviewed_at = timezone('utc', now()), reviewed_by = v_profile_id,
      version = version + 1
  where id = p_redemption_id;

  insert into public.coin_ledger (
    family_id, child_id, entry_type, amount_signed, balance_after,
    source_type, source_id, reason, created_by, idempotency_key
  ) values (
    v_redemption.family_id, v_redemption.child_id, 'redemption', -v_redemption.cost_snapshot,
    v_new_balance, 'redemption_request', p_redemption_id, v_redemption.title_snapshot,
    v_profile_id, p_idempotency_key || ':ledger'
  )
  on conflict (source_id, entry_type) do nothing;

  if found then
    update public.child_wallets
    set coin_balance = v_new_balance, version = version + 1
    where child_id = v_redemption.child_id;
  end if;

  insert into public.redemption_events (redemption_id, event_type, actor, actor_role, idempotency_key)
  values (p_redemption_id, 'approved', v_profile_id, 'guardian', p_idempotency_key);

  perform public.emit_notification(
    v_redemption.family_id, 'redemption.approved', 'redemption_request', p_redemption_id,
    'child', null, v_redemption.child_id,
    'Recompensa aprovada!', v_redemption.title_snapshot,
    jsonb_build_object('redemption_id', p_redemption_id), '/child/rewards',
    'redemption_approved:' || p_redemption_id::text
  );

  select w.coin_balance into v_balance
  from public.child_wallets w where w.child_id = v_redemption.child_id;
  return query select p_redemption_id, v_new_status, v_balance;
end;
$$;

create or replace function public.process_level_changes(p_child_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total_xp int;
  v_current_level int;
  v_bonus_coins int;
  v_family_id uuid;
  v_new_level int;
  v_level int;
  v_balance int;
  v_idempotency_key text;
begin
  select w.total_xp, w.current_level, w.coin_balance
  into v_total_xp, v_current_level, v_balance
  from public.child_wallets w
  where w.child_id = p_child_id
  for update;

  if v_total_xp is null then
    return;
  end if;

  select cp.level_bonus_coins, cp.family_id into v_bonus_coins, v_family_id
  from public.child_profiles cp where cp.id = p_child_id;

  select max(level) into v_new_level
  from public.level_definitions
  where active and min_total_xp <= v_total_xp;

  if v_new_level is null or v_new_level <= v_current_level then
    return;
  end if;

  for v_level in (v_current_level + 1)..v_new_level loop
    v_idempotency_key := 'level_up:' || p_child_id::text || ':' || v_level::text;

    if coalesce(v_bonus_coins, 0) > 0 then
      insert into public.coin_ledger (
        family_id, child_id, entry_type, amount_signed, balance_after,
        source_type, source_id, reason, idempotency_key
      ) values (
        v_family_id, p_child_id, 'level_bonus', v_bonus_coins, v_balance + v_bonus_coins,
        'level_up', extensions.gen_random_uuid(), 'Bônus por alcançar o nível ' || v_level,
        v_idempotency_key
      )
      on conflict (idempotency_key) do nothing;

      if found then
        v_balance := v_balance + v_bonus_coins;
      end if;
    end if;

    perform public.emit_notification(
      v_family_id, 'progress.level_up', 'child_wallet', p_child_id,
      'child', null, p_child_id,
      'Você subiu de nível!', 'Agora você está no nível ' || v_level,
      jsonb_build_object('level', v_level), '/child/home',
      v_idempotency_key
    );
  end loop;

  update public.child_wallets
  set current_level = v_new_level, coin_balance = v_balance, version = version + 1
  where child_id = p_child_id;
end;
$$;

create or replace function public.grant_birthday_bonus()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_child record;
  v_today date;
  v_year int;
  v_is_leap boolean;
  v_effective_day int;
  v_effective_birthday date;
  v_idempotency_key text;
  v_balance int;
begin
  for v_child in
    select cp.id as child_id, cp.family_id, cp.birth_date, cp.birthday_bonus_coins,
           coalesce(f.timezone, 'America/Sao_Paulo') as timezone
    from public.child_profiles cp
    join public.families f on f.id = cp.family_id
    where cp.status = 'active'
  loop
    v_today := (timezone('utc', now()) at time zone v_child.timezone)::date;
    v_year := extract(year from v_today)::int;
    v_is_leap := (v_year % 4 = 0 and (v_year % 100 <> 0 or v_year % 400 = 0));

    v_effective_day := extract(day from v_child.birth_date)::int;
    if extract(month from v_child.birth_date) = 2 and v_effective_day = 29 and not v_is_leap then
      v_effective_day := 28;
    end if;

    v_effective_birthday := make_date(v_year, extract(month from v_child.birth_date)::int, v_effective_day);

    if v_effective_birthday <> v_today then
      continue;
    end if;

    if coalesce(v_child.birthday_bonus_coins, 0) <= 0 then
      continue;
    end if;

    v_idempotency_key := 'birthday:' || v_child.child_id::text || ':' || v_year::text;

    select coin_balance into v_balance
    from public.child_wallets where child_id = v_child.child_id for update;

    insert into public.coin_ledger (
      family_id, child_id, entry_type, amount_signed, balance_after,
      source_type, source_id, reason, idempotency_key
    ) values (
      v_child.family_id, v_child.child_id, 'birthday_bonus', v_child.birthday_bonus_coins,
      coalesce(v_balance, 0) + v_child.birthday_bonus_coins, 'birthday',
      extensions.gen_random_uuid(), 'Bônus de aniversário', v_idempotency_key
    )
    on conflict (idempotency_key) do nothing;

    if found then
      update public.child_wallets
      set coin_balance = coalesce(v_balance, 0) + v_child.birthday_bonus_coins, version = version + 1
      where child_id = v_child.child_id;

      perform public.emit_notification(
        v_child.family_id, 'progress.birthday_bonus', 'child_wallet', v_child.child_id,
        'child', null, v_child.child_id,
        'Feliz aniversário!', 'Você ganhou um bônus especial de aniversário',
        jsonb_build_object('coins', v_child.birthday_bonus_coins), '/child/home',
        v_idempotency_key
      );
    end if;
  end loop;
end;
$$;
