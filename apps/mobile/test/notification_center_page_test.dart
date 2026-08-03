import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/notification_center_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationRepository extends NotificationRepository {
  _FakeNotificationRepository(super.client, this._notifications);

  final List<Map<String, dynamic>> _notifications;

  @override
  Future<List<Map<String, dynamic>>> listNotifications() async =>
      _notifications;
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

  testWidgets('mostra título e corpo de cada notificação', (tester) async {
    final notifications = [
      {
        'id': 'notif-1',
        'title': 'Tarefa aprovada!',
        'body': 'Escovar os dentes',
        'read_at': null,
      },
      {
        'id': 'notif-2',
        'title': 'Você subiu de nível!',
        'body': 'Agora você está no nível 2',
        'read_at': '2026-08-03T10:00:00Z',
      },
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(
            _FakeNotificationRepository(KidsTaskSupabase.client, notifications),
          ),
        ],
        child: const MaterialApp(home: NotificationCenterPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tarefa aprovada!'), findsOneWidget);
    expect(find.text('Escovar os dentes'), findsOneWidget);
    expect(find.text('Você subiu de nível!'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none), findsOneWidget);
  });
}
