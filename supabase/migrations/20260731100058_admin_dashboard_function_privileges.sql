-- Marco 7 (fatia 7) — menor privilégio, mesmo padrão das fatias anteriores.

revoke execute on all functions in schema public from public;

grant execute on function public.admin_get_dashboard_metrics() to authenticated;
