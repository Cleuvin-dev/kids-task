# Status de Implementação

**Última atualização:** 31/07/2026

**Estado atual:** Marco 0 — Fundação concluído. Marco 1 — Autenticação e
Família concluído (com bloqueios de infraestrutura documentados abaixo).
**Ciclo pausado aqui a pedido do proprietário do produto** — a implementação
retoma no **Marco 2 — Rotina e Tarefas** numa sessão futura. Este documento e
o `git log` são a fonte de verdade do que já existe; ler esta seção e a
"Próxima ação" antes de continuar.

## Repositório

- Estrutura: monorepo conforme `docs/08_ARQUITETURA_TECNICA.md` —
  `apps/mobile`, `apps/admin_web`, `packages/{domain,data_access,design_system}`,
  `supabase/{migrations,functions,tests}`, `docs/adr`.
- Identidade visual: assets reais de `img/` processados (remoção de fundo de
  croma, recorte, recompressão) em `packages/design_system/assets` e
  `packages/design_system/branding` — ver
  `packages/design_system/assets/README.md` para a origem de cada arquivo.
  Ícone do app (Android/iOS) e splash nativo gerados a partir dessas artes
  via `flutter_launcher_icons`/`flutter_native_splash`; favicon/ícones Web do
  `admin_web` também atualizados.

### apps/mobile

Aplicativo único (responsável + criança) com fluxo de autenticação real de
ponta a ponta:

- Entrada comum (`/access`) com fundo `tela-de-login.png` e wordmark.
- Responsável: cadastro/login por e-mail e senha (com tela de "confirme seu
  e-mail" quando a confirmação é exigida), "esqueci minha senha".
- Consentimento (`/onboarding/consent`) antes da família existir; o registro
  em `consent_records` é persistido logo após a família ser criada (a tabela
  exige `family_id`, que só existe a partir desse ponto).
- Criação de família com escolha de tema azul/rosa (sem relação com gênero)
  e exibição do código familiar gerado pelo servidor.
- Cadastro da primeira criança (nome, apelido, nascimento, avatar de uma
  lista fixa neutra quanto a gênero).
- Início do responsável (`/guardian/home`) com dados reais: família, código
  (com regeneração), responsáveis vinculados, convite de novo responsável
  (com aviso claro quando o envio de e-mail está `not_configured`), lista de
  crianças.
- Detalhe da criança: definir/remover PIN, gerar código de pareamento para
  aparelho sem PIN, listar e revogar aparelhos autorizados.
- Acesso da criança (`/access/child`): código da família → seleção de
  avatar/apelido → PIN ou código de pareamento → sessão vinculada.
- Início da criança (`/child/home`): nome, avatar, aviso honesto de que
  tarefas/KidsCoins/XP chegam nos próximos marcos (nada simulado); saída
  atrás de uma barreira parental simples (pergunta de soma para adulto).
- Guard único em `go_router`: `redirect` sempre lê `resolvedSessionProvider`
  (backend) de forma síncrona, com `RouterRefreshNotifier` (via `ref.listen`)
  reagindo a qualquer mudança de sessão — nenhuma rota abre um shell por
  flag local.

### Backend (Supabase)

- Migrations (`supabase/migrations/202607311000{01..07}_*.sql`):
  `plans` (seed free/premium), `profiles` (+ trigger em `auth.users`),
  `families`, `family_members`, `family_invites`, `child_profiles`,
  `child_device_bindings`, `consent_records`, `child_login_attempts`,
  `device_pairing_codes`; RLS em todas; funções `create_family`,
  `rotate_family_code`, `remove_guardian`, `create_child` (valida
  `PLAN_CHILD_LIMIT`), `set_child_pin`, `revoke_child_device`,
  `invite_guardian`, `cancel_guardian_invite`, `accept_guardian_invite`,
  `create_device_pairing_code`, `resolve_family_children_by_code`,
  `verify_child_pin`, rate limit (`check_child_login_rate_limit`,
  `record_child_login_attempt`).
- Privilégio mínimo: `revoke execute ... from public` seguido de `grant`
  explícito por papel — funções internas (verificação de PIN, resolução de
  código, rate limit) só são executáveis por `service_role`, nunca
  diretamente por `authenticated`/`anon` via RPC.
- Edge Functions (`supabase/functions/`): `authorize-child-device` e
  `resolve-family-children` implementam o ADR 0001 (sessão anônima +
  `child_device_bindings` + rate limit + erro genérico); `send-guardian-invite`
  cria o convite via RPC e tenta enviar e-mail (bloqueio documentado abaixo).
- `docs/adr/0001-autenticacao-infantil.md`: decisão registrada antes da
  implementação, com alternativas rejeitadas.

### CI

- `.github/workflows/ci.yml` (criado no Marco 0): formatação/análise/teste
  por pacote e app, build de fumaça Android/Web/iOS, lint/teste do banco via
  Supabase CLI, verificação de segredos. Ainda não executado em CI real.

## Marcos

| Marco | Estado | Evidência |
|---|---|---|
| 0 — Fundação | **Concluído** | Ver `IMPLEMENTATION_STATUS.md` (histórico) |
| 1 — Autenticação e família | **Concluído** | Ver seções acima; testes abaixo |
| 2 — Rotina e tarefas | Não iniciado | — |
| 3 — KidsCoins e recompensas | Não iniciado | — |
| 4 — XP e progressão | Não iniciado | — |
| 5 — Temas e idade | Não iniciado | Catálogo de temas e assets já registrados em `design_system` (`kidsThemeCatalog`), aguardando telas/backend de seleção |
| 6 — Notificações | Não iniciado | — |
| 7 — Premium e painel | Não iniciado | — |
| 8 — Privacidade e release | Não iniciado | — |

## Testes (executados localmente em 31/07/2026)

| Comando | Escopo | Resultado |
|---|---|---|
| `dart format --set-exit-if-changed .` | domain, data_access, design_system, apps/mobile, apps/admin_web | ✅ Sem alterações pendentes |
| `flutter analyze` | idem | ✅ "No issues found" em todos os 5 |
| `flutter test` | domain (8), data_access (7), design_system (8), apps/mobile (1), apps/admin_web (1) | ✅ 25/25 passando |
| `flutter build apk --debug` | apps/mobile | ✅ `build/app/outputs/flutter-apk/app-debug.apk` gerado (com ícone/splash reais) |
| `flutter build web` | apps/admin_web | ✅ `build/web` gerado (Marco 0) |
| `flutter build ios --no-codesign` | apps/mobile | ⛔ Não executável neste Windows; validado só no CI (runner macOS) |
| `supabase db lint` / `supabase test db` | supabase/ | ⛔ Exigem Docker (ausente aqui); migrations e pgTAP revisados manualmente, execução real pendente do CI |
| `supabase functions serve` | Edge Functions | ⛔ Também exige Docker; as três funções foram revisadas manualmente linha a linha (sem checagem de tipos do Deno) |

## Bloqueios

1. **Docker ausente localmente** — impede `supabase start`/`db lint`/
   `test db`/`functions serve` nesta máquina. As migrations, políticas RLS,
   funções SQL e Edge Functions foram revisadas manualmente com atenção a
   nomes de coluna, tipos e assinaturas, mas **não foram executadas** contra
   um Postgres real neste ciclo. Isso inclui o teste pgTAP novo
   (`supabase/tests/database/10_marco1_family_auth_test.sql`), que só será
   confirmado quando rodar em CI ou numa máquina com Docker.
2. **Provedor de e-mail transacional não configurado** — `send-guardian-invite`
   cria o convite normalmente e retorna `email_delivery: "not_configured"` com
   o link para compartilhar manualmente. Documentado também em
   `docs/18_PENDENCIAS_NAO_BLOQUEANTES.md`.
3. **Domínio do painel/app não decidido** — o link de convite usa
   `https://app.kidstask.com.br/invite` como placeholder explícito
   (`docs/18`, seção 5).
4. **Projetos Supabase/Firebase/lojas por ambiente ainda não existem** — como
   no Marco 0; bloqueia testes de integração reais, não a lógica implementada.
5. **CI ainda não rodou em GitHub Actions** — pendente do primeiro push/PR.

## Build de verificação manual (release APK)

Para permitir instalar o app num celular Android e conferir visualmente o
que existe até aqui, foi gerado um APK release
(`apps/mobile/build/app/outputs/flutter-apk/app-release.apk`), assinado com
a chave de debug padrão do Flutter (`signingConfig = signingConfigs.debug`
em `android/app/build.gradle.kts` — suficiente para instalar num aparelho
próprio via "instalar de fontes desconhecidas", não serve para publicar na
Play Store).

Como não existe projeto Supabase real ainda (bloqueio já listado acima), o
build usa credenciais **placeholder** (`apps/mobile/env/dev.json`, ignorado
pelo Git). Isso significa:

- o app abre normalmente até a tela de acesso comum (splash → "Sou
  responsável"/"Sou criança"), com o ícone, o splash e o visual reais;
- os formulários (entrar, criar conta, código da família etc.) abrem e
  validam campos normalmente;
- qualquer ação que precise falar com o backend de verdade (cadastrar,
  entrar, criar família) vai falhar com erro genérico, porque
  `https://example.supabase.co` não existe — isso é esperado, não é um bug.

Quando houver um projeto Supabase real, gerar `env/dev.json` com os valores
verdadeiros (formato documentado em `.env.example`) e rebuildar para testar
o fluxo completo de ponta a ponta.

## Próxima ação

Retomar no **Marco 2 — Rotina e Tarefas**: catálogo de ícones/tarefas,
agendas (recorrente, data única, bônus, sem horário, com prazo), geração de
ocorrências, limite gratuito de três por dia, tela "Hoje" real para a
criança, conclusão automática/manual, rejeição/correção, atraso/expiração,
Realtime, histórico — sobre a base de família/criança já criada no Marco 1.

Antes de iniciar novas telas, recomenda-se validar este Marco 1 num ambiente
com Docker (`supabase start`, `supabase db lint --local`, `supabase test db`)
e, se possível, um projeto Supabase real de desenvolvimento, para confirmar
que as migrations aplicam sem erro e o teste pgTAP passa de fato.
