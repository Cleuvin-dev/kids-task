import 'package:domain/domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduz erros do Supabase (RPC/Edge Function/Auth) para [DomainFailure],
/// para que a camada de apresentação nunca precise inspecionar exceções do
/// backend diretamente (docs/14_APIS_FUNCOES_E_EVENTOS.md, seção 11: "A UI
/// traduz o código para mensagem amigável; não exibe stack ou SQL").
DomainFailure mapSupabaseError(Object error) {
  if (error is DomainFailure) return error;

  if (error is PostgrestException) {
    final code = _wireNameFrom(error.message);
    if (code != null) {
      return DomainFailure(
        code,
        message: error.message,
        details: error.details is Map
            ? Map<String, Object?>.from(error.details as Map)
            : null,
      );
    }
    return DomainFailure(
      DomainErrorCode.validationError,
      message: error.message,
    );
  }

  if (error is FunctionException) {
    final body = error.details;
    final bodyCode = body is Map ? body['error'] as String? : null;
    final code = bodyCode != null ? _wireNameFrom(bodyCode) : null;
    return DomainFailure(
      code ?? DomainErrorCode.validationError,
      message: bodyCode ?? error.toString(),
    );
  }

  if (error is AuthException) {
    return DomainFailure(
      DomainErrorCode.validationError,
      message: _friendlyAuthMessage(error),
    );
  }

  return DomainFailure(
    DomainErrorCode.validationError,
    message: error.toString(),
  );
}

DomainErrorCode? _wireNameFrom(String message) {
  final trimmed = message.trim();
  final isKnown = DomainErrorCode.values.any((c) => c.wireName == trimmed);
  return isKnown ? DomainErrorCodeWireName.fromWireName(trimmed) : null;
}

String _friendlyAuthMessage(AuthException error) {
  final message = error.message.toLowerCase();
  if (message.contains('invalid login credentials')) {
    return 'E-mail ou senha incorretos.';
  }
  if (message.contains('already registered') ||
      message.contains('already exists')) {
    return 'Já existe uma conta com este e-mail.';
  }
  if (message.contains('password') && message.contains('least')) {
    return 'A senha não atende aos requisitos mínimos de segurança.';
  }
  if (message.contains('email not confirmed')) {
    return 'Confirme seu e-mail antes de entrar.';
  }
  return error.message;
}
