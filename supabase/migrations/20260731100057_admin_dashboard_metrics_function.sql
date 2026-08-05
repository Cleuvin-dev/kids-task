-- Marco 7 (fatia 7) — "métricas e auditoria" (docs/12 seção 3: dashboard
-- de métricas agregadas; seção 10: auditoria). O log de auditoria em si
-- (`audit_logs`) já tem RLS pronta desde a fatia 2 (`audit_logs_select_own`/
-- `audit_logs_select_super_admin`) — não precisa de função nova, só uma
-- tela nova (ver apps/admin_web). Esta migration cobre só o dashboard.
--
-- Só `super_admin` (docs/12 seção 2: "configuração geral" — visão
-- cross-domínio que nenhum outro papel precisa por completo). Nunca conta
-- nem exibe nome de criança (docs/12 seção 3: "por padrão, não mostrar
-- nomes de crianças no dashboard") — todas as métricas são contagens.
--
-- **Métrica deliberadamente ausente**: "falhas de push/jobs/webhooks"
-- (docs/12 seção 3) não tem de onde vir — não existe rastreamento de
-- falha de `pg_cron` nem de webhook de loja numa tabela consultável, e
-- push de verdade continua bloqueado (Marco 6, bloqueio 5). Fica de fora
-- em vez de aparecer como um zero enganoso; expor esse buraco é melhor do
-- que fingir uma métrica que não existe.
create or replace function public.admin_get_dashboard_metrics()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if not public.is_active_platform_admin(array['super_admin']) then
    raise exception 'FORBIDDEN';
  end if;

  select jsonb_build_object(
    'families_total', (select count(*) from public.families),
    'families_active', (select count(*) from public.families where status = 'active'),
    -- Proxy para "onboarding concluído" (docs/12 seção 3): não existe uma
    -- coluna dedicada — família com ao menos uma criança ativa já passou
    -- por consentimento + criação de família + cadastro de criança
    -- (docs/03), então é o melhor sinal disponível sem inventar campo novo.
    'families_onboarded', (select count(distinct family_id) from public.child_profiles where status = 'active'),
    'guardians_total', (select count(*) from public.family_members where status = 'active'),
    'children_total', (select count(*) from public.child_profiles where status = 'active'),
    'families_by_effective_plan', (
      select coalesce(jsonb_object_agg(effective_plan_code, cnt), '{}'::jsonb)
      from (
        select effective_plan_code, count(*) as cnt
        from public.v_effective_entitlements
        group by effective_plan_code
      ) s
    ),
    'subscriptions_by_status', (
      select coalesce(jsonb_object_agg(status, cnt), '{}'::jsonb)
      from (select status, count(*) as cnt from public.subscriptions group by status) s
    ),
    'tasks_active', (select count(*) from public.tasks where is_active),
    'occurrences_approved_total', (select count(*) from public.task_occurrences where status = 'approved'),
    'occurrences_awaiting_approval', (select count(*) from public.task_occurrences where status = 'awaiting_approval'),
    'redemptions_pending', (select count(*) from public.redemption_requests where status = 'requested'),
    'redemptions_delivered_total', (select count(*) from public.redemption_requests where status = 'delivered'),
    'support_tickets_open', (
      select count(*) from public.support_tickets
      where status in ('open', 'in_progress', 'waiting_on_family')
    )
  ) into v_result;

  return v_result;
end;
$$;
