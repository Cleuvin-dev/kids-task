# 06 — Temas, Design e Faixas Etárias

## 1. Área do responsável

O responsável escolhe manualmente entre:

| Tema | Cor principal sugerida | Fundo sugerido |
|---|---|---|
| Azul padrão | `#2F80ED` | `#F4F8FF` |
| Rosa | `#E95D9A` | `#FFF5FA` |

A opção não depende de gênero da criança ou do responsável. Gênero não é coletado.

Os dois temas usam a mesma arquitetura de informação e os mesmos contrastes, estados e componentes.

## 2. Área infantil

Cada criança possui um tema individual:

- escolhido e aplicado pelo responsável;
- sincronizado em todos os aparelhos autorizados;
- visível, mas não alterável pela criança;
- mantido ao sair e entrar novamente;
- revertido com segurança em downgrade de plano.

Caminho:

> Crianças → selecionar criança → Personalização → Tema → visualizar → aplicar

## 3. Catálogo inicial

| Tema | Slug | Plano |
|---|---|---|
| Tema Infantil Padrão | `kids_default` | Gratuito |
| Mundo dos Blocos | `block_world` | Gratuito |
| Mundo Encantado | `enchanted_world` | Premium |
| Herói Aracnídeo | `web_hero` | Premium |
| Aventura Espacial | `space_adventure` | Premium |
| Dinossauros | `dino_adventure` | Premium/futuro |
| Princesas e Castelos | `castles_quest` | Premium/futuro |
| Carros e Corridas | `racing_world` | Premium/futuro |
| Animais da Floresta | `forest_friends` | Premium/futuro |

Os cinco primeiros formam o catálogo pretendido para lançamento; os demais podem ser publicados por configuração sem mudar a navegação.

## 4. Propriedade intelectual

Não usar:

- nome Roblox ou Minecraft no produto;
- nome Barbie;
- nome Homem-Aranha/Spider-Man;
- personagens, logotipos, roupas, teias, fontes ou composições copiadas;
- assets encontrados na internet sem licença verificável.

Os temas devem ser originais e apenas trabalhar categorias amplas: blocos, fantasia rosa, herói ágil, espaço e aventura.

Temas oficiais de marcas só podem existir mediante contrato de licenciamento.

## 5. Contrato de um tema

Um pacote de tema pode definir:

- cores semânticas;
- gradientes;
- fundo;
- ilustrações decorativas;
- estilo de cards e botões;
- conjunto de ícones;
- moldura do avatar;
- animação de conclusão;
- efeito de KidsCoin;
- trilha/efeitos sonoros;
- assets por densidade;
- versão e compatibilidade mínima.

Não pode alterar:

- posição de ações críticas;
- significado dos ícones;
- permissões;
- fluxo de aprovação;
- legibilidade;
- acessibilidade;
- regras de plano.

## 6. Tokens semânticos

O código consome tokens, e não cores soltas:

```text
color.primary
color.onPrimary
color.background
color.surface
color.onSurface
color.success
color.warning
color.error
color.coin
color.xp
radius.card
radius.button
motion.reward
sound.complete
```

Cada tema precisa de modo seguro de fallback. Asset ausente nunca pode quebrar uma tela.

## 7. Adaptação por idade

### 2–7 anos

- alvos de toque grandes;
- uma ação principal por card;
- ícones e áudio de apoio;
- pouco texto;
- confirmação clara;
- nenhuma tela financeira complexa;
- saída e links protegidos por barreira parental.

### 8–10 anos

- linguagem de missão;
- mais detalhes de progresso;
- cards ilustrados;
- explicação curta de moedas e níveis;
- autonomia com supervisão.

### 11–13+

- visual menos infantil;
- métricas pessoais;
- linguagem direta;
- estética gamer leve;
- personalização sem competição pública.

A data de nascimento define a faixa sugerida. O responsável pode ajustar o modo de apresentação sem alterar a idade registrada.

## 8. Movimento e som

- conclusão aprovada pode usar confete, som e moeda animada;
- conclusão aguardando aprovação usa feedback diferente e não simula crédito;
- respeitar “reduzir movimento” do sistema;
- oferecer opção de silenciar sons;
- evitar flashes;
- animações curtas e não bloqueantes;
- não usar padrões manipulativos de recompensa variável.

## 9. Acessibilidade

- contraste compatível com WCAG AA sempre que aplicável;
- suporte a escala de texto;
- labels semânticos;
- não depender apenas de cor;
- ícone + texto para estados;
- foco e navegação por teclado no painel Web;
- texto alternativo em ilustrações informativas;
- botões com área mínima adequada.

## 10. Solicitação Premium de tema

O formulário coleta:

- categoria desejada;
- cores;
- descrição livre;
- faixa etária;
- consentimento para análise.

Não deve solicitar foto da criança. A equipe pode transformar a ideia em tema original, colocar em fila ou rejeitar.

