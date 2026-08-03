import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('RedemptionStatus', () {
    test('wireName corresponde ao identificador técnico do backend', () {
      expect(RedemptionStatus.requested.wireName, 'requested');
      expect(RedemptionStatus.approved.wireName, 'approved');
      expect(RedemptionStatus.rejected.wireName, 'rejected');
      expect(RedemptionStatus.delivered.wireName, 'delivered');
      expect(RedemptionStatus.cancelled.wireName, 'cancelled');
    });

    test('fromWireName é o inverso de wireName para todos os estados', () {
      for (final status in RedemptionStatus.values) {
        expect(RedemptionStatus.fromWireName(status.wireName), status);
      }
    });

    test('fromWireName rejeita valores desconhecidos', () {
      expect(
        () => RedemptionStatus.fromWireName('unknown'),
        throwsArgumentError,
      );
    });

    test('apenas approved é isApprovedPending', () {
      expect(RedemptionStatus.approved.isApprovedPending, isTrue);
      expect(RedemptionStatus.requested.isApprovedPending, isFalse);
      expect(RedemptionStatus.delivered.isApprovedPending, isFalse);
    });

    test('rejected/delivered/cancelled são isTerminal', () {
      expect(RedemptionStatus.rejected.isTerminal, isTrue);
      expect(RedemptionStatus.delivered.isTerminal, isTrue);
      expect(RedemptionStatus.cancelled.isTerminal, isTrue);
      expect(RedemptionStatus.requested.isTerminal, isFalse);
      expect(RedemptionStatus.approved.isTerminal, isFalse);
    });
  });
}
