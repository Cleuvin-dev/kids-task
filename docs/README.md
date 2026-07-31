# Kid's Task — Documentação do Produto e do MVP

**Versão:** 1.0

**Data de consolidação:** 30/07/2026

**Status:** requisitos de produto consolidados e prontos para implementação

**Mercado inicial:** Brasil, em português do Brasil

**Plataformas do aplicativo:** Android e iOS

## 1. Decisão central

O Kid's Task será **um único aplicativo Flutter**, publicado uma vez na Google Play e uma vez na App Store. Após o acesso, o backend identifica o perfil e abre uma experiência completamente diferente:

- **Responsável:** administra família, crianças, tarefas, aprovações, recompensas, temas, relatórios e assinatura.
- **Criança:** vê e conclui tarefas, acompanha KidsCoins, XP, nível, sequência e solicita recompensas.

O painel administrativo da plataforma é um sistema Web separado, exclusivo para a equipe do Kid's Task. Ele não é uma segunda versão do aplicativo para consumidores.

## 2. Decisões definitivas

| Tema | Decisão |
|---|---|
| Marca | Kid's Task |
| Aplicativos móveis | Um único aplicativo Flutter com ambientes por perfil |
| Lançamento | Android e iOS |
| Painel da plataforma | Web, separado e restrito |
| Backend | Supabase: Auth, Postgres, Storage, Realtime e Edge Functions |
| Push | Firebase Cloud Messaging, incluindo configuração APNs no iOS |
| Uso sem internet | Não haverá execução offline no MVP |
| Responsáveis | Uma família pode ter vários responsáveis |
| Convite | Link enviado por e-mail e aberto diretamente no aplicativo |
| Acesso infantil | Código da família + perfil da criança + PIN opcional; sem PIN exige aparelho previamente autorizado |
| Faixas etárias | 2–7, 8–10 e 11–13+ |
| Tarefas | Recorrentes, data específica, bônus, sem horário e com prazo |
| Tarefa vencida | Responsável escolhe entre permitir atraso ou expirar sem recompensa |
| Aprovação | Configurada por tarefa; automática ou manual |
| Comprovação por foto | Fora do MVP |
| Moeda | KidsCoin |
| XP | Separado de KidsCoins |
| Ranking entre irmãos | Não haverá |
| Tema infantil | Escolhido somente pelo responsável |
| Área do responsável | Azul padrão, com rosa como alternativa manual e sem vínculo com gênero |
| Plano gratuito | Uma criança, até três ocorrências de tarefa por dia, dois temas e relatórios básicos |
| Temas gratuitos | Tema Infantil Padrão e Mundo dos Blocos |
| Premium | Tarefas e crianças ilimitadas, temas e recursos Premium |
| Preço Premium | A definir; nunca deve ser fixado no código |
| Bônus de nível | Configurável; sugestão inicial de 5 KidsCoins |
| Bônus de aniversário | Configurável; sugestão inicial de 50 KidsCoins |
| Dados de gênero | Não serão coletados |
| Foto | Avatar inicialmente; foto real opcional e privada |
| Exclusão familiar | Exige confirmação de outro responsável ativo, quando houver |
| Idioma inicial | Português do Brasil |
| País inicial | Brasil |
| Publicidade | Sem anúncios no MVP |

## 3. Ordem recomendada de leitura

1. `README.md`
2. `CLAUDE.md`
3. `docs/01_VISAO_DO_PRODUTO.md`
4. `docs/02_ESCOPO_MVP_E_PLANOS.md`
5. `docs/03_USUARIOS_FAMILIA_E_AUTENTICACAO.md`
6. `docs/04_TAREFAS_APROVACOES_E_ROTINA.md`
7. `docs/05_KIDSCOINS_RECOMPENSAS_XP_E_STREAK.md`
8. `docs/06_TEMAS_DESIGN_E_FAIXAS_ETARIAS.md`
9. `docs/07_TELAS_E_FLUXOS.md`
10. `docs/08_ARQUITETURA_TECNICA.md`
11. `docs/09_MODELO_DE_DADOS.md`
12. `docs/10_SEGURANCA_PRIVACIDADE_E_LGPD.md`
13. `docs/11_NOTIFICACOES.md`
14. `docs/12_PAINEL_ADMINISTRATIVO_WEB.md`
15. `docs/13_ASSINATURAS_E_ENTITLEMENTS.md`
16. `docs/14_APIS_FUNCOES_E_EVENTOS.md`
17. `docs/15_CRITERIOS_DE_ACEITE_E_TESTES.md`
18. `docs/16_BACKLOG_E_ROADMAP.md`
19. `docs/17_BANCO_INICIAL_DE_TAREFAS.md`
20. `docs/18_PENDENCIAS_NAO_BLOQUEANTES.md`
21. `docs/19_REFERENCIAS_OFICIAIS.md`
22. `docs/20_PROMPT_PARA_CLAUDE_CODE.md`
23. `docs/IMPLEMENTATION_STATUS.md`

## 4. Vocabulário obrigatório

Para evitar ambiguidades:

- **Responsável:** pai, mãe ou tutor vinculado à família.
- **Criança:** perfil infantil que executa as rotinas.
- **Administrador da plataforma:** integrante autorizado da equipe do Kid's Task.
- **Ocorrência de tarefa:** uma tarefa concreta programada para uma criança em determinada data.
- **KidsCoin:** moeda virtual interna usada em recompensas familiares.
- **XP:** pontuação de evolução que não pode ser gasta.
- **Entitlement:** permissão efetiva decorrente do plano da família.

O termo genérico “admin” não deve ser usado para se referir ao responsável.

## 5. Como usar este pacote

Coloque esta pasta na raiz do repositório e envie ao Claude Code o conteúdo de `docs/20_PROMPT_PARA_CLAUDE_CODE.md`. A implementação deve ocorrer por etapas, preservando migrations, testes e documentação no Git.

As decisões presentes neste pacote substituem o briefing antigo chamado “Estrelin”. O documento antigo permanece apenas como referência histórica do problema; nome, arquitetura e regras consolidadas são as descritas aqui.
