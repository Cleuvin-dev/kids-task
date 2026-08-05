import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Módulo "Famílias e usuários" do painel administrativo (docs/12 seção 4):
/// busca de família, detalhe (responsáveis, crianças, aparelhos,
/// consentimentos) e alteração de status (docs/12 seção 11).
///
/// Dado infantil fica oculto por padrão: [listChildren] nunca devolve nome/
/// apelido/data de nascimento/avatar — só [revealChildIdentity] revela,
/// mediante justificativa, e essa função já grava a própria auditoria no
/// banco (mesmo padrão de `admin_set_family_status`), então este
/// repositório não chama `AdminAuditLogRepository` de novo para nenhuma das
/// duas.
class AdminFamilyRepository {
  AdminFamilyRepository(this._client);

  final SupabaseClient _client;

  /// Mesma função `admin_search_families` do módulo Assinaturas (fatia 3) —
  /// busca por ID da família ou e-mail do responsável, nunca por código
  /// familiar.
  Future<List<Map<String, dynamic>>> searchFamilies(String query) async {
    try {
      final rows = await _client.rpc(
        'admin_search_families',
        params: {'p_query': query},
      );
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// Só `status`/`age_mode`/`created_at` por criança — nunca identidade.
  Future<List<Map<String, dynamic>>> listChildren(String familyId) async {
    try {
      final rows = await _client.rpc(
        'admin_list_family_children',
        params: {'p_family_id': familyId},
      );
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// Revela nome/apelido/avatar/nascimento de uma criança — exige
  /// justificativa e fica auditado (docs/12 seção 4: "dados infantis ficam
  /// ocultos até uma ação justificada de suporte").
  Future<Map<String, dynamic>> revealChildIdentity({
    required String childId,
    required String justification,
  }) async {
    try {
      final rows = await _client.rpc(
        'admin_reveal_child_identity',
        params: {'p_child_id': childId, 'p_justification': justification},
      );
      return (rows as List).single as Map<String, dynamic>;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// Aparelhos vinculados às crianças informadas (docs/12 seção 4:
  /// "aparelhos ativos") — [childIds] normalmente vem de [listChildren].
  Future<List<Map<String, dynamic>>> listDevices(List<String> childIds) async {
    if (childIds.isEmpty) return const [];
    try {
      final rows = await _client
          .from('child_device_bindings')
          .select(
            'id, child_id, device_name, authorized_at, last_seen_at, revoked_at',
          )
          .inFilter('child_id', childIds)
          .order('authorized_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
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

  /// docs/12 seção 11: bloquear/restringir/reativar uma família — motivo
  /// obrigatório, idempotente, auditado e já revoga os aparelhos infantis
  /// vinculados quando o novo status sai de active/restricted (feito no
  /// próprio `admin_set_family_status`).
  Future<String> setFamilyStatus({
    required String familyId,
    required String newStatus,
    required String reason,
    required String idempotencyKey,
  }) async {
    try {
      final rows = await _client.rpc(
        'admin_set_family_status',
        params: {
          'p_family_id': familyId,
          'p_new_status': newStatus,
          'p_reason': reason,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return ((rows as List).single as Map<String, dynamic>)['status']
          as String;
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
