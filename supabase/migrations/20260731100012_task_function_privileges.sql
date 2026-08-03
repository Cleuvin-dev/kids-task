-- Marco 2 — Rotina e Tarefas (parte 5/8)
-- Menor privilégio nas novas funções, mesmo padrão de
-- 20260731100007_function_privileges.sql: por padrão o Postgres concede
-- EXECUTE em novas funções a PUBLIC, então revogamos e concedemos
-- explicitamente só o necessário.

revoke execute on all functions in schema public from public;

-- Funções que o app chama diretamente (responsável e/ou criança autenticados).
grant execute on function public.upsert_task_with_schedule(
  uuid, uuid, text, text, text, text, text, boolean, boolean, boolean,
  integer, integer, text, text, integer, text, date, smallint[], date, date, time, time
) to authenticated;
grant execute on function public.pause_task(uuid) to authenticated;
grant execute on function public.resume_task(uuid) to authenticated;
grant execute on function public.archive_task(uuid) to authenticated;
grant execute on function public.complete_task_occurrence(uuid, text, integer, boolean) to authenticated;
grant execute on function public.review_task_occurrence(uuid, text, text, integer, text) to authenticated;
grant execute on function public.skip_task_occurrence(uuid, text, text) to authenticated;

-- Funções chamadas só pelo agendador interno (pg_cron), nunca por um
-- cliente autenticado.
grant execute on function public.generate_task_occurrences(uuid) to service_role;
grant execute on function public.expire_due_task_occurrences() to service_role;

-- grant_task_rewards e task_schedule_occurrence_dates: nenhum grant a
-- nenhum papel de cliente, de propósito — só chamáveis internamente por
-- outra função security definer do mesmo dono (mesmo padrão das
-- utilitárias de hash do Marco 1).
