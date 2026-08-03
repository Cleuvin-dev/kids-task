import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Ciclo de vida do resgate (docs/05 seção 5): solicitar, aprovar/rejeitar,
/// marcar entregue, cancelar um resgate aprovado.
class RedemptionRepository {
  RedemptionRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> requestRedemption({
    required String rewardId,
    required String idempotencyKey,
  }) async {
    try {
      final rows = await _client.rpc(
        'request_redemption',
        params: {'p_reward_id': rewardId, 'p_idempotency_key': idempotencyKey},
      );
      return (rows as List).single as Map<String, dynamic>;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<Map<String, dynamic>> reviewRedemption({
    required String redemptionId,
    required String decision,
    required String idempotencyKey,
    required int expectedVersion,
    String? rejectionReason,
  }) async {
    try {
      final rows = await _client.rpc(
        'review_redemption',
        params: {
          'p_redemption_id': redemptionId,
          'p_decision': decision,
          'p_idempotency_key': idempotencyKey,
          'p_expected_version': expectedVersion,
          'p_rejection_reason': rejectionReason,
        },
      );
      return (rows as List).single as Map<String, dynamic>;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<Map<String, dynamic>> markDelivered({
    required String redemptionId,
    required String idempotencyKey,
  }) async {
    try {
      final rows = await _client.rpc(
        'mark_redemption_delivered',
        params: {
          'p_redemption_id': redemptionId,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return (rows as List).single as Map<String, dynamic>;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<Map<String, dynamic>> cancelApproved({
    required String redemptionId,
    required String reason,
    required String idempotencyKey,
  }) async {
    try {
      final rows = await _client.rpc(
        'cancel_approved_redemption',
        params: {
          'p_redemption_id': redemptionId,
          'p_reason': reason,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return (rows as List).single as Map<String, dynamic>;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listForChild(String childId) async {
    try {
      final rows = await _client
          .from('redemption_requests')
          .select()
          .eq('child_id', childId)
          .order('requested_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listForFamily(String familyId) async {
    try {
      final rows = await _client
          .from('redemption_requests')
          .select()
          .eq('family_id', familyId)
          .order('requested_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
