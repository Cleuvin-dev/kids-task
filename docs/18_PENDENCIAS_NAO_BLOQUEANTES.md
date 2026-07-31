# 18 — Pendências Não Bloqueantes

Estas decisões não impedem a fundação do MVP. Devem ser configuráveis e resolvidas antes da publicação.

## 1. Produto e negócio

| Item | Estado | Diretriz provisória |
|---|---|---|
| Preço Premium mensal | A definir | buscar da loja, nunca fixar na UI |
| Plano anual | A definir | deixar arquitetura preparada |
| Período de teste | A definir | sem trial por padrão |
| Países além do Brasil | Futuro | bloquear escopo inicial em pt-BR |
| Política de uso justo Premium | A definir | limites técnicos altos, não comerciais |
| SLA de solicitação de tema | A definir | comunicar que não há garantia |

## 2. Marca e design

- logotipo final;
- ícone Android/iOS;
- mascote;
- assets finais do Tema Infantil Padrão;
- assets finais do Mundo dos Blocos;
- assets dos três temas Premium iniciais;
- catálogo inicial de avatares e acessórios;
- biblioteca licenciada de sons;
- fonte da marca.

Durante o desenvolvimento, usar placeholders próprios, claramente identificados e fáceis de substituir.

## 3. Balanceamento

Valores iniciais já documentados:

- 10 XP por tarefa aprovada;
- curva de nível `50 × (L - 1) × L`;
- 5 KidsCoins por nível;
- 50 KidsCoins no aniversário;
- streak percentual padrão de 80%.

Eles são suficientes para implementar, mas devem ser avaliados em beta e permanecer configuráveis.

Também falta decidir:

- valor padrão sugerido de KidsCoins por tarefa;
- taxa simbólica KidsCoin → BRL sugerida no onboarding;
- se marcos de streak concederão bônus em fase posterior.

## 4. Operação

- domínio do painel Web;
- remetente e provedor de e-mail transacional;
- e-mail de suporte;
- contato de privacidade/encarregado;
- razão social e dados do controlador;
- horários de atendimento;
- política de moderação para solicitações de tema;
- processo de incidentes e responsável de plantão.

## 5. Lojas

- bundle IDs/package names;
- IDs finais de assinatura em produção;
- conta Apple Developer;
- conta Google Play Console;
- categoria e classificação etária finais;
- decisão sobre participação na Kids Category da Apple;
- textos e screenshots de loja;
- política de privacidade pública;
- termos da assinatura;
- detalhes de trial/ofertas.

## 6. Privacidade e jurídico

Requer revisão jurídica:

- texto de consentimento;
- bases legais por finalidade;
- prazo de retenção;
- período de segurança de exclusão, sugerido em sete dias;
- fluxo em disputa entre responsáveis;
- RIPD;
- política de privacidade;
- termos de uso;
- contratos com Supabase, Firebase, e-mail e lojas;
- ECA Digital e regras vigentes no lançamento.

## 7. Decisões técnicas de implementação

O time pode decidir, documentando em ADR:

- versões exatas do Flutter e dependências;
- provedor de e-mail;
- mecanismo de execução dos jobs;
- hospedagem do painel;
- ferramenta de feature flags;
- uso ou não de serviço externo de crash reporting após revisão de privacidade;
- estratégia de backup e região.

## 8. Decisões que não estão pendentes

Não reabrir sem solicitação do proprietário:

- um único aplicativo móvel;
- Android e iOS;
- Supabase + FCM;
- painel Web;
- uma criança no gratuito;
- três ocorrências por dia no gratuito;
- dois temas gratuitos;
- KidsCoin;
- XP separado;
- bônus configuráveis;
- múltiplos responsáveis;
- criança com código + PIN opcional;
- sem offline;
- sem ranking;
- sem gênero;
- sem prova por foto no MVP;
- sem anúncios;
- português/Brasil inicialmente.

