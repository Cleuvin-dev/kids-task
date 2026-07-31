import 'package:admin_web/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('painel de fundação sobe e mostra o título do admin', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: KidsTaskAdminApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining("Kid's Task"), findsOneWidget);
  });
}
