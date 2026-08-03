import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/child_home/child_today_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeOccurrenceRepository extends OccurrenceRepository {
  _FakeOccurrenceRepository(super.client, this._occurrences);

  final List<Map<String, dynamic>> _occurrences;

  @override
  Future<List<Map<String, dynamic>>> listToday({
    String? childId,
    String? familyId,
  }) async => _occurrences;

  @override
  Stream<void> watchChildOccurrences(String childId) => const Stream.empty();
}

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

  testWidgets('mostra estados corretos por ocorrência', (tester) async {
    final occurrences = [
      {
        'id': 'occ-1',
        'status': 'pending',
        'title_snapshot': 'Escovar os dentes',
        'coin_reward_snapshot': 5,
        'version': 1,
      },
      {
        'id': 'occ-2',
        'status': 'awaiting_approval',
        'title_snapshot': 'Arrumar o quarto',
        'coin_reward_snapshot': 8,
        'version': 2,
      },
      {
        'id': 'occ-3',
        'status': 'needs_correction',
        'title_snapshot': 'Ler um livro',
        'coin_reward_snapshot': 3,
        'version': 3,
        'rejection_reason': 'Capriche mais',
      },
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          occurrenceRepositoryProvider.overrideWithValue(
            _FakeOccurrenceRepository(KidsTaskSupabase.client, occurrences),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ChildTodaySection(childId: 'child-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Escovar os dentes'), findsOneWidget);
    expect(find.text('Aguardando aprovação'), findsOneWidget);
    expect(find.text('Motivo: Capriche mais'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Concluir'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Corrigir e reenviar'),
      findsOneWidget,
    );
  });
}
