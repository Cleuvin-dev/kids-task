import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/async_error_banner.dart';

/// Catálogo de recompensas da família: criar, editar, ativar/desativar
/// (docs/05 seção 4). Recompensa inativa some do catálogo da criança mas
/// permanece no histórico.
class GuardianRewardListPage extends ConsumerStatefulWidget {
  const GuardianRewardListPage({super.key, required this.familyId});

  final String familyId;

  @override
  ConsumerState<GuardianRewardListPage> createState() =>
      _GuardianRewardListPageState();
}

class _GuardianRewardListPageState
    extends ConsumerState<GuardianRewardListPage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _rewards = const [];
  Map<String, String> _childNames = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final rewards = await ref
          .read(rewardRepositoryProvider)
          .listAllForFamily(widget.familyId);
      final children = await ref
          .read(childRepositoryProvider)
          .listChildren(widget.familyId);
      setState(() {
        _rewards = rewards;
        _childNames = {
          for (final child in children)
            child['id'] as String:
                (child['nickname'] as String?) ?? child['first_name'] as String,
        };
      });
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível carregar as recompensas agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createNew() async {
    final saved = await context.push<bool>(
      '/guardian/rewards/new',
      extra: {'familyId': widget.familyId},
    );
    if (saved == true) _load();
  }

  Future<void> _edit(Map<String, dynamic> reward) async {
    final saved = await context.push<bool>(
      '/guardian/rewards/${reward['id']}/edit',
      extra: {'familyId': widget.familyId, 'reward': reward},
    );
    if (saved == true) _load();
  }

  Future<void> _toggleActive(Map<String, dynamic> reward) async {
    try {
      await ref
          .read(rewardRepositoryProvider)
          .setActive(reward['id'] as String, !(reward['active'] as bool));
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível atualizar agora.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recompensas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pending_actions_outlined),
            tooltip: 'Resgates pendentes',
            onPressed: () => context.push('/guardian/redemptions'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNew,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    AsyncErrorBanner(message: _errorMessage!),
                  if (_rewards.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text('Nenhuma recompensa cadastrada ainda.'),
                      ),
                    ),
                  ..._rewards.map(_buildRewardCard),
                ],
              ),
      ),
    );
  }

  Widget _buildRewardCard(Map<String, dynamic> reward) {
    final active = reward['active'] as bool;
    final childId = reward['child_id'] as String?;
    final scope = childId == null
        ? 'Toda a família'
        : (_childNames[childId] ?? 'Criança');

    return Card(
      child: ListTile(
        leading: Icon(
          Icons.card_giftcard_outlined,
          color: active ? null : Theme.of(context).disabledColor,
        ),
        title: Text(reward['title'] as String),
        subtitle: Text(
          '${reward['cost_coins']} KidsCoins · $scope'
          '${active ? '' : ' · inativa'}',
        ),
        onTap: () => _edit(reward),
        trailing: Switch(
          value: active,
          onChanged: (_) => _toggleActive(reward),
        ),
      ),
    );
  }
}
