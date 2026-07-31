# 16 — Backlog e Roadmap

## 1. Regra de execução

Não iniciar várias fases incompletas em paralelo. Cada marco termina com migrations, testes, documentação e demonstração funcional.

## 2. Marco 0 — Fundação

- [ ] criar monorepo;
- [ ] configurar Flutter mobile e admin Web;
- [ ] configurar packages compartilhados;
- [ ] criar projetos Supabase/Firebase por ambiente;
- [ ] preparar CI;
- [ ] criar `.env.example`;
- [ ] estabelecer design system e l10n;
- [ ] criar `docs/IMPLEMENTATION_STATUS.md`;
- [ ] configurar migrations e testes SQL;
- [ ] cadastrar ADR da autenticação infantil.

Saída: projetos compilando, pipeline verde e banco reproduzível.

## 3. Marco 1 — Autenticação e família

- [ ] cadastro/login do responsável;
- [ ] consentimentos;
- [ ] criar família;
- [ ] convite e deep link;
- [ ] cadastrar criança;
- [ ] código familiar;
- [ ] PIN opcional;
- [ ] sessão anônima e vínculo de aparelho;
- [ ] revogação;
- [ ] guards por perfil;
- [ ] RLS familiar.

Saída: responsável e criança entram no mesmo app em ambientes diferentes.

## 4. Marco 2 — Rotina e tarefas

- [ ] catálogo de ícones/tarefas;
- [ ] tarefas e agendas;
- [ ] geração de ocorrências;
- [ ] limite gratuito de três;
- [ ] tela Hoje;
- [ ] conclusão automática;
- [ ] aprovação manual;
- [ ] rejeição/correção;
- [ ] atraso/expiração;
- [ ] realtime;
- [ ] histórico.

Saída: rotina diária completa em dois aparelhos.

## 5. Marco 3 — KidsCoins e recompensas

- [ ] wallet e ledger;
- [ ] ajustes manuais;
- [ ] catálogo de recompensas;
- [ ] pedido/aprovação/recusa;
- [ ] entrega e estorno;
- [ ] conversão simbólica;
- [ ] testes de concorrência.

Saída: economia familiar íntegra e auditável.

## 6. Marco 4 — XP e progressão

- [ ] XP ledger;
- [ ] níveis;
- [ ] bônus de nível;
- [ ] unlocks;
- [ ] streak configurável;
- [ ] progresso diário;
- [ ] aniversário;
- [ ] medalhas;
- [ ] telas de progresso.

Saída: gamificação individual sem ranking.

## 7. Marco 5 — Temas e experiência por idade

- [ ] tema azul/rosa do responsável;
- [ ] engine de temas infantis;
- [ ] Tema Infantil Padrão;
- [ ] Mundo dos Blocos;
- [ ] temas Premium iniciais;
- [ ] modo 2–7;
- [ ] modo 8–10;
- [ ] modo 11–13+;
- [ ] movimento/som/acessibilidade;
- [ ] fallback/versionamento.

Saída: temas individuais estáveis e adequados à idade.

## 8. Marco 6 — Notificações

- [ ] FCM Android;
- [ ] APNs/FCM iOS;
- [ ] tokens;
- [ ] outbox;
- [ ] matriz completa de eventos;
- [ ] preferências;
- [ ] quiet hours;
- [ ] notificações internas;
- [ ] templates seguros;
- [ ] deep links.

Saída: ações sincronizadas e notificadas sem dados sensíveis.

## 9. Marco 7 — Premium e painel Web

- [ ] planos/entitlements;
- [ ] produtos de loja;
- [ ] compra e restauração;
- [ ] validação backend;
- [ ] webhooks;
- [ ] downgrade seguro;
- [ ] painel com MFA;
- [ ] famílias/usuários;
- [ ] assinatura;
- [ ] temas/conteúdo;
- [ ] suporte;
- [ ] métricas e auditoria.

Saída: modelo de negócio operacional.

## 10. Marco 8 — Privacidade e release

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

