-- Marco 7 (fatia 5) — módulo "Temas e conteúdo" (docs/12 seção 6): criar
-- rascunho, validar manifest, definir gratuito/Premium, publicar versão,
-- retirar sem quebrar famílias atuais.
--
-- Simplificação registrada, mesma raiz da já registrada no Marco 5 (sem
-- `theme_assets`/pipeline de CDN): "upload de assets" aqui não é upload de
-- arquivo — o catálogo de temas em `packages/design_system` é código Dart
-- compilado (`buildKidsThemeBySlug`), não carregado em runtime de um
-- Storage. Então "editar o manifest" é apontar
-- `manifest_json.background_asset_key` para uma chave que um dev já
-- processou e publicou em `packages/design_system` — o painel administra o
-- catálogo (metadado: slug, nome, plano, status, versão), não a arte em
-- si. Publicar exige confirmação humana de revisão de propriedade
-- intelectual (`p_ip_review_confirmed`, docs/12 seção 6: "revisão de
-- propriedade intelectual") — contraste/acessibilidade/tamanho máximo
-- continuam checados por revisão humana antes de um dev publicar a build,
-- não por um validador automático que não existe.
--
-- "Retirar sem quebrar famílias atuais": retirar só tira o tema de
-- `themes_select_authenticated` (RLS já filtra `status = 'published'`) e
-- de `apply_child_theme` (só aceita tema `published`). Uma criança que já
-- tinha o tema aplicado continua com `child_profiles.theme_slug` apontando
-- pro slug retirado (a FK não é tocada, a linha em `themes` não é
-- apagada) e `buildKidsThemeBySlug` resolve pelo slug direto do catálogo
-- estático do app, sem consultar a tabela — nada quebra.

create or replace function public.admin_list_themes()
returns table (
  theme_id uuid,
  slug text,
  name text,
  plan_tier text,
  manifest_json jsonb,
  version integer,
  status text,
  published_at timestamptz,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_active_platform_admin(array['super_admin', 'content']) then
    raise exception 'FORBIDDEN';
  end if;

  return query
  select t.id, t.slug, t.name, t.plan_tier, t.manifest_json, t.version, t.status, t.published_at, t.created_at
  from public.themes t
  order by t.created_at;
end;
$$;

create or replace function public.admin_create_theme_draft(
  p_slug text,
  p_name text,
  p_plan_tier text
)
returns table (theme_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_theme_id uuid;
begin
  if not public.is_active_platform_admin(array['super_admin', 'content']) then
    raise exception 'FORBIDDEN';
  end if;

  if p_slug is null or length(trim(p_slug)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'slug is required';
  end if;

  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'name is required';
  end if;

  if p_plan_tier not in ('free', 'premium') then
    raise exception 'VALIDATION_ERROR' using detail = 'invalid plan_tier';
  end if;

  if exists (select 1 from public.themes where slug = trim(p_slug)) then
    raise exception 'VALIDATION_ERROR' using detail = 'slug already exists';
  end if;

  insert into public.themes (slug, name, plan_tier, manifest_json, status)
  values (trim(p_slug), trim(p_name), p_plan_tier, '{}'::jsonb, 'draft')
  returning id into v_theme_id;

  perform public.record_admin_audit_log(
    'admin.theme_draft_created', 'theme', v_theme_id::text, 'success',
    jsonb_build_object('slug', trim(p_slug), 'plan_tier', p_plan_tier)
  );

  return query select v_theme_id;
end;
$$;

-- Editar o manifest de um tema já publicado é uma nova versão de
-- conteúdo (docs/12 seção 12: "publicação de tema é versionada") — editar
-- um rascunho ainda não publicado não bump a versão (nada foi publicado
-- ainda). Retirado fica congelado: reeditar exige republicar primeiro.
create or replace function public.admin_update_theme_manifest(
  p_theme_id uuid,
  p_manifest_json jsonb
)
returns table (status text, version integer)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  if not public.is_active_platform_admin(array['super_admin', 'content']) then
    raise exception 'FORBIDDEN';
  end if;

  if p_manifest_json is null then
    raise exception 'VALIDATION_ERROR' using detail = 'manifest_json is required';
  end if;

  select t.status into v_status from public.themes t where t.id = p_theme_id for update;

  if v_status is null then
    raise exception 'VALIDATION_ERROR' using detail = 'theme not found';
  end if;

  if v_status = 'retired' then
    raise exception 'VALIDATION_ERROR' using detail = 'theme is retired; republish before editing';
  end if;

  update public.themes
  set manifest_json = p_manifest_json,
      version = case when v_status = 'published' then version + 1 else version end
  where id = p_theme_id;

  perform public.record_admin_audit_log(
    'admin.theme_manifest_updated', 'theme', p_theme_id::text, 'success',
    jsonb_build_object('manifest_json', p_manifest_json)
  );

  return query select t.status, t.version from public.themes t where t.id = p_theme_id;
end;
$$;

create or replace function public.admin_publish_theme(
  p_theme_id uuid,
  p_ip_review_confirmed boolean
)
returns table (status text, version integer, published_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_manifest jsonb;
begin
  if not public.is_active_platform_admin(array['super_admin', 'content']) then
    raise exception 'FORBIDDEN';
  end if;

  if not coalesce(p_ip_review_confirmed, false) then
    raise exception 'VALIDATION_ERROR' using detail = 'ip_review_confirmed is required';
  end if;

  select t.status, t.manifest_json into v_status, v_manifest
  from public.themes t where t.id = p_theme_id for update;

  if v_status is null then
    raise exception 'VALIDATION_ERROR' using detail = 'theme not found';
  end if;

  if v_status = 'published' then
    raise exception 'VALIDATION_ERROR' using detail = 'theme is already published';
  end if;

  if coalesce(v_manifest ->> 'background_asset_key', '') = '' then
    raise exception 'VALIDATION_ERROR' using detail = 'manifest_json.background_asset_key is required to publish';
  end if;

  update public.themes
  set status = 'published',
      published_at = timezone('utc', now()),
      version = case when v_status = 'retired' then version + 1 else version end
  where id = p_theme_id;

  perform public.record_admin_audit_log(
    'admin.theme_published', 'theme', p_theme_id::text, 'success',
    jsonb_build_object('previous_status', v_status)
  );

  return query select t.status, t.version, t.published_at from public.themes t where t.id = p_theme_id;
end;
$$;

create or replace function public.admin_retire_theme(p_theme_id uuid)
returns table (status text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  if not public.is_active_platform_admin(array['super_admin', 'content']) then
    raise exception 'FORBIDDEN';
  end if;

  select t.status into v_status from public.themes t where t.id = p_theme_id for update;

  if v_status is null then
    raise exception 'VALIDATION_ERROR' using detail = 'theme not found';
  end if;

  if v_status <> 'published' then
    raise exception 'VALIDATION_ERROR' using detail = 'only a published theme can be retired';
  end if;

  update public.themes set status = 'retired' where id = p_theme_id;

  perform public.record_admin_audit_log(
    'admin.theme_retired', 'theme', p_theme_id::text, 'success', '{}'::jsonb
  );

  return query select t.status from public.themes t where t.id = p_theme_id;
end;
$$;
