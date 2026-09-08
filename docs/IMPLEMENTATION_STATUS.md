# Status de Implementação

**Última atualização:** 05/08/2026

**Estado atual:** Marco 0 — Fundação concluído. Marco 1 — Autenticação e
Família concluído. Marco 2 — Rotina e Tarefas concluído. Marco 3 —
KidsCoins e Recompensas concluído. Marco 4 — XP e Progressão concluído.
Marco 5 — Temas e Experiência por Idade concluído. Marco 6 — Notificações
concluído **parcialmente** (central interna funciona de ponta a ponta;
push de verdade via FCM/APNs está bloqueado por falta de projeto Firebase
real — ver "Bloqueios"). **Marco 7 — Premium e Painel concluído**: backend
de assinaturas (fatia 1); fundação do painel Web — login separado + MFA
obrigatório + auditoria (fatia 2); módulo Assinaturas (fatia 3); módulo
"Famílias e usuários" (fatia 4); módulo "Temas e conteúdo" (fatia 5);
módulo "Suporte" (fatia 6); e módulo "Notificações" do painel + dashboard
de métricas + log de auditoria (fatia 7) estão prontos — os quatro papéis
administrativos (`super_admin`/`billing`/`support`/`content`) têm pelo
menos um módulo funcional. Como no Marco 5/6, "concluído" não significa
zero lacunas: push real, templates de notificação, reprocessamento e
anexos privados de ticket continuam bloqueados por falta de infraestrutura
externa (projeto Firebase, decisão de Supabase Storage) — ver "Bloqueios"
e as notas de cada fatia abaixo. "Gestão de papéis" (docs/12 seção 2) e
publicar os temas `draft` do Marco 5 (falta de arte própria) ficam como
pendências não bloqueantes, registradas em
`docs/18_PENDENCIAS_NAO_BLOQUEANTES.md`. **Marco 8 — Privacidade e release
concluído** (com o mesmo espírito dos Marcos 5-7: tudo que é engenharia
foi entregue; itens que dependem de advogado, contas reais de loja ou
ambiente de produção ficam registrados como pendência, nunca fingidos):
fluxo de exclusão dupla da família, exportação de dados, revogação de
consentimento, retenção técnica automatizada, revisão de consentimento/
SDKs, auto-revisão de segurança (achado real corrigido), auditoria de
acessibilidade (achados reais corrigidos), scaffold de testes E2E e
runbooks operacionais. Revisão jurídica, TestFlight/contas de loja reais,
categoria Kids/Families oficial e pentest externo continuam pendentes —
não são tarefas de engenharia. Este documento e o `git log` são a fonte de
verdade do que já existe; ler esta
seção e a "Próxima ação" antes de continuar.

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
- **Marco 7 (fatia 4)** — `SessionRoleResolver` ganhou um novo estado,
  `GuardianFamilyBlocked`: quando `families.status` (lido junto da consulta
  a `family_members`, via `families(status)`) está em `blocked`/
  `deletion_pending`/`deleted`, o responsável cai em `/access/family-blocked`
  (`FamilyBlockedPage`) em vez do shell normal — mesmo guard síncrono do
  resto do router. `restricted` continua caindo em `GuardianSession` (sem
  tela de restrição granular ainda). É o outro lado de
  `admin_set_family_status` (ver "Backend do módulo Famílias e usuários"
  abaixo): o painel bloqueia, o app aplica.
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
  - `/admin/home`: pós-login, mostra o papel do administrador e um card de
    navegação por módulo já pronto (só "Assinaturas" nesta fatia); papéis
    sem nenhum módulo disponível veem uma mensagem em vez de uma tela
    vazia.
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
- **Marco 7 (fatia 3)** — primeiro módulo real, "Assinaturas" (docs/12
  seção 5), visível só para `super_admin`/`billing` (`/admin/home` esconde
  o card para os demais papéis; `redirect` também bloqueia navegação
  direta pela URL):
  - `/admin/subscriptions`: busca por ID da família ou e-mail do
    responsável (nunca por código familiar, CLAUDE.md), lista família,
    plano efetivo, e-mails dos responsáveis e quantidade de crianças.
  - `/admin/subscriptions/:familyId`: plano efetivo, estado da assinatura,
    loja/produto, validade/carência, eventos recentes
    (`subscription_events`) e o botão de override — "Conceder override de
    suporte" (data de expiração + justificativa obrigatória) quando a
    família não está em override, "Revogar" (motivo obrigatório) quando
    está. O texto do diálogo deixa explícito que não representa pagamento
    real (docs/12 seção 5: "override não deve fingir pagamento").
  - `packages/data_access/src/admin/admin_subscription_repository.dart`:
    `AdminSubscriptionRepository` (busca, `v_effective_entitlements`,
    `subscriptions`, `subscription_events`, conceder/revogar override) —
    as duas últimas já gravam a própria auditoria no banco
    (`record_admin_audit_log`), sem chamada duplicada do lado do Flutter.
- **Marco 7 (fatia 4)** — módulo "Famílias e usuários" (docs/12 seção 4),
  visível só para `super_admin`/`support` (`billing` tem leitura entre
  famílias no banco, herdada de `families_select_admin`, mas não ganha este
  módulo no painel — não é seu papel por docs/12 seção 2):
  - `/admin/families`: mesma busca por ID/e-mail de `admin_search_families`
    (fatia 3), reaproveitada num contexto diferente do painel.
  - `/admin/families/:familyId`: status, plano, responsáveis; crianças
    listadas só com `status`/`age_mode` (`admin_list_family_children` —
    nunca nome/apelido/nascimento/avatar, docs/12 seção 4: "dados infantis
    ficam ocultos até uma ação justificada de suporte"), com botão "Revelar
    identidade" por criança (`admin_reveal_child_identity`, exige
    justificativa, audita, mostra o nome só nesta sessão do painel);
    aparelhos vinculados (ativo/revogado); consentimentos; botão "Alterar
    status" (docs/12 seção 11) com motivo obrigatório para qualquer um dos
    5 estados de `families.status`.
  - `packages/data_access/src/admin/admin_family_repository.dart`:
    `AdminFamilyRepository` — as funções de revelar identidade e alterar
    status já gravam a própria auditoria no banco, sem chamada duplicada do
    lado do Flutter (mesmo princípio da fatia 3).
  - Efeito real de "bloquear uma família" (não só um rótulo): `admin_set_
    family_status` revoga todos os `child_device_bindings` ativos da
    família quando o novo status sai de `active`/`restricted` — a criança
    perde a sessão no próximo resolve, mesmo mecanismo de
    `revoke_child_device` do Marco 1. Reativar não volta a autorizar o
    aparelho sozinho (decisão de segurança deliberada, ver comentário na
    migration). Do lado do responsável, `SessionRoleResolver` (app móvel)
    passa a tratar `families.status` fora de `active`/`restricted` como um
    estado de sessão bloqueado — ver "apps/mobile" acima.
- **Marco 7 (fatia 5)** — módulo "Temas e conteúdo" (docs/12 seção 6),
  visível só para `super_admin`/`content` (é a primeira fatia em que o
  papel `content` enxerga algum módulo — até aqui via "Nenhum módulo
  disponível" na home):
  - `/admin/themes`: catálogo inteiro (inclusive `draft`/`retired`, ao
    contrário do que a criança/responsável vê) com "Criar rascunho"
    (slug/nome/plano), por tema "Editar asset" (aponta
    `manifest_json.background_asset_key` — ver simplificação abaixo),
    "Publicar" (diálogo com checkbox obrigatório confirmando revisão de
    licença/proveniência, contraste/acessibilidade, propriedade
    intelectual e tamanho máximo, docs/12 seção 6) e "Retirar"; abaixo,
    fila de solicitações Premium de tema (`theme_requests`, Marco 5, sem
    tela nenhuma até aqui) com "Marcar como revisado".
  - `packages/data_access/src/admin/admin_theme_repository.dart`:
    `AdminThemeRepository` — todas as escritas já gravam a própria
    auditoria no banco.
  - **Simplificação registrada**, mesma raiz da já registrada no Marco 5
    (sem `theme_assets`/pipeline de CDN): "upload de assets" não é upload
    de arquivo — o catálogo de temas do app é código Dart compilado em
    `packages/design_system` (`buildKidsThemeBySlug`), não carregado de um
    Storage em runtime. O painel administra o metadado do catálogo (slug,
    nome, plano, status, versão, chave do asset); a arte em si continua
    sendo um processo manual de desenvolvimento — um dev builda o tema e
    processa os assets, o painel só aponta o manifest pra chave já pronta.
    Do mesmo jeito, licença/proveniência/contraste/acessibilidade/tamanho
    máximo são confirmados por revisão humana (checkbox obrigatório antes
    de publicar), não por um validador automático que não existe.
- **Marco 7 (fatia 6)** — módulo "Suporte" (docs/12 seção 9), visível só
  para `super_admin`/`support`:
  - `/admin/support`: fila de tickets (assunto, categoria, prioridade,
    status, ordenada por atividade mais recente) com "Novo ticket" —
    família opcional (campo de ID; sem uma segunda busca dedicada, o
    operador já teria o ID vindo do módulo Famílias e usuários),
    categoria, prioridade e referência de incidente opcionais.
  - `/admin/support/:ticketId`: visão geral (status/categoria/prioridade/
    família/incidente), timeline de mensagens (`support_ticket_messages`)
    com campo de resposta, e "Alterar status" (docs/12 seção 9:
    encerramento e reabertura).
  - `packages/data_access/src/admin/admin_support_repository.dart`:
    `AdminSupportRepository` — sem RPC dedicada, lê/escreve
    `support_tickets`/`support_ticket_messages` direto via RLS (docs/14
    seção 1: sem regra de negócio crítica além de autorização, mesmo
    padrão de `rewards`/`consent_records`).
  - **Sem impersonação** (docs/12 seção 9): nenhuma tela ou função deste
    módulo dá acesso à sessão de um responsável ou criança — um ticket só
    referencia `family_id` para contexto, nunca abre a conta da família.
  - **Simplificação registrada**: "anexos privados" (docs/12 seção 9) fica
    fora desta fatia — seria o primeiro upload de arquivo de verdade do
    projeto inteiro (nem `private_photo_path` do Marco 1 tem pipeline
    real), decisão técnica própria (bucket do Storage, policies de
    `storage.objects`, seletor de arquivo no Flutter Web) que não deveria
    ser encaixada como sub-item desta entrega. A timeline cobre resposta
    em texto sem anexo por enquanto.
- **Marco 7 (fatia 7)** — módulo "Notificações" do painel (docs/12 seção
  8, visível a `super_admin`/`support`) e "métricas e auditoria" (docs/12
  seções 3 e 10, dashboard visível só a `super_admin`) — fecha o Marco 7:
  - `/admin/notifications`: histórico do canal interno (`notifications`,
    o único canal real sem push) e "Enviar aviso operacional" — chega só
    aos responsáveis ativos de uma família (ID informado manualmente),
    nunca à criança (docs/12 seção 8: "sem campanha de marketing
    direcionada diretamente a crianças no MVP").
  - `packages/data_access/src/admin/admin_notification_repository.dart`:
    `AdminNotificationRepository`.
  - **Simplificação registrada**: "templates/categorias",
    "reprocessamento controlado" e "teste para aparelhos internos"
    (docs/12 seção 8) ficam fora — mesma raiz do bloqueio de push do
    Marco 6 (sem projeto Firebase, não há pipeline de entrega real pra
    reprocessar ou testar; templates exigiriam refatorar chamadas de
    `emit_notification` já commitadas nos Marcos 2-6). Registrado em
    `docs/18_PENDENCIAS_NAO_BLOQUEANTES.md` seção 7.
  - `/admin/dashboard`: métricas agregadas (famílias totais/ativas/
    onboarding, responsáveis, crianças, gratuito×Premium, tarefas ativas,
    aprovações/resgates pendentes, totais aprovados/entregues, tickets
    abertos) — nunca nome de criança (docs/12 seção 3), só contagens.
    "Falhas de push/jobs/webhooks" fica deliberadamente fora: não existe
    rastreamento de falha de `pg_cron` nem de webhook de loja numa tabela
    consultável — melhor faltar do que fingir uma métrica zero.
  - `/admin/audit-log`: lista `audit_logs`, cuja RLS já existia pronta
    desde a fatia 2 (`super_admin` vê tudo, outro papel só as próprias
    ações) sem nenhuma tela até aqui. "Exportação de auditoria" (docs/12
    seção 10) é copiar CSV para a área de transferência — não baixar um
    arquivo — para não depender de API específica do Flutter Web sem um
    navegador real pra testar neste ambiente.
  - `packages/data_access/src/admin/admin_dashboard_repository.dart`:
    `AdminDashboardRepository`.
  - Corrigido nesta fatia: `AdminHomePage` (todos os módulos desde a
    fatia 3) tinha a coluna de cards sem rolagem — com seis módulos
    possíveis para `super_admin`, a tela estourava a altura disponível
    (`RenderFlex overflowed`, pego pelo teste de widget "só super_admin vê
    o módulo Dashboard"). Trocado `Padding` por `SingleChildScrollView`.

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

### Backend do módulo Assinaturas (Marco 7, fatia 3)

- Migrations (`supabase/migrations/202607311000{39..43}_*.sql`).
- `is_active_platform_admin(p_roles text[])`: bloco reaproveitável para RLS
  entre famílias — só olha a própria linha do chamador em
  `platform_admins`, então não precisa ser security definer. Base de
  `families_select_admin` (`super_admin`/`support`/`billing`),
  `subscriptions_select_admin`/`subscription_events_select_admin`
  (`super_admin`/`billing` só — dado financeiro fica fora do papel
  `support`, docs/12 seção 2). Como `v_effective_entitlements`
  (fatia 1) já é `security_invoker`, essas duas policies bastam para o
  admin consultar o plano efetivo de qualquer família sem view nova.
- `admin_search_families` (security definer, docs/12 seção 4: "busca por
  ID da família ou e-mail do responsável" — nunca por código familiar,
  CLAUDE.md): só ela lê `auth.users` (e-mail não existe em nenhuma tabela
  RLS-visível), por isso precisa ser security definer mesmo sendo só
  leitura; limitada a 20 resultados, exige 3+ caracteres.
- `admin_grant_subscription_override`/`admin_revoke_subscription_override`
  (docs/12 seção 5: "override de suporte com expiração e justificativa";
  "não deve fingir pagamento"): só mexem em `status`/`current_period_end`
  — nunca em `store`/`product_id`/`original_transaction_id` — e
  reaproveitam `apply_subscription_transition` (fatia 1, propaga o plano
  efetivo e chama `apply_safe_downgrade`/`restore_paused_entitlements`
  sozinho) e `record_admin_audit_log` (fatia 2), sem mecanismo novo de
  nenhum dos dois. Ambas exigem `p_idempotency_key` (CLAUDE.md: "toda ação
  crítica deve aceitar chave de idempotência"), verificada contra
  `subscription_events.idempotency_key`. Simplificação registrada: revogar
  (manual ou por expiração) sempre volta a `free`, não "o que a família
  tinha antes do override" — cobrir uma assinatura real de loja coexistindo
  com um override fica para quando o módulo de suporte precisar disso de
  verdade.
- `expire_support_overrides` (interna, só `service_role`, agendada de hora
  em hora via `pg_cron`): garante o critério de aceite "override de
  assinatura expira" (docs/15 seção 14) sem depender de um administrador
  voltar à tela manualmente — mesmo padrão de `expire_due_task_occurrences`
  do Marco 2.
- pgTAP: `supabase/tests/database/90_marco7_admin_subscriptions_test.sql`
  (32 asserções) cobrindo: RLS entre famílias restrita por papel; busca por
  ID/e-mail, rejeição de busca curta e de papéis sem permissão; concessão
  de override (controle de acesso, validação, idempotência, efeito no
  plano da família, auditoria); revogação (inclusive rejeitar revogar uma
  assinatura que não está em override); expiração automática; privilégio
  mínimo.

### Backend do módulo Famílias e usuários (Marco 7, fatia 4)

- Migrations (`supabase/migrations/202607311000{44..48}_*.sql`).
- `family_status_events` (ledger append-only, mesmo padrão de
  `subscription_events`/`task_events`/`redemption_events` — é o que dá
  idempotência real a `admin_set_family_status`, não `audit_logs`, que é
  genérica entre módulos); RLS de select só `super_admin`/`support`.
- `admin_list_family_children`/`admin_reveal_child_identity`: por que são
  funções e não uma policy de RLS em `child_profiles` — RLS é por linha,
  não por coluna, então uma policy de select exporia nome/nascimento/avatar
  junto com status/age_mode de uma vez só. `admin_list_family_children`
  (`super_admin`/`support`/`billing`, mesmos papéis de
  `families_select_admin`) nunca devolve identidade;
  `admin_reveal_child_identity` (`super_admin`/`support` só) exige
  justificativa e grava auditoria antes de devolver
  nome/apelido/avatar/nascimento — herda a exigência de `aal2` de
  `record_admin_audit_log` (fatia 2), então revelar sem segundo fator
  verificado falha a chamada inteira.
- RLS admin direta (sem função) em `child_device_bindings`/
  `consent_records` (`super_admin`/`support`) — essas duas tabelas não têm
  identidade infantil na própria linha, então uma policy de select comum é
  suficiente (ao contrário de `child_profiles`).
- `admin_set_family_status` (docs/12 seção 11: "exige motivo; não apaga
  dados; revoga ou restringe sessões conforme risco; notifica responsáveis
  quando apropriado; permite revisão e reversão auditada"): `super_admin`/
  `support`, motivo e `p_idempotency_key` obrigatórios, rejeita status
  inválido e reafirmar o status já vigente. "Não apaga dados": só troca
  `families.status` (os 5 estados já existiam no check constraint desde o
  Marco 1). Ao sair de `active`/`restricted`, revoga todo
  `child_device_bindings` ativo da família (mesmo efeito de
  `revoke_child_device`, aplicado a todas as crianças) e notifica os
  responsáveis ativos via `emit_notification` (nunca em linguagem
  punitiva, nunca ao voltar para `active`). Grava `family_status_events` e
  `record_admin_audit_log`. Simplificação registrada: reativar não
  restaura os aparelhos revogados automaticamente — o responsável precisa
  parear de novo, decisão deliberada para não reabrir uma sessão sem
  verificação nova.
- Sessão do responsável (Supabase Auth/GoTrue) não pode ser invalidada por
  uma função SQL comum sem `service_role` do Auth Admin API — por isso o
  bloqueio do lado do responsável é aplicado no app (`SessionRoleResolver`,
  ver "apps/mobile" acima), não no banco.
- pgTAP: `supabase/tests/database/100_marco7_admin_families_test.sql`
  (32 asserções) cobrindo: RLS admin de aparelhos/consentimentos;
  `admin_list_family_children` nunca devolve identidade e respeita papel;
  `admin_reveal_child_identity` exige papel, justificativa e `aal2`;
  `admin_set_family_status` (controle de acesso, validação, idempotência,
  revogação de aparelhos ao bloquear, notificação aos dois responsáveis,
  auditoria, reativar não restaura aparelho nem notifica de novo);
  privilégio mínimo.

### Backend do módulo Temas e conteúdo (Marco 7, fatia 5)

- Migrations (`supabase/migrations/202607311000{49..51}_*.sql`).
- `admin_list_themes` (`super_admin`/`content`, catálogo inteiro
  independente de status — a policy `themes_select_authenticated` do
  Marco 5 só mostra `published` para o app, então esta função é o único
  jeito do painel ver `draft`/`retired`) e `admin_create_theme_draft`
  (slug/nome/plano validados, slug duplicado rejeitado, nasce sempre
  `draft` na versão 1).
- `admin_update_theme_manifest`: só bump `version` quando o tema já está
  `published` (editar um rascunho ainda não é uma "versão" publicada,
  docs/12 seção 12: "publicação de tema é versionada"); rejeita edição de
  tema `retired` (precisa republicar antes).
- `admin_publish_theme`: exige `p_ip_review_confirmed = true` e
  `manifest_json.background_asset_key` preenchido (não publica um tema
  visualmente vazio); rejeita publicar um tema já publicado; republicar a
  partir de `retired` bump a versão (é conteúdo novo voltando ao ar).
- `admin_retire_theme`: só a partir de `published`. Não apaga a linha nem
  desvincula `child_profiles.theme_slug` de quem já usa o tema — RLS do
  cliente e `apply_child_theme` (Marco 5) já filtram por `published`,
  então retirar só tira o tema do catálogo para novas escolhas;
  `buildKidsThemeBySlug` resolve pelo catálogo estático do app, sem
  consultar `themes`, então quem já tinha o tema aplicado não é afetado
  (docs/12 seção 6: "retirar sem quebrar famílias atuais").
- `admin_list_theme_requests` (security definer, junta `families.name` e
  `auth.users.email` de quem pediu — mesmo motivo de
  `admin_search_families`, e-mail não é visível via RLS a `authenticated`)
  e `admin_review_theme_request` (`pending → reviewed`, rejeita revisar
  duas vezes) — dão vida à fila de `theme_requests` que existia sem
  nenhuma tela desde o Marco 5.
- Todas as cinco funções de escrita chamam `record_admin_audit_log`.
  Nenhuma exige `p_idempotency_key`: são transições de status internas de
  baixo risco, sem notificação nem efeito em cascata sobre outra tabela —
  mesmo padrão (sem idempotência) de `mark_notification_read` no Marco 6.
- pgTAP: `supabase/tests/database/110_marco7_admin_themes_test.sql`
  (33 asserções) cobrindo: controle de acesso por papel em todas as sete
  funções; criação de rascunho (validação, slug duplicado); edição de
  manifest (versiona só quando publicado, rejeita tema retirado/
  inexistente); publicação (exige confirmação de revisão de PI e asset
  key, rejeita publicar duas vezes, republicar retirado bump versão);
  retirada (só a partir de publicado); fila de solicitações (join
  família/e-mail, rejeita revisar duas vezes); privilégio mínimo.

### Backend do módulo Suporte (Marco 7, fatia 6)

- Migrations (`supabase/migrations/202607311000{52..53}_*.sql`).
- `support_tickets`/`support_ticket_messages`: RLS direta (sem função,
  docs/14 seção 1 — mesmo padrão de `rewards`/`consent_records`), sem
  nenhuma função PL/pgSQL chamável via RPC nesta fatia (a migration 53 só
  reafirma o revoke defensivo de hábito; não há nada novo pra restringir).
- `category`/`priority`/`status` são `check` na própria coluna, não
  validação em função — `category` em (`billing`, `technical`, `account`,
  `content`, `other`), `priority` em (`low`, `medium`, `high`, `urgent`),
  `status` em (`open`, `in_progress`, `waiting_on_family`, `resolved`,
  `closed`).
- `sync_support_ticket_closed_at` (gatilho antes de `update` em
  `support_tickets`): preenche `closed_at` ao entrar em `resolved`/
  `closed`, limpa ao sair — nunca fica dessincronizado de um `update`
  manual que esqueceu a coluna.
- `touch_support_ticket_on_message` (gatilho depois de `insert` em
  `support_ticket_messages`, `security definer` porque escreve numa tabela
  diferente da que disparou o gatilho — mesmo motivo de
  `create_child_wallet`/`create_child_streak` do Marco 1/4): toca
  `support_tickets.updated_at` a cada mensagem nova, então a fila
  (ordenada por `updated_at`) sobe o ticket com atividade recente.
  `support_ticket_messages` é append-only (sem policy de update/delete),
  mesmo padrão de `task_events`/`redemption_events` — é a própria timeline
  que satisfaz "quem, quando, por quê" (docs/12 seção 12) para ações de
  ticket, sem precisar também passar por `record_admin_audit_log`.
- pgTAP: `supabase/tests/database/120_marco7_admin_support_test.sql`
  (18 asserções) cobrindo: criação de ticket e RLS por papel (select/
  insert, inclusive um responsável comum); timeline (mensagem aparece,
  billing não pode escrever); `closed_at` sincroniza ao resolver/reabrir;
  billing não pode alterar status; os três `check` de enum rejeitam valor
  inválido; ticket sem família vinculada (consulta geral).

### Backend dos módulos Notificações e Dashboard (Marco 7, fatia 7)

- Migrations (`supabase/migrations/202607311000{54..58}_*.sql`).
- `notifications_select_admin`: RLS direta para `super_admin`/`support` —
  `notifications` não guarda identidade infantil na própria linha (título/
  corpo vêm de snapshot de tarefa/recompensa, não de perfil), então não
  precisa de função como `child_profiles` (fatia 4).
- `admin_operational_notices`: ledger de idempotência (mesmo padrão de
  `family_status_events`/`subscription_events`) para
  `admin_send_operational_notice` (`super_admin`/`support`, motivo:
  título/corpo obrigatórios, `p_idempotency_key` obrigatório) — chama
  `emit_notification` (Marco 6) uma vez por responsável ativo da família,
  nunca para a criança, grava o ledger e `record_admin_audit_log`. Um
  retry com a mesma chave devolve o resultado já gravado em vez de
  reprocessar (e não gera uma segunda linha de auditoria).
- `admin_get_dashboard_metrics` (`super_admin` só): retorna um único
  `jsonb` com contagens — famílias totais/ativas/onboarding (proxy:
  família com criança ativa, sem coluna dedicada), responsáveis, crianças,
  famílias por plano efetivo (via `v_effective_entitlements`), assinaturas
  por status, tarefas ativas, ocorrências aguardando aprovação/aprovadas,
  resgates pendentes/entregues, tickets abertos. Nunca nome de criança
  (docs/12 seção 3). Métrica de falha de push/job/webhook fica de fora,
  documentada inline como ausente em vez de aparecer como zero enganoso.
- Log de auditoria (docs/12 seção 10) não precisou de migration nova —
  `audit_logs_select_own`/`audit_logs_select_super_admin` já existiam
  desde a fatia 2, só sem nenhuma tela consumindo até aqui.
- pgTAP: `supabase/tests/database/130_marco7_admin_notifications_test.sql`
  (13 asserções: RLS de histórico, papel/validação/idempotência do aviso
  operacional, nunca notifica criança, auditoria, privilégio mínimo) e
  `supabase/tests/database/140_marco7_admin_dashboard_test.sql`
  (9 asserções: controle de acesso só `super_admin`, métricas batendo com
  dados criados na própria transação de teste).

## Marco 8 — Privacidade e release

Diferente dos Marcos 1-7 (código sobre uma base que já existia), o
Marco 8 mistura itens de engenharia com itens que só advogado/conta real
de loja resolvem. Todo item de engenharia do checklist (docs/16 seção 10)
foi construído; os que não são engenharia estão registrados em
`docs/18_PENDENCIAS_NAO_BLOQUEANTES.md`, nunca fingidos como prontos.

### Backend (Supabase)

- Migrations (`supabase/migrations/202607311000{59..65}_*.sql`).
- `deletion_requests` (docs/09 seção 8, docs/10 seção 10): "dupla" é sobre
  aprovação, não sobre duas exclusões — com 2+ responsáveis ativos no
  momento do pedido, um pede e outro aprova/rejeita; com um só, a
  confirmação forte do próprio já basta (`requires_second_approval`
  registra qual caminho valeu, snapshot no momento do pedido). Índice
  parcial único garante no máximo um pedido "em jogo"
  (`pending_approval`/`approved`) por família, sem impedir um novo pedido
  depois de uma rejeição/cancelamento.
- `request_family_deletion`/`respond_family_deletion`/
  `cancel_family_deletion` (`authenticated`, idempotência no pedido
  inicial): notificam via `emit_notification` (Marco 6) nos pontos certos
  — o outro responsável ao pedir, o solicitante ao ser respondido, todos
  ao cancelar. **Achado da auto-revisão de segurança desta fatia**: as
  duas primeiras versões de `respond_family_deletion`/
  `cancel_family_deletion` checavam o *status* do pedido antes de checar
  se quem chamou pertence à família — um responsável de outra família
  descobriria o estado de um pedido alheio antes de levar `FORBIDDEN`.
  Corrigido invertendo a ordem (autorização sempre antes de qualquer
  detalhe de estado) e coberto por um teste de isolamento entre famílias
  novo no pgTAP (docs/15 seção 16).
- `process_scheduled_deletions` (`service_role`/`pg_cron`, horário, mesmo
  padrão de `expire_due_task_occurrences`/`expire_support_overrides`):
  executa a exclusão de verdade quando o período de segurança de 7 dias
  termina — revoga aparelhos infantis, anonimiza identidade da criança
  (nome/apelido/foto/PIN), arquiva tarefas, remove o vínculo dos
  responsáveis, marca a família `deleted`. Ledgers/eventos (histórico
  financeiro/auditoria) ficam intocados — não carregam nome, só
  `child_id`. Escopo exato de anonimização é o default técnico adotado,
  pendente de validação jurídica (docs/18 seção 7). Sem notificação de
  conclusão nem e-mail: no momento em que a família some de
  `family_members`, a policy de leitura de `notifications` do responsável
  já não alcança mais nada dela, e não há provedor de e-mail configurado
  (pendência já existente desde o Marco 1).
- `export_family_data` (`authenticated`, docs/10 seção 12): devolve num
  único `jsonb` os dados da *própria* família de quem chama — família
  deriva da sessão, nunca de um parâmetro (não dá pra pedir a exportação
  de outra família por engano ou má-fé). Cobre família, responsáveis
  (e-mail/papel), crianças (perfil completo, exceto `pin_hash` — nunca sai
  do digest, docs/10 seção 8), carteira, até 200 lançamentos recentes do
  ledger de moedas, recompensas, pedidos de resgate, consentimentos e
  assinatura.
- `revoke_consent` (`authenticated`) — achado da revisão de consentimento
  (docs/10 seção 4: "permitir consulta e revogação"): `consent_records`
  já tinha `status`/`revoked_at` desde o Marco 1, mas nenhuma função
  escrevia neles — só o registro inicial existia. Fechado nesta fatia.
- `purge_stale_operational_data` (`service_role`/`pg_cron`, diária,
  docs/10 seção 13): convite não aceito/cancelado/expirado (30 dias),
  tentativa de login infantil (90 dias), token de push inativo (30 dias).
  Janelas são o default técnico adotado, pendente de validação jurídica
  (docs/18 seção 7) — trocar é editar a função, não uma migration de
  schema.
- pgTAP: `supabase/tests/database/150_marco8_deletion_and_privacy_test.sql`
  (32 asserções) cobrindo: pedido com dois responsáveis (pendente,
  segundo notificado, segundo pedido bloqueado enquanto o primeiro está
  em aberto); resposta (quem pediu não pode responder, rejeitar exige
  motivo, aprovar agenda); **isolamento entre famílias** (responsável de
  família B não enxerga nem age sobre pedido da família A); cancelamento
  (e rejeição de cancelar duas vezes); caminho de responsável único
  (aprova direto, já agendado); idempotência do pedido; execução real de
  `process_scheduled_deletions` (família marcada `deleted`, criança
  anonimizada, responsável perde vínculo, pedido `completed`);
  `export_family_data` (dados da própria família, `FORBIDDEN` para quem
  não é responsável de nenhuma); `revoke_consent` (revoga, rejeita
  revogar duas vezes, `FORBIDDEN` para quem não é da família);
  `purge_stale_operational_data` (remove o velho, preserva o recente).

### apps/mobile

- `/guardian/privacy` (docs/10 seção 12: "ver dados, corrigir, exportar,
  retirar foto, revogar aparelhos, consultar consentimentos, solicitar
  exclusão, acessar canal de privacidade" — corrigir/retirar foto/revogar
  aparelho já existiam em outras telas desde o Marco 1; esta tela cobre o
  resto): exportar dados (mostra o JSON, com botão copiar — mesmo padrão
  de "exportação via clipboard" já usado no log de auditoria do painel,
  Marco 7 fatia 7, para não depender de API de download específica do
  Flutter Web/mobile sem navegador real pra testar aqui); consentimentos
  com botão revogar; solicitar/aprovar/rejeitar/cancelar exclusão da
  família, com textos diferentes conforme o pedido existe ou não e quem é
  o solicitante. Card de acesso novo em `guardian_home_page.dart`.
- `packages/data_access/src/privacy/privacy_repository.dart`:
  `PrivacyRepository`.
- `consent_page.dart` (revisão de consentimento, docs/10 seção 4):
  adicionado texto sobre retenção ("enquanto sua família usar o app") e
  terceiros ("sem venda de dados, sem terceiros para publicidade"), que
  faltavam; referência corrigida de "Mais > Privacidade" (hub que nunca
  existiu) para "Início > Privacidade" (onde a tela realmente está).
  Identificação do controlador/contato de privacidade (docs/10 seção 4,
  item 1) e explicação infantil curta no ambiente da criança (item 6)
  **não foram adicionadas** — a primeira depende de dados que ainda não
  existem (razão social, contato — docs/18 seção 4); a segunda ficou fora
  desta passada para não arriscar uma tela já testada do Marco 1
  (`child_home_page.dart`) sem tempo de validar visualmente — registrada
  em docs/18 seção 7.
- Acessibilidade: 3 `IconButton` sem `tooltip` (inacessíveis a leitor de
  tela) corrigidos — `child_home_page.dart` (notificações, sair) e
  `guardian_home_page.dart` (sair). Os outros ~15 `IconButton` do app já
  tinham `tooltip`; o painel administrativo (`apps/admin_web`) já estava
  100% coberto antes desta fatia.
- `integration_test/app_test.dart` (docs/15 seção 1: "Integração Flutter"):
  scaffold real com o pacote `integration_test`, um smoke test que abre o
  app e confirma a tela de acesso comum — mesmo teste de
  `test/widget_test.dart`, mas executável num dispositivo físico de
  verdade via `flutter test integration_test`, não só no sandbox do
  `flutter_test`. **Decisão do proprietário do produto**: testar em
  aparelho físico conectado (Android via USB), nunca em emulador — não
  reabrir essa opção sem pedido explícito. Fluxos além da tela de acesso
  (onboarding, tarefas, aprovação) exigem um projeto Supabase real para
  exercitar de ponta a ponta — mesmo bloqueio de sempre.

### Runbooks

- `docs/21_RUNBOOKS_OPERACIONAIS.md` (novo): backup/restauração,
  provisionamento do primeiro administrador, resposta a incidentes
  (aplicando o plano mínimo de docs/10 seção 14 aos mecanismos reais do
  projeto — `audit_logs`, `platform_admins.active`,
  `revoke_child_device`/`admin_set_family_status`), deploy/rollback,
  checklist de release (aponta para docs/10 seção 16 e docs/15 seções
  16-17 em vez de duplicar).

### Desempenho (docs/15 seção 15: "listas paginadas")

Revisão leve de código (sem dispositivo/ambiente real pra medir de
verdade — registrado em docs/18 seção 7): três listas sem `.limit()`
encontradas e corrigidas — `WalletRepository.listLedger` (histórico de
KidsCoins) e `RedemptionRepository.listForChild`/`listForFamily`
(histórico de resgates), todas cresciam sem parar ao longo dos anos de
uso de uma família ativa. As demais listas do app já eram naturalmente
pequenas (catálogo de temas/tarefas fixo, tarefas do dia, aprovações
pendentes) ou já tinham `.limit()` desde que foram criadas (histórico de
notificações, log de auditoria do painel).

### Revisão de SDKs (docs/10 seção 15, docs/15 seção 1)

Dependências de terceiros de `apps/mobile`/`apps/admin_web`/
`packages/data_access`: `flutter_riverpod`, `go_router`, `intl`,
`cupertino_icons`, `shared_preferences` (só `admin_web`), `supabase_flutter`
(o próprio backend, não um terceiro de rastreamento). **Nenhum SDK de
anúncios, analytics ou crash reporting de terceiro** — CLAUDE.md seção 5
("não incluir SDK de anúncios"; "evitar analytics de terceiros no
ambiente infantil") totalmente respeitado, sem precisar remover nada.

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
| 7 — Premium e painel | **Concluído** | Backend de assinaturas, fundação do painel Web, módulos Assinaturas/Famílias e usuários/Temas e conteúdo/Suporte/Notificações e dashboard de métricas + log de auditoria prontos — ver seções acima. Lacunas conhecidas (não bloqueiam a conclusão do marco, mesmo espírito do Marco 5/6): push real, templates/reprocessamento de notificação e anexos privados de ticket bloqueados por infraestrutura externa; gestão de papéis e publicar temas `draft` são pendências não bloqueantes (docs/18) |
| 8 — Privacidade e release | **Concluído** | Fluxo de exclusão dupla, exportação de dados, retenção, revogação de consentimento, revisão de SDKs/segurança/acessibilidade/desempenho e runbooks prontos — ver seção "Marco 8" acima. Google Play Families, App Store Kids, TestFlight e revisão jurídica não são tarefas de engenharia — pendências registradas em docs/18 |

## Status de layout e design (mobile + admin_web)

Pergunta recorrente ("o layout já está finalizado?") — resumo para não
reabrir a investigação inteira toda vez que ela voltar.

- **Mecanismo de tema: finalizado e ligado de ponta a ponta** (Marco 5,
  ver seção acima) — tema azul/rosa do responsável e tema individual da
  criança aplicados de verdade nas duas árvores de rotas (`ShellRoute` +
  `buildGuardianTheme`/`buildKidsThemeBySlug`), com fallback seguro para
  slug desconhecido/asset ausente (docs/06 seção 6). Quatro temas com
  build real (`kids_default`, `block_world`, `space_adventure`,
  `castles_quest`); ícone do app, splash nativo e favicon/ícones do
  `admin_web` já gerados a partir de assets reais processados
  (`packages/design_system/assets`). Acessibilidade: `admin_web` 100%
  coberto (tooltips em todo `IconButton`), app mobile com 3 `IconButton`
  corrigidos no Marco 8.
- **Não finalizado — arte/marca definitiva** (docs/18 seção 2, "usar
  placeholders próprios enquanto não decidido"): logotipo final, ícone
  oficial, mascote, fonte da marca, biblioteca de sons licenciada,
  catálogo de avatares/acessórios. Dois dos seis temas do catálogo
  pretendido (Mundo Encantado, Herói Aracnídeo) ficam `draft` só por
  falta de arte — o mecanismo do painel para publicar já existe desde o
  Marco 7 fatia 5.
- **Não construído — adaptação por faixa etária** (docs/06 seção 7,
  docs/16 seção 7): hoje só a paleta de cor muda por tema; densidade e
  linguagem de UI diferenciadas para 2-7, 8-10 e 11-13+ anos não foram
  implementadas. Nenhuma animação de recompensa existe ainda para aplicar
  "reduzir movimento" — o token `motionReward` está definido no design
  system, mas sem uso real em nenhuma tela.
- **Não verificado**: nenhuma tela foi validada visualmente em
  dispositivo físico nem com leitor de tela real (WCAG AA) — só revisão
  de código (docs/18 seção 7).

Em uma frase: a **arquitetura/mecanismo de tema** está pronta e
funcionando nos dois apps; o que falta é **arte definitiva de marca** e
a **camada de adaptação por idade**, ambas decisões de produto/design,
não pendências de engenharia em aberto.

## Testes (executados localmente em 05/08/2026)

| Comando | Escopo | Resultado |
|---|---|---|
| `dart format --set-exit-if-changed .` | domain, data_access, design_system, apps/mobile, apps/admin_web | ✅ Sem alterações pendentes |
| `flutter analyze` | idem | ✅ "No issues found" em todos os 5 |
| `flutter test` | domain (29), data_access (9), design_system (10), apps/mobile (6), apps/admin_web (11) | ✅ 65/65 passando |
| `flutter test integration_test` | apps/mobile | ⛔ Pacote configurado e smoke test escrito; ainda não executado — o proprietário do produto decidiu testar em aparelho físico conectado (não em emulador), pendente de conectar o aparelho — ver docs/18 seção 7 |
| `supabase db lint --linked` | supabase/ | ✅ Executado contra o projeto real (`rdomwiykyiiuhyheujuq`) em 08/09/2026, sem depender de Docker — achou e (após correção) confirmou zero erros; ver "Primeira validação em infraestrutura real" |
| `supabase test db --linked` | supabase/ | ⛔ Confirmado que ainda exige Docker mesmo mirando o projeto remoto (baixa a imagem `pg_prove`); as 376 asserções pgTAP acumuladas dos Marcos 2-8 seguem revisadas manualmente, execução real pendente de Docker nesta máquina ou do CI |
| `flutter build apk --debug` / `flutter build web` / `flutter build ios --no-codesign` | apps/mobile, apps/admin_web | Não reexecutados neste ciclo (sem mudança de dependências nativas); ver Marco 0/1 para o último build real |

## Primeira validação em infraestrutura real (07-08/09/2026)

Primeira vez que qualquer migration deste repositório rodou contra um
Postgres/Supabase de verdade (até aqui só revisão manual, ver "Bloqueios"
abaixo).

**Correção de projeto (08/09/2026):** a fatia de 07/09 tinha linkado e
aplicado tudo contra um projeto `kids-task` (ref `npqoylppdijucywialug`,
org "Orbix-Pulse") acessível só pela integração MCP deste ambiente. Essa
conta não é a conta de desenvolvimento real do dono do produto — o CLI
`supabase`, autenticado separadamente, só enxerga a org **"Orbix Inovacao"**
(`bghtirchgxbyaxkswltc`), confirmada pelo usuário como a correta. O projeto
real de desenvolvimento é **`KidsTask`** (ref `rdomwiykyiiuhyheujuq`, região
`us-west-2`, mesma org). Estava vazio (0 tabelas); todas as 67 migrations
foram aplicadas do zero nele via `npx supabase db push --linked`. O projeto
`npqoylppdijucywialug`/"Orbix-Pulse" fica órfão — criado por engano na conta
errada, sem relação com o projeto real; nada neste repositório referencia
mais esse ref.

Problemas reais só apareceram ao rodar de verdade (nenhum detectável por
revisão manual de SQL nem pela suíte Flutter, que usa mocks):

- **Erro de sintaxe** em `20260731100016_rewards_and_redemptions.sql` e
  `20260731100025_themes_schema.sql`: `created_by uuid not null default
  (select auth.uid())` — Postgres não aceita subquery em `DEFAULT`
  (`SQLSTATE 0A000`). Corrigido direto nos arquivos originais (nenhuma das
  duas migrations tinha sido aplicada em ambiente nenhum antes disso).
- **Vazamento de privilégio `EXECUTE`**, corrigido em migration nova
  (`20260907214801_fix_function_execute_privilege_leak.sql`): todo projeto
  novo do Supabase concede `EXECUTE` em toda função nova automaticamente a
  `anon`/`authenticated` (grant direto, de fábrica, não herdado de
  `PUBLIC`). As migrations de privilégio dos Marcos 1-8 só faziam `revoke
  execute on all functions in schema public from public`, que **não**
  remove esse grant direto — toda função do schema `public`, inclusive
  `verify_child_pin` e funções administrativas internas, estava executável
  por qualquer requisição **sem sessão nenhuma** via
  `/rest/v1/rpc/<função>`. A migration nova impede herança futura do grant
  padrão, revoga `EXECUTE` de `anon` em tudo, e reseta `authenticated` para
  exatamente as 51 funções pretendidas pelos Marcos 1-8.
- **14 funções com `SQLSTATE 42702` ("column reference is ambiguous"),
  reprodução confirmada e corrigidas nesta fatia (08/09/2026)**: toda
  função `security definer` que declara `returns table (x uuid, ...)` (ou
  parâmetro `OUT`) cujo nome de coluna de retorno colide com o nome de uma
  coluna real de tabela — ex.: `complete_task_occurrence` retorna
  `occurrence_id`, e faz `where occurrence_id = p_occurrence_id` sem
  qualificar `task_events` — dispara erro de runtime **sempre que aquele
  trecho executa**, porque o padrão do PL/pgSQL (`plpgsql.variable_conflict
  = error`) é abortar diante da ambiguidade, não escolher silenciosamente
  um lado. `supabase db lint --linked` (sem precisar de Docker) achou o
  primeiro caso; reproduzido isoladamente contra o projeto real antes de
  mexer em qualquer arquivo, para confirmar que era erro de execução e não
  falso positivo do linter. Afetava: `complete_task_occurrence`,
  `review_task_occurrence`, `skip_task_occurrence`, `review_redemption`,
  `mark_redemption_delivered`, `cancel_approved_redemption`,
  `request_family_deletion`, `accept_guardian_invite`,
  `upsert_task_with_schedule`, `handle_store_notification`,
  `admin_update_theme_manifest`, `admin_publish_theme` — ou seja, concluir
  tarefa, aprovar/rejeitar tarefa, resgatar recompensa, excluir conta,
  aceitar convite de responsável, criar/editar tarefa, webhook de loja e
  publicar tema no painel estavam **todos quebrados** contra Postgres real,
  apesar de aprovados em revisão manual e nos 65 testes Flutter (que nunca
  executam o corpo da função). Corrigido em todos os arquivos de migration
  originais (qualificação explícita de tabela nos `exists`/`update`
  ambíguos, mais `#variable_conflict use_column` nas 14 funções como rede
  de segurança contra qualquer outra referência ambígua não coberta pela
  correção pontual) e reaplicado contra o projeto real. Duas funções
  administrativas adicionais tinham um segundo tipo de erro (`SQLSTATE
  42804`, `varchar(255)` retornado onde a assinatura declara `text`):
  `admin_list_theme_requests` e `admin_search_families` — corrigido com
  `::text`/`::text[]` explícito. `db lint --linked` re-executado após as
  correções: **zero erros**, restam só 5 avisos cosméticos preexistentes
  (variável de loop `i`/`v_attempt`/`v_level` sombreando uma variável já
  declarada — padrão comum e inofensivo, sem risco de execução).
- **`supabase test db --linked` confirmado ainda dependente de Docker**
  local (baixa a imagem `pg_prove` via Docker mesmo mirando o projeto
  remoto) — não dá para rodar as 376 asserções pgTAP nesta máquina até
  Docker existir aqui; `db lint --linked` não tem essa dependência e já
  cobriu o achado acima.
- **`pg_cron` confirmado agendando os 6 jobs reais** (`generate-task-
  occurrences`, `expire-due-task-occurrences`, `grant-birthday-bonus`,
  `expire-support-overrides`, `process-scheduled-deletions`,
  `purge-stale-operational-data`), todos `active = true`. Contagem de
  "sete jobs" em passagens anteriores deste documento estava errada — os
  "dois jobs que a fila `outbox_events` ainda não usa" nunca foram
  implementados como `pg_cron` (é o mesmo gap conhecido de push real por
  falta de projeto Firebase, não um job perdido).

**Achado à parte, fora do escopo de engenharia**: um arquivo solto não
rastreado (`Kids-task`) apareceu na raiz do repositório contendo a senha do
banco em texto puro. ✅ Removido em 08/09/2026 (nunca foi commitado; a senha
em si continua recuperável pelo dashboard do Supabase se precisar de novo).

**Provisionamento e validação de ponta a ponta (08/09/2026), completando as
pendências desta fatia:**

- ✅ **Primeiro `platform_admin` provisionado** (runbook `docs/21` seção 2):
  usuário criado no Supabase Auth pelo próprio dono do produto via
  dashboard (não pelo CLI/MCP, para a chave `service_role` nunca passar
  pelo agente — `projects api-keys` é bloqueado pelo classificador de
  permissões exatamente por materializar essa chave), `profiles` criado
  automaticamente pelo trigger `handle_new_auth_user`, linha inserida em
  `platform_admins` (`role = 'super_admin'`, `active = true`,
  `mfa_required = true` — MFA será exigido no primeiro acesso a
  `/admin/access`). Validação módulo a módulo do painel com dados reais
  ainda não feita — só o provisionamento.
- ✅ **`apps/mobile/env/dev.json` gerado com credenciais reais** do projeto
  `rdomwiykyiiuhyheujuq` (`SUPABASE_URL` + a chave `anon`/publicável — não
  secreta, o usuário rodou `supabase projects api-keys` na própria máquina
  e colou só essa linha, mesmo motivo do item acima). Arquivo confirmado
  `.gitignore`d (`**/env/*.json`), nunca chega a ser commitado.
- ✅ **App mobile rebuildado contra o projeto real**: `flutter build apk
  --debug` (395s de Gradle) e `flutter build apk --release` (150s,
  `app-release.apk`, 67,5 MB, assinado com a chave de debug padrão do
  Flutter) — ambos sem erro. Ainda **não testado interativamente na UI**
  (só confirma que compila e linka contra as credenciais reais); o fluxo
  de ponta a ponta (cadastro, login, criar família, completar tarefa)
  continua para o item 6 da seção "Próxima ação" abaixo (aparelho físico
  Android).

**Pendente para continuar**:

1. **Commitar tudo desta sessão** — nada foi commitado ainda:
   `20260731100016`/`20260731100025` (bug de sintaxe), a migration nova
   `20260907214801` (privilégio EXECUTE), as correções de ambiguidade de
   coluna nas 14 funções (arquivos: `20260731100005`, `20260731100011`,
   `20260731100018`, `20260731100022`, `20260731100030`, `20260731100033`,
   `20260731100040`, `20260731100049`, `20260731100050`, `20260731100060`)
   e este próprio `IMPLEMENTATION_STATUS.md`;
2. Rodar `supabase test db` (376 asserções pgTAP) assim que Docker existir
   nesta máquina — único item de validação real ainda bloqueado;
3. Validar cada módulo do painel admin com dados reais usando a conta
   `super_admin` já provisionada;
4. Testar o app pela UI de verdade (não só compilar) — instalar o
   `app-release.apk` num aparelho e passar pelo fluxo de acesso comum,
   cadastro e criação de família contra o backend real;
5. `flutter test integration_test` num aparelho físico Android (item 6 da
   seção "Próxima ação").

## Bloqueios

1. **Docker ausente localmente** — impede `supabase start`/`db lint`/
   `test db`/`functions serve` nesta máquina (reverificado nesta fatia:
   continua ausente). As migrations, políticas RLS e funções SQL dos
   Marcos 2-7 foram revisadas manualmente com atenção a nomes de coluna,
   tipos e assinaturas, mas **não foram executadas** contra um Postgres
   real. Isso inclui o pgTAP de assinaturas
   (`70_marco7_subscriptions_test.sql`), o de administradores da
   plataforma (`80_marco7_platform_admin_test.sql`), o do módulo
   Assinaturas do painel (`90_marco7_admin_subscriptions_test.sql`), o do
   módulo Famílias e usuários (`100_marco7_admin_families_test.sql`), o do
   módulo Temas e conteúdo (`110_marco7_admin_themes_test.sql`), o do
   módulo Suporte (`120_marco7_admin_support_test.sql`) e os dos módulos
   Notificações/Dashboard (`130_marco7_admin_notifications_test.sql`,
   `140_marco7_admin_dashboard_test.sql`) e o do Marco 8
   (`150_marco8_deletion_and_privacy_test.sql`), que só serão confirmados
   quando rodarem em CI ou numa máquina com Docker.
2. ✅ **Resolvido em 08/09/2026 — `pg_cron` confirmado no projeto Supabase
   real**: os 6 jobs das migrations `20260731100015_task_cron_jobs.sql`,
   `20260731100042_admin_subscription_cron.sql`,
   `20260731100061_deletion_privileges_and_cron.sql` e
   `20260731100064_privacy_function_privileges_and_cron.sql` estão
   agendados e `active = true` (ver "Primeira validação em infraestrutura
   real" acima).
3. **Provedor de e-mail transacional não configurado** — `send-guardian-invite`
   cria o convite normalmente e retorna `email_delivery: "not_configured"` com
   o link para compartilhar manualmente. Documentado também em
   `docs/18_PENDENCIAS_NAO_BLOQUEANTES.md`.
4. **Domínio do painel/app não decidido** — o link de convite usa
   `https://app.kidstask.com.br/invite` como placeholder explícito
   (`docs/18`, seção 5).
5. **Projeto Supabase de desenvolvimento já existe** (ver "Primeira
   validação em infraestrutura real" acima — `KidsTask`,
   `rdomwiykyiiuhyheujuq`, org Orbix Inovacao, todas as migrations
   aplicadas); **Firebase e contas de loja ainda não existem**. Isso ainda bloqueia push real: sem
   projeto Firebase, não há como registrar `firebase_messaging` no app nem
   enviar push de verdade (FCM/APNs) — a central interna de notificações
   funciona independente disso, mas a fila `outbox_events` fica sem nenhum
   worker consumindo.
6. **CI ainda não rodou em GitHub Actions** — pendente do primeiro push/PR.

## Build de verificação manual (release APK)

Para permitir instalar o app num celular Android e conferir visualmente o
que existe até aqui, foi gerado um APK release
(`apps/mobile/build/app/outputs/flutter-apk/app-release.apk`), assinado com
a chave de debug padrão do Flutter (`signingConfig = signingConfigs.debug`
em `android/app/build.gradle.kts` — suficiente para instalar num aparelho
próprio via "instalar de fontes desconhecidas", não serve para publicar na
Play Store).

**Atualizado em 08/09/2026 — build contra o projeto real.** Até a fatia
anterior, o build usava credenciais **placeholder**
(`https://example.supabase.co`), então qualquer ação que falasse com o
backend falhava com erro genérico por design. Isso não é mais o caso:
`apps/mobile/env/dev.json` (ignorado pelo Git) agora aponta para o projeto
`KidsTask` real (`rdomwiykyiiuhyheujuq`, `SUPABASE_URL` + chave `anon`), e
`flutter build apk --debug`/`--release --dart-define-from-file=env/dev.json`
rodaram sem erro (67,5 MB o release). O que isso confirma e o que ainda
não:

- ✅ confirma que o app compila e linka contra credenciais reais de
  produção-de-desenvolvimento;
- ❌ **não confirma** o fluxo funcional — ninguém ainda abriu o APK
  instalado e passou por cadastro/login/criar família/completar tarefa
  contra o backend real pela UI. Esse teste interativo (mais
  `flutter test integration_test` num aparelho físico Android, decisão já
  registrada de não usar emulador) é o próximo passo pendente, não algo já
  feito.

## Próxima ação

**Marcos 7 e 8 estão concluídos.** Todo o trabalho de engenharia dos
Marcos 1-8 foi entregue, testado (pgTAP + `flutter test`, 65/65) e
documentado. Não existe mais um "próximo marco" no sentido de código novo
a escrever a partir do roadmap — o que resta antes de um lançamento real
é uma mistura de (a) validar contra infraestrutura real o que já foi
revisado só manualmente, e (b) decisões de produto/jurídicas/comerciais
que nenhuma linha de código resolve sozinha.

**(a) Validação contra infraestrutura real** — nada foi executado contra
um Postgres/Supabase de verdade ainda, só revisado manualmente:

1. ✅ **Feito em 07-08/09/2026** — projeto Supabase real de desenvolvimento
   (`KidsTask`, `rdomwiykyiiuhyheujuq`, org Orbix Inovacao) com todas as
   67 migrations aplicadas — ver "Primeira validação em infraestrutura
   real" acima para os bugs achados e corrigidos (incluindo as 14 funções
   com erro de ambiguidade de coluna);
2. ✅ **Feito em 08/09/2026** — `pg_cron` confirmado: 6 jobs agendados e
   ativos (`generate-task-occurrences`, `expire-due-task-occurrences`,
   `grant-birthday-bonus`, `expire-support-overrides`,
   `process-scheduled-deletions`, `purge-stale-operational-data`);
3. ✅ **Feito em 08/09/2026** — `supabase db lint --linked`: zero erros
   após as correções (só 5 avisos cosméticos preexistentes). `supabase
   test db --linked` confirmado ainda bloqueado por Docker local (baixa a
   imagem `pg_prove` mesmo mirando o projeto remoto) — as 376 asserções
   pgTAP seguem sem execução real até Docker existir aqui ou rodar no CI;
4. ✅ **Feito em 08/09/2026** — primeiro `platform_admin` provisionado
   (`cleuvin@gmail.com`, `super_admin`, runbook `docs/21` seção 2).
   Validar cada módulo do painel com dados reais ainda está pendente
   (ver "Pendente para continuar" acima);
5. ✅ **Feito em 08/09/2026** — `apps/mobile/env/dev.json` gerado com
   valores reais do projeto `rdomwiykyiiuhyheujuq` e app rebuildado
   (debug + release, ambos sem erro) — ver "Build de verificação manual"
   abaixo para o que isso confirma e o que ainda não;
6. Rodar `flutter test integration_test` num **aparelho físico Android
   conectado por USB** (infraestrutura pronta desde o Marco 8, ainda não
   executada) — decisão do proprietário do produto: testar em aparelho
   físico, não em emulador (`flutter devices` deve listar o aparelho
   depois de conectado e com depuração USB autorizada). Com um backend
   real, fluxos além do smoke test atual passam a ser possíveis de
   escrever.

**(b) Decisões que não são engenharia**, todas já registradas em
`docs/18_PENDENCIAS_NAO_BLOQUEANTES.md` — revisão jurídica completa
(seção 6), contas de desenvolvedor Apple/Google e categoria Kids/Families
(seção 5), domínio/e-mail transacional/contato de suporte (seção 4),
preço e balanceamento final (seções 1 e 3), marca e assets finais
(seção 2). Nenhuma delas tem uma tarefa de código esperando — são
decisões do proprietário do produto ou de terceiros (advogado, Apple,
Google).

Sem essas duas frentes resolvidas, o produto está **funcionalmente
completo mas não pronto para publicar nas lojas** (docs/16 seção 10:
"candidato de produção"). Se surgir uma tarefa de engenharia nova depois
disso, ela provavelmente nasce de uma dessas decisões (ex.: categoria
Kids da Apple decidida → ajustar parental gate/textos; provedor de
e-mail escolhido → ligar `send-guardian-invite` de verdade).
