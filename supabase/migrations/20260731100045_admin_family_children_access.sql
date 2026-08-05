-- Marco 7 (fatia 4) — acesso administrativo a crianças (docs/12 seção 4:
-- "dados infantis ficam ocultos até uma ação justificada de suporte").
--
-- Por isso nenhuma policy de RLS dá select direto em `child_profiles` para
-- administradores: RLS é por linha, não por coluna, e `child_profiles` tem
-- `first_name`/`nickname`/`birth_date`/`avatar_id`/`private_photo_path`
-- juntos numa linha só — uma policy de select exporia tudo de uma vez.
-- Em vez disso, duas funções: uma que devolve só o essencial operacional
-- (status, idade aproximada via age_mode, contagem), e outra que revela
-- identidade só mediante justificativa, sempre auditada.

create or replace function public.admin_list_family_children(p_family_id uuid)
returns table (
  child_id uuid,
  status text,
  age_mode text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_active_platform_admin(array['super_admin', 'support', 'billing']) then
    raise exception 'FORBIDDEN';
  end if;

  return query
  select cp.id, cp.status, cp.age_mode, cp.created_at
  from public.child_profiles cp
  where cp.family_id = p_family_id
  order by cp.created_at;
end;
$$;

comment on function public.admin_list_family_children(uuid) is
  'Nunca devolve first_name/nickname/birth_date/avatar_id/private_photo_path '
  '— identidade da criança só via admin_reveal_child_identity, com '
  'justificativa e auditoria (docs/12 seção 4).';

create or replace function public.admin_reveal_child_identity(
  p_child_id uuid,
  p_justification text
)
returns table (
  first_name text,
  nickname text,
  avatar_id text,
  birth_date date
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_family_id uuid;
begin
  -- content fica de fora aqui (ao contrário da listagem acima): não lida
  -- com dado de família/responsável nem tem motivo de suporte para ver
  -- nome de criança (docs/12 seção 2).
  if not public.is_active_platform_admin(array['super_admin', 'support']) then
    raise exception 'FORBIDDEN';
  end if;

  if p_justification is null or length(trim(p_justification)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'justification is required';
  end if;

  select cp.family_id into v_family_id
  from public.child_profiles cp
  where cp.id = p_child_id;

  if v_family_id is null then
    raise exception 'VALIDATION_ERROR' using detail = 'child not found';
  end if;

  perform public.record_admin_audit_log(
    'admin.child_identity_revealed',
    'child_profile',
    p_child_id::text,
    'success',
    jsonb_build_object('justification', p_justification, 'family_id', v_family_id)
  );

  return query
  select cp.first_name, cp.nickname, cp.avatar_id, cp.birth_date
  from public.child_profiles cp
  where cp.id = p_child_id;
end;
$$;

comment on function public.admin_reveal_child_identity(uuid, text) is
  'Exige aal2 por baixo dos panos (record_admin_audit_log rejeita sem '
  'segundo fator verificado) — revelar identidade infantil é uma ação '
  'crítica, mesmo padrão de MFA reforçado no banco do resto do painel.';
