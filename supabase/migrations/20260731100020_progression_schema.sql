-- Marco 4 — XP e Progressão (parte 1/5)
-- Definição de níveis, progresso diário e streak.
-- Ver docs/05_KIDSCOINS_RECOMPENSAS_XP_E_STREAK.md seções 7-12,
-- docs/09_MODELO_DE_DADOS.md seção 4.
--
-- Escopo deste marco: nível, bônus de nível, aniversário, streak e
-- progresso diário. Desbloqueios de cosméticos (avatares, molduras, temas,
-- medalhas) ficam para o Marco 5, junto do catálogo de temas — desbloquear
-- algo que ainda não existe no design system seria só schema vazio agora.

create table public.level_definitions (
  level integer primary key check (level >= 1),
  min_total_xp integer not null check (min_total_xp >= 0),
  title_key text not null,
  active boolean not null default true
);

comment on table public.level_definitions is
  'XP mínimo por nível: fórmula docs/05 seção 8, 50 * (L-1) * L. O cliente '
  'consulta esta tabela; não recalcula a fórmula por conta própria. O bônus '
  'de KidsCoins por nível é o valor configurável em '
  'child_profiles.level_bonus_coins (docs/05 seção 9), não uma coluna aqui.';

insert into public.level_definitions (level, min_total_xp, title_key)
select l, 50 * (l - 1) * l, 'level_' || l
from generate_series(1, 30) as l;

alter table public.level_definitions enable row level security;

create policy "level_definitions_select_authenticated" on public.level_definitions
  for select
  to authenticated
  using (active);

create table public.daily_progress (
  child_id uuid not null references public.child_profiles (id) on delete cascade,
  progress_date date not null,
  required_total integer not null default 0,
  required_completed integer not null default 0,
  percentage integer not null default 0,
  qualifies_for_streak boolean not null default false,
  calculated_at timestamptz not null default timezone('utc', now()),
  primary key (child_id, progress_date)
);

comment on table public.daily_progress is
  'Um dia sem tarefa obrigatória elegível (required_total = 0) é neutro: '
  'não conta a favor nem contra o streak (docs/05 seção 12).';

alter table public.daily_progress enable row level security;

create policy "daily_progress_select_guardian" on public.daily_progress
  for select
  to authenticated
  using (
    exists (
      select 1 from public.child_profiles cp
      join public.family_members fm on fm.family_id = cp.family_id
      where cp.id = daily_progress.child_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

create policy "daily_progress_select_own_child" on public.daily_progress
  for select
  to authenticated
  using (
    exists (
      select 1 from public.child_device_bindings cdb
      where cdb.child_id = daily_progress.child_id
        and cdb.auth_user_id = (select auth.uid())
        and cdb.revoked_at is null
    )
  );

create table public.child_streaks (
  child_id uuid primary key references public.child_profiles (id) on delete cascade,
  current_streak integer not null default 0,
  best_streak integer not null default 0,
  last_qualified_date date,
  updated_at timestamptz not null default timezone('utc', now())
);

create trigger set_updated_at
  before update on public.child_streaks
  for each row execute function public.set_updated_at();

create or replace function public.create_child_streak()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.child_streaks (child_id)
  values (new.id)
  on conflict (child_id) do nothing;
  return new;
end;
$$;

create trigger create_child_streak_after_insert
  after insert on public.child_profiles
  for each row execute function public.create_child_streak();

alter table public.child_streaks enable row level security;

create policy "child_streaks_select_guardian" on public.child_streaks
  for select
  to authenticated
  using (
    exists (
      select 1 from public.child_profiles cp
      join public.family_members fm on fm.family_id = cp.family_id
      where cp.id = child_streaks.child_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

create policy "child_streaks_select_own_child" on public.child_streaks
  for select
  to authenticated
  using (
    exists (
      select 1 from public.child_device_bindings cdb
      where cdb.child_id = child_streaks.child_id
        and cdb.auth_user_id = (select auth.uid())
        and cdb.revoked_at is null
    )
  );

-- Sem policy de insert/update em daily_progress/child_streaks: só
-- recalculate_daily_progress/advance_streak (internas) escrevem.

-- Amplia o ledger para os novos tipos de lançamento deste marco
-- (docs/05 seção 2). Não editamos a migration original do Marco 2
-- (20260731100009), já commitada — evolução de schema é sempre uma nova
-- migration a partir daqui.
alter table public.coin_ledger drop constraint coin_ledger_entry_type_check;
alter table public.coin_ledger add constraint coin_ledger_entry_type_check check (
  entry_type in (
    'task_reward', 'manual_adjustment', 'redemption', 'redemption_refund',
    'level_bonus', 'birthday_bonus'
  )
);
