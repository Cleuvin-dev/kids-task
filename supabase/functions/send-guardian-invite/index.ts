// Cria o convite (via RPC, que já garante autorização e as regras de
// negócio) e tenta enviar o e-mail com o link de aceite.
//
// BLOQUEIO CONHECIDO: nenhum provedor de e-mail transacional está
// configurado neste ambiente (docs/18_PENDENCIAS_NAO_BLOQUEANTES.md, seção
// 4: "remetente e provedor de e-mail transacional" ainda a definir). A
// função cria o convite normalmente e retorna `email_delivery: "not_configured"`
// junto com o link, para que a equipe possa compartilhá-lo manualmente
// enquanto o provedor não existe. Quando houver provedor, implemente
// `sendInviteEmail` sem alterar o restante do fluxo.
import { corsHeaders } from "../_shared/cors.ts";
import { callerClient } from "../_shared/clients.ts";

// Domínio do painel/app ainda não decidido (docs/18, seção 5: "domínio do
// painel Web"). Placeholder documentado — trocar quando o domínio existir.
const INVITE_LINK_BASE = "https://app.kidstask.com.br/invite";

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

  let familyId: string, email: string;
  try {
    const body = await req.json();
    familyId = String(body.family_id ?? "");
    email = String(body.email ?? "");
  } catch {
    return new Response(JSON.stringify({ error: "VALIDATION_ERROR" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { data, error } = await caller.rpc("invite_guardian", {
    p_family_id: familyId,
    p_email: email,
  });

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const invite = Array.isArray(data) ? data[0] : data;
  const inviteLink = `${INVITE_LINK_BASE}?token=${invite.token}`;

  const emailDelivery = await sendInviteEmail(email, inviteLink);

  return new Response(
    JSON.stringify({
      invite_id: invite.invite_id,
      expires_at: invite.expires_at,
      invite_link: inviteLink,
      email_delivery: emailDelivery,
    }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});

/**
 * Adapter de envio de e-mail. Sem provedor configurado, apenas registra a
 * intenção de envio e sinaliza `not_configured` — nunca falha a criação do
 * convite por causa disso (o convite e o link continuam válidos).
 */
async function sendInviteEmail(
  email: string,
  inviteLink: string,
): Promise<"sent" | "not_configured" | "failed"> {
  const apiKey = Deno.env.get("TRANSACTIONAL_EMAIL_API_KEY");
  if (!apiKey) {
    console.warn(
      `[send-guardian-invite] provedor de e-mail não configurado; link para ${email}: ${inviteLink}`,
    );
    return "not_configured";
  }

  // TODO(Marco 1 pendência externa): implementar a chamada real ao provedor
  // escolhido assim que uma conta existir (docs/18_PENDENCIAS_NAO_BLOQUEANTES.md).
  return "not_configured";
}
