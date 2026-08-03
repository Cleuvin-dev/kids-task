-- Marco 6 — Notificações (parte 1/4)
-- Central interna de notificações, fila de saída (outbox), tokens de
-- aparelho e preferências. Ver docs/11_NOTIFICACOES.md,
-- docs/09_MODELO_DE_DADOS.md seção 7, docs/14 seções 9-10.
--
-- Bloqueio conhecido (docs/IMPLEMENTATION_STATUS.md): não existe projeto
-- Firebase real ainda, então push de verdade (FCM/APNs) não pode ser
-- testado nem enviado neste ciclo. Este marco constrói o que é possível
-- sem a infraestrutura externa: o modelo de dados, a central interna (que
-- já funciona sozinha, sem depender de push) e a fila de eventos que um
-- futuro worker de envio consumiria.

create table public.device_tokens (
  id uuid primary key default extensions.gen_random_uuid(),
  auth_user_id uuid not null,
  -- Não nulo só para o token da sessão infantil (docs/11 seção 7:
  -- "associar token infantil ao vínculo de aparelho"). Token de
  -- responsável usa só auth_user_id.
  child_binding_id uuid references public.child_device_bindings (id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  fcm_token text not null,
  locale text not null default 'pt-BR',
  active boolean not null default true,
  last_seen_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now())
);

create unique index device_tokens_fcm_token_idx on public.device_tokens (fcm_token);
create index device_tokens_auth_user_id_idx on public.device_tokens (auth_user_id) where active;

alter table public.device_tokens enable row level security;

create policy "device_tokens_select_own" on public.device_tokens
  for select
  to authenticated
  using (auth_user_id = (select auth.uid()));

-- Sem policy de insert/update: só via register_device_token/
-- deactivate_device_token (validam o vínculo antes de gravar).

create table public.notification_preferences (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  recipient_type text not null check (recipient_type in ('guardian', 'child')),
  recipient_profile_id uuid references public.profiles (id),
  recipient_child_id uuid references public.child_profiles (id),
  event_type text not null,
  enabled boolean not null default true,
  lead_minutes integer,
  quiet_hours_start time,
  quiet_hours_end time,
  updated_at timestamptz not null default timezone('utc', now()),
  constraint notification_preferences_recipient_check check (
    (recipient_type = 'guardian' and recipient_profile_id is not null and recipient_child_id is null)
    or
    (recipient_type = 'child' and recipient_child_id is not null and recipient_profile_id is null)
  )
);

comment on table public.notification_preferences is
  'Notificações essenciais de segurança/exclusão não aparecem aqui — nunca '
  'podem ser desativadas (docs/11 seção 4). Enforcement de preferência (não '
  'enviar quando desabilitado/quiet hours) fica para quando existir um '
  'worker de envio de verdade — este marco só guarda a preferência.';

create unique index notification_preferences_guardian_idx
  on public.notification_preferences (recipient_profile_id, event_type)
  where recipient_type = 'guardian';

create unique index notification_preferences_child_idx
  on public.notification_preferences (recipient_child_id, event_type)
  where recipient_type = 'child';

create trigger set_updated_at
  before update on public.notification_preferences
  for each row execute function public.set_updated_at();

alter table public.notification_preferences enable row level security;

create policy "notification_preferences_select_guardian" on public.notification_preferences
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = notification_preferences.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

create policy "notification_preferences_select_own_child" on public.notification_preferences
  for select
  to authenticated
  using (
    recipient_type = 'child'
    and exists (
      select 1 from public.child_device_bindings cdb
      where cdb.child_id = notification_preferences.recipient_child_id
        and cdb.auth_user_id = (select auth.uid())
        and cdb.revoked_at is null
    )
  );

-- Preferência (inclusive das crianças) é decisão do responsável — "criança
-- pequena não deve tomar decisão jurídica de consentimento" (docs/11 seção
-- 10), mesmo espírito do tema em docs/06 ("visível, mas não alterável pela
-- criança").
create policy "notification_preferences_insert_guardian" on public.notification_preferences
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = notification_preferences.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

create policy "notification_preferences_update_guardian" on public.notification_preferences
  for update
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = notification_preferences.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  )
  with check (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = notification_preferences.family_id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

create table public.notifications (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  recipient_type text not null check (recipient_type in ('guardian', 'child')),
  recipient_profile_id uuid references public.profiles (id),
  recipient_child_id uuid references public.child_profiles (id),
  event_type text not null,
  -- Texto já pronto em pt-BR, mesmo padrão do resto do app (nenhuma tela
  -- usa o ARB ainda). O conteúdo aqui pode ser completo porque só aparece
  -- dentro do app, autenticado — o padrão restrito de lock screen
  -- (docs/11 seção 6) só vale para o texto do push em si, que este marco
  -- ainda não envia (bloqueio de Firebase).
  title text not null,
  body text not null,
  payload jsonb not null default '{}'::jsonb,
  deep_link text,
  read_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  constraint notifications_recipient_check check (
    (recipient_type = 'guardian' and recipient_profile_id is not null and recipient_child_id is null)
    or
    (recipient_type = 'child' and recipient_child_id is not null and recipient_profile_id is null)
  )
);

create index notifications_guardian_idx
  on public.notifications (recipient_profile_id, created_at desc)
  where recipient_type = 'guardian';

create index notifications_child_idx
  on public.notifications (recipient_child_id, created_at desc)
  where recipient_type = 'child';

alter table public.notifications enable row level security;

create policy "notifications_select_guardian" on public.notifications
  for select
  to authenticated
  using (recipient_type = 'guardian' and recipient_profile_id = (select auth.uid()));

create policy "notifications_select_own_child" on public.notifications
  for select
  to authenticated
  using (
    recipient_type = 'child'
    and exists (
      select 1 from public.child_device_bindings cdb
      where cdb.child_id = notifications.recipient_child_id
        and cdb.auth_user_id = (select auth.uid())
        and cdb.revoked_at is null
    )
  );

-- Sem policy de insert/update: criação só via emit_notification (interna);
-- marcar como lida só via mark_notification_read.

create table public.outbox_events (
  id uuid primary key default extensions.gen_random_uuid(),
  event_type text not null,
  aggregate_type text not null,
  aggregate_id uuid,
  family_id uuid not null references public.families (id) on delete cascade,
  occurred_at timestamptz not null default timezone('utc', now()),
  schema_version integer not null default 1,
  payload jsonb not null default '{}'::jsonb,
  idempotency_key text not null unique,
  attempts integer not null default 0,
  next_attempt_at timestamptz,
  processed_at timestamptz
);

comment on table public.outbox_events is
  'Fila para um futuro worker de envio de push (docs/11 seção 7, docs/14 '
  'seção 10 — mesmo formato de envelope de evento). Nenhum papel de '
  'cliente acessa esta tabela; é só um mecanismo de entrega interno, '
  'igual a family_invites no Marco 1.';

create index outbox_events_pending_idx
  on public.outbox_events (next_attempt_at)
  where processed_at is null;

alter table public.outbox_events enable row level security;

-- Nenhuma policy: acesso só por service_role (bypassa RLS), quando um
-- worker de envio existir.
