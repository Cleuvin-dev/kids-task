import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Nível, XP e streak da criança (docs/05 seções 7-12). Escrita de
/// progresso em si (nível, streak) é sempre indireta, via aprovação de
/// tarefa — só as configurações da regra são editáveis pelo responsável.
class ProgressRepository {
  ProgressRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listLevelDefinitions() async {
    try {
      final rows = await _client
          .from('level_definitions')
          .select()
          .order('level');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<Map<String, dynamic>?> fetchStreak(String childId) async {
    try {
      return await _client
          .from('child_streaks')
          .select()
          .eq('child_id', childId)
          .maybeSingle();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// `streakRule` é `'at_least_one'`, `'all_required'` ou `'percentage'`
  /// (docs/05 seção 12).
  Future<void> updateProgressSettings({
    required String childId,
    required String streakRule,
    required int streakPercentage,
    required int levelBonusCoins,
    required int birthdayBonusCoins,
  }) async {
    try {
      await _client
          .from('child_profiles')
          .update({
            'streak_rule': streakRule,
            'streak_percentage': streakPercentage,
            'level_bonus_coins': levelBonusCoins,
            'birthday_bonus_coins': birthdayBonusCoins,
          })
          .eq('id', childId);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
