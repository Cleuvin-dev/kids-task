-- Marco 4 — XP e Progressão (parte 3/5)
-- Liga nível e streak à aprovação de tarefas. Redefine por completo
-- complete_task_occurrence/review_task_occurrence (definidas no Marco 2,
-- migration 20260731100011, já commitada) — evolução de função é sempre
-- um novo `create or replace function` numa migration nova, nunca uma
-- edição do arquivo antigo.
--
-- Única mudança de comportamento: depois de grant_task_rewards, também
-- chama process_level_changes (créditos de nível) e
-- recalculate_daily_progress + advance_streak (streak do dia da
-- OCORRÊNCIA, não do dia da aprovação — docs/05 seção 12, docs/15 seção 9:
-- "aprovação tardia usa data da execução").

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
  end if;

  select w.coin_balance, w.total_xp into v_wallet
  from public.child_wallets w where w.child_id = v_occ.child_id;

  return query select p_occurrence_id, v_new_status, v_wallet.coin_balance, v_wallet.total_xp;
end;
$$;
