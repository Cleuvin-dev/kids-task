-- Testes de fundação (pgTAP). Executar com `supabase test db` (requer stack
-- local via Docker). Provam que a migration 20260731000001 aplicou
-- corretamente antes de qualquer schema de domínio existir.
begin;

select plan(3);

select has_extension('pgcrypto', 'pgcrypto deve estar habilitada');

select isnt(
  extensions.gen_random_uuid(),
  extensions.gen_random_uuid(),
  'gen_random_uuid() deve gerar valores distintos a cada chamada'
);

select has_function(
  'public', 'set_updated_at', array[]::text[],
  'a função utilitária set_updated_at() deve existir para uso em triggers'
);

select * from finish();

rollback;
