# 21 — Runbooks Operacionais

Procedimentos mínimos para operar o Kid's Task em produção (Marco 8, docs/16 seção 10: "backups e runbooks"). Como nenhum projeto Supabase/Firebase/loja real existe ainda (docs/18 seção 5, docs/IMPLEMENTATION_STATUS.md "Bloqueios"), os passos abaixo descrevem o procedimento — a primeira execução real só é possível depois que esses projetos existirem.

## 1. Backup e restauração

O Supabase Cloud mantém backups automáticos gerenciados (frequência e retenção dependem do plano contratado — decisão pendente, docs/18 seção 7: "estratégia de backup e região").

Procedimento mínimo antes de produção:

1. confirmar o plano do projeto Supabase e a política de backup automático correspondente;
2. agendar (ou confirmar) backups lógicos adicionais (`pg_dump`) para uma região/conta separada da hospedagem principal — proteção contra perda da conta do provedor, não só do banco;
3. documentar e testar a restauração completa (`supabase db reset` local a partir de um dump real) pelo menos uma vez antes do lançamento — docs/15 seção 15: "backup e restauração testados antes de produção";
4. versionar toda mudança de schema como migration (`supabase/migrations/`) — nunca alterar produção fora de migration (CLAUDE.md seção 4);
5. após qualquer restauração, reconferir `pg_cron` (`expire_due_task_occurrences`, `expire_support_overrides`, `process_scheduled_deletions`, `purge_stale_operational_data`) e RLS antes de liberar tráfego.

## 2. Provisionar o primeiro administrador da plataforma

Não há autocadastro (docs/12 seção 10; docs/18 seção 7 — "gestão de papéis" é pendência não bloqueante).

1. Criar o usuário no Supabase Auth (console ou `service_role`), fora do app;
2. Inserir a linha correspondente em `platform_admins` (`profile_id`, `role`, `active = true`) via SQL direto com `service_role` — nunca por um endpoint do app;
3. Pedir para o novo administrador entrar em `/admin/access` e completar o enrolamento de MFA (`/admin/mfa/enroll`) no primeiro login;
4. Registrar a criação em canal interno da equipe (ainda não existe trilha própria para provisionamento — `record_admin_audit_log` só cobre ações feitas de dentro do painel).

## 3. Resposta a incidentes

Mesmo plano mínimo de docs/10 seção 14, com apontamento de onde cada passo acontece hoje:

1. **Detectar e conter** — monitorar `supabase get_logs`/`get_advisors` (Postgres, Auth, Edge Functions) e o log de auditoria do painel (`/admin/audit-log`, docs/12 seção 10);
2. **Preservar evidências** — `audit_logs` é append-only (sem policy de update/delete); não editar linhas manualmente durante a investigação;
3. **Avaliar dados e titulares afetados** — cruzar `family_id`/`resource_id` do evento com `families`/`child_profiles` (painel, módulo Famílias e usuários, docs/12 seção 4) — identidade infantil só via `admin_reveal_child_identity`, com justificativa e auditoria;
4. **Revogar chaves/sessões** — chave `service_role` comprometida: rotacionar no console do Supabase imediatamente (invalida todas as Edge Functions até o redeploy); sessão de administrador: `platform_admins.active = false` revoga o acesso no próximo `resolve()`; sessão infantil: `revoke_child_device`/`admin_set_family_status` (fatia 4) revoga aparelhos;
5. **Corrigir causa** — migration nova (nunca editar uma já commitada, CLAUDE.md seção 4) ou correção de código, com teste que comprove a falha antes da correção;
6. **Obrigações de comunicação** — depende de revisão jurídica (docs/18 seção 6); ainda não há processo formal definido;
7. **Registrar decisões** — em `docs/18_PENDENCIAS_NAO_BLOQUEANTES.md` ou num ADR (`docs/adr/`) quando a decisão afetar arquitetura;
8. **Revisar controles** — atualizar este runbook e os testes relevantes (pgTAP/`flutter test`) para cobrir o cenário.

Incidente envolvendo dados de criança é prioridade máxima (docs/10 seção 14).

## 4. Deploy e rollback

- **Migrations**: aplicadas em ordem pelo nome do arquivo (`supabase/migrations/YYYYMMDDHHMMSS_*.sql`); nunca editar uma migration já aplicada em produção — sempre uma nova migration corretiva (mesmo princípio já seguido em todo o histórico do projeto);
- **Edge Functions**: deploy via Supabase CLI; rollback é reverter para a versão anterior do código e reimplantar (sem versionamento automático de Edge Function no Supabase);
- **Apps Flutter**: rollback é promover a build anterior na track da loja (Android: track interno/fechado; iOS: TestFlight) — nenhuma das duas contas existe ainda (docs/18 seção 5);
- **Painel Web**: hospedagem ainda não decidida (docs/18 seção 4); rollback depende de onde for hospedado.

## 5. Checklist antes de qualquer release

Reaproveita docs/10 seção 16 e docs/15 seções 16-17 — não duplicado aqui.

## 6. Contatos e responsabilidades

Pendente (docs/18 seção 4): e-mail de suporte, contato de privacidade/encarregado, horários de atendimento, responsável de plantão. Preencher antes do lançamento.
