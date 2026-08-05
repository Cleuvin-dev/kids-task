-- Marco 7 (fatia 4) — RLS admin para os dois itens de docs/12 seção 4 que
-- não têm dado de identidade infantil na própria linha ("aparelhos
-- ativos"; "consentimentos"), então (ao contrário de child_profiles) uma
-- policy de select direta é suficiente — sem precisar de função.
create policy "child_device_bindings_select_admin" on public.child_device_bindings
  for select
  to authenticated
  using (public.is_active_platform_admin(array['super_admin', 'support']));

create policy "consent_records_select_admin" on public.consent_records
  for select
  to authenticated
  using (public.is_active_platform_admin(array['super_admin', 'support']));
