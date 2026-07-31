-- Marco 1 — Autenticação e Família (parte 3/4)
-- Perfil da criança, vínculo de aparelho e registro de consentimento.
-- Ver docs/09 seção 2, docs/03 seções 6-7, docs/10 seção 4, ADR 0001.

create table public.child_profiles (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  first_name text not null,
  nickname text,
  birth_date date not null,
  avatar_id text not null default 'default',
  private_photo_path text,
  pin_hash text,
  pin_enabled boolean not null default false,
  -- Sem FK para uma tabela `themes` ainda inexistente (chega no Marco 5).
  -- O slug já segue o catálogo real de docs/06 seção 3.
  theme_slug text not null default 'kids_default',
  age_mode text not null check (age_mode in ('young', 'middle', 'teen')),
  streak_rule text not null default 'at_least_one' check (streak_rule in ('at_least_one', 'all_required', 'percentage')),
  streak_percentage smallint not null default 80 check (streak_percentage between 1 and 100),
  level_bonus_coins integer not null default 5 check (level_bonus_coins >= 0),
  birthday_bonus_coins integer not null default 50 check (birthday_bonus_coins >= 0),
  status text not null default 'active' check (status in ('active', 'plan_paused', 'archived')),
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

comment on table public.child_profiles is
  'Sem coluna de gênero: o Kid''s Task não coleta gênero (CLAUDE.md).';

create trigger set_updated_at
  before update on public.child_profiles
  for each row execute function public.set_updated_at();

-- Índice parcial para aplicar o limite "uma criança ativa" do plano
-- gratuito de forma eficiente (a validação de negócio fica na função
-- create_child; este índice só acelera a contagem).
create index child_profiles_family_active_idx
  on public.child_profiles (family_id)
  where status = 'active';

create table public.child_device_bindings (
  id uuid primary key default extensions.gen_random_uuid(),
  child_id uuid not null references public.child_profiles (id) on delete cascade,
  auth_user_id uuid not null,
  device_name text not null,
  authorized_by uuid references public.profiles (id),
  authorized_at timestamptz not null default timezone('utc', now()),
  last_seen_at timestamptz not null default timezone('utc', now()),
  revoked_at timestamptz
);

comment on column public.child_device_bindings.auth_user_id is
  'auth.uid() da sessão anônima do aparelho. Não referencia auth.users por '
  'FK direta para evitar acoplamento rígido com o schema interno do GoTrue; '
  'a integridade é garantida pela Edge Function authorize_child_device.';

-- Uma identidade técnica ativa não pode apontar para mais de uma criança/família
-- ao mesmo tempo (docs/09 seção 2: "Restrição: uma identidade técnica ativa
-- não pode apontar para várias famílias").
create unique index child_device_bindings_one_active_per_auth_user
  on public.child_device_bindings (auth_user_id)
  where revoked_at is null;

create index child_device_bindings_child_id_idx on public.child_device_bindings (child_id);

create table public.consent_records (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  guardian_profile_id uuid not null references public.profiles (id),
  document text not null,
  document_version text not null,
  purpose text not null,
  status text not null default 'granted' check (status in ('granted', 'revoked')),
  created_at timestamptz not null default timezone('utc', now()),
  revoked_at timestamptz
);

create index consent_records_family_id_idx on public.consent_records (family_id);

alter table public.child_profiles enable row level security;
alter table public.child_device_bindings enable row level security;
alter table public.consent_records enable row level security;

-- child_profiles: responsáveis da família administram; a própria criança
-- (via vínculo de aparelho ativo) só lê o próprio perfil.
create policy "child_profiles_select_guardian" on public.child_profiles
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = child_profiles.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

create policy "child_profiles_select_own_child" on public.child_profiles
  for select
  to authenticated
  using (
    exists (
      select 1 from public.child_device_bindings cdb
      where cdb.child_id = child_profiles.id
        and cdb.auth_user_id = (select auth.uid())
        and cdb.revoked_at is null
    )
  );

create policy "child_profiles_write_guardian" on public.child_profiles
  for update
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = child_profiles.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  )
  with check (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = child_profiles.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

-- Sem policy de INSERT: criação só via create_child() (valida limite do plano
-- na mesma transação, evitando corrida entre checagem e escrita).

-- child_device_bindings: só responsáveis da família enxergam/gerenciam
-- (docs/03 seção 6: "nome do aparelho e última atividade visíveis ao
-- responsável"). A criança nunca lista os próprios vínculos.
create policy "child_device_bindings_select_guardian" on public.child_device_bindings
  for select
  to authenticated
  using (
    exists (
      select 1 from public.child_profiles cp
      join public.family_members fm on fm.family_id = cp.family_id
      where cp.id = child_device_bindings.child_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

create policy "child_device_bindings_update_guardian" on public.child_device_bindings
  for update
  to authenticated
  using (
    exists (
      select 1 from public.child_profiles cp
      join public.family_members fm on fm.family_id = cp.family_id
      where cp.id = child_device_bindings.child_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  )
  with check (
    exists (
      select 1 from public.child_profiles cp
      join public.family_members fm on fm.family_id = cp.family_id
      where cp.id = child_device_bindings.child_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

-- A própria criança pode ler o próprio vínculo ativo (necessário para o app
-- redescobrir seu child_id ao reabrir, sem listar aparelhos alheios nem
-- outros vínculos da mesma criança).
create policy "child_device_bindings_select_own" on public.child_device_bindings
  for select
  to authenticated
  using (
    auth_user_id = (select auth.uid())
    and revoked_at is null
  );

-- consent_records: responsáveis da família consultam o próprio histórico.
create policy "consent_records_select_guardian" on public.consent_records
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = consent_records.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

create policy "consent_records_insert_guardian" on public.consent_records
  for insert
  to authenticated
  with check (
    guardian_profile_id = (select auth.uid())
    and exists (
      select 1 from public.family_members fm
      where fm.family_id = consent_records.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );
