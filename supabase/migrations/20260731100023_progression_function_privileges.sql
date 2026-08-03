-- Marco 4 — XP e Progressão (parte 4/5)
-- Menor privilégio: só grant_birthday_bonus é chamada por um agendador
-- (service_role, via pg_cron). process_level_changes,
-- recalculate_daily_progress e advance_streak são internas, chamadas só de
-- dentro de complete_task_occurrence/review_task_occurrence — nenhum
-- grant a nenhum papel de cliente, de propósito.

revoke execute on all functions in schema public from public;

grant execute on function public.grant_birthday_bonus() to service_role;
