-- Marco 7 (fatia 4) — menor privilégio, mesmo padrão das fatias 2/3.

revoke execute on all functions in schema public from public;

grant execute on function public.admin_list_family_children(uuid) to authenticated;
grant execute on function public.admin_reveal_child_identity(uuid, text) to authenticated;
grant execute on function public.admin_set_family_status(uuid, text, text, text) to authenticated;
