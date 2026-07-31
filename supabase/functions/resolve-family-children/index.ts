// Primeiro passo do acesso infantil: valida o código da família e devolve a
// lista mínima de perfis para a tela de seleção de avatar/apelido
// (docs/03_USUARIOS_FAMILIA_E_AUTENTICACAO.md, seção 6, passo 3; ADR 0001).
//
// Exige uma sessão anônima já criada pelo app (auth.uid() do aparelho).
// Aplica o mesmo rate limit de `authorize-child-device`, pois este endpoint
// também é uma superfície de tentativa-e-erro sobre o código da família.
import { corsHeaders } from "../_shared/cors.ts";
import { callerClient, serviceRoleClient } from "../_shared/clients.ts";

const GENERIC_ERROR = { error: "INVALID_CODE_OR_RATE_LIMITED" };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const caller = callerClient(req);
  const { data: userData, error: userError } = await caller.auth.getUser();
  if (userError || !userData?.user) {
    return new Response(JSON.stringify({ error: "AUTH_REQUIRED" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
  const authUserId = userData.user.id;

  let familyCode: string;
  try {
    const body = await req.json();
    familyCode = String(body.family_code ?? "");
  } catch {
    return new Response(JSON.stringify({ error: "VALIDATION_ERROR" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const admin = serviceRoleClient();

  const { data: allowed } = await admin.rpc("check_child_login_rate_limit", {
    p_auth_user_id: authUserId,
  });
  if (allowed === false) {
    return new Response(JSON.stringify(GENERIC_ERROR), {
      status: 429,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { data: children, error } = await admin.rpc(
    "resolve_family_children_by_code",
    { p_family_code: familyCode },
  );

  await admin.rpc("record_child_login_attempt", {
    p_auth_user_id: authUserId,
    p_succeeded: !error,
  });

  if (error) {
    return new Response(JSON.stringify(GENERIC_ERROR), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ children }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
