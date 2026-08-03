import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/async_error_banner.dart';

const _statusLabels = {
  'requested': 'Solicitado',
  'approved': 'Aprovado',
  'rejected': 'Rejeitado',
  'delivered': 'Entregue',
  'cancelled': 'Cancelado',
};

/// Resgates solicitados e aprovados aguardando ação do responsável
/// (docs/05 seção 5).
class PendingRedemptionsPage extends ConsumerStatefulWidget {
  const PendingRedemptionsPage({super.key, required this.familyId});

  final String familyId;

  @override
  ConsumerState<PendingRedemptionsPage> createState() =>
      _PendingRedemptionsPageState();
}

class _PendingRedemptionsPageState
    extends ConsumerState<PendingRedemptionsPage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _redemptions = const [];
  Map<String, String> _childNames = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await ref
          .read(redemptionRepositoryProvider)
          .listForFamily(widget.familyId);
      final children = await ref
          .read(childRepositoryProvider)
          .listChildren(widget.familyId);
      setState(() {
        _redemptions = all
            .where(
              (r) => r['status'] == 'requested' || r['status'] == 'approved',
            )
            .toList();
        _childNames = {
          for (final child in children)
            child['id'] as String:
                (child['nickname'] as String?) ?? child['first_name'] as String,
        };
      });
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível carregar os resgates agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(Map<String, dynamic> redemption) async {
    try {
      await ref
          .read(redemptionRepositoryProvider)
          .reviewRedemption(
            redemptionId: redemption['id'] as String,
            decision: 'approve',
            idempotencyKey: newIdempotencyKey(),
            expectedVersion: redemption['version'] as int,
          );
      _load();
    } catch (_) {
      _showError('Não foi possível aprovar agora.');
    }
  }

  Future<void> _reject(Map<String, dynamic> redemption) async {
    final reason = await _promptForText('Motivo (opcional)');
    try {
      await ref
          .read(redemptionRepositoryProvider)
          .reviewRedemption(
            redemptionId: redemption['id'] as String,
            decision: 'reject',
            idempotencyKey: newIdempotencyKey(),
            expectedVersion: redemption['version'] as int,
            rejectionReason: reason,
          );
      _load();
    } catch (_) {
      _showError('Não foi possível rejeitar agora.');
    }
  }

  Future<void> _markDelivered(Map<String, dynamic> redemption) async {
    try {
      await ref
          .read(redemptionRepositoryProvider)
          .markDelivered(
            redemptionId: redemption['id'] as String,
            idempotencyKey: newIdempotencyKey(),
          );
      _load();
    } catch (_) {
      _showError('Não foi possível marcar como entregue agora.');
    }
  }

  Future<void> _cancel(Map<String, dynamic> redemption) async {
    final reason = await _promptForText('Motivo do cancelamento');
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await ref
          .read(redemptionRepositoryProvider)
          .cancelApproved(
            redemptionId: redemption['id'] as String,
            reason: reason.trim(),
            idempotencyKey: newIdempotencyKey(),
          );
      _load();
    } catch (_) {
      _showError('Não foi possível cancelar agora.');
    }
  }

  Future<String?> _promptForText(String label) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resgates')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    AsyncErrorBanner(message: _errorMessage!),
                  if (_redemptions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('Nenhum resgate pendente.')),
                    ),
                  ..._redemptions.map(_buildCard),
                ],
              ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> redemption) {
    final status = redemption['status'] as String;
    final childName = _childNames[redemption['child_id'] as String] ?? '—';
    final requested = status == 'requested';

    return Card(
      child: ListTile(
        title: Text(redemption['title_snapshot'] as String),
        subtitle: Text(
          '$childName · ${redemption['cost_snapshot']} KidsCoins · '
          '${_statusLabels[status] ?? status}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: requested
              ? [
                  IconButton(
                    onPressed: () => _reject(redemption),
                    icon: const Icon(Icons.close),
                    tooltip: 'Rejeitar',
                  ),
                  IconButton(
                    onPressed: () => _approve(redemption),
                    icon: const Icon(Icons.check),
                    tooltip: 'Aprovar',
                  ),
                ]
              : [
                  IconButton(
                    onPressed: () => _cancel(redemption),
                    icon: const Icon(Icons.undo),
                    tooltip: 'Cancelar (estorna)',
                  ),
                  IconButton(
                    onPressed: () => _markDelivered(redemption),
                    icon: const Icon(Icons.local_shipping_outlined),
                    tooltip: 'Marcar entregue',
                  ),
                ],
        ),
      ),
    );
  }
}
