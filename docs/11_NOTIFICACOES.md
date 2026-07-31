# 11 — Notificações

## 1. Canais

- push por FCM/APNs;
- central interna de notificações;
- e-mail para convite, segurança, assinatura e exclusão;
- nenhum SMS no MVP.

## 2. Eventos da criança

| Evento | Canal | Ação ao tocar |
|---|---|---|
| Tarefa próxima | Push + central | detalhe da tarefa |
| Tarefa atrasada | Push + central | tarefas de hoje |
| KidsCoins recebidos | Push + central | carteira |
| Resgate aprovado | Push + central | pedido |
| Resgate rejeitado | Push + central | pedido + motivo |
| Subida de nível | Push + central | progresso |
| Bônus de aniversário | Push + central | celebração/carteira |

## 3. Eventos do responsável

| Evento | Canal | Ação ao tocar |
|---|---|---|
| Criança enviou conclusão | Push + central | aprovação |
| Tarefa aguardando aprovação | Push + central | fila |
| Pedido de resgate | Push + central | resgate |
| Tarefa atrasada/expirada | Push + central | rotina da criança |
| Convite aceito | Push + central | responsáveis |
| Novo aparelho infantil | Push + central + e-mail de segurança | aparelhos |
| Pedido de exclusão | Push + central + e-mail | decisão |
| Assinatura em problema | Push + central + e-mail | assinatura |

Todos os eventos confirmados pelo usuário estão contemplados.

## 4. Preferências

Por família/criança:

- ligar/desligar cada categoria opcional;
- antecedência da tarefa;
- lembrete de atraso;
- resumo diário;
- horário silencioso;
- som/vibração conforme sistema.

Notificações essenciais de segurança e exclusão não podem ser desativadas totalmente; se push estiver negado, usar e-mail do responsável.

## 5. Agenda

- tarefa próxima: padrão 15 minutos antes, configurável;
- tarefa atrasada: após mudança de estado;
- aprovação pendente: imediatamente e lembrete agrupado;
- resumo do responsável: opcional no fim do dia;
- respeitar fuso da família;
- evitar envio durante quiet hours, salvo segurança.

## 6. Privacidade do conteúdo

Padrão de lock screen:

- “Você tem uma tarefa próxima.”
- “Há uma conclusão esperando sua aprovação.”
- “Uma recompensa foi atualizada.”

Evitar:

- nome completo;
- data de nascimento;
- saldo detalhado;
- motivo de rejeição;
- foto;
- texto livre do responsável;
- código familiar.

O conteúdo completo aparece somente após abrir e autorizar o aplicativo.

## 7. Implementação

- registrar um token por instalação e contexto;
- associar token infantil ao vínculo de aparelho;
- renovar token quando o provedor alterar;
- desativar token inválido;
- usar outbox;
- agrupar notificações duplicadas;
- chaves de colapso por ocorrência;
- deep link com identificador opaco;
- revalidar permissão ao abrir.

## 8. Idempotência

Uma aprovação repetida não gera vários push. Evento de notificação tem chave única, por exemplo:

```text
task_approved:<occurrence_id>
redemption_requested:<request_id>
level_up:<child_id>:<level>
birthday:<child_id>:<year>
```

## 9. Falhas

- push falhou: manter notificação interna;
- token inválido: desativar;
- provedor indisponível: retry com backoff;
- sessão revogada: deep link abre login, sem mostrar conteúdo;
- item removido: abrir destino seguro com mensagem “Este item não está mais disponível”.

## 10. Permissão

- não pedir push na primeira frame;
- explicar o benefício no onboarding;
- responsável autoriza notificações familiares;
- criança pequena não deve tomar decisão jurídica de consentimento;
- fornecer instrução para reativar nas configurações do sistema.

