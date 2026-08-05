-- Marco 7 (fatia 2) — Menor privilégio, mesmo padrão dos marcos anteriores.

revoke execute on all functions in schema public from public;

grant execute on function public.record_admin_audit_log(text, text, text, text, jsonb) to authenticated;
