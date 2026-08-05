-- Marco 7 (fatia 7) — testes do dashboard administrativo: controle de
-- acesso (só super_admin), métricas refletem dados reais criados na
-- própria transação, privilégio mínimo (docs/12 seção 3).
begin;

select plan(9);

create temporary table t_state (key text primary key, value text);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a1@familia-a.test', '', now(), '{}', '{"display_name":"A1"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a3@familia-b.test', '', now(), '{}', '{"display_name":"A3"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-super@kidstask.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-billing@kidstask.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-support@kidstask.test', '', now(), '{}', '{}', now(), now());

insert into t_state (key, value)
select 'a1_id', id::text from auth.users where email = 'a1@familia-a.test'
union all select 'a3_id', id::text from auth.users where email = 'a3@familia-b.test'
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

-- ---------------------------------------------------------------------
-- Fixtures: família A (com uma criança) e família B (sem criança), mais
-- um ticket de suporte aberto.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'family_a_id', family_id::text from public.create_family('Familia A', 'America/Sao_Paulo', 'blue');

insert into t_state (key, value)
select 'child_a_id', child_id::text from public.create_child(
  (select value::uuid from t_state where key = 'family_a_id'), 'Joana', (current_date - interval '9 years')::date
);

select pg_temp.act_as('a3_id');

insert into t_state (key, value)
select 'family_b_id', family_id::text from public.create_family('Familia B', 'America/Sao_Paulo', 'blue');

reset role;
reset request.jwt.claims;

insert into public.support_tickets (family_id, subject, category, created_by)
values (
  (select value::uuid from t_state where key = 'family_a_id'), 'Dúvida sobre convite', 'account',
  (select value::uuid from t_state where key = 'admin_support_id')
);

-- ---------------------------------------------------------------------
-- 1) Controle de acesso.
-- ---------------------------------------------------------------------
select pg_temp.act_as('admin_billing_id');

select throws_ok(
  $$ select public.admin_get_dashboard_metrics() $$,
  'FORBIDDEN',
  'billing não pode ver o dashboard (só super_admin)'
);

select pg_temp.act_as('admin_support_id');

select throws_ok(
  $$ select public.admin_get_dashboard_metrics() $$,
  'FORBIDDEN',
  'support não pode ver o dashboard (só super_admin)'
);

select pg_temp.act_as('a1_id');

select throws_ok(
  $$ select public.admin_get_dashboard_metrics() $$,
  'FORBIDDEN',
  'Um responsável comum não pode ver o dashboard'
);

-- ---------------------------------------------------------------------
-- 2) Métricas refletem os dados criados nesta transação.
-- ---------------------------------------------------------------------
select pg_temp.act_as('admin_super_id');

select results_eq(
  $$ select (public.admin_get_dashboard_metrics() ->> 'families_total')::int $$,
  $$ values (2) $$,
  'families_total conta as duas famílias criadas'
);

select results_eq(
  $$ select (public.admin_get_dashboard_metrics() ->> 'families_onboarded')::int $$,
  $$ values (1) $$,
  'families_onboarded só conta a família com criança ativa'
);

select results_eq(
  $$ select (public.admin_get_dashboard_metrics() ->> 'guardians_total')::int $$,
  $$ values (2) $$,
  'guardians_total conta os dois responsáveis (um por família)'
);

select results_eq(
  $$ select (public.admin_get_dashboard_metrics() ->> 'children_total')::int $$,
  $$ values (1) $$,
  'children_total conta a única criança ativa'
);

select results_eq(
  $$ select public.admin_get_dashboard_metrics() -> 'families_by_effective_plan' -> 'free' $$,
  $$ values ('2'::jsonb) $$,
  'families_by_effective_plan agrupa as duas famílias como free (plano padrão)'
);

select results_eq(
  $$ select (public.admin_get_dashboard_metrics() ->> 'support_tickets_open')::int $$,
  $$ values (1) $$,
  'support_tickets_open conta o ticket aberto'
);

select * from finish();

rollback;
