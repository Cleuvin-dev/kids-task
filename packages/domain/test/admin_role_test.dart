import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('AdminRole', () {
    test('wireName corresponde ao identificador técnico do backend', () {
      expect(AdminRole.superAdmin.wireName, 'super_admin');
      expect(AdminRole.support.wireName, 'support');
      expect(AdminRole.content.wireName, 'content');
      expect(AdminRole.billing.wireName, 'billing');
    });

    test('fromWireName é o inverso de wireName para todos os papéis', () {
      for (final role in AdminRole.values) {
        expect(AdminRole.fromWireName(role.wireName), role);
      }
    });

    test('fromWireName rejeita valores desconhecidos', () {
      expect(() => AdminRole.fromWireName('unknown'), throwsArgumentError);
    });
  });
}
