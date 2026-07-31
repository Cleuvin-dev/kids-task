# 07 — Telas e Fluxos

## 1. Diretriz de navegação

O aplicativo tem uma entrada visual comum e dois shells internos independentes. Após a autorização, o usuário não escolhe manualmente qual shell abrir.

## 2. Entrada comum

### Splash

- logotipo Kid's Task;
- restauração de sessão;
- carregamento mínimo de configuração;
- redirecionamento por perfil;
- estado de erro com tentar novamente.

### Acesso

- identidade visual neutra da marca;
- botão “Sou responsável”;
- botão “Sou criança”;
- link de privacidade e ajuda;
- nenhuma informação familiar antes da validação.

### Acesso do responsável

- e-mail;
- senha;
- entrar;
- criar conta;
- esqueci minha senha;
- abrir convite pendente por deep link.

### Acesso da criança

- código da família;
- seleção segura de perfil/avatares após validação;
- PIN quando habilitado;
- caminho de pareamento por responsável quando não houver PIN;
- erros genéricos e apropriados à idade.

## 3. Onboarding do responsável

Etapas:

1. Criar/confirmar conta.
2. Aceitar termos e consentimento de tratamento infantil.
3. Nomear família e confirmar fuso.
4. Cadastrar primeira criança:
   - nome;
   - apelido opcional;
   - data de nascimento;
   - avatar;
   - foto opcional;
   - PIN opcional.
5. Escolher tema da criança.
6. Escolher regra de streak.
7. Configurar bônus de nível e aniversário.
8. Criar até três tarefas sugeridas.
9. Mostrar código familiar e opção de parear aparelho.
10. Solicitar notificações.

Deve ser possível sair e continuar sem perder etapas concluídas.

## 4. Shell do responsável

Navegação principal recomendada:

- **Início**
- **Tarefas**
- **Aprovações**
- **Recompensas**
- **Mais**

O seletor de criança permanece acessível no topo das telas aplicáveis.

### 4.1 Início

- saudação;
- criança selecionada;
- progresso do dia;
- tarefas pendentes, concluídas, atrasadas e expiradas;
- próxima tarefa;
- aprovações pendentes;
- pedidos de resgate;
- KidsCoins, XP, nível e streak;
- atalho “Adicionar tarefa”;
- banner Premium somente quando contextual.

### 4.2 Crianças

- lista de crianças;
- estado ativo/pausado pelo plano;
- adicionar criança;
- editar perfil;
- avatar/foto;
- idade e próximo aniversário;
- tema;
- PIN;
- aparelhos autorizados;
- regra de streak;
- bônus;
- exclusão individual protegida.

### 4.3 Tarefas

- calendário e lista;
- filtros por criança, período e estado;
- tabs Manhã, Tarde/Noite e Qualquer horário;
- tarefas bônus;
- criar, duplicar, editar, reordenar, pausar e arquivar;
- aviso visual do limite gratuito;
- visualização de conflitos antes de salvar.

### 4.4 Formulário de tarefa

- título e ícone;
- descrição opcional;
- criança;
- obrigatória ou bônus;
- recorrente ou data única;
- dias;
- período/horário/prazo;
- KidsCoins;
- aprovação automática/manual;
- permitir atraso ou expirar;
- resumo legível antes de salvar.

### 4.5 Aprovações

Duas filas:

- conclusões de tarefa;
- pedidos de recompensa.

Cada item exibe:

- criança;
- ação;
- data/hora;
- valor;
- prazo original;
- aprovar;
- rejeitar com motivo;
- histórico.

### 4.6 Recompensas

- catálogo por criança;
- criar e editar;
- ativar/desativar;
- custo;
- solicitações pendentes;
- aprovadas;
- entregues;
- carteira e ajustes manuais.

### 4.7 Progresso e relatórios

Gratuito:

- semana atual;
- concluídas x não concluídas;
- streak atual;
- saldo e movimentos recentes.

Premium:

- períodos maiores;
- comparação da criança com o próprio histórico;
- distribuição por período/categoria;
- tempo médio de aprovação;
- tendências;
- futura exportação.

### 4.8 Mais

- família e responsáveis;
- convites;
- aparência azul/rosa;
- notificações;
- assinatura;
- privacidade e consentimentos;
- suporte;
- sair;
- solicitar exclusão familiar.

## 5. Shell infantil

Navegação recomendada:

- **Hoje**
- **Progresso**
- **Recompensas**
- **Meu perfil**

Para 2–7 anos, usar ícones grandes com rótulos curtos.

### 5.1 Hoje

Topo:

- avatar;
- primeiro nome ou apelido;
- saldo KidsCoin;
- nível/XP.

Conteúdo:

- período atual destacado;
- cards grandes de tarefas;
- estados pendente, aguardando, concluída, correção, atrasada e expirada;
- próxima tarefa;
- acesso aos outros períodos do dia;
- celebração apenas quando a recompensa foi realmente concedida.

### 5.2 Detalhe da tarefa

- ícone;
- título;
- descrição;
- horário/prazo;
- recompensa em KidsCoins;
- aviso se precisa de aprovação;
- botão “Concluir”;
- confirmação adequada à idade;
- mensagem “Enviado para seu responsável” no modo manual.

Não haverá upload de foto no MVP.

### 5.3 Progresso

- nível;
- barra de XP;
- streak;
- recorde pessoal;
- medalhas;
- próximos desbloqueios;
- histórico simples de KidsCoins;
- sem ranking.

### 5.4 Recompensas

- catálogo da família;
- custo e saldo;
- solicitar;
- estado pendente/aprovado/rejeitado/entregue;
- motivo de recusa em linguagem respeitosa;
- recurso bloqueado por Premium sem tela de compra.

### 5.5 Meu perfil

- avatar/foto;
- nome ou apelido;
- idade atual;
- dias até o aniversário;
- tema aplicado;
- itens desbloqueados;
- som e redução de animação;
- ajuda;
- sair atrás de barreira parental.

## 6. Estados obrigatórios

Toda tela que carrega dados deve possuir:

- carregando;
- vazia;
- conteúdo;
- erro recuperável;
- sem conexão;
- acesso revogado;
- recurso bloqueado pelo plano, quando aplicável.

Como o MVP não é offline, uma ação de escrita sem internet:

- não é enfileirada;
- não aparenta sucesso;
- mantém os dados digitados localmente enquanto a tela estiver aberta, quando seguro;
- oferece “Tentar novamente”.

## 7. Feedback

| Evento | Feedback |
|---|---|
| Tarefa automática aprovada | animação, som opcional, saldo atualizado |
| Tarefa enviada para aprovação | animação curta neutra, sem moeda voando |
| Tarefa rejeitada | mensagem de correção, sem linguagem punitiva |
| Resgate solicitado | confirmação e estado pendente |
| Nível alcançado | celebração + itens liberados + bônus |
| Sem conexão | aviso claro, sem perder contexto |

## 8. Barreira parental

A barreira é obrigatória antes de:

- compra ou restauração de assinatura;
- link externo;
- sair do perfil infantil;
- alterar conta;
- trocar de criança;
- solicitar suporte externo;
- permissões sensíveis;
- abrir termos em navegador.

Pode usar desafio adulto simples, reautenticação ou confirmação em aparelho responsável. Não usar uma pergunta cuja resposta esteja visível na própria tela.

## 9. Deep links

Rotas aceitas:

- convite de responsável;
- tarefa aguardando aprovação;
- pedido de recompensa;
- tela de assinatura;
- suporte;
- solicitação de exclusão.

Cada rota revalida sessão e autorização antes de abrir. Deep link nunca concede acesso por si só.

