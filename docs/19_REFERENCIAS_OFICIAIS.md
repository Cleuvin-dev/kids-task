# 19 — Referências Oficiais

**Verificadas em:** 30/07/2026

As políticas e bibliotecas mudam. Conferir novamente antes de cada release.

## Supabase

- [Supabase Auth](https://supabase.com/docs/guides/auth)
- [Anonymous Sign-Ins](https://supabase.com/docs/guides/auth/auth-anonymous)
- [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Securing your data](https://supabase.com/docs/guides/database/secure-data)
- [Edge Functions](https://supabase.com/docs/guides/functions)
- [Environment Variables and Secrets](https://supabase.com/docs/guides/functions/secrets)
- [Managing User Data](https://supabase.com/docs/guides/auth/managing-user-data)

## Flutter e notificações

- [Supabase with Flutter](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [Firebase Cloud Messaging for Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)
- [Receiving FCM messages in Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)
- [Flutter in_app_purchase](https://pub.dev/packages/in_app_purchase)

## Apple

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Design safe and age-appropriate experiences](https://developer.apple.com/kids/)
- [In-App Purchase](https://developer.apple.com/in-app-purchase/)
- [Auto-renewable subscriptions](https://developer.apple.com/app-store/subscriptions/)
- [Age ratings values and definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)

## Google Play

- [Google Play Families Policies](https://support.google.com/googleplay/android-developer/answer/9893335)
- [Understanding Google Play Payments policy](https://support.google.com/googleplay/android-developer/answer/10281818)
- [Google Play Billing](https://developer.android.com/google/play/billing)
- [Integrate Play Billing](https://developer.android.com/google/play/billing/integrate)
- [Subscription lifecycle](https://developer.android.com/google/play/billing/subscriptions?hl=pt-br)

## Brasil — privacidade infantil

- [Lei Geral de Proteção de Dados — Lei nº 13.709/2018](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709compilado.htm)
- [ANPD — ECA Digital](https://www.gov.br/anpd/pt-br/assuntos/eca-digital)
- [ANPD — Relatório de Impacto à Proteção de Dados Pessoais](https://www.gov.br/anpd/pt-br/canais_atendimento/agente-de-tratamento/relatorio-de-impacto-a-protecao-de-dados-pessoais-ripd)
- [ANPD — Mecanismos de aferição de idade](https://www.gov.br/anpd/pt-br/centrais-de-conteudo/documentos-tecnicos-orientativos/radar-tecnologico-5-mecanismos-de-afericao-de-idade.pdf)

## Observações aplicadas ao projeto

- RLS é obrigatória em tabelas expostas.
- Chaves secretas ficam apenas no backend.
- Sessões anônimas podem ser diferenciadas e restringidas por RLS.
- Premium digital deve respeitar os sistemas e políticas de compra aplicáveis das lojas.
- Aplicação infantil exige parental gates, minimização e revisão cuidadosa de SDKs.
- O tratamento de dados infantis deve priorizar o melhor interesse e os deveres vigentes no Brasil.
