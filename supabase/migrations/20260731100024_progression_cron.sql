-- Marco 4 — XP e Progressão (parte 5/5)
-- Agendamento do bônus de aniversário (docs/14 seção 13: "Aniversários:
-- diário após 00:05 no fuso"). Mesmo horário UTC 04:00 já usado para
-- geração de ocorrências (Marco 2) — cobre o fuso padrão
-- America/Sao_Paulo com folga; ver bloqueio de disponibilidade de
-- pg_cron já documentado em docs/IMPLEMENTATION_STATUS.md.

select cron.schedule(
  'grant-birthday-bonus',
  '0 4 * * *',
  $$select public.grant_birthday_bonus();$$
);
