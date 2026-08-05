-- Marco 8 — retenção (docs/10 seção 13: "os prazos finais dependem de
-- validação jurídica"). Janelas abaixo são o default técnico adotado
-- nesta passada, documentado também em
-- docs/18_PENDENCIAS_NAO_BLOQUEANTES.md seção 7 — trocar é um `update`
-- nesta função, não uma migration de schema.
create or replace function public.purge_stale_operational_data()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Convite não aceito: expirado/cancelado/aceito há mais de 30 dias não
  -- tem mais valor operacional (docs/10 seção 13: "remover após expiração
  -- + janela curta de segurança").
  delete from public.family_invites
  where (accepted_at is not null and accepted_at < timezone('utc', now()) - interval '30 days')
     or (cancelled_at is not null and cancelled_at < timezone('utc', now()) - interval '30 days')
     or (accepted_at is null and cancelled_at is null and expires_at < timezone('utc', now()) - interval '30 days');

  -- Tentativas de login infantil: retenção curta para antifraude.
  delete from public.child_login_attempts
  where created_at < timezone('utc', now()) - interval '90 days';

  -- Token de push inativo: remover rapidamente (docs/10 seção 13).
  delete from public.device_tokens
  where not active and last_seen_at < timezone('utc', now()) - interval '30 days';
end;
$$;
