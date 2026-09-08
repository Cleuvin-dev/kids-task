-- Correção de segurança: EXECUTE vazando para anon/authenticated em toda
-- função do schema public.
--
-- Achado ao aplicar as 65 migrations anteriores pela primeira vez contra um
-- projeto Supabase real (nunca tinham rodado antes — Docker ausente
-- localmente, ver docs/IMPLEMENTATION_STATUS.md "Bloqueios"): todo projeto
-- novo do Supabase já vem de fábrica com
-- `alter default privileges ... grant execute on functions to anon,
-- authenticated, service_role`. Isso concede EXECUTE diretamente aos papéis
-- `anon`/`authenticated` no momento em que cada função é criada — um grant
-- separado do papel `PUBLIC`. As migrations de privilégio anteriores
-- (`..._function_privileges.sql`, Marcos 1-8) só faziam
-- `revoke execute on all functions in schema public from public`, o que não
-- remove grants concedidos diretamente a `anon`/`authenticated` (só o
-- privilégio herdado de PUBLIC). Confirmado após o `db push`: toda função —
-- inclusive `verify_child_pin`, `resolve_family_children_by_code`,
-- `check_child_login_rate_limit`, funções administrativas e utilitárias
-- internas, que deveriam ser só `service_role` ou sem grant nenhum a
-- cliente — ficou executável por qualquer requisição sem sessão via
-- `/rest/v1/rpc/<função>`, contornando a autorização interna das próprias
-- funções e o rate limit da Edge Function. CLAUDE.md seção 4: "toda regra
-- SQL, função e política deve existir em migration versionada".

-- 1) Funções criadas a partir de agora não herdam mais o grant padrão do
--    Supabase para anon/authenticated.
alter default privileges in schema public
  revoke execute on functions from anon, authenticated;

-- 2) `anon` (requisição sem nenhuma sessão) nunca deve executar função
--    nenhuma deste projeto — nem o acesso da criança usa o papel `anon`
--    (sessão autenticada limitada e vinculada ao aparelho, docs/03 seção 6;
--    CLAUDE.md seção 5).
revoke execute on all functions in schema public from anon;

-- 3) Reseta `authenticated` para exatamente o conjunto já pretendido por
--    cada migration de privilégios dos Marcos 1-8 — remove o excesso
--    concedido pelo default do Supabase às funções que deveriam ser só
--    `service_role` ou sem nenhum grant a cliente (verify_child_pin,
--    internals de admin, jobs de cron, utilitárias de hash etc.), sem tocar
--    em `service_role`.
revoke execute on all functions in schema public from authenticated;

do $$
declare
  r record;
  intended text[] := array[
    'create_family', 'rotate_family_code', 'remove_guardian', 'create_child',
    'set_child_pin', 'revoke_child_device', 'invite_guardian',
    'cancel_guardian_invite', 'accept_guardian_invite',
    'create_device_pairing_code', 'upsert_task_with_schedule', 'pause_task',
    'resume_task', 'archive_task', 'complete_task_occurrence',
    'review_task_occurrence', 'skip_task_occurrence', 'adjust_child_coins',
    'request_redemption', 'review_redemption', 'mark_redemption_delivered',
    'cancel_approved_redemption', 'register_device_token',
    'deactivate_device_token', 'mark_notification_read', 'apply_child_theme',
    'submit_theme_request', 'submit_purchase_receipt', 'restore_entitlements',
    'is_active_platform_admin', 'admin_search_families',
    'admin_grant_subscription_override', 'admin_revoke_subscription_override',
    'record_admin_audit_log', 'admin_list_family_children',
    'admin_reveal_child_identity', 'admin_set_family_status',
    'admin_send_operational_notice', 'admin_get_dashboard_metrics',
    'admin_list_themes', 'admin_create_theme_draft',
    'admin_update_theme_manifest', 'admin_publish_theme', 'admin_retire_theme',
    'admin_list_theme_requests', 'admin_review_theme_request',
    'revoke_consent', 'request_family_deletion', 'respond_family_deletion',
    'cancel_family_deletion', 'export_family_data'
  ];
  found_count integer;
begin
  select count(*) into found_count
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = any (intended);

  if found_count <> array_length(intended, 1) then
    raise exception
      'fix_function_execute_privilege_leak: esperava % funções da lista pretendida, encontrou % — conferir nomes antes de regravar os grants',
      array_length(intended, 1), found_count;
  end if;

  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = any (intended)
  loop
    execute format('grant execute on function %s to authenticated', r.sig);
  end loop;
end $$;
