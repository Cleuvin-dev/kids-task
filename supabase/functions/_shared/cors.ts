// Cabeçalhos CORS compartilhados. O app móvel/admin_web chama estas funções
// diretamente via supabase-flutter; nenhuma origem de terceiro é esperada,
// mas CORS precisa responder ao preflight do navegador (admin_web/testes).
export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
