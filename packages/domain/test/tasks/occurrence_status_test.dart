import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('OccurrenceStatus', () {
    test('wireName corresponde ao identificador técnico do backend', () {
      expect(OccurrenceStatus.pending.wireName, 'pending');
      expect(OccurrenceStatus.awaitingApproval.wireName, 'awaiting_approval');
      expect(OccurrenceStatus.approved.wireName, 'approved');
      expect(OccurrenceStatus.late.wireName, 'late');
      expect(OccurrenceStatus.expired.wireName, 'expired');
      expect(OccurrenceStatus.needsCorrection.wireName, 'needs_correction');
      expect(OccurrenceStatus.cancelled.wireName, 'cancelled');
      expect(
        OccurrenceStatus.skippedByGuardian.wireName,
        'skipped_by_guardian',
      );
    });

    test('fromWireName é o inverso de wireName para todos os estados', () {
      for (final status in OccurrenceStatus.values) {
        expect(OccurrenceStatus.fromWireName(status.wireName), status);
      }
    });

    test('fromWireName rejeita valores desconhecidos', () {
      expect(
        () => OccurrenceStatus.fromWireName('unknown'),
        throwsArgumentError,
      );
    });

    test('apenas pending/late/needs_correction são isCompletable', () {
      expect(OccurrenceStatus.pending.isCompletable, isTrue);
      expect(OccurrenceStatus.late.isCompletable, isTrue);
      expect(OccurrenceStatus.needsCorrection.isCompletable, isTrue);
      expect(OccurrenceStatus.awaitingApproval.isCompletable, isFalse);
      expect(OccurrenceStatus.approved.isCompletable, isFalse);
      expect(OccurrenceStatus.expired.isCompletable, isFalse);
      expect(OccurrenceStatus.cancelled.isCompletable, isFalse);
      expect(OccurrenceStatus.skippedByGuardian.isCompletable, isFalse);
    });

    test('approved/expired/cancelled/skipped_by_guardian são isTerminal', () {
      expect(OccurrenceStatus.approved.isTerminal, isTrue);
      expect(OccurrenceStatus.expired.isTerminal, isTrue);
      expect(OccurrenceStatus.cancelled.isTerminal, isTrue);
      expect(OccurrenceStatus.skippedByGuardian.isTerminal, isTrue);
      expect(OccurrenceStatus.pending.isTerminal, isFalse);
      expect(OccurrenceStatus.late.isTerminal, isFalse);
      expect(OccurrenceStatus.awaitingApproval.isTerminal, isFalse);
      expect(OccurrenceStatus.needsCorrection.isTerminal, isFalse);
    });
  });
}
