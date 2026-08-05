import 'package:data_access/data_access.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke test de integração real (docs/15 seção 1: "Integração Flutter |
/// onboarding e fluxos críticos"), rodando num binding de app de verdade
/// em vez do sandbox de `flutter_test` — mesmo teste de
/// `test/widget_test.dart`, mas executável em dispositivo/navegador real
/// (`flutter test integration_test`).
///
/// Fluxos além da tela de acesso comum (onboarding, tarefas, aprovação)
/// exigem falar com um backend de verdade — `KidsTaskSupabase` aqui usa a
/// mesma URL placeholder de todo o projeto (nenhum projeto Supabase real
/// existe ainda, ver docs/IMPLEMENTATION_STATUS.md "Bloqueios") — então
/// ficam fora deste smoke test até existir um projeto real para apontar.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('o app abre e mostra a tela de acesso comum', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await KidsTaskSupabase.initialize(
      const SupabaseEnv(
        url: 'https://example.supabase.co',
        publishableKey: 'test-key',
      ),
    );

    await tester.pumpWidget(const ProviderScope(child: KidsTaskApp()));
    await tester.pumpAndSettle();

    expect(find.text('Sou responsável'), findsOneWidget);
    expect(find.text('Sou criança'), findsOneWidget);
  });
}
