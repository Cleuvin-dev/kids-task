-- Marco 7 (fatia 6) — testes do módulo "Suporte" do painel: RLS por
-- papel (create/read/update), timeline de mensagens, sincronização de
-- `closed_at` com o status, constraints de enum, ticket sem família
-- vinculada (docs/12 seção 9).
begin;

select plan(18);

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

-- ---------------------------------------------------------------------
-- Fixtures: família A.
-- ---------------------------------------------------------------------
select pg_temp.act_as('a1_id');

insert into t_state (key, value)
select 'family_a_id', family_id::text from public.create_family('Familia A', 'America/Sao_Paulo', 'blue');

-- ---------------------------------------------------------------------
-- 1) Criação de ticket: papel e RLS.
-- ---------------------------------------------------------------------
select pg_temp.act_as('admin_support_id');

with new_ticket as (
  insert into public.support_tickets (family_id, subject, category, priority, incident_ref, created_by)
  values (
    (select value::uuid from t_state where key = 'family_a_id'),
    'Responsável não recebe convite por e-mail', 'technical', 'high', 'INC-042',
    (select value::uuid from t_state where key = 'admin_support_id')
  )
  returning id
)
insert into t_state (key, value)
select 'ticket_id', id::text from new_ticket;

select results_eq(
  $$ select subject, status from public.support_tickets
     where id = (select value::uuid from t_state where key = 'ticket_id') $$,
  $$ values ('Responsável não recebe convite por e-mail'::text, 'open'::text) $$,
  'support cria o ticket, que nasce com status open'
);

select pg_temp.act_as('admin_billing_id');

select is_empty(
  $$ select 1 from public.support_tickets
     where id = (select value::uuid from t_state where key = 'ticket_id') $$,
  'billing não enxerga tickets (fora do papel permitido)'
);

select throws_ok(
  $$ insert into public.support_tickets (family_id, subject, category, created_by)
     values (
       (select value::uuid from t_state where key = 'family_a_id'), 'Teste', 'technical',
       (select value::uuid from t_state where key = 'admin_billing_id')
     ) $$,
  '42501',
  'billing não pode criar ticket (violação de RLS)'
);

select pg_temp.act_as('admin_content_id');

select is_empty(
  $$ select 1 from public.support_tickets
     where id = (select value::uuid from t_state where key = 'ticket_id') $$,
  'content não enxerga tickets (fora do papel permitido)'
);

select pg_temp.act_as('a1_id');

select is_empty(
  $$ select 1 from public.support_tickets
     where id = (select value::uuid from t_state where key = 'ticket_id') $$,
  'Um responsável comum não enxerga tickets'
);

select throws_ok(
  $$ insert into public.support_tickets (family_id, subject, category, created_by)
     values (
       (select value::uuid from t_state where key = 'family_a_id'), 'Teste', 'technical',
       (select value::uuid from t_state where key = 'a1_id')
     ) $$,
  '42501',
  'Um responsável comum não pode criar ticket (violação de RLS)'
);

-- ---------------------------------------------------------------------
-- 2) Timeline: mensagens (resposta).
-- ---------------------------------------------------------------------
select pg_temp.act_as('admin_support_id');

select lives_ok(
  $$ insert into public.support_ticket_messages (ticket_id, author_admin_id, body)
     values (
       (select value::uuid from t_state where key = 'ticket_id'),
       (select value::uuid from t_state where key = 'admin_support_id'),
       'Reenviamos o convite manualmente, aguardando confirmação.'
     ) $$,
  'support adiciona uma mensagem à timeline do ticket'
);

select results_eq(
  $$ select body from public.support_ticket_messages
     where ticket_id = (select value::uuid from t_state where key = 'ticket_id') $$,
  $$ values ('Reenviamos o convite manualmente, aguardando confirmação.'::text) $$,
  'A mensagem aparece na timeline do ticket'
);

select pg_temp.act_as('admin_billing_id');

select throws_ok(
  $$ insert into public.support_ticket_messages (ticket_id, author_admin_id, body)
     values (
       (select value::uuid from t_state where key = 'ticket_id'),
       (select value::uuid from t_state where key = 'admin_billing_id'),
       'Não deveria conseguir'
     ) $$,
  '42501',
  'billing não pode adicionar mensagem (violação de RLS)'
);

-- ---------------------------------------------------------------------
-- 3) Status e sincronização de closed_at (encerramento/reabertura).
-- ---------------------------------------------------------------------
select pg_temp.act_as('admin_support_id');

select results_eq(
  $$ update public.support_tickets set status = 'resolved'
     where id = (select value::uuid from t_state where key = 'ticket_id')
     returning status $$,
  $$ values ('resolved'::text) $$,
  'support marca o ticket como resolvido'
);

select ok(
  (select closed_at is not null from public.support_tickets
   where id = (select value::uuid from t_state where key = 'ticket_id')),
  'Encerrar o ticket preenche closed_at automaticamente'
);

select results_eq(
  $$ update public.support_tickets set status = 'open'
     where id = (select value::uuid from t_state where key = 'ticket_id')
     returning status $$,
  $$ values ('open'::text) $$,
  'support reabre o ticket'
);

select ok(
  (select closed_at is null from public.support_tickets
   where id = (select value::uuid from t_state where key = 'ticket_id')),
  'Reabrir o ticket limpa closed_at automaticamente'
);

select pg_temp.act_as('admin_billing_id');

select throws_ok(
  $$ update public.support_tickets set status = 'closed'
     where id = (select value::uuid from t_state where key = 'ticket_id') $$,
  '42501',
  'billing não pode alterar status do ticket (violação de RLS)'
);

-- ---------------------------------------------------------------------
-- 4) Constraints de enum.
-- ---------------------------------------------------------------------
select pg_temp.act_as('admin_support_id');

select throws_ok(
  $$ insert into public.support_tickets (family_id, subject, category, created_by)
     values (
       (select value::uuid from t_state where key = 'family_a_id'), 'Teste', 'categoria_invalida',
       (select value::uuid from t_state where key = 'admin_support_id')
     ) $$,
  '23514',
  'Categoria inválida é rejeitada pelo check constraint'
);

select throws_ok(
  $$ insert into public.support_tickets (family_id, subject, category, priority, created_by)
     values (
       (select value::uuid from t_state where key = 'family_a_id'), 'Teste', 'technical', 'critica',
       (select value::uuid from t_state where key = 'admin_support_id')
     ) $$,
  '23514',
  'Prioridade inválida é rejeitada pelo check constraint'
);

select throws_ok(
  $$ update public.support_tickets set status = 'arquivado'
     where id = (select value::uuid from t_state where key = 'ticket_id') $$,
  '23514',
  'Status inválido é rejeitado pelo check constraint'
);

-- ---------------------------------------------------------------------
-- 5) Ticket sem família vinculada (consulta geral).
-- ---------------------------------------------------------------------
select results_eq(
  $$ insert into public.support_tickets (family_id, subject, category, created_by)
     values (
       null, 'Dúvida geral sobre planos', 'other',
       (select value::uuid from t_state where key = 'admin_support_id')
     )
     returning family_id $$,
  $$ values (null::uuid) $$,
  'Um ticket pode existir sem família vinculada'
);

select * from finish();

rollback;
