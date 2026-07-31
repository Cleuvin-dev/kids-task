-- Marco 1 — Autenticação e Família (parte 2/4)
-- Família, responsáveis vinculados e convites.
-- Ver docs/03_USUARIOS_FAMILIA_E_AUTENTICACAO.md, docs/09 seção 2.

-- Alfabeto sem caracteres ambíguos (sem 0/O, 1/I, e sem vogais que formem
-- palavras acidentais): docs/03 seção 5 "caracteres não ambíguos".
create or replace function public.normalize_family_code(p_code text)
returns text
language sql
immutable
set search_path = ''
as $$
  select upper(regexp_replace(p_code, '[^A-Za-z0-9]', '', 'g'));
$$;

create or replace function public.hash_family_code(p_code text)
returns text
language sql
immutable
set search_path = ''
as $$
  select encode(extensions.digest(public.normalize_family_code(p_code), 'sha256'), 'hex');
$$;

create or replace function public.generate_family_code()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_alphabet text := '23456789ACDEFGHJKLMNPQRTUVWXY';
  v_code text := '';
  i integer;
begin
  for i in 1..8 loop
    v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    if i = 4 then
      v_code := v_code || '-';
    end if;
  end loop;
  return v_code;
end;
$$;

create table public.families (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null,
  timezone text not null default 'America/Sao_Paulo',
  family_code_digest text not null unique,
  guardian_theme text not null default 'blue' check (guardian_theme in ('blue', 'pink')),
  plan_id uuid not null references public.plans (id),
  status text not null default 'active' check (status in ('active', 'restricted', 'blocked', 'deletion_pending', 'deleted')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deletion_scheduled_at timestamptz
);

comment on column public.families.family_code_digest is
  'SHA-256 do código normalizado. O código em claro nunca é persistido — '
  'apenas retornado uma vez ao responsável na criação/regeneração.';

create trigger set_updated_at
  before update on public.families
  for each row execute function public.set_updated_at();

create table public.family_members (
  family_id uuid not null references public.families (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  role text not null check (role in ('owner', 'guardian')),
  status text not null default 'active' check (status in ('active', 'removed')),
  joined_at timestamptz not null default timezone('utc', now()),
  removed_at timestamptz,
  primary key (family_id, profile_id)
);

-- Um profile só pode ter um vínculo ATIVO por família (mas pode ter havido
-- vínculos removidos no histórico — por isso não é UNIQUE simples em profile_id).
create unique index family_members_one_active_family_per_profile
  on public.family_members (profile_id)
  where status = 'active';

create table public.family_invites (
  id uuid primary key default extensions.gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  email_normalized text not null,
  token_digest text not null unique,
  role text not null default 'guardian' check (role in ('guardian')),
  invited_by uuid not null references public.profiles (id),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

create index family_invites_family_id_idx on public.family_invites (family_id);

alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.family_invites enable row level security;

-- families: apenas membros ativos enxergam a própria família. Nenhum INSERT
-- direto — só via create_family() (security definer), para garantir plano
-- gratuito inicial e o primeiro family_members com role=owner na mesma transação.
create policy "families_select_member" on public.families
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = families.id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

create policy "families_update_guardian" on public.families
  for update
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = families.id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  )
  with check (
    exists (
      select 1 from public.family_members fm
      where fm.family_id = families.id
        and fm.profile_id = (select auth.uid())
        and fm.status = 'active'
    )
  );

-- family_members: um membro vê os outros membros da mesma família ativa.
create policy "family_members_select_same_family" on public.family_members
  for select
  to authenticated
  using (
    exists (
      select 1 from public.family_members fm2
      where fm2.family_id = family_members.family_id
        and fm2.profile_id = (select auth.uid())
        and fm2.status = 'active'
    )
  );

-- family_invites: nenhum acesso direto do cliente (nem ao token, nem ao
-- digest) — tudo passa por Edge Functions com service_role. RLS aqui existe
-- só como cinto de segurança (deny by default; nenhuma policy de select
-- concedida a `authenticated`/`anon`).
