-- Marco 7 (fatia 3) — Agendamento de expire_support_overrides (docs/15
-- seção 14: "override de assinatura expira"). Overrides são concedidos em
-- dias/semanas, não minutos, então uma checagem horária é suficiente —
-- não precisa da cadência de 5 minutos usada para prazo de tarefa.

select cron.schedule(
  'expire-support-overrides',
  '0 * * * *',
  $$select public.expire_support_overrides();$$
);
