import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Central interna de notificações (docs/11_NOTIFICACOES.md seção 1). RLS
/// já resolve "notificações de quem" — o cliente nunca precisa informar o
/// destinatário nas leituras.
class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listNotifications() async {
    try {
      final rows = await _client
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _client.rpc(
        'mark_notification_read',
        params: {'p_notification_id': notificationId},
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
