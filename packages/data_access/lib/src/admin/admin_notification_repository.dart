import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Módulo "Notificações" do painel administrativo (docs/12 seção 8):
/// histórico de entrega (canal interno, `notifications` — o único que
/// existe de verdade sem push real) e envio de aviso operacional aos
/// responsáveis de uma família.
class AdminNotificationRepository {
  AdminNotificationRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listHistory() async {
    try {
      final rows = await _client
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// Notifica todos os responsáveis ativos da família — nunca a criança
  /// (docs/12 seção 8: "sem campanha... direcionada diretamente a
  /// crianças no MVP"). Já grava a própria auditoria no banco.
  Future<int> sendOperationalNotice({
    required String familyId,
    required String title,
    required String body,
    required String idempotencyKey,
  }) async {
    try {
      final rows = await _client.rpc(
        'admin_send_operational_notice',
        params: {
          'p_family_id': familyId,
          'p_title': title,
          'p_body': body,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return ((rows as List).single
              as Map<String, dynamic>)['recipients_notified']
          as int;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
