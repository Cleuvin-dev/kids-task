import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

class ChildSelectionOption {
  const ChildSelectionOption({
    required this.childId,
    required this.displayName,
    required this.avatarId,
    required this.pinEnabled,
  });

  final String childId;
  final String displayName;
  final String avatarId;
  final bool pinEnabled;
}

class ChildDeviceAuthorization {
  const ChildDeviceAuthorization({
    required this.childId,
    required this.deviceBindingId,
  });

  final String childId;
  final String deviceBindingId;
}

/// Fluxo de acesso da criança, do lado do aparelho, antes de existir
/// qualquer vínculo (ADR 0001, docs/03 seção 6, docs/08 seção 5).
///
/// Erros aqui são deliberadamente genéricos (mesma mensagem para código
/// inválido, criança inexistente ou PIN incorreto) — proteção contra
/// enumeração (docs/03 seção 6).
class ChildAccessRepository {
  ChildAccessRepository(this._client);

  final SupabaseClient _client;

  static const _genericErrorMessage =
      'Não foi possível entrar. Confira o código da família e tente novamente.';

  /// Garante que o aparelho tem uma sessão técnica antes de qualquer outra
  /// chamada. Idempotente: se já houver sessão anônima válida, não cria outra.
  Future<void> ensureDeviceSession() async {
    if (_client.auth.currentSession != null) return;
    try {
      await _client.auth.signInAnonymously();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<List<ChildSelectionOption>> resolveFamilyChildren(
    String familyCode,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'resolve-family-children',
        body: {'family_code': familyCode},
      );
      final data = response.data as Map<String, dynamic>;
      final children = List<Map<String, dynamic>>.from(
        data['children'] as List,
      );
      return children
          .map(
            (c) => ChildSelectionOption(
              childId: c['child_id'] as String,
              displayName: c['display_name'] as String,
              avatarId: c['avatar_id'] as String,
              pinEnabled: c['pin_enabled'] as bool,
            ),
          )
          .toList();
    } catch (_) {
      throw Exception(_genericErrorMessage);
    }
  }

  Future<ChildDeviceAuthorization> authorizeDevice({
    required String familyCode,
    required String childId,
    required String deviceName,
    String? pin,
    String? pairingCode,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'authorize-child-device',
        body: {
          'family_code': familyCode,
          'child_id': childId,
          'device_name': deviceName,
          'pin': ?pin,
          'pairing_code': ?pairingCode,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return ChildDeviceAuthorization(
        childId: data['child_id'] as String,
        deviceBindingId: data['device_binding_id'] as String,
      );
    } catch (_) {
      throw Exception(_genericErrorMessage);
    }
  }
}
