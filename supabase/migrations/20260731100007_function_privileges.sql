-- Marco 1 — menor privilégio nas funções (docs/10 seção 9: "menor
-- privilégio, rate limit e proteção contra enumeração").
--
-- Por padrão o Postgres concede EXECUTE em novas funções a PUBLIC. Isso
-- deixaria funções internas (usadas só dentro de outras funções
-- security definer, ou só pela Edge Function via service_role) chamáveis
-- diretamente por qualquer cliente autenticado via RPC — inclusive
-- contornando o rate limit implementado na Edge Function. Este bloco revoga
-- o padrão e concede explicitamente apenas o necessário.

revoke execute on all functions in schema public from public;

-- Funções que o app chama diretamente (responsável autenticado).
grant execute on function public.create_family(text, text, text) to authenticated;
grant execute on function public.rotate_family_code(uuid) to authenticated;
grant execute on function public.remove_guardian(uuid, uuid) to authenticated;
grant execute on function public.create_child(uuid, text, date, text, text) to authenticated;
grant execute on function public.set_child_pin(uuid, text) to authenticated;
grant execute on function public.revoke_child_device(uuid) to authenticated;
grant execute on function public.invite_guardian(uuid, text) to authenticated;
grant execute on function public.cancel_guardian_invite(uuid) to authenticated;
grant execute on function public.accept_guardian_invite(text) to authenticated;
grant execute on function public.create_device_pairing_code(uuid) to authenticated;

-- Funções internas: só service_role (chamadas de dentro de Edge Functions)
-- ou invocadas indiretamente por outra função security definer, que roda
-- com o privilégio do dono da função, não do chamador original.
grant execute on function public.resolve_family_children_by_code(text) to service_role;
grant execute on function public.verify_child_pin(uuid, text) to service_role;
grant execute on function public.check_child_login_rate_limit(uuid) to service_role;
grant execute on function public.record_child_login_attempt(uuid, boolean, text) to service_role;

-- Utilitárias de hash/normalização: nunca expostas a nenhum papel de
-- cliente, só chamadas internamente por outras funções.
-- (sem grant para authenticated/anon/service_role de propósito)
