# 14 — APIs, Funções e Eventos

## 1. Diretriz

Operações simples de leitura podem usar Data API com RLS. Operações que alteram saldo, nível, assinatura, vínculo infantil ou exclusão devem usar funções transacionais/Edge Functions com autorização explícita.

## 2. Funções de família e autenticação

| Operação | Chamador | Implementação | Resultado |
|---|---|---|---|
| `create_family` | responsável | RPC | família + owner + plano free |
| `rotate_family_code` | responsável | Edge/RPC | revoga código antigo e gera novo |
| `invite_guardian` | responsável | Edge Function | convite + e-mail |
| `accept_guardian_invite` | convidado | Edge Function | vínculo familiar |
| `remove_guardian` | responsável autorizado | RPC | revogação auditada |
| `create_child` | responsável | RPC | perfil + carteira |
| `update_child` | responsável | RPC/Data API com RLS | perfil atualizado |
| `set_child_pin` | responsável | Edge Function | hash do PIN |
| `authorize_child_device` | sessão técnica | Edge Function | vínculo de aparelho |
| `revoke_child_device` | responsável | RPC | vínculo revogado |

## 3. Funções de tarefas

### `upsert_task_with_schedule`

Responsabilidades:

- autorizar responsável;
- validar campos;
- validar plano;
- criar/editar tarefa e agenda;
- atualizar ocorrências futuras;
- retornar conflitos.

### `generate_task_occurrences`

- executada por job;
- idempotente;
- gera janela móvel;
- usa fuso;
- respeita pausa e limites;
- registra conflitos operacionais.

### `complete_task_occurrence`

Entrada:

- `occurrence_id`;
- `idempotency_key`;
- versão esperada.

Saída:

- estado;
- saldo;
- XP;
- nível;
- recompensas concedidas;
- estado do dia.

No modo automático, aprova e recompensa. No manual, apenas envia.

### `review_task_occurrence`

Entrada:

- ocorrência;
- decisão approve/reject;
- motivo obrigatório na rejeição;
- idempotency key.

Na aprovação, executa crédito/XP/nível atomicamente.

### `skip_task_occurrence`

Somente responsável; exige motivo e retira a ocorrência do denominador de streak.

## 4. Funções de carteira e progressão

| Função | Efeito |
|---|---|
| `adjust_child_coins` | crédito/débito manual com motivo |
| `grant_task_rewards` | interna; ledger de coin + XP |
| `process_level_changes` | calcula níveis, unlocks e bônus |
| `grant_birthday_bonus` | uma vez por ano |
| `recalculate_daily_progress` | qualificação do streak |
| `advance_streak` | atualiza streak de modo idempotente |

Funções internas não devem ser executáveis diretamente por clientes.

## 5. Funções de recompensas

| Função | Chamador | Regra |
|---|---|---|
| `create_reward` | responsável | custo não negativo |
| `request_redemption` | criança | valida ativo e saldo |
| `review_redemption` | responsável | debita apenas ao aprovar |
| `mark_redemption_delivered` | responsável | sem novo débito |
| `cancel_approved_redemption` | responsável | estorno atômico e motivo |

## 6. Funções de temas

- `list_available_themes(child_id)`;
- `apply_child_theme(child_id, theme_id)`;
- `submit_theme_request`;
- `publish_theme_version` apenas painel;
- `retire_theme` apenas painel.

`apply_child_theme` valida:

- família;
- papel;
- estado publicado;
- entitlement;
- nível, quando aplicável.

## 7. Assinaturas

- `get_store_products` ocorre no cliente por SDK da loja;
- `verify_purchase` no backend;
- `handle_apple_notification`;
- `handle_google_notification`;
- `restore_entitlements`;
- `apply_subscription_transition`;
- `apply_safe_downgrade`.

Webhooks validam assinatura/autenticidade conforme documentação oficial da loja.

## 8. Exclusão

- `request_family_deletion`;
- `respond_family_deletion`;
- `cancel_family_deletion`;
- `execute_family_deletion` interna;
- `request_child_deletion`.

Todas exigem reautenticação ou token recente apropriado e criam auditoria.

## 9. Eventos de domínio

| Evento | Produtor | Consumidores |
|---|---|---|
| `family.guardian_invited` | convite | e-mail |
| `family.guardian_joined` | aceite | push/auditoria |
| `child.device_authorized` | login infantil | segurança/push |
| `task.occurrence_due_soon` | job | push infantil |
| `task.occurrence_submitted` | criança | aprovação/push responsável |
| `task.occurrence_approved` | responsável/sistema | wallet, XP, push |
| `task.occurrence_rejected` | responsável | push infantil |
| `task.occurrence_overdue` | job | push/relatório |
| `wallet.coins_changed` | ledger | UI/push |
| `progress.level_up` | progressão | unlocks/bônus/push |
| `progress.birthday_bonus` | job | wallet/push |
| `redemption.requested` | criança | push responsável |
| `redemption.approved` | responsável | wallet/push |
| `redemption.rejected` | responsável | push infantil |
| `subscription.changed` | webhook | entitlements/downgrade |
| `family.deletion_requested` | responsável | segundo responsável |

## 10. Envelope do evento

```json
{
  "event_id": "uuid",
  "event_type": "task.occurrence_approved",
  "aggregate_type": "task_occurrence",
  "aggregate_id": "uuid",
  "family_id": "uuid",
  "occurred_at": "UTC timestamp",
  "schema_version": 1,
  "idempotency_key": "string",
  "payload": {}
}
```

Payload não deve incluir PIN, código familiar, token, data de nascimento ou foto.

## 11. Erros de domínio

Padronizar códigos:

- `AUTH_REQUIRED`;
- `FORBIDDEN`;
- `SESSION_REVOKED`;
- `FAMILY_NOT_FOUND`;
- `PLAN_CHILD_LIMIT`;
- `PLAN_DAILY_TASK_LIMIT`;
- `TASK_NOT_COMPLETABLE`;
- `TASK_EXPIRED`;
- `VERSION_CONFLICT`;
- `ALREADY_PROCESSED`;
- `INSUFFICIENT_COINS`;
- `REDEMPTION_NOT_PENDING`;
- `THEME_NOT_ENTITLED`;
- `SUBSCRIPTION_NOT_VERIFIED`;
- `RATE_LIMITED`;
- `VALIDATION_ERROR`.

A UI traduz o código para mensagem amigável; não exibe stack ou SQL.

## 12. Concorrência

- `SELECT ... FOR UPDATE` em carteira e ocorrência quando necessário;
- versão otimista nos registros;
- unique constraints como última defesa;
- idempotency key por ação;
- retry apenas para erros seguros;
- callbacks fora de ordem tratados por timestamp/versão da fonte.

## 13. Jobs e frequência inicial

| Job | Frequência sugerida |
|---|---|
| Gerar ocorrências | diário + após editar agenda |
| Verificar prazo | a cada 5 minutos |
| Lembretes | a cada 5 minutos |
| Aniversários | diário após 00:05 no fuso |
| Streak diário | após fechamento do dia + reprocessamento |
| Outbox | contínuo/curto intervalo |
| Tokens/convites expirados | diário |
| Exclusões | diário |
| Reconciliação de assinatura | diária + webhooks |

Frequências são parâmetros operacionais, não constantes espalhadas.

