-- Marco 8 — Privacidade e release: fluxo de exclusão dupla da família
-- (docs/09 seção 8, docs/10 seção 10, docs/15 seção 13).
--
-- "Dupla" é sobre aprovação: com dois ou mais responsáveis ativos, um pede
-- e outro aprova/rejeita; com um único responsável, a confirmação forte do
-- próprio já basta (docs/10 seção 10, "Com um único responsável"). As duas
-- rotas usam a mesma tabela — `requires_second_approval` documenta qual
-- caminho valeu no momento do pedido (não recalculado depois, mesmo
-- princípio de imutabilidade de snapshot usado em tarefas/recompensas).
create table public.deletion_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  requested_by uuid not null references public.profiles (id),
  requires_second_approval boolean not null,
  status text not null default 'pending_approval' check (status in (
    'pending_approval', 'approved', 'rejected', 'cancelled', 'completed'
  )),
  second_guardian_id uuid references public.profiles (id),
  second_guardian_responded_at timestamptz,
  rejection_reason text,
  scheduled_for timestamptz,
  cancelled_by uuid references public.profiles (id),
  cancelled_at timestamptz,
  completed_at timestamptz,
  idempotency_key text unique,
  created_at timestamptz not null default timezone('utc', now())
);

comment on table public.deletion_requests is
  'Fluxo de exclusão dupla (docs/10 seção 10). Escrita só via '
  'request_family_deletion/respond_family_deletion/cancel_family_deletion/'
  'process_scheduled_deletions — sem policy de insert/update, mesmo padrão '
  'de tabelas com regra de negócio crítica (docs/14 seção 1).';

-- Uma família só pode ter um pedido "em jogo" por vez — evita dois
-- pedidos concorrentes brigando por segundo-aprovador/cron.
create unique index deletion_requests_one_active_per_family
  on public.deletion_requests (family_id)
  where status in ('pending_approval', 'approved');

create index deletion_requests_scheduled_idx
  on public.deletion_requests (scheduled_for)
  where status = 'approved';

alter table public.deletion_requests enable row level security;

-- Qualquer responsável ativo da família enxerga o pedido — quem pediu,
-- quem precisa responder, e qualquer um pode acompanhar/cancelar.
create policy "deletion_requests_select_guardian" on public.deletion_requests
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = deletion_requests.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );
