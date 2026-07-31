# ADR 0001 — Autenticação da criança por sessão técnica vinculada ao aparelho

**Status:** aceito

**Data:** 2026-07-31 (Marco 0 — Fundação)

## Contexto

O Kid's Task é um único aplicativo Flutter que atende dois perfis muito
diferentes — responsável e criança — usando o mesmo backend Supabase. O
responsável autentica normalmente com e-mail/senha (Supabase Auth). A criança
não tem e-mail nem senha: ela entra com o código da família, escolhe seu
perfil e, opcionalmente, digita um PIN; sem PIN, o aparelho precisa já ter
sido autorizado por um responsável (`docs/03_USUARIOS_FAMILIA_E_AUTENTICACAO.md`,
seções 6–7).

Toda tabela exposta no Postgres precisa de RLS (`CLAUDE.md`, seção 4), o que
exige que a criança tenha uma identidade verificável por `auth.uid()` — mas
sem criar credenciais falsas nem expor a criança a mecanismos pensados para
adultos.

## Alternativas consideradas

1. **E-mail fictício + senha derivada do PIN.** Rejeitada explicitamente:
   `CLAUDE.md` e `docs/08_ARQUITETURA_TECNICA.md` (seção 5) proíbem e-mail
   infantil fictício e derivação de senha a partir do PIN. Criaria uma
   credencial reutilizável fora do controle do responsável e dificultaria
   revogação por aparelho.
2. **JWT customizado sem vínculo por aparelho.** Permitiria a mesma sessão
   "criança" ser reutilizada em qualquer aparelho sem rastro de qual aparelho
   fez login, impossibilitando a revogação granular e a auditoria de "novo
   aparelho infantil" exigida em `docs/11_NOTIFICACOES.md` (seção 3).
3. **Sessão anônima do Supabase Auth + tabela de vínculo por aparelho.**
   Escolhida — detalhada abaixo.

## Decisão

1. O aplicativo cria (ou restaura) uma **sessão anônima do Supabase Auth**
   por aparelho. Essa sessão tem seu próprio `auth.uid()`, mas nenhuma
   permissão até ser vinculada a uma criança.
2. Uma **Edge Function** (`authorize_child_device`, a implementar no Marco 1)
   recebe o código da família e o PIN (ou um token de pareamento curto gerado
   pelo responsável) e:
   - aplica rate limit e atraso progressivo;
   - compara apenas contra digests seguros (nunca texto puro);
   - retorna erro genérico em caso de falha, sem indicar qual dado estava
     errado (proteção contra enumeração, `docs/03` seção 6).
3. Em caso de sucesso, a função cria um registro em `child_device_bindings`
   ligando aquele `auth.uid()` técnico a um `child_id` específico, com
   `device_name`, `authorized_by`, `authorized_at` e `revoked_at` nulo.
4. As políticas RLS de todas as tabelas infantis (tarefas, carteira, XP,
   recompensas etc.) verificam a existência de um vínculo **ativo** entre
   `auth.uid()` e o `child_id` da linha, em vez de confiar em qualquer claim
   enviada pelo cliente.
5. Revogar o vínculo (responsável, a qualquer momento) zera o acesso
   imediatamente — nenhuma re-autenticação do cliente é necessária para que a
   próxima requisição já falhe.
6. Um aparelho lembra apenas o último perfil infantil autorizado; trocar de
   criança no mesmo aparelho exige novo PIN ou nova autorização adulta
   (`docs/03`, seção 8).

## Consequências

- Nenhuma credencial reutilizável de criança existe fora do backend; revogar
  é uma operação de dados (UPDATE em `child_device_bindings`), não uma
  operação de identidade.
- RLS pode ser expressa como uma junção simples contra o vínculo ativo, sem
  `security definer` amplo nem exceções por tabela.
- Cada login infantil bem-sucedido ou malsucedido é auditável por aparelho,
  cumprindo a exigência de registrar tentativas suspeitas e notificar "novo
  aparelho infantil" ao responsável.
- Custo: a lógica de autorização vive inteiramente em uma Edge Function
  (não em RLS pura), então toda mudança nesse fluxo exige nova versão da
  função com testes de autorização e rate limit — não apenas uma migration.
- Este ADR não define o schema exato de `child_device_bindings` nem a Edge
  Function em si; isso é implementado no Marco 1 (`docs/16_BACKLOG_E_ROADMAP.md`),
  seguindo o modelo já descrito em `docs/09_MODELO_DE_DADOS.md`, seção 2.
