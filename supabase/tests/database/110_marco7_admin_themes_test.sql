-- Marco 7 (fatia 5) — testes do módulo "Temas e conteúdo" do painel:
-- controle de acesso por papel, criação de rascunho, edição de manifest
-- (versionamento), publicação (validações), retirada, fila de
-- solicitações Premium e privilégio mínimo (docs/12 seção 6).
begin;

select plan(33);

create temporary table t_state (key text primary key, value text);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a1@familia-a.test', '', now(), '{}', '{"display_name":"A1"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-super@kidstask.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-billing@kidstask.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-support@kidstask.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-content@kidstask.test', '', now(), '{}', '{}', now(), now());

insert into t_state (key, value)
select 'a1_id', id::text from auth.users where email = 'a1@familia-a.test'
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
-- Fixtures: família A e uma solicitação de tema.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'family_a_id', family_id::text from public.create_family('Familia A', 'America/Sao_Paulo', 'blue');

insert into t_state (key, value)
select 'request_id', request_id::text from public.submit_theme_request(
  (select value::uuid from t_state where key = 'family_a_id'),
  'dinossauros', 'verde e marrom', 'algo com dinossauros', '8-10', true
);

-- ---------------------------------------------------------------------
-- 1) admin_list_themes: papel e catálogo seedado do Marco 5.
-- ---------------------------------------------------------------------
select pg_temp.act_as_mfa('admin_content_id');

select ok(
  (select count(*) from public.admin_list_themes()) >= 9,
  'content lista o catálogo inteiro (inclusive draft), pelo menos os 9 temas seedados no Marco 5'
);

select pg_temp.act_as('a1_id');

select throws_ok(
  $$ select * from public.admin_list_themes() $$,
  'FORBIDDEN',
  'Um responsável comum não pode listar o catálogo administrativo'
);

-- ---------------------------------------------------------------------
-- 2) admin_create_theme_draft: validação e controle de acesso.
-- ---------------------------------------------------------------------
select pg_temp.act_as_mfa('admin_support_id');

select throws_ok(
  $$ select * from public.admin_create_theme_draft('test_theme_1', 'Tema de Teste', 'free') $$,
  'FORBIDDEN',
  'support não pode criar rascunho de tema (só super_admin/content)'
);

select pg_temp.act_as_mfa('admin_content_id');

select throws_ok(
  $$ select * from public.admin_create_theme_draft('   ', 'Tema de Teste', 'free') $$,
  'VALIDATION_ERROR',
  'Slug em branco é rejeitado'
);

select throws_ok(
  $$ select * from public.admin_create_theme_draft('test_theme_1', 'Tema de Teste', 'ouro') $$,
  'VALIDATION_ERROR',
  'plan_tier inválido é rejeitado'
);

select throws_ok(
  $$ select * from public.admin_create_theme_draft('block_world', 'Duplicado', 'free') $$,
  'VALIDATION_ERROR',
  'Slug já existente é rejeitado'
);

select lives_ok(
  $$ insert into t_state (key, value)
     select 'theme_id', theme_id::text from public.admin_create_theme_draft('test_theme_1', 'Tema de Teste', 'free') $$,
  'content cria o rascunho com sucesso'
);

select results_eq(
  $$ select status, version from public.themes where id = (select value::uuid from t_state where key = 'theme_id') $$,
  $$ values ('draft'::text, 1) $$,
  'O rascunho nasce draft na versão 1'
);

select results_eq(
  $$ select count(*)::int from public.audit_logs where action = 'admin.theme_draft_created' $$,
  $$ values (1) $$,
  'Criar rascunho gera auditoria'
);

-- ---------------------------------------------------------------------
-- 3) admin_update_theme_manifest: versiona só quando já publicado.
-- ---------------------------------------------------------------------
select results_eq(
  $$ select status, version from public.admin_update_theme_manifest(
       (select value::uuid from t_state where key = 'theme_id'),
       '{"background_asset_key": "test_theme_1"}'::jsonb
     ) $$,
  $$ values ('draft'::text, 1) $$,
  'Editar manifest de um rascunho não altera a versão'
);

select throws_ok(
  $$ select * from public.admin_update_theme_manifest(gen_random_uuid(), '{}'::jsonb) $$,
  'VALIDATION_ERROR',
  'Editar manifest de tema inexistente é rejeitado'
);

-- ---------------------------------------------------------------------
-- 4) admin_publish_theme: validações e caminho feliz.
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select * from public.admin_publish_theme(
       (select value::uuid from t_state where key = 'theme_id'), false
     ) $$,
  'VALIDATION_ERROR',
  'Publicar sem confirmar revisão de PI é rejeitado'
);

select lives_ok(
  $$ select * from public.admin_publish_theme(
       (select value::uuid from t_state where key = 'theme_id'), true
     ) $$,
  'content publica o tema com sucesso'
);

select results_eq(
  $$ select status, version from public.themes where id = (select value::uuid from t_state where key = 'theme_id') $$,
  $$ values ('published'::text, 1) $$,
  'A primeira publicação não bump a versão (ainda era a v1 nunca publicada)'
);

select throws_ok(
  $$ select * from public.admin_publish_theme(
       (select value::uuid from t_state where key = 'theme_id'), true
     ) $$,
  'VALIDATION_ERROR',
  'Publicar um tema já publicado é rejeitado'
);

select results_eq(
  $$ select status, version from public.admin_update_theme_manifest(
       (select value::uuid from t_state where key = 'theme_id'),
       '{"background_asset_key": "test_theme_1_v2"}'::jsonb
     ) $$,
  $$ values ('published'::text, 2) $$,
  'Editar manifest de um tema publicado bump a versão'
);

-- Rascunho novo, sem asset key, não pode ser publicado.
select lives_ok(
  $$ insert into t_state (key, value)
     select 'theme_empty_id', theme_id::text from public.admin_create_theme_draft('test_theme_empty', 'Tema Vazio', 'free') $$,
  'content cria um segundo rascunho, sem asset key'
);

select throws_ok(
  $$ select * from public.admin_publish_theme(
       (select value::uuid from t_state where key = 'theme_empty_id'), true
     ) $$,
  'VALIDATION_ERROR',
  'Publicar sem background_asset_key no manifest é rejeitado'
);

-- ---------------------------------------------------------------------
-- 5) admin_retire_theme e reedição/republicação.
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select * from public.admin_retire_theme(
       (select value::uuid from t_state where key = 'theme_empty_id')
     ) $$,
  'VALIDATION_ERROR',
  'Só um tema publicado pode ser retirado'
);

select results_eq(
  $$ select status from public.admin_retire_theme(
       (select value::uuid from t_state where key = 'theme_id')
     ) $$,
  $$ values ('retired'::text) $$,
  'content retira o tema publicado'
);

select throws_ok(
  $$ select * from public.admin_update_theme_manifest(
       (select value::uuid from t_state where key = 'theme_id'), '{"background_asset_key": "x"}'::jsonb
     ) $$,
  'VALIDATION_ERROR',
  'Editar manifest de um tema retirado é rejeitado'
);

select results_eq(
  $$ select status, version from public.admin_publish_theme(
       (select value::uuid from t_state where key = 'theme_id'), true
     ) $$,
  $$ values ('published'::text, 3) $$,
  'Republicar um tema retirado bump a versão de novo'
);

-- ---------------------------------------------------------------------
-- 6) Fila de solicitações Premium de tema.
-- ---------------------------------------------------------------------
select results_eq(
  $$ select category, requested_by_email from public.admin_list_theme_requests()
     where request_id = (select value::uuid from t_state where key = 'request_id') $$,
  $$ values ('dinossauros'::text, 'a1@familia-a.test'::text) $$,
  'admin_list_theme_requests devolve categoria e e-mail de quem pediu'
);

select pg_temp.act_as_mfa('admin_support_id');

select throws_ok(
  $$ select * from public.admin_list_theme_requests() $$,
  'FORBIDDEN',
  'support não pode listar solicitações de tema (só super_admin/content)'
);

select pg_temp.act_as_mfa('admin_content_id');

select results_eq(
  $$ select status from public.admin_review_theme_request(
       (select value::uuid from t_state where key = 'request_id')
     ) $$,
  $$ values ('reviewed'::text) $$,
  'content marca a solicitação como revisada'
);

select throws_ok(
  $$ select * from public.admin_review_theme_request(
       (select value::uuid from t_state where key = 'request_id')
     ) $$,
  'VALIDATION_ERROR',
  'Revisar uma solicitação já revisada é rejeitado'
);

-- ---------------------------------------------------------------------
-- 7) Privilégio mínimo.
-- ---------------------------------------------------------------------
select ok(
  has_function_privilege('authenticated', 'public.admin_list_themes()', 'EXECUTE'),
  'authenticated pode chamar admin_list_themes'
);

select ok(
  has_function_privilege('authenticated', 'public.admin_create_theme_draft(text, text, text)', 'EXECUTE'),
  'authenticated pode chamar admin_create_theme_draft'
);

select ok(
  has_function_privilege('authenticated', 'public.admin_update_theme_manifest(uuid, jsonb)', 'EXECUTE'),
  'authenticated pode chamar admin_update_theme_manifest'
);

select ok(
  has_function_privilege('authenticated', 'public.admin_publish_theme(uuid, boolean)', 'EXECUTE'),
  'authenticated pode chamar admin_publish_theme'
);

select ok(
  has_function_privilege('authenticated', 'public.admin_retire_theme(uuid)', 'EXECUTE'),
  'authenticated pode chamar admin_retire_theme'
);

select ok(
  has_function_privilege('authenticated', 'public.admin_list_theme_requests()', 'EXECUTE'),
  'authenticated pode chamar admin_list_theme_requests'
);

select ok(
  has_function_privilege('authenticated', 'public.admin_review_theme_request(uuid)', 'EXECUTE'),
  'authenticated pode chamar admin_review_theme_request'
);

select * from finish();

rollback;
