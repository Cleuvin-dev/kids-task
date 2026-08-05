-- Marco 7 (fatia 3) — busca de família para o módulo "Assinaturas"
-- (docs/12 seção 4: "busca por ID da família ou e-mail do responsável").
--
-- Nunca por código familiar (CLAUDE.md: "não enumerar famílias ou crianças
-- a partir de tentativas de código" — o código só existe como digest,
-- docs/03 seção 5). E-mail vive em auth.users, que nenhuma policy de RLS
-- expõe a `authenticated`; por isso esta função precisa ser security
-- definer (dono `postgres`, com acesso a auth.users) em vez de uma policy
-- direta como as de families/subscriptions.
create or replace function public.admin_search_families(p_query text)
returns table (
  family_id uuid,
  family_name text,
  status text,
  plan_code text,
  guardian_emails text[],
  children_count integer,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_query text := trim(coalesce(p_query, ''));
  v_family_id uuid;
begin
  if not public.is_active_platform_admin(array['super_admin', 'support', 'billing']) then
    raise exception 'FORBIDDEN';
  end if;

  if length(v_query) < 3 then
    raise exception 'VALIDATION_ERROR' using detail = 'query too short';
  end if;

  begin
    v_family_id := v_query::uuid;
  exception when invalid_text_representation then
    v_family_id := null;
  end;

  return query
  select
    f.id,
    f.name,
    f.status,
    p.code,
    array(
      select u.email from public.family_members fm
      join auth.users u on u.id = fm.profile_id
      where fm.family_id = f.id and fm.status = 'active'
      order by u.email
    ),
    (
      select count(*)::int from public.child_profiles cp
      where cp.family_id = f.id
    ),
    f.created_at
  from public.families f
  join public.plans p on p.id = f.plan_id
  where
    f.id = v_family_id
    or exists (
      select 1 from public.family_members fm
      join auth.users u on u.id = fm.profile_id
      where fm.family_id = f.id
        and fm.status = 'active'
        and u.email ilike '%' || v_query || '%'
    )
  order by f.created_at desc
  limit 20;
end;
$$;

comment on function public.admin_search_families(text) is
  'Retorna no máximo 20 famílias por busca — suficiente para o operador '
  'refinar a busca em vez de listar a base inteira (docs/12 seção 4).';
