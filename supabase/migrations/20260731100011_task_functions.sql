-- Marco 2 — Rotina e Tarefas (parte 4/8)
-- Funções transacionais chamadas via RPC (docs/14_APIS_FUNCOES_E_EVENTOS.md
-- seção 3-4). Mesma convenção de erro do Marco 1: a MENSAGEM da exceção é
-- exatamente um DomainErrorCode.wireName.

-- ---------------------------------------------------------------------
-- Helper: datas que uma agenda ocuparia dentro de uma janela [inicio, fim].
-- Reutilizado pela checagem de limite diário e pela geração de ocorrências.
-- ---------------------------------------------------------------------
create or replace function public.task_schedule_occurrence_dates(
  p_schedule_type text,
  p_one_time_date date,
  p_weekdays smallint[],
  p_starts_on date,
  p_ends_on date,
  p_window_start date,
  p_window_end date
)
returns setof date
language sql
stable
set search_path = ''
as $$
  select d::date
  from generate_series(
    greatest(p_window_start, coalesce(p_starts_on, p_window_start)),
    least(p_window_end, coalesce(p_ends_on, p_window_end)),
    interval '1 day'
  ) as d
  where p_schedule_type = 'recurring'
    and extract(dow from d)::smallint = any (p_weekdays)
  union all
  select p_one_time_date
  where p_schedule_type = 'once'
    and p_one_time_date between p_window_start and p_window_end;
$$;

-- ---------------------------------------------------------------------
-- upsert_task_with_schedule: cria ou edita tarefa+agenda, validando o
-- limite diário do plano gratuito antes de ativar (docs/04 seção 10).
-- ---------------------------------------------------------------------
create or replace function public.upsert_task_with_schedule(
  p_task_id uuid default null,
  p_child_id uuid default null,
  p_title text default null,
  p_description text default null,
  p_icon_key text default 'default',
  p_category text default 'geral',
  p_period text default 'anytime',
  p_is_bonus boolean default false,
  p_is_required boolean default true,
  p_counts_toward_streak boolean default true,
  p_coin_reward integer default 0,
  p_xp_reward_default integer default 0,
  p_approval_mode text default 'automatic',
  p_late_policy text default 'allow_late',
  p_sort_order integer default 0,
  p_schedule_type text default 'recurring',
  p_one_time_date date default null,
  p_weekdays smallint[] default null,
  p_starts_on date default null,
  p_ends_on date default null,
  p_start_time time default null,
  p_due_time time default null
)
returns table (task_id uuid, schedule_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_family_id uuid;
  v_child_id uuid;
  v_task_id uuid;
  v_schedule_id uuid;
  v_max_daily int;
  v_window_start date := current_date;
  v_window_end date := current_date + 29;
  v_conflicts jsonb := '[]'::jsonb;
  v_date date;
  v_existing_count int;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_task_id is not null then
    select t.family_id, t.child_id into v_family_id, v_child_id
    from public.tasks t
    where t.id = p_task_id;

    if v_family_id is null then
      raise exception 'VALIDATION_ERROR' using detail = 'task not found';
    end if;
  else
    if p_child_id is null then
      raise exception 'VALIDATION_ERROR' using detail = 'child_id is required to create a task';
    end if;

    select cp.family_id into v_family_id
    from public.child_profiles cp
    where cp.id = p_child_id and cp.status = 'active';

    if v_family_id is null then
      raise exception 'VALIDATION_ERROR' using detail = 'child not found';
    end if;

    v_child_id := p_child_id;
  end if;

  if not exists (
    select 1 from public.family_members fm
    where fm.family_id = v_family_id and fm.profile_id = v_profile_id and fm.status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  if p_title is null or length(trim(p_title)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'title is required';
  end if;

  if p_period not in ('morning', 'afternoon_evening', 'anytime') then
    raise exception 'VALIDATION_ERROR' using detail = 'invalid period';
  end if;

  if p_approval_mode not in ('automatic', 'manual') then
    raise exception 'VALIDATION_ERROR' using detail = 'invalid approval_mode';
  end if;

  if p_late_policy not in ('allow_late', 'expire_no_reward') then
    raise exception 'VALIDATION_ERROR' using detail = 'invalid late_policy';
  end if;

  if coalesce(p_coin_reward, 0) < 0 or coalesce(p_xp_reward_default, 0) < 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'rewards must not be negative';
  end if;

  if coalesce(p_is_bonus, false) and coalesce(p_is_required, true) then
    raise exception 'VALIDATION_ERROR' using detail = 'a bonus task cannot be required';
  end if;

  if p_schedule_type not in ('once', 'recurring') then
    raise exception 'VALIDATION_ERROR' using detail = 'invalid schedule_type';
  end if;

  if p_schedule_type = 'once' then
    if p_one_time_date is null then
      raise exception 'VALIDATION_ERROR' using detail = 'one_time_date is required for a once schedule';
    end if;
  else
    if p_weekdays is null or array_length(p_weekdays, 1) is null or array_length(p_weekdays, 1) = 0 then
      raise exception 'VALIDATION_ERROR' using detail = 'weekdays is required for a recurring schedule';
    end if;
    if not (p_weekdays <@ array[0, 1, 2, 3, 4, 5, 6]::smallint[]) then
      raise exception 'VALIDATION_ERROR' using detail = 'weekdays must be between 0 and 6';
    end if;
  end if;

  select p.max_daily_occurrences into v_max_daily
  from public.families f
  join public.plans p on p.id = f.plan_id
  where f.id = v_family_id
  for update of f;

  -- Simula os dias que a nova agenda ocuparia na janela móvel de 30 dias
  -- e conta ocorrências ativas de OUTRAS tarefas já existentes nesses dias
  -- para a mesma criança. Nunca ativa silenciosamente acima do limite
  -- (docs/04 seção 10).
  for v_date in
    select * from public.task_schedule_occurrence_dates(
      p_schedule_type, p_one_time_date, p_weekdays, p_starts_on, p_ends_on,
      v_window_start, v_window_end
    )
  loop
    select count(*) into v_existing_count
    from public.task_occurrences o
    where o.child_id = v_child_id
      and o.occurrence_date = v_date
      and o.status <> 'cancelled'
      and o.task_id is distinct from p_task_id;

    if v_existing_count + 1 > v_max_daily then
      v_conflicts := v_conflicts || jsonb_build_object('date', v_date, 'existing_count', v_existing_count);
    end if;
  end loop;

  if jsonb_array_length(v_conflicts) > 0 then
    raise exception 'PLAN_DAILY_TASK_LIMIT' using detail = v_conflicts::text;
  end if;

  if p_task_id is null then
    insert into public.tasks (
      family_id, child_id, title, description, icon_key, category, period,
      is_bonus, is_required, counts_toward_streak, coin_reward, xp_reward_default,
      approval_mode, late_policy, sort_order, created_by
    ) values (
      v_family_id, v_child_id, trim(p_title), p_description, coalesce(p_icon_key, 'default'),
      coalesce(p_category, 'geral'), p_period, coalesce(p_is_bonus, false), coalesce(p_is_required, true),
      coalesce(p_counts_toward_streak, true), coalesce(p_coin_reward, 0), coalesce(p_xp_reward_default, 0),
      p_approval_mode, p_late_policy, coalesce(p_sort_order, 0), v_profile_id
    )
    returning id into v_task_id;
  else
    update public.tasks set
      title = trim(p_title),
      description = p_description,
      icon_key = coalesce(p_icon_key, 'default'),
      category = coalesce(p_category, 'geral'),
      period = p_period,
      is_bonus = coalesce(p_is_bonus, false),
      is_required = coalesce(p_is_required, true),
      counts_toward_streak = coalesce(p_counts_toward_streak, true),
      coin_reward = coalesce(p_coin_reward, 0),
      xp_reward_default = coalesce(p_xp_reward_default, 0),
      approval_mode = p_approval_mode,
      late_policy = p_late_policy,
      sort_order = coalesce(p_sort_order, 0)
    where id = p_task_id;

    v_task_id := p_task_id;

    -- Ocorrências futuras ainda pendentes são regeneradas com os novos
    -- snapshots; histórico (awaiting_approval/approved/late/expired/etc.)
    -- nunca é tocado (docs/04 seção 11).
    delete from public.task_occurrences
    where task_id = v_task_id
      and occurrence_date >= current_date
      and status = 'pending';
  end if;

  insert into public.task_schedules (
    task_id, schedule_type, one_time_date, weekdays, starts_on, ends_on, start_time, due_time
  ) values (
    v_task_id, p_schedule_type, p_one_time_date, p_weekdays, p_starts_on, p_ends_on, p_start_time, p_due_time
  )
  on conflict (task_id) where active
  do update set
    schedule_type = excluded.schedule_type,
    one_time_date = excluded.one_time_date,
    weekdays = excluded.weekdays,
    starts_on = excluded.starts_on,
    ends_on = excluded.ends_on,
    start_time = excluded.start_time,
    due_time = excluded.due_time
  returning id into v_schedule_id;

  perform public.generate_task_occurrences(v_family_id);

  return query select v_task_id, v_schedule_id;
end;
$$;

create or replace function public.pause_task(p_task_id uuid)
returns void
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

  if not exists (
    select 1 from public.tasks t
    join public.family_members fm on fm.family_id = t.family_id
    where t.id = p_task_id and fm.profile_id = v_profile_id and fm.status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  update public.tasks set is_active = false where id = p_task_id;
  update public.task_schedules set active = false where task_id = p_task_id and active;
end;
$$;

create or replace function public.resume_task(p_task_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_family_id uuid;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select t.family_id into v_family_id
  from public.tasks t
  where t.id = p_task_id
    and t.archived_at is null
    and exists (
      select 1 from public.family_members fm
      where fm.family_id = t.family_id and fm.profile_id = v_profile_id and fm.status = 'active'
    );

  if v_family_id is null then
    raise exception 'FORBIDDEN';
  end if;

  update public.tasks set is_active = true where id = p_task_id;

  -- Só a agenda mais recente é reativada (uma edição anterior pode ter
  -- deixado agendas antigas pausadas como histórico).
  update public.task_schedules
  set active = true
  where id = (
    select id from public.task_schedules
    where task_id = p_task_id
    order by created_at desc
    limit 1
  );

  perform public.generate_task_occurrences(v_family_id);
end;
$$;

create or replace function public.archive_task(p_task_id uuid)
returns void
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

  if not exists (
    select 1 from public.tasks t
    join public.family_members fm on fm.family_id = t.family_id
    where t.id = p_task_id and fm.profile_id = v_profile_id and fm.status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  -- Arquivamento lógico: preferido a exclusão física (docs/04 seção 11).
  update public.tasks
  set is_active = false, archived_at = timezone('utc', now())
  where id = p_task_id and archived_at is null;

  update public.task_schedules set active = false where task_id = p_task_id and active;

  delete from public.task_occurrences
  where task_id = p_task_id
    and occurrence_date >= current_date
    and status = 'pending';
end;
$$;

-- ---------------------------------------------------------------------
-- generate_task_occurrences: job diário (+ chamado ao final de
-- upsert_task_with_schedule/resume_task). Idempotente via unique index.
-- Só service_role (ver migration de privilégios).
-- ---------------------------------------------------------------------
create or replace function public.generate_task_occurrences(p_family_id uuid default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_task record;
  v_schedule record;
  v_family_tz text;
  v_max_daily int;
  v_date date;
  v_daily_count int;
begin
  for v_task in
    select t.id, t.family_id, t.child_id, t.coin_reward, t.xp_reward_default,
           t.approval_mode, t.late_policy, t.title, t.icon_key
    from public.tasks t
    where t.is_active
      and t.archived_at is null
      and (p_family_id is null or t.family_id = p_family_id)
  loop
    select s.* into v_schedule
    from public.task_schedules s
    where s.task_id = v_task.id and s.active
    limit 1;

    if not found then
      continue;
    end if;

    select f.timezone into v_family_tz from public.families f where f.id = v_task.family_id;

    select p.max_daily_occurrences into v_max_daily
    from public.families f
    join public.plans p on p.id = f.plan_id
    where f.id = v_task.family_id;

    for v_date in
      select * from public.task_schedule_occurrence_dates(
        v_schedule.schedule_type, v_schedule.one_time_date, v_schedule.weekdays,
        v_schedule.starts_on, v_schedule.ends_on,
        current_date, current_date + 29
      )
    loop
      -- Defesa em profundidade: o limite já foi validado em
      -- upsert_task_with_schedule antes de ativar a agenda, mas o job roda
      -- em lote sobre todas as tarefas; se ainda assim estourasse, pula só
      -- essa ocorrência em vez de abortar o lote inteiro (docs/14 seção 3).
      select count(*) into v_daily_count
      from public.task_occurrences o
      where o.child_id = v_task.child_id
        and o.occurrence_date = v_date
        and o.status <> 'cancelled';

      if v_daily_count >= v_max_daily then
        continue;
      end if;

      insert into public.task_occurrences (
        task_id, child_id, family_id, occurrence_date, starts_at, due_at,
        coin_reward_snapshot, xp_reward_snapshot, approval_mode_snapshot,
        late_policy_snapshot, title_snapshot, icon_snapshot
      ) values (
        v_task.id, v_task.child_id, v_task.family_id, v_date,
        case when v_schedule.start_time is not null
          then (v_date + v_schedule.start_time) at time zone coalesce(v_family_tz, 'America/Sao_Paulo')
          else null end,
        case when v_schedule.due_time is not null
          then (v_date + v_schedule.due_time) at time zone coalesce(v_family_tz, 'America/Sao_Paulo')
          else null end,
        v_task.coin_reward, v_task.xp_reward_default, v_task.approval_mode,
        v_task.late_policy, v_task.title, v_task.icon_key
      )
      on conflict (task_id, child_id, occurrence_date) do nothing;
    end loop;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- expire_due_task_occurrences: job a cada 5 minutos (docs/14 seção 13).
-- Só service_role.
-- ---------------------------------------------------------------------
create or replace function public.expire_due_task_occurrences()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.task_occurrences
  set status = 'late', version = version + 1
  where status = 'pending'
    and due_at is not null
    and due_at < timezone('utc', now())
    and late_policy_snapshot = 'allow_late';

  update public.task_occurrences
  set status = 'expired', expired_at = timezone('utc', now()), version = version + 1
  where status = 'pending'
    and due_at is not null
    and due_at < timezone('utc', now())
    and late_policy_snapshot = 'expire_no_reward';
end;
$$;

-- ---------------------------------------------------------------------
-- grant_task_rewards: interna, nunca exposta a nenhum papel de cliente.
-- Só chamada de dentro de complete_task_occurrence/review_task_occurrence,
-- na mesma transação que já tem a ocorrência travada (for update).
-- ---------------------------------------------------------------------
create or replace function public.grant_task_rewards(p_occurrence_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_occ record;
  v_idempotency_key text := 'occurrence:' || p_occurrence_id::text;
  v_coin_balance int;
  v_total_xp int;
begin
  select * into v_occ from public.task_occurrences where id = p_occurrence_id;

  if not found then
    return;
  end if;

  select coin_balance, total_xp into v_coin_balance, v_total_xp
  from public.child_wallets where child_id = v_occ.child_id for update;

  v_coin_balance := coalesce(v_coin_balance, 0) + v_occ.coin_reward_snapshot;
  v_total_xp := coalesce(v_total_xp, 0) + v_occ.xp_reward_snapshot;

  insert into public.coin_ledger (
    family_id, child_id, entry_type, amount_signed, balance_after,
    source_type, source_id, reason, idempotency_key
  ) values (
    v_occ.family_id, v_occ.child_id, 'task_reward', v_occ.coin_reward_snapshot, v_coin_balance,
    'task_occurrence', p_occurrence_id, v_occ.title_snapshot, v_idempotency_key
  )
  on conflict (source_id, entry_type) do nothing;

  if not found then
    -- Já creditado antes (retry ou duplo-approve simultâneo): não duplica
    -- (docs/04 seção 8).
    return;
  end if;

  insert into public.xp_ledger (
    family_id, child_id, amount, total_after, source_type, source_id, idempotency_key
  ) values (
    v_occ.family_id, v_occ.child_id, v_occ.xp_reward_snapshot, v_total_xp,
    'task_occurrence', p_occurrence_id, v_idempotency_key || ':xp'
  )
  on conflict (source_id) do nothing;

  update public.child_wallets
  set coin_balance = v_coin_balance, total_xp = v_total_xp, version = version + 1
  where child_id = v_occ.child_id;
end;
$$;

-- ---------------------------------------------------------------------
-- complete_task_occurrence: toque em "Concluir" (criança ou responsável
-- em nome dela). Automático credita na hora; manual só envia para
-- aprovação (docs/04 seção 6-7).
-- ---------------------------------------------------------------------
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
  end if;

  select w.coin_balance, w.total_xp into v_wallet
  from public.child_wallets w where w.child_id = v_occ.child_id;

  return query select p_occurrence_id, v_new_status, v_wallet.coin_balance, v_wallet.total_xp;
end;
$$;

-- ---------------------------------------------------------------------
-- review_task_occurrence: só responsável. Aprovar credita; rejeitar exige
-- motivo e volta para needs_correction (docs/04 seção 6-7).
-- ---------------------------------------------------------------------
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
  end if;

  select w.coin_balance, w.total_xp into v_wallet
  from public.child_wallets w where w.child_id = v_occ.child_id;

  return query select p_occurrence_id, v_new_status, v_wallet.coin_balance, v_wallet.total_xp;
end;
$$;

-- ---------------------------------------------------------------------
-- skip_task_occurrence: só responsável, exige motivo, nunca credita
-- (docs/04 seção 7 e 12).
-- ---------------------------------------------------------------------
create or replace function public.skip_task_occurrence(
  p_occurrence_id uuid,
  p_reason text,
  p_idempotency_key text
)
returns table (occurrence_id uuid, status text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_occ record;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'reason is required';
  end if;

  if p_idempotency_key is null or length(trim(p_idempotency_key)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'idempotency_key is required';
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
    return query select v_occ.id, v_occ.status;
    return;
  end if;

  if v_occ.status not in ('pending', 'late', 'awaiting_approval', 'needs_correction') then
    raise exception 'TASK_NOT_COMPLETABLE';
  end if;

  update public.task_occurrences
  set status = 'skipped_by_guardian', rejection_reason = p_reason, version = version + 1
  where id = p_occurrence_id;

  insert into public.task_events (occurrence_id, event_type, actor, actor_role, payload, idempotency_key)
  values (
    p_occurrence_id, 'skipped', v_profile_id, 'guardian',
    jsonb_build_object('reason', p_reason), p_idempotency_key
  );

  return query select p_occurrence_id, 'skipped_by_guardian'::text;
end;
$$;
