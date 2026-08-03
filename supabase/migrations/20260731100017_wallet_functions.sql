-- Marco 3 — KidsCoins e Recompensas (parte 2/4)
-- Ajuste manual de moedas pelo responsável (docs/05 seção 3,
-- docs/14 seção 4).

create or replace function public.adjust_child_coins(
  p_child_id uuid,
  p_amount integer,
  p_direction text,
  p_reason text,
  p_idempotency_key text
)
returns table (coin_balance integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_family_id uuid;
  v_balance int;
  v_new_balance int;
  v_source_id uuid;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_idempotency_key is null or length(trim(p_idempotency_key)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'idempotency_key is required';
  end if;

  -- Idempotência: reprocessar a mesma chave retorna o saldo atual sem
  -- lançar de novo.
  if exists (select 1 from public.coin_ledger where idempotency_key = p_idempotency_key) then
    select w.coin_balance into v_balance
    from public.child_wallets w where w.child_id = p_child_id;
    return query select v_balance;
    return;
  end if;

  select cp.family_id into v_family_id
  from public.child_profiles cp
  where cp.id = p_child_id;

  if v_family_id is null then
    raise exception 'VALIDATION_ERROR' using detail = 'child not found';
  end if;

  if not exists (
    select 1 from public.family_members fm
    where fm.family_id = v_family_id and fm.profile_id = v_profile_id and fm.status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  if p_direction not in ('credit', 'debit') then
    raise exception 'VALIDATION_ERROR' using detail = 'direction must be credit or debit';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'amount must be a positive integer';
  end if;

  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'reason is required';
  end if;

  select w.coin_balance into v_balance
  from public.child_wallets w
  where w.child_id = p_child_id
  for update;

  if p_direction = 'debit' and p_amount > v_balance then
    raise exception 'INSUFFICIENT_COINS';
  end if;

  v_new_balance := case
    when p_direction = 'credit' then v_balance + p_amount
    else v_balance - p_amount
  end;

  v_source_id := extensions.gen_random_uuid();

  insert into public.coin_ledger (
    family_id, child_id, entry_type, amount_signed, balance_after,
    source_type, source_id, reason, created_by, idempotency_key
  ) values (
    v_family_id, p_child_id, 'manual_adjustment',
    case when p_direction = 'credit' then p_amount else -p_amount end,
    v_new_balance, 'manual_adjustment', v_source_id, p_reason, v_profile_id,
    p_idempotency_key
  );

  update public.child_wallets
  set coin_balance = v_new_balance, version = version + 1
  where child_id = p_child_id;

  return query select v_new_balance;
end;
$$;
