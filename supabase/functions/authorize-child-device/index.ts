// Segundo passo do acesso infantil: autoriza este aparelho (sessão anônima)
// a atuar como a criança escolhida, via PIN ou via código de pareamento
// gerado pelo responsável (docs/03 seção 6-7; docs/08 seção 5; ADR 0001).
//
// Nunca cria e-mail fictício nem deriva senha do PIN. `service_role` só é
// usado dentro desta função; nunca chega ao cliente.
import { corsHeaders } from "../_shared/cors.ts";
import { callerClient, serviceRoleClient } from "../_shared/clients.ts";

const GENERIC_ERROR = { error: "AUTHORIZATION_FAILED" };

interface RequestBody {
  family_code?: string;
  child_id?: string;
  device_name?: string;
  pin?: string;
  pairing_code?: string;
}

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

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "VALIDATION_ERROR" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { family_code, child_id, device_name, pin, pairing_code } = body;
  if (!family_code || !child_id || !device_name) {
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

  const fail = async () => {
    await admin.rpc("record_child_login_attempt", {
      p_auth_user_id: authUserId,
      p_succeeded: false,
    });
    return new Response(JSON.stringify(GENERIC_ERROR), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  };

  const { data: children, error: resolveError } = await admin.rpc(
    "resolve_family_children_by_code",
    { p_family_code: family_code },
  );
  if (resolveError) return await fail();

  type ChildRow = {
    child_id: string;
    pin_enabled: boolean;
  };
  const child = (children as ChildRow[] | null)?.find((c) => c.child_id === child_id);
  if (!child) return await fail();

  let authorizedBy: string | null = null;

  if (child.pin_enabled) {
    if (!pin) return await fail();
    const { data: pinOk } = await admin.rpc("verify_child_pin", {
      p_child_id: child_id,
      p_pin: pin,
    });
    if (!pinOk) return await fail();
  } else {
    if (!pairing_code) return await fail();
    const { data: pairingRow } = await admin
      .from("device_pairing_codes")
      .select("id, created_by, expires_at, used_at")
      .eq("child_id", child_id)
      .eq("code_digest", await sha256Hex(normalizeCode(pairing_code)))
      .is("used_at", null)
      .maybeSingle();

    if (!pairingRow || new Date(pairingRow.expires_at) < new Date()) {
      return await fail();
    }

    const { data: consumed } = await admin
      .from("device_pairing_codes")
      .update({ used_at: new Date().toISOString() })
      .eq("id", pairingRow.id)
      .is("used_at", null)
      .select("id");

    if (!consumed || consumed.length === 0) return await fail();
    authorizedBy = pairingRow.created_by;
  }

  // Um aparelho lembra apenas o último perfil infantil autorizado
  // (docs/03 seção 8): revoga qualquer vínculo ativo anterior deste aparelho.
  await admin
    .from("child_device_bindings")
    .update({ revoked_at: new Date().toISOString() })
    .eq("auth_user_id", authUserId)
    .is("revoked_at", null);

  const { data: binding, error: insertError } = await admin
    .from("child_device_bindings")
    .insert({
      child_id,
      auth_user_id: authUserId,
      device_name,
      authorized_by: authorizedBy,
    })
    .select("id")
    .single();

  if (insertError || !binding) return await fail();

  await admin.rpc("record_child_login_attempt", {
    p_auth_user_id: authUserId,
    p_succeeded: true,
  });

  return new Response(
    JSON.stringify({ child_id, device_binding_id: binding.id }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});

function normalizeCode(code: string): string {
  return code.toUpperCase().replace(/[^A-Z0-9]/g, "");
}

async function sha256Hex(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
