import 'dart:math';

import 'package:data_access/data_access.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'child_today_section.dart';

/// Início real da criança: nome, avatar e a tela "Hoje" com as tarefas do
/// dia (docs/04). KidsCoins/XP acumulados e recompensas chegam nos
/// próximos marcos.
class ChildHomePage extends ConsumerStatefulWidget {
  const ChildHomePage({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<ChildHomePage> createState() => _ChildHomePageState();
}

class _ChildHomePageState extends ConsumerState<ChildHomePage> {
  bool _loading = true;
  Map<String, dynamic>? _child;
  int _coinBalance = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final child = await ref
          .read(supabaseClientProvider)
          .from('child_profiles')
          .select('first_name, nickname, avatar_id')
          .eq('id', widget.childId)
          .single();
      final wallet = await ref
          .read(walletRepositoryProvider)
          .fetchWallet(widget.childId);
      setState(() {
        _child = child;
        _coinBalance = wallet?['coin_balance'] as int? ?? 0;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestExit() async {
    final a = 2 + Random().nextInt(7);
    final b = 2 + Random().nextInt(7);
    final controller = TextEditingController();
    final answer = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pergunta para um responsável'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quanto é $a + $b?'),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(controller.text)),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (answer == a + b) {
      await ref.read(supabaseClientProvider).auth.signOut();
      ref.invalidate(resolvedSessionProvider);
      if (mounted) context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final child = _child;
    final avatar = childAvatarById(child?['avatar_id'] as String? ?? 'default');
    final name =
        (child?['nickname'] as String?) ??
        (child?['first_name'] as String? ?? '');

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: _requestExit,
                icon: const Icon(Icons.logout),
              ),
            ),
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: avatar.color,
                    child: Icon(avatar.icon, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Oi, $name!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.savings_outlined),
                title: Text('$_coinBalance KidsCoins'),
                trailing: FilledButton.tonal(
                  onPressed: () => context.push('/child/rewards'),
                  child: const Text('Recompensas'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Hoje', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ChildTodaySection(childId: widget.childId),
          ],
        ),
      ),
    );
  }
}
