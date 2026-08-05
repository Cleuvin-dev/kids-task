-- Marco 7 (fatia 3) — testes do módulo "Assinaturas" do painel: leitura
-- entre famílias restrita por papel, busca de família, override de
-- suporte (conceder/revogar/expirar), idempotência e privilégio mínimo
-- (docs/12 seção 5, docs/15 seção 14: "override de assinatura expira").
begin;

select plan(32);

create temporary table t_state (key text primary key, value text);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a1@familia-a.test', '', now(), '{}', '{"display_name":"A1"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'c1@familia-c.test', '', now(), '{}', '{"display_name":"C1"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-super@kidstask.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-billing@kidstask.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-support@kidstask.test', '', now(), '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-content@kidstask.test', '', now(), '{}', '{}', now(), now());

insert into t_state (key, value)
select 'a1_id', id::text from auth.users where email = 'a1@familia-a.test'
union all select 'c1_id', id::text from auth.users where email = 'c1@familia-c.test'
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

-- aal2: precisa para qualquer chamada que grava auditoria
-- (record_admin_audit_log, fatia 2).
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
-- Fixtures: família A (a1) e família C (c1, sem override).
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'family_a_id', family_id::text from public.create_family('Familia A', 'America/Sao_Paulo', 'blue');

select pg_temp.act_as('c1_id');

insert into t_state (key, value)
select 'family_c_id', family_id::text from public.create_family('Familia C');

-- ---------------------------------------------------------------------
-- 1) RLS admin: families/subscriptions restritos por papel.
-- ---------------------------------------------------------------------
select pg_temp.act_as('admin_billing_id');

select results_eq(
  $$ select name from public.families where id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values ('Familia A'::text) $$,
  'billing enxerga qualquer família (families_select_admin)'
);

select results_eq(
  $$ select status from public.subscriptions where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values ('free'::text) $$,
  'billing enxerga a assinatura de qualquer família'
);

select pg_temp.act_as('admin_content_id');

select is_empty(
  $$ select 1 from public.families where id = (select value::uuid from t_state where key = 'family_a_id') $$,
  'content não enxerga famílias (fora dos papéis de families_select_admin)'
);

select pg_temp.act_as('admin_support_id');

select is_empty(
  $$ select 1 from public.subscriptions where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  'support não enxerga assinatura (fora dos papéis de subscriptions_select_admin)'
);

-- ---------------------------------------------------------------------
-- 2) admin_search_families.
-- ---------------------------------------------------------------------
select pg_temp.act_as('admin_super_id');

select results_eq(
  $$ select family_id from public.admin_search_families((select value from t_state where key = 'family_a_id')) $$,
  $$ values ((select value::uuid from t_state where key = 'family_a_id')) $$,
  'Busca por family_id (UUID) encontra a família A'
);

select results_eq(
  $$ select family_id from public.admin_search_families('a1@familia-a.test') $$,
  $$ values ((select value::uuid from t_state where key = 'family_a_id')) $$,
  'Busca por e-mail do responsável encontra a família A'
);

select throws_ok(
  $$ select * from public.admin_search_families('ab') $$,
  'VALIDATION_ERROR',
  'Busca com menos de 3 caracteres é rejeitada'
);

select pg_temp.act_as('a1_id');

select throws_ok(
  $$ select * from public.admin_search_families('a1@familia-a.test') $$,
  'FORBIDDEN',
  'Um responsável comum não pode buscar famílias'
);

select pg_temp.act_as('admin_content_id');

select throws_ok(
  $$ select * from public.admin_search_families('a1@familia-a.test') $$,
  'FORBIDDEN',
  'content não pode buscar famílias (fora do papel permitido)'
);

-- ---------------------------------------------------------------------
-- 3) admin_grant_subscription_override: controle de acesso e validação.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

select throws_ok(
  $$ select * from public.admin_grant_subscription_override(
       (select value::uuid from t_state where key = 'family_a_id'),
       timezone('utc', now()) + interval '30 days', 'teste', 'idem-guardian-1'
     ) $$,
  'FORBIDDEN',
  'Um responsável comum não pode conceder override'
);

select pg_temp.act_as_mfa('admin_support_id');

select throws_ok(
  $$ select * from public.admin_grant_subscription_override(
       (select value::uuid from t_state where key = 'family_a_id'),
       timezone('utc', now()) + interval '30 days', 'teste', 'idem-support-1'
     ) $$,
  'FORBIDDEN',
  'support não pode conceder override (só super_admin/billing)'
);

select pg_temp.act_as_mfa('admin_billing_id');

select throws_ok(
  $$ select * from public.admin_grant_subscription_override(
       (select value::uuid from t_state where key = 'family_a_id'),
       timezone('utc', now()) + interval '30 days', '   ', 'idem-blank-justification'
     ) $$,
  'VALIDATION_ERROR',
  'Justificativa em branco é rejeitada'
);

select throws_ok(
  $$ select * from public.admin_grant_subscription_override(
       (select value::uuid from t_state where key = 'family_a_id'),
       timezone('utc', now()) - interval '1 day', 'justificativa válida', 'idem-past-expiry'
     ) $$,
  'VALIDATION_ERROR',
  'Data de expiração no passado é rejeitada'
);

-- ---------------------------------------------------------------------
-- 4) admin_grant_subscription_override: caminho feliz + idempotência.
-- ---------------------------------------------------------------------
select lives_ok(
  $$ select * from public.admin_grant_subscription_override(
       (select value::uuid from t_state where key = 'family_a_id'),
       timezone('utc', now()) + interval '30 days',
       'Cortesia de suporte, ticket #123', 'idem-grant-1'
     ) $$,
  'billing concede o override com sucesso'
);

select results_eq(
  $$ select status from public.subscriptions where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values ('support_override'::text) $$,
  'A assinatura da família A fica support_override'
);

select results_eq(
  $$ select p.code from public.families f join public.plans p on p.id = f.plan_id
     where f.id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values ('premium'::text) $$,
  'apply_subscription_transition promove a família A a premium'
);

select results_eq(
  $$ select count(*)::int from public.audit_logs
     where action = 'admin.subscription_override_granted'
       and actor_profile_id = (select value::uuid from t_state where key = 'admin_billing_id') $$,
  $$ values (1) $$,
  'A concessão gera uma linha de auditoria'
);

select lives_ok(
  $$ select * from public.admin_grant_subscription_override(
       (select value::uuid from t_state where key = 'family_a_id'),
       timezone('utc', now()) + interval '30 days',
       'Cortesia de suporte, ticket #123', 'idem-grant-1'
     ) $$,
  'Reenviar a mesma idempotency_key não gera erro'
);

select results_eq(
  $$ select count(*)::int from public.subscription_events
     where family_id = (select value::uuid from t_state where key = 'family_a_id')
       and event_type = 'support_override_granted' $$,
  $$ values (1) $$,
  'O reenvio não duplica o evento de concessão'
);

-- ---------------------------------------------------------------------
-- 5) admin_revoke_subscription_override.
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select * from public.admin_revoke_subscription_override(
       (select value::uuid from t_state where key = 'family_c_id'), 'engano', 'idem-revoke-not-override'
     ) $$,
  'VALIDATION_ERROR',
  'Não é possível revogar override numa assinatura que não está em override'
);

select lives_ok(
  $$ select * from public.admin_revoke_subscription_override(
       (select value::uuid from t_state where key = 'family_a_id'), 'Ticket #123 encerrado', 'idem-revoke-1'
     ) $$,
  'billing revoga o override com sucesso'
);

select results_eq(
  $$ select status from public.subscriptions where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values ('free'::text) $$,
  'A assinatura da família A volta a free após a revogação'
);

select results_eq(
  $$ select p.code from public.families f join public.plans p on p.id = f.plan_id
     where f.id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values ('free'::text) $$,
  'apply_subscription_transition reverte a família A para o plano gratuito'
);

select results_eq(
  $$ select count(*)::int from public.audit_logs where action = 'admin.subscription_override_revoked' $$,
  $$ values (1) $$,
  'A revogação gera uma linha de auditoria'
);

-- ---------------------------------------------------------------------
-- 6) expire_support_overrides.
-- ---------------------------------------------------------------------
select lives_ok(
  $$ select * from public.admin_grant_subscription_override(
       (select value::uuid from t_state where key = 'family_a_id'),
       timezone('utc', now()) + interval '1 hour', 'segunda cortesia', 'idem-grant-2'
     ) $$,
  'billing concede um segundo override para simular expiração'
);

reset role;
reset request.jwt.claims;

update public.subscriptions
set current_period_end = timezone('utc', now()) - interval '1 hour'
where family_id = (select value::uuid from t_state where key = 'family_a_id');

select lives_ok(
  $$ select public.expire_support_overrides() $$,
  'expire_support_overrides roda sem erro'
);

select results_eq(
  $$ select status from public.subscriptions where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values ('free'::text) $$,
  'O override expirado volta a free automaticamente'
);

select results_eq(
  $$ select p.code from public.families f join public.plans p on p.id = f.plan_id
     where f.id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values ('free'::text) $$,
  'A expiração também reverte o plano da família para o gratuito'
);

-- ---------------------------------------------------------------------
-- 7) Privilégio mínimo.
-- ---------------------------------------------------------------------
select ok(
  has_function_privilege('authenticated', 'public.admin_search_families(text)', 'EXECUTE'),
  'authenticated pode chamar admin_search_families'
);

select ok(
  has_function_privilege('authenticated', 'public.admin_grant_subscription_override(uuid, timestamptz, text, text)', 'EXECUTE'),
  'authenticated pode chamar admin_grant_subscription_override'
);

select ok(
  has_function_privilege('authenticated', 'public.admin_revoke_subscription_override(uuid, text, text)', 'EXECUTE'),
  'authenticated pode chamar admin_revoke_subscription_override'
);

select ok(
  not has_function_privilege('authenticated', 'public.expire_support_overrides()', 'EXECUTE'),
  'authenticated não pode chamar expire_support_overrides diretamente'
);

select * from finish();

rollback;
