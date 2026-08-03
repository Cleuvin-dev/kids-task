-- Marco 4 — XP e Progressão (parte 2/5)
-- Funções internas de nível, aniversário e streak (docs/14 seção 4).
-- Nenhuma destas é exposta a `authenticated` — todas são chamadas de
-- dentro de complete_task_occurrence/review_task_occurrence (nível/streak)
-- ou pelo cron (aniversário), nunca diretamente pelo cliente.

-- ---------------------------------------------------------------------
-- process_level_changes: credita o bônus de TODOS os níveis cruzados numa
-- única aprovação, de forma idempotente (docs/05 seção 9, docs/15 seção 8).
-- ---------------------------------------------------------------------
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
    if coalesce(v_bonus_coins, 0) > 0 then
      v_idempotency_key := 'level_up:' || p_child_id::text || ':' || v_level::text;

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
  end loop;

  update public.child_wallets
  set current_level = v_new_level, coin_balance = v_balance, version = version + 1
  where child_id = p_child_id;
end;
$$;

-- ---------------------------------------------------------------------
-- grant_birthday_bonus: uma vez por ano, no fuso da família. 29/02 vira
-- 28/02 em anos não bissextos (docs/05 seção 11). Chamada pelo cron para
-- todas as crianças ativas.
-- ---------------------------------------------------------------------
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
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- recalculate_daily_progress: quantas tarefas obrigatórias (não bônus, não
-- dispensadas) foram aprovadas num dia, e se o dia qualifica para o streak
-- segundo a regra da criança (docs/05 seção 12).
--
-- Simplificação registrada: usa a definição ATUAL de tasks.is_required/
-- is_bonus (não um snapshot por ocorrência, que o Marco 2 não persistiu).
-- Na prática o recálculo roda no mesmo dia da aprovação, então a janela de
-- divergência é pequena; ver docs/IMPLEMENTATION_STATUS.md.
-- ---------------------------------------------------------------------
create or replace function public.recalculate_daily_progress(
  p_child_id uuid,
  p_progress_date date
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rule text;
  v_pct_threshold int;
  v_required_total int;
  v_required_completed int;
  v_percentage int;
  v_qualifies boolean;
begin
  select streak_rule, streak_percentage into v_rule, v_pct_threshold
  from public.child_profiles where id = p_child_id;

  select count(*) filter (where true), count(*) filter (where o.status = 'approved')
  into v_required_total, v_required_completed
  from public.task_occurrences o
  join public.tasks t on t.id = o.task_id
  where o.child_id = p_child_id
    and o.occurrence_date = p_progress_date
    and t.is_required
    and not t.is_bonus
    and o.status <> 'skipped_by_guardian';

  v_percentage := case when coalesce(v_required_total, 0) = 0 then 0
    else round(100.0 * v_required_completed / v_required_total)::int end;

  v_qualifies := case
    when coalesce(v_required_total, 0) = 0 then false
    when v_rule = 'all_required' then v_required_completed = v_required_total
    when v_rule = 'percentage' then v_percentage >= coalesce(v_pct_threshold, 80)
    else v_required_completed >= 1 -- at_least_one (padrão)
  end;

  insert into public.daily_progress (
    child_id, progress_date, required_total, required_completed, percentage,
    qualifies_for_streak, calculated_at
  ) values (
    p_child_id, p_progress_date, coalesce(v_required_total, 0), coalesce(v_required_completed, 0),
    v_percentage, v_qualifies, timezone('utc', now())
  )
  on conflict (child_id, progress_date) do update set
    required_total = excluded.required_total,
    required_completed = excluded.required_completed,
    percentage = excluded.percentage,
    qualifies_for_streak = excluded.qualifies_for_streak,
    calculated_at = excluded.calculated_at;
end;
$$;

-- ---------------------------------------------------------------------
-- advance_streak: idempotente por (child_id, progress_date) via
-- last_qualified_date — reprocessar o mesmo dia não incrementa de novo
-- (docs/15 seção 9).
--
-- Simplificação registrada: cobre o caso comum (dias processados em ordem
-- crescente). Uma aprovação tardia que altera um dia MUITO no passado não
-- recalcula toda a cadeia de streak seguinte — ver
-- docs/IMPLEMENTATION_STATUS.md.
-- ---------------------------------------------------------------------
create or replace function public.advance_streak(
  p_child_id uuid,
  p_progress_date date
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_required_total int;
  v_qualifies boolean;
  v_last_qualified date;
  v_current int;
begin
  select required_total, qualifies_for_streak into v_required_total, v_qualifies
  from public.daily_progress
  where child_id = p_child_id and progress_date = p_progress_date;

  if not found or v_required_total = 0 then
    -- Dia neutro ou ainda não calculado: não mexe no streak.
    return;
  end if;

  select current_streak, last_qualified_date into v_current, v_last_qualified
  from public.child_streaks
  where child_id = p_child_id
  for update;

  if not v_qualifies then
    update public.child_streaks set current_streak = 0 where child_id = p_child_id;
    return;
  end if;

  if v_last_qualified is not null and v_last_qualified >= p_progress_date then
    -- Já contabilizado (reprocessamento idempotente).
    return;
  end if;

  update public.child_streaks
  set current_streak = v_current + 1,
      best_streak = greatest(best_streak, v_current + 1),
      last_qualified_date = p_progress_date
  where child_id = p_child_id;
end;
$$;
