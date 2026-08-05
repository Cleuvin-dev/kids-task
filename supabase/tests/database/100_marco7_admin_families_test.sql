-- Marco 7 (fatia 4) — testes do módulo "Famílias e usuários" do painel:
-- RLS admin de aparelhos/consentimentos, ocultação/revelação de
-- identidade infantil, admin_set_family_status (validação, idempotência,
-- revogação de aparelhos, notificação, auditoria) e privilégio mínimo
-- (docs/12 seções 4 e 11).
begin;

select plan(32);

create temporary table t_state (key text primary key, value text);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a1@familia-a.test', '', now(), '{}', '{"display_name":"A1"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a2@familia-a.test', '', now(), '{}', '{"display_name":"A2"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-super@kidstask.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-billing@kidstask.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-support@kidstask.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-content@kidstask.test', '', now(), '{}', '{}', now(), now());

insert into t_state (key, value)
select 'a1_id', id::text from auth.users where email = 'a1@familia-a.test'
union all select 'a2_id', id::text from auth.users where email = 'a2@familia-a.test'
union all select 'admin_super_id', id::text from auth.users where email = 'admin-super@kidstask.test'
union all select 'admin_billing_id', id::text from auth.users where email = 'admin-billing@kidstask.test'
union all select 'admin_support_id', id::text from auth.users where email = 'admin-support@kidstask.test'
union all select 'admin_content_id', id::text from auth.users where email = 'admin-content@kidstask.test';

insert into public.platform_admins (profile_id, role, active) values
  ((select value::uuid from t_state where key = 'admin_super_id'), 'super_admin', true),
  ((select value::uuid from t_state where key = 'admin_billing_id'), 'billing', true),
  ((select value::uuid from t_state where key = 'admin_support_id'), 'support', true),
  ((select value::uuid from t_state where key = 'admin_content_id'), 'content', true);

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
-- Fixtures: família A com dois responsáveis (a1 dono, a2 convidado
-- inserido direto — bypass de RLS, ainda como postgres/superuser) e uma
-- criança.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'family_a_id', family_id::text from public.create_family('Familia A', 'America/Sao_Paulo', 'blue');

-- Nascimento calculado relativo a hoje (9 anos), longe das bordas de
-- age_mode (7/10), para o teste não depender da data em que roda.
insert into t_state (key, value)
select 'child_a_id', child_id::text from public.create_child(
  (select value::uuid from t_state where key = 'family_a_id'), 'Joana', (current_date - interval '9 years')::date
);

insert into public.child_device_bindings (child_id, auth_user_id, device_name)
select (select value::uuid from t_state where key = 'child_a_id'), gen_random_uuid(), 'Tablet da Joana';

reset role;
reset request.jwt.claims;

insert into public.family_members (family_id, profile_id, role, status)
values (
  (select value::uuid from t_state where key = 'family_a_id'),
  (select value::uuid from t_state where key = 'a2_id'),
  'guardian', 'active'
);

insert into public.consent_records (family_id, guardian_profile_id, document, document_version, purpose)
values (
  (select value::uuid from t_state where key = 'family_a_id'),
  (select value::uuid from t_state where key = 'a1_id'),
  'terms_of_service', 'v1', 'terms_of_service'
);

-- ---------------------------------------------------------------------
-- 1) RLS admin: child_device_bindings / consent_records.
-- ---------------------------------------------------------------------
select pg_temp.act_as('admin_support_id');

select results_eq(
  $$ select device_name from public.child_device_bindings
     where child_id = (select value::uuid from t_state where key = 'child_a_id') $$,
  $$ values ('Tablet da Joana'::text) $$,
  'support enxerga aparelhos de qualquer família (child_device_bindings_select_admin)'
);

select pg_temp.act_as('admin_billing_id');

select is_empty(
  $$ select 1 from public.child_device_bindings
     where child_id = (select value::uuid from t_state where key = 'child_a_id') $$,
  'billing não enxerga aparelhos (fora do papel permitido)'
);

select pg_temp.act_as('admin_support_id');

select results_eq(
  $$ select document from public.consent_records
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values ('terms_of_service'::text) $$,
  'support enxerga consentimentos de qualquer família (consent_records_select_admin)'
);

select pg_temp.act_as('admin_content_id');

select is_empty(
  $$ select 1 from public.consent_records
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  'content não enxerga consentimentos (fora do papel permitido)'
);

-- ---------------------------------------------------------------------
-- 2) admin_list_family_children: nunca devolve identidade.
-- ---------------------------------------------------------------------
select pg_temp.act_as('admin_super_id');

select results_eq(
  $$ select status, age_mode from public.admin_list_family_children(
       (select value::uuid from t_state where key = 'family_a_id')
     ) $$,
  $$ values ('active'::text, 'middle'::text) $$,
  'admin_list_family_children devolve status/age_mode, sem nome'
);

select pg_temp.act_as('admin_billing_id');

select lives_ok(
  $$ select * from public.admin_list_family_children(
       (select value::uuid from t_state where key = 'family_a_id')
     ) $$,
  'billing também pode listar crianças (mesmo papel de families_select_admin)'
);

select pg_temp.act_as('admin_content_id');

select throws_ok(
  $$ select * from public.admin_list_family_children(
       (select value::uuid from t_state where key = 'family_a_id')
     ) $$,
  'FORBIDDEN',
  'content não pode listar crianças'
);

select pg_temp.act_as('a1_id');

select throws_ok(
  $$ select * from public.admin_list_family_children(
       (select value::uuid from t_state where key = 'family_a_id')
     ) $$,
  'FORBIDDEN',
  'Um responsável comum não pode chamar admin_list_family_children'
);

-- ---------------------------------------------------------------------
-- 3) admin_reveal_child_identity: exige aal2, papel e justificativa.
-- ---------------------------------------------------------------------
select pg_temp.act_as('admin_billing_id');

select throws_ok(
  $$ select * from public.admin_reveal_child_identity(
       (select value::uuid from t_state where key = 'child_a_id'), 'ticket #1'
     ) $$,
  'FORBIDDEN',
  'billing não pode revelar identidade infantil (só super_admin/support)'
);

select pg_temp.act_as_mfa('admin_support_id');

select throws_ok(
  $$ select * from public.admin_reveal_child_identity(
       (select value::uuid from t_state where key = 'child_a_id'), '   '
     ) $$,
  'VALIDATION_ERROR',
  'Justificativa em branco é rejeitada'
);

select results_eq(
  $$ select first_name from public.admin_reveal_child_identity(
       (select value::uuid from t_state where key = 'child_a_id'), 'Ticket #456: verificar idade'
     ) $$,
  $$ values ('Joana'::text) $$,
  'support com aal2 e justificativa revela o nome da criança'
);

select results_eq(
  $$ select count(*)::int from public.audit_logs
     where action = 'admin.child_identity_revealed'
       and actor_profile_id = (select value::uuid from t_state where key = 'admin_support_id') $$,
  $$ values (1) $$,
  'A revelação de identidade gera uma linha de auditoria'
);

select pg_temp.act_as('admin_support_id');

select throws_ok(
  $$ select * from public.admin_reveal_child_identity(
       (select value::uuid from t_state where key = 'child_a_id'), 'sem segundo fator'
     ) $$,
  'FORBIDDEN',
  'Sem aal2, record_admin_audit_log rejeita e a revelação falha inteira'
);

-- ---------------------------------------------------------------------
-- 4) admin_set_family_status: controle de acesso e validação.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

select throws_ok(
  $$ select * from public.admin_set_family_status(
       (select value::uuid from t_state where key = 'family_a_id'), 'blocked', 'motivo', 'idem-guardian-1'
     ) $$,
  'FORBIDDEN',
  'Um responsável comum não pode alterar o status da própria família'
);

select pg_temp.act_as_mfa('admin_billing_id');

select throws_ok(
  $$ select * from public.admin_set_family_status(
       (select value::uuid from t_state where key = 'family_a_id'), 'blocked', 'motivo', 'idem-billing-1'
     ) $$,
  'FORBIDDEN',
  'billing não pode alterar status de família (só super_admin/support)'
);

select pg_temp.act_as_mfa('admin_support_id');

select throws_ok(
  $$ select * from public.admin_set_family_status(
       (select value::uuid from t_state where key = 'family_a_id'), 'blocked', '   ', 'idem-blank-reason'
     ) $$,
  'VALIDATION_ERROR',
  'Motivo em branco é rejeitado'
);

select throws_ok(
  $$ select * from public.admin_set_family_status(
       (select value::uuid from t_state where key = 'family_a_id'), 'not_a_status', 'motivo', 'idem-bad-status'
     ) $$,
  'VALIDATION_ERROR',
  'Status inválido é rejeitado'
);

select throws_ok(
  $$ select * from public.admin_set_family_status(
       (select value::uuid from t_state where key = 'family_a_id'), 'active', 'motivo', 'idem-noop-status'
     ) $$,
  'VALIDATION_ERROR',
  'Definir o mesmo status já vigente é rejeitado'
);

-- ---------------------------------------------------------------------
-- 5) admin_set_family_status: caminho feliz (bloquear), efeitos colaterais
-- e idempotência.
-- ---------------------------------------------------------------------
select results_eq(
  $$ select status from public.admin_set_family_status(
       (select value::uuid from t_state where key = 'family_a_id'), 'blocked',
       'Atividade suspeita reportada, ticket #789', 'idem-block-1'
     ) $$,
  $$ values ('blocked'::text) $$,
  'support bloqueia a família A com sucesso'
);

select results_eq(
  $$ select status from public.families where id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values ('blocked'::text) $$,
  'families.status reflete o bloqueio'
);

select results_eq(
  $$ select count(*)::int from public.child_device_bindings
     where child_id = (select value::uuid from t_state where key = 'child_a_id')
       and revoked_at is not null $$,
  $$ values (1) $$,
  'Bloquear a família revoga o aparelho vinculado à criança'
);

select results_eq(
  $$ select count(*)::int from public.notifications
     where family_id = (select value::uuid from t_state where key = 'family_a_id')
       and event_type = 'family.status_changed' $$,
  $$ values (2) $$,
  'Os dois responsáveis ativos são notificados do bloqueio'
);

select results_eq(
  $$ select previous_status, new_status from public.family_status_events
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values ('active'::text, 'blocked'::text) $$,
  'family_status_events registra a transição'
);

select results_eq(
  $$ select count(*)::int from public.audit_logs where action = 'admin.family_status_changed' $$,
  $$ values (1) $$,
  'O bloqueio gera uma linha de auditoria'
);

select lives_ok(
  $$ select * from public.admin_set_family_status(
       (select value::uuid from t_state where key = 'family_a_id'), 'blocked', 'motivo repetido', 'idem-block-1'
     ) $$,
  'Reenviar a mesma idempotency_key não gera erro'
);

select results_eq(
  $$ select count(*)::int from public.family_status_events
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values (1) $$,
  'O reenvio não duplica o evento de mudança de status'
);

-- ---------------------------------------------------------------------
-- 6) Reativar não restaura aparelhos automaticamente nem notifica de novo.
-- ---------------------------------------------------------------------
select results_eq(
  $$ select status from public.admin_set_family_status(
       (select value::uuid from t_state where key = 'family_a_id'), 'active',
       'Ticket #789 resolvido', 'idem-reactivate-1'
     ) $$,
  $$ values ('active'::text) $$,
  'support reativa a família A'
);

select results_eq(
  $$ select count(*)::int from public.child_device_bindings
     where child_id = (select value::uuid from t_state where key = 'child_a_id')
       and revoked_at is null $$,
  $$ values (0) $$,
  'Reativar não restaura o aparelho revogado automaticamente'
);

select results_eq(
  $$ select count(*)::int from public.notifications
     where family_id = (select value::uuid from t_state where key = 'family_a_id')
       and payload ->> 'new_status' = 'active' $$,
  $$ values (0) $$,
  'Reativar não gera notificação (só transições que não voltam a active)'
);

-- ---------------------------------------------------------------------
-- 7) Privilégio mínimo.
-- ---------------------------------------------------------------------
select ok(
  has_function_privilege('authenticated', 'public.admin_list_family_children(uuid)', 'EXECUTE'),
  'authenticated pode chamar admin_list_family_children'
);

select ok(
  has_function_privilege('authenticated', 'public.admin_reveal_child_identity(uuid, text)', 'EXECUTE'),
  'authenticated pode chamar admin_reveal_child_identity'
);

select ok(
  has_function_privilege('authenticated', 'public.admin_set_family_status(uuid, text, text, text)', 'EXECUTE'),
  'authenticated pode chamar admin_set_family_status'
);

select * from finish();

rollback;
