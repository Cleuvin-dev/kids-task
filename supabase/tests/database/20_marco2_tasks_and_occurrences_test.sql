-- Marco 2 — testes de máquina de estados, crédito idempotente, limite do
-- plano gratuito, política de prazo, isolamento entre famílias e
-- privilégio mínimo (docs/15_CRITERIOS_DE_ACEITE_E_TESTES.md,
-- docs/04_TAREFAS_APROVACOES_E_ROTINA.md).
--
-- Mesmo padrão de fixture de 10_marco1_family_auth_test.sql: Família A
-- (A1 + A2 responsáveis, 1 criança free-plan) e Família B (B1, independente).
begin;

select plan(41);

create temporary table t_state (key text primary key, value text);

-- ---------------------------------------------------------------------
-- Fixtures de auth.users, incluindo uma sessão técnica anônima simulando
-- o aparelho da criança A1 (o vínculo real seria criado pela Edge Function
-- authorize-child-device, fora do escopo do pgTAP; aqui inserimos o
-- child_device_bindings diretamente como dono da tabela).
-- ---------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a1@familia-a.test', '', now(), '{}', '{"display_name":"A1"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a2@familia-a.test', '', now(), '{}', '{"display_name":"A2"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'b1@familia-b.test', '', now(), '{}', '{"display_name":"B1"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'child-a1-device@device.test', '', now(), '{}', '{}', now(), now());

insert into t_state (key, value)
select 'a1_id', id::text from auth.users where email = 'a1@familia-a.test'
union all select 'a2_id', id::text from auth.users where email = 'a2@familia-a.test'
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
-- Fixtures de família/criança (comportamento já coberto pelo Marco 1;
-- aqui só preparamos o terreno, sem reafirmar).
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'family_a_id', family_id::text from public.create_family('Familia A', 'America/Sao_Paulo', 'blue');

insert into t_state (key, value)
select 'invite_token', token from public.invite_guardian(
  (select value::uuid from t_state where key = 'family_a_id'),
  'a2@familia-a.test'
);

select pg_temp.act_as('a2_id');
select public.accept_guardian_invite((select value from t_state where key = 'invite_token'));

select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'child_a1_id', child_id::text from public.create_child(
  (select value::uuid from t_state where key = 'family_a_id'),
  'Crianca A1', '2016-05-10'
);

-- Vínculo de aparelho da criança A1, inserido diretamente como dono da
-- tabela (sem policy de insert para clientes, por design).
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

insert into t_state (key, value)
select 'child_b1_id', child_id::text from public.create_child(
  (select value::uuid from t_state where key = 'family_b_id'),
  'Crianca B1', '2015-03-20'
);

-- ---------------------------------------------------------------------
-- 1) Criação de tarefas e geração imediata de ocorrências.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'task_auto_id', task_id::text from public.upsert_task_with_schedule(
  p_child_id => (select value::uuid from t_state where key = 'child_a1_id'),
  p_title => 'Escovar os dentes',
  p_coin_reward => 5,
  p_xp_reward_default => 10,
  p_approval_mode => 'automatic',
  p_late_policy => 'allow_late',
  p_schedule_type => 'recurring',
  p_weekdays => array[0, 1, 2, 3, 4, 5, 6]::smallint[]
);

select ok(
  (select value from t_state where key = 'task_auto_id') is not null,
  'upsert_task_with_schedule cria a tarefa automática de A1'
);

select results_eq(
  $$ select count(*)::int from public.task_occurrences
     where task_id = (select value::uuid from t_state where key = 'task_auto_id')
       and occurrence_date = current_date $$,
  $$ values (1) $$,
  'A ocorrência de hoje já existe logo após criar a agenda recorrente'
);

-- ---------------------------------------------------------------------
-- 2) Limite diário do plano gratuito (3 ocorrências/dia).
-- ---------------------------------------------------------------------
insert into t_state (key, value)
select 'task_manual_id', task_id::text from public.upsert_task_with_schedule(
  p_child_id => (select value::uuid from t_state where key = 'child_a1_id'),
  p_title => 'Arrumar o quarto',
  p_coin_reward => 8,
  p_approval_mode => 'manual',
  p_late_policy => 'allow_late',
  p_schedule_type => 'once',
  p_one_time_date => current_date
);

select ok(
  (select value from t_state where key = 'task_manual_id') is not null,
  'upsert_task_with_schedule cria a tarefa manual de A1'
);

insert into t_state (key, value)
select 'task_third_id', task_id::text from public.upsert_task_with_schedule(
  p_child_id => (select value::uuid from t_state where key = 'child_a1_id'),
  p_title => 'Ler um livro',
  p_coin_reward => 3,
  p_approval_mode => 'automatic',
  p_late_policy => 'allow_late',
  p_schedule_type => 'once',
  p_one_time_date => current_date
);

select ok(
  (select value from t_state where key = 'task_third_id') is not null,
  'upsert_task_with_schedule cria a terceira tarefa de hoje de A1'
);

select throws_ok(
  $$ select * from public.upsert_task_with_schedule(
       p_child_id => (select value::uuid from t_state where key = 'child_a1_id'),
       p_title => 'Quarta tarefa de hoje',
       p_approval_mode => 'automatic',
       p_late_policy => 'allow_late',
       p_schedule_type => 'once',
       p_one_time_date => current_date
     ) $$,
  'PLAN_DAILY_TASK_LIMIT',
  'A quarta ocorrência do dia é bloqueada pelo limite do plano gratuito'
);

select results_eq(
  $$ select count(*)::int from public.task_occurrences
     where child_id = (select value::uuid from t_state where key = 'child_a1_id')
       and occurrence_date = current_date $$,
  $$ values (3) $$,
  'A tentativa bloqueada não apaga nem duplica as 3 ocorrências existentes'
);

insert into t_state (key, value)
select 'occ_auto_id', id::text from public.task_occurrences
where task_id = (select value::uuid from t_state where key = 'task_auto_id')
  and occurrence_date = current_date;

insert into t_state (key, value)
select 'occ_manual_id', id::text from public.task_occurrences
where task_id = (select value::uuid from t_state where key = 'task_manual_id')
  and occurrence_date = current_date;

-- ---------------------------------------------------------------------
-- 3) Fluxo automático: concluir credita na hora, de forma idempotente.
-- ---------------------------------------------------------------------
select pg_temp.act_as('child_a1_device_id');

select lives_ok(
  $$ select * from public.complete_task_occurrence(
       (select value::uuid from t_state where key = 'occ_auto_id'), 'idem-auto-1', 1, false
     ) $$,
  'A criança conclui a tarefa automática'
);

select results_eq(
  $$ select status from public.task_occurrences where id = (select value::uuid from t_state where key = 'occ_auto_id') $$,
  $$ values ('approved'::text) $$,
  'A ocorrência automática vira approved imediatamente'
);

select results_eq(
  $$ select count(*)::int from public.coin_ledger
     where source_id = (select value::uuid from t_state where key = 'occ_auto_id') $$,
  $$ values (1) $$,
  'Exatamente um lançamento de moedas para a ocorrência automática'
);

select lives_ok(
  $$ select * from public.complete_task_occurrence(
       (select value::uuid from t_state where key = 'occ_auto_id'), 'idem-auto-1', 1, false
     ) $$,
  'Repetir a mesma chamada (duplo-tap) não gera erro'
);

select results_eq(
  $$ select count(*)::int from public.coin_ledger
     where source_id = (select value::uuid from t_state where key = 'occ_auto_id') $$,
  $$ values (1) $$,
  'O duplo-tap com a mesma idempotency_key não duplica o crédito'
);

-- ---------------------------------------------------------------------
-- 4) Fluxo manual: enviar, rejeitar, corrigir, aprovar; segunda aprovação
--    simultânea não duplica o crédito.
-- ---------------------------------------------------------------------
select lives_ok(
  $$ select * from public.complete_task_occurrence(
       (select value::uuid from t_state where key = 'occ_manual_id'), 'idem-manual-1', 1, false
     ) $$,
  'A criança envia a tarefa manual para aprovação'
);

select pg_temp.act_as('a1_id');

select throws_ok(
  $$ select * from public.review_task_occurrence(
       (select value::uuid from t_state where key = 'occ_manual_id'), 'reject', 'idem-reject-empty', 2, null
     ) $$,
  'VALIDATION_ERROR',
  'Rejeitar sem motivo é bloqueado'
);

select lives_ok(
  $$ select * from public.review_task_occurrence(
       (select value::uuid from t_state where key = 'occ_manual_id'), 'reject', 'idem-reject-1', 2, 'Capriche mais'
     ) $$,
  'A1 rejeita com motivo'
);

select results_eq(
  $$ select status from public.task_occurrences where id = (select value::uuid from t_state where key = 'occ_manual_id') $$,
  $$ values ('needs_correction'::text) $$,
  'A ocorrência rejeitada vira needs_correction'
);

select pg_temp.act_as('child_a1_device_id');

select lives_ok(
  $$ select * from public.complete_task_occurrence(
       (select value::uuid from t_state where key = 'occ_manual_id'), 'idem-manual-2', 3, false
     ) $$,
  'A criança reenvia após a correção'
);

select pg_temp.act_as('a1_id');

select lives_ok(
  $$ select * from public.review_task_occurrence(
       (select value::uuid from t_state where key = 'occ_manual_id'), 'approve', 'idem-approve-1', 4, null
     ) $$,
  'A1 aprova a tarefa reenviada'
);

select pg_temp.act_as('a2_id');

select throws_ok(
  $$ select * from public.review_task_occurrence(
       (select value::uuid from t_state where key = 'occ_manual_id'), 'approve', 'idem-approve-2', 4, null
     ) $$,
  'ALREADY_PROCESSED',
  'A2 não consegue aprovar de novo uma ocorrência já aprovada por A1'
);

select results_eq(
  $$ select count(*)::int from public.coin_ledger
     where source_id = (select value::uuid from t_state where key = 'occ_manual_id') $$,
  $$ values (1) $$,
  'A dupla aprovação simultânea não duplica o crédito'
);

-- ---------------------------------------------------------------------
-- 5) Política de prazo na família B (dia isolado do limite de A).
-- ---------------------------------------------------------------------
select pg_temp.act_as('b1_id');

insert into t_state (key, value)
select 'task_b_allow_id', task_id::text from public.upsert_task_with_schedule(
  p_child_id => (select value::uuid from t_state where key = 'child_b1_id'),
  p_title => 'Tarefa com atraso permitido',
  p_coin_reward => 4,
  p_approval_mode => 'automatic',
  p_late_policy => 'allow_late',
  p_schedule_type => 'once',
  p_one_time_date => current_date
);

select ok(
  (select value from t_state where key = 'task_b_allow_id') is not null,
  'B1 cria a tarefa com allow_late'
);

insert into t_state (key, value)
select 'task_b_expire_id', task_id::text from public.upsert_task_with_schedule(
  p_child_id => (select value::uuid from t_state where key = 'child_b1_id'),
  p_title => 'Tarefa que expira',
  p_coin_reward => 4,
  p_approval_mode => 'automatic',
  p_late_policy => 'expire_no_reward',
  p_schedule_type => 'once',
  p_one_time_date => current_date
);

select ok(
  (select value from t_state where key = 'task_b_expire_id') is not null,
  'B1 cria a tarefa com expire_no_reward'
);

insert into t_state (key, value)
select 'occ_b_allow_id', id::text from public.task_occurrences
where task_id = (select value::uuid from t_state where key = 'task_b_allow_id');

insert into t_state (key, value)
select 'occ_b_expire_id', id::text from public.task_occurrences
where task_id = (select value::uuid from t_state where key = 'task_b_expire_id');

reset role;
reset request.jwt.claims;

update public.task_occurrences
set due_at = timezone('utc', now()) - interval '1 hour'
where id in (
  (select value::uuid from t_state where key = 'occ_b_allow_id'),
  (select value::uuid from t_state where key = 'occ_b_expire_id')
);

select lives_ok(
  $$ select public.expire_due_task_occurrences() $$,
  'O job de expiração roda sem erro'
);

select results_eq(
  $$ select status from public.task_occurrences where id = (select value::uuid from t_state where key = 'occ_b_allow_id') $$,
  $$ values ('late'::text) $$,
  'allow_late move a ocorrência vencida para late, ainda completável'
);

select results_eq(
  $$ select status from public.task_occurrences where id = (select value::uuid from t_state where key = 'occ_b_expire_id') $$,
  $$ values ('expired'::text) $$,
  'expire_no_reward move a ocorrência vencida para expired'
);

select pg_temp.act_as('b1_id');

select throws_ok(
  $$ select * from public.complete_task_occurrence(
       (select value::uuid from t_state where key = 'occ_b_expire_id'), 'idem-b-expire-1', 2, true
     ) $$,
  'TASK_EXPIRED',
  'Concluir uma ocorrência expirada é bloqueado'
);

select is_empty(
  $$ select 1 from public.coin_ledger
     where source_id = (select value::uuid from t_state where key = 'occ_b_expire_id') $$,
  'Nenhum crédito é concedido para a ocorrência expirada'
);

select lives_ok(
  $$ select * from public.complete_task_occurrence(
       (select value::uuid from t_state where key = 'occ_b_allow_id'), 'idem-b-late-1', 2, true
     ) $$,
  'B1 conclui em nome da criança uma ocorrência atrasada (allow_late)'
);

select results_eq(
  $$ select status from public.task_occurrences where id = (select value::uuid from t_state where key = 'occ_b_allow_id') $$,
  $$ values ('approved'::text) $$,
  'A ocorrência atrasada com allow_late ainda pode ser aprovada e recompensada'
);

-- ---------------------------------------------------------------------
-- 6) Pausar tarefa não apaga histórico nem gera novas ocorrências.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

select lives_ok(
  $$ select public.pause_task((select value::uuid from t_state where key = 'task_auto_id')) $$,
  'A1 pausa a tarefa automática'
);

select results_eq(
  $$ select is_active from public.tasks where id = (select value::uuid from t_state where key = 'task_auto_id') $$,
  $$ values (false) $$,
  'A tarefa pausada fica com is_active = false'
);

-- ---------------------------------------------------------------------
-- 7) Isolamento entre famílias via RLS.
-- ---------------------------------------------------------------------
select pg_temp.act_as('b1_id');

select is_empty(
  $$ select 1 from public.tasks where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  'B1 não enxerga tarefas da família A'
);

select is_empty(
  $$ select 1 from public.task_occurrences where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  'B1 não enxerga ocorrências da família A'
);

select is_empty(
  $$ select 1 from public.coin_ledger where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  'B1 não enxerga o ledger de moedas da família A'
);

select pg_temp.act_as('a1_id');

select is_empty(
  $$ select 1 from public.tasks where family_id = (select value::uuid from t_state where key = 'family_b_id') $$,
  'A1 não enxerga tarefas da família B'
);

-- ---------------------------------------------------------------------
-- 8) Privilégio mínimo.
-- ---------------------------------------------------------------------
select ok(
  not has_function_privilege('authenticated', 'public.generate_task_occurrences(uuid)', 'EXECUTE'),
  'authenticated não pode chamar generate_task_occurrences diretamente'
);

select ok(
  not has_function_privilege('authenticated', 'public.expire_due_task_occurrences()', 'EXECUTE'),
  'authenticated não pode chamar expire_due_task_occurrences diretamente'
);

select ok(
  not has_function_privilege('authenticated', 'public.grant_task_rewards(uuid)', 'EXECUTE'),
  'authenticated não pode chamar grant_task_rewards diretamente'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.upsert_task_with_schedule(uuid, uuid, text, text, text, text, text, boolean, boolean, boolean, integer, integer, text, text, integer, text, date, smallint[], date, date, time, time)',
    'EXECUTE'
  ),
  'authenticated pode chamar upsert_task_with_schedule'
);

select ok(
  has_function_privilege('authenticated', 'public.complete_task_occurrence(uuid, text, integer, boolean)', 'EXECUTE'),
  'authenticated pode chamar complete_task_occurrence'
);

select ok(
  has_function_privilege('authenticated', 'public.review_task_occurrence(uuid, text, text, integer, text)', 'EXECUTE'),
  'authenticated pode chamar review_task_occurrence'
);

select ok(
  has_function_privilege('authenticated', 'public.skip_task_occurrence(uuid, text, text)', 'EXECUTE'),
  'authenticated pode chamar skip_task_occurrence'
);

select * from finish();

rollback;
