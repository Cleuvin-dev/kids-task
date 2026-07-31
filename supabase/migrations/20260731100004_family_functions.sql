-- Marco 1 — Autenticação e Família (parte 4/4)
-- Funções transacionais chamadas via RPC pelo app (docs/14_APIS_FUNCOES_E_EVENTOS.md).
--
-- Convenção de erro: em vez de códigos de erro do Postgres, as funções
-- levantam exceções cuja MENSAGEM é exatamente um DomainErrorCode.wireName
-- (ex.: 'PLAN_CHILD_LIMIT'). O cliente Dart mapeia a mensagem da
-- PostgrestException de volta para DomainErrorCode. Isso evita duplicar a
-- tabela de códigos de erro em SQL e em Dart.

create or replace function public.create_family(
  p_name text,
  p_timezone text default 'America/Sao_Paulo',
  p_guardian_theme text default 'blue'
)
returns table (family_id uuid, family_code text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_plan_id uuid;
  v_code text;
  v_family_id uuid;
  v_attempt int;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if exists (
    select 1 from public.family_members
    where profile_id = v_profile_id and status = 'active'
  ) then
    raise exception 'VALIDATION_ERROR' using detail = 'guardian already belongs to an active family';
  end if;

  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'name is required';
  end if;

  if p_guardian_theme not in ('blue', 'pink') then
    raise exception 'VALIDATION_ERROR' using detail = 'invalid guardian_theme';
  end if;

  select id into v_plan_id from public.plans where code = 'free' and active;

  -- Colisão de código é praticamente impossível (29^8 combinações), mas o
  -- laço evita uma falha visível ao usuário no caso extremo.
  for v_attempt in 1..5 loop
    v_code := public.generate_family_code();
    begin
      insert into public.families (name, timezone, family_code_digest, guardian_theme, plan_id)
      values (trim(p_name), coalesce(p_timezone, 'America/Sao_Paulo'), public.hash_family_code(v_code), p_guardian_theme, v_plan_id)
      returning id into v_family_id;
      exit;
    exception when unique_violation then
      v_family_id := null;
    end;
  end loop;

  if v_family_id is null then
    raise exception 'VALIDATION_ERROR' using detail = 'could not allocate a unique family code';
  end if;

  insert into public.family_members (family_id, profile_id, role, status)
  values (v_family_id, v_profile_id, 'owner', 'active');

  return query select v_family_id, v_code;
end;
$$;

create or replace function public.rotate_family_code(p_family_id uuid)
returns table (family_code text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_code text;
  v_attempt int;
  v_updated boolean := false;
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

  for v_attempt in 1..5 loop
    v_code := public.generate_family_code();
    begin
      update public.families
      set family_code_digest = public.hash_family_code(v_code)
      where id = p_family_id;
      v_updated := true;
      exit;
    exception when unique_violation then
      v_updated := false;
    end;
  end loop;

  if not v_updated then
    raise exception 'VALIDATION_ERROR' using detail = 'could not allocate a unique family code';
  end if;

  return query select v_code;
end;
$$;

create or replace function public.remove_guardian(p_family_id uuid, p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_active_count int;
begin
  if v_caller is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if not exists (
    select 1 from public.family_members
    where family_id = p_family_id and profile_id = v_caller and status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  select count(*) into v_active_count
  from public.family_members
  where family_id = p_family_id and status = 'active';

  if v_active_count <= 1 then
    raise exception 'VALIDATION_ERROR' using detail = 'cannot remove the last active guardian of a family';
  end if;

  update public.family_members
  set status = 'removed', removed_at = timezone('utc', now())
  where family_id = p_family_id and profile_id = p_profile_id and status = 'active';

  if not found then
    raise exception 'ALREADY_PROCESSED';
  end if;
end;
$$;

create or replace function public.create_child(
  p_family_id uuid,
  p_first_name text,
  p_birth_date date,
  p_nickname text default null,
  p_avatar_id text default 'default'
)
returns table (child_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_plan_max_children int;
  v_active_children int;
  v_age_years int;
  v_age_mode text;
  v_child_id uuid;
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

  if p_first_name is null or length(trim(p_first_name)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'first_name is required';
  end if;

  if p_birth_date is null or p_birth_date > current_date then
    raise exception 'VALIDATION_ERROR' using detail = 'birth_date is required and must be in the past';
  end if;

  select p.max_active_children into v_plan_max_children
  from public.families f
  join public.plans p on p.id = f.plan_id
  where f.id = p_family_id
  for update of f;

  select count(*) into v_active_children
  from public.child_profiles
  where family_id = p_family_id and status = 'active';

  if v_active_children >= v_plan_max_children then
    raise exception 'PLAN_CHILD_LIMIT';
  end if;

  v_age_years := extract(year from age(current_date, p_birth_date))::int;
  v_age_mode := case
    when v_age_years <= 7 then 'young'
    when v_age_years <= 10 then 'middle'
    else 'teen'
  end;

  insert into public.child_profiles (
    family_id, first_name, nickname, birth_date, avatar_id, age_mode, created_by
  ) values (
    p_family_id, trim(p_first_name), nullif(trim(coalesce(p_nickname, '')), ''), p_birth_date, coalesce(p_avatar_id, 'default'), v_age_mode, v_profile_id
  )
  returning id into v_child_id;

  return query select v_child_id;
end;
$$;

create or replace function public.set_child_pin(p_child_id uuid, p_pin text)
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
    select 1 from public.child_profiles cp
    join public.family_members fm on fm.family_id = cp.family_id
    where cp.id = p_child_id and fm.profile_id = v_profile_id and fm.status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  if p_pin is null then
    update public.child_profiles
    set pin_hash = null, pin_enabled = false
    where id = p_child_id;
    return;
  end if;

  if p_pin !~ '^[0-9]{4,6}$' then
    raise exception 'VALIDATION_ERROR' using detail = 'pin must be 4 to 6 digits';
  end if;

  update public.child_profiles
  set pin_hash = extensions.crypt(p_pin, extensions.gen_salt('bf')), pin_enabled = true
  where id = p_child_id;
end;
$$;

create or replace function public.revoke_child_device(p_binding_id uuid)
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
    select 1 from public.child_device_bindings cdb
    join public.child_profiles cp on cp.id = cdb.child_id
    join public.family_members fm on fm.family_id = cp.family_id
    where cdb.id = p_binding_id and fm.profile_id = v_profile_id and fm.status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  -- Idempotente: revogar duas vezes não é erro.
  update public.child_device_bindings
  set revoked_at = timezone('utc', now())
  where id = p_binding_id and revoked_at is null;
end;
$$;
