import 'package:data_access/data_access.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'mapeia mensagem de PostgrestException que é um DomainErrorCode conhecido',
    () {
      final failure = mapSupabaseError(
        const PostgrestException(message: 'PLAN_CHILD_LIMIT'),
      );
      expect(failure.code, DomainErrorCode.planChildLimit);
    },
  );

  test(
    'PostgrestException com mensagem desconhecida vira VALIDATION_ERROR',
    () {
      final failure = mapSupabaseError(
        const PostgrestException(message: 'algum erro interno de sql'),
      );
      expect(failure.code, DomainErrorCode.validationError);
    },
  );

  test('FunctionException usa o campo error do corpo da resposta', () {
    final failure = mapSupabaseError(
      FunctionException(status: 401, details: {'error': 'AUTH_REQUIRED'}),
    );
    expect(failure.code, DomainErrorCode.authRequired);
  });

  test('AuthException de credenciais inválidas vira mensagem em pt-BR', () {
    final failure = mapSupabaseError(
      const AuthException('Invalid login credentials'),
    );
    expect(failure.message, 'E-mail ou senha incorretos.');
  });

  test('DomainFailure já mapeada é retornada sem alteração', () {
    const original = DomainFailure(DomainErrorCode.forbidden);
    expect(mapSupabaseError(original), same(original));
  });
}
