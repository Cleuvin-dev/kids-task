-- Marco 7 (fatia 7) — menor privilégio, mesmo padrão das fatias anteriores.

revoke execute on all functions in schema public from public;

grant execute on function public.admin_send_operational_notice(uuid, text, text, text) to authenticated;
