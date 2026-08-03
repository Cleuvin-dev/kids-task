import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Operações sobre ocorrências de tarefa: tela "Hoje" da criança, inbox de
/// aprovações do responsável, e as transições de estado da máquina descrita
/// em docs/04_TAREFAS_APROVACOES_E_ROTINA.md seção 7.
class OccurrenceRepository {
  OccurrenceRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listToday({
    String? childId,
    String? familyId,
  }) async {
    assert(
      (childId == null) != (familyId == null),
      'informe exatamente um de childId ou familyId',
    );
    try {
      var query = _client.from('v_child_today_tasks').select();
      if (childId != null) query = query.eq('child_id', childId);
      if (familyId != null) query = query.eq('family_id', familyId);
      final rows = await query;
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listPendingApprovals(
    String familyId,
  ) async {
    try {
      final rows = await _client
          .from('v_pending_approvals')
          .select()
          .eq('family_id', familyId);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// Toque em "Concluir". Automático credita na hora; manual só envia para
  /// aprovação. `completedByGuardian: true` é o responsável concluindo em
  /// nome da criança (auditado).
  Future<Map<String, dynamic>> completeOccurrence({
    required String occurrenceId,
    required String idempotencyKey,
    required int expectedVersion,
    bool completedByGuardian = false,
  }) async {
    try {
      final rows = await _client.rpc(
        'complete_task_occurrence',
        params: {
          'p_occurrence_id': occurrenceId,
          'p_idempotency_key': idempotencyKey,
          'p_expected_version': expectedVersion,
          'p_completed_by_guardian': completedByGuardian,
        },
      );
      return (rows as List).single as Map<String, dynamic>;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// Só responsável. `decision` é `'approve'` ou `'reject'`; `rejectionReason`
  /// é obrigatório ao rejeitar.
  Future<Map<String, dynamic>> reviewOccurrence({
    required String occurrenceId,
    required String decision,
    required String idempotencyKey,
    required int expectedVersion,
    String? rejectionReason,
  }) async {
    try {
      final rows = await _client.rpc(
        'review_task_occurrence',
        params: {
          'p_occurrence_id': occurrenceId,
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

  /// Só responsável; exige motivo. Não credita nem debita, não afeta streak.
  Future<Map<String, dynamic>> skipOccurrence({
    required String occurrenceId,
    required String reason,
    required String idempotencyKey,
  }) async {
    try {
      final rows = await _client.rpc(
        'skip_task_occurrence',
        params: {
          'p_occurrence_id': occurrenceId,
          'p_reason': reason,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return (rows as List).single as Map<String, dynamic>;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// Emite um evento sempre que uma ocorrência da criança muda no backend
  /// (Realtime). Não entrega os dados em si — a UI deve recarregar a lista,
  /// mesmo padrão pragmático já usado no resto do app em vez de reconciliar
  /// deltas manualmente.
  Stream<void> watchChildOccurrences(String childId) {
    final controller = StreamController<void>.broadcast();
    final channel = _client
        .channel('child-today-$childId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'task_occurrences',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'child_id',
            value: childId,
          ),
          callback: (payload) => controller.add(null),
        )
        .subscribe();

    controller.onCancel = () => _client.removeChannel(channel);
    return controller.stream;
  }

  /// Mesma ideia de [watchChildOccurrences], mas para a inbox de aprovações
  /// do responsável (por família).
  Stream<void> watchFamilyOccurrences(String familyId) {
    final controller = StreamController<void>.broadcast();
    final channel = _client
        .channel('family-approvals-$familyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'task_occurrences',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'family_id',
            value: familyId,
          ),
          callback: (payload) => controller.add(null),
        )
        .subscribe();

    controller.onCancel = () => _client.removeChannel(channel);
    return controller.stream;
  }
}
