import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Grava a trilha de auditoria append-only do painel administrativo via
/// `record_admin_audit_log` (docs/12 seção 10: "toda ação é auditada").
class AdminAuditLogRepository {
  AdminAuditLogRepository(this._client);

  final SupabaseClient _client;

  Future<void> record({
    required String action,
    required String resourceType,
    String? resourceId,
    String result = 'success',
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      await _client.rpc(
        'record_admin_audit_log',
        params: {
          'p_action': action,
          'p_resource_type': resourceType,
          'p_resource_id': resourceId,
          'p_result': result,
          'p_metadata': metadata,
        },
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
