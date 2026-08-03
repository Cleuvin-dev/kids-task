# Status de Implementação

**Última atualização:** 03/08/2026

**Estado atual:** Marco 0 — Fundação concluído. Marco 1 — Autenticação e
Família concluído. Marco 2 — Rotina e Tarefas concluído. Marco 3 —
KidsCoins e Recompensas concluído (com bloqueios de infraestrutura
documentados abaixo — nada foi executado contra um Postgres real neste
ciclo). Este documento e o `git log` são a fonte de verdade do que já
existe; ler esta seção e a "Próxima ação" antes de continuar.

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
- **Marco 2** — tarefas e rotina, sobre a base de família/criança do Marco 1:
  - Responsável (`/guardian/children/:childId/tasks`): lista de tarefas da
    criança, criar/editar num único formulário (`task_form_page.dart`) que
    cobre os cinco tipos de agenda via campos condicionais (recorrente com
    dias da semana, data única, sem horário, com prazo, bônus), pausar/
    retomar/arquivar, catálogo de templates prontos
    (`/guardian/tasks/templates`, docs/17), inbox de aprovações pendentes
    (`/guardian/approvals`) com aprovar/rejeitar (motivo obrigatório) e
    Realtime.
  - Criança (`/child/home`): `ChildTodaySection` substitui o placeholder
    "em breve" por uma lista real das ocorrências de hoje, com o botão
    "Concluir"/"Corrigir e reenviar" conforme o estado, Realtime, e
    linguagem neutra (nunca punitiva) para tarefa atrasada/expirada.
  - Nenhuma rota nova mexeu no `redirect` síncrono do router — todas
    entram nos branches `GuardianSession`/`ChildSession` já existentes.
- **Marco 3** — KidsCoins e recompensas, sobre a carteira mínima do Marco 2:
  - Responsável (`/guardian/rewards`): catálogo de recompensas (CRUD direto
    via RLS, sem RPC — cadastro simples sem regra de plano), ativar/
    desativar (recompensa inativa some do catálogo mas fica no histórico),
    escopo "toda a família" ou uma criança específica; inbox de resgates
    (`/guardian/redemptions`) com aprovar/rejeitar solicitações e marcar
    entregue/cancelar (com estorno) resgates aprovados; ajuste manual de
    KidsCoins (crédito/débito com motivo obrigatório) na tela de detalhe da
    criança.
  - Criança (`/child/rewards`, acessível pelo saldo exibido em
    `/child/home`): catálogo com botão "Resgatar" desabilitado quando o
    saldo é insuficiente, lista dos próprios pedidos com status em
    linguagem simples.
  - Nenhuma rota nova mexeu no `redirect` síncrono do router.

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
- **Marco 2** — migrations (`supabase/migrations/202607311000{08..15}_*.sql`):
  `tasks`, `task_schedules`, `task_occurrences`, `task_events` (máquina de
  estados completa do docs/04 seção 7, snapshots imutáveis, unique index
  anti-duplicação); `child_wallets`/`coin_ledger`/`xp_ledger` (carteira
  mínima — só crédito atômico ao aprovar, sem catálogo de recompensas,
  ajuste manual ou nível/streak, que ficam para os Marcos 3/4);
  `task_templates` com seed de ~55 tarefas prontas do docs/17; RLS dupla
  (responsável administra, criança só lê o que é dela) em todas as tabelas
  novas; funções `upsert_task_with_schedule` (valida limite diário do plano
  gratuito antes de ativar, nunca ativa silenciosamente acima do limite),
  `pause_task`/`resume_task`/`archive_task`, `complete_task_occurrence`,
  `review_task_occurrence`, `skip_task_occurrence` (todas com idempotência,
  expostas a `authenticated`); `generate_task_occurrences` e
  `expire_due_task_occurrences` (só `service_role`, agendadas via
  `pg_cron`); `grant_task_rewards` (interna, sem grant a nenhum papel de
  cliente); views `v_child_today_tasks`/`v_pending_approvals`
  (`security_invoker = true`); Realtime habilitado em `task_occurrences`.
- pgTAP: `supabase/tests/database/20_marco2_tasks_and_occurrences_test.sql`
  (41 asserções) cobrindo a máquina de estados completa, crédito idempotente
  sob duplo-tap e duplo-approve simultâneo, limite diário do plano gratuito,
  `allow_late` vs `expire_no_reward`, isolamento RLS entre famílias e
  privilégio mínimo.
- **Marco 3** — migrations (`supabase/migrations/202607311000{16..19}_*.sql`):
  `rewards` (RLS com insert/update para o responsável — sem RPC dedicada,
  já que não há regra de negócio além de autorização, docs/14 seção 1),
  `redemption_requests` (máquina de estados `requested → approved|rejected`,
  `approved → delivered|cancelled`, snapshots imutáveis de título/custo),
  `redemption_events` (auditoria append-only, mesmo padrão de
  `task_events`); `coin_ledger.entry_type` ampliado para incluir
  `manual_adjustment`/`redemption`/`redemption_refund` (editado direto na
  migration do Marco 2 antes de qualquer commit/execução real); funções
  `adjust_child_coins` (motivo obrigatório, bloqueia débito acima do saldo),
  `request_redemption` (valida saldo na solicitação), `review_redemption`
  (revalida saldo na aprovação, débito exatamente uma vez), 
  `mark_redemption_delivered` (nunca debita de novo),
  `cancel_approved_redemption` (estorno atômico com motivo) — todas
  idempotentes, expostas a `authenticated`.
- pgTAP: `supabase/tests/database/30_marco3_rewards_and_redemptions_test.sql`
  (32 asserções) cobrindo ajuste manual (motivo obrigatório, saldo nunca
  negativo), resgate pendente não debita, saldo insuficiente bloqueia a
  aprovação, aprovação debita exatamente uma vez mesmo sob retry, entrega
  não debita de novo, rejeição não debita, cancelamento aprovado gera
  estorno integral, isolamento RLS entre famílias e privilégio mínimo.

### CI

- `.github/workflows/ci.yml` (criado no Marco 0): formatação/análise/teste
  por pacote e app, build de fumaça Android/Web/iOS, lint/teste do banco via
  Supabase CLI, verificação de segredos. Ainda não executado em CI real.

## Marcos

| Marco | Estado | Evidência |
|---|---|---|
| 0 — Fundação | **Concluído** | Ver `IMPLEMENTATION_STATUS.md` (histórico) |
| 1 — Autenticação e família | **Concluído** | Ver seções acima; testes abaixo |
| 2 — Rotina e tarefas | **Concluído** | Ver seções acima; testes abaixo |
| 3 — KidsCoins e recompensas | **Concluído** | Ver seções acima; testes abaixo. Taxa de conversão simbólica KidsCoin→BRL (docs/05 seção 6) **não implementada** — valor sugerido ainda é pendência não bloqueante (docs/18) |
| 4 — XP e progressão | Não iniciado | `xp_ledger`/`child_wallets.current_level` já existem como schema (Marco 2, placeholder nunca escrito); falta nível, streak, desbloqueios |
| 5 — Temas e idade | Não iniciado | Catálogo de temas e assets já registrados em `design_system` (`kidsThemeCatalog`), aguardando telas/backend de seleção |
| 6 — Notificações | Não iniciado | — |
| 7 — Premium e painel | Não iniciado | — |
| 8 — Privacidade e release | Não iniciado | — |

## Testes (executados localmente em 03/08/2026)

| Comando | Escopo | Resultado |
|---|---|---|
| `dart format --set-exit-if-changed .` | domain, data_access, design_system, apps/mobile, apps/admin_web | ✅ Sem alterações pendentes |
| `flutter analyze` | idem | ✅ "No issues found" em todos os 5 |
| `flutter test` | domain (26), data_access (9), design_system (8), apps/mobile (5), apps/admin_web (1) | ✅ 49/49 passando |
| `supabase db lint` / `supabase test db` | supabase/ | ⛔ Exigem Docker (ausente aqui); migrations, funções SQL e os pgTAP dos Marcos 2 e 3 (73 asserções ao todo) revisados manualmente linha a linha, execução real pendente do CI |
| `flutter build apk --debug` / `flutter build web` / `flutter build ios --no-codesign` | apps/mobile, apps/admin_web | Não reexecutados neste ciclo (sem mudança de dependências nativas); ver Marco 0/1 para o último build real |

## Bloqueios

1. **Docker ausente localmente** — impede `supabase start`/`db lint`/
   `test db`/`functions serve` nesta máquina. As migrations, políticas RLS
   e funções SQL dos Marcos 2 e 3 foram revisadas manualmente com atenção a
   nomes de coluna, tipos e assinaturas, mas **não foram executadas** contra
   um Postgres real. Isso inclui os dois pgTAP novos, que só serão
   confirmados quando rodarem em CI ou numa máquina com Docker.
2. **`pg_cron` não confirmado no projeto Supabase real** — a migration
   `20260731100015_task_cron_jobs.sql` assume que a extensão está
   disponível (padrão em projetos Supabase Cloud), mas isso só pode ser
   verificado quando existir um projeto real (bloqueio 4 abaixo).
3. **Provedor de e-mail transacional não configurado** — `send-guardian-invite`
   cria o convite normalmente e retorna `email_delivery: "not_configured"` com
   o link para compartilhar manualmente. Documentado também em
   `docs/18_PENDENCIAS_NAO_BLOQUEANTES.md`.
4. **Domínio do painel/app não decidido** — o link de convite usa
   `https://app.kidstask.com.br/invite` como placeholder explícito
   (`docs/18`, seção 5).
5. **Projetos Supabase/Firebase/lojas por ambiente ainda não existem** — como
   no Marco 0; bloqueia testes de integração reais, não a lógica implementada.
6. **CI ainda não rodou em GitHub Actions** — pendente do primeiro push/PR.

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

**Marco 4 — XP e Progressão**: `process_level_changes` (calcula nível a
partir do `xp_ledger` já existente, concede bônus de nível configurável por
criança — `child_wallets.current_level`, já reservado desde o Marco 2 —,
lida com pular vários níveis numa só aprovação, idempotente por
`level_up:<child_id>:<level>`), `grant_birthday_bonus` (uma vez por ano,
`birthday:<child_id>:<year>`, regra especial para 29/02),
`recalculate_daily_progress`/`advance_streak` (regra por criança —
`at_least_one`/`all_required`/`percentage`, já modelada em
`child_profiles.streak_rule`/`streak_percentage` desde o Marco 1 — tarefas
bônus fora do denominador, tarefa dispensada sai do denominador, dia sem
tarefa obrigatória é neutro), desbloqueios de cosméticos por nível+plano
(`level_definitions`, `cosmetic_items`, `child_unlocks`), tela de
progresso/nível/streak na criança, sem ranking entre irmãos (docs/05
seções 7-13).

Antes de iniciar, recomenda-se validar os Marcos 1-3 num ambiente com
Docker (`supabase start`, `supabase db lint --local`, `supabase test db`) e,
se possível, um projeto Supabase real de desenvolvimento — nenhuma migration
ou função SQL destes marcos foi executada contra um Postgres de verdade
ainda, só revisada manualmente. Confirmar também se `pg_cron` está
disponível nesse projeto (bloqueio 2 acima).
