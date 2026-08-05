import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Módulo "Assinaturas" do painel administrativo (docs/12 seção 5): busca
/// de família, consulta de entitlement/assinatura/eventos e override de
/// suporte. `admin_grant_subscription_override`/
/// `admin_revoke_subscription_override` já gravam a própria auditoria no
/// banco (docs/12 seção 10) — este repositório não chama
/// `AdminAuditLogRepository` de novo para essas duas ações.
class AdminSubscriptionRepository {
  AdminSubscriptionRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> searchFamilies(String query) async {
    try {
      final rows = await _client.rpc(
        'admin_search_families',
        params: {'p_query': query},
      );
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// Plano efetivo da família (docs/13 seção 5) — mesma view que o app
  /// consulta, agora visível ao admin via `families_select_admin`/
  /// `subscriptions_select_admin`.
  Future<Map<String, dynamic>?> fetchEntitlements(String familyId) async {
    try {
      return await _client
          .from('v_effective_entitlements')
          .select()
          .eq('family_id', familyId)
          .maybeSingle();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<Map<String, dynamic>?> fetchSubscription(String familyId) async {
    try {
      return await _client
          .from('subscriptions')
          .select()
          .eq('family_id', familyId)
          .maybeSingle();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecentEvents(String familyId) async {
    try {
      final rows = await _client
          .from('subscription_events')
          .select()
          .eq('family_id', familyId)
          .order('created_at', ascending: false)
          .limit(20);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<Map<String, dynamic>> grantOverride({
    required String familyId,
    required DateTime expiresAt,
    required String justification,
    required String idempotencyKey,
  }) async {
    try {
      final rows = await _client.rpc(
        'admin_grant_subscription_override',
        params: {
          'p_family_id': familyId,
          'p_expires_at': expiresAt.toUtc().toIso8601String(),
          'p_justification': justification,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return (rows as List).single as Map<String, dynamic>;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<Map<String, dynamic>> revokeOverride({
    required String familyId,
    required String reason,
    required String idempotencyKey,
  }) async {
    try {
      final rows = await _client.rpc(
        'admin_revoke_subscription_override',
        params: {
          'p_family_id': familyId,
          'p_reason': reason,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return (rows as List).single as Map<String, dynamic>;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
