import 'package:meta/meta.dart';

import 'domain_error_code.dart';

/// Falha de domínio esperada, carregando o [DomainErrorCode] estável e uma
/// mensagem técnica (não destinada diretamente ao usuário final).
@immutable
class DomainFailure implements Exception {
  const DomainFailure(this.code, {this.message, this.details});

  final DomainErrorCode code;

  /// Mensagem técnica para logs/depuração, nunca exibida crua na UI.
  final String? message;

  /// Contexto adicional não sensível (ex.: campo inválido).
  final Map<String, Object?>? details;

  @override
  String toString() =>
      'DomainFailure(${code.wireName}${message != null ? ': $message' : ''})';

  @override
  bool operator ==(Object other) =>
      other is DomainFailure && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);
}
