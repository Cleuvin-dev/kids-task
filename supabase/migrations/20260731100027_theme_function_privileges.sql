-- Marco 5 — Temas e Experiência por Idade (parte 3/3)
-- Menor privilégio, mesmo padrão dos marcos anteriores.

revoke execute on all functions in schema public from public;

grant execute on function public.apply_child_theme(uuid, text) to authenticated;
grant execute on function public.submit_theme_request(uuid, text, text, text, text, boolean) to authenticated;
