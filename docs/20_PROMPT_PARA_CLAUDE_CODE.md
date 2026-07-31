# 20 — Prompt para Claude Code

Copie o texto abaixo e envie ao Claude Code com esta pasta disponível na raiz do projeto.

---

Você atuará como líder técnico e implementador do MVP do **Kid's Task**.

## Fonte de verdade

Antes de alterar qualquer código:

1. Leia integralmente `README.md`, `CLAUDE.md` e todos os arquivos de `docs/`.
2. Trate esses documentos como requisitos normativos.
3. Se existir repositório, inspecione sua estrutura, `git status`, instruções locais, dependências, migrations e testes. Preserve todo trabalho existente.
4. Se o repositório estiver vazio, crie a estrutura recomendada.
5. Crie/atualize `docs/IMPLEMENTATION_STATUS.md` com o que existe, o que falta e qual marco está em execução.

Não pare apenas na análise: depois da inspeção, implemente o próximo marco incompleto de forma funcional e testada. Avance pelos marcos enquanto houver contexto e segurança para continuar.

## Produto obrigatório

- Um único aplicativo Flutter, publicado para Android e iOS.
- A tela de acesso é comum.
- Responsável entra com e-mail/senha.
- Criança entra com código familiar, seleção do perfil e PIN opcional.
- Criança sem PIN exige aparelho previamente autorizado pelo responsável.
- O backend identifica o papel e abre o ambiente correto.
- Não deve existir forma de uma sessão infantil abrir o painel do responsável alterando apenas rota/estado local.
- Painel administrativo Web separado, exclusivo da equipe Kid's Task.
- Backend em Supabase.
- Push com Firebase Cloud Messaging e APNs no iOS.
- MVP online: não enfileirar conclusões offline.
- Mercado inicial Brasil/pt-BR.

## Plano gratuito e Premium

Gratuito:

- vários responsáveis;
- uma criança ativa;
- até três ocorrências por dia;
- Tema Infantil Padrão;
- Mundo dos Blocos;
- relatórios básicos;
- sem anúncios.

Premium:

- crianças e tarefas ilimitadas dentro de limites técnicos;
- todos os temas publicados;
- relatórios avançados;
- solicitação de tema;
- todos os recursos liberados.

Preço ainda será definido. Obtenha preço da App Store/Google Play e nunca o fixe no código. A compra só libera entitlement após validação confiável no backend. Implemente restauração e downgrade sem apagar dados.

## Regras críticas

- Moeda: KidsCoin.
- XP separado e não gastável.
- Bônus de nível e aniversário configuráveis.
- Sugestões iniciais: 5 KidsCoins por nível e 50 no aniversário.
- Tarefas aprovadas concedem XP; baseline 10 XP.
- Responsável configura KidsCoins por tarefa.
- Aprovação automática ou manual por tarefa.
- Rejeição tem motivo e permite correção.
- Atraso segue `allow_late` ou `expire_no_reward`.
- Tarefa perdida não retira saldo.
- Toda recompensa solicitada exige aprovação.
- Resgate desconta apenas na aprovação.
- Sem saldo negativo.
- Sem ranking entre irmãos.
- Tema infantil só é escolhido pelo responsável.
- Área do responsável: azul padrão ou rosa manual, sem relação com gênero.
- Não coletar gênero.
- Avatar padrão; foto opcional e privada.
- Sem prova por foto no MVP.
- Exclusão familiar requer outro responsável quando houver.

## Arquitetura esperada

Use monorepo:

```text
apps/mobile
apps/admin_web
packages/domain
packages/data_access
packages/design_system
supabase/migrations
supabase/functions
supabase/tests
docs
```

Use arquitetura por features e camadas. Riverpod e `go_router` são recomendados. Fixe versões estáveis compatíveis no lockfile.

Para criança, implemente sessão técnica limitada por aparelho:

1. autenticação anônima do Supabase;
2. Edge Function valida código/PIN ou pareamento;
3. cria `child_device_binding`;
4. RLS restringe a `child_id`;
5. responsável pode revogar.

Não crie e-mail fictício infantil nem derive senha do PIN.

## Banco e backend

- Toda tabela exposta tem RLS.
- Crie migrations versionadas.
- Nunca aplique regra apenas no banco de produção.
- `service_role` e secrets nunca entram no app.
- KidsCoins e XP usam ledgers append-only.
- Saldos, aprovações, resgates, níveis e aniversário são atômicos e idempotentes.
- Use snapshots nas ocorrências.
- Use outbox para push/eventos.
- Use fuso da família e timestamps UTC.
- Dinheiro simbólico em centavos inteiros.
- Implemente constraints e testes negativos de RLS.

## Ordem de implementação

Siga `docs/16_BACKLOG_E_ROADMAP.md`:

1. fundação;
2. autenticação/família;
3. tarefas/aprovações;
4. KidsCoins/recompensas;
5. XP/streak/aniversário;
6. temas/faixas etárias;
7. notificações;
8. Premium/painel Web;
9. privacidade/hardening/release.

Não construa telas falsas desconectadas do backend como se estivessem concluídas. Placeholders são permitidos apenas para assets visuais ainda pendentes.

## Segurança e conteúdo infantil

- Aplicar menor privilégio, rate limit e proteção contra enumeração.
- Hash para PIN, código e convite.
- Foto em bucket privado, removendo EXIF.
- Push sem nome completo, data de nascimento, saldo detalhado ou motivo livre.
- Sem SDK de anúncios.
- Compra, link externo, troca de perfil e saída infantil atrás de barreira parental.
- Não usar Roblox, Minecraft, Barbie, Homem-Aranha/Spider-Man ou qualquer asset protegido sem licença.
- Os temas devem ser originais.
- Registrar consentimentos e disponibilizar exclusão dentro do app.

## Qualidade

Para cada marco:

1. migrations;
2. backend/RLS;
3. UI completa com loading, vazio, erro e sem conexão;
4. testes;
5. formatação/análise;
6. atualização de `docs/IMPLEMENTATION_STATUS.md`.

Execute e registre os resultados dos comandos aplicáveis:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
supabase db lint
supabase test db
```

Crie testes com duas famílias, múltiplos responsáveis, duas crianças e perfis de plataforma para provar isolamento.

## Regras de trabalho

- Não apagar nem sobrescrever alterações do usuário.
- Não usar comandos destrutivos.
- Não inventar credenciais.
- Documentar variáveis necessárias em `.env.example`.
- Não declarar sucesso com teste falhando.
- Quando uma pendência depender de conta externa, implemente a interface/adapter, documente exatamente o bloqueio e continue no que for independente.
- Atualize a documentação se uma decisão técnica precisar ser refinada, sem mudar regra de produto silenciosamente.

## Entrega esperada a cada ciclo

Informe:

- resultado funcional alcançado;
- arquivos e migrations principais;
- testes executados e resultado;
- como executar localmente;
- riscos ou bloqueios reais;
- próximo marco recomendado;
- status atualizado da documentação.

Comece agora pela leitura e auditoria do repositório; em seguida, implemente o Marco 0 ou continue do primeiro marco incompleto identificado.

---

