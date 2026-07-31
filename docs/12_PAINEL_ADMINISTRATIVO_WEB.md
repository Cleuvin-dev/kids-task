# 12 — Painel Administrativo Web

## 1. Finalidade

O painel é exclusivo da equipe Kid's Task. Responsáveis não usam este painel para configurar tarefas.

## 2. Papéis

| Papel | Acesso |
|---|---|
| `super_admin` | configuração geral e administração de papéis |
| `support` | suporte com dados mínimos |
| `content` | temas, assets, avatares e textos |
| `billing` | planos, produtos e assinaturas |

MFA é obrigatório. Toda ação é auditada.

## 3. Dashboard

Métricas agregadas:

- famílias totais e ativas;
- responsáveis e crianças;
- onboarding concluído;
- gratuito x Premium;
- assinaturas por estado;
- tarefas programadas/concluídas;
- volume de aprovações e resgates;
- falhas de push/jobs/webhooks;
- tickets abertos.

Por padrão, não mostrar nomes de crianças no dashboard.

## 4. Famílias e usuários

- busca por ID da família ou e-mail do responsável;
- status;
- plano;
- responsáveis vinculados;
- quantidade de crianças;
- aparelhos ativos;
- consentimentos;
- exclusão em andamento;
- bloqueio por segurança;
- histórico de ações administrativas.

Dados infantis ficam ocultos até uma ação justificada de suporte.

## 5. Assinaturas

- plano efetivo;
- loja;
- produto;
- estado;
- período e carência;
- eventos recebidos;
- falhas de validação;
- restaurar sincronização;
- override de suporte com expiração e justificativa.

O painel não altera comprovante da loja. Override não deve fingir pagamento.

## 6. Temas e conteúdo

- criar rascunho;
- upload de assets;
- validar manifest;
- pré-visualizar faixas etárias;
- definir gratuito/Premium;
- publicar versão;
- retirar sem quebrar famílias atuais;
- catálogo de avatares, ícones e cosméticos;
- fila de solicitações Premium.

Publicação exige:

- licença/proveniência dos assets;
- contraste e acessibilidade;
- fallback;
- revisão de propriedade intelectual;
- tamanho máximo.

## 7. Planos e configuração

Configurações:

- limite de crianças;
- limite diário de ocorrências;
- temas incluídos;
- XP padrão;
- níveis;
- bônus sugeridos;
- feature flags;
- IDs de produtos das lojas;
- textos do paywall.

Alterações críticas devem ser versionadas e possuir data de vigência.

## 8. Notificações

- templates;
- categorias;
- histórico de entrega;
- reprocessamento controlado;
- avisos operacionais para responsáveis;
- teste para aparelhos internos.

Não permitir campanha de marketing direcionada diretamente a crianças no MVP.

## 9. Suporte

- tickets;
- categoria e prioridade;
- anexos privados;
- timeline;
- resposta;
- encerramento;
- vínculo com incidente.

Sem impersonação. Se uma ferramenta de acesso assistido for criada futuramente, deve exigir consentimento, tempo limitado e auditoria destacada.

## 10. Segurança e auditoria

- login separado do app infantil;
- MFA;
- timeout de sessão;
- restrição por papel;
- reautenticação em ações críticas;
- auditoria append-only;
- exportação de auditoria;
- alerta para acesso em massa;
- secrets somente no servidor;
- proteção CSRF/CORS conforme arquitetura.

## 11. Bloqueios

Possíveis estados:

- ativo;
- restrito;
- bloqueado por segurança;
- exclusão pendente;
- excluído.

Bloquear uma família:

- exige motivo;
- não apaga dados;
- revoga ou restringe sessões conforme risco;
- notifica responsáveis quando apropriado;
- permite revisão e reversão auditada.

## 12. Critérios de aceite

- nenhum operador acessa módulo fora de seu papel;
- toda alteração registra quem, quando e por quê;
- busca não expõe PIN, código familiar ou token;
- dashboard funciona com dados agregados;
- publicação de tema é versionada;
- override de assinatura expira;
- operações destrutivas exigem confirmação reforçada.

