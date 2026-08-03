-- Marco 2 — Rotina e Tarefas (parte 2/8)
-- Carteira mínima da criança e ledgers imutáveis de KidsCoins/XP.
-- Ver docs/04 seção 6 e 8, docs/09_MODELO_DE_DADOS.md seção 4.
--
-- Escopo deste marco: só o crédito atômico ao aprovar uma ocorrência.
-- Catálogo de recompensas/resgate e ajuste manual de moedas (Marco 3),
-- cálculo de nível e streak (Marco 4) ficam fora daqui.

create table public.child_wallets (
  child_id uuid primary key references public.child_profiles (id) on delete cascade,
  family_id uuid not null references public.families (id) on delete cascade,
  coin_balance integer not null default 0 check (coin_balance >= 0),
  total_xp integer not null default 0 check (total_xp >= 0),
  -- Placeholder para o Marco 4 (nível/progressão): nunca escrito neste
  -- marco, mantido aqui só para evitar um `alter table` futuro.
  current_level integer not null default 1 check (current_level >= 1),
  version integer not null default 1,
  updated_at timestamptz not null default timezone('utc', now())
);

comment on table public.child_wallets is
  'Cache transacional do saldo. Os ledgers (coin_ledger/xp_ledger) são a '
  'trilha financeira real (docs/09 seção 4). Só grant_task_rewards escreve '
  'aqui.';

create trigger set_updated_at
  before update on public.child_wallets
  for each row execute function public.set_updated_at();

-- Cria a carteira automaticamente ao criar a criança, para que
-- grant_task_rewards sempre encontre uma linha para atualizar.
create or replace function public.create_child_wallet()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.child_wallets (child_id, family_id)
  values (new.id, new.family_id)
  on conflict (child_id) do nothing;
  return new;
end;
$$;

create trigger create_child_wallet_after_insert
  after insert on public.child_profiles
  for each row execute function public.create_child_wallet();

create table public.coin_ledger (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  child_id uuid not null references public.child_profiles (id) on delete cascade,
  -- 'level_bonus'/'birthday_bonus' (Marco 4) e 'admin_correction' (Marco 7)
  -- ainda não existem.
  entry_type text not null check (
    entry_type in (
      'task_reward', 'manual_adjustment', 'redemption', 'redemption_refund'
    )
  ),
  amount_signed integer not null,
  balance_after integer not null check (balance_after >= 0),
  source_type text not null default 'task_occurrence',
  source_id uuid not null,
  reason text,
  created_by uuid,
  created_at timestamptz not null default timezone('utc', now()),
  idempotency_key text not null
);

comment on table public.coin_ledger is
  'Restrição única por (source_id, entry_type) garante recompensa exatamente '
  'uma vez por ocorrência, mesmo sob duplo-tap ou duplo-approve simultâneo '
  '(docs/04 seção 8).';

create unique index coin_ledger_source_entry_idx
  on public.coin_ledger (source_id, entry_type);

create unique index coin_ledger_idempotency_key_idx
  on public.coin_ledger (idempotency_key);

create index coin_ledger_child_id_idx on public.coin_ledger (child_id);

create table public.xp_ledger (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  child_id uuid not null references public.child_profiles (id) on delete cascade,
  amount integer not null check (amount >= 0),
  total_after integer not null check (total_after >= 0),
  source_type text not null default 'task_occurrence',
  source_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  idempotency_key text not null
);

create unique index xp_ledger_source_idx on public.xp_ledger (source_id);
create unique index xp_ledger_idempotency_key_idx on public.xp_ledger (idempotency_key);
create index xp_ledger_child_id_idx on public.xp_ledger (child_id);

alter table public.child_wallets enable row level security;
alter table public.coin_ledger enable row level security;
alter table public.xp_ledger enable row level security;

create policy "child_wallets_select_guardian" on public.child_wallets
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = child_wallets.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

create policy "child_wallets_select_own_child" on public.child_wallets
  for select
  to authenticated
  using (
    exists (
      select 1 from public.child_device_bindings cdb
      where cdb.child_id = child_wallets.child_id
        and cdb.auth_user_id = (select auth.uid())
        and cdb.revoked_at is null
    )
  );

-- Sem policy de insert/update: só create_child_wallet (trigger) e
-- grant_task_rewards escrevem.

create policy "coin_ledger_select_guardian" on public.coin_ledger
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = coin_ledger.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

create policy "coin_ledger_select_own_child" on public.coin_ledger
  for select
  to authenticated
  using (
    exists (
      select 1 from public.child_device_bindings cdb
      where cdb.child_id = coin_ledger.child_id
        and cdb.auth_user_id = (select auth.uid())
        and cdb.revoked_at is null
    )
  );

create policy "xp_ledger_select_guardian" on public.xp_ledger
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = xp_ledger.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

create policy "xp_ledger_select_own_child" on public.xp_ledger
  for select
  to authenticated
  using (
    exists (
      select 1 from public.child_device_bindings cdb
      where cdb.child_id = xp_ledger.child_id
        and cdb.auth_user_id = (select auth.uid())
        and cdb.revoked_at is null
    )
  );

-- Sem policy de insert/update/delete em nenhum dos dois ledgers: só
-- grant_task_rewards (security definer, interna) escreve.
