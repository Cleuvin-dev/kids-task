-- Marco 0 — Fundação: extensões e utilitários reutilizados por todas as
-- migrations futuras. Não cria nenhuma tabela de domínio (isso começa no
-- Marco 1, em docs/16_BACKLOG_E_ROADMAP.md).

-- pgcrypto fornece gen_random_uuid(), usado como default de todo PK uuid
-- (docs/09_MODELO_DE_DADOS.md, seção 1: "IDs: UUID").
create extension if not exists pgcrypto with schema extensions;

-- Função utilitária para manter `updated_at` sempre em UTC e atualizado pelo
-- servidor, nunca pelo cliente. `search_path` fixo e vazio evita sequestro de
-- função conforme docs/09 seção 10 ("não usar security definer sem
-- search_path fixo").
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

comment on function public.set_updated_at() is
  'Trigger BEFORE UPDATE genérico: mantém updated_at em UTC. Uso: '
  'create trigger set_updated_at before update on <tabela> '
  'for each row execute function public.set_updated_at();';
