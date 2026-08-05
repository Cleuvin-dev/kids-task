-- Marco 7 (fatia 7) — módulo "Notificações" do painel (docs/12 seção 8):
-- histórico de entrega (o canal interno, `notifications`, do Marco 6 — o
-- único que existe de verdade hoje) e avisos operacionais para
-- responsáveis.
--
-- `notifications` não guarda nome de criança na própria linha (título/
-- corpo vêm de snapshots de tarefa/recompensa, não de perfil infantil —
-- ver comentário original na migration do Marco 6), então uma policy
-- direta é suficiente, ao contrário de `child_profiles` (fatia 4).
create policy "notifications_select_admin" on public.notifications
  for select
  to authenticated
  using (public.is_active_platform_admin(array['super_admin', 'support']));
