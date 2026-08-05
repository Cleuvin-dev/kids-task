# 18 — Pendências Não Bloqueantes

Estas decisões não impedem a fundação do MVP. Devem ser configuráveis e resolvidas antes da publicação.

## 1. Produto e negócio

| Item | Estado | Diretriz provisória |
|---|---|---|
| Preço Premium mensal | A definir | buscar da loja, nunca fixar na UI |
| Plano anual | A definir | deixar arquitetura preparada |
| Período de teste | A definir | sem trial por padrão |
| Países além do Brasil | Futuro | bloquear escopo inicial em pt-BR |
| Política de uso justo Premium | A definir | limites técnicos altos, não comerciais |
| SLA de solicitação de tema | A definir | comunicar que não há garantia |

## 2. Marca e design

- logotipo final;
- ícone Android/iOS;
- mascote;
- assets finais do Tema Infantil Padrão;
- assets finais do Mundo dos Blocos;
- assets dos três temas Premium iniciais;
- catálogo inicial de avatares e acessórios;
- biblioteca licenciada de sons;
- fonte da marca.

Durante o desenvolvimento, usar placeholders próprios, claramente identificados e fáceis de substituir.

## 3. Balanceamento

Valores iniciais já documentados:

- 10 XP por tarefa aprovada;
- curva de nível `50 × (L - 1) × L`;
- 5 KidsCoins por nível;
- 50 KidsCoins no aniversário;
- streak percentual padrão de 80%.

Eles são suficientes para implementar, mas devem ser avaliados em beta e permanecer configuráveis.

Também falta decidir:

- valor padrão sugerido de KidsCoins por tarefa;
- taxa simbólica KidsCoin → BRL sugerida no onboarding;
- se marcos de streak concederão bônus em fase posterior.

## 4. Operação

- domínio do painel Web;
- remetente e provedor de e-mail transacional;
- e-mail de suporte;
- contato de privacidade/encarregado;
- razão social e dados do controlador;
- horários de atendimento;
- política de moderação para solicitações de tema;
- processo de incidentes e responsável de plantão.

## 5. Lojas

- bundle IDs/package names;
- IDs finais de assinatura em produção;
- conta Apple Developer;
- conta Google Play Console;
- categoria e classificação etária finais;
- decisão sobre participação na Kids Category da Apple;
- textos e screenshots de loja;
- política de privacidade pública;
- termos da assinatura;
- detalhes de trial/ofertas.

## 6. Privacidade e jurídico

Requer revisão jurídica:

- texto de consentimento;
- bases legais por finalidade;
- prazo de retenção;
- período de segurança de exclusão, sugerido em sete dias;
- fluxo em disputa entre responsáveis;
- RIPD;
- política de privacidade;
- termos de uso;
- contratos com Supabase, Firebase, e-mail e lojas;
- ECA Digital e regras vigentes no lançamento.

## 7. Decisões técnicas de implementação

O time pode decidir, documentando em ADR:

- versões exatas do Flutter e dependências;
- provedor de e-mail;
- mecanismo de execução dos jobs;
- hospedagem do painel;
- ferramenta de feature flags;
- uso ou não de serviço externo de crash reporting após revisão de privacidade;
- estratégia de backup e região.

Pendências específicas do backend de assinaturas (Marco 7, fatia 1 —
`docs/IMPLEMENTATION_STATUS.md`):

- Edge Function que valida a assinatura/autenticidade do webhook (JWS da
  Apple, Pub/Sub da Google) antes de chamar `handle_apple_notification`/
  `handle_google_notification` — ainda não existe; hoje essas funções SQL
  são `service_role`-only e presumem que o chamador já validou. Depende das
  contas de desenvolvedor Apple/Google (seção 5 acima);
- `apply_safe_downgrade` sempre reverte tema Premium para `kids_default`,
  sem lembrar o último tema gratuito usado pela criança — exigiria uma
  coluna de histórico não implementada; docs/02 seção 5 não especifica qual
  tema gratuito deve valer;
- Critério de desempate de quais ocorrências do dia permanecem ativas no
  downgrade: as mais antigas por `created_at`. docs/02 seção 5 não define
  um critério; se o produto quiser outro (ex.: por horário programado da
  tarefa), é uma migration nova em `apply_safe_downgrade`.

Pendências específicas do painel administrativo (Marco 7, fatias 4-7 —
`docs/IMPLEMENTATION_STATUS.md`):

- "Gestão de papéis" (docs/12 seção 2: `super_admin` promover outros
  administradores pela UI) — nenhuma fatia implementou; provisionar um
  admin continua manual (`service_role`, criar usuário + inserir linha em
  `platform_admins`). Sem prioridade definida porque nenhum módulo até o
  fim do Marco 7 dependeu disso de verdade;
- Anexos privados em tickets de suporte (docs/12 seção 9, Marco 7 fatia 6)
  — adiado por ser o primeiro upload de arquivo de verdade do projeto
  inteiro (nem foto de criança, docs/09, tem pipeline real); exige decisão
  própria de bucket do Supabase Storage e policies de `storage.objects`;
- Templates/categorias, reprocessamento controlado e teste para aparelhos
  internos de notificação (docs/12 seção 8, Marco 7 fatia 7) — bloqueados
  pela mesma raiz do bloqueio de push do Marco 6 (sem projeto Firebase,
  não há pipeline de entrega real para reprocessar ou testar; templates
  exigiriam refatorar as chamadas de `emit_notification` já commitadas nos
  Marcos 2-6 para ler de uma tabela nova, fora do escopo de uma fatia de
  painel);
- Publicar os temas `draft` do Marco 5 (Mundo Encantado, Herói Aracnídeo) —
  o mecanismo do painel já existe (Marco 7 fatia 5), só falta a arte
  (seção 2 acima).

Pendências específicas do Marco 8 — Privacidade e release
(`docs/IMPLEMENTATION_STATUS.md`):

- Janelas de retenção técnicas implementadas como default, pendentes de
  validação jurídica (docs/10 seção 13; seção 6 acima): convite não aceito/
  cancelado/expirado — 30 dias; tentativa de login infantil — 90 dias;
  token de push inativo — 30 dias; período de segurança de exclusão — 7
  dias (já sugerido em docs/10 seção 10, não inventado aqui). Trocar
  qualquer uma é editar a função correspondente
  (`purge_stale_operational_data`/`request_family_deletion`), não uma
  migration de schema;
- Escopo exato de "apagar ou anonimizar" na exclusão de família (docs/10
  seção 11) — o default técnico adotado (`process_scheduled_deletions`)
  anonimiza identidade da criança (nome, apelido, foto, PIN) e mantém
  ledgers/eventos financeiros/de auditoria intocados (não têm nome, só
  `child_id`); confirmar com jurídico se isso satisfaz a obrigação legal
  ou se algo mais precisa ser apagado;
- Confirmação por e-mail ao concluir a exclusão (docs/10 seção 10, passo
  9) não é enviada — depende do provedor de e-mail transacional (seção 4
  acima), mesma pendência já registrada para convites;
- Reautenticação de senha antes de solicitar exclusão (docs/10 seção 10,
  caminho de responsável único) não é forçada pelo backend — o app usa
  uma confirmação explícita forte (checkbox + explicação), não uma
  verificação de senha nova; revisar se isso é suficiente ou se merece
  reautenticação real numa fatia futura;
- Testes E2E (`apps/mobile/integration_test/`): infraestrutura pronta
  (pacote `integration_test`, um smoke test real), mas fluxos além da
  tela de acesso comum exigem um projeto Supabase real para exercitar de
  ponta a ponta — mesmo bloqueio de sempre;
- Auditoria de acessibilidade completa (WCAG AA, leitor de tela, navegação
  por teclado no painel Web) não foi feita com ferramentas reais de
  acessibilidade — só uma revisão de código (tooltips de `IconButton`
  ausentes corrigidos, docs/06 seção 9). Recomenda-se uma passada com
  TalkBack/VoiceOver e um leitor de tela no navegador antes do
  lançamento;
- Pentest externo — a auto-revisão desta fatia é uma revisão de código
  (RLS, ordem de checagem de autorização, isolamento entre famílias), não
  substitui um pentest de verdade contra um ambiente real (docs/15 seção
  1: "Segurança | enumeração, rate limit, acesso cruzado").

## 8. Decisões que não estão pendentes

Não reabrir sem solicitação do proprietário:

- um único aplicativo móvel;
- Android e iOS;
- Supabase + FCM;
- painel Web;
- uma criança no gratuito;
- três ocorrências por dia no gratuito;
- dois temas gratuitos;
- KidsCoin;
- XP separado;
- bônus configuráveis;
- múltiplos responsáveis;
- criança com código + PIN opcional;
- sem offline;
- sem ranking;
- sem gênero;
- sem prova por foto no MVP;
- sem anúncios;
- português/Brasil inicialmente.

