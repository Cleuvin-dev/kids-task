import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('DomainErrorCode', () {
    test('todos os códigos exportam wireName em maiúsculas com underscore', () {
      for (final code in DomainErrorCode.values) {
        expect(code.wireName, matches(RegExp(r'^[A-Z_]+$')));
      }
    });

    test('fromWireName reconhece PLAN_DAILY_TASK_LIMIT', () {
      expect(
        DomainErrorCodeWireName.fromWireName('PLAN_DAILY_TASK_LIMIT'),
        DomainErrorCode.planDailyTaskLimit,
      );
    });
  });

  group('Result', () {
    test('Ok carrega o valor', () {
      const result = Result<int>.ok(42);
      expect(result.isOk, isTrue);
      expect(result.when(ok: (v) => v, err: (_) => -1), 42);
    });

    test('Err carrega a falha', () {
      const failure = DomainFailure(DomainErrorCode.insufficientCoins);
      final result = Result<int>.err(failure);
      expect(result.isErr, isTrue);
      expect(result.when(ok: (_) => null, err: (f) => f), failure);
    });
  });
}
