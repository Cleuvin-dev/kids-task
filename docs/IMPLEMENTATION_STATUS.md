# Status de Implementação

**Última atualização:** 31/07/2026

**Estado atual:** Marco 0 — Fundação concluído.

## Repositório

- Estrutura: monorepo criado conforme `docs/08_ARQUITETURA_TECNICA.md` —
  `apps/mobile`, `apps/admin_web`, `packages/{domain,data_access,design_system}`,
  `supabase/{migrations,functions,tests}`, `docs/adr`.
- Flutter mobile (`apps/mobile`): projeto Flutter Android/iOS (`org com.kidstask`),
  compila, com tela de fundação usando tema, l10n (pt) e `go_router` ligados.
- Admin Web (`apps/admin_web`): projeto Flutter Web, compila, mesma estrutura
  de fundação, tema e l10n próprios.
- Packages compartilhados:
  - `domain`: Dart puro (sem Flutter). `UserRole`, `DomainErrorCode`,
    `DomainFailure`, `Result<T>`.
  - `data_access`: depende de Flutter + `supabase_flutter`. `SupabaseEnv`
    (config via `--dart-define-from-file`) e `KidsTaskSupabase` (inicialização
    única do cliente).
  - `design_system`: Flutter. Tokens semânticos (`KidsTaskTokens`), temas
    azul/rosa do responsável e Tema Infantil Padrão (placeholder de cor,
    sem asset final).
- Supabase local: `supabase/config.toml` gerado via CLI (`npx supabase init`),
  primeira migration de fundação (extensão `pgcrypto` + trigger
  `set_updated_at`), `seed.sql` vazio documentado, teste pgTAP de fundação em
  `supabase/tests/database/00_foundation_test.sql`, `supabase/functions/README.md`
  com convenções para a primeira Edge Function (Marco 1).
- CI: `.github/workflows/ci.yml` com jobs de formatação/análise/teste por
  pacote e app, build de fumaça Android (debug) + Web, build de fumaça iOS
  (`--no-codesign`, runner macOS), lint/teste do banco via Supabase CLI
  (`supabase start` + `db lint` + `test db`) e verificação de segredos
  (`gitleaks`). Ainda não executado em CI real (sem push/PR neste ciclo).
- `.env.example`: documentado na raiz (Supabase URL/publishable key, Firebase
  project id, IDs de produto de loja); nenhum segredo de backend incluído.
- `docs/adr/0001-autenticacao-infantil.md`: decisão de sessão anônima do
  Supabase + `child_device_bindings` + Edge Function + RLS, com alternativas
  rejeitadas e consequências.
- Supabase CLI local: instalado como devDependency npm (`npx supabase`,
  v2.111.0) — ver bloqueios abaixo sobre Docker.

## Marcos

| Marco | Estado | Evidência |
|---|---|---|
| 0 — Fundação | **Concluído** | Ver seções acima; comandos de qualidade na tabela abaixo |
| 1 — Autenticação e família | Não iniciado | — |
| 2 — Rotina e tarefas | Não iniciado | — |
| 3 — KidsCoins e recompensas | Não iniciado | — |
| 4 — XP e progressão | Não iniciado | — |
| 5 — Temas e idade | Não iniciado | — |
| 6 — Notificações | Não iniciado | — |
| 7 — Premium e painel | Não iniciado | — |
| 8 — Privacidade e release | Não iniciado | — |

## Testes (executados localmente em 31/07/2026)

| Comando | Escopo | Resultado |
|---|---|---|
| `dart format --set-exit-if-changed .` | domain, data_access, design_system, apps/mobile, apps/admin_web | ✅ Sem alterações pendentes (após reformatação inicial) |
| `flutter analyze` | domain, data_access, design_system, apps/mobile, apps/admin_web | ✅ "No issues found" em todos |
| `flutter test` | domain (8 testes), data_access (2), design_system (6), apps/mobile (1), apps/admin_web (1) | ✅ 18/18 passando |
| `flutter build apk --debug` | apps/mobile | ✅ `build/app/outputs/flutter-apk/app-debug.apk` gerado |
| `flutter build web` | apps/admin_web | ✅ `build/web` gerado |
| `flutter build ios --no-codesign` | apps/mobile | ⛔ Não executável localmente (Windows); validado apenas no job `build_smoke_ios` do CI (runner macOS) |
| `supabase db lint --local` | supabase/ | ⛔ Bloqueado localmente: exige Docker (`ECONNREFUSED 127.0.0.1:54322`), ausente neste ambiente de desenvolvimento. Roda no CI (`supabase` job), onde Docker está disponível no runner `ubuntu-latest` |
| `supabase test db` | supabase/ | ⛔ Mesmo bloqueio acima |

## Bloqueios

1. **Docker ausente no ambiente de desenvolvimento local** — impede rodar
   `supabase start`/`db lint`/`test db` nesta máquina. Não bloqueia o CI
   (runners `ubuntu-latest` do GitHub Actions incluem Docker). Ação: instalar
   Docker Desktop localmente quando for necessário depurar migrations sem
   depender só do CI.
2. **Projetos Supabase por ambiente (dev/staging/prod) ainda não existem** —
   `.env.example` documenta as chaves esperadas, mas nenhum valor real foi
   criado (depende de conta/organização Supabase). Bloqueia apenas testes de
   integração reais; não bloqueia migrations, RLS ou lógica de domínio.
3. **Projeto(s) Firebase ainda não existem** — mesmo motivo; bloqueia push
   real (Marco 6) e configuração de `google-services.json`/
   `GoogleService-Info.plist`, não o Marco 0.
4. **Contas de loja (App Store/Google Play) ainda não existem** — bloqueia
   IDs de produto reais e testes de compra (Marco 7), documentado também em
   `docs/18_PENDENCIAS_NAO_BLOQUEANTES.md`.
5. **CI ainda não rodou em GitHub Actions** — o workflow foi escrito e os
   comandos equivalentes foram validados localmente onde possível, mas o
   primeiro push/PR precisa confirmar o pipeline verde de ponta a ponta
   (em especial os jobs `supabase` e `build_smoke_ios`, que dependem de
   recursos indisponíveis localmente).

Nenhum desses bloqueios impede o Marco 1; todos dependem de contas externas
ou de infraestrutura de CI, conforme previsto em `CLAUDE.md` ("implemente a
interface/adapter, documente o bloqueio e continue no que for independente").

## Próxima ação

Marco 1 — Autenticação e Família: cadastro/login do responsável, consentimentos,
criação de família, convite por e-mail/deep link, cadastro de criança, código
familiar, PIN opcional, sessão anônima + `child_device_bindings` (implementando
o ADR 0001), guards de perfil no `go_router` e RLS familiar completa.
