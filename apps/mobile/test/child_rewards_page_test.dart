import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/child_home/child_rewards_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWalletRepository extends WalletRepository {
  _FakeWalletRepository(super.client, this._balance);

  final int _balance;

  @override
  Future<Map<String, dynamic>?> fetchWallet(String childId) async => {
    'child_id': childId,
    'coin_balance': _balance,
    'total_xp': 0,
  };
}

class _FakeRewardRepository extends RewardRepository {
  _FakeRewardRepository(super.client, this._rewards);

  final List<Map<String, dynamic>> _rewards;

  @override
  Future<List<Map<String, dynamic>>> listActiveForChild(String childId) async =>
      _rewards;
}

class _FakeRedemptionRepository extends RedemptionRepository {
  _FakeRedemptionRepository(super.client);

  @override
  Future<List<Map<String, dynamic>>> listForChild(String childId) async => [];
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

  testWidgets('desabilita "Resgatar" quando o saldo é insuficiente', (
    tester,
  ) async {
    final rewards = [
      {'id': 'reward-1', 'title': 'Passeio ao parque', 'cost_coins': 100},
      {'id': 'reward-2', 'title': 'Escolher o filme', 'cost_coins': 5},
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(
            _FakeWalletRepository(KidsTaskSupabase.client, 10),
          ),
          rewardRepositoryProvider.overrideWithValue(
            _FakeRewardRepository(KidsTaskSupabase.client, rewards),
          ),
          redemptionRepositoryProvider.overrideWithValue(
            _FakeRedemptionRepository(KidsTaskSupabase.client),
          ),
        ],
        child: const MaterialApp(home: ChildRewardsPage(childId: 'child-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('10 KidsCoins'), findsOneWidget);

    final expensiveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Resgatar').first,
    );
    final cheapButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Resgatar').last,
    );

    expect(expensiveButton.onPressed, isNull);
    expect(cheapButton.onPressed, isNotNull);
  });
}
