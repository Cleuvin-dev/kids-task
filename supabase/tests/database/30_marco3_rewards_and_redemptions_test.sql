-- Marco 3 — testes de ajuste manual, ciclo de vida do resgate, saldo nunca
-- negativo e isolamento entre famílias (docs/15_CRITERIOS_DE_ACEITE_E_TESTES.md
-- seção 7, docs/05_KIDSCOINS_RECOMPENSAS_XP_E_STREAK.md seções 3 e 5).
--
-- Mesmo padrão de fixture dos testes de Marco 1/2: Família A (A1
-- responsável, 1 criança free-plan) e Família B (B1, independente).
begin;

select plan(32);

create temporary table t_state (key text primary key, value text);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a1@familia-a.test', '', now(), '{}', '{"display_name":"A1"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'b1@familia-b.test', '', now(), '{}', '{"display_name":"B1"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'child-a1-device@device.test', '', now(), '{}', '{}', now(), now());

insert into t_state (key, value)
select 'a1_id', id::text from auth.users where email = 'a1@familia-a.test'
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
-- Fixtures de família/criança/aparelho (comportamento já coberto nos
-- Marcos 1-2; aqui só preparamos o terreno).
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'family_a_id', family_id::text from public.create_family('Familia A', 'America/Sao_Paulo', 'blue');

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
-- 1) Ajuste manual de moedas.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

select lives_ok(
  $$ select * from public.adjust_child_coins(
       (select value::uuid from t_state where key = 'child_a1_id'), 100, 'credit',
       'Saldo inicial de teste', 'idem-adjust-credit-1'
     ) $$,
  'A1 credita 100 KidsCoins com motivo'
);

select results_eq(
  $$ select coin_balance from public.child_wallets
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (100) $$,
  'Saldo reflete o crédito manual'
);

select results_eq(
  $$ select count(*)::int from public.coin_ledger
     where child_id = (select value::uuid from t_state where key = 'child_a1_id')
       and entry_type = 'manual_adjustment' $$,
  $$ values (1) $$,
  'Um lançamento de ajuste manual foi criado'
);

select throws_ok(
  $$ select * from public.adjust_child_coins(
       (select value::uuid from t_state where key = 'child_a1_id'), 10, 'credit', null, 'idem-adjust-no-reason'
     ) $$,
  'VALIDATION_ERROR',
  'Ajuste manual sem motivo é bloqueado'
);

select throws_ok(
  $$ select * from public.adjust_child_coins(
       (select value::uuid from t_state where key = 'child_a1_id'), 500, 'debit',
       'Retirada grande demais', 'idem-adjust-too-much'
     ) $$,
  'INSUFFICIENT_COINS',
  'Débito manual maior que o saldo é bloqueado'
);

select results_eq(
  $$ select coin_balance from public.child_wallets
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (100) $$,
  'Tentativas bloqueadas não alteram o saldo'
);

-- ---------------------------------------------------------------------
-- 2) Recompensas: cadastro simples via RLS (sem RPC dedicada).
-- ---------------------------------------------------------------------
with new_reward as (
  insert into public.rewards (family_id, title, cost_coins)
  values ((select value::uuid from t_state where key = 'family_a_id'), 'Passeio ao parque', 30)
  returning id
)
insert into t_state (key, value)
select 'reward_cheap_id', id::text from new_reward;

with new_reward as (
  insert into public.rewards (family_id, title, cost_coins)
  values ((select value::uuid from t_state where key = 'family_a_id'), 'Filme escolhido pela criança', 10)
  returning id
)
insert into t_state (key, value)
select 'reward_reject_id', id::text from new_reward;

with new_reward as (
  insert into public.rewards (family_id, title, cost_coins)
  values ((select value::uuid from t_state where key = 'family_a_id'), 'Uma hora de videogame', 15)
  returning id
)
insert into t_state (key, value)
select 'reward_cancel_id', id::text from new_reward;

-- ---------------------------------------------------------------------
-- 3) Resgate pendente não debita; saldo insuficiente impede aprovação.
-- ---------------------------------------------------------------------
select pg_temp.act_as('child_a1_device_id');

insert into t_state (key, value)
select 'redemption_cheap_id', redemption_id::text from public.request_redemption(
  (select value::uuid from t_state where key = 'reward_cheap_id'), 'idem-request-cheap'
);

select results_eq(
  $$ select coin_balance from public.child_wallets
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (100) $$,
  'Solicitação pendente não debita o saldo'
);

select pg_temp.act_as('a1_id');

select lives_ok(
  $$ select public.adjust_child_coins(
       (select value::uuid from t_state where key = 'child_a1_id'), 90, 'debit',
       'Reduzir saldo para o teste de aprovação sem fundos', 'idem-adjust-debit-90'
     ) $$,
  'A1 reduz o saldo para 10 (menor que o custo da recompensa)'
);

select throws_ok(
  $$ select * from public.review_redemption(
       (select value::uuid from t_state where key = 'redemption_cheap_id'), 'approve',
       'idem-review-cheap-1', 1, null
     ) $$,
  'INSUFFICIENT_COINS',
  'Aprovação é bloqueada quando o saldo já não é suficiente'
);

select lives_ok(
  $$ select public.adjust_child_coins(
       (select value::uuid from t_state where key = 'child_a1_id'), 50, 'credit',
       'Repor saldo para aprovar o resgate', 'idem-adjust-credit-2'
     ) $$,
  'A1 repõe o saldo para 60'
);

-- ---------------------------------------------------------------------
-- 4) Aprovação debita exatamente uma vez.
-- ---------------------------------------------------------------------
select lives_ok(
  $$ select * from public.review_redemption(
       (select value::uuid from t_state where key = 'redemption_cheap_id'), 'approve',
       'idem-review-cheap-2', 1, null
     ) $$,
  'A1 aprova o resgate com saldo suficiente'
);

select results_eq(
  $$ select coin_balance from public.child_wallets
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (30) $$,
  'Saldo é debitado no valor exato da recompensa (60 - 30)'
);

select results_eq(
  $$ select count(*)::int from public.coin_ledger
     where source_id = (select value::uuid from t_state where key = 'redemption_cheap_id')
       and entry_type = 'redemption' $$,
  $$ values (1) $$,
  'Exatamente um lançamento de débito para o resgate'
);

select lives_ok(
  $$ select * from public.review_redemption(
       (select value::uuid from t_state where key = 'redemption_cheap_id'), 'approve',
       'idem-review-cheap-2', 1, null
     ) $$,
  'Reprocessar a mesma aprovação (mesma idempotency_key) não gera erro'
);

select results_eq(
  $$ select coin_balance from public.child_wallets
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (30) $$,
  'O reprocessamento não debita de novo'
);

-- ---------------------------------------------------------------------
-- 5) Entrega não debita novamente.
-- ---------------------------------------------------------------------
select lives_ok(
  $$ select public.mark_redemption_delivered(
       (select value::uuid from t_state where key = 'redemption_cheap_id'), 'idem-delivered-cheap'
     ) $$,
  'A1 marca o resgate como entregue'
);

select results_eq(
  $$ select coin_balance from public.child_wallets
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (30) $$,
  'Marcar como entregue não movimenta o saldo'
);

-- ---------------------------------------------------------------------
-- 6) Rejeição não debita.
-- ---------------------------------------------------------------------
select pg_temp.act_as('child_a1_device_id');

insert into t_state (key, value)
select 'redemption_reject_id', redemption_id::text from public.request_redemption(
  (select value::uuid from t_state where key = 'reward_reject_id'), 'idem-request-reject'
);

select pg_temp.act_as('a1_id');

select lives_ok(
  $$ select public.review_redemption(
       (select value::uuid from t_state where key = 'redemption_reject_id'), 'reject',
       'idem-review-reject-1', 1, 'Não é uma boa hora para este filme'
     ) $$,
  'A1 rejeita o resgate com motivo'
);

select results_eq(
  $$ select coin_balance from public.child_wallets
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (30) $$,
  'Rejeição não debita o saldo'
);

-- ---------------------------------------------------------------------
-- 7) Cancelamento aprovado gera estorno.
-- ---------------------------------------------------------------------
select pg_temp.act_as('child_a1_device_id');

insert into t_state (key, value)
select 'redemption_cancel_id', redemption_id::text from public.request_redemption(
  (select value::uuid from t_state where key = 'reward_cancel_id'), 'idem-request-cancel'
);

select pg_temp.act_as('a1_id');

select lives_ok(
  $$ select public.review_redemption(
       (select value::uuid from t_state where key = 'redemption_cancel_id'), 'approve',
       'idem-review-cancel-1', 1, null
     ) $$,
  'A1 aprova o resgate que será cancelado'
);

select results_eq(
  $$ select coin_balance from public.child_wallets
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (15) $$,
  'Saldo debitado após a aprovação (30 - 15)'
);

select lives_ok(
  $$ select public.cancel_approved_redemption(
       (select value::uuid from t_state where key = 'redemption_cancel_id'),
       'Combinamos outra recompensa', 'idem-cancel-1'
     ) $$,
  'A1 cancela o resgate aprovado com motivo'
);

select results_eq(
  $$ select coin_balance from public.child_wallets
     where child_id = (select value::uuid from t_state where key = 'child_a1_id') $$,
  $$ values (30) $$,
  'Cancelamento estorna o valor integral'
);

select results_eq(
  $$ select count(*)::int from public.coin_ledger
     where source_id = (select value::uuid from t_state where key = 'redemption_cancel_id')
       and entry_type = 'redemption_refund' $$,
  $$ values (1) $$,
  'Exatamente um lançamento de estorno'
);

-- ---------------------------------------------------------------------
-- 8) Isolamento entre famílias via RLS.
-- ---------------------------------------------------------------------
select pg_temp.act_as('b1_id');

select is_empty(
  $$ select 1 from public.rewards where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  'B1 não enxerga recompensas da família A'
);

select is_empty(
  $$ select 1 from public.redemption_requests where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  'B1 não enxerga resgates da família A'
);

select is_empty(
  $$ select 1 from public.coin_ledger where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  'B1 não enxerga o ledger de moedas da família A'
);

-- ---------------------------------------------------------------------
-- 9) Privilégio mínimo.
-- ---------------------------------------------------------------------
select ok(
  has_function_privilege('authenticated', 'public.adjust_child_coins(uuid, integer, text, text, text)', 'EXECUTE'),
  'authenticated pode chamar adjust_child_coins'
);

select ok(
  has_function_privilege('authenticated', 'public.request_redemption(uuid, text)', 'EXECUTE'),
  'authenticated pode chamar request_redemption'
);

select ok(
  has_function_privilege('authenticated', 'public.review_redemption(uuid, text, text, integer, text)', 'EXECUTE'),
  'authenticated pode chamar review_redemption'
);

select ok(
  has_function_privilege('authenticated', 'public.mark_redemption_delivered(uuid, text)', 'EXECUTE'),
  'authenticated pode chamar mark_redemption_delivered'
);

select ok(
  has_function_privilege('authenticated', 'public.cancel_approved_redemption(uuid, text, text)', 'EXECUTE'),
  'authenticated pode chamar cancel_approved_redemption'
);

select * from finish();

rollback;
