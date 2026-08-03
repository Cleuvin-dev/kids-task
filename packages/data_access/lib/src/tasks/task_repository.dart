import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Operações do responsável sobre o catálogo de tarefas da família
/// (docs/04_TAREFAS_APROVACOES_E_ROTINA.md, docs/14 seção 3).
class TaskRepository {
  TaskRepository(this._client);

  final SupabaseClient _client;

  /// Cria (quando `taskId` é nulo) ou edita uma tarefa e sua agenda numa só
  /// chamada atômica. Retorna `{'task_id': ..., 'schedule_id': ...}`.
  ///
  /// `scheduleType` é `'once'` (exige `oneTimeDate`) ou `'recurring'` (exige
  /// `weekdays`, valores `0`=domingo a `6`=sábado). `approvalMode` é
  /// `'automatic'`/`'manual'`; `latePolicy` é `'allow_late'`/`'expire_no_reward'`.
  Future<Map<String, dynamic>> upsertTask({
    String? taskId,
    String? childId,
    required String title,
    String? description,
    String iconKey = 'default',
    String category = 'geral',
    String period = 'anytime',
    bool isBonus = false,
    bool isRequired = true,
    bool countsTowardStreak = true,
    int coinReward = 0,
    int xpRewardDefault = 0,
    required String approvalMode,
    required String latePolicy,
    int sortOrder = 0,
    required String scheduleType,
    DateTime? oneTimeDate,
    List<int>? weekdays,
    DateTime? startsOn,
    DateTime? endsOn,
    String? startTime,
    String? dueTime,
  }) async {
    try {
      final rows = await _client.rpc(
        'upsert_task_with_schedule',
        params: {
          'p_task_id': taskId,
          'p_child_id': childId,
          'p_title': title,
          'p_description': description,
          'p_icon_key': iconKey,
          'p_category': category,
          'p_period': period,
          'p_is_bonus': isBonus,
          'p_is_required': isRequired,
          'p_counts_toward_streak': countsTowardStreak,
          'p_coin_reward': coinReward,
          'p_xp_reward_default': xpRewardDefault,
          'p_approval_mode': approvalMode,
          'p_late_policy': latePolicy,
          'p_sort_order': sortOrder,
          'p_schedule_type': scheduleType,
          'p_one_time_date': oneTimeDate == null
              ? null
              : _dateOnly(oneTimeDate),
          'p_weekdays': weekdays,
          'p_starts_on': startsOn == null ? null : _dateOnly(startsOn),
          'p_ends_on': endsOn == null ? null : _dateOnly(endsOn),
          'p_start_time': startTime,
          'p_due_time': dueTime,
        },
      );
      return (rows as List).single as Map<String, dynamic>;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> pauseTask(String taskId) async {
    try {
      await _client.rpc('pause_task', params: {'p_task_id': taskId});
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> resumeTask(String taskId) async {
    try {
      await _client.rpc('resume_task', params: {'p_task_id': taskId});
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> archiveTask(String taskId) async {
    try {
      await _client.rpc('archive_task', params: {'p_task_id': taskId});
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listTasksForChild(String childId) async {
    try {
      final rows = await _client
          .from('tasks')
          .select()
          .eq('child_id', childId)
          .filter('archived_at', 'is', null)
          .order('sort_order');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// Agenda ativa da tarefa (uma tarefa tem no máximo uma). Usado para
  /// pré-preencher o formulário de edição.
  Future<Map<String, dynamic>?> fetchActiveSchedule(String taskId) async {
    try {
      return await _client
          .from('task_schedules')
          .select()
          .eq('task_id', taskId)
          .eq('active', true)
          .maybeSingle();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listTasksForFamily(String familyId) async {
    try {
      final rows = await _client
          .from('tasks')
          .select()
          .eq('family_id', familyId)
          .filter('archived_at', 'is', null)
          .order('sort_order');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
