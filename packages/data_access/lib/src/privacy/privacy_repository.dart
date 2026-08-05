import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Direitos de privacidade do responsável (docs/10 seção 12): ver
/// consentimentos, exportar dados e o fluxo de exclusão dupla da família
/// (docs/10 seção 10).
class PrivacyRepository {
  PrivacyRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> exportFamilyData() async {
    try {
      final result = await _client.rpc('export_family_data');
      return Map<String, dynamic>.from(result as Map);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listConsents(String familyId) async {
    try {
      final rows = await _client
          .from('consent_records')
          .select()
          .eq('family_id', familyId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> revokeConsent(String consentId) async {
    try {
      await _client.rpc('revoke_consent', params: {'p_consent_id': consentId});
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// Pedido de exclusão em andamento da família (`pending_approval` ou
  /// `approved`) — `null` quando não há nenhum.
  Future<Map<String, dynamic>?> fetchActiveDeletionRequest(
    String familyId,
  ) async {
    try {
      return await _client
          .from('deletion_requests')
          .select()
          .eq('family_id', familyId)
          .inFilter('status', ['pending_approval', 'approved'])
          .maybeSingle();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<Map<String, dynamic>> requestFamilyDeletion(
    String idempotencyKey,
  ) async {
    try {
      final rows = await _client.rpc(
        'request_family_deletion',
        params: {'p_idempotency_key': idempotencyKey},
      );
      return (rows as List).single as Map<String, dynamic>;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> respondFamilyDeletion({
    required String requestId,
    required bool approve,
    String? rejectionReason,
  }) async {
    try {
      await _client.rpc(
        'respond_family_deletion',
        params: {
          'p_request_id': requestId,
          'p_approve': approve,
          'p_rejection_reason': rejectionReason,
        },
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> cancelFamilyDeletion(String requestId) async {
    try {
      await _client.rpc(
        'cancel_family_deletion',
        params: {'p_request_id': requestId},
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
