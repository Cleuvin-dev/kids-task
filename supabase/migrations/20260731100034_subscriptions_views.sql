-- Marco 7 — Assinaturas e Entitlements (parte 3/4)
-- v_effective_entitlements (docs/09 seção 10, docs/13 seção 5: "O
-- aplicativo consulta v_effective_entitlements").
--
-- security_invoker = true: a view roda com o privilégio de QUEM CONSULTA,
-- não do dono da view, para que a RLS de families/plans/subscriptions
-- continue valendo (doc09: "As views devem respeitar RLS").

create view public.v_effective_entitlements
with (security_invoker = true) as
select
  f.id as family_id,
  f.plan_id,
  p.code as plan_code,
  s.status as subscription_status,
  public.resolve_effective_plan_code(coalesce(s.status, 'free')) as effective_plan_code,
  p.max_active_children,
  p.max_daily_occurrences,
  p.entitlements_json,
  s.current_period_end,
  s.grace_period_end,
  f.primary_child_id
from public.families f
join public.plans p on p.id = f.plan_id
left join public.subscriptions s on s.family_id = f.id;

comment on view public.v_effective_entitlements is
  'Fonte que o app consulta para saber o plano efetivo da família '
  '(docs/13 seção 5). effective_plan_code considera o status da assinatura '
  '(ex.: grace_period/cancelled_active_until_end ainda contam como premium), '
  'não só o plan_id em cache — mesmo que apply_subscription_transition '
  'mantenha os dois sincronizados na maior parte do tempo.';
