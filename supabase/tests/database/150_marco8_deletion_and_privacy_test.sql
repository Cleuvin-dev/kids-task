-- Marco 8 — testes de exclusão dupla, exportação de dados e retenção
-- (docs/09 seção 8, docs/10 seções 10-13).
begin;

select plan(32);

create temporary table t_state (key text primary key, value text);

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a1@familia-a.test', '', now(), '{}', '{"display_name":"A1"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'a2@familia-a.test', '', now(), '{}', '{"display_name":"A2"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'b1@familia-b.test', '', now(), '{}', '{"display_name":"B1"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated', 'authenticated', 'admin-content@kidstask.test', '', now(), '{}', '{}', now(), now());

insert into t_state (key, value)
select 'a1_id', id::text from auth.users where email = 'a1@familia-a.test'
union all select 'a2_id', id::text from auth.users where email = 'a2@familia-a.test'
union all select 'b1_id', id::text from auth.users where email = 'b1@familia-b.test'
union all select 'admin_content_id', id::text from auth.users where email = 'admin-content@kidstask.test';

insert into public.platform_admins (profile_id, role, active)
values ((select value::uuid from t_state where key = 'admin_content_id'), 'content', true);

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
-- Fixtures: família A (a1 + a2, uma criança) e família B (só b1, uma
-- criança).
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'family_a_id', family_id::text from public.create_family('Familia A', 'America/Sao_Paulo', 'blue');

insert into t_state (key, value)
select 'child_a_id', child_id::text from public.create_child(
  (select value::uuid from t_state where key = 'family_a_id'), 'Joana', (current_date - interval '9 years')::date
);

reset role;
reset request.jwt.claims;

insert into public.family_members (family_id, profile_id, role, status)
values (
  (select value::uuid from t_state where key = 'family_a_id'),
  (select value::uuid from t_state where key = 'a2_id'),
  'guardian', 'active'
);

select pg_temp.act_as('b1_id');

insert into t_state (key, value)
select 'family_b_id', family_id::text from public.create_family('Familia B', 'America/Sao_Paulo', 'blue');

insert into t_state (key, value)
select 'child_b_id', child_id::text from public.create_child(
  (select value::uuid from t_state where key = 'family_b_id'), 'Pedro', (current_date - interval '9 years')::date
);

-- ---------------------------------------------------------------------
-- 1) request_family_deletion: caminho com dois responsáveis.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

select results_eq(
  $$ select status, requires_second_approval from public.request_family_deletion('idem-req-a-1') $$,
  $$ values ('pending_approval'::text, true) $$,
  'a1 pede exclusão; com dois responsáveis, fica pendente de aprovação'
);

select results_eq(
  $$ select count(*)::int from public.notifications
     where family_id = (select value::uuid from t_state where key = 'family_a_id')
       and event_type = 'family.deletion_requested' $$,
  $$ values (1) $$,
  'O outro responsável (a2) é notificado do pedido'
);

select throws_ok(
  $$ select * from public.request_family_deletion('idem-req-a-2') $$,
  'VALIDATION_ERROR',
  'Não é possível abrir um segundo pedido enquanto um já está em andamento'
);

insert into t_state (key, value)
select 'request_a_id', id::text from public.deletion_requests
where family_id = (select value::uuid from t_state where key = 'family_a_id');

-- ---------------------------------------------------------------------
-- 2) respond_family_deletion.
-- ---------------------------------------------------------------------
select throws_ok(
  $$ select * from public.respond_family_deletion(
       (select value::uuid from t_state where key = 'request_a_id'), true
     ) $$,
  'VALIDATION_ERROR',
  'Quem pediu não pode responder ao próprio pedido'
);

select pg_temp.act_as('a2_id');

select throws_ok(
  $$ select * from public.respond_family_deletion(
       (select value::uuid from t_state where key = 'request_a_id'), false, null
     ) $$,
  'VALIDATION_ERROR',
  'Rejeitar exige motivo'
);

select results_eq(
  $$ select status from public.respond_family_deletion(
       (select value::uuid from t_state where key = 'request_a_id'), false, 'Não concordo'
     ) $$,
  $$ values ('rejected'::text) $$,
  'a2 rejeita o pedido'
);

-- Rejeitado libera a família para um novo pedido.
select pg_temp.act_as('a1_id');

select lives_ok(
  $$ select * from public.request_family_deletion('idem-req-a-3') $$,
  'a1 pede exclusão de novo depois da rejeição'
);

insert into t_state (key, value)
select 'request_a2_id', id::text from public.deletion_requests
where family_id = (select value::uuid from t_state where key = 'family_a_id')
  and status = 'pending_approval';

select pg_temp.act_as('a2_id');

select results_eq(
  $$ select status from public.respond_family_deletion(
       (select value::uuid from t_state where key = 'request_a2_id'), true
     ) $$,
  $$ values ('approved'::text) $$,
  'a2 aprova desta vez'
);

select ok(
  (select scheduled_for is not null from public.deletion_requests
   where id = (select value::uuid from t_state where key = 'request_a2_id')),
  'Aprovar agenda a exclusão (scheduled_for preenchido)'
);

-- ---------------------------------------------------------------------
-- 2.5) Isolamento entre famílias: b1 (família B) não enxerga nem age
-- sobre o pedido da família A (docs/15 seção 16: "um teste negativo é tão
-- obrigatório quanto o positivo").
-- ---------------------------------------------------------------------
select pg_temp.act_as('b1_id');

select is_empty(
  $$ select 1 from public.deletion_requests
     where id = (select value::uuid from t_state where key = 'request_a2_id') $$,
  'b1 não enxerga o pedido de exclusão da família A'
);

select throws_ok(
  $$ select * from public.cancel_family_deletion(
       (select value::uuid from t_state where key = 'request_a2_id')
     ) $$,
  'FORBIDDEN',
  'b1 não pode cancelar o pedido de exclusão da família A'
);

select throws_ok(
  $$ select * from public.respond_family_deletion(
       (select value::uuid from t_state where key = 'request_a2_id'), true
     ) $$,
  'FORBIDDEN',
  'b1 não pode responder ao pedido de exclusão da família A'
);

-- ---------------------------------------------------------------------
-- 3) cancel_family_deletion.
-- ---------------------------------------------------------------------
select lives_ok(
  $$ select * from public.cancel_family_deletion(
       (select value::uuid from t_state where key = 'request_a2_id')
     ) $$,
  'a2 cancela o pedido já aprovado'
);

select throws_ok(
  $$ select * from public.cancel_family_deletion(
       (select value::uuid from t_state where key = 'request_a2_id')
     ) $$,
  'VALIDATION_ERROR',
  'Cancelar um pedido já cancelado é rejeitado'
);

-- ---------------------------------------------------------------------
-- 4) Caminho de responsável único (família B).
-- ---------------------------------------------------------------------
select pg_temp.act_as('b1_id');

select results_eq(
  $$ select status, requires_second_approval from public.request_family_deletion('idem-req-b-1') $$,
  $$ values ('approved'::text, false) $$,
  'b1 (único responsável) pede exclusão e já fica aprovada, agendada'
);

select ok(
  (select scheduled_for is not null from public.deletion_requests
   where family_id = (select value::uuid from t_state where key = 'family_b_id')),
  'O pedido de b1 já nasce com scheduled_for preenchido'
);

-- Idempotência: reenviar a mesma chave não cria um segundo pedido.
select lives_ok(
  $$ select * from public.request_family_deletion('idem-req-b-1') $$,
  'Reenviar a mesma idempotency_key não gera erro'
);

select results_eq(
  $$ select count(*)::int from public.deletion_requests
     where family_id = (select value::uuid from t_state where key = 'family_b_id') $$,
  $$ values (1) $$,
  'O reenvio não duplica o pedido de família B'
);

-- ---------------------------------------------------------------------
-- 5) process_scheduled_deletions: execução real.
-- ---------------------------------------------------------------------
reset role;
reset request.jwt.claims;

update public.deletion_requests
set scheduled_for = timezone('utc', now()) - interval '1 hour'
where family_id = (select value::uuid from t_state where key = 'family_b_id');

select lives_ok(
  $$ select public.process_scheduled_deletions() $$,
  'process_scheduled_deletions roda sem erro'
);

select results_eq(
  $$ select status from public.families where id = (select value::uuid from t_state where key = 'family_b_id') $$,
  $$ values ('deleted'::text) $$,
  'A família B fica com status deleted'
);

select results_eq(
  $$ select first_name, nickname, pin_enabled from public.child_profiles
     where id = (select value::uuid from t_state where key = 'child_b_id') $$,
  $$ values ('Criança excluída'::text, null::text, false) $$,
  'A criança da família B tem a identidade anonimizada'
);

select results_eq(
  $$ select status from public.family_members
     where family_id = (select value::uuid from t_state where key = 'family_b_id')
       and profile_id = (select value::uuid from t_state where key = 'b1_id') $$,
  $$ values ('removed'::text) $$,
  'b1 perde o vínculo ativo com a família'
);

select results_eq(
  $$ select status from public.deletion_requests
     where family_id = (select value::uuid from t_state where key = 'family_b_id') $$,
  $$ values ('completed'::text) $$,
  'O pedido de família B fica completed'
);

-- ---------------------------------------------------------------------
-- 6) export_family_data.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

select results_eq(
  $$ select public.export_family_data() -> 'family' ->> 'name' $$,
  $$ values ('Familia A'::text) $$,
  'export_family_data devolve o nome da própria família'
);

select results_eq(
  $$ select jsonb_array_length(public.export_family_data() -> 'children') $$,
  $$ values (1) $$,
  'export_family_data lista a criança da família'
);

select pg_temp.act_as('admin_content_id');

select throws_ok(
  $$ select public.export_family_data() $$,
  'FORBIDDEN',
  'Quem não é responsável de nenhuma família não pode exportar'
);

-- ---------------------------------------------------------------------
-- 7) revoke_consent.
-- ---------------------------------------------------------------------
reset role;
reset request.jwt.claims;

insert into public.consent_records (family_id, guardian_profile_id, document, document_version, purpose)
values (
  (select value::uuid from t_state where key = 'family_a_id'),
  (select value::uuid from t_state where key = 'a1_id'),
  'terms_of_service', '2026-07-31', 'terms_of_service'
);

insert into t_state (key, value)
select 'consent_a_id', id::text from public.consent_records
where family_id = (select value::uuid from t_state where key = 'family_a_id');

select pg_temp.act_as('admin_content_id');

select throws_ok(
  $$ select * from public.revoke_consent((select value::uuid from t_state where key = 'consent_a_id')) $$,
  'FORBIDDEN',
  'Quem não é responsável da família não pode revogar o consentimento'
);

select pg_temp.act_as('a1_id');

select results_eq(
  $$ select status from public.revoke_consent((select value::uuid from t_state where key = 'consent_a_id')) $$,
  $$ values ('revoked'::text) $$,
  'a1 revoga o próprio consentimento da família'
);

select throws_ok(
  $$ select * from public.revoke_consent((select value::uuid from t_state where key = 'consent_a_id')) $$,
  'VALIDATION_ERROR',
  'Revogar um consentimento já revogado é rejeitado'
);

-- ---------------------------------------------------------------------
-- 8) purge_stale_operational_data.
-- ---------------------------------------------------------------------
reset role;
reset request.jwt.claims;

insert into public.family_invites (family_id, email_normalized, token_digest, invited_by, expires_at)
values (
  (select value::uuid from t_state where key = 'family_a_id'), 'velho@teste.com', 'digest-velho',
  (select value::uuid from t_state where key = 'a1_id'),
  timezone('utc', now()) - interval '60 days'
);

insert into public.family_invites (family_id, email_normalized, token_digest, invited_by, expires_at)
values (
  (select value::uuid from t_state where key = 'family_a_id'), 'novo@teste.com', 'digest-novo',
  (select value::uuid from t_state where key = 'a1_id'),
  timezone('utc', now()) + interval '7 days'
);

select lives_ok(
  $$ select public.purge_stale_operational_data() $$,
  'purge_stale_operational_data roda sem erro'
);

select is_empty(
  $$ select 1 from public.family_invites where token_digest = 'digest-velho' $$,
  'Convite expirado há muito tempo é removido'
);

select results_eq(
  $$ select token_digest from public.family_invites where family_id = (select value::uuid from t_state where key = 'family_a_id') $$,
  $$ values ('digest-novo'::text) $$,
  'Convite recente não é removido'
);

select * from finish();

rollback;
