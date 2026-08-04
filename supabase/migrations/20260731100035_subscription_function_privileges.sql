-- Marco 7 — Assinaturas e Entitlements (parte 4/4)
-- Menor privilégio, mesmo padrão dos marcos anteriores.

revoke execute on all functions in schema public from public;

-- Funções que o app chama diretamente (responsável autenticado).
grant execute on function public.submit_purchase_receipt(uuid, text, text, text, text) to authenticated;
grant execute on function public.restore_entitlements(uuid) to authenticated;

-- Funções internas/webhook: só service_role (uma futura Edge Function que
-- valida a assinatura do webhook chama estas, ou outra função security
-- definer chama internamente).
grant execute on function public.verify_purchase(uuid, text, text, text, text, uuid) to service_role;
grant execute on function public.handle_apple_notification(text, text, text, text, timestamptz, timestamptz, timestamptz, jsonb) to service_role;
grant execute on function public.handle_google_notification(text, text, text, text, timestamptz, timestamptz, timestamptz, jsonb) to service_role;
grant execute on function public.handle_store_notification(text, text, text, text, text, timestamptz, timestamptz, timestamptz, jsonb) to service_role;
grant execute on function public.apply_subscription_transition(uuid) to service_role;
grant execute on function public.apply_safe_downgrade(uuid) to service_role;
grant execute on function public.restore_paused_entitlements(uuid) to service_role;

-- resolve_effective_plan_code: utilitária pura, sem grant a papel de
-- cliente (só chamada internamente), mesmo padrão de normalize_family_code.
