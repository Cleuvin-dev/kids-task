-- Marco 2 — Rotina e Tarefas (parte 7/8)
-- Realtime para a tela "Hoje" da criança e a inbox de aprovações do
-- responsável (docs/04 seção 12: "acompanhar o progresso do dia em tempo
-- real"). Realtime respeita RLS: cada cliente só recebe as linhas que a
-- policy correspondente já permitiria ler via select.

alter publication supabase_realtime add table public.task_occurrences;
