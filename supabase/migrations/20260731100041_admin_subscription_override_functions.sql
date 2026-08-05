-- Marco 7 (fatia 3) — Override de suporte (docs/12 seção 5: "override de
-- suporte com expiração e justificativa"; "o painel não altera comprovante
-- da loja; override não deve fingir pagamento").
--
-- Por isso nenhuma das duas funções abaixo toca `store`/`product_id`/
-- `original_transaction_id`: só `status`/`current_period_end`, reutilizando
-- o campo que já existe para "quando a assinatura para de valer" em vez de
-- criar uma coluna nova só para o override. Ambas reaproveitam
-- `apply_subscription_transition` (fatia 1) para propagar o efeito no
-- plano da família (docs/02 seção 5) e `record_admin_audit_log` (fatia 2)
-- para a trilha de auditoria — nenhum mecanismo novo de nenhum dos dois.
--
-- Simplificação registrada: revogar (manual ou por expiração) sempre volta
-- para `free`, não para "o que a família tinha antes do override". Cobrir
-- o caso raro de uma assinatura real de loja coexistindo com um override
-- fica para quando o módulo de suporte precisar dele de verdade.

create or replace function public.admin_grant_subscription_override(
  p_family_id uuid,
  p_expires_at timestamptz,
  p_justification text,
  p_idempotency_key text
)
returns table (status text, current_period_end timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := (select auth.uid());
begin
  if not public.is_active_platform_admin(array['super_admin', 'billing']) then
    raise exception 'FORBIDDEN';
  end if;

  if p_idempotency_key is null or length(trim(p_idempotency_key)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'idempotency_key is required';
  end if;

  if p_justification is null or length(trim(p_justification)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'justification is required';
  end if;

  if p_expires_at is null or p_expires_at <= timezone('utc', now()) then
    raise exception 'VALIDATION_ERROR' using detail = 'expires_at must be in the future';
  end if;

  if exists (select 1 from public.subscription_events where idempotency_key = p_idempotency_key) then
    return query
      select s.status, s.current_period_end from public.subscriptions s
      where s.family_id = p_family_id;
    return;
  end if;

  if not exists (select 1 from public.subscriptions where family_id = p_family_id for update) then
    raise exception 'VALIDATION_ERROR' using detail = 'family not found';
  end if;

  update public.subscriptions
  set status = 'support_override',
      current_period_end = p_expires_at,
      auto_renew = false,
      pending_verification = false
  where family_id = p_family_id;

  insert into public.subscription_events (
    family_id, store, event_type, store_event_id, store_event_at, payload, idempotency_key
  ) values (
    p_family_id, 'internal', 'support_override_granted', extensions.gen_random_uuid()::text,
    timezone('utc', now()),
    jsonb_build_object('expires_at', p_expires_at, 'justification', p_justification, 'granted_by', v_admin_id),
    p_idempotency_key
  );

  perform public.apply_subscription_transition(p_family_id);

  perform public.record_admin_audit_log(
    'admin.subscription_override_granted',
    'subscription',
    p_family_id::text,
    'success',
    jsonb_build_object('expires_at', p_expires_at, 'justification', p_justification)
  );

  return query
    select s.status, s.current_period_end from public.subscriptions s
    where s.family_id = p_family_id;
end;
$$;

create or replace function public.admin_revoke_subscription_override(
  p_family_id uuid,
  p_reason text,
  p_idempotency_key text
)
returns table (status text, current_period_end timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := (select auth.uid());
  v_status text;
begin
  if not public.is_active_platform_admin(array['super_admin', 'billing']) then
    raise exception 'FORBIDDEN';
  end if;

  if p_idempotency_key is null or length(trim(p_idempotency_key)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'idempotency_key is required';
  end if;

  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'reason is required';
  end if;

  if exists (select 1 from public.subscription_events where idempotency_key = p_idempotency_key) then
    return query
      select s.status, s.current_period_end from public.subscriptions s
      where s.family_id = p_family_id;
    return;
  end if;

  select s.status into v_status from public.subscriptions s
  where s.family_id = p_family_id
  for update;

  if v_status is null then
    raise exception 'VALIDATION_ERROR' using detail = 'family not found';
  end if;

  if v_status <> 'support_override' then
    raise exception 'VALIDATION_ERROR' using detail = 'subscription is not under an active override';
  end if;

  update public.subscriptions
  set status = 'free', current_period_end = null, auto_renew = false
  where family_id = p_family_id;

  insert into public.subscription_events (
    family_id, store, event_type, store_event_id, store_event_at, payload, idempotency_key
  ) values (
    p_family_id, 'internal', 'support_override_revoked', extensions.gen_random_uuid()::text,
    timezone('utc', now()),
    jsonb_build_object('reason', p_reason, 'revoked_by', v_admin_id),
    p_idempotency_key
  );

  perform public.apply_subscription_transition(p_family_id);

  perform public.record_admin_audit_log(
    'admin.subscription_override_revoked',
    'subscription',
    p_family_id::text,
    'success',
    jsonb_build_object('reason', p_reason)
  );

  return query
    select s.status, s.current_period_end from public.subscriptions s
    where s.family_id = p_family_id;
end;
$$;

-- expire_support_overrides: agendada via pg_cron (próxima migration), como
-- expire_due_task_occurrences no Marco 2 — só service_role, sem grant a
-- nenhum papel de cliente. Garante o critério de aceite "override de
-- assinatura expira" (docs/15 seção 14) sem exigir que um administrador
-- volte a esta tela manualmente.
create or replace function public.expire_support_overrides()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row record;
begin
  for v_row in
    select family_id, current_period_end
    from public.subscriptions
    where status = 'support_override'
      and current_period_end is not null
      and current_period_end < timezone('utc', now())
  loop
    update public.subscriptions
    set status = 'free', current_period_end = null, auto_renew = false
    where family_id = v_row.family_id;

    insert into public.subscription_events (
      family_id, store, event_type, store_event_id, store_event_at, payload, idempotency_key
    ) values (
      v_row.family_id, 'internal', 'support_override_revoked', extensions.gen_random_uuid()::text,
      timezone('utc', now()),
      jsonb_build_object('reason', 'expired'),
      'override-expire:' || v_row.family_id || ':' || v_row.current_period_end
    )
    on conflict (idempotency_key) where idempotency_key is not null do nothing;

    perform public.apply_subscription_transition(v_row.family_id);
  end loop;
end;
$$;
