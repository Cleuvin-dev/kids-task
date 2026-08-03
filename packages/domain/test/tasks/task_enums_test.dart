import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('TaskPeriod', () {
    test('wireName e fromWireName são inversos', () {
      for (final period in TaskPeriod.values) {
        expect(TaskPeriod.fromWireName(period.wireName), period);
      }
      expect(TaskPeriod.afternoonEvening.wireName, 'afternoon_evening');
    });

    test('fromWireName rejeita valores desconhecidos', () {
      expect(() => TaskPeriod.fromWireName('unknown'), throwsArgumentError);
    });
  });

  group('ApprovalMode', () {
    test('wireName e fromWireName são inversos', () {
      for (final mode in ApprovalMode.values) {
        expect(ApprovalMode.fromWireName(mode.wireName), mode);
      }
    });

    test('fromWireName rejeita valores desconhecidos', () {
      expect(() => ApprovalMode.fromWireName('unknown'), throwsArgumentError);
    });
  });

  group('LatePolicy', () {
    test('wireName e fromWireName são inversos', () {
      for (final policy in LatePolicy.values) {
        expect(LatePolicy.fromWireName(policy.wireName), policy);
      }
      expect(LatePolicy.expireNoReward.wireName, 'expire_no_reward');
    });

    test('fromWireName rejeita valores desconhecidos', () {
      expect(() => LatePolicy.fromWireName('unknown'), throwsArgumentError);
    });
  });

  group('ScheduleType', () {
    test('wireName e fromWireName são inversos', () {
      for (final type in ScheduleType.values) {
        expect(ScheduleType.fromWireName(type.wireName), type);
      }
    });

    test('fromWireName rejeita valores desconhecidos', () {
      expect(() => ScheduleType.fromWireName('unknown'), throwsArgumentError);
    });
  });
}
