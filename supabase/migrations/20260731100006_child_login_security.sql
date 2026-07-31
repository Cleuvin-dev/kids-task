-- Marco 1 — proteções do login infantil (docs/03 seção 6, 10; ADR 0001).
-- Suporta o fluxo com PIN e o fluxo sem PIN (pareamento por código curto
-- gerado pelo responsável), mais rate limit/atraso progressivo.

create table public.child_login_attempts (
  id uuid primary key default extensions.gen_random_uuid(),
  auth_user_id uuid not null,
  ip_hash text,
  succeeded boolean not null,
  created_at timestamptz not null default timezone('utc', now())
);

create index child_login_attempts_auth_user_idx
  on public.child_login_attempts (auth_user_id, created_at desc);

comment on table public.child_login_attempts is
  'Somente a Edge Function (service_role) escreve aqui. Sem policy de select '
  'para authenticated/anon: nenhum cliente lê tentativas alheias.';

alter table public.child_login_attempts enable row level security;

create table public.device_pairing_codes (
  id uuid primary key default extensions.gen_random_uuid(),
  child_id uuid not null references public.child_profiles (id) on delete cascade,
  code_digest text not null unique,
  created_by uuid not null references public.profiles (id),
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

create index device_pairing_codes_child_id_idx on public.device_pairing_codes (child_id);

alter table public.device_pairing_codes enable row level security;

-- Nenhuma policy de select/insert direta: criação via create_device_pairing_code()
-- (guardian), consumo via Edge Function authorize-child-device (service_role).

create or replace function public.check_child_login_rate_limit(p_auth_user_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_recent_failures int;
begin
  select count(*) into v_recent_failures
  from public.child_login_attempts
  where auth_user_id = p_auth_user_id
    and succeeded = false
    and created_at > timezone('utc', now()) - interval '15 minutes';

  -- Atraso progressivo simplificado: acima de 5 falhas em 15 minutos,
  -- bloqueia novas tentativas até a janela expirar (docs/03 seção 6).
  return v_recent_failures < 5;
end;
$$;

create or replace function public.record_child_login_attempt(p_auth_user_id uuid, p_succeeded boolean, p_ip_hash text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.child_login_attempts (auth_user_id, succeeded, ip_hash)
  values (p_auth_user_id, p_succeeded, p_ip_hash);
end;
$$;

-- Usada pela Edge Function para validar o PIN sem expor pin_hash ao cliente.
create or replace function public.verify_child_pin(p_child_id uuid, p_pin text)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select pin_enabled and pin_hash is not null and pin_hash = extensions.crypt(p_pin, pin_hash)
  from public.child_profiles
  where id = p_child_id;
$$;

-- Responsável gera um código curto e temporário para autorizar um aparelho
-- sem PIN (docs/03 seção 6, "Criança sem PIN").
create or replace function public.create_device_pairing_code(p_child_id uuid)
returns table (pairing_code text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_alphabet text := '23456789ACDEFGHJKLMNPQRTUVWXY';
  v_code text := '';
  v_expires_at timestamptz := timezone('utc', now()) + interval '10 minutes';
  i int;
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

  for i in 1..6 loop
    v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
  end loop;

  insert into public.device_pairing_codes (child_id, code_digest, created_by, expires_at)
  values (p_child_id, public.hash_family_code(v_code), v_profile_id, v_expires_at);

  return query select v_code, v_expires_at;
end;
$$;

-- Resolve os perfis infantis de uma família a partir do código, para a tela
-- de seleção de avatar/apelido (docs/03 seção 6, passo 3). Não expõe nada
-- além do mínimo necessário e não distingue "código inválido" de "família
-- sem crianças" na mensagem de erro.
create or replace function public.resolve_family_children_by_code(p_family_code text)
returns table (child_id uuid, display_name text, avatar_id text, pin_enabled boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_family_id uuid;
begin
  select id into v_family_id
  from public.families
  where family_code_digest = public.hash_family_code(p_family_code)
    and status = 'active';

  if v_family_id is null then
    raise exception 'VALIDATION_ERROR' using detail = 'invalid family code';
  end if;

  return query
    select cp.id, coalesce(cp.nickname, cp.first_name), cp.avatar_id, cp.pin_enabled
    from public.child_profiles cp
    where cp.family_id = v_family_id and cp.status = 'active'
    order by cp.created_at;
end;
$$;
