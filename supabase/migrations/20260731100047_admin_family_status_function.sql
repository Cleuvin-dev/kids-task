-- Marco 7 (fatia 4) — admin_set_family_status (docs/12 seção 11):
-- "exige motivo; não apaga dados; revoga ou restringe sessões conforme
-- risco; notifica responsáveis quando apropriado; permite revisão e
-- reversão auditada."
--
-- "Não apaga dados": a função só troca `families.status` (já existe desde
-- o Marco 1, com os 5 estados no check constraint) — nenhuma linha é
-- removida em nenhum caminho.
--
-- "Revoga ou restringe sessões conforme risco": o vínculo de aparelho da
-- criança (`child_device_bindings`) pode ser revogado por SQL de verdade —
-- é exatamente o que `revoke_child_device` (Marco 1) já faz, e todo o app
-- já respeita `revoked_at is null` para manter uma sessão infantil viva
-- (RLS + SessionRoleResolver). A sessão do responsável (Supabase Auth/GoTrue)
-- não pode ser invalidada por uma função SQL comum sem `service_role` do
-- Auth Admin API — fora do escopo de uma migration. Em vez disso, o app
-- móvel passa a tratar `families.status` fora de active/restricted como um
-- estado de sessão explícito (bloqueio síncrono no redirect do router,
-- packages/data_access SessionRoleResolver) — a próxima vez que o
-- responsável abrir o app ou a sessão for revalidada, o acesso é negado.
create or replace function public.admin_set_family_status(
  p_family_id uuid,
  p_new_status text,
  p_reason text,
  p_idempotency_key text
)
returns table (status text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin_id uuid := (select auth.uid());
  v_previous_status text;
  v_child record;
  v_title text;
  v_body text;
begin
  if not public.is_active_platform_admin(array['super_admin', 'support']) then
    raise exception 'FORBIDDEN';
  end if;

  if p_idempotency_key is null or length(trim(p_idempotency_key)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'idempotency_key is required';
  end if;

  if p_reason is null or length(trim(p_reason)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'reason is required';
  end if;

  if p_new_status not in ('active', 'restricted', 'blocked', 'deletion_pending', 'deleted') then
    raise exception 'VALIDATION_ERROR' using detail = 'invalid status';
  end if;

  if exists (select 1 from public.family_status_events where idempotency_key = p_idempotency_key) then
    return query select f.status from public.families f where f.id = p_family_id;
    return;
  end if;

  select f.status into v_previous_status
  from public.families f
  where f.id = p_family_id
  for update;

  if v_previous_status is null then
    raise exception 'VALIDATION_ERROR' using detail = 'family not found';
  end if;

  if v_previous_status = p_new_status then
    raise exception 'VALIDATION_ERROR' using detail = 'family is already in this status';
  end if;

  update public.families set status = p_new_status where id = p_family_id;

  insert into public.family_status_events (
    family_id, previous_status, new_status, reason, changed_by, idempotency_key
  ) values (
    p_family_id, v_previous_status, p_new_status, p_reason, v_admin_id, p_idempotency_key
  );

  -- Estados fora de active/restricted revogam todo aparelho infantil
  -- vinculado — mesmo efeito de revoke_child_device, aplicado a todas as
  -- crianças da família de uma vez. Reverter para 'active' não volta a
  -- autorizar nada sozinho: o responsável precisa parear o aparelho de
  -- novo (mesma decisão de segurança do fluxo manual do Marco 1 — restaurar
  -- automaticamente seria reabrir uma sessão sem verificação nova).
  if p_new_status not in ('active', 'restricted') then
    for v_child in select id from public.child_profiles where family_id = p_family_id loop
      update public.child_device_bindings
      set revoked_at = timezone('utc', now())
      where child_id = v_child.id and revoked_at is null;
    end loop;
  end if;

  -- Notifica responsáveis quando apropriado (docs/12 seção 11) — nunca em
  -- linguagem punitiva (CLAUDE.md/docs/06), e nunca ao voltar para
  -- 'active' (é um alívio, não precisa de notificação própria).
  if p_new_status <> 'active' then
    v_title := 'Atualização sobre sua família';
    v_body := case p_new_status
      when 'restricted' then 'Algumas funções da sua conta foram temporariamente restritas. Fale com o suporte para mais informações.'
      when 'blocked' then 'O acesso da sua família foi temporariamente bloqueado. Fale com o suporte para mais informações.'
      when 'deletion_pending' then 'Uma exclusão de conta foi solicitada para sua família. Fale com o suporte se isso não foi você.'
      when 'deleted' then 'A conta da sua família foi encerrada.'
      else 'O status da sua família foi atualizado.'
    end;

    perform public.emit_notification(
      p_family_id, 'family.status_changed', 'family', p_family_id,
      'guardian', fm.profile_id, null,
      v_title, v_body,
      jsonb_build_object('new_status', p_new_status), null,
      'family_status_changed:' || p_idempotency_key || ':' || fm.profile_id::text
    )
    from public.family_members fm
    where fm.family_id = p_family_id and fm.status = 'active';
  end if;

  perform public.record_admin_audit_log(
    'admin.family_status_changed',
    'family',
    p_family_id::text,
    'success',
    jsonb_build_object('previous_status', v_previous_status, 'new_status', p_new_status, 'reason', p_reason)
  );

  return query select f.status from public.families f where f.id = p_family_id;
end;
$$;
