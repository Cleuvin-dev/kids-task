import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('UserRole', () {
    test('wireName corresponde ao identificador técnico do backend', () {
      expect(UserRole.familyOwner.wireName, 'family_owner');
      expect(UserRole.familyGuardian.wireName, 'family_guardian');
      expect(UserRole.child.wireName, 'child');
      expect(UserRole.platformAdmin.wireName, 'platform_admin');
    });

    test('fromWireName é o inverso de wireName para todos os papéis', () {
      for (final role in UserRole.values) {
        expect(UserRole.fromWireName(role.wireName), role);
      }
    });

    test('fromWireName rejeita valores desconhecidos', () {
      expect(() => UserRole.fromWireName('unknown'), throwsArgumentError);
    });

    test('apenas responsáveis são isGuardian', () {
      expect(UserRole.familyOwner.isGuardian, isTrue);
      expect(UserRole.familyGuardian.isGuardian, isTrue);
      expect(UserRole.child.isGuardian, isFalse);
      expect(UserRole.platformAdmin.isGuardian, isFalse);
    });
  });
}
