import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

/**
 * Cliente que atua com a identidade de quem chamou a função (respeita RLS).
 * Usado para descobrir `auth.uid()` do chamador a partir do JWT recebido.
 */
export function callerClient(req: Request): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization")! } } },
  );
}

/**
 * Cliente com `service_role`, ignora RLS. Só usado para as operações que
 * exigem privilégio elevado (login infantil antes de existir vínculo,
 * escrita em tabelas sem policy de INSERT para o cliente). A chave nunca
 * chega ao app — vive apenas no ambiente de execução da Edge Function.
 */
export function serviceRoleClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}
