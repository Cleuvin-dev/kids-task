# 16 — Backlog e Roadmap

## 1. Regra de execução

Não iniciar várias fases incompletas em paralelo. Cada marco termina com migrations, testes, documentação e demonstração funcional.

**Status geral (ver `docs/IMPLEMENTATION_STATUS.md` para o detalhe técnico
de cada item marcado):** Marcos 0-5 concluídos. Marco 6 concluído
**parcialmente**. Quando um item está marcado `[x]` mas tem uma lacuna
relevante, o texto ao lado explica exatamente qual — nunca um item foi
silenciosamente dado como pronto. Nenhuma migration ou função SQL foi
executada contra um Postgres real ainda (sem Docker nesta máquina); tudo
abaixo foi revisado manualmente e coberto por pgTAP, pendente de
confirmação em CI.

## 2. Marco 0 — Fundação

- [x] criar monorepo;
- [x] configurar Flutter mobile e admin Web;
- [x] configurar packages compartilhados;
- [ ] criar projetos Supabase/Firebase por ambiente — nenhum projeto real existe ainda, só placeholders (bloqueio persistente desde o Marco 0);
- [x] preparar CI — `.github/workflows/ci.yml` existe, mas nunca rodou de verdade (sem push/PR ainda);
- [x] criar `.env.example`;
- [x] estabelecer design system e l10n — l10n só tem a estrutura (ARB com 2 chaves), telas usam texto pt-BR direto, não o `AppLocalizations`;
- [x] criar `docs/IMPLEMENTATION_STATUS.md`;
- [x] configurar migrations e testes SQL;
- [x] cadastrar ADR da autenticação infantil.

Saída: projetos compilando, pipeline verde e banco reproduzível.

## 3. Marco 1 — Autenticação e família

- [x] cadastro/login do responsável;
- [x] consentimentos;
- [x] criar família;
- [x] convite e deep link;
- [x] cadastrar criança;
- [x] código familiar;
- [x] PIN opcional;
- [x] sessão anônima e vínculo de aparelho;
- [x] revogação;
- [x] guards por perfil;
- [x] RLS familiar.

Saída: responsável e criança entram no mesmo app em ambientes diferentes.

## 4. Marco 2 — Rotina e tarefas

- [x] catálogo de ícones/tarefas — ~55 templates seedados (docs/17); "ícones" são só chaves lógicas, sem arte própria ainda;
- [x] tarefas e agendas — os 5 tipos num único formulário com campos condicionais;
- [x] geração de ocorrências — `pg_cron` diário, disponibilidade não confirmada num projeto real;
- [x] limite gratuito de três;
- [x] tela Hoje;
- [x] conclusão automática;
- [x] aprovação manual;
- [x] rejeição/correção;
- [x] atraso/expiração;
- [x] realtime;
- [x] histórico.

Saída: rotina diária completa em dois aparelhos.

## 5. Marco 3 — KidsCoins e recompensas

- [x] wallet e ledger;
- [x] ajustes manuais;
- [x] catálogo de recompensas;
- [x] pedido/aprovação/recusa;
- [x] entrega e estorno;
- [ ] conversão simbólica — docs/05 seção 6 não implementada; taxa sugerida ainda é pendência não bloqueante (docs/18);
- [x] testes de concorrência — duplo-approve/duplo-tap cobertos em pgTAP.

Saída: economia familiar íntegra e auditável.

## 6. Marco 4 — XP e progressão

- [x] XP ledger;
- [x] níveis;
- [x] bônus de nível;
- [ ] unlocks — sem catálogo de cosméticos ainda (depende de conteúdo do Marco 5, que também não foi construído);
- [x] streak configurável;
- [x] progresso diário;
- [x] aniversário;
- [ ] medalhas — mesma dependência de `unlocks`;
- [x] telas de progresso.

Saída: gamificação individual sem ranking.

## 7. Marco 5 — Temas e experiência por idade

- [x] tema azul/rosa do responsável — agora aplicado de verdade (antes deste marco o app inteiro rodava só no azul);
- [x] engine de temas infantis — `buildKidsThemeBySlug`, fallback seguro para slug desconhecido;
- [x] Tema Infantil Padrão;
- [x] Mundo dos Blocos;
- [x] temas Premium iniciais — Aventura Espacial e Princesas e Castelos; Mundo Encantado e Herói Aracnídeo ficam `draft` até ter arte;
- [ ] modo 2–7 — só a paleta de cores muda por tema; densidade/linguagem de UI por faixa etária não foi construída;
- [ ] modo 8–10 — idem;
- [ ] modo 11–13+ — idem;
- [ ] movimento/som/acessibilidade — não existe nenhuma animação de recompensa ainda para aplicar "reduzir movimento"; token `motionReward` existe mas está sem uso real;
- [x] fallback/versionamento.

Saída: temas individuais estáveis e adequados à idade.

## 8. Marco 6 — Notificações

- [ ] FCM Android — bloqueado: sem projeto Firebase real, nenhum SDK de push foi adicionado ao app;
- [ ] APNs/FCM iOS — mesmo bloqueio;
- [x] tokens — `device_tokens` + `register_device_token`/`deactivate_device_token` prontos; sem SDK de push, nenhum token real passa por eles ainda;
- [x] outbox — `outbox_events`, sem nenhum worker consumindo (não há para onde enviar sem Firebase);
- [ ] matriz completa de eventos — só os pontos de maior tráfego (tarefa enviada/aprovada/rejeitada, resgate solicitado/aprovado, nível, aniversário); convite aceito, novo aparelho, tarefa próxima/atrasada e o resto da matriz de docs/11 seções 2-3 ficaram de fora;
- [ ] preferências — schema e RLS prontos (`notification_preferences`), sem tela nem qualquer enforcement real (não há o que fazer com a preferência sem um worker de envio);
- [ ] quiet hours — mesma lacuna: coluna existe, nada a aplica ainda;
- [x] notificações internas — central funciona de ponta a ponta nos dois perfis, testada;
- [ ] templates seguros — sem envio de push real, o texto restrito de lock screen (docs/11 seção 6) ainda não tem onde se aplicar; o conteúdo interno hoje é completo, não restrito;
- [x] deep links — cada notificação carrega uma rota e a central navega até ela ao abrir.

Saída: ações sincronizadas e notificadas sem dados sensíveis — alcançado
só dentro do app (central interna); a entrega por push de verdade depende
de um projeto Firebase real.

## 9. Marco 7 — Premium e painel Web

Parcial. Fatias 1 (backend de assinaturas), 2 (fundação do painel: login,
MFA, auditoria), 3 (módulo Assinaturas), 4 (módulo Famílias e usuários) e
5 (módulo Temas e conteúdo) concluídas — ver
`docs/IMPLEMENTATION_STATUS.md`.

- [x] planos/entitlements — modelo de assinatura completo (`subscriptions`, `v_effective_entitlements`, `resolve_effective_plan_code`);
- [x] produtos de loja — `subscription_products`, mapeamento versionado store+product_id→plano;
- [x] compra e restauração — `submit_purchase_receipt`, `restore_entitlements`;
- [x] validação backend — `verify_purchase` (máquina de estados real; validação criptográfica contra a loja em si continua bloqueada por falta de conta de desenvolvedor, docs/18 seção 5);
- [x] webhooks — `handle_apple_notification`/`handle_google_notification`, idempotentes e com detecção de evento fora de ordem; nenhuma Edge Function de recepção/validação de assinatura foi criada ainda;
- [x] downgrade seguro — `apply_safe_downgrade`/`restore_paused_entitlements`, testado (docs/02 seção 5);
- [x] painel com MFA — fundação pronta: login separado, `platform_admins`, MFA obrigatório (TOTP) e auditoria (`record_admin_audit_log`);
- [x] famílias/usuários — busca, detalhe (responsáveis, plano, crianças com identidade oculta por padrão e revelação justificada/auditada, aparelhos, consentimentos) e `admin_set_family_status` (docs/12 seção 11: motivo obrigatório, revoga aparelhos infantis, notifica responsáveis, auditado); o bloqueio do lado do responsável é aplicado pelo app móvel (`SessionRoleResolver`/`GuardianFamilyBlocked`), já que a sessão do Supabase Auth não pode ser revogada por uma função SQL comum;
- [x] assinatura (módulo do painel — docs/12 seção 5): busca de família, plano efetivo, eventos, conceder/revogar override de suporte com expiração automática (`expire_support_overrides` via `pg_cron`);
- [x] temas/conteúdo — catálogo administrado de ponta a ponta (criar rascunho, editar chave de asset, publicar com versionamento e confirmação de revisão de PI, retirar sem quebrar famílias atuais) e fila de solicitações Premium de tema; publicar os temas `draft` do Marco 5 (Mundo Encantado, Herói Aracnídeo) continua bloqueado só por falta de arte própria, não de mecanismo;
- [ ] suporte;
- [ ] métricas e auditoria.

Saída: modelo de negócio operacional.

## 10. Marco 8 — Privacidade e release

Não iniciado.

- [ ] fluxo de exclusão dupla;
- [ ] exportação de dados;
- [ ] retenção;
- [ ] revisão de consentimento;
- [ ] revisão de SDKs;
- [ ] pentest/segurança;
- [ ] testes E2E;
- [ ] desempenho;
- [ ] acessibilidade;
- [ ] Google Play Families;
- [ ] App Store/Kids e parental gate;
- [ ] TestFlight e track fechado;
- [ ] backups e runbooks;
- [ ] revisão jurídica.

Saída: candidato de produção.

## 11. Pós-MVP

- comprovação por foto com revisão de privacidade;
- relatórios e exportações avançadas;
- streak milestones com bônus;
- temas sazonais;
- mais idiomas;
- sugestões de rotina por idade;
- widgets;
- web app para responsáveis, se houver demanda;
- integração com calendários, somente com consentimento;
- múltiplas famílias por responsável, se necessário;
- modo escolar/institucional separado.

Continuam fora do plano:

- ranking infantil público;
- chat anônimo;
- anúncios comportamentais;
- dinheiro sacável;
- tema copiado de propriedade intelectual.

## 12. Riscos prioritários

| Risco | Mitigação |
|---|---|
| Acesso infantil com PIN fraco | sessão por aparelho, rate limit e pareamento |
| Crédito duplicado | ledger, constraints e idempotência |
| Regras SQL só em produção | migrations e CI obrigatórios |
| Rejeição nas lojas | revisão Families/Kids, IAP e parental gate |
| Excesso de dados infantis | minimização e revisão de SDKs |
| Downgrade apagar dados | política de pausa, nunca exclusão |
| Temas infringirem marcas | curadoria e assets originais |
| Escopo grande do MVP | marcos demonstráveis e feature flags |

