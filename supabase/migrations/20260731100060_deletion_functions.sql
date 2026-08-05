-- Marco 8 — funções do fluxo de exclusão dupla (docs/10 seção 10).
--
-- Simplificação registrada: "reautenticação" e "aviso de
-- irreversibilidade" (docs/10 seção 10, caminho de responsável único) são
-- responsabilidade do cliente (diálogo de confirmação forte antes de
-- chamar `request_family_deletion`) — não há reautenticação de senha
-- forçada no backend nesta passada, mesmo padrão de outras ações críticas
-- do app que já dependem só da sessão ativa.

create or replace function public.request_family_deletion(p_idempotency_key text)
returns table (
  request_id uuid,
  status text,
  requires_second_approval boolean,
  scheduled_for timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_family_id uuid;
  v_active_guardians int;
  v_requires_second boolean;
  v_request_id uuid;
  v_status text;
  v_scheduled timestamptz;
  v_guardian record;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if p_idempotency_key is null or length(trim(p_idempotency_key)) = 0 then
    raise exception 'VALIDATION_ERROR' using detail = 'idempotency_key is required';
  end if;

  if exists (select 1 from public.deletion_requests where idempotency_key = p_idempotency_key) then
    return query
      select d.id, d.status, d.requires_second_approval, d.scheduled_for
      from public.deletion_requests d
      where d.idempotency_key = p_idempotency_key;
    return;
  end if;

  select fm.family_id into v_family_id
  from public.family_members fm
  where fm.profile_id = v_profile_id and fm.status = 'active';

  if v_family_id is null then
    raise exception 'FORBIDDEN';
  end if;

  if exists (
    select 1 from public.deletion_requests
    where family_id = v_family_id and status in ('pending_approval', 'approved')
  ) then
    raise exception 'VALIDATION_ERROR' using detail = 'a deletion request is already in progress for this family';
  end if;

  select count(*) into v_active_guardians
  from public.family_members
  where family_id = v_family_id and status = 'active';

  v_requires_second := v_active_guardians > 1;
  v_status := case when v_requires_second then 'pending_approval' else 'approved' end;
  v_scheduled := case when v_requires_second then null else timezone('utc', now()) + interval '7 days' end;

  insert into public.deletion_requests (
    family_id, requested_by, requires_second_approval, status, scheduled_for, idempotency_key
  ) values (
    v_family_id, v_profile_id, v_requires_second, v_status, v_scheduled, p_idempotency_key
  )
  returning id into v_request_id;

  if v_requires_second then
    for v_guardian in
      select fm.profile_id from public.family_members fm
      where fm.family_id = v_family_id and fm.status = 'active' and fm.profile_id <> v_profile_id
    loop
      perform public.emit_notification(
        v_family_id, 'family.deletion_requested', 'deletion_request', v_request_id,
        'guardian', v_guardian.profile_id, null,
        'Pedido de exclusão da família',
        'Um responsável solicitou excluir a família. Sua aprovação é necessária.',
        '{}'::jsonb, '/guardian/privacy',
        'deletion_requested:' || v_request_id::text || ':' || v_guardian.profile_id::text
      );
    end loop;
  end if;

  return query select v_request_id, v_status, v_requires_second, v_scheduled;
end;
$$;

-- respond_family_deletion: só o(s) OUTRO(S) responsável(is) — nunca quem
-- pediu — aprova ou rejeita (docs/10 seção 10, passos 2-4).
create or replace function public.respond_family_deletion(
  p_request_id uuid,
  p_approve boolean,
  p_rejection_reason text default null
)
returns table (status text, scheduled_for timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_request public.deletion_requests%rowtype;
  v_new_status text;
  v_scheduled timestamptz;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select * into v_request from public.deletion_requests where id = p_request_id for update;

  if not found then
    raise exception 'VALIDATION_ERROR' using detail = 'request not found';
  end if;

  -- Autorização antes de qualquer detalhe de estado do pedido — um
  -- responsável de outra família não deve descobrir se um request_id
  -- existe, muito menos seu status, antes de sabermos que ele pertence à
  -- família (docs/10 seção 16: "teste de isolamento entre duas famílias").
  if not exists (
    select 1 from public.family_members fm
    where fm.family_id = v_request.family_id and fm.profile_id = v_profile_id and fm.status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  if v_request.status <> 'pending_approval' then
    raise exception 'VALIDATION_ERROR' using detail = 'request is not pending approval';
  end if;

  if v_profile_id = v_request.requested_by then
    raise exception 'VALIDATION_ERROR' using detail = 'the requester cannot respond to their own request';
  end if;

  if not p_approve and (p_rejection_reason is null or length(trim(p_rejection_reason)) = 0) then
    raise exception 'VALIDATION_ERROR' using detail = 'rejection_reason is required';
  end if;

  v_new_status := case when p_approve then 'approved' else 'rejected' end;
  v_scheduled := case when p_approve then timezone('utc', now()) + interval '7 days' else null end;

  update public.deletion_requests
  set status = v_new_status,
      second_guardian_id = v_profile_id,
      second_guardian_responded_at = timezone('utc', now()),
      rejection_reason = case when p_approve then null else p_rejection_reason end,
      scheduled_for = v_scheduled
  where id = p_request_id;

  perform public.emit_notification(
    v_request.family_id,
    case when p_approve then 'family.deletion_approved' else 'family.deletion_rejected' end,
    'deletion_request', p_request_id,
    'guardian', v_request.requested_by, null,
    case when p_approve then 'Exclusão aprovada' else 'Exclusão rejeitada' end,
    case when p_approve
      then 'A exclusão da família foi aprovada e está agendada. É possível cancelar a qualquer momento antes da data.'
      else 'O outro responsável rejeitou o pedido de exclusão.'
    end,
    '{}'::jsonb, '/guardian/privacy',
    'deletion_responded:' || p_request_id::text
  );

  return query select v_new_status, v_scheduled;
end;
$$;

-- cancel_family_deletion: qualquer responsável ativo, a qualquer momento
-- antes da execução (docs/10 seção 10, passo 6).
create or replace function public.cancel_family_deletion(p_request_id uuid)
returns table (status text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_request public.deletion_requests%rowtype;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select * into v_request from public.deletion_requests where id = p_request_id for update;

  if not found then
    raise exception 'VALIDATION_ERROR' using detail = 'request not found';
  end if;

  -- Autorização antes de qualquer detalhe de estado, mesmo raciocínio de
  -- respond_family_deletion acima.
  if not exists (
    select 1 from public.family_members fm
    where fm.family_id = v_request.family_id and fm.profile_id = v_profile_id and fm.status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  if v_request.status not in ('pending_approval', 'approved') then
    raise exception 'VALIDATION_ERROR' using detail = 'request cannot be cancelled in its current status';
  end if;

  update public.deletion_requests
  set status = 'cancelled', cancelled_by = v_profile_id, cancelled_at = timezone('utc', now())
  where id = p_request_id;

  perform public.emit_notification(
    v_request.family_id, 'family.deletion_cancelled', 'deletion_request', p_request_id,
    'guardian', fm.profile_id, null,
    'Exclusão cancelada', 'O pedido de exclusão da família foi cancelado.',
    '{}'::jsonb, '/guardian/privacy',
    'deletion_cancelled:' || p_request_id::text || ':' || fm.profile_id::text
  )
  from public.family_members fm
  where fm.family_id = v_request.family_id and fm.status = 'active';

  return query select 'cancelled'::text;
end;
$$;

-- process_scheduled_deletions: só service_role/pg_cron, mesmo padrão de
-- expire_due_task_occurrences (Marco 2) e expire_support_overrides
-- (Marco 7). Executa a exclusão de verdade quando o período de segurança
-- termina.
--
-- Sem notificação de conclusão: no momento em que a família some de
-- `family_members` (status 'removed'), a policy de leitura de
-- `notifications` do responsável já não alcança mais nada dessa família —
-- uma notificação "concluído" ficaria órfã. Confirmação por e-mail
-- (docs/10 seção 10, passo 9) depende de provedor de e-mail transacional,
-- pendência já registrada (docs/18 seção 4).
--
-- Anonimização (docs/10 seção 11: "apagar/anonimizar... manter apenas
-- registros legalmente necessários") é o default técnico adotado aqui,
-- pendente de validação jurídica (docs/18 seção 7): identidade da criança
-- é anonimizada; ledgers/eventos (histórico financeiro/de auditoria)
-- permanecem intocados, já que não carregam nome, só `child_id`.
create or replace function public.process_scheduled_deletions()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request record;
  v_child record;
begin
  for v_request in
    select * from public.deletion_requests
    where status = 'approved'
      and scheduled_for is not null
      and scheduled_for <= timezone('utc', now())
  loop
    for v_child in select id from public.child_profiles where family_id = v_request.family_id loop
      update public.child_device_bindings
      set revoked_at = timezone('utc', now())
      where child_id = v_child.id and revoked_at is null;
    end loop;

    update public.child_profiles
    set first_name = 'Criança excluída',
        nickname = null,
        private_photo_path = null,
        pin_hash = null,
        pin_enabled = false,
        status = 'archived'
    where family_id = v_request.family_id;

    update public.tasks
    set is_active = false, archived_at = timezone('utc', now())
    where family_id = v_request.family_id and is_active;

    update public.family_members
    set status = 'removed', removed_at = timezone('utc', now())
    where family_id = v_request.family_id and status = 'active';

    update public.families set status = 'deleted' where id = v_request.family_id;

    update public.deletion_requests
    set status = 'completed', completed_at = timezone('utc', now())
    where id = v_request.id;
  end loop;
end;
$$;
