import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Catálogo de recompensas da família (docs/05 seção 4). Sem regra de
/// negócio além de autorização, então o CRUD é feito direto via RLS, sem
/// função dedicada (docs/14 seção 1).
class RewardRepository {
  RewardRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listActiveForChild(String childId) async {
    try {
      final rows = await _client
          .from('rewards')
          .select()
          .eq('active', true)
          .or('child_id.is.null,child_id.eq.$childId')
          .order('cost_coins');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listAllForFamily(String familyId) async {
    try {
      final rows = await _client
          .from('rewards')
          .select()
          .eq('family_id', familyId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> createReward({
    required String familyId,
    String? childId,
    required String title,
    String? description,
    String iconKey = 'default',
    String category = 'geral',
    required int costCoins,
    int? cashEquivalentCents,
  }) async {
    try {
      await _client.from('rewards').insert({
        'family_id': familyId,
        'child_id': childId,
        'title': title,
        'description': description,
        'icon_key': iconKey,
        'category': category,
        'cost_coins': costCoins,
        'cash_equivalent_cents': cashEquivalentCents,
      });
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> updateReward({
    required String rewardId,
    required String title,
    String? description,
    String? iconKey,
    String? category,
    required int costCoins,
    int? cashEquivalentCents,
  }) async {
    try {
      final values = <String, dynamic>{
        'title': title,
        'description': description,
        'cost_coins': costCoins,
        'cash_equivalent_cents': cashEquivalentCents,
      };
      if (iconKey != null) values['icon_key'] = iconKey;
      if (category != null) values['category'] = category;
      await _client.from('rewards').update(values).eq('id', rewardId);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> setActive(String rewardId, bool active) async {
    try {
      await _client
          .from('rewards')
          .update({'active': active})
          .eq('id', rewardId);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
