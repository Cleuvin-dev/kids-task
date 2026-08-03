-- Marco 4 — testes de bônus de nível (cruzar vários de uma vez, retry sem
-- duplicar), bônus de aniversário (idempotente), e streak (at_least_one,
-- percentage, dia neutro, tarefa dispensada, quebra) — docs/15 seções 8-9.
--
-- Mesmo padrão de fixture dos testes de Marco 1-3: Família A (A1
-- responsável, 1 criança free-plan) e Família B (B1, independente, só para
-- isolamento).
begin;

select plan(39);

create temporary table t_state (key text primary key, value text);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a1@familia-a.test', '', now(), '{}', '{"display_name":"A1"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'b1@familia-b.test', '', now(), '{}', '{"display_name":"B1"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'child-a1-device@device.test', '', now(), '{}', '{}', now(), now());

insert into t_state (key, value)
select 'a1_id', id::text from auth.users where email = 'a1@familia-a.test'
union all select 'b1_id', id::text from auth.users where email = 'b1@familia-b.test'
union all select 'child_a1_device_id', id::text from auth.users where email = 'child-a1-device@device.test';

create or replace function pg_temp.act_as(p_user_key text) returns void as $$
declare
  v_id text;
begin
  select value into v_id from t_state where key = p_user_key;
  perform set_config('request.jwt.claims', json_build_object('sub', v_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$ language plpgsql;

-- ---------------------------------------------------------------------
-- Fixtures de família/criança/aparelho.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'family_a_id', family_id::text from public.create_family('Familia A', 'America/Sao_Paulo', 'blue');

insert into t_state (key, value)
select 'child_a1_id', child_id::text from public.create_child(
  (select value::uuid from t_state where key = 'family_a_id'),
  'Crianca A1', '2016-05-10'
);

reset role;
reset request.jwt.claims;

insert into public.child_device_bindings (child_id, auth_user_id, device_name, authorized_by)
values (
  (select value::uuid from t_state where key = 'child_a1_id'),
  (select value::uuid from t_state where key = 'child_a1_device_id'),
  'Aparelho de teste',
  (select value::uuid from t_state where key = 'a1_id')
);

select pg_temp.act_as('b1_id');

insert into t_state (key, value)
select 'family_b_id', family_id::text from public.create_family('Familia B');

-- ---------------------------------------------------------------------
-- 1) Bônus de nível: cruzar um nível, retry idempotente, cruzar vários.
-- ---------------------------------------------------------------------
reset role;
reset request.jwt.claims;

update public.child_wallets set total_xp = 250
where child_id = (select value::uuid from t_state where key = 'child_a1_id');

select lives_ok(
  $$ select public.process_level_changes((select value::uuid from t_state where key = 'child_a1_id')) $$,
  'process_level_changes credita o nível 2 (250 XP)'
);

select results_eq(
  $$ select current_level from public.child_wallets
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (2) $$,
  'current_level vira 2'
);

select results_eq(
  $$ select coin_balance from public.child_wallets
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (5) $$,
  'Saldo recebe o bônus de nível (5 KidsCoins padrão)'
);

select results_eq(
  $$ select count(*)::int from public.coin_ledger
     where child_id = (select value::uuid from t_state where key = 'child_a1_id')
       and entry_type = 'level_bonus' $$,
  $$ values (1) $$,
  'Um lançamento de bônus de nível'
);

select lives_ok(
  $$ select public.process_level_changes((select value::uuid from t_state where key = 'child_a1_id')) $$,
  'Reprocessar sem novo XP não gera erro'
);

select results_eq(
  $$ select current_level from public.child_wallets
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (2) $$,
  'Reprocessar não avança o nível de novo'
);

select results_eq(
  $$ select coin_balance from public.child_wallets
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (5) $$,
  'Reprocessar não duplica o bônus'
);

update public.child_wallets set total_xp = 650
where child_id = (select value::uuid from t_state where key = 'child_a1_id');

select lives_ok(
  $$ select public.process_level_changes((select value::uuid from t_state where key = 'child_a1_id')) $$,
  'process_level_changes cruza os níveis 3 e 4 numa só chamada (650 XP)'
);

select results_eq(
  $$ select current_level from public.child_wallets
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (4) $$,
  'current_level vira 4 (pulou o 3 direto)'
);

select results_eq(
  $$ select coin_balance from public.child_wallets
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (15) $$,
  'Saldo recebe o bônus dos dois níveis cruzados (5 + 5)'
);

select results_eq(
  $$ select count(*)::int from public.coin_ledger
     where child_id = (select value::uuid from t_state where key = 'child_a1_id')
       and entry_type = 'level_bonus' $$,
  $$ values (3) $$,
  'Três lançamentos de bônus de nível ao todo (níveis 2, 3 e 4)'
);

-- ---------------------------------------------------------------------
-- 2) Bônus de aniversário: uma vez por ano, idempotente.
-- ---------------------------------------------------------------------
-- 2015 não é bissexto: se o teste rodar num 29/02, usa 28/02 (mesma regra
-- de docs/05 seção 11) para não quebrar make_date.
update public.child_profiles
set birth_date = case
  when extract(month from current_date) = 2 and extract(day from current_date) = 29
    then make_date(2015, 2, 28)
  else make_date(2015, extract(month from current_date)::int, extract(day from current_date)::int)
end
where id = (select value::uuid from t_state where key = 'child_a1_id');

select lives_ok(
  $$ select public.grant_birthday_bonus() $$,
  'grant_birthday_bonus credita no aniversário de hoje'
);

select results_eq(
  $$ select count(*)::int from public.coin_ledger
     where child_id = (select value::uuid from t_state where key = 'child_a1_id')
       and entry_type = 'birthday_bonus' $$,
  $$ values (1) $$,
  'Um lançamento de bônus de aniversário'
);

select results_eq(
  $$ select coin_balance from public.child_wallets
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (65) $$,
  'Saldo recebe o bônus de aniversário (15 + 50 padrão)'
);

select lives_ok(
  $$ select public.grant_birthday_bonus() $$,
  'Rodar o job de novo no mesmo dia não gera erro'
);

select results_eq(
  $$ select coin_balance from public.child_wallets
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (65) $$,
  'Reprocessar não credita o bônus de aniversário de novo'
);

-- ---------------------------------------------------------------------
-- 3) Streak — regra padrão at_least_one, tarefa bônus fora do denominador.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'task_required1_id', task_id::text from public.upsert_task_with_schedule(
  p_child_id => (select value::uuid from t_state where key = 'child_a1_id'),
  p_title => 'Tarefa obrigatória de hoje',
  p_approval_mode => 'automatic',
  p_late_policy => 'allow_late',
  p_schedule_type => 'once',
  p_one_time_date => current_date
);

insert into t_state (key, value)
select 'task_bonus1_id', task_id::text from public.upsert_task_with_schedule(
  p_child_id => (select value::uuid from t_state where key = 'child_a1_id'),
  p_title => 'Tarefa bônus de hoje',
  p_is_bonus => true,
  p_is_required => false,
  p_approval_mode => 'automatic',
  p_late_policy => 'allow_late',
  p_schedule_type => 'once',
  p_one_time_date => current_date
);

insert into t_state (key, value)
select 'occ_required1_id', id::text from public.task_occurrences
where task_id = (select value::uuid from t_state where key = 'task_required1_id');

insert into t_state (key, value)
select 'occ_bonus1_id', id::text from public.task_occurrences
where task_id = (select value::uuid from t_state where key = 'task_bonus1_id');

select pg_temp.act_as('child_a1_device_id');

select lives_ok(
  $$ select * from public.complete_task_occurrence(
       (select value::uuid from t_state where key = 'occ_required1_id'), 'idem-req1', 1, false
     ) $$,
  'A criança conclui a tarefa obrigatória de hoje'
);

select results_eq(
  $$ select required_total, required_completed, qualifies_for_streak from public.daily_progress
     where child_id = (select value::uuid from t_state where key = 'child_a1_id')
       and progress_date = current_date $$,
  $$ values (1, 1, true) $$,
  'Progresso de hoje: 1 de 1 obrigatória concluída, qualifica'
);

select results_eq(
  $$ select current_streak, best_streak from public.child_streaks
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (1, 1) $$,
  'Streak avança para 1 no primeiro dia qualificado'
);

select lives_ok(
  $$ select * from public.complete_task_occurrence(
       (select value::uuid from t_state where key = 'occ_bonus1_id'), 'idem-bonus1', 1, false
     ) $$,
  'A criança também conclui a tarefa bônus'
);

select results_eq(
  $$ select current_streak from public.child_streaks
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (1) $$,
  'Tarefa bônus não altera o streak nem duplica o avanço do mesmo dia'
);

-- ---------------------------------------------------------------------
-- 4) Streak — regra percentage (amanhã).
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

update public.child_profiles
set streak_rule = 'percentage', streak_percentage = 50
where id = (select value::uuid from t_state where key = 'child_a1_id');

insert into t_state (key, value)
select 'task_pct_a_id', task_id::text from public.upsert_task_with_schedule(
  p_child_id => (select value::uuid from t_state where key = 'child_a1_id'),
  p_title => 'Tarefa percentual A',
  p_approval_mode => 'automatic',
  p_late_policy => 'allow_late',
  p_schedule_type => 'once',
  p_one_time_date => current_date + 1
);

insert into t_state (key, value)
select 'task_pct_b_id', task_id::text from public.upsert_task_with_schedule(
  p_child_id => (select value::uuid from t_state where key = 'child_a1_id'),
  p_title => 'Tarefa percentual B',
  p_approval_mode => 'automatic',
  p_late_policy => 'allow_late',
  p_schedule_type => 'once',
  p_one_time_date => current_date + 1
);

insert into t_state (key, value)
select 'occ_pct_a_id', id::text from public.task_occurrences
where task_id = (select value::uuid from t_state where key = 'task_pct_a_id');

select pg_temp.act_as('child_a1_device_id');

select lives_ok(
  $$ select * from public.complete_task_occurrence(
       (select value::uuid from t_state where key = 'occ_pct_a_id'), 'idem-pct-a', 1, false
     ) $$,
  'A criança conclui metade das tarefas de amanhã'
);

select results_eq(
  $$ select required_total, required_completed, qualifies_for_streak from public.daily_progress
     where child_id = (select value::uuid from t_state where key = 'child_a1_id')
       and progress_date = current_date + 1 $$,
  $$ values (2, 1, true) $$,
  '50% concluído qualifica com o limite configurado de 50%'
);

select results_eq(
  $$ select current_streak, best_streak from public.child_streaks
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (2, 2) $$,
  'Streak avança para 2 no segundo dia consecutivo qualificado'
);

-- ---------------------------------------------------------------------
-- 5) Dia neutro: única tarefa obrigatória foi dispensada.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'task_dispense_id', task_id::text from public.upsert_task_with_schedule(
  p_child_id => (select value::uuid from t_state where key = 'child_a1_id'),
  p_title => 'Tarefa que será dispensada',
  p_approval_mode => 'automatic',
  p_late_policy => 'allow_late',
  p_schedule_type => 'once',
  p_one_time_date => current_date + 2
);

insert into t_state (key, value)
select 'occ_dispense_id', id::text from public.task_occurrences
where task_id = (select value::uuid from t_state where key = 'task_dispense_id');

select lives_ok(
  $$ select public.skip_task_occurrence(
       (select value::uuid from t_state where key = 'occ_dispense_id'), 'Viagem em família', 'idem-skip-1'
     ) $$,
  'A1 dispensa a única tarefa obrigatória de depois de amanhã'
);

select lives_ok(
  $$ select public.recalculate_daily_progress(
       (select value::uuid from t_state where key = 'child_a1_id'), current_date + 2
     ) $$,
  'Recalcula o progresso do dia com a tarefa dispensada'
);

select results_eq(
  $$ select required_total from public.daily_progress
     where child_id = (select value::uuid from t_state where key = 'child_a1_id')
       and progress_date = current_date + 2 $$,
  $$ values (0) $$,
  'Tarefa dispensada sai do denominador (dia fica neutro)'
);

select lives_ok(
  $$ select public.advance_streak(
       (select value::uuid from t_state where key = 'child_a1_id'), current_date + 2
     ) $$,
  'advance_streak roda sem erro no dia neutro'
);

select results_eq(
  $$ select current_streak from public.child_streaks
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (2) $$,
  'Dia neutro não aumenta nem quebra o streak'
);

-- ---------------------------------------------------------------------
-- 6) Streak quebra: tarefa obrigatória não concluída.
-- ---------------------------------------------------------------------
insert into t_state (key, value)
select 'task_break_id', task_id::text from public.upsert_task_with_schedule(
  p_child_id => (select value::uuid from t_state where key = 'child_a1_id'),
  p_title => 'Tarefa que ficará pendente',
  p_approval_mode => 'automatic',
  p_late_policy => 'allow_late',
  p_schedule_type => 'once',
  p_one_time_date => current_date + 3
);

select lives_ok(
  $$ select public.recalculate_daily_progress(
       (select value::uuid from t_state where key = 'child_a1_id'), current_date + 3
     ) $$,
  'Recalcula o progresso de um dia com tarefa pendente (não concluída)'
);

select results_eq(
  $$ select required_total, required_completed, qualifies_for_streak from public.daily_progress
     where child_id = (select value::uuid from t_state where key = 'child_a1_id')
       and progress_date = current_date + 3 $$,
  $$ values (1, 0, false) $$,
  '0% concluído não qualifica'
);

select lives_ok(
  $$ select public.advance_streak(
       (select value::uuid from t_state where key = 'child_a1_id'), current_date + 3
     ) $$,
  'advance_streak processa o dia não qualificado'
);

select results_eq(
  $$ select current_streak from public.child_streaks
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (0) $$,
  'Streak quebra (volta a zero) num dia obrigatório não cumprido'
);

-- ---------------------------------------------------------------------
-- 7) Isolamento entre famílias via RLS.
-- ---------------------------------------------------------------------
select pg_temp.act_as('b1_id');

select is_empty(
  $$ select 1 from public.child_streaks
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  'B1 não enxerga o streak da criança da família A'
);

select is_empty(
  $$ select 1 from public.daily_progress
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  'B1 não enxerga o progresso diário da criança da família A'
);

-- ---------------------------------------------------------------------
-- 8) Privilégio mínimo: nenhuma destas é chamável por authenticated.
-- ---------------------------------------------------------------------
select ok(
  not has_function_privilege('authenticated', 'public.process_level_changes(uuid)', 'EXECUTE'),
  'authenticated não pode chamar process_level_changes diretamente'
);

select ok(
  not has_function_privilege('authenticated', 'public.recalculate_daily_progress(uuid, date)', 'EXECUTE'),
  'authenticated não pode chamar recalculate_daily_progress diretamente'
);

select ok(
  not has_function_privilege('authenticated', 'public.advance_streak(uuid, date)', 'EXECUTE'),
  'authenticated não pode chamar advance_streak diretamente'
);

select ok(
  not has_function_privilege('authenticated', 'public.grant_birthday_bonus()', 'EXECUTE'),
  'authenticated não pode chamar grant_birthday_bonus diretamente'
);

select * from finish();

rollback;
