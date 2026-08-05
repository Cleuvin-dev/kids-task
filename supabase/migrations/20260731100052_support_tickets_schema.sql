-- Marco 7 (fatia 6) — módulo "Suporte" (docs/12 seção 9): tickets,
-- categoria e prioridade, timeline, resposta, encerramento, vínculo com
-- incidente.
--
-- Sem função PL/pgSQL nesta migration: como `rewards`/`consent_records`
-- (docs/14 seção 1: "sem regra de negócio crítica em campos simples não
-- precisa de função"), a única regra aqui é autorização por papel — já
-- coberta por `is_active_platform_admin` direto nas policies — mais os
-- `check` de enum nas próprias colunas. Sem idempotência, sem cascata
-- para outra tabela, sem notificação: RLS comum basta.
--
-- **Sem impersonação** (docs/12 seção 9) — nada aqui dá a um admin acesso
-- à sessão de um responsável ou criança; um ticket só referencia
-- `family_id` para contexto.
--
-- **Simplificação registrada**: "anexos privados" (docs/12 seção 9) fica
-- fora desta fatia. Seria o primeiro upload de arquivo de verdade do
-- projeto inteiro — nem `private_photo_path` (Marco 1) tem pipeline real
-- ainda — e exige decidir bucket do Supabase Storage, policies de
-- `storage.objects` e um seletor de arquivo no Flutter Web, uma decisão
-- técnica própria que não deveria ser encaixada como sub-item de outra
-- entrega. `support_ticket_messages` cobre timeline e resposta em texto
-- sem anexo por enquanto.
create table public.support_tickets (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid references public.families (id) on delete set null,
  subject text not null,
  category text not null check (category in ('billing', 'technical', 'account', 'content', 'other')),
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high', 'urgent')),
  status text not null default 'open' check (status in ('open', 'in_progress', 'waiting_on_family', 'resolved', 'closed')),
  incident_ref text,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  closed_at timestamptz
);

create index support_tickets_family_id_idx on public.support_tickets (family_id);
create index support_tickets_status_idx on public.support_tickets (status);

create trigger set_updated_at
  before update on public.support_tickets
  for each row execute function public.set_updated_at();

-- closed_at segue o status automaticamente: nunca fica dessincronizado de
-- um `update` manual que esqueceu de setar/limpar a coluna.
create or replace function public.sync_support_ticket_closed_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status in ('resolved', 'closed') and old.status not in ('resolved', 'closed') then
    new.closed_at := timezone('utc', now());
  elsif new.status not in ('resolved', 'closed') then
    new.closed_at := null;
  end if;
  return new;
end;
$$;

create trigger sync_closed_at
  before update on public.support_tickets
  for each row execute function public.sync_support_ticket_closed_at();

alter table public.support_tickets enable row level security;

create policy "support_tickets_select_admin" on public.support_tickets
  for select
  to authenticated
  using (public.is_active_platform_admin(array['super_admin', 'support']));

create policy "support_tickets_insert_admin" on public.support_tickets
  for insert
  to authenticated
  with check (
    public.is_active_platform_admin(array['super_admin', 'support'])
    and created_by = (select auth.uid())
  );

create policy "support_tickets_update_admin" on public.support_tickets
  for update
  to authenticated
  using (public.is_active_platform_admin(array['super_admin', 'support']))
  with check (public.is_active_platform_admin(array['super_admin', 'support']));

-- support_ticket_messages: timeline e resposta (docs/12 seção 9) — mesmo
-- padrão append-only de task_events/redemption_events, sem update/delete.
create table public.support_ticket_messages (
  id uuid primary key default extensions.gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets (id) on delete cascade,
  author_admin_id uuid not null references public.profiles (id),
  body text not null,
  created_at timestamptz not null default timezone('utc', now())
);

create index support_ticket_messages_ticket_id_idx on public.support_ticket_messages (ticket_id);

-- Uma nova mensagem "toca" o ticket, movendo-o para o topo de uma lista
-- ordenada por updated_at — sem isso, um ticket antigo com atividade nova
-- pareceria parado.
create or replace function public.touch_support_ticket_on_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.support_tickets set updated_at = timezone('utc', now()) where id = new.ticket_id;
  return new;
end;
$$;

create trigger touch_ticket_after_message
  after insert on public.support_ticket_messages
  for each row execute function public.touch_support_ticket_on_message();

alter table public.support_ticket_messages enable row level security;

create policy "support_ticket_messages_select_admin" on public.support_ticket_messages
  for select
  to authenticated
  using (public.is_active_platform_admin(array['super_admin', 'support']));

create policy "support_ticket_messages_insert_admin" on public.support_ticket_messages
  for insert
  to authenticated
  with check (
    public.is_active_platform_admin(array['super_admin', 'support'])
    and author_admin_id = (select auth.uid())
  );
