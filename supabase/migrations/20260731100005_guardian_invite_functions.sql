-- Marco 1 — convite de responsável (docs/03 seção 4, docs/14 seção 2).
-- O envio de e-mail em si acontece na Edge Function `send-guardian-invite`
-- (fora do banco); estas funções cuidam apenas da parte transacional.

create or replace function public.normalize_email(p_email text)
returns text
language sql
immutable
set search_path = ''
as $$
  select lower(trim(p_email));
$$;

create or replace function public.hash_invite_token(p_token text)
returns text
language sql
immutable
set search_path = ''
as $$
  select encode(extensions.digest(p_token, 'sha256'), 'hex');
$$;

create or replace function public.invite_guardian(p_family_id uuid, p_email text)
returns table (invite_id uuid, token text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_email text := public.normalize_email(p_email);
  v_token text;
  v_invite_id uuid;
  v_expires_at timestamptz := timezone('utc', now()) + interval '72 hours';
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if not exists (
    select 1 from public.family_members
    where family_id = p_family_id and profile_id = v_profile_id and status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  if v_email is null or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'VALIDATION_ERROR' using detail = 'invalid email';
  end if;

  -- Reenviar invalida o convite pendente anterior para o mesmo e-mail
  -- (docs/03 seção 4: "Reenvio invalida token anterior").
  update public.family_invites
  set cancelled_at = timezone('utc', now())
  where family_id = p_family_id
    and email_normalized = v_email
    and accepted_at is null
    and cancelled_at is null;

  v_token := encode(extensions.gen_random_bytes(24), 'hex');

  insert into public.family_invites (family_id, email_normalized, token_digest, invited_by, expires_at)
  values (p_family_id, v_email, public.hash_invite_token(v_token), v_profile_id, v_expires_at)
  returning id into v_invite_id;

  return query select v_invite_id, v_token, v_expires_at;
end;
$$;

create or replace function public.cancel_guardian_invite(p_invite_id uuid)
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

  if not exists (
    select 1 from public.family_invites fi
    join public.family_members fm on fm.family_id = fi.family_id
    where fi.id = p_invite_id and fm.profile_id = v_profile_id and fm.status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  update public.family_invites
  set cancelled_at = timezone('utc', now())
  where id = p_invite_id and accepted_at is null and cancelled_at is null;
end;
$$;

create or replace function public.accept_guardian_invite(p_token text)
returns table (family_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_caller_email text;
  v_invite public.family_invites;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select * into v_invite
  from public.family_invites
  where token_digest = public.hash_invite_token(p_token)
  limit 1;

  if v_invite.id is null then
    raise exception 'VALIDATION_ERROR' using detail = 'invite not found';
  end if;

  if v_invite.cancelled_at is not null or v_invite.expires_at < timezone('utc', now()) then
    raise exception 'VALIDATION_ERROR' using detail = 'invite expired or cancelled';
  end if;

  if v_invite.accepted_at is not null then
    -- Idempotente: se quem chama já é membro ativo desta família, não é erro.
    if exists (
      select 1 from public.family_members
      where family_id = v_invite.family_id and profile_id = v_profile_id and status = 'active'
    ) then
      return query select v_invite.family_id;
      return;
    end if;
    raise exception 'ALREADY_PROCESSED';
  end if;

  select email into v_caller_email from auth.users where id = v_profile_id;

  if public.normalize_email(v_caller_email) <> v_invite.email_normalized then
    raise exception 'FORBIDDEN';
  end if;

  if exists (
    select 1 from public.family_members
    where profile_id = v_profile_id and status = 'active'
  ) then
    raise exception 'VALIDATION_ERROR' using detail = 'guardian already belongs to an active family';
  end if;

  insert into public.family_members (family_id, profile_id, role, status)
  values (v_invite.family_id, v_profile_id, 'guardian', 'active');

  update public.family_invites
  set accepted_at = timezone('utc', now())
  where id = v_invite.id;

  return query select v_invite.family_id;
end;
$$;
