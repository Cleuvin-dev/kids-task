-- Marco 6 — Notificações (parte 4/4)
-- Menor privilégio: funções client-facing para authenticated;
-- emit_notification permanece interna, sem grant a nenhum papel de
-- cliente, mesmo padrão de grant_task_rewards.

revoke execute on all functions in schema public from public;

grant execute on function public.register_device_token(text, text, text) to authenticated;
grant execute on function public.deactivate_device_token(uuid) to authenticated;
grant execute on function public.mark_notification_read(uuid) to authenticated;
