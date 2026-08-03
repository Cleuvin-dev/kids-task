import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Catálogo de temas e solicitações de tema Premium
/// (docs/06_TEMAS_DESIGN_E_FAIXAS_ETARIAS.md, docs/14 seção 6).
class ThemeRepository {
  ThemeRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listPublishedThemes() async {
    try {
      final rows = await _client
          .from('themes')
          .select()
          .order('plan_tier')
          .order('name');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> applyChildTheme({
    required String childId,
    required String themeSlug,
  }) async {
    try {
      await _client.rpc(
        'apply_child_theme',
        params: {'p_child_id': childId, 'p_theme_slug': themeSlug},
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> submitThemeRequest({
    required String familyId,
    required String category,
    String? colors,
    String? description,
    String? targetAgeRange,
    required bool consent,
  }) async {
    try {
      await _client.rpc(
        'submit_theme_request',
        params: {
          'p_family_id': familyId,
          'p_category': category,
          'p_colors': colors,
          'p_description': description,
          'p_target_age_range': targetAgeRange,
          'p_consent': consent,
        },
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
