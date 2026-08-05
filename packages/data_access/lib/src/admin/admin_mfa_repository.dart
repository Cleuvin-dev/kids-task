import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Dados de um enrolamento TOTP recém-criado, o suficiente para a UI
/// mostrar a chave secreta e depois confirmar com [AdminMfaRepository.verifyFactor].
@immutable
class TotpEnrollment {
  const TotpEnrollment({required this.factorId, required this.secret});

  final String factorId;
  final String secret;
}

/// Enrolamento e verificação do segundo fator (TOTP) do painel
/// administrativo — MFA é obrigatório antes de qualquer módulo
/// (docs/12_PAINEL_ADMINISTRATIVO_WEB.md seções 2 e 10).
class AdminMfaRepository {
  AdminMfaRepository(this._client);

  final SupabaseClient _client;

  Future<TotpEnrollment> enrollTotp({String? friendlyName}) async {
    try {
      final response = await _client.auth.mfa.enroll(
        factorType: FactorType.totp,
        friendlyName: friendlyName,
      );
      return TotpEnrollment(
        factorId: response.id,
        secret: response.totp!.secret,
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  /// Usado tanto para confirmar um fator recém-enrolado quanto para
  /// completar o desafio de MFA de uma sessão já existente — o gesto do
  /// usuário (digitar o código do app autenticador) é o mesmo nos dois
  /// casos.
  Future<void> verifyFactor({
    required String factorId,
    required String code,
  }) async {
    try {
      await _client.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
