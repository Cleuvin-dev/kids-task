# Status de Implementação

**Última atualização:** 05/08/2026

**Estado atual:** Marco 0 — Fundação concluído. Marco 1 — Autenticação e
Família concluído. Marco 2 — Rotina e Tarefas concluído. Marco 3 —
KidsCoins e Recompensas concluído. Marco 4 — XP e Progressão concluído.
Marco 5 — Temas e Experiência por Idade concluído. Marco 6 — Notificações
concluído **parcialmente** (central interna funciona de ponta a ponta;
push de verdade via FCM/APNs está bloqueado por falta de projeto Firebase
real — ver "Bloqueios"). Marco 7 — Premium e Painel iniciado
**parcialmente**: backend de assinaturas (fatia 1) e fundação do painel
Web — login separado + MFA obrigatório + auditoria (fatia 2) — estão
prontos; `apps/admin_web` ainda não tem nenhum módulo (famílias, conteúdo,
assinaturas, notificações, suporte). Este documento e o `git log` são a
fonte de verdade do que já existe; ler esta seção e a "Próxima ação" antes
de continuar.

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
- **Marco 4** — nível, XP e streak, sem tela nova (embutido nas telas
  existentes):
  - Criança (`/child/home`): card de nível com barra de progresso até o
    próximo nível (calculada a partir de `level_definitions` + XP total,
    o cliente nunca recalcula a fórmula) e contador de dias seguidos de
    streak.
  - Responsável (detalhe da criança): card "Nível N · M dias de streak"
    com um diálogo para configurar a regra de streak
    (`at_least_one`/`all_required`/`percentage`), o percentual mínimo, o
    bônus de KidsCoins por nível e o bônus de aniversário — grava direto
    em `child_profiles` via RLS (mesmo princípio de docs/14 seção 1: sem
    regra de negócio crítica nesses campos, não precisa de função).
  - Sem tela de desbloqueios de cosméticos — adiado para o Marco 5 junto
    do catálogo de temas.
- **Marco 5** — temas de verdade (o app inteiro rodava só no tema azul do
  responsável antes deste marco, inclusive nas telas da criança — a
  aplicação dinâmica de tema nunca tinha sido ligada):
  - `router.dart` ganhou dois `ShellRoute`: um envolvendo todas as rotas
    `/guardian/*` que aplica `buildGuardianTheme` a partir de
    `families.guardian_theme` (`familyGuardianThemeProvider`), outro
    envolvendo `/child/*` que aplica `buildKidsThemeBySlug` a partir de
    `child_profiles.theme_slug` (`childThemeSlugProvider`) — cada um só
    um `Theme(...)` sobre o `child` do Shell, sem tocar no `redirect`
    síncrono nem duplicar rotas.
  - `packages/design_system`: `buildBlockWorldTheme`/
    `buildSpaceAdventureTheme`/`buildCastlesQuestTheme` (cores/geometria
    originais, sem nenhum asset de terceiros — docs/06 seção 4) e
    `buildKidsThemeBySlug(slug)`, que cai no Tema Infantil Padrão para
    qualquer slug desconhecido ou ainda sem build (docs/06 seção 6:
    "asset ausente nunca pode quebrar uma tela").
  - Responsável: card "Tema do app" na home (trocar azul/rosa,
    `families.guardian_theme` via RLS) e tela `/guardian/children/:childId/theme`
    (catálogo publicado, cadeado nos temas Premium quando a família é
    free, "Solicitar um tema" para o formulário de docs/06 seção 10).
  - Nenhuma rota nova mexeu no `redirect` síncrono do router.
- **Marco 6** — central interna de notificações (`/guardian/notifications`
  e `/child/notifications`, mesma tela `NotificationCenterPage` para os
  dois perfis — a RLS de `notifications` já resolve "de quem" é cada
  notificação), ícone de sino na home do responsável e da criança, toque
  marca como lida e navega para o `deep_link` gravado no evento.
  Registro/preferência de push (`register_device_token` etc.) não tem
  tela ainda — sem SDK de push instalado, não há token real para
  registrar (bloqueio abaixo).

### apps/admin_web

Painel administrativo Web, separado do app móvel (docs/12 seção 10:
"login separado do app infantil") — mesmo `Supabase Auth`, conta e sessão
distintas.

- **Marco 7 (fatia 2)** — fundação (login + MFA obrigatório), sobre o
  scaffold do Marco 0:
  - `/admin/access`: login por e-mail/senha, "esqueci minha senha". Sem
    "criar conta" — provisionar um administrador é operação manual
    (`service_role`; ver "Bloqueios" abaixo), não um fluxo de autocadastro.
  - `/admin/mfa/enroll`: enrolamento TOTP obrigatório na primeira vez —
    mostra a chave secreta para digitar num app autenticador (sem QR code
    nesta fatia, para não trazer uma dependência de renderização de SVG só
    para a fundação; uso interno, poucos operadores) e confirma com um
    código de 6 dígitos.
  - `/admin/mfa/challenge`: verificação de MFA em sessões que já têm um
    fator TOTP verificado, mas ainda estão em `aal1`.
  - `/admin/unauthorized`: conta autenticada sem vínculo ativo em
    `platform_admins` — estado explícito em vez de erro genérico (não
    deveria acontecer em uso normal, já que não há autocadastro).
  - `/admin/home`: placeholder pós-login mostrando o papel do
    administrador; nenhum módulo (famílias, conteúdo, assinaturas,
    notificações, suporte) existe ainda — fica para as próximas fatias.
  - Guard único em `go_router`, mesmo padrão do app móvel: `redirect`
    sempre lê `adminResolvedSessionProvider` (backend + estado de MFA da
    sessão) de forma síncrona, com `RouterRefreshNotifier` reagindo a
    mudanças — nenhuma sessão chega a `/admin/home` sem `aal2`.
  - `packages/data_access/src/admin`: `AdminAuthRepository`,
    `AdminMfaRepository` (enrolar/verificar TOTP via `supabase_flutter`
    `auth.mfa`), `AdminSessionResolver` (`AdminNoSession` /
    `AdminUnauthorized` / `AdminMfaEnrollmentRequired` /
    `AdminMfaChallengeRequired` / `AdminSession`, paralelo ao
    `SessionRoleResolver` do app móvel) e `AdminAuditLogRepository`
    (`record_admin_audit_log`). `packages/domain`: `AdminRole`.

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
- **Marco 4** — migrations (`supabase/migrations/202607311000{20..24}_*.sql`):
  `level_definitions` (seed de 30 níveis pela fórmula `50 × (L-1) × L` do
  docs/05 seção 8 — o bônus de KidsCoins por nível continua sendo
  `child_profiles.level_bonus_coins`, já configurável desde o Marco 1, não
  uma coluna nova), `daily_progress`, `child_streaks`; `coin_ledger.entry_type`
  ampliado para `level_bonus`/`birthday_bonus`; funções internas (sem grant
  a nenhum papel de cliente) `process_level_changes` (credita todos os
  níveis cruzados numa aprovação, idempotente por
  `level_up:<child_id>:<level>`), `recalculate_daily_progress` e
  `advance_streak` (regra por criança, tarefa bônus fora do denominador,
  tarefa dispensada sai do denominador, dia sem tarefa obrigatória é
  neutro, idempotente por `last_qualified_date`); `grant_birthday_bonus`
  (só `service_role`/cron, idempotente por `birthday:<child_id>:<year>`,
  29/02 vira 28/02 em ano não bissexto). `complete_task_occurrence` e
  `review_task_occurrence` (do Marco 2) foram **redefinidas** (novo
  `create or replace function` numa migration nova — a migration original
  do Marco 2, já commitada, não foi editada) para chamar as três funções
  de progressão depois de `grant_task_rewards`.
- **Simplificações registradas** (ver comentários nas migrations): (1)
  `recalculate_daily_progress` usa a definição *atual* de
  `tasks.is_required`/`is_bonus`, não um snapshot por ocorrência — o
  Marco 2 não persistiu esse snapshot; a janela de divergência é pequena
  porque o recálculo roda no mesmo dia da aprovação; (2) `advance_streak`
  cobre o caso comum (dias processados em ordem crescente) — uma
  aprovação tardia que corrige um dia muito antigo não recalcula toda a
  cadeia de streak seguinte automaticamente; (3) desbloqueios de
  cosméticos (`cosmetic_items`/`child_unlocks`, docs/05 seção 10) ficam
  para o Marco 5, junto do catálogo de temas — schema vazio sem conteúdo
  para desbloquear não agregaria nada agora.
- pgTAP: `supabase/tests/database/40_marco4_progression_test.sql`
  (39 asserções) cobrindo cruzar um nível, cruzar vários níveis numa só
  aprovação, retry sem duplicar bônus, aniversário idempotente (com
  proteção para o teste rodar num 29/02), streak nas três regras
  (`at_least_one`, `percentage`), dia neutro com tarefa dispensada, streak
  quebrando com tarefa obrigatória não cumprida, isolamento RLS e
  privilégio mínimo.
- **Marco 5** — migrations (`supabase/migrations/202607311000{25..27}_*.sql`):
  `themes` (catálogo publicado de verdade, substituindo a lista estática
  que só existia em `packages/design_system` — só entram como `published`
  os slugs que já têm build real: `kids_default`, `block_world`,
  `space_adventure`, `castles_quest`; os outros cinco do catálogo
  pretendido do docs/06 seção 3 ficam `draft`, invisíveis ao cliente via
  RLS, até ganharem arte própria — publicar depois não muda navegação);
  `child_profiles.theme_slug` ganhou FK para `themes.slug` (a coluna já
  existia sem FK desde o Marco 1, "chega no Marco 5" — migration nova, a
  original não foi editada); `theme_requests` (formulário de docs/06
  seção 10, nunca coleta foto). Funções `apply_child_theme` (valida
  família, papel, tema publicado e entitlement do plano — `THEME_NOT_ENTITLED`
  quando a família não é Premium) e `submit_theme_request` (consentimento
  obrigatório), ambas expostas a `authenticated`.
- **Simplificação registrada**: sem `theme_assets` (docs/09 seção 6) —
  o catálogo guarda só uma referência (`manifest_json.background_asset_key`)
  resolvida contra os assets já processados em `packages/design_system`;
  não existe pipeline de densidade/CDN para justificar uma tabela própria
  ainda. Desbloqueios de cosméticos (`cosmetic_items`/`child_unlocks`,
  adiados do Marco 4) **continuam não implementados** — o catálogo de
  temas agora é real, mas nenhum cosmético além do tema em si (avatar,
  moldura, medalha) tem conteúdo definido; fica como item de backlog sem
  marco designado, não algo esquecido.
- pgTAP: `supabase/tests/database/50_marco5_themes_test.sql`
  (17 asserções) cobrindo catálogo só mostra temas publicados, aplicar
  tema gratuito, bloqueio de tema Premium em plano gratuito
  (`THEME_NOT_ENTITLED`), tema não publicado/inexistente rejeitado, tema
  Premium liberado após upgrade de plano, isolamento entre famílias
  (inclusive `FORBIDDEN` ao tentar mudar tema de criança de outra
  família), solicitação de tema exige consentimento, e privilégio mínimo.
- **Marco 6** — migrations (`supabase/migrations/202607311000{28..31}_*.sql`):
  `device_tokens`, `notification_preferences` (guardião administra, inclusive
  para as crianças — mesmo espírito de docs/06 "visível, mas não alterável
  pela criança" — enforcement de preferência fica para quando existir um
  worker de envio de verdade, este marco só guarda a preferência),
  `notifications` (central interna, é o que a tela consome), `outbox_events`
  (fila para um futuro worker de push, sem nenhuma policy de RLS — só
  `service_role`, mesmo padrão de `family_invites` do Marco 1). Funções
  `register_device_token`/`deactivate_device_token`/`mark_notification_read`
  (expostas a `authenticated`) e `emit_notification` (interna, grava a
  notificação e o evento de outbox atomicamente com a mesma
  `idempotency_key`, sem grant a nenhum papel de cliente).
  `complete_task_occurrence`, `review_task_occurrence` (Marco 2/4),
  `request_redemption`, `review_redemption` (Marco 3), `process_level_changes`,
  `grant_birthday_bonus` (Marco 4) foram **redefinidas** (novo
  `create or replace function` — as migrations originais não foram
  editadas) para chamar `emit_notification` nos pontos mais centrais do
  dia a dia: tarefa enviada (notifica os dois responsáveis)/aprovada/
  rejeitada, resgate solicitado (notifica os dois responsáveis)/aprovado,
  subida de nível, bônus de aniversário — reaproveitando as mesmas chaves
  de idempotência de docs/11 seção 8 (`level_up:<child_id>:<level>`,
  `birthday:<child_id>:<year>`) quando já existiam.
- **Bloqueio novo, o mais importante deste marco**: push de verdade
  (FCM/APNs) não pode ser enviado nem testado — não existe projeto
  Firebase real (mesma raiz do bloqueio 5 já existente: nenhum projeto
  externo foi provisionado ainda). Por isso este marco **não** adiciona
  `firebase_messaging` nem nenhum SDK nativo ao `pubspec.yaml` — só o
  necessário para funcionar sem ele: a central interna (tabela
  `notifications`, que já funciona sozinha) e a fila `outbox_events` (que
  um worker futuro consumiria quando o projeto Firebase existir).
- **Escopo não coberto nesta passada** (registrado, não esquecido): eventos
  de "tarefa próxima"/"tarefa atrasada" (dependem de um job de varredura
  periódica que ainda não existe — `expire_due_task_occurrences` já roda a
  cada 5 minutos, mas não emite notificação, só muda o estado);
  `mark_redemption_delivered`/`cancel_approved_redemption` (Marco 3),
  `skip_task_occurrence` (Marco 2) não emitem notificação ainda; eventos do
  Marco 1 (convite aceito, novo aparelho infantil — este último vive na
  Edge Function `authorize-child-device`, TypeScript, não SQL) não foram
  tocados; tela de preferências (`notification_preferences`) não tem UI
  ainda, só schema+RLS.
- pgTAP: `supabase/tests/database/60_marco6_notifications_test.sql`
  (26 asserções) cobrindo notificar os dois responsáveis ao enviar
  tarefa/solicitar resgate, notificar a criança ao aprovar/rejeitar tarefa
  e ao aprovar resgate, reprocessar aprovação não duplica notificação,
  subida de nível notifica, registro de token é idempotente (mesmo token
  não duplica linha), marcar como lida (e bloqueio de papel errado),
  isolamento RLS entre famílias e privilégio mínimo.

### Backend de assinaturas (Marco 7, fatia 1)

Só o backend — `apps/admin_web` continua sendo o scaffold do Marco 0
(`FoundationPage`), sem login/MFA/módulos ainda; isso fica para a próxima
fatia (ver "Próxima ação").

- `subscription_products`: mapeamento versionado `store + product_id →
  plan_code + billing_period`, seed com `kids_task_premium_monthly`/`_yearly`
  para `apple`/`google` (docs/13 seção 2 — IDs finais de loja continuam
  pendentes, bloqueio 4 abaixo).
- `subscriptions` (uma linha por família, criada automaticamente junto com
  `create_family` via gatilho) e `subscription_events` (ledger append-only,
  `family_id` nullable para persistir webhook órfão) com RLS restrita ao
  responsável da família.
- Funções: `submit_purchase_receipt` (client-facing) → `verify_purchase`
  (interna) → `apply_subscription_transition` → `apply_safe_downgrade` /
  `restore_paused_entitlements`; `handle_apple_notification` /
  `handle_google_notification` (webhook, via `handle_store_notification`
  compartilhada) com idempotência por `store_event_id` e detecção de evento
  fora de ordem; `restore_entitlements`.
- **Bloqueio conhecido, documentado inline em `verify_purchase`**: sem conta
  de desenvolvedor Apple/Google (docs/18 seção 5), não há validação
  criptográfica real do recibo contra a loja — a máquina de estados
  (idempotência, mapeamento de produto, vínculo à família) é real; só a
  chamada de rede à loja está isolada num bloco comentado para ser trocada
  depois, mesmo padrão do `send-guardian-invite` do Marco 1. Da mesma forma,
  nenhuma Edge Function de webhook foi criada nesta fatia — `handle_apple_
  notification`/`handle_google_notification` pressupõem uma Edge Function
  futura validando a assinatura do webhook antes de chamá-las.
- Downgrade seguro (docs/02 seção 5): `apply_safe_downgrade` escolhe/mantém
  `families.primary_child_id`, pausa (`status='plan_paused'`) crianças e
  ocorrências futuras excedentes sem apagar nada, reverte tema Premium para
  `kids_default` (simplificação assumida — sem histórico de "último tema
  gratuito" persistido). `restore_paused_entitlements` reverte tudo ao
  reativar o Premium.
- `v_effective_entitlements`: view que o app deve consultar para o plano
  efetivo da família (docs/13 seção 5), considerando o status da assinatura
  além do `plan_id` em cache.
- pgTAP: `supabase/tests/database/70_marco7_subscriptions_test.sql`
  (39 asserções) cobrindo validação/controle de acesso, compra válida,
  restauração sem duplicar, idempotência e ordenação de webhook, isolamento
  RLS entre famílias, privilégio mínimo e o downgrade seguro completo
  (5 crianças → 1 ativa + 4 pausadas, 10 ocorrências futuras → 3 ativas +
  7 pausadas, ocorrências de hoje intocadas, nada apagado, reativação
  restaura tudo).
- Sem mudança em `packages/domain`/`packages/data_access` nesta fatia: os
  códigos de erro usados já existiam; sem UI consumindo ainda, nenhum
  `SubscriptionRepository` foi criado.

### Backend do painel administrativo (Marco 7, fatia 2)

- Migrations (`supabase/migrations/202607311000{36..38}_*.sql`):
  `platform_admins` (`profile_id` → `profiles.id`, `role` em
  `super_admin`/`support`/`content`/`billing`, `mfa_required`, `active`) e
  `audit_logs` (append-only: ator, papel, ação, recurso, resultado,
  metadata) — docs/09 seção 8, docs/12 seções 2 e 10.
- RLS: `platform_admins` só permite `select` da própria linha (é o que o
  app usa para resolver "eu sou admin? qual papel?"); sem policy de
  insert/update/delete — provisionar/alterar um administrador é operação
  manual (`service_role`) nesta fatia, não um módulo de gestão de papéis
  (isso fica para uma fatia futura, junto do resto do painel). `audit_logs`
  permite `select` das próprias ações para qualquer admin ativo e visão
  completa para `super_admin`; sem nenhuma policy de escrita — só via
  `record_admin_audit_log`.
- Função `record_admin_audit_log` (security definer, `authenticated`):
  grava uma linha de auditoria só se o chamador for um `platform_admins`
  ativo **e** a sessão já estiver em `aal2` (segundo fator verificado) —
  reforço de "MFA obrigatório" no banco, além do gate síncrono do
  `AdminSessionResolver` no app. Nesta fatia o único chamador real é a
  confirmação de MFA (enrolamento ou desafio) no login; os módulos futuros
  do painel devem reaproveitar a mesma função.
- pgTAP: `supabase/tests/database/80_marco7_platform_admin_test.sql`
  (13 asserções) cobrindo: admin ativo com `aal2` grava auditoria;
  bloqueios (não-admin, sessão sem `aal2`, admin inativo); RLS de
  `audit_logs` (super_admin vê tudo, outro papel só as próprias ações);
  RLS de `platform_admins` (só a própria linha); privilégio mínimo.

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
| 4 — XP e progressão | **Concluído** | Ver seções acima; testes abaixo. Desbloqueios de cosméticos **não implementados** — adiados para o Marco 5 |
| 5 — Temas e idade | **Concluído** | Ver seções acima; testes abaixo. Desbloqueios de cosméticos (avatar/moldura/medalha por nível+plano) **continuam não implementados** — sem marco designado ainda. Adaptação visual por faixa etária (docs/06 seção 7 — linguagem/densidade de UI por 2-7/8-10/11-13+) também não foi construída: hoje só a paleta de cores muda por tema |
| 6 — Notificações | **Parcial** | Central interna completa e testada; push real (FCM/APNs) bloqueado por falta de projeto Firebase (bloqueio 5). Matriz de eventos parcialmente coberta — ver seção acima |
| 7 — Premium e painel | **Parcial** | Backend de assinaturas completo e fundação do painel Web (login separado + MFA obrigatório + auditoria) prontos — ver seções acima. `apps/admin_web` ainda não tem nenhum módulo (famílias, conteúdo, assinaturas, notificações, suporte) |
| 8 — Privacidade e release | Não iniciado | — |

## Testes (executados localmente em 05/08/2026)

| Comando | Escopo | Resultado |
|---|---|---|
| `dart format --set-exit-if-changed .` | domain, data_access, design_system, apps/mobile, apps/admin_web | ✅ Sem alterações pendentes |
| `flutter analyze` | idem | ✅ "No issues found" em todos os 5 |
| `flutter test` | domain (29), data_access (9), design_system (10), apps/mobile (6), apps/admin_web (1) | ✅ 55/55 passando |
| `supabase db lint` / `supabase test db` | supabase/ | ⛔ Exigem Docker (ainda ausente aqui, reverificado nesta fatia); as 3 migrations novas e o pgTAP de administradores da plataforma (13 asserções, total 207 nos Marcos 2-7) foram revisados manualmente linha a linha, execução real pendente do CI |
| `flutter build apk --debug` / `flutter build web` / `flutter build ios --no-codesign` | apps/mobile, apps/admin_web | Não reexecutados neste ciclo (sem mudança de dependências nativas); ver Marco 0/1 para o último build real |

## Bloqueios

1. **Docker ausente localmente** — impede `supabase start`/`db lint`/
   `test db`/`functions serve` nesta máquina (reverificado nesta fatia:
   continua ausente). As migrations, políticas RLS e funções SQL dos
   Marcos 2-7 foram revisadas manualmente com atenção a nomes de coluna,
   tipos e assinaturas, mas **não foram executadas** contra um Postgres
   real. Isso inclui o pgTAP de assinaturas
   (`70_marco7_subscriptions_test.sql`) e o de administradores da
   plataforma (`80_marco7_platform_admin_test.sql`), que só serão
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
   No Marco 6 isso significa especificamente: sem projeto Firebase, não há
   como registrar `firebase_messaging` no app nem enviar push de verdade
   (FCM/APNs) — a central interna de notificações funciona independente
   disso, mas a fila `outbox_events` fica sem nenhum worker consumindo.
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

**Marco 7 (fatia 3) — Primeiro módulo real do painel**: login separado,
MFA obrigatório e auditoria (fatia 2, ver seção acima) estão prontos, assim
como o backend de assinaturas (fatia 1). `/admin/home` ainda é um
placeholder sem nenhum módulo. Sugestão de ordem, seguindo docs/12: (1)
"Famílias e usuários" (seção 4) — busca por família/e-mail, status, plano,
responsáveis, quantidade de crianças, sem expor dado infantil por padrão
(seção 3: "não mostrar nomes de crianças no dashboard") — é o módulo que
mais depende do `super_admin` já poder promover outros administradores, o
que ainda não existe (gestão de papéis, seção 2, também pendente); (2)
"Assinaturas" (seção 5), que já tem backend completo (fatia 1) só faltando
UI — plano efetivo, loja, estado, override de suporte com expiração.
Cada módulo novo que gravar algo deve chamar `record_admin_audit_log`
(fatia 2) em vez de inventar outro mecanismo de auditoria.

Um administrador ainda precisa ser provisionado manualmente para testar
qualquer módulo (`service_role`: criar o usuário no Supabase Auth e inserir
a linha em `platform_admins`) — não existe autocadastro nem, ainda, uma
tela de gestão de papéis para o `super_admin` promover outros.

Pendências técnicas ainda não decididas que bloqueiam parte deste marco
(docs/18): contas de desenvolvedor Apple/Google Play, IDs de produto de
assinatura em produção, domínio/hospedagem do painel Web — nenhuma delas
impede os módulos do painel ou o backend de assinaturas já construído, mas
testar a compra de verdade e publicar o painel dependem delas.

Antes de continuar, recomenda-se validar os Marcos 1-7 num ambiente com
Docker (`supabase start`, `supabase db lint --local`, `supabase test db`) e,
se possível, um projeto Supabase real de desenvolvimento — nenhuma migration
ou função SQL destes marcos foi executada contra um Postgres de verdade
ainda, só revisada manualmente. Confirmar também se `pg_cron` está
disponível nesse projeto (bloqueio 2 acima).
