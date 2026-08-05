import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Leitura do saldo da criança. Escrita é sempre indireta, via
/// `complete_task_occurrence`/`review_task_occurrence`
/// (docs/09_MODELO_DE_DADOS.md seção 4).
class WalletRepository {
  WalletRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchWallet(String childId) async {
    try {
      return await _client
          .from('child_wallets')
          .select()
          .eq('child_id', childId)
          .maybeSingle();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listLedger(String childId) async {
    try {
      final rows = await _client
          .from('coin_ledger')
          .select()
          .eq('child_id', childId)
          .order('created_at', ascending: false)
          .limit(200);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// Crédito/débito manual do responsável (docs/05 seção 3). `direction` é
  /// `'credit'` ou `'debit'`; `amount` é sempre positivo, o backend decide
  /// o sinal.
  Future<int> adjustCoins({
    required String childId,
    required int amount,
    required String direction,
    required String reason,
    required String idempotencyKey,
  }) async {
    try {
      final rows = await _client.rpc(
        'adjust_child_coins',
        params: {
          'p_child_id': childId,
          'p_amount': amount,
          'p_direction': direction,
          'p_reason': reason,
          'p_idempotency_key': idempotencyKey,
        },
      );
      final row = (rows as List).single as Map<String, dynamic>;
      return row['coin_balance'] as int;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
