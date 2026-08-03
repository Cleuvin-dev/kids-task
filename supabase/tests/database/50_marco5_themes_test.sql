-- Marco 5 — testes de aplicação de tema (entitlement por plano, tema não
-- publicado bloqueado), solicitação de tema (consentimento obrigatório) e
-- isolamento entre famílias — docs/15_CRITERIOS_DE_ACEITE_E_TESTES.md
-- seção 10, docs/06_TEMAS_DESIGN_E_FAIXAS_ETARIAS.md.
--
-- Mesmo padrão de fixture dos testes de Marco 1-4: Família A (A1
-- responsável, 1 criança free-plan) e Família B (B1, independente).
begin;

select plan(17);

create temporary table t_state (key text primary key, value text);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a1@familia-a.test', '', now(), '{}', '{"display_name":"A1"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'b1@familia-b.test', '', now(), '{}', '{"display_name":"B1"}', now(), now());

insert into t_state (key, value)
select 'a1_id', id::text from auth.users where email = 'a1@familia-a.test'
union all select 'b1_id', id::text from auth.users where email = 'b1@familia-b.test';

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
-- Fixtures de família/criança.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'family_a_id', family_id::text from public.create_family('Familia A', 'America/Sao_Paulo', 'blue');

insert into t_state (key, value)
select 'child_a1_id', child_id::text from public.create_child(
  (select value::uuid from t_state where key = 'family_a_id'),
  'Crianca A1', '2016-05-10'
);

select pg_temp.act_as('b1_id');

insert into t_state (key, value)
select 'family_b_id', family_id::text from public.create_family('Familia B');

-- ---------------------------------------------------------------------
-- 1) Catálogo: só temas publicados são visíveis.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

select results_eq(
  $$ select slug from public.themes where slug = 'block_world' $$,
  $$ values ('block_world'::text) $$,
  'Tema publicado (gratuito) aparece no catálogo'
);

select is_empty(
  $$ select 1 from public.themes where slug = 'enchanted_world' $$,
  'Tema ainda não publicado (draft) não aparece para o cliente'
);

-- ---------------------------------------------------------------------
-- 2) Aplicar tema gratuito publicado.
-- ---------------------------------------------------------------------
select lives_ok(
  $$ select public.apply_child_theme(
       (select value::uuid from t_state where key = 'child_a1_id'), 'block_world'
     ) $$,
  'A1 aplica o tema gratuito Mundo dos Blocos'
);

select results_eq(
  $$ select theme_slug from public.child_profiles
     where id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values ('block_world'::text) $$,
  'theme_slug da criança é atualizado'
);

-- ---------------------------------------------------------------------
-- 3) Tema Premium bloqueado no plano gratuito.
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select public.apply_child_theme(
       (select value::uuid from t_state where key = 'child_a1_id'), 'space_adventure'
     ) $$,
  'THEME_NOT_ENTITLED',
  'Tema Premium é bloqueado para família no plano gratuito'
);

select results_eq(
  $$ select theme_slug from public.child_profiles
     where id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values ('block_world'::text) $$,
  'Tentativa bloqueada não altera o tema atual'
);

-- ---------------------------------------------------------------------
-- 4) Tema inexistente ou não publicado.
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select public.apply_child_theme(
       (select value::uuid from t_state where key = 'child_a1_id'), 'enchanted_world'
     ) $$,
  'VALIDATION_ERROR',
  'Tema ainda não publicado (draft) não pode ser aplicado'
);

select throws_ok(
  $$ select public.apply_child_theme(
       (select value::uuid from t_state where key = 'child_a1_id'), 'does_not_exist'
     ) $$,
  'VALIDATION_ERROR',
  'Slug de tema inexistente é rejeitado'
);

-- ---------------------------------------------------------------------
-- 5) Após upgrade de plano, o tema Premium fica disponível.
-- ---------------------------------------------------------------------
reset role;
reset request.jwt.claims;

update public.families
set plan_id = (select id from public.plans where code = 'premium')
where id = (select value::uuid from t_state where key = 'family_a_id');

select pg_temp.act_as('a1_id');

select lives_ok(
  $$ select public.apply_child_theme(
       (select value::uuid from t_state where key = 'child_a1_id'), 'space_adventure'
     ) $$,
  'Depois do upgrade para Premium, o tema fica disponível'
);

select results_eq(
  $$ select theme_slug from public.child_profiles
     where id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values ('space_adventure'::text) $$,
  'theme_slug reflete o novo tema Premium'
);

-- ---------------------------------------------------------------------
-- 6) B1 não pode aplicar tema numa criança de outra família.
-- ---------------------------------------------------------------------
select pg_temp.act_as('b1_id');

select throws_ok(
  $$ select public.apply_child_theme(
       (select value::uuid from t_state where key = 'child_a1_id'), 'block_world'
     ) $$,
  'FORBIDDEN',
  'B1 não pode alterar o tema de uma criança da família A'
);

-- ---------------------------------------------------------------------
-- 7) Solicitação de tema: consentimento obrigatório.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

select throws_ok(
  $$ select * from public.submit_theme_request(
       (select value::uuid from t_state where key = 'family_a_id'),
       'Fantasia rosa', 'Rosa e dourado', 'Tema de fadas', '8-10', false
     ) $$,
  'VALIDATION_ERROR',
  'Solicitação sem consentimento é bloqueada'
);

select lives_ok(
  $$ select * from public.submit_theme_request(
       (select value::uuid from t_state where key = 'family_a_id'),
       'Fantasia rosa', 'Rosa e dourado', 'Tema de fadas', '8-10', true
     ) $$,
  'Solicitação com consentimento é aceita'
);

select results_eq(
  $$ select count(*)::int from public.theme_requests
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values (1) $$,
  'Um pedido de tema registrado para a família A'
);

-- ---------------------------------------------------------------------
-- 8) Isolamento entre famílias via RLS.
-- ---------------------------------------------------------------------
select pg_temp.act_as('b1_id');

select is_empty(
  $$ select 1 from public.theme_requests
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  'B1 não enxerga a solicitação de tema da família A'
);

-- ---------------------------------------------------------------------
-- 9) Privilégio mínimo.
-- ---------------------------------------------------------------------
select ok(
  has_function_privilege('authenticated', 'public.apply_child_theme(uuid, text)', 'EXECUTE'),
  'authenticated pode chamar apply_child_theme'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.submit_theme_request(uuid, text, text, text, text, boolean)',
    'EXECUTE'
  ),
  'authenticated pode chamar submit_theme_request'
);

select * from finish();

rollback;
