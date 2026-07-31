# 15 — Critérios de Aceite e Testes

## 1. Estratégia

| Camada | Cobertura |
|---|---|
| Unitários | regras de data, plano, XP, streak, estados |
| Widget | telas e estados |
| Integração Flutter | onboarding e fluxos críticos |
| Banco | funções, constraints, idempotência |
| RLS | matriz completa de papéis |
| Edge Functions | validação, autorização e webhooks |
| E2E | responsável ↔ criança em aparelhos distintos |
| Segurança | enumeração, rate limit, acesso cruzado |
| Lojas | sandbox/test tracks |

## 2. Aplicativo único e autorização

- [ ] Login do responsável abre somente o shell do responsável.
- [ ] Login infantil abre somente o shell infantil.
- [ ] Alterar rota local não abre tela adulta.
- [ ] Sessão infantil não lê outra criança.
- [ ] Uma família não lê dados de outra.
- [ ] Deep link exige sessão e vínculo corretos.
- [ ] Revogar aparelho encerra o acesso infantil.
- [ ] Criança sem PIN só entra em aparelho autorizado.

## 3. Família

- [ ] Primeiro responsável cria família.
- [ ] Convite por e-mail abre o app.
- [ ] Token expirado, cancelado ou reutilizado falha.
- [ ] Segundo responsável acessa as mesmas crianças.
- [ ] Remoção de responsável é auditada.
- [ ] Código regenerado invalida o anterior.

## 4. Plano gratuito

### Cenário: limite diário

```gherkin
Dado uma família gratuita com uma criança
E três ocorrências ativas na mesma data
Quando o responsável tenta ativar uma quarta
Então o backend rejeita com PLAN_DAILY_TASK_LIMIT
E nenhuma ocorrência existente é apagada
E o paywall aparece somente ao responsável
```

### Cenário: tarefa recorrente

```gherkin
Dado uma tarefa recorrente às segundas
Quando ela é ativada
Então conta uma ocorrência em cada segunda
E não conta nos outros dias
```

- [ ] Segunda criança é bloqueada no gratuito.
- [ ] Dois temas gratuitos permanecem disponíveis.
- [ ] Criança não visualiza compra.

## 5. Tarefas

- [ ] Todos os cinco tipos de agenda funcionam.
- [ ] Períodos e ordenação sincronizam.
- [ ] Pausar impede novas ocorrências.
- [ ] Editar não muda histórico.
- [ ] `allow_late` permite conclusão e recompensa.
- [ ] `expire_no_reward` impede conclusão.
- [ ] Envio antes do prazo pode ser aprovado depois.
- [ ] Tarefa perdida não desconta KidsCoins/XP.
- [ ] Bônus não prejudica streak.

## 6. Aprovação e idempotência

### Automática

- [ ] conclusão credita coin e XP uma vez;
- [ ] duplo toque não duplica;
- [ ] retry não duplica;
- [ ] saldo e UI retornam consistentes.

### Manual

- [ ] envio não credita antecipadamente;
- [ ] responsável aprova e concede uma vez;
- [ ] rejeição exige motivo;
- [ ] criança vê correção e reenvia;
- [ ] dois responsáveis aprovando simultaneamente não duplicam.

## 7. KidsCoins e recompensas

- [ ] ledger é append-only.
- [ ] saldo nunca negativo.
- [ ] ajuste manual exige motivo.
- [ ] resgate pendente não debita.
- [ ] aprovação debita uma vez.
- [ ] saldo insuficiente impede aprovação.
- [ ] rejeição não debita.
- [ ] entrega não debita novamente.
- [ ] cancelamento aprovado gera estorno.

## 8. XP, nível e aniversário

- [ ] XP não pode ser gasto.
- [ ] cruzar nível concede bônus.
- [ ] cruzar vários níveis concede todos.
- [ ] retry não duplica bônus.
- [ ] unlock exige nível e plano.
- [ ] aniversário concede uma vez por ano.
- [ ] 29/02 segue regra definida.
- [ ] idade e contagem de dias são corretas no fuso.

## 9. Streak

- [ ] `at_least_one` calcula corretamente.
- [ ] `all_required` calcula corretamente.
- [ ] percentual respeita configuração.
- [ ] dia neutro não quebra nem aumenta.
- [ ] ocorrência dispensada sai do denominador.
- [ ] aprovação tardia usa data da execução.
- [ ] mudança de regra não corrompe histórico.

## 10. Temas

- [ ] responsável alterna azul/rosa.
- [ ] escolha não depende de gênero.
- [ ] cada criança mantém tema próprio.
- [ ] criança não altera tema.
- [ ] fallback funciona com asset ausente.
- [ ] downgrade troca tema sem quebrar a tela.
- [ ] nenhum asset protegido sem licença.
- [ ] reduzir movimento e silenciar funcionam.

## 11. Notificações

- [ ] todos os eventos da matriz possuem teste.
- [ ] evento duplicado não gera push duplicado.
- [ ] lock screen não mostra dado sensível.
- [ ] token inválido é removido.
- [ ] quiet hours funcionam.
- [ ] deep link revalida autorização.

## 12. Assinatura

- [ ] preço vem da loja.
- [ ] callback local sem validação não libera Premium definitivo.
- [ ] restaurar compras funciona.
- [ ] webhooks duplicados são idempotentes.
- [ ] eventos fora de ordem não regridem estado incorretamente.
- [ ] downgrade preserva dados.
- [ ] carência mantém acesso conforme loja.

## 13. Exclusão

- [ ] com dois responsáveis, segundo recebe pedido.
- [ ] recusa impede exclusão.
- [ ] aprovação agenda.
- [ ] cancelamento no prazo funciona.
- [ ] sessão/aparelhos são revogados na execução.
- [ ] único responsável passa por confirmação reforçada.
- [ ] dados são apagados/anonimizados conforme matriz.

## 14. Painel Web

- [ ] MFA obrigatório.
- [ ] cada papel só vê seu módulo.
- [ ] toda mutação cria auditoria.
- [ ] PIN/códigos/tokens nunca aparecem.
- [ ] tema é publicado por versão.
- [ ] override de assinatura expira.
- [ ] métricas agregadas não expõem criança.

## 15. Não funcional

- [ ] carregamento, vazio, erro e sem conexão em todas as telas.
- [ ] escrita sem internet não aparenta sucesso.
- [ ] acessibilidade básica.
- [ ] pt-BR revisado.
- [ ] primeira tela interativa em tempo aceitável nos aparelhos-alvo.
- [ ] listas paginadas.
- [ ] imagens otimizadas.
- [ ] sem segredo no bundle.
- [ ] migrations reproduzem banco vazio.
- [ ] backup e restauração testados antes de produção.

## 16. RLS obrigatória

Criar fixtures com:

- Família A: responsável A1, A2 e criança A.
- Família B: responsável B1 e criança B.
- Admin support.
- Admin content.

Testar `select`, `insert`, `update`, `delete` em cada tabela para cada papel. Um teste negativo é tão obrigatório quanto o positivo.

## 17. Release móvel

- [ ] Android em track interno/fechado.
- [ ] iOS em TestFlight.
- [ ] compra sandbox.
- [ ] push Android e iOS.
- [ ] universal links/app links.
- [ ] exclusão dentro do app.
- [ ] Data Safety/Privacy Labels revisados.
- [ ] categoria etária e público revisados.
- [ ] barreira parental validada.

