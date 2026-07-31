import 'package:data_access/data_access.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await KidsTaskSupabase.initialize(
      const SupabaseEnv(
        url: 'https://example.supabase.co',
        publishableKey: 'test-key',
      ),
    );
  });

  testWidgets('sem sessão, o app redireciona para a tela de acesso comum', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: KidsTaskApp()));
    await tester.pumpAndSettle();

    expect(find.text('Sou responsável'), findsOneWidget);
    expect(find.text('Sou criança'), findsOneWidget);
  });
}
