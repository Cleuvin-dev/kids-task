import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// "Métricas e auditoria" (docs/12 seções 3 e 10): dashboard agregado —
/// nunca nome de criança, só contagens — e o log de auditoria
/// (`audit_logs`, já existe desde a fatia 2 com RLS pronta: super_admin
/// vê tudo, outro papel só as próprias ações).
class AdminDashboardRepository {
  AdminDashboardRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> fetchMetrics() async {
    try {
      final result = await _client.rpc('admin_get_dashboard_metrics');
      return Map<String, dynamic>.from(result as Map);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listAuditLog() async {
    try {
      final rows = await _client
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(200);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
