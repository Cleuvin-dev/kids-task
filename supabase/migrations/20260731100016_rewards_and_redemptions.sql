-- Marco 3 — KidsCoins e Recompensas (parte 1/4)
-- Catálogo de recompensas e ciclo de vida do resgate.
-- Ver docs/05_KIDSCOINS_RECOMPENSAS_XP_E_STREAK.md seções 4-5,
-- docs/09_MODELO_DE_DADOS.md seção 5.

create table public.rewards (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  -- null = recompensa compartilhada, disponível para qualquer criança da
  -- família (docs/09 seção 5).
  child_id uuid references public.child_profiles (id) on delete cascade,
  title text not null,
  description text,
  icon_key text not null default 'default',
  category text not null default 'geral',
  cost_coins integer not null check (cost_coins >= 0),
  cash_equivalent_cents integer check (cash_equivalent_cents >= 0),
  currency text not null default 'BRL',
  active boolean not null default true,
  created_by uuid not null default (select auth.uid()) references public.profiles (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

comment on table public.rewards is
  'Sem limite de estoque/quantidade de resgates no MVP (docs/05 seção 4). '
  'Uma recompensa inativa permanece no histórico — nunca é excluída, só '
  'desativada.';

create trigger set_updated_at
  before update on public.rewards
  for each row execute function public.set_updated_at();

create index rewards_family_active_idx
  on public.rewards (family_id)
  where active;

create table public.redemption_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  child_id uuid not null references public.child_profiles (id) on delete cascade,
  reward_id uuid not null references public.rewards (id),
  -- Snapshots: editar/desativar a recompensa depois não muda solicitações
  -- já feitas (mesmo princípio de imutabilidade do Marco 2).
  title_snapshot text not null,
  cost_snapshot integer not null check (cost_snapshot >= 0),
  status text not null default 'requested' check (status in (
    'requested', 'approved', 'rejected', 'delivered', 'cancelled'
  )),
  requested_at timestamptz not null default timezone('utc', now()),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles (id),
  rejection_reason text,
  delivered_at timestamptz,
  version integer not null default 1,
  idempotency_key text not null unique
);

comment on table public.redemption_requests is
  'Máquina de estados: requested -> approved|rejected; approved -> '
  'delivered|cancelled (docs/05 seção 5). KidsCoins só saem do saldo na '
  'aprovação, nunca na solicitação.';

create index redemption_requests_family_status_idx
  on public.redemption_requests (family_id, status);

create index redemption_requests_child_idx
  on public.redemption_requests (child_id);

create table public.redemption_events (
  id uuid primary key default extensions.gen_random_uuid(),
  redemption_id uuid not null references public.redemption_requests (id) on delete cascade,
  event_type text not null,
  actor uuid,
  actor_role text not null check (actor_role in ('guardian', 'child', 'system')),
  payload jsonb not null default '{}'::jsonb,
  idempotency_key text,
  created_at timestamptz not null default timezone('utc', now())
);

comment on table public.redemption_events is
  'Auditoria append-only das transições após a solicitação inicial '
  '(aprovar/rejeitar/entregar/cancelar), cada uma com sua própria '
  'idempotency_key — mesmo padrão de task_events do Marco 2.';

create unique index redemption_events_idempotency_key_idx
  on public.redemption_events (idempotency_key)
  where idempotency_key is not null;

create index redemption_events_redemption_id_idx
  on public.redemption_events (redemption_id);

alter table public.rewards enable row level security;
alter table public.redemption_requests enable row level security;
alter table public.redemption_events enable row level security;

-- rewards: sem regra de negócio além de autorização (nenhum limite diário
-- como em tasks), então CRUD simples via RLS é suficiente
-- (docs/14 seção 1: "operações simples... podem usar Data API com RLS").
create policy "rewards_select_guardian" on public.rewards
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = rewards.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

create policy "rewards_select_own_child" on public.rewards
  for select
  to authenticated
  using (
    rewards.active
    and exists (
      select 1 from public.child_device_bindings cdb
      join public.child_profiles cp on cp.id = cdb.child_id
      where cdb.auth_user_id = (select auth.uid())
        and cdb.revoked_at is null
        and cp.family_id = rewards.family_id
        and (rewards.child_id is null or rewards.child_id = cp.id)
    )
  );

create policy "rewards_insert_guardian" on public.rewards
  for insert
  to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (
      select 1 from public.family_members fm
      where fm.family_id = rewards.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
    and (
      rewards.child_id is null
      or exists (
        select 1 from public.child_profiles cp
        where cp.id = rewards.child_id and cp.family_id = rewards.family_id
      )
    )
  );

create policy "rewards_update_guardian" on public.rewards
  for update
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = rewards.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  )
  with check (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = rewards.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
    and (
      rewards.child_id is null
      or exists (
        select 1 from public.child_profiles cp
        where cp.id = rewards.child_id and cp.family_id = rewards.family_id
      )
    )
  );

-- redemption_requests: ciclo de vida crítico (mexe em saldo) — só leitura
-- via RLS, toda escrita passa por função (docs/14 seção 1 e seção 5).
create policy "redemption_requests_select_guardian" on public.redemption_requests
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = redemption_requests.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

create policy "redemption_requests_select_own_child" on public.redemption_requests
  for select
  to authenticated
  using (
    exists (
      select 1 from public.child_device_bindings cdb
      where cdb.child_id = redemption_requests.child_id
        and cdb.auth_user_id = (select auth.uid())
        and cdb.revoked_at is null
    )
  );

-- redemption_events: auditoria só para o responsável, mesmo padrão de
-- task_events.
create policy "redemption_events_select_guardian" on public.redemption_events
  for select
  to authenticated
  using (
    exists (
      select 1 from public.redemption_requests r
      join public.family_members fm on fm.family_id = r.family_id
      where r.id = redemption_events.redemption_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );
