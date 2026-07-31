# Edge Functions

Vazio no Marco 0 (Fundação). A primeira função chega no Marco 1 —
autorização de aparelho infantil (`authorize_child_device`) — ver
`docs/08_ARQUITETURA_TECNICA.md` seção 5 e `docs/14_APIS_FUNCOES_E_EVENTOS.md`.

Convenções para quando as funções forem criadas:

- uma pasta por função (`supabase/functions/<nome>/index.ts`);
- nenhum segredo (`service_role`, credenciais de push/loja) fora de
  `supabase secrets`;
- toda função crítica aceita e verifica uma chave de idempotência;
- rate limit e proteção contra enumeração nas funções de acesso infantil;
- `search_path` fixo em qualquer função SQL `security definer` chamada a
  partir daqui.
