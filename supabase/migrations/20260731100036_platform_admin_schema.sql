-- Marco 7 (fatia 2) — Fundação do painel Web: administradores da
-- plataforma e trilha de auditoria (docs/12_PAINEL_ADMINISTRATIVO_WEB.md
-- seções 2 e 10, docs/09_MODELO_DE_DADOS.md seção 8, docs/10 seção 7).
--
-- Provisionar um administrador é operação manual (service_role) nesta
-- fatia: não existe autocadastro nem módulo de gestão de papéis ainda —
-- fica para uma fatia futura do Marco 7, junto do restante do painel.
-- Condiz com "conta separada, sem impersonação silenciosa" (docs/10 seção
-- 7): dar alta de administrador não pode ser uma ação de RLS de cliente.

create table public.platform_admins (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  role text not null check (role in ('super_admin', 'support', 'content', 'billing')),
  mfa_required boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create trigger set_updated_at
  before update on public.platform_admins
  for each row execute function public.set_updated_at();

alter table public.platform_admins enable row level security;

-- Só a própria linha: o painel usa isto para resolver "eu sou admin? qual
-- papel? MFA é exigido?" (mesmo espírito de family_members no app móvel) —
-- nunca lista outros administradores por aqui.
create policy "platform_admins_select_own" on public.platform_admins
  for select
  to authenticated
  using (profile_id = (select auth.uid()));

-- Sem policy de insert/update/delete: só service_role nesta fatia.

create table public.audit_logs (
  id uuid primary key default extensions.gen_random_uuid(),
  actor_profile_id uuid references public.profiles (id),
  actor_role text not null,
  action text not null,
  resource_type text not null,
  resource_id text,
  result text not null check (result in ('success', 'failure')),
  request_id text,
  ip_hash text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

comment on table public.audit_logs is
  'Trilha append-only de ações administrativas (docs/12 seção 10). Nesta '
  'fatia o único chamador real de record_admin_audit_log() é a '
  'verificação de MFA no login — os módulos que geram a maior parte dos '
  'eventos (famílias, conteúdo, assinaturas, suporte) chegam em fatias '
  'futuras do Marco 7 e devem reaproveitar a mesma função.';

create index audit_logs_actor_idx on public.audit_logs (actor_profile_id, created_at desc);

alter table public.audit_logs enable row level security;

-- Um administrador ativo sempre pode ver as próprias ações.
create policy "audit_logs_select_own" on public.audit_logs
  for select
  to authenticated
  using (
    actor_profile_id = (select auth.uid())
    and exists (
      select 1 from public.platform_admins pa
      where pa.profile_id = (select auth.uid()) and pa.active
    )
  );

-- super_admin tem visão completa (docs/12 seção 2: "administração geral").
create policy "audit_logs_select_super_admin" on public.audit_logs
  for select
  to authenticated
  using (
    exists (
      select 1 from public.platform_admins pa
      where pa.profile_id = (select auth.uid())
        and pa.active
        and pa.role = 'super_admin'
    )
  );

-- Sem policy de insert/update/delete: só via record_admin_audit_log
-- (security definer, mesmo padrão de grant_task_rewards) — auditoria
-- nunca é editável ou apagável pelo cliente.
