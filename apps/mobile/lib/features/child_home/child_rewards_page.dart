import 'package:data_access/data_access.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _statusLabels = {
  'requested': 'Aguardando o responsável',
  'approved': 'Aprovado, em preparo',
  'rejected': 'Não aprovado desta vez',
  'delivered': 'Entregue',
  'cancelled': 'Cancelado',
};

/// Catálogo de recompensas da criança e seus próprios pedidos
/// (docs/05 seções 4-5).
class ChildRewardsPage extends ConsumerStatefulWidget {
  const ChildRewardsPage({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<ChildRewardsPage> createState() => _ChildRewardsPageState();
}

class _ChildRewardsPageState extends ConsumerState<ChildRewardsPage> {
  bool _loading = true;
  int _coinBalance = 0;
  List<Map<String, dynamic>> _rewards = const [];
  List<Map<String, dynamic>> _myRedemptions = const [];
  final Set<String> _requesting = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final wallet = await ref
          .read(walletRepositoryProvider)
          .fetchWallet(widget.childId);
      final rewards = await ref
          .read(rewardRepositoryProvider)
          .listActiveForChild(widget.childId);
      final redemptions = await ref
          .read(redemptionRepositoryProvider)
          .listForChild(widget.childId);
      if (mounted) {
        setState(() {
          _coinBalance = wallet?['coin_balance'] as int? ?? 0;
          _rewards = rewards;
          _myRedemptions = redemptions;
        });
      }
    } catch (_) {
      // Falha silenciosa: tela mostra o último estado carregado.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request(Map<String, dynamic> reward) async {
    final rewardId = reward['id'] as String;
    setState(() => _requesting.add(rewardId));
    try {
      await ref
          .read(redemptionRepositoryProvider)
          .requestRedemption(
            rewardId: rewardId,
            idempotencyKey: newIdempotencyKey(),
          );
    } on DomainFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == DomainErrorCode.insufficientCoins
                  ? 'Ainda não tem KidsCoins suficientes para essa recompensa.'
                  : 'Não foi possível pedir essa recompensa agora.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting.remove(rewardId));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recompensas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.savings_outlined),
                      title: const Text('Seu saldo'),
                      trailing: Text(
                        '$_coinBalance KidsCoins',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Catálogo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_rewards.isEmpty) const Text('Nada por aqui ainda.'),
                  ..._rewards.map((reward) {
                    final cost = reward['cost_coins'] as int;
                    final canAfford = _coinBalance >= cost;
                    final isRequesting = _requesting.contains(reward['id']);
                    return Card(
                      child: ListTile(
                        title: Text(reward['title'] as String),
                        subtitle: Text('$cost KidsCoins'),
                        trailing: FilledButton(
                          onPressed: (!canAfford || isRequesting)
                              ? null
                              : () => _request(reward),
                          child: isRequesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Resgatar'),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  Text(
                    'Meus pedidos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_myRedemptions.isEmpty)
                    const Text('Você ainda não pediu nenhuma recompensa.'),
                  ..._myRedemptions.map(
                    (redemption) => Card(
                      child: ListTile(
                        title: Text(redemption['title_snapshot'] as String),
                        subtitle: Text(
                          _statusLabels[redemption['status']] ??
                              redemption['status'] as String,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
