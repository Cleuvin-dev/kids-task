-- Marco 7 (fatia 2) — testes da fundação do painel Web: isolamento de
-- platform_admins, MFA obrigatório reforçado em record_admin_audit_log
-- (docs/12 seções 2 e 10, docs/10 seção 7) e privilégio mínimo.
--
-- Fixtures: dois administradores da família Kid's Task (admin1 super_admin
-- ativo, admin2 support ativo, admin3 support inativo) e um responsável
-- comum (guardian1) que nunca deveria conseguir agir como administrador.
begin;

select plan(13);

create temporary table t_state (key text primary key, value text);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin1@kidstask.test', '', now(), '{}', '{"display_name":"Admin Super"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin2@kidstask.test', '', now(), '{}', '{"display_name":"Admin Suporte"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin3@kidstask.test', '', now(), '{}', '{"display_name":"Admin Inativo"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'guardian1@familia.test', '', now(), '{}', '{"display_name":"Guardian"}', now(), now());

insert into t_state (key, value)
select 'admin1_id', id::text from auth.users where email = 'admin1@kidstask.test'
union all select 'admin2_id', id::text from auth.users where email = 'admin2@kidstask.test'
union all select 'admin3_id', id::text from auth.users where email = 'admin3@kidstask.test'
union all select 'guardian1_id', id::text from auth.users where email = 'guardian1@familia.test';

insert into public.platform_admins (profile_id, role, active) values
  ((select value::uuid from t_state where key = 'admin1_id'), 'super_admin', true),
  ((select value::uuid from t_state where key = 'admin2_id'), 'support', true),
  ((select value::uuid from t_state where key = 'admin3_id'), 'support', false);

-- request.jwt.claims sem 'aal' simula uma sessão que ainda não verificou o
-- segundo fator (aal1, o padrão do próprio Supabase Auth).
create or replace function pg_temp.act_as(p_user_key text) returns void as $$
declare
  v_id text;
begin
  select value into v_id from t_state where key = p_user_key;
  perform set_config('request.jwt.claims', json_build_object('sub', v_id, 'role', 'authenticated')::text, true);
  set local role authenticated;
end;
$$ language plpgsql;

-- Sessão com o segundo fator já verificado (aal2) — só depois disso o
-- painel deveria deixar qualquer ação auditável acontecer.
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
-- 1) MFA verificado (aal2) + administrador ativo grava auditoria.
-- ---------------------------------------------------------------------
select pg_temp.act_as_mfa('admin1_id');

select lives_ok(
  $$ select public.record_admin_audit_log('admin.mfa_verified', 'platform_admin', (select value from t_state where key = 'admin1_id'), 'success', '{}'::jsonb) $$,
  'Super admin com aal2 registra o próprio login de MFA'
);

select results_eq(
  $$ select actor_role from public.audit_logs
     where actor_profile_id = (select value::uuid from t_state where key = 'admin1_id') $$,
  $$ values ('super_admin'::text) $$,
  'A auditoria grava o papel do administrador no momento da ação'
);

-- ---------------------------------------------------------------------
-- 2) Bloqueios: não-admin, sem aal2, admin inativo.
-- ---------------------------------------------------------------------
select pg_temp.act_as_mfa('guardian1_id');

select throws_ok(
  $$ select public.record_admin_audit_log('admin.mfa_verified', 'platform_admin', null, 'success', '{}'::jsonb) $$,
  'FORBIDDEN',
  'Um responsável comum (não administrador) não consegue gravar auditoria mesmo com aal2'
);

select pg_temp.act_as('admin1_id');

select throws_ok(
  $$ select public.record_admin_audit_log('admin.mfa_verified', 'platform_admin', null, 'success', '{}'::jsonb) $$,
  'FORBIDDEN',
  'Administrador sem o segundo fator verificado (aal1) é bloqueado'
);

select pg_temp.act_as_mfa('admin3_id');

select throws_ok(
  $$ select public.record_admin_audit_log('admin.mfa_verified', 'platform_admin', null, 'success', '{}'::jsonb) $$,
  'FORBIDDEN',
  'Administrador inativo é bloqueado mesmo com aal2'
);

-- ---------------------------------------------------------------------
-- 3) Segundo administrador ativo também consegue gravar.
-- ---------------------------------------------------------------------
select pg_temp.act_as_mfa('admin2_id');

select lives_ok(
  $$ select public.record_admin_audit_log('admin.mfa_verified', 'platform_admin', (select value from t_state where key = 'admin2_id'), 'success', '{}'::jsonb) $$,
  'Admin de suporte com aal2 registra o próprio login de MFA'
);

select results_eq(
  $$ select count(*)::int from public.audit_logs $$,
  $$ values (2) $$,
  'Só as duas tentativas válidas (admin1 e admin2) geraram linha de auditoria'
);

-- ---------------------------------------------------------------------
-- 4) RLS de audit_logs: super_admin vê tudo; outro papel só vê o próprio.
-- ---------------------------------------------------------------------
select pg_temp.act_as('admin1_id');

select results_eq(
  $$ select count(*)::int from public.audit_logs $$,
  $$ values (2) $$,
  'super_admin enxerga a auditoria de qualquer administrador'
);

select pg_temp.act_as('admin2_id');

select results_eq(
  $$ select count(*)::int from public.audit_logs $$,
  $$ values (1) $$,
  'Um admin de suporte só enxerga a própria auditoria'
);

select is_empty(
  $$ select 1 from public.audit_logs
     where actor_profile_id = (select value::uuid from t_state where key = 'admin1_id') $$,
  'Admin de suporte não enxerga a auditoria de outro administrador'
);

-- ---------------------------------------------------------------------
-- 5) RLS de platform_admins: só a própria linha.
-- ---------------------------------------------------------------------
select results_eq(
  $$ select role from public.platform_admins
     where profile_id = (select value::uuid from t_state where key = 'admin2_id') $$,
  $$ values ('support'::text) $$,
  'Admin de suporte enxerga o próprio papel'
);

select is_empty(
  $$ select 1 from public.platform_admins
     where profile_id = (select value::uuid from t_state where key = 'admin1_id') $$,
  'Admin de suporte não enxerga a linha de outro administrador'
);

-- ---------------------------------------------------------------------
-- 6) Privilégio mínimo.
-- ---------------------------------------------------------------------
select ok(
  has_function_privilege('authenticated', 'public.record_admin_audit_log(text, text, text, text, jsonb)', 'EXECUTE'),
  'authenticated pode chamar record_admin_audit_log'
);

select * from finish();

rollback;
