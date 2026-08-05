-- Marco 7 (fatia 6) — menor privilégio, mesmo padrão das fatias
-- anteriores. Diferente das fatias 3-5, esta não expõe nenhuma função
-- chamável via RPC (`support_tickets`/`support_ticket_messages` usam RLS
-- direta, docs/14 seção 1) — só o revoke defensivo de hábito, cobrindo
-- `sync_support_ticket_closed_at`/`touch_support_ticket_on_message`
-- (funções de gatilho; o próprio Postgres já impede chamá-las fora de um
-- gatilho, então isto é redundante, não uma correção de um buraco real).

revoke execute on all functions in schema public from public;
