-- Marco 7 (fatia 4) — Módulo "Famílias e usuários" do painel (docs/12
-- seção 11: bloquear uma família "exige motivo... permite revisão e
-- reversão auditada"). `audit_logs` (fatia 2) já registra "quem, quando,
-- por quê" para qualquer ação administrativa, mas é genérica entre
-- módulos; esta tabela é o ledger append-only específico do agregado
-- "status da família" — mesmo padrão de `subscription_events`,
-- `task_events`, `redemption_events` — e é o que dá idempotência real a
-- `admin_set_family_status` (próxima migration), não `audit_logs`.
create table public.family_status_events (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  previous_status text not null,
  new_status text not null,
  reason text not null,
  changed_by uuid not null references public.profiles (id),
  idempotency_key text not null unique,
  created_at timestamptz not null default timezone('utc', now())
);

create index family_status_events_family_id_idx on public.family_status_events (family_id);

alter table public.family_status_events enable row level security;

-- Só leitura administrativa (super_admin/support — docs/12 seção 11 é uma
-- ação de suporte/segurança, billing fica de fora, mesmo raciocínio de
-- não dar a billing acesso a aparelhos/consentimentos). Sem policy de
-- insert/update/delete: escrita só via admin_set_family_status.
create policy "family_status_events_select_admin" on public.family_status_events
  for select
  to authenticated
  using (public.is_active_platform_admin(array['super_admin', 'support']));
