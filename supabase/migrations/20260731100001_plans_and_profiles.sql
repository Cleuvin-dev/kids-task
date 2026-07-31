-- Marco 1 — Autenticação e Família (parte 1/4)
-- Tabelas de referência de plano e perfil de usuário responsável.
-- Ver docs/09_MODELO_DE_DADOS.md seções 2 e 6, docs/02_ESCOPO_MVP_E_PLANOS.md.

create table public.plans (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique check (code in ('free', 'premium')),
  max_active_children integer not null check (max_active_children > 0),
  max_daily_occurrences integer not null check (max_daily_occurrences > 0),
  entitlements_json jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

comment on table public.plans is
  'Planos gratuito/Premium. Limites lidos daqui, nunca fixados na UI '
  '(CLAUDE.md: "Valores de plano... não devem ficar espalhados ou fixados na interface").';

create trigger set_updated_at
  before update on public.plans
  for each row execute function public.set_updated_at();

-- Uso justo do Premium: limites técnicos altos, não comerciais
-- (docs/18_PENDENCIAS_NAO_BLOQUEANTES.md, seção 1).
insert into public.plans (code, max_active_children, max_daily_occurrences, entitlements_json) values
  ('free', 1, 3, '{"themes": ["kids_default", "block_world"], "advanced_reports": false, "theme_requests": false}'),
  ('premium', 20, 200, '{"themes": "all_published", "advanced_reports": true, "theme_requests": true}');

alter table public.plans enable row level security;

-- Planos são referência pública somente leitura para qualquer usuário
-- autenticado (necessário para exibir a matriz de planos/paywall).
create policy "plans_select_authenticated" on public.plans
  for select
  to authenticated
  using (true);

-- ---------------------------------------------------------------------
-- profiles: um registro por usuário do Supabase Auth (somente responsáveis
-- e administradores de plataforma; a criança nunca tem linha aqui, sua
-- identidade técnica é anônima e vive em child_device_bindings).
-- ---------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  locale text not null default 'pt-BR',
  status text not null default 'active' check (status in ('active', 'blocked', 'deleted')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create trigger set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;

create policy "profiles_select_own" on public.profiles
  for select
  to authenticated
  using (id = (select auth.uid()));

create policy "profiles_update_own" on public.profiles
  for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Cria o profile automaticamente quando um responsável confirma cadastro no
-- Supabase Auth. display_name vem de raw_user_meta_data (definido no
-- signUp do cliente); nunca coletamos gênero neste formulário (CLAUDE.md).
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();
