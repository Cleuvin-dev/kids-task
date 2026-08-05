-- Marco 7 (fatia 2) — Fundação do painel Web: função interna de
-- auditoria, reaproveitável por todos os módulos futuros do painel
-- (docs/12 seção 10, docs/14 seção 1: "sem regra de negócio crítica em
-- campos simples não precisa de função" — aqui a regra crítica é MFA
-- obrigatório mais a trilha append-only, então existe função).
--
-- MFA obrigatório é reforçado em duas camadas: o app só deixa a sessão
-- chegar num módulo do painel depois de aal2 (packages/data_access,
-- AdminSessionResolver), e esta função reforça de novo no banco — nenhuma
-- ação auditada é gravada sem o segundo fator já verificado nesta sessão,
-- mesmo que alguém tente chamar a função diretamente via RPC.
create or replace function public.record_admin_audit_log(
  p_action text,
  p_resource_type text,
  p_resource_id text default null,
  p_result text default 'success',
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin public.platform_admins%rowtype;
  v_id uuid;
begin
  select * into v_admin
  from public.platform_admins
  where profile_id = (select auth.uid()) and active;

  if not found then
    raise exception 'FORBIDDEN';
  end if;

  if coalesce((select auth.jwt() ->> 'aal'), 'aal1') <> 'aal2' then
    raise exception 'FORBIDDEN';
  end if;

  insert into public.audit_logs (
    actor_profile_id, actor_role, action, resource_type, resource_id, result, metadata
  ) values (
    v_admin.profile_id, v_admin.role, p_action, p_resource_type, p_resource_id, p_result, p_metadata
  )
  returning id into v_id;

  return v_id;
end;
$$;
