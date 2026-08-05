-- Marco 8 — menor privilégio (mesmo padrão de todas as fatias anteriores)
-- e agendamento de process_scheduled_deletions.

revoke execute on all functions in schema public from public;

grant execute on function public.request_family_deletion(text) to authenticated;
grant execute on function public.respond_family_deletion(uuid, boolean, text) to authenticated;
grant execute on function public.cancel_family_deletion(uuid) to authenticated;
grant execute on function public.process_scheduled_deletions() to service_role;

-- Período de segurança é de dias, não minutos — checagem horária é mais
-- que suficiente (mesma cadência de expire_support_overrides, Marco 7).
select cron.schedule(
  'process-scheduled-deletions',
  '0 * * * *',
  $$select public.process_scheduled_deletions();$$
);
