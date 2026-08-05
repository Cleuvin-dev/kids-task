-- Marco 7 (fatia 3) — Módulo "Assinaturas" do painel (docs/12 seção 5).
--
-- Antes deste módulo, nenhuma policy de RLS deixava um administrador ler
-- dados de uma família que não é a dele — só o backend de assinaturas em
-- si existia (fatia 1). `is_active_platform_admin` é o bloco reaproveitável
-- que qualquer módulo futuro do painel (famílias, conteúdo, suporte) vai
-- usar para conceder leitura entre famílias, sempre restrita por papel.

create or replace function public.is_active_platform_admin(p_roles text[] default null)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.platform_admins pa
    where pa.profile_id = (select auth.uid())
      and pa.active
      and (p_roles is null or pa.role = any(p_roles))
  );
$$;

comment on function public.is_active_platform_admin(text[]) is
  'Bloco reaproveitável para RLS entre famílias (docs/12): true se o '
  'usuário autenticado for um platform_admins ativo, opcionalmente restrito '
  'a um subconjunto de papéis. Só olha a própria linha do chamador — '
  'respeita a RLS de platform_admins mesmo sem ser security definer.';

-- families: super_admin (visão geral), support (dados mínimos p/ ticket,
-- docs/12 seção 9) e billing (módulo de assinaturas) enxergam qualquer
-- família. content fica de fora — não lida com dado de família/responsável.
create policy "families_select_admin" on public.families
  for select
  to authenticated
  using (public.is_active_platform_admin(array['super_admin', 'support', 'billing']));

-- subscriptions/subscription_events: só super_admin e billing (docs/12
-- seção 2: billing = "planos, produtos e assinaturas").
create policy "subscriptions_select_admin" on public.subscriptions
  for select
  to authenticated
  using (public.is_active_platform_admin(array['super_admin', 'billing']));

create policy "subscription_events_select_admin" on public.subscription_events
  for select
  to authenticated
  using (public.is_active_platform_admin(array['super_admin', 'billing']));

-- Sem policy de insert/update/delete para admin em nenhuma das três: toda
-- escrita continua só via função (submit_purchase_receipt e as internas já
-- existentes, mais admin_grant_subscription_override/
-- admin_revoke_subscription_override desta fatia).
