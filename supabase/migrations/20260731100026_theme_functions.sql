-- Marco 5 — Temas e Experiência por Idade (parte 2/3)
-- apply_child_theme e submit_theme_request (docs/14 seção 6).

create or replace function public.apply_child_theme(
  p_child_id uuid,
  p_theme_slug text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_family_id uuid;
  v_plan_code text;
  v_theme record;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select cp.family_id into v_family_id
  from public.child_profiles cp
  where cp.id = p_child_id;

  if v_family_id is null then
    raise exception 'VALIDATION_ERROR' using detail = 'child not found';
  end if;

  if not exists (
    select 1 from public.family_members fm
    where fm.family_id = v_family_id and fm.profile_id = v_profile_id and fm.status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  select t.slug, t.plan_tier, t.status into v_theme
  from public.themes t
  where t.slug = p_theme_slug;

  if not found or v_theme.status <> 'published' then
    raise exception 'VALIDATION_ERROR' using detail = 'theme not available';
  end if;

  if v_theme.plan_tier = 'premium' then
    select p.code into v_plan_code
    from public.families f
    join public.plans p on p.id = f.plan_id
    where f.id = v_family_id;

    if v_plan_code <> 'premium' then
      raise exception 'THEME_NOT_ENTITLED';
    end if;
  end if;

  update public.child_profiles
  set theme_slug = p_theme_slug
  where id = p_child_id;
end;
$$;

create or replace function public.submit_theme_request(
  p_family_id uuid,
  p_category text,
  p_colors text,
  p_description text,
  p_target_age_range text,
  p_consent boolean
)
returns table (request_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_request_id uuid;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if not exists (
    select 1 from public.family_members fm
    where fm.family_id = p_family_id and fm.profile_id = v_profile_id and fm.status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  if not coalesce(p_consent, false) then
    raise exception 'VALIDATION_ERROR' using detail = 'consent is required';
  end if;

  if p_category is null or length(trim(p_category)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'category is required';
  end if;

  insert into public.theme_requests (
    family_id, category, colors, description, target_age_range, consent, created_by
  ) values (
    p_family_id, trim(p_category), p_colors, p_description, p_target_age_range, true, v_profile_id
  )
  returning id into v_request_id;

  return query select v_request_id;
end;
$$;
