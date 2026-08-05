import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Módulo "Temas e conteúdo" do painel administrativo (docs/12 seção 6):
/// catálogo de temas (criar rascunho, editar manifest, publicar, retirar)
/// e fila de solicitações Premium (`theme_requests`, Marco 5).
///
/// As funções já gravam a própria auditoria no banco, sem chamada
/// duplicada do lado do Flutter (mesmo padrão dos outros módulos do
/// painel).
class AdminThemeRepository {
  AdminThemeRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listThemes() async {
    try {
      final rows = await _client.rpc('admin_list_themes');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<String> createThemeDraft({
    required String slug,
    required String name,
    required String planTier,
  }) async {
    try {
      final rows = await _client.rpc(
        'admin_create_theme_draft',
        params: {'p_slug': slug, 'p_name': name, 'p_plan_tier': planTier},
      );
      return ((rows as List).single as Map<String, dynamic>)['theme_id']
          as String;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> updateThemeManifest({
    required String themeId,
    required Map<String, dynamic> manifest,
  }) async {
    try {
      await _client.rpc(
        'admin_update_theme_manifest',
        params: {'p_theme_id': themeId, 'p_manifest_json': manifest},
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> publishTheme({
    required String themeId,
    required bool ipReviewConfirmed,
  }) async {
    try {
      await _client.rpc(
        'admin_publish_theme',
        params: {
          'p_theme_id': themeId,
          'p_ip_review_confirmed': ipReviewConfirmed,
        },
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> retireTheme(String themeId) async {
    try {
      await _client.rpc('admin_retire_theme', params: {'p_theme_id': themeId});
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<List<Map<String, dynamic>>> listThemeRequests() async {
    try {
      final rows = await _client.rpc('admin_list_theme_requests');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> reviewThemeRequest(String requestId) async {
    try {
      await _client.rpc(
        'admin_review_theme_request',
        params: {'p_request_id': requestId},
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
