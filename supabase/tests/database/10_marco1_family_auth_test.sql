-- Marco 1 — testes de isolamento entre famílias, limite do plano gratuito e
-- privilégio mínimo de funções (docs/15_CRITERIOS_DE_ACEITE_E_TESTES.md,
-- seção 16: fixtures com Família A [A1, A2, criança] e Família B [B1, criança]).
begin;

select plan(17);

-- Tabela temporária só para carregar estado entre os passos deste teste
-- (ids/códigos gerados dinamicamente pelas próprias funções sob teste).
create temporary table t_state (key text primary key, value text);

-- ---------------------------------------------------------------------
-- Fixtures de auth.users (schema local do GoTrue, já presente no stack de
-- teste do `supabase test db`).
-- ---------------------------------------------------------------------
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a1@familia-a.test', '', now(), '{}', '{"display_name":"A1"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a2@familia-a.test', '', now(), '{}', '{"display_name":"A2"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'b1@familia-b.test', '', now(), '{}', '{"display_name":"B1"}', now(), now());

insert into t_state (key, value)
select 'a1_id', id::text from auth.users where email = 'a1@familia-a.test'
union all select 'a2_id', id::text from auth.users where email = 'a2@familia-a.test'
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
-- 1) A1 cria a família A.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'family_a_id', family_id::text from public.create_family('Familia A', 'America/Sao_Paulo', 'blue');

select ok(
  (select value from t_state where key = 'family_a_id') is not null,
  'create_family retorna um id de família para A1'
);

select results_eq(
  $$ select role::text from public.family_members
     where family_id = (select value::uuid from t_state where key = 'family_a_id')
       and profile_id = (select value::uuid from t_state where key = 'a1_id') $$,
  $$ values ('owner'::text) $$,
  'A1 vira owner da família A'
);

select throws_ok(
  $$ select * from public.create_family('Familia A de novo') $$,
  'VALIDATION_ERROR',
  'A1 não pode criar uma segunda família ativa'
);

-- ---------------------------------------------------------------------
-- 2) A1 convida A2; A2 aceita.
-- ---------------------------------------------------------------------
insert into t_state (key, value)
select 'invite_token', token from public.invite_guardian(
  (select value::uuid from t_state where key = 'family_a_id'),
  'a2@familia-a.test'
);

select pg_temp.act_as('a2_id');

select lives_ok(
  $$ select * from public.accept_guardian_invite((select value from t_state where key = 'invite_token')) $$,
  'A2 aceita o convite da família A'
);

select results_eq(
  $$ select status::text from public.family_members
     where family_id = (select value::uuid from t_state where key = 'family_a_id')
       and profile_id = (select value::uuid from t_state where key = 'a2_id') $$,
  $$ values ('active'::text) $$,
  'A2 vira membro ativo da família A'
);

-- ---------------------------------------------------------------------
-- 3) A1 cria uma criança; a segunda esbarra no limite do plano gratuito.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'child_a1_id', child_id::text from public.create_child(
  (select value::uuid from t_state where key = 'family_a_id'),
  'Crianca A1', '2018-05-10'
);

select ok(
  (select value from t_state where key = 'child_a1_id') is not null,
  'create_child cria a primeira criança da família A'
);

select throws_ok(
  $$ select * from public.create_child(
       (select value::uuid from t_state where key = 'family_a_id'),
       'Crianca A2', '2020-01-01'
     ) $$,
  'PLAN_CHILD_LIMIT',
  'Segunda criança no plano gratuito é bloqueada com PLAN_CHILD_LIMIT'
);

-- ---------------------------------------------------------------------
-- 4) Família B, independente, com seu próprio owner e criança.
-- ---------------------------------------------------------------------
select pg_temp.act_as('b1_id');

insert into t_state (key, value)
select 'family_b_id', family_id::text from public.create_family('Familia B');

select ok(
  (select value from t_state where key = 'family_b_id') is not null,
  'create_family cria a família B independente da família A'
);

insert into t_state (key, value)
select 'child_b1_id', child_id::text from public.create_child(
  (select value::uuid from t_state where key = 'family_b_id'),
  'Crianca B1', '2016-03-20'
);

-- ---------------------------------------------------------------------
-- 5) Isolamento entre famílias via RLS.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

select is_empty(
  $$ select 1 from public.families where id = (select value::uuid from t_state where key = 'family_b_id') $$,
  'A1 não enxerga a família B'
);

select is_empty(
  $$ select 1 from public.child_profiles where id = (select value::uuid from t_state where key = 'child_b1_id') $$,
  'A1 não enxerga a criança da família B'
);

select bag_eq(
  $$ select id from public.child_profiles where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ select (select value::uuid from t_state where key = 'child_a1_id') $$,
  'A1 enxerga exatamente a criança da própria família'
);

select pg_temp.act_as('b1_id');

select is_empty(
  $$ select 1 from public.child_profiles where id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  'B1 não enxerga a criança da família A'
);

-- ---------------------------------------------------------------------
-- 6) PIN e código de acesso da criança.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

select lives_ok(
  $$ select public.set_child_pin((select value::uuid from t_state where key = 'child_a1_id'), '1234') $$,
  'A1 define um PIN de 4 dígitos para a própria criança'
);

reset role;
reset request.jwt.claims;

select ok(
  (select public.verify_child_pin((select value::uuid from t_state where key = 'child_a1_id'), '1234')),
  'verify_child_pin aceita o PIN correto'
);

select ok(
  not (select public.verify_child_pin((select value::uuid from t_state where key = 'child_a1_id'), '0000')),
  'verify_child_pin rejeita um PIN incorreto'
);

-- ---------------------------------------------------------------------
-- 7) Privilégio mínimo: funções internas não são chamáveis por `authenticated`.
-- ---------------------------------------------------------------------
select ok(
  not has_function_privilege('authenticated', 'public.verify_child_pin(uuid, text)', 'EXECUTE'),
  'authenticated não pode chamar verify_child_pin diretamente'
);

select ok(
  has_function_privilege('authenticated', 'public.create_family(text, text, text)', 'EXECUTE'),
  'authenticated pode chamar create_family diretamente'
);

select * from finish();

rollback;
