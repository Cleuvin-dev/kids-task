-- Marco 7 (fatia 3) — Menor privilégio, mesmo padrão dos marcos
-- anteriores.

revoke execute on all functions in schema public from public;

-- is_active_platform_admin: usada dentro de policies de RLS (que rodam
-- como o papel de quem consulta) e também chamável diretamente.
grant execute on function public.is_active_platform_admin(text[]) to authenticated;

-- Funções que o painel chama diretamente (administrador autenticado; cada
-- uma valida o papel internamente).
grant execute on function public.admin_search_families(text) to authenticated;
grant execute on function public.admin_grant_subscription_override(uuid, timestamptz, text, text) to authenticated;
grant execute on function public.admin_revoke_subscription_override(uuid, text, text) to authenticated;

-- expire_support_overrides: só o agendador interno (pg_cron roda como o
-- dono do job, não como authenticated/anon) — mesmo padrão de
-- expire_due_task_occurrences.
grant execute on function public.expire_support_overrides() to service_role;
