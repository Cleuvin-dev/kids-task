-- Marco 8 — menor privilégio e agendamento, mesmo padrão de todas as
-- fatias anteriores.

revoke execute on all functions in schema public from public;

grant execute on function public.export_family_data() to authenticated;
grant execute on function public.purge_stale_operational_data() to service_role;

-- Diária: dados operacionais de curta retenção não precisam de cadência
-- horária (diferente de expire_due_task_occurrences/
-- process_scheduled_deletions, que lidam com prazos de horas/dias).
select cron.schedule(
  'purge-stale-operational-data',
  '0 3 * * *',
  $$select public.purge_stale_operational_data();$$
);
