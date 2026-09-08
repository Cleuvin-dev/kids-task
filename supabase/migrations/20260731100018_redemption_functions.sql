-- Marco 3 — KidsCoins e Recompensas (parte 3/4)
-- Ciclo de vida do resgate (docs/05 seção 5, docs/14 seção 5).

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
    select 1 from public.redemption_events re
    where re.redemption_id = p_redemption_id and re.idempotency_key = p_idempotency_key
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

  select w.coin_balance into v_balance
  from public.child_wallets w where w.child_id = v_redemption.child_id;
  return query select p_redemption_id, v_new_status, v_balance;
end;
$$;

create or replace function public.mark_redemption_delivered(
  p_redemption_id uuid,
  p_idempotency_key text
)
returns table (redemption_id uuid, status text)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_profile_id uuid := (select auth.uid());
  v_redemption record;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
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
    select 1 from public.redemption_events re
    where re.redemption_id = p_redemption_id and re.idempotency_key = p_idempotency_key
  ) then
    return query select v_redemption.id, v_redemption.status;
    return;
  end if;

  if v_redemption.status <> 'approved' then
    raise exception 'REDEMPTION_NOT_PENDING';
  end if;

  -- "Entregue" só registra a entrega física; nunca movimenta saldo de novo
  -- (docs/05 seção 5).
  update public.redemption_requests
  set status = 'delivered', delivered_at = timezone('utc', now()), version = version + 1
  where id = p_redemption_id;

  insert into public.redemption_events (redemption_id, event_type, actor, actor_role, idempotency_key)
  values (p_redemption_id, 'delivered', v_profile_id, 'guardian', p_idempotency_key);

  return query select p_redemption_id, 'delivered'::text;
end;
$$;

create or replace function public.cancel_approved_redemption(
  p_redemption_id uuid,
  p_reason text,
  p_idempotency_key text
)
returns table (redemption_id uuid, status text, coin_balance integer)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_profile_id uuid := (select auth.uid());
  v_redemption record;
  v_balance int;
  v_new_balance int;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'reason is required';
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
    select 1 from public.redemption_events re
    where re.redemption_id = p_redemption_id and re.idempotency_key = p_idempotency_key
  ) then
    select w.coin_balance into v_balance
    from public.child_wallets w where w.child_id = v_redemption.child_id;
    return query select v_redemption.id, v_redemption.status, v_balance;
    return;
  end if;

  -- Estorno excepcional só se aplica antes da entrega (docs/05 seção 5:
  -- approved -> cancelled; delivered é terminal).
  if v_redemption.status <> 'approved' then
    raise exception 'REDEMPTION_NOT_PENDING';
  end if;

  select coin_balance into v_balance
  from public.child_wallets
  where child_id = v_redemption.child_id
  for update;

  v_new_balance := coalesce(v_balance, 0) + v_redemption.cost_snapshot;

  update public.redemption_requests
  set status = 'cancelled', rejection_reason = p_reason, version = version + 1
  where id = p_redemption_id;

  insert into public.coin_ledger (
    family_id, child_id, entry_type, amount_signed, balance_after,
    source_type, source_id, reason, created_by, idempotency_key
  ) values (
    v_redemption.family_id, v_redemption.child_id, 'redemption_refund', v_redemption.cost_snapshot,
    v_new_balance, 'redemption_request', p_redemption_id, p_reason, v_profile_id,
    p_idempotency_key || ':ledger'
  )
  on conflict (source_id, entry_type) do nothing;

  if found then
    update public.child_wallets
    set coin_balance = v_new_balance, version = version + 1
    where child_id = v_redemption.child_id;
  end if;

  insert into public.redemption_events (redemption_id, event_type, actor, actor_role, payload, idempotency_key)
  values (p_redemption_id, 'cancelled', v_profile_id, 'guardian',
          jsonb_build_object('reason', p_reason), p_idempotency_key);

  select w.coin_balance into v_balance
  from public.child_wallets w where w.child_id = v_redemption.child_id;
  return query select p_redemption_id, 'cancelled'::text, v_balance;
end;
$$;
