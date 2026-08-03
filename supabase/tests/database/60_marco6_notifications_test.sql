-- Marco 6 — testes de emissão de notificação nos fluxos de tarefa,
-- resgate e progressão (docs/11_NOTIFICACOES.md), idempotência,
-- isolamento entre famílias e privilégio mínimo.
--
-- Mesmo padrão de fixture dos testes de Marco 1-5: Família A (A1 + A2
-- responsáveis, 1 criança free-plan) e Família B (B1, independente).
begin;

select plan(26);

create temporary table t_state (key text primary key, value text);

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
-- Fixtures de família/criança/aparelho.
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
-- 1) Tarefa manual: enviar notifica os dois responsáveis.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'task_manual_id', task_id::text from public.upsert_task_with_schedule(
  p_child_id => (select value::uuid from t_state where key = 'child_a1_id'),
  p_title => 'Arrumar o quarto',
  p_approval_mode => 'manual',
  p_late_policy => 'allow_late',
  p_schedule_type => 'once',
  p_one_time_date => current_date
);

insert into t_state (key, value)
select 'occ_manual_id', id::text from public.task_occurrences
where task_id = (select value::uuid from t_state where key = 'task_manual_id');

select pg_temp.act_as('child_a1_device_id');

select lives_ok(
  $$ select * from public.complete_task_occurrence(
       (select value::uuid from t_state where key = 'occ_manual_id'), 'idem-submit-1', 1, false
     ) $$,
  'A criança envia a tarefa manual para aprovação'
);

select results_eq(
  $$ select count(*)::int from public.notifications
     where event_type = 'task.occurrence_submitted'
       and recipient_type = 'guardian' $$,
  $$ values (2) $$,
  'Os dois responsáveis da família A recebem a notificação de envio'
);

select results_eq(
  $$ select count(distinct recipient_profile_id)::int from public.notifications
     where event_type = 'task.occurrence_submitted' $$,
  $$ values (2) $$,
  'As notificações vão para dois destinatários distintos (A1 e A2)'
);

-- ---------------------------------------------------------------------
-- 2) Aprovar notifica a criança; reprocessar não duplica.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

select lives_ok(
  $$ select * from public.review_task_occurrence(
       (select value::uuid from t_state where key = 'occ_manual_id'), 'approve', 'idem-approve-1', 2, null
     ) $$,
  'A1 aprova a tarefa'
);

select results_eq(
  $$ select count(*)::int from public.notifications
     where event_type = 'task.occurrence_approved'
       and recipient_type = 'child'
       and recipient_child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (1) $$,
  'A criança recebe exatamente uma notificação de aprovação'
);

select pg_temp.act_as('a2_id');

select throws_ok(
  $$ select * from public.review_task_occurrence(
       (select value::uuid from t_state where key = 'occ_manual_id'), 'approve', 'idem-approve-2', 2, null
     ) $$,
  'ALREADY_PROCESSED',
  'A2 não consegue reprocessar a mesma aprovação'
);

select results_eq(
  $$ select count(*)::int from public.notifications where event_type = 'task.occurrence_approved' $$,
  $$ values (1) $$,
  'A tentativa bloqueada não gera uma segunda notificação de aprovação'
);

-- ---------------------------------------------------------------------
-- 3) Rejeitar notifica a criança com o motivo.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'task_reject_id', task_id::text from public.upsert_task_with_schedule(
  p_child_id => (select value::uuid from t_state where key = 'child_a1_id'),
  p_title => 'Ler um livro',
  p_approval_mode => 'manual',
  p_late_policy => 'allow_late',
  p_schedule_type => 'once',
  p_one_time_date => current_date
);

insert into t_state (key, value)
select 'occ_reject_id', id::text from public.task_occurrences
where task_id = (select value::uuid from t_state where key = 'task_reject_id');

select pg_temp.act_as('child_a1_device_id');

select public.complete_task_occurrence(
  (select value::uuid from t_state where key = 'occ_reject_id'), 'idem-submit-2', 1, false
);

select pg_temp.act_as('a1_id');

select lives_ok(
  $$ select * from public.review_task_occurrence(
       (select value::uuid from t_state where key = 'occ_reject_id'), 'reject', 'idem-reject-1', 2,
       'Capriche mais'
     ) $$,
  'A1 rejeita a tarefa com motivo'
);

select results_eq(
  $$ select body from public.notifications
     where event_type = 'task.occurrence_rejected'
       and recipient_child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values ('Ler um livro'::text) $$,
  'A criança recebe a notificação de rejeição com o título da tarefa'
);

-- ---------------------------------------------------------------------
-- 4) Resgate: solicitar notifica os responsáveis; aprovar notifica a
--    criança.
-- ---------------------------------------------------------------------
with new_reward as (
  insert into public.rewards (family_id, title, cost_coins)
  values ((select value::uuid from t_state where key = 'family_a_id'), 'Passeio ao parque', 5)
  returning id
)
insert into t_state (key, value)
select 'reward_id', id::text from new_reward;

select pg_temp.act_as('child_a1_device_id');

insert into t_state (key, value)
select 'redemption_id', redemption_id::text from public.request_redemption(
  (select value::uuid from t_state where key = 'reward_id'), 'idem-request-1'
);

select results_eq(
  $$ select count(*)::int from public.notifications where event_type = 'redemption.requested' $$,
  $$ values (2) $$,
  'Os dois responsáveis recebem a notificação de pedido de resgate'
);

select pg_temp.act_as('a1_id');

select lives_ok(
  $$ select * from public.review_redemption(
       (select value::uuid from t_state where key = 'redemption_id'), 'approve', 'idem-review-1', 1, null
     ) $$,
  'A1 aprova o resgate'
);

select results_eq(
  $$ select count(*)::int from public.notifications
     where event_type = 'redemption.approved'
       and recipient_child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (1) $$,
  'A criança recebe a notificação de resgate aprovado'
);

-- ---------------------------------------------------------------------
-- 5) Subida de nível notifica a criança.
-- ---------------------------------------------------------------------
reset role;
reset request.jwt.claims;

update public.child_wallets set total_xp = 250
where child_id = (select value::uuid from t_state where key = 'child_a1_id');

select lives_ok(
  $$ select public.process_level_changes((select value::uuid from t_state where key = 'child_a1_id')) $$,
  'process_level_changes credita o nível 2'
);

select results_eq(
  $$ select count(*)::int from public.notifications
     where event_type = 'progress.level_up'
       and recipient_child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (1) $$,
  'A criança recebe a notificação de subida de nível'
);

-- ---------------------------------------------------------------------
-- 6) Registro de token de aparelho.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

select lives_ok(
  $$ select * from public.register_device_token('android', 'token-a1-device-1', 'pt-BR') $$,
  'A1 registra um token de push'
);

select lives_ok(
  $$ select * from public.register_device_token('android', 'token-a1-device-1', 'pt-BR') $$,
  'Registrar o mesmo token de novo não gera erro (upsert)'
);

select results_eq(
  $$ select count(*)::int from public.device_tokens where fcm_token = 'token-a1-device-1' $$,
  $$ values (1) $$,
  'O reenvio do mesmo token não duplica a linha'
);

-- ---------------------------------------------------------------------
-- 7) Marcar notificação como lida; papel errado é bloqueado.
-- ---------------------------------------------------------------------
insert into t_state (key, value)
select 'notification_a1_id', id::text from public.notifications
where event_type = 'task.occurrence_submitted' and recipient_profile_id = (select value::uuid from t_state where key = 'a1_id')
limit 1;

select lives_ok(
  $$ select public.mark_notification_read(
       (select value::uuid from t_state where key = 'notification_a1_id')
     ) $$,
  'A1 marca a própria notificação como lida'
);

select results_eq(
  $$ select (read_at is not null) from public.notifications
     where id = (select value::uuid from t_state where key = 'notification_a1_id') $$,
  $$ values (true) $$,
  'read_at é preenchido'
);

select pg_temp.act_as('child_a1_device_id');

select throws_ok(
  $$ select public.mark_notification_read(
       (select value::uuid from t_state where key = 'notification_a1_id')
     ) $$,
  'FORBIDDEN',
  'A criança não pode marcar como lida uma notificação do responsável'
);

-- ---------------------------------------------------------------------
-- 8) Isolamento entre famílias via RLS.
-- ---------------------------------------------------------------------
select pg_temp.act_as('b1_id');

select is_empty(
  $$ select 1 from public.notifications
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  'B1 não enxerga notificações da família A'
);

select is_empty(
  $$ select 1 from public.device_tokens
     where auth_user_id = (select value::uuid from t_state where key = 'a1_id') $$,
  'B1 não enxerga o token de aparelho de A1'
);

-- ---------------------------------------------------------------------
-- 9) Privilégio mínimo.
-- ---------------------------------------------------------------------
select ok(
  has_function_privilege('authenticated', 'public.register_device_token(text, text, text)', 'EXECUTE'),
  'authenticated pode chamar register_device_token'
);

select ok(
  has_function_privilege('authenticated', 'public.deactivate_device_token(uuid)', 'EXECUTE'),
  'authenticated pode chamar deactivate_device_token'
);

select ok(
  has_function_privilege('authenticated', 'public.mark_notification_read(uuid)', 'EXECUTE'),
  'authenticated pode chamar mark_notification_read'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.emit_notification(uuid, text, text, uuid, text, uuid, uuid, text, text, jsonb, text, text)',
    'EXECUTE'
  ),
  'authenticated não pode chamar emit_notification diretamente'
);

select * from finish();

rollback;
