import 'package:admin_web/app/app.dart';
import 'package:data_access/data_access.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('sem sessão, o painel redireciona para o login administrativo', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: KidsTaskAdminApp()));
    await tester.pumpAndSettle();

    expect(find.text('Painel administrativo'), findsWidgets);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
  });
}
