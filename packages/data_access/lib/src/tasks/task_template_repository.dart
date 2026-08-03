import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Catálogo global de tarefas prontas, somente leitura
/// (docs/17_BANCO_INICIAL_DE_TAREFAS.md).
class TaskTemplateRepository {
  TaskTemplateRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listTemplates({
    int? ageYears,
    String? category,
  }) async {
    try {
      var query = _client.from('task_templates').select().eq('active', true);
      if (ageYears != null) {
        query = query
            .lte('suggested_age_min', ageYears)
            .gte('suggested_age_max', ageYears);
      }
      if (category != null) {
        query = query.eq('category', category);
      }
      final rows = await query.order('title');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
