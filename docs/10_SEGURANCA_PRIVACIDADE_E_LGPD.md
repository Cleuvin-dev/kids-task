# 10 — Segurança, Privacidade e LGPD

## 1. Aviso

Este documento define requisitos técnicos e de produto, mas não substitui revisão jurídica antes do lançamento. Como o serviço trata dados de crianças e adolescentes no Brasil, a avaliação deve considerar LGPD, ECA Digital, regras das lojas e o melhor interesse da criança.

## 2. Princípios

- melhor interesse da criança;
- minimização;
- finalidade clara;
- transparência em linguagem simples;
- supervisão parental;
- segurança por padrão;
- retenção limitada;
- ausência de publicidade comportamental;
- nenhuma venda de dados;
- nenhum ranking público;
- nenhuma permissão infantil para compra ou link externo.

## 3. Dados coletados

### Responsável

- nome;
- e-mail;
- credencial administrada pelo provedor de autenticação;
- vínculo familiar;
- preferências;
- assinatura;
- registros de consentimento e auditoria.

### Criança

- nome;
- apelido opcional;
- data de nascimento;
- avatar;
- foto opcional;
- PIN em hash, quando usado;
- tarefas, conclusões e progresso;
- KidsCoins, XP, nível, streak e recompensas;
- aparelhos autorizados.

### Não coletar

- gênero;
- localização;
- contatos;
- biometria;
- escola;
- chat;
- publicidade;
- dados bancários da criança;
- foto como prova no MVP.

## 4. Consentimento e transparência

Antes de criar a primeira criança:

1. identificar o controlador e contato de privacidade;
2. explicar dados, finalidades, retenção e terceiros;
3. obter consentimento específico e destacado quando aplicável;
4. registrar versão do texto e timestamp;
5. permitir consulta e revogação;
6. mostrar uma explicação infantil curta no ambiente da criança.

Consentimento não deve ser agrupado com marketing. Push opcional tem escolha separada.

## 5. Data de nascimento

É necessária para:

- faixa de apresentação;
- idade;
- contagem até aniversário;
- bônus anual.

Proteções:

- nunca exibir publicamente;
- não enviar em push;
- não usar para publicidade;
- limitar acesso no painel;
- registrar apenas `date`, sem horário;
- explicar ao responsável por que é necessária.

## 6. Foto

- avatar é o padrão.
- foto real é opcional e controlada pelo responsável.
- bucket privado.
- acesso apenas à família e suporte autorizado quando indispensável.
- remover metadados EXIF no upload.
- validar tipo e tamanho.
- permitir remover sem apagar o perfil.
- nunca usar em treinamento, reconhecimento facial ou publicidade.

## 7. Autorização

### Responsável

RLS exige vínculo ativo com a família.

### Criança

RLS exige vínculo ativo entre `auth.uid()` técnico, aparelho e `child_id`.

### Administrador

- conta separada;
- MFA obrigatório;
- menor privilégio;
- acesso por função;
- trilha de auditoria;
- sem impersonação silenciosa.

## 8. Segredos

- chaves de serviço somente em backend.
- publishable key pode estar no cliente com RLS correta.
- PIN, tokens de convite e código familiar em digest seguro.
- credenciais de FCM, APNs e lojas em secrets.
- nunca registrar segredo em log.
- rotação documentada.

## 9. Proteções de API

- rate limit em login, convites, resgates e ações críticas;
- idempotência;
- validação de payload;
- autorização dentro da função;
- proteção contra enumeração;
- limites de upload;
- CORS restrito no painel;
- cabeçalhos seguros;
- reautenticação para ações destrutivas;
- logs com request ID e dados reduzidos.

## 10. Exclusão da família

### Com mais de um responsável

1. Um responsável solicita a exclusão.
2. Outro responsável ativo recebe push e e-mail.
3. Ele aprova ou rejeita.
4. Rejeição encerra o pedido.
5. Aprovação agenda a exclusão, com período de segurança sugerido de sete dias.
6. Durante o período, qualquer responsável pode cancelar.
7. Na execução, sessões e aparelhos são revogados.
8. Dados são apagados ou anonimizados conforme obrigação legal.
9. Responsáveis recebem confirmação.

### Com um único responsável

- reautenticação;
- confirmação explícita;
- período de segurança;
- aviso de irreversibilidade.

### Exceções legais

A regra de dupla aprovação é uma proteção familiar, mas não pode bloquear indefinidamente um direito legal válido. Conflitos, disputa de tutela ou pedido formal de titular devem ser encaminhados ao processo de privacidade e revisão jurídica.

## 11. Exclusão de uma criança

- reautenticação;
- aviso sobre histórico, saldo e recompensas;
- revogar aparelhos;
- período de segurança;
- cancelar ocorrências futuras;
- apagar/anonimizar dados após o prazo;
- manter apenas registros legalmente necessários.

## 12. Direitos de privacidade

Área do responsável deve permitir:

- ver dados cadastrados;
- corrigir;
- solicitar exportação;
- retirar foto;
- revogar aparelhos;
- consultar consentimentos;
- solicitar exclusão;
- acessar canal de privacidade.

## 13. Retenção sugerida

Os prazos finais dependem de validação jurídica.

| Dado | Diretriz |
|---|---|
| Convite não aceito | remover após expiração + janela curta de segurança |
| Tentativas de login | retenção curta para antifraude |
| Push token inválido | remover rapidamente |
| Dados da família ativa | enquanto necessários ao serviço |
| Conta em exclusão | período de segurança e então apagar/anonimizar |
| Auditoria crítica | prazo definido por obrigação e risco |
| Anexos de suporte | remover ao encerrar finalidade |

## 14. Incidentes

Plano mínimo:

1. detectar e conter;
2. preservar evidências;
3. avaliar dados e titulares afetados;
4. revogar chaves/sessões;
5. corrigir causa;
6. seguir obrigações de comunicação;
7. registrar decisões;
8. revisar controles.

Incidente envolvendo crianças recebe prioridade máxima.

## 15. Lojas e categoria infantil

Antes de publicar:

- declarar corretamente o público-alvo;
- revisar Google Play Families;
- revisar Kids Category e parental gates da Apple, se utilizada;
- garantir ausência de SDK de anúncios;
- revisar todos os SDKs e dados transmitidos;
- preencher Data Safety e Privacy Nutrition Labels com precisão;
- manter compras e links atrás de barreira parental;
- revisar política de privacidade dentro e fora do app.

## 16. Checklist de segurança para release

- [ ] RLS ativada e testada em todas as tabelas expostas
- [ ] teste de isolamento entre duas famílias
- [ ] criança impedida de acessar dados de responsável
- [ ] `service_role` ausente do app
- [ ] PIN/código/token nunca em texto puro
- [ ] MFA de administradores
- [ ] storage privado para fotos
- [ ] EXIF removido
- [ ] logs sem dados infantis desnecessários
- [ ] exclusão disponível no app
- [ ] consentimentos versionados
- [ ] deep links revalidam autorização
- [ ] push sem dados sensíveis
- [ ] dependências e SDKs inventariados
- [ ] análise jurídica pré-lançamento

