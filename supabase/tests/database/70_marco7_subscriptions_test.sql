-- Marco 7 (fatia 1) — testes do backend de assinaturas: compra/validação,
-- webhooks idempotentes e fora de ordem, restauração, isolamento entre
-- famílias, privilégio mínimo e downgrade seguro (docs/13, docs/02 seção 5).
--
-- Mesmo padrão de fixture dos testes de Marco 1-6: Família A (A1 + A2
-- responsáveis, 1 criança free-plan) e Família B (B1, independente).
begin;

select plan(39);

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
-- 1) Validação e controle de acesso.
-- ---------------------------------------------------------------------
select results_eq(
  $$ select subscription_status, verified from public.submit_purchase_receipt(
       (select value::uuid from t_state where key = 'family_b_id'),
       'apple', 'produto_inexistente', 'recibo-qualquer', 'txn-b1'
     ) $$,
  $$ values ('free'::text, false) $$,
  'Produto de loja desconhecido não é verificado nem altera o plano'
);

select throws_ok(
  $$ select * from public.submit_purchase_receipt(
       (select value::uuid from t_state where key = 'family_b_id'),
       'apple', 'kids_task_premium_monthly', '', 'txn-b1'
     ) $$,
  'VALIDATION_ERROR',
  'Recibo vazio é rejeitado com VALIDATION_ERROR'
);

select throws_ok(
  $$ select * from public.submit_purchase_receipt(
       (select value::uuid from t_state where key = 'family_a_id'),
       'apple', 'kids_task_premium_monthly', 'recibo-b1', 'txn-x'
     ) $$,
  'FORBIDDEN',
  'B1 não pode comprar assinatura para a família A (não é membro)'
);

select pg_temp.act_as('child_a1_device_id');

select throws_ok(
  $$ select * from public.submit_purchase_receipt(
       (select value::uuid from t_state where key = 'family_a_id'),
       'apple', 'kids_task_premium_monthly', 'recibo-crianca', 'txn-x'
     ) $$,
  'FORBIDDEN',
  'A sessão infantil não pode comprar assinatura'
);

-- ---------------------------------------------------------------------
-- 2) Compra válida.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

select results_eq(
  $$ select subscription_status, verified from public.submit_purchase_receipt(
       (select value::uuid from t_state where key = 'family_a_id'),
       'apple', 'kids_task_premium_monthly', 'recibo-a1', 'apple-txn-a1'
     ) $$,
  $$ values ('active'::text, true) $$,
  'A1 compra Premium para a família A com sucesso'
);

select results_eq(
  $$ select p.code from public.families f join public.plans p on p.id = f.plan_id
     where f.id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values ('premium'::text) $$,
  'families.plan_id passa a apontar para o plano premium'
);

select results_eq(
  $$ select effective_plan_code from public.v_effective_entitlements
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values ('premium'::text) $$,
  'v_effective_entitlements reflete o plano premium'
);

select results_eq(
  $$ select count(*)::int from public.subscriptions
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values (1) $$,
  'Continua existindo exatamente uma linha de assinatura para a família A'
);

-- ---------------------------------------------------------------------
-- 3) Restaurar compras.
-- ---------------------------------------------------------------------
select pg_temp.act_as('b1_id');

select results_eq(
  $$ select subscription_status, restored from public.restore_entitlements(
       (select value::uuid from t_state where key = 'family_b_id')
     ) $$,
  $$ values ('free'::text, false) $$,
  'Restaurar sem compra prévia não reativa nada'
);

select pg_temp.act_as('a1_id');

select results_eq(
  $$ select subscription_status, restored from public.restore_entitlements(
       (select value::uuid from t_state where key = 'family_a_id')
     ) $$,
  $$ values ('active'::text, true) $$,
  'Restaurar com compra prévia reconfirma o Premium'
);

select results_eq(
  $$ select count(*)::int from public.subscriptions
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values (1) $$,
  'Restaurar não duplica a linha de assinatura'
);

-- ---------------------------------------------------------------------
-- 4) Webhooks: idempotência e ordem.
-- ---------------------------------------------------------------------
reset role;
reset request.jwt.claims;

select results_eq(
  $$ select applied from public.handle_apple_notification(
       'evt-1', 'renewal', 'apple-txn-a1', 'active', now() + interval '30 days', null, now(), '{}'::jsonb
     ) $$,
  $$ values (true) $$,
  'Webhook de renovação é aplicado'
);

select results_eq(
  $$ select applied from public.handle_apple_notification(
       'evt-1', 'renewal', 'apple-txn-a1', 'active', now() + interval '30 days', null, now(), '{}'::jsonb
     ) $$,
  $$ values (false) $$,
  'Reprocessar o mesmo store_event_id é no-op'
);

select results_eq(
  $$ select count(*)::int from public.subscription_events where store = 'apple' and store_event_id = 'evt-1' $$,
  $$ values (1) $$,
  'O webhook duplicado não gera uma segunda linha de evento'
);

select results_eq(
  $$ select applied from public.handle_apple_notification(
       'evt-2', 'cancellation', 'apple-txn-a1', 'cancelled_active_until_end', null, null,
       now() - interval '1 hour', '{}'::jsonb
     ) $$,
  $$ values (false) $$,
  'Webhook com timestamp mais antigo que o último aplicado é ignorado'
);

select results_eq(
  $$ select processing_status from public.subscription_events
     where store = 'apple' and store_event_id = 'evt-2' $$,
  $$ values ('ignored_out_of_order'::text) $$,
  'O evento fora de ordem fica marcado como ignored_out_of_order'
);

select results_eq(
  $$ select status from public.subscriptions
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values ('active'::text) $$,
  'O estado da assinatura não regride por causa do evento fora de ordem'
);

-- ---------------------------------------------------------------------
-- 5) resolve_effective_plan_code cobre todos os estados de docs/13 seção 4.
-- ---------------------------------------------------------------------
select results_eq(
  $$ select public.resolve_effective_plan_code(s) from unnest(array[
       'trialing', 'active', 'grace_period', 'billing_retry',
       'cancelled_active_until_end', 'support_override', 'free', 'expired', 'revoked'
     ]) as s $$,
  $$ values
       ('premium'::text), ('premium'::text), ('premium'::text), ('premium'::text),
       ('premium'::text), ('premium'::text), ('free'::text), ('free'::text), ('free'::text) $$,
  'resolve_effective_plan_code mapeia cada estado para free/premium corretamente'
);

-- ---------------------------------------------------------------------
-- 6) Privilégio mínimo.
-- ---------------------------------------------------------------------
select ok(
  has_function_privilege('authenticated', 'public.submit_purchase_receipt(uuid, text, text, text, text)', 'EXECUTE'),
  'authenticated pode chamar submit_purchase_receipt'
);

select ok(
  has_function_privilege('authenticated', 'public.restore_entitlements(uuid)', 'EXECUTE'),
  'authenticated pode chamar restore_entitlements'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.verify_purchase(uuid, text, text, text, text, uuid)',
    'EXECUTE'
  ),
  'authenticated não pode chamar verify_purchase diretamente'
);

select ok(
  not has_function_privilege('authenticated', 'public.apply_safe_downgrade(uuid)', 'EXECUTE'),
  'authenticated não pode chamar apply_safe_downgrade diretamente'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.handle_apple_notification(text, text, text, text, timestamptz, timestamptz, timestamptz, jsonb)',
    'EXECUTE'
  ),
  'authenticated não pode chamar handle_apple_notification diretamente'
);

-- ---------------------------------------------------------------------
-- 7) Isolamento entre famílias via RLS.
-- ---------------------------------------------------------------------
select pg_temp.act_as('b1_id');

select is_empty(
  $$ select 1 from public.subscriptions
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  'B1 não enxerga a assinatura da família A'
);

select is_empty(
  $$ select 1 from public.subscription_events
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  'B1 não enxerga os eventos de assinatura da família A'
);

select is_empty(
  $$ select 1 from public.v_effective_entitlements
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  'B1 não enxerga o entitlement efetivo da família A'
);

-- ---------------------------------------------------------------------
-- 8) Downgrade seguro (docs/02 seção 5): família A tem 5 crianças e
--    ocorrências futuras além do limite gratuito quando o Premium expira.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

select public.create_child((select value::uuid from t_state where key = 'family_a_id'), 'Crianca A2', '2017-01-01');
select public.create_child((select value::uuid from t_state where key = 'family_a_id'), 'Crianca A3', '2017-01-01');
select public.create_child((select value::uuid from t_state where key = 'family_a_id'), 'Crianca A4', '2017-01-01');
select public.create_child((select value::uuid from t_state where key = 'family_a_id'), 'Crianca A5', '2017-01-01');

update public.child_profiles
set theme_slug = 'space_adventure'
where id = (select value::uuid from t_state where key = 'child_a1_id');

insert into t_state (key, value)
select 'task_a1_id', task_id::text from public.upsert_task_with_schedule(
  p_child_id => (select value::uuid from t_state where key = 'child_a1_id'),
  p_title => 'Tarefa de apoio ao teste',
  p_approval_mode => 'automatic',
  p_late_policy => 'allow_late',
  p_schedule_type => 'once',
  p_one_time_date => current_date + 1
);

reset role;
reset request.jwt.claims;

-- 9 ocorrências extras de amanhã (a que o upsert_task_with_schedule já
-- gerou soma 10 no total) + 5 de hoje, todas 'pending', inseridas
-- diretamente (mesmo padrão de fixture usado nos testes de Marco 2-3).
insert into public.task_occurrences (
  task_id, child_id, family_id, occurrence_date, status,
  coin_reward_snapshot, xp_reward_snapshot, approval_mode_snapshot,
  late_policy_snapshot, title_snapshot, icon_snapshot, created_at
)
select
  (select value::uuid from t_state where key = 'task_a1_id'),
  (select value::uuid from t_state where key = 'child_a1_id'),
  (select value::uuid from t_state where key = 'family_a_id'),
  current_date + 1, 'pending', 1, 1, 'automatic', 'allow_late', 'Fixture', 'star',
  timezone('utc', now()) + (n || ' seconds')::interval
from generate_series(1, 9) as n;

insert into public.task_occurrences (
  task_id, child_id, family_id, occurrence_date, status,
  coin_reward_snapshot, xp_reward_snapshot, approval_mode_snapshot,
  late_policy_snapshot, title_snapshot, icon_snapshot, created_at
)
select
  (select value::uuid from t_state where key = 'task_a1_id'),
  (select value::uuid from t_state where key = 'child_a1_id'),
  (select value::uuid from t_state where key = 'family_a_id'),
  current_date, 'pending', 1, 1, 'automatic', 'allow_late', 'Fixture', 'star',
  timezone('utc', now()) + (n || ' seconds')::interval
from generate_series(1, 5) as n;

select results_eq(
  $$ select count(*)::int from public.task_occurrences
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values (15) $$,
  'Fixture: família A tem 15 ocorrências antes do downgrade (10 amanhã + 5 hoje)'
);

-- Dispara o downgrade: expira a assinatura e aplica a transição (fora do
-- papel authenticated, como as demais funções internas dos marcos anteriores).
update public.subscriptions
set status = 'expired'
where family_id = (select value::uuid from t_state where key = 'family_a_id');

select lives_ok(
  $$ select public.apply_subscription_transition((select value::uuid from t_state where key = 'family_a_id')) $$,
  'apply_subscription_transition aplica o downgrade sem erro'
);

select results_eq(
  $$ select p.code from public.families f join public.plans p on p.id = f.plan_id
     where f.id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values ('free'::text) $$,
  'A família A volta ao plano gratuito'
);

select results_eq(
  $$ select count(*)::int from public.child_profiles
     where family_id = (select value::uuid from t_state where key = 'family_a_id') and status = 'active' $$,
  $$ values (1) $$,
  'Só uma criança continua ativa após o downgrade (limite do plano gratuito)'
);

select results_eq(
  $$ select (primary_child_id = (select value::uuid from t_state where key = 'child_a1_id'))
     from public.families where id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values (true) $$,
  'A primeira criança criada é escolhida como primary_child_id automaticamente'
);

select results_eq(
  $$ select count(*)::int from public.child_profiles
     where family_id = (select value::uuid from t_state where key = 'family_a_id') and status = 'plan_paused' $$,
  $$ values (4) $$,
  'As outras 4 crianças ficam plan_paused'
);

select results_eq(
  $$ select theme_slug from public.child_profiles
     where id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values ('kids_default'::text) $$,
  'O tema Premium da criança principal é revertido para o padrão gratuito'
);

select results_eq(
  $$ select
       count(*) filter (where status = 'pending')::int,
       count(*) filter (where status = 'plan_paused')::int
     from public.task_occurrences
     where family_id = (select value::uuid from t_state where key = 'family_a_id')
       and occurrence_date = current_date + 1 $$,
  $$ values (3, 7) $$,
  'Só 3 ocorrências de amanhã continuam pending; as outras 7 ficam plan_paused'
);

select results_eq(
  $$ select count(*) filter (where status = 'plan_paused')::int from public.task_occurrences
     where family_id = (select value::uuid from t_state where key = 'family_a_id')
       and occurrence_date = current_date $$,
  $$ values (0) $$,
  'As ocorrências de hoje não são tocadas pelo downgrade'
);

select results_eq(
  $$ select count(*)::int from public.task_occurrences
     where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values (15) $$,
  'Nenhuma ocorrência é apagada pelo downgrade (só muda de status)'
);

-- ---------------------------------------------------------------------
-- 9) Reativação: nova compra Premium despausa crianças e ocorrências.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

select lives_ok(
  $$ select * from public.submit_purchase_receipt(
       (select value::uuid from t_state where key = 'family_a_id'),
       'apple', 'kids_task_premium_monthly', 'recibo-a1-reativacao', 'apple-txn-a1-2'
     ) $$,
  'A1 reativa o Premium após o downgrade'
);

select results_eq(
  $$ select count(*)::int from public.child_profiles
     where family_id = (select value::uuid from t_state where key = 'family_a_id') and status = 'active' $$,
  $$ values (5) $$,
  'As 5 crianças voltam a ficar ativas dentro do novo limite premium'
);

select results_eq(
  $$ select count(*) filter (where status = 'pending')::int from public.task_occurrences
     where family_id = (select value::uuid from t_state where key = 'family_a_id')
       and occurrence_date = current_date + 1 $$,
  $$ values (10) $$,
  'As ocorrências de amanhã voltam todas a pending dentro do novo limite premium'
);

select * from finish();

rollback;
