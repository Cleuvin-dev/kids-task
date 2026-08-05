-- Marco 8 — achado da revisão de consentimento (docs/10 seção 4: "permitir
-- consulta e revogação"): `consent_records` já tinha `status`/`revoked_at`
-- desde o Marco 1, mas nenhuma função escrevia neles — só a leitura e o
-- registro inicial (`recordConsent`, RLS de insert) existiam. Consulta já
-- é resolvida por `consent_records_select_guardian`; faltava revogação.
create or replace function public.revoke_consent(p_consent_id uuid)
returns table (status text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_record public.consent_records%rowtype;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select * into v_record from public.consent_records where id = p_consent_id;

  if not found then
    raise exception 'VALIDATION_ERROR' using detail = 'consent record not found';
  end if;

  if not exists (
    select 1 from public.family_members fm
    where fm.family_id = v_record.family_id and fm.profile_id = v_profile_id and fm.status = 'active'
  ) then
    raise exception 'FORBIDDEN';
  end if;

  if v_record.status = 'revoked' then
    raise exception 'VALIDATION_ERROR' using detail = 'consent already revoked';
  end if;

  update public.consent_records
  set status = 'revoked', revoked_at = timezone('utc', now())
  where id = p_consent_id;

  return query select 'revoked'::text;
end;
$$;

-- Revoke-all defensivo de hábito (mesmo padrão de toda migration de
-- privilégios) — as concessões às funções de fatias anteriores já feitas
-- em suas próprias migrations não são afetadas (REVOKE ... FROM PUBLIC
-- nunca remove um grant explícito a `authenticated`/`service_role`).
revoke execute on all functions in schema public from public;

grant execute on function public.revoke_consent(uuid) to authenticated;
