import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';

void main() {
  testWidgets('app de fundação sobe e mostra o título Kid\'s Task', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: KidsTaskApp()));
    await tester.pumpAndSettle();

    expect(find.text("Kid's Task"), findsOneWidget);
  });
}
