-- Marco 2 — Rotina e Tarefas (parte 8/8)
-- Agendamento interno via pg_cron (docs/14_APIS_FUNCOES_E_EVENTOS.md
-- seção 13: "Gerar ocorrências: diário + após editar agenda" e
-- "Verificar prazo: a cada 5 minutos").
--
-- pg_cron roda dentro do próprio banco, sem infraestrutura externa nova
-- (nenhum scheduler HTTP, nenhum segredo adicional) — diferente das Edge
-- Functions do Marco 1, que existem para orquestrar chamadas HTTP de um
-- cliente não autenticado. Aqui o job não tem cliente algum, só o
-- agendador interno do Supabase.
--
-- generate_task_occurrences já calcula occurrence_date/starts_at/due_at no
-- fuso de CADA família internamente, então uma execução diária em UTC
-- 04:00 (01:00 no fuso padrão America/Sao_Paulo) é suficiente para o
-- público atual, só no Brasil.
--
-- BLOQUEIO CONHECIDO (ver docs/IMPLEMENTATION_STATUS.md): esta migration
-- não pôde ser validada nesta máquina (sem Docker) nem confirmada contra um
-- projeto Supabase real (ainda não provisionado). pg_cron é uma extensão
-- padrão em projetos Supabase Cloud, mas a disponibilidade efetiva só será
-- confirmada quando houver um projeto real e/ou quando o CI rodar.

create extension if not exists pg_cron;

select cron.schedule(
  'generate-task-occurrences',
  '0 4 * * *',
  $$select public.generate_task_occurrences();$$
);

select cron.schedule(
  'expire-due-task-occurrences',
  '*/5 * * * *',
  $$select public.expire_due_task_occurrences();$$
);
