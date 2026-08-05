-- Marco 7 (fatia 7) — testes do módulo "Notificações" do painel: RLS de
-- histórico, envio de aviso operacional (papel, validação, idempotência,
-- só ao responsável nunca à criança), auditoria, privilégio mínimo
-- (docs/12 seção 8).
begin;

select plan(13);

create temporary table t_state (key text primary key, value text);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a1@familia-a.test', '', now(), '{}', '{"display_name":"A1"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a2@familia-a.test', '', now(), '{}', '{"display_name":"A2"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-super@kidstask.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-billing@kidstask.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-support@kidstask.test', '', now(), '{}', '{}', now(), now());

insert into t_state (key, value)
select 'a1_id', id::text from auth.users where email = 'a1@familia-a.test'
union all select 'a2_id', id::text from auth.users where email = 'a2@familia-a.test'
union all select 'admin_super_id', id::text from auth.users where email = 'admin-super@kidstask.test'
union all select 'admin_billing_id', id::text from auth.users where email = 'admin-billing@kidstask.test'
union all select 'admin_support_id', id::text from auth.users where email = 'admin-support@kidstask.test';

insert into public.platform_admins (profile_id, role, active) values
  ((select value::uuid from t_state where key = 'admin_super_id'), 'super_admin', true),
  ((select value::uuid from t_state where key = 'admin_billing_id'), 'billing', true),
  ((select value::uuid from t_state where key = 'admin_support_id'), 'support', true);

create or replace function pg_temp.act_as(p_user_key text) returns void as $$
declare
  v_id text;
begin
  select value into v_id from t_state where key = p_user_key;
  perform set_config('request.jwt.claims', json_build_object('sub', v_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$ language plpgsql;

create or replace function pg_temp.act_as_mfa(p_user_key text) returns void as $$
declare
  v_id text;
begin
  select value into v_id from t_state where key = p_user_key;
  perform set_config('request.jwt.claims', json_build_object('sub', v_id, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  set local role authenticated;
end;
$$ language plpgsql;

-- ---------------------------------------------------------------------
-- Fixtures: família A com dois responsáveis e uma notificação existente.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'family_a_id', family_id::text from public.create_family('Familia A', 'America/Sao_Paulo', 'blue');

reset role;
reset request.jwt.claims;

insert into public.family_members (family_id, profile_id, role, status)
values (
  (select value::uuid from t_state where key = 'family_a_id'),
  (select value::uuid from t_state where key = 'a2_id'),
  'guardian', 'active'
);

insert into public.notifications (family_id, recipient_type, recipient_profile_id, event_type, title, body)
values (
  (select value::uuid from t_state where key = 'family_a_id'),
  'guardian', (select value::uuid from t_state where key = 'a1_id'),
  'task.occurrence_approved', 'Tarefa aprovada!', 'Escovar os dentes'
);

-- ---------------------------------------------------------------------
-- 1) RLS: histórico de notificações.
-- ---------------------------------------------------------------------
select pg_temp.act_as('admin_support_id');

select results_eq(
  $$ select title from public.notifications
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values ('Tarefa aprovada!'::text) $$,
  'support enxerga o histórico de notificações de qualquer família'
);

select pg_temp.act_as('admin_billing_id');

select is_empty(
  $$ select 1 from public.notifications
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  'billing não enxerga notificações (fora do papel permitido)'
);

-- ---------------------------------------------------------------------
-- 2) admin_send_operational_notice: validação e controle de acesso.
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select * from public.admin_send_operational_notice(
       (select value::uuid from t_state where key = 'family_a_id'),
       'Manutenção programada', 'O app ficará indisponível às 2h.', 'idem-billing-1'
     ) $$,
  'FORBIDDEN',
  'billing não pode enviar aviso operacional (só super_admin/support)'
);

select pg_temp.act_as_mfa('admin_support_id');

select throws_ok(
  $$ select * from public.admin_send_operational_notice(
       (select value::uuid from t_state where key = 'family_a_id'),
       '   ', 'corpo', 'idem-blank-title'
     ) $$,
  'VALIDATION_ERROR',
  'Título em branco é rejeitado'
);

select throws_ok(
  $$ select * from public.admin_send_operational_notice(
       (select value::uuid from t_state where key = 'family_a_id'),
       'título', 'corpo', '   '
     ) $$,
  'VALIDATION_ERROR',
  'idempotency_key em branco é rejeitada'
);

select throws_ok(
  $$ select * from public.admin_send_operational_notice(
       gen_random_uuid(), 'título', 'corpo', 'idem-family-not-found'
     ) $$,
  'VALIDATION_ERROR',
  'Família inexistente é rejeitada'
);

-- ---------------------------------------------------------------------
-- 3) Caminho feliz: notifica só os responsáveis, nunca a criança.
-- ---------------------------------------------------------------------
select results_eq(
  $$ select recipients_notified from public.admin_send_operational_notice(
       (select value::uuid from t_state where key = 'family_a_id'),
       'Manutenção programada', 'O app ficará indisponível às 2h.', 'idem-notice-1'
     ) $$,
  $$ values (2) $$,
  'support envia o aviso para os dois responsáveis ativos'
);

select results_eq(
  $$ select count(*)::int from public.notifications
     where family_id = (select value::uuid from t_state where key = 'family_a_id')
       and event_type = 'admin.operational_notice' $$,
  $$ values (2) $$,
  'Os dois responsáveis recebem a notificação interna'
);

select is_empty(
  $$ select 1 from public.notifications
     where event_type = 'admin.operational_notice' and recipient_type = 'child' $$,
  'Nenhuma criança recebe aviso operacional (nunca marketing/aviso direto à criança)'
);

select lives_ok(
  $$ select * from public.admin_send_operational_notice(
       (select value::uuid from t_state where key = 'family_a_id'),
       'Manutenção programada', 'O app ficará indisponível às 2h.', 'idem-notice-1'
     ) $$,
  'Reenviar a mesma idempotency_key não gera erro'
);

select results_eq(
  $$ select count(*)::int from public.notifications
     where family_id = (select value::uuid from t_state where key = 'family_a_id')
       and event_type = 'admin.operational_notice' $$,
  $$ values (2) $$,
  'O reenvio não duplica a notificação'
);

select results_eq(
  $$ select count(*)::int from public.audit_logs where action = 'admin.operational_notice_sent' $$,
  $$ values (1) $$,
  'O envio gera uma linha de auditoria'
);

-- ---------------------------------------------------------------------
-- 4) Privilégio mínimo.
-- ---------------------------------------------------------------------
select ok(
  has_function_privilege('authenticated', 'public.admin_send_operational_notice(uuid, text, text, text)', 'EXECUTE'),
  'authenticated pode chamar admin_send_operational_notice'
);

select * from finish();

rollback;
