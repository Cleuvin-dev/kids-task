# 02 — Escopo do MVP e Planos

## 1. Escopo funcional do MVP

O MVP inclui:

- cadastro e autenticação do responsável;
- criação da família;
- convite de outros responsáveis por e-mail/deep link;
- cadastro de crianças;
- código familiar e acesso infantil com PIN opcional;
- autorização e revogação de aparelhos infantis;
- rotinas recorrentes e tarefas pontuais;
- tarefas bônus, sem horário e com prazo;
- política de vencimento escolhida por tarefa;
- aprovação automática ou manual;
- justificativa de recusa e reenvio;
- KidsCoins, histórico e ajustes manuais auditados;
- recompensas livres e pedidos de resgate;
- XP, níveis, desbloqueios e bônus de nível;
- streak configurável;
- bônus anual de aniversário;
- temas por criança;
- notificações para todos os eventos confirmados;
- relatórios básicos e Premium;
- assinatura Premium;
- painel administrativo Web;
- exclusão de conta e dados com fluxo de dupla autorização.

## 2. Matriz de planos

| Recurso | Gratuito | Premium |
|---|---:|---:|
| Responsáveis por família | Vários | Vários |
| Crianças ativas | 1 | Ilimitadas dentro de limites técnicos de uso justo |
| Ocorrências programadas por dia | Até 3 | Ilimitadas dentro de limites técnicos de uso justo |
| Tarefas recorrentes e pontuais | Sim | Sim |
| Aprovação automática/manual | Sim | Sim |
| KidsCoins e recompensas | Sim | Sim |
| XP, níveis e streak | Sim | Sim |
| Temas | Infantil Padrão + Mundo dos Blocos | Todos os temas publicados |
| Solicitação de novo tema | Não | Sim, sujeita a curadoria e licenças |
| Relatórios | Semana atual e resumo básico | Semanal, mensal, tendências e exportações futuras |
| Criança com foto opcional | Sim | Sim |
| Anúncios | Não | Não |

O preço Premium permanece **a definir**. A interface deve ler preço e período diretamente das lojas.

## 3. Regra das três tarefas

O limite gratuito é de **três ocorrências de tarefa por criança por data local da família**.

Exemplos:

- Uma tarefa recorrente para segunda, quarta e sexta conta uma vez em cada data em que aparece.
- Três tarefas recorrentes na segunda ocupam todo o limite de segunda.
- Uma tarefa pontual adicionada a uma segunda que já possui três ocorrências deve ser bloqueada ou substituir/desativar outra.
- Tarefas bônus também contam no dia em que forem programadas.
- Tarefas desativadas e ocorrências canceladas não contam.

O limite deve ser validado no backend. A interface antecipa o aviso, mas não é a autoridade.

## 4. Limite de criança

No plano gratuito:

- somente uma criança pode estar ativa;
- é permitido convidar mais de um responsável;
- a tentativa de cadastrar uma segunda criança abre a apresentação do Premium;
- não apagar perfis existentes em caso de perda do Premium.

## 5. Downgrade do Premium

Quando o Premium expirar:

1. Nenhuma criança, tarefa, histórico ou saldo é apagado.
2. A família escolhe uma criança principal para permanecer ativa no plano gratuito.
3. Se não escolher, o sistema mantém temporariamente a primeira criança criada e solicita confirmação.
4. A partir do dia seguinte, no máximo três ocorrências ficam ativas por dia.
5. Ocorrências excedentes são pausadas, nunca excluídas.
6. Tema Premium volta para o último tema gratuito usado ou para Tema Infantil Padrão.
7. Pedidos de recompensa e aprovações já existentes continuam acessíveis.
8. Ao reativar o Premium, configurações pausadas podem ser restauradas.

O estado da assinatura deve contemplar ativo, período de carência, cobrança pendente, cancelado e expirado.

## 6. Regras de paywall

- O paywall só pode ser aberto pelo responsável.
- No ambiente infantil, um recurso Premium bloqueado mostra mensagem neutra: “Peça ajuda ao seu responsável”.
- Preço, moeda, período e ofertas vêm da loja.
- Deve existir ação “Restaurar compras”.
- A compra só libera o plano após validação confiável do entitlement.
- Falhas de loja não podem bloquear as funções gratuitas.

## 7. Temas Premium solicitados

“Solicitar tema” significa enviar uma sugestão à curadoria da plataforma. Não significa criação automática ou garantia de publicação.

Solicitações que usem marca, personagem ou identidade protegida devem:

- ser recusadas ou convertidas em proposta original;
- nunca resultar em cópia visual;
- ficar visíveis apenas à equipe autorizada.

## 8. Publicidade

O MVP não terá publicidade. A monetização será baseada em assinatura, reduzindo coleta de dados e riscos em uma aplicação infantil.

