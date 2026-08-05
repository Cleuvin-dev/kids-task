-- Marco 7 (fatia 5) — menor privilégio, mesmo padrão das fatias anteriores.

revoke execute on all functions in schema public from public;

grant execute on function public.admin_list_themes() to authenticated;
grant execute on function public.admin_create_theme_draft(text, text, text) to authenticated;
grant execute on function public.admin_update_theme_manifest(uuid, jsonb) to authenticated;
grant execute on function public.admin_publish_theme(uuid, boolean) to authenticated;
grant execute on function public.admin_retire_theme(uuid) to authenticated;
grant execute on function public.admin_list_theme_requests() to authenticated;
grant execute on function public.admin_review_theme_request(uuid) to authenticated;
