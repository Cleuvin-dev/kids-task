-- Marco 3 — KidsCoins e Recompensas (parte 4/4)
-- Menor privilégio nas novas funções, mesmo padrão de
-- 20260731100007_function_privileges.sql / 20260731100012_task_function_privileges.sql.

revoke execute on all functions in schema public from public;

grant execute on function public.adjust_child_coins(uuid, integer, text, text, text) to authenticated;
grant execute on function public.request_redemption(uuid, text) to authenticated;
grant execute on function public.review_redemption(uuid, text, text, integer, text) to authenticated;
grant execute on function public.mark_redemption_delivered(uuid, text) to authenticated;
grant execute on function public.cancel_approved_redemption(uuid, text, text) to authenticated;
