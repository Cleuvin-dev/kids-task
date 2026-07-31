# Instruções obrigatórias para implementação

Este arquivo é normativo para qualquer agente ou desenvolvedor que trabalhe no Kid's Task.

## 1. Fonte de verdade

1. Os documentos desta pasta são a fonte de verdade do produto.
2. Em caso de conflito, prevalece esta ordem:
   - `README.md`;
   - `CLAUDE.md`;
   - documento temático mais específico;
   - briefing histórico.
3. Não reintroduza o nome “Estrelin”, “Estrelinhas” ou a arquitetura de dois aplicativos.

## 2. Regras que não podem ser alteradas silenciosamente

- Um único aplicativo móvel Flutter deve atender responsáveis e crianças.
- O backend, e não apenas a interface, deve determinar perfil e permissões.
- O painel administrativo Web é separado do aplicativo móvel.
- O plano gratuito permite uma criança e até três ocorrências de tarefa por dia.
- O plano gratuito inclui Tema Infantil Padrão e Mundo dos Blocos.
- Não coletar gênero.
- Não implementar ranking entre irmãos.
- Não implementar conclusão offline.
- Não implementar comprovação por foto no MVP.
- Não usar nomes, personagens, logotipos ou artes de Roblox, Barbie, Homem-Aranha ou outras propriedades de terceiros sem licença.
- O aplicativo não realiza transferência bancária entre responsável e criança.
- KidsCoins não têm valor financeiro fora da família.
- Não exibir compra, link externo ou configuração administrativa no ambiente da criança sem barreira parental.

Qualquer mudança nessas regras exige registro explícito em `docs/18_PENDENCIAS_NAO_BLOQUEANTES.md` e aprovação do proprietário do produto.

## 3. Estrutura esperada do repositório

```text
kids_task/
├── apps/
│   ├── mobile/                 # Flutter Android/iOS: responsável + criança
│   └── admin_web/              # Flutter Web: administração da plataforma
├── packages/
│   ├── domain/                 # entidades, contratos e casos de uso compartilhados
│   ├── data_access/            # DTOs, clientes e repositórios
│   └── design_system/          # tokens e componentes reutilizáveis
├── supabase/
│   ├── migrations/
│   ├── functions/
│   ├── tests/
│   └── seed.sql
├── docs/
├── .env.example
└── README.md
```

É permitido ajustar a estrutura se o repositório existente já possuir convenções equivalentes. Não duplique projetos nem descarte trabalho do usuário.

## 4. Princípios técnicos

- Arquitetura por funcionalidades, com separação entre apresentação, aplicação, domínio e dados.
- Estado previsível e testável; Riverpod é a opção recomendada.
- Navegação declarativa; `go_router` é a opção recomendada.
- Dependências devem ser fixadas no lockfile e escolhidas em versões estáveis compatíveis no momento da implementação.
- Valores de plano, XP, bônus, limites e temas não devem ficar espalhados ou fixados na interface.
- Datas operacionais usam o fuso da família; timestamps são persistidos em UTC.
- Dinheiro simbólico usa centavos inteiros, nunca `double`.
- Saldos são alterados apenas por operações atômicas e lançamentos imutáveis.
- Toda ação crítica deve aceitar chave de idempotência.
- Toda tabela exposta deve ter RLS habilitada e testada.
- Chaves secretas e `service_role` jamais entram no aplicativo.
- Toda regra SQL, função e política deve existir em migration versionada. Não criar lógica apenas no banco de produção.
- Ambientes de desenvolvimento, homologação e produção devem ser separados.

## 5. Segurança infantil

- O acesso do responsável usa Supabase Auth.
- O acesso infantil usa uma sessão autenticada limitada e vinculada ao aparelho.
- PINs são opcionais, mas nunca podem ser armazenados em texto puro.
- Criança sem PIN só entra em aparelho autorizado por um responsável.
- Não enumerar famílias ou crianças a partir de tentativas de código.
- Aplicar limite de tentativas, atraso progressivo e auditoria no login infantil.
- Fotos e avatares personalizados ficam em armazenamento privado.
- Push não deve carregar nome completo, data de nascimento ou outro dado sensível.
- Não incluir SDK de anúncios.
- Evitar analytics de terceiros no ambiente infantil.

## 6. Fluxo de desenvolvimento

Para cada etapa:

1. Ler o documento temático correspondente.
2. Registrar o plano curto da etapa.
3. Criar ou atualizar migrations primeiro quando houver mudança de dados.
4. Implementar backend e políticas.
5. Implementar interface e estados de erro/carregamento/vazio.
6. Criar testes.
7. Executar formatação, análise estática e testes.
8. Atualizar `docs/IMPLEMENTATION_STATUS.md`.
9. Não declarar a etapa concluída com testes falhando ou sem verificar RLS.

## 7. Comandos de qualidade esperados

Adapte à estrutura real do repositório:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
supabase db lint
supabase test db
```

O CI deve bloquear merge se análise, testes ou validação de migrations falharem.

## 8. Definição de pronto

Uma funcionalidade só está pronta quando:

- regra de negócio e permissões funcionam no backend;
- a UI trata carregamento, vazio, sucesso e erro;
- há teste automatizado proporcional ao risco;
- eventos críticos são auditáveis;
- não há segredo no repositório;
- o comportamento foi verificado nos dois perfis;
- documentação e status foram atualizados;
- acessibilidade básica e textos em pt-BR foram conferidos.

