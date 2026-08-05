-- Marco 8 — "solicitar exportação" (docs/10 seção 12). Devolve os dados da
-- própria família da pessoa que chama — nunca de outra família (RLS não
-- se aplicaria aqui do mesmo jeito por ser security definer, então a
-- checagem de vínculo é feita à mão, mesmo padrão de todas as outras
-- funções deste tipo). `pin_hash` nunca é incluído (docs/10 seção 8: "PIN
-- ... em digest seguro" — mesmo a própria família não lê o hash).
create or replace function public.export_family_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile_id uuid := (select auth.uid());
  v_family_id uuid;
  v_result jsonb;
begin
  if v_profile_id is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  select fm.family_id into v_family_id
  from public.family_members fm
  where fm.profile_id = v_profile_id and fm.status = 'active';

  if v_family_id is null then
    raise exception 'FORBIDDEN';
  end if;

  select jsonb_build_object(
    'exported_at', timezone('utc', now()),
    'family', (
      select jsonb_build_object(
        'id', f.id, 'name', f.name, 'status', f.status,
        'guardian_theme', f.guardian_theme, 'created_at', f.created_at
      )
      from public.families f where f.id = v_family_id
    ),
    'guardians', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'email', u.email, 'role', fm.role, 'status', fm.status, 'joined_at', fm.joined_at
      )), '[]'::jsonb)
      from public.family_members fm
      join auth.users u on u.id = fm.profile_id
      where fm.family_id = v_family_id
    ),
    'children', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', cp.id, 'first_name', cp.first_name, 'nickname', cp.nickname,
        'birth_date', cp.birth_date, 'avatar_id', cp.avatar_id, 'status', cp.status,
        'theme_slug', cp.theme_slug, 'created_at', cp.created_at,
        'wallet', (
          select jsonb_build_object(
            'coin_balance', cw.coin_balance, 'total_xp', cw.total_xp, 'current_level', cw.current_level
          )
          from public.child_wallets cw where cw.child_id = cp.id
        ),
        'devices', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'device_name', cdb.device_name, 'authorized_at', cdb.authorized_at,
            'revoked_at', cdb.revoked_at
          )), '[]'::jsonb)
          from public.child_device_bindings cdb where cdb.child_id = cp.id
        )
      )), '[]'::jsonb)
      from public.child_profiles cp where cp.family_id = v_family_id
    ),
    'recent_coin_ledger', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'child_id', cl.child_id, 'entry_type', cl.entry_type,
        'amount_signed', cl.amount_signed, 'balance_after', cl.balance_after,
        'created_at', cl.created_at
      ) order by cl.created_at desc), '[]'::jsonb)
      from (
        select * from public.coin_ledger where family_id = v_family_id
        order by created_at desc limit 200
      ) cl
    ),
    'rewards', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'title', r.title, 'cost_coins', r.cost_coins, 'active', r.active
      )), '[]'::jsonb)
      from public.rewards r where r.family_id = v_family_id
    ),
    'redemption_requests', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'title_snapshot', rr.title_snapshot, 'cost_snapshot', rr.cost_snapshot,
        'status', rr.status, 'requested_at', rr.requested_at
      ) order by rr.requested_at desc), '[]'::jsonb)
      from public.redemption_requests rr where rr.family_id = v_family_id
    ),
    'consent_records', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'document', cr.document, 'document_version', cr.document_version,
        'purpose', cr.purpose, 'status', cr.status, 'created_at', cr.created_at,
        'revoked_at', cr.revoked_at
      )), '[]'::jsonb)
      from public.consent_records cr where cr.family_id = v_family_id
    ),
    'subscription', (
      select jsonb_build_object(
        'status', s.status, 'store', s.store, 'current_period_end', s.current_period_end
      )
      from public.subscriptions s where s.family_id = v_family_id
    )
  ) into v_result;

  return v_result;
end;
$$;
