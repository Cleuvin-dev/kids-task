-- Marco 7 (fatia 5) — fila de solicitações Premium de tema (docs/12 seção
-- 6). `theme_requests` já existe desde o Marco 5 (docs/06 seção 10); até
-- aqui nada no painel a consultava. `admin_list_theme_requests` precisa
-- ser security definer para juntar o e-mail de quem pediu (auth.users, sem
-- RLS visível a authenticated) — mesmo motivo de admin_search_families.

create or replace function public.admin_list_theme_requests()
returns table (
  request_id uuid,
  family_id uuid,
  family_name text,
  requested_by_email text,
  category text,
  colors text,
  description text,
  target_age_range text,
  status text,
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
  select tr.id, tr.family_id, f.name, u.email, tr.category, tr.colors, tr.description,
         tr.target_age_range, tr.status, tr.created_at
  from public.theme_requests tr
  join public.families f on f.id = tr.family_id
  join auth.users u on u.id = tr.created_by
  order by tr.status, tr.created_at;
end;
$$;

create or replace function public.admin_review_theme_request(p_request_id uuid)
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

  select tr.status into v_status from public.theme_requests tr where tr.id = p_request_id for update;

  if v_status is null then
    raise exception 'VALIDATION_ERROR' using detail = 'request not found';
  end if;

  if v_status = 'reviewed' then
    raise exception 'VALIDATION_ERROR' using detail = 'request already reviewed';
  end if;

  update public.theme_requests set status = 'reviewed' where id = p_request_id;

  perform public.record_admin_audit_log(
    'admin.theme_request_reviewed', 'theme_request', p_request_id::text, 'success', '{}'::jsonb
  );

  return query select tr.status from public.theme_requests tr where tr.id = p_request_id;
end;
$$;
