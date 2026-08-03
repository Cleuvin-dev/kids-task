-- Marco 2 — Rotina e Tarefas (parte 1/8)
-- Tarefa, agenda, ocorrência e log de eventos.
-- Ver docs/04_TAREFAS_APROVACOES_E_ROTINA.md, docs/09_MODELO_DE_DADOS.md seção 3.

create table public.tasks (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  child_id uuid not null references public.child_profiles (id) on delete cascade,
  title text not null,
  description text,
  icon_key text not null default 'default',
  category text not null default 'geral',
  period text not null default 'anytime' check (period in ('morning', 'afternoon_evening', 'anytime')),
  is_bonus boolean not null default false,
  is_required boolean not null default true,
  -- Tarefa obrigatória de fim de semana pode optar por não contar no streak
  -- (docs/04 seção 13). O cálculo de streak em si só chega no Marco 4, mas
  -- a coluna precisa existir agora para o responsável já poder decidir.
  counts_toward_streak boolean not null default true,
  coin_reward integer not null default 0 check (coin_reward >= 0),
  xp_reward_default integer not null default 0 check (xp_reward_default >= 0),
  approval_mode text not null default 'automatic' check (approval_mode in ('automatic', 'manual')),
  late_policy text not null default 'allow_late' check (late_policy in ('allow_late', 'expire_no_reward')),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  archived_at timestamptz,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint tasks_bonus_not_required_check check (not (is_bonus and is_required))
);

comment on table public.tasks is
  'Definição reutilizável de tarefa. Uma tarefa pertence a uma única '
  'criança (docs/04 seção 3). Escrita só via upsert_task_with_schedule / '
  'pause_task / resume_task / archive_task.';

create trigger set_updated_at
  before update on public.tasks
  for each row execute function public.set_updated_at();

create index tasks_family_child_active_idx
  on public.tasks (family_id, child_id)
  where archived_at is null;

create table public.task_schedules (
  id uuid primary key default extensions.gen_random_uuid(),
  task_id uuid not null references public.tasks (id) on delete cascade,
  schedule_type text not null check (schedule_type in ('once', 'recurring')),
  one_time_date date,
  weekdays smallint[],
  starts_on date,
  ends_on date,
  start_time time,
  due_time time,
  timezone text not null default 'America/Sao_Paulo',
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint task_schedules_type_fields_check check (
    (schedule_type = 'once' and one_time_date is not null and weekdays is null)
    or
    (schedule_type = 'recurring' and weekdays is not null and array_length(weekdays, 1) > 0 and one_time_date is null)
  ),
  constraint task_schedules_weekdays_range_check check (
    weekdays is null or weekdays <@ array[0, 1, 2, 3, 4, 5, 6]::smallint[]
  )
);

comment on column public.task_schedules.weekdays is
  'extract(dow from date): 0 = domingo .. 6 = sábado, igual ao Postgres.';

-- Sem-horário e com-prazo (docs/04 seção 2) são combinações de start_time/
-- due_time nulos ou preenchidos sobre once/recurring, não tipos à parte.
-- Bônus é a flag tasks.is_bonus, também não um schedule_type separado.

-- Uma tarefa tem no máximo uma agenda ATIVA por vez; editar substitui a
-- agenda ativa (ver upsert_task_with_schedule), agendas antigas pausadas
-- ficam como histórico inativo.
create unique index task_schedules_one_active_per_task
  on public.task_schedules (task_id)
  where active;

create trigger set_updated_at
  before update on public.task_schedules
  for each row execute function public.set_updated_at();

create table public.task_occurrences (
  id uuid primary key default extensions.gen_random_uuid(),
  task_id uuid not null references public.tasks (id) on delete cascade,
  child_id uuid not null references public.child_profiles (id) on delete cascade,
  family_id uuid not null references public.families (id) on delete cascade,
  occurrence_date date not null,
  starts_at timestamptz,
  due_at timestamptz,
  status text not null default 'pending' check (status in (
    'pending', 'awaiting_approval', 'approved', 'late', 'expired',
    'needs_correction', 'cancelled', 'skipped_by_guardian'
  )),
  -- Snapshots: alterar a tarefa depois não muda ocorrências já geradas
  -- (docs/04 seção 8 e seção 11).
  coin_reward_snapshot integer not null check (coin_reward_snapshot >= 0),
  xp_reward_snapshot integer not null check (xp_reward_snapshot >= 0),
  approval_mode_snapshot text not null check (approval_mode_snapshot in ('automatic', 'manual')),
  late_policy_snapshot text not null check (late_policy_snapshot in ('allow_late', 'expire_no_reward')),
  title_snapshot text not null,
  icon_snapshot text not null,
  submitted_at timestamptz,
  approved_at timestamptz,
  expired_at timestamptz,
  approved_by uuid references public.profiles (id),
  rejection_reason text,
  version integer not null default 1,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

comment on table public.task_occurrences is
  'Item concreto exibido em uma data. Histórico imutável: só transiciona '
  'de estado via complete_task_occurrence / review_task_occurrence / '
  'skip_task_occurrence / generate_task_occurrences / '
  'expire_due_task_occurrences (docs/04 seção 7 e 9).';

-- Restrição única evita duplicação (docs/04 seção 9).
create unique index task_occurrences_task_child_date_idx
  on public.task_occurrences (task_id, child_id, occurrence_date);

create index task_occurrences_family_date_status_idx
  on public.task_occurrences (family_id, occurrence_date, status);

create index task_occurrences_child_date_idx
  on public.task_occurrences (child_id, occurrence_date);

create index task_occurrences_awaiting_approval_idx
  on public.task_occurrences (family_id)
  where status = 'awaiting_approval';

create trigger set_updated_at
  before update on public.task_occurrences
  for each row execute function public.set_updated_at();

create table public.task_events (
  id uuid primary key default extensions.gen_random_uuid(),
  occurrence_id uuid not null references public.task_occurrences (id) on delete cascade,
  event_type text not null,
  actor uuid,
  actor_role text not null check (actor_role in ('guardian', 'child', 'system')),
  payload jsonb not null default '{}'::jsonb,
  idempotency_key text,
  created_at timestamptz not null default timezone('utc', now())
);

comment on table public.task_events is
  'Log de auditoria append-only. A unicidade de idempotency_key também '
  'serve de trava contra reprocessar a mesma chamada do cliente '
  '(docs/04 seção 8).';

create unique index task_events_idempotency_key_idx
  on public.task_events (idempotency_key)
  where idempotency_key is not null;

create index task_events_occurrence_id_idx on public.task_events (occurrence_id);

alter table public.tasks enable row level security;
alter table public.task_schedules enable row level security;
alter table public.task_occurrences enable row level security;
alter table public.task_events enable row level security;

-- tasks: responsáveis administram (via função); a própria criança só lê
-- as tarefas ativas e não arquivadas atribuídas a ela.
create policy "tasks_select_guardian" on public.tasks
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = tasks.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

create policy "tasks_select_own_child" on public.tasks
  for select
  to authenticated
  using (
    tasks.is_active
    and tasks.archived_at is null
    and exists (
      select 1 from public.child_device_bindings cdb
      where cdb.child_id = tasks.child_id
        and cdb.auth_user_id = (select auth.uid())
        and cdb.revoked_at is null
    )
  );

-- Sem policy de insert/update/delete: toda escrita passa por
-- upsert_task_with_schedule / pause_task / resume_task / archive_task.

-- task_schedules: só o responsável consulta a regra de agenda; a criança
-- só vê as ocorrências já geradas, não a regra em si.
create policy "task_schedules_select_guardian" on public.task_schedules
  for select
  to authenticated
  using (
    exists (
      select 1 from public.tasks t
      join public.family_members fm on fm.family_id = t.family_id
      where t.id = task_schedules.task_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

-- task_occurrences: responsáveis da família e a própria criança leem;
-- nenhuma escrita direta de cliente.
create policy "task_occurrences_select_guardian" on public.task_occurrences
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = task_occurrences.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

create policy "task_occurrences_select_own_child" on public.task_occurrences
  for select
  to authenticated
  using (
    exists (
      select 1 from public.child_device_bindings cdb
      where cdb.child_id = task_occurrences.child_id
        and cdb.auth_user_id = (select auth.uid())
        and cdb.revoked_at is null
    )
  );

-- task_events: auditoria visível só ao responsável, nunca à criança.
create policy "task_events_select_guardian" on public.task_events
  for select
  to authenticated
  using (
    exists (
      select 1 from public.task_occurrences o
      join public.family_members fm on fm.family_id = o.family_id
      where o.id = task_events.occurrence_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );
