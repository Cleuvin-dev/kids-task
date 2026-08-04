-- Marco 7 — Assinaturas e Entitlements (parte 1/4)
-- Modelo de dados: catálogo de produto↔loja↔entitlement, assinatura da
-- família e ledger append-only de eventos de assinatura.
-- Ver docs/13_ASSINATURAS_E_ENTITLEMENTS.md, docs/09 seção 6, docs/14 seção 7,
-- docs/02 seção 5 (downgrade seguro).

-- ---------------------------------------------------------------------
-- subscription_products: mapeamento versionado entre product_id da loja e
-- a regra de entitlement que ele concede (docs/13 seção 2: "Não usar o ID
-- como fonte única da regra. Manter mapeamento versionado entre produto,
-- loja e entitlement").
-- ---------------------------------------------------------------------
create table public.subscription_products (
  id uuid primary key default extensions.gen_random_uuid(),
  store text not null check (store in ('apple', 'google')),
  product_id text not null,
  plan_code text not null references public.plans (code),
  billing_period text not null check (billing_period in ('monthly', 'yearly')),
  -- Mapeamento é versionado: nunca dar update em plan_code numa linha
  -- ativa, sempre active=false + nova linha, para preservar o que uma
  -- assinatura histórica realmente comprou.
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

comment on table public.subscription_products is
  'IDs configuráveis por ambiente (docs/13 seção 2): kids_task_premium_monthly '
  'e kids_task_premium_yearly (opcional). Nunca decidir entitlement a partir '
  'do product_id em código; sempre consultar esta tabela.';

create unique index subscription_products_store_product_active_idx
  on public.subscription_products (store, product_id)
  where active;

alter table public.subscription_products enable row level security;

create policy "subscription_products_select_authenticated" on public.subscription_products
  for select
  to authenticated
  using (active);

-- Seed: nomes lógicos de docs/13 seção 2. IDs finais de loja em produção
-- ainda não existem (docs/18 seção 5) — este mapeamento é o nome lógico do
-- produto, substituível por configuração real sem migração de schema.
insert into public.subscription_products (store, product_id, plan_code, billing_period) values
  ('apple', 'kids_task_premium_monthly', 'premium', 'monthly'),
  ('apple', 'kids_task_premium_yearly', 'premium', 'yearly'),
  ('google', 'kids_task_premium_monthly', 'premium', 'monthly'),
  ('google', 'kids_task_premium_yearly', 'premium', 'yearly');

-- ---------------------------------------------------------------------
-- subscriptions: uma linha por família (entitlement é no nível da família,
-- docs/13 seção 1). Snapshot verificável do estado confiável.
-- ---------------------------------------------------------------------
create table public.subscriptions (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null unique references public.families (id) on delete cascade,
  store text not null check (store in ('apple', 'google', 'none')),
  product_id text,
  -- Identificador estável da assinatura na loja (originalTransactionId da
  -- Apple / assinatura vinculada ao purchaseToken do Google).
  original_transaction_id text,
  status text not null default 'free' check (status in (
    'free', 'trialing', 'active', 'grace_period', 'billing_retry',
    'cancelled_active_until_end', 'expired', 'revoked', 'support_override'
  )),
  current_period_end timestamptz,
  grace_period_end timestamptz,
  auto_renew boolean not null default false,
  -- Compra vinculada ao responsável autenticado que a realizou
  -- (docs/13 seção 10: "vincular compra à família do responsável autenticado").
  purchased_by uuid references public.profiles (id),
  environment text not null default 'sandbox' check (environment in ('sandbox', 'production')),
  last_verified_at timestamptz,
  -- Estado local pendente enquanto o backend não confirma (docs/13 seção 9:
  -- "backend indisponível após compra: registrar estado local pendente").
  pending_verification boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

comment on table public.subscriptions is
  'Uma linha por família, sempre existe (criada junto com create_family via '
  'create_family_subscription_after_insert, status=free/store=none). '
  'Snapshot; nunca a única fonte de verdade de "o que foi comprado" — '
  'subscription_events preserva o histórico bruto da loja (docs/13 seção 5).';

create trigger set_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();

create index subscriptions_original_transaction_id_idx
  on public.subscriptions (original_transaction_id)
  where original_transaction_id is not null;

alter table public.subscriptions enable row level security;

create policy "subscriptions_select_guardian" on public.subscriptions
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = subscriptions.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

-- Sem policy de insert/update: escrita só via submit_purchase_receipt /
-- verify_purchase / handle_apple_notification / handle_google_notification /
-- apply_subscription_transition / apply_safe_downgrade (todas security
-- definer). A criança nunca acessa (docs/13 seção 10: "impedir que criança
-- acesse fluxo" — sem policy via child_device_bindings aqui).

-- ---------------------------------------------------------------------
-- subscription_events: ledger append-only, mesmo padrão de coin_ledger/
-- task_events. store_event_id garante idempotência de webhook (docs/13
-- seção 6: "evento duplicado: idempotência").
-- ---------------------------------------------------------------------
create table public.subscription_events (
  id uuid primary key default extensions.gen_random_uuid(),
  -- Nullable (foge do padrão usual de ledger `not null`): um webhook pode
  -- chegar para uma original_transaction_id que este backend nunca viu
  -- (ex.: compra direta na loja antes de qualquer submit_purchase_receipt).
  -- docs/13 seção 6 exige persistir todo evento antes de processar, mesmo
  -- os órfãos, então family_id precisa poder ficar em aberto.
  family_id uuid references public.families (id) on delete cascade,
  store text not null check (store in ('apple', 'google', 'internal')),
  -- 'internal' cobre eventos gerados dentro do backend (support_override,
  -- downgrade automático) que não vieram de webhook de loja.
  event_type text not null check (event_type in (
    'purchase', 'renewal', 'cancellation', 'expiration', 'refund',
    'revocation', 'product_change', 'grace_period_started', 'billing_recovered',
    'verification', 'restore', 'support_override_granted', 'support_override_revoked',
    'safe_downgrade_applied'
  )),
  -- Identificador único do evento na loja (Apple notificationUUID, Google
  -- Play RTDN message id) ou uma chave interna determinística para eventos
  -- 'internal'. É a trava de idempotência (docs/13 seção 6).
  store_event_id text not null,
  store_event_at timestamptz,
  -- Estado bruto reportado pela loja no momento do evento, para permitir
  -- reprocessamento e comparação de versão/data em webhook fora de ordem
  -- (docs/13 seção 9).
  payload jsonb not null default '{}'::jsonb,
  processing_status text not null default 'processed' check (processing_status in (
    'processed', 'ignored_out_of_order', 'ignored_invalid', 'pending_review'
  )),
  idempotency_key text,
  created_at timestamptz not null default timezone('utc', now())
);

comment on table public.subscription_events is
  'Append-only. Nunca UPDATE/DELETE de cliente (processing_status é a única '
  'coluna que funções internas ajustam depois do insert, para registrar '
  'evento fora de ordem/ inválido sem apagar o histórico). store_event_id '
  'garante que reprocessar o mesmo webhook é no-op (docs/13 seção 6).';

create unique index subscription_events_store_event_id_idx
  on public.subscription_events (store, store_event_id);

create unique index subscription_events_idempotency_key_idx
  on public.subscription_events (idempotency_key)
  where idempotency_key is not null;

create index subscription_events_family_id_idx
  on public.subscription_events (family_id, created_at desc);

alter table public.subscription_events enable row level security;

create policy "subscription_events_select_guardian" on public.subscription_events
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = subscription_events.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

-- Sem policy de insert/update/delete: só as funções de webhook/verificação
-- (security definer) escrevem aqui — mesmo padrão de task_events/coin_ledger.

-- ---------------------------------------------------------------------
-- families.primary_child_id: criança escolhida para permanecer ativa no
-- downgrade seguro (docs/02 seção 5, itens 2-3). Nulo até haver downgrade
-- ou até o responsável escolher proativamente.
-- ---------------------------------------------------------------------
alter table public.families
  add column primary_child_id uuid references public.child_profiles (id);

comment on column public.families.primary_child_id is
  'Criança que permanece ativa em caso de downgrade para o plano gratuito '
  '(docs/02 seção 5). Se nula no momento do downgrade, apply_safe_downgrade '
  'escolhe a primeira criança criada e preenche esta coluna automaticamente.';

-- ---------------------------------------------------------------------
-- task_occurrences.status ganha 'plan_paused': ocorrência excedente pausada
-- por limite de plano (docs/02 seção 5, item 5: "Ocorrências excedentes são
-- pausadas, nunca excluídas"). Nenhum dos 7 estados do Marco 2 cobre esse
-- significado (cancelled é decisão do responsável, não limite de plano).
-- Extensão do enum existente numa migration nova, sem editar o arquivo
-- original do Marco 2 (20260731100008) — mesmo padrão já usado em
-- 20260731100020 para coin_ledger.entry_type.
-- ---------------------------------------------------------------------
alter table public.task_occurrences drop constraint task_occurrences_status_check;
alter table public.task_occurrences add constraint task_occurrences_status_check check (
  status in (
    'pending', 'awaiting_approval', 'approved', 'late', 'expired',
    'needs_correction', 'cancelled', 'skipped_by_guardian', 'plan_paused'
  )
);

comment on column public.task_occurrences.status is
  'plan_paused (Marco 7): ocorrência que existiria mas excede o limite '
  'diário do plano atual da família. Reativada por '
  'restore_paused_entitlements quando o plano volta a Premium.';

-- ---------------------------------------------------------------------
-- Cria a assinatura (status=free) automaticamente junto com a família, para
-- que apply_subscription_transition e v_effective_entitlements sempre
-- encontrem uma linha — mesmo padrão de create_child_wallet_after_insert
-- em 20260731100009_wallet_and_ledgers.sql. create_family() (Marco 1) fica
-- intocado.
-- ---------------------------------------------------------------------
create or replace function public.create_family_subscription()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.subscriptions (family_id, store, status)
  values (new.id, 'none', 'free')
  on conflict (family_id) do nothing;
  return new;
end;
$$;

create trigger create_family_subscription_after_insert
  after insert on public.families
  for each row execute function public.create_family_subscription();
