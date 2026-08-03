-- Marco 2 — Rotina e Tarefas (parte 6/8)
-- Views de leitura (docs/09_MODELO_DE_DADOS.md seção 10).
--
-- security_invoker = true: a view roda com o privilégio de QUEM CONSULTA,
-- não do dono da view, para que a RLS das tabelas de baixo continue valendo
-- (doc09: "As views devem respeitar RLS").

create view public.v_child_today_tasks
with (security_invoker = true) as
select o.*
from public.task_occurrences o
where o.occurrence_date = current_date;

comment on view public.v_child_today_tasks is
  'Tela "Hoje" da criança e do responsável. RLS de task_occurrences já '
  'filtra por família/criança; esta view só recorta a data de hoje.';

create view public.v_pending_approvals
with (security_invoker = true) as
select
  o.*,
  t.title as task_title,
  t.icon_key as task_icon_key
from public.task_occurrences o
join public.tasks t on t.id = o.task_id
where o.status = 'awaiting_approval';

comment on view public.v_pending_approvals is
  'Inbox de aprovações do responsável.';

-- Grants explícitos por segurança (o schema public do Supabase normalmente
-- já concede select em novos objetos via default privileges, mas fica
-- explícito aqui por serem os primeiros dois objetos do tipo view no repo).
grant select on public.v_child_today_tasks to authenticated;
grant select on public.v_pending_approvals to authenticated;
