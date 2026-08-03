-- Marco 6 — Notificações (parte 2/4)
-- register_device_token, deactivate_device_token, mark_notification_read
-- (client-facing) e emit_notification (interna, chamada de dentro de
-- outras funções — mesmo padrão de grant_task_rewards).

create or replace function public.register_device_token(
  p_platform text,
  p_fcm_token text,
  p_locale text default 'pt-BR'
)
returns table (token_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_child_binding_id uuid;
  v_token_id uuid;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_platform not in ('android', 'ios') then
    raise exception 'VALIDATION_ERROR' using detail = 'invalid platform';
  end if;

  if p_fcm_token is null or length(trim(p_fcm_token)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'fcm_token is required';
  end if;

  -- Sessão infantil: amarra o token ao vínculo de aparelho ativo
  -- (docs/11 seção 7). Sessão de responsável: v_child_binding_id fica nulo.
  select cdb.id into v_child_binding_id
  from public.child_device_bindings cdb
  where cdb.auth_user_id = v_profile_id and cdb.revoked_at is null;

  insert into public.device_tokens (auth_user_id, child_binding_id, platform, fcm_token, locale)
  values (v_profile_id, v_child_binding_id, p_platform, p_fcm_token, coalesce(p_locale, 'pt-BR'))
  on conflict (fcm_token) do update set
    auth_user_id = excluded.auth_user_id,
    child_binding_id = excluded.child_binding_id,
    platform = excluded.platform,
    locale = excluded.locale,
    active = true,
    last_seen_at = timezone('utc', now())
  returning id into v_token_id;

  return query select v_token_id;
end;
$$;

create or replace function public.deactivate_device_token(p_token_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  update public.device_tokens
  set active = false
  where id = p_token_id and auth_user_id = v_profile_id;
end;
$$;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_notification record;
  v_is_child boolean;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select * into v_notification from public.notifications where id = p_notification_id;

  if not found then
    return;
  end if;

  if v_notification.recipient_type = 'guardian' then
    if v_notification.recipient_profile_id <> v_profile_id then
      raise exception 'FORBIDDEN';
    end if;
  else
    v_is_child := exists (
      select 1 from public.child_device_bindings cdb
      where cdb.child_id = v_notification.recipient_child_id
        and cdb.auth_user_id = v_profile_id
        and cdb.revoked_at is null
    );
    if not v_is_child then
      raise exception 'FORBIDDEN';
    end if;
  end if;

  update public.notifications
  set read_at = timezone('utc', now())
  where id = p_notification_id and read_at is null;
end;
$$;

-- ---------------------------------------------------------------------
-- emit_notification: interna, sem grant a nenhum papel de cliente.
-- Grava a notificação interna e o evento de outbox atomicamente, com a
-- mesma idempotency_key nos dois — reprocessar uma aprovação não duplica
-- nem o evento nem a notificação (docs/11 seção 8).
-- ---------------------------------------------------------------------
create or replace function public.emit_notification(
  p_family_id uuid,
  p_event_type text,
  p_aggregate_type text,
  p_aggregate_id uuid,
  p_recipient_type text,
  p_recipient_profile_id uuid,
  p_recipient_child_id uuid,
  p_title text,
  p_body text,
  p_payload jsonb,
  p_deep_link text,
  p_idempotency_key text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.outbox_events (
    event_type, aggregate_type, aggregate_id, family_id, payload, idempotency_key
  ) values (
    p_event_type, p_aggregate_type, p_aggregate_id, p_family_id, p_payload, p_idempotency_key
  )
  on conflict (idempotency_key) do nothing;

  if not found then
    -- Já emitido antes (retry): não duplica a notificação interna.
    return;
  end if;

  insert into public.notifications (
    family_id, recipient_type, recipient_profile_id, recipient_child_id,
    event_type, title, body, payload, deep_link
  ) values (
    p_family_id, p_recipient_type, p_recipient_profile_id, p_recipient_child_id,
    p_event_type, p_title, p_body, p_payload, p_deep_link
  );
end;
$$;
