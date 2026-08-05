-- Marco 7 (fatia 7) — "avisos operacionais para responsáveis" (docs/12
-- seção 8). Só ao responsável, nunca à criança (mesmo espírito de "sem
-- campanha de marketing direcionada diretamente a crianças no MVP" —
-- qualquer comunicação administrativa fica de fora do ambiente infantil).
--
-- `admin_operational_notices` é o ledger de idempotência — mesmo padrão
-- de `family_status_events`/`subscription_events`, já que esta ação
-- dispara efeito colateral em outra tabela (`notifications`, uma por
-- responsável) e precisa de replay seguro (CLAUDE.md: "toda ação crítica
-- deve aceitar chave de idempotência").
create table public.admin_operational_notices (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  title text not null,
  body text not null,
  recipients_notified integer not null,
  sent_by uuid not null references public.profiles (id),
  idempotency_key text not null unique,
  created_at timestamptz not null default timezone('utc', now())
);

create index admin_operational_notices_family_id_idx on public.admin_operational_notices (family_id);

alter table public.admin_operational_notices enable row level security;

create policy "admin_operational_notices_select_admin" on public.admin_operational_notices
  for select
  to authenticated
  using (public.is_active_platform_admin(array['super_admin', 'support']));

-- Reaproveita `emit_notification` (Marco 6) para cada responsável ativo da
-- família, mesmo padrão de "notificar os dois responsáveis" já usado em
-- tarefas/resgates.
create or replace function public.admin_send_operational_notice(
  p_family_id uuid,
  p_title text,
  p_body text,
  p_idempotency_key text
)
returns table (recipients_notified integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := (select auth.uid());
  v_count integer := 0;
  v_guardian record;
begin
  if not public.is_active_platform_admin(array['super_admin', 'support']) then
    raise exception 'FORBIDDEN';
  end if;

  if p_idempotency_key is null or length(trim(p_idempotency_key)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'idempotency_key is required';
  end if;

  if p_title is null or length(trim(p_title)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'title is required';
  end if;

  if p_body is null or length(trim(p_body)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'body is required';
  end if;

  if exists (select 1 from public.admin_operational_notices where idempotency_key = p_idempotency_key) then
    return query
      select n.recipients_notified from public.admin_operational_notices n
      where n.idempotency_key = p_idempotency_key;
    return;
  end if;

  if not exists (select 1 from public.families where id = p_family_id) then
    raise exception 'VALIDATION_ERROR' using detail = 'family not found';
  end if;

  for v_guardian in
    select fm.profile_id from public.family_members fm
    where fm.family_id = p_family_id and fm.status = 'active'
  loop
    perform public.emit_notification(
      p_family_id, 'admin.operational_notice', 'family', p_family_id,
      'guardian', v_guardian.profile_id, null,
      p_title, p_body,
      '{}'::jsonb, null,
      'admin_operational_notice:' || p_idempotency_key || ':' || v_guardian.profile_id::text
    );
    v_count := v_count + 1;
  end loop;

  insert into public.admin_operational_notices (
    family_id, title, body, recipients_notified, sent_by, idempotency_key
  ) values (
    p_family_id, p_title, p_body, v_count, v_admin_id, p_idempotency_key
  );

  perform public.record_admin_audit_log(
    'admin.operational_notice_sent', 'family', p_family_id::text, 'success',
    jsonb_build_object('title', p_title, 'recipients', v_count)
  );

  return query select v_count;
end;
$$;
