import 'package:data_access/data_access.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/async_error_banner.dart';

const _statusLabels = {
  'free': 'Gratuito',
  'trialing': 'Período de teste',
  'active': 'Ativa',
  'grace_period': 'Carência',
  'billing_retry': 'Tentando cobrar de novo',
  'cancelled_active_until_end': 'Cancelada (ativa até o fim do período)',
  'expired': 'Expirada',
  'revoked': 'Revogada',
  'support_override': 'Override de suporte',
};

const _eventTypeLabels = {
  'purchase': 'Compra',
  'renewal': 'Renovação',
  'cancellation': 'Cancelamento',
  'expiration': 'Expiração',
  'refund': 'Reembolso',
  'revocation': 'Revogação',
  'product_change': 'Troca de produto',
  'grace_period_started': 'Início de carência',
  'billing_recovered': 'Cobrança recuperada',
  'verification': 'Verificação',
  'restore': 'Restauração',
  'support_override_granted': 'Override concedido',
  'support_override_revoked': 'Override revogado',
  'safe_downgrade_applied': 'Downgrade seguro aplicado',
};

final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

/// Detalhe de assinatura de uma família (docs/12 seção 5): plano efetivo,
/// estado, eventos recentes e override de suporte (conceder/revogar).
class AdminSubscriptionDetailPage extends ConsumerStatefulWidget {
  const AdminSubscriptionDetailPage({
    super.key,
    required this.familyId,
    required this.familyName,
  });

  final String familyId;
  final String? familyName;

  @override
  ConsumerState<AdminSubscriptionDetailPage> createState() =>
      _AdminSubscriptionDetailPageState();
}

class _AdminSubscriptionDetailPageState
    extends ConsumerState<AdminSubscriptionDetailPage> {
  bool _loading = true;
  String? _errorMessage;
  Map<String, dynamic>? _entitlements;
  Map<String, dynamic>? _subscription;
  List<Map<String, dynamic>> _events = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(adminSubscriptionRepositoryProvider);
      final entitlements = await repo.fetchEntitlements(widget.familyId);
      final subscription = await repo.fetchSubscription(widget.familyId);
      final events = await repo.fetchRecentEvents(widget.familyId);
      setState(() {
        _entitlements = entitlements;
        _subscription = subscription;
        _events = events;
        _errorMessage = null;
      });
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível carregar a assinatura agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _grantOverride() async {
    final result = await showDialog<_OverrideGrantInput>(
      context: context,
      builder: (context) => const _GrantOverrideDialog(),
    );
    if (result == null) return;
    try {
      await ref
          .read(adminSubscriptionRepositoryProvider)
          .grantOverride(
            familyId: widget.familyId,
            expiresAt: result.expiresAt,
            justification: result.justification,
            idempotencyKey: newIdempotencyKey(),
          );
      await _load();
    } on DomainFailure catch (e) {
      _showError(e.message ?? 'Não foi possível conceder o override agora.');
    }
  }

  Future<void> _revokeOverride() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _RevokeOverrideDialog(),
    );
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await ref
          .read(adminSubscriptionRepositoryProvider)
          .revokeOverride(
            familyId: widget.familyId,
            reason: reason.trim(),
            idempotencyKey: newIdempotencyKey(),
          );
      await _load();
    } on DomainFailure catch (e) {
      _showError(e.message ?? 'Não foi possível revogar o override agora.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final subscription = _subscription;
    final isOverride = subscription?['status'] == 'support_override';

    return Scaffold(
      appBar: AppBar(title: Text(widget.familyName ?? 'Assinatura')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    AsyncErrorBanner(message: _errorMessage!),
                  if (subscription == null)
                    const Text('Assinatura não encontrada.')
                  else ...[
                    _buildOverviewCard(subscription),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: isOverride ? _revokeOverride : _grantOverride,
                      child: Text(
                        isOverride
                            ? 'Revogar override de suporte'
                            : 'Conceder override de suporte',
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Eventos recentes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_events.isEmpty) const Text('Nenhum evento ainda.'),
                    ..._events.map(_buildEventTile),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCard(Map<String, dynamic> subscription) {
    final effectivePlan = _entitlements?['effective_plan_code'] as String?;
    final currentPeriodEnd = subscription['current_period_end'] as String?;
    final graceEnd = subscription['grace_period_end'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plano efetivo: ${_planLabel(effectivePlan)}'),
            const SizedBox(height: 4),
            Text(
              'Estado da assinatura: '
              '${_statusLabels[subscription['status']] ?? subscription['status']}',
            ),
            const SizedBox(height: 4),
            Text('Loja: ${subscription['store']}'),
            if (subscription['product_id'] != null) ...[
              const SizedBox(height: 4),
              Text('Produto: ${subscription['product_id']}'),
            ],
            if (currentPeriodEnd != null) ...[
              const SizedBox(height: 4),
              Text(
                'Válida até: ${_dateFormat.format(DateTime.parse(currentPeriodEnd).toLocal())}',
              ),
            ],
            if (graceEnd != null) ...[
              const SizedBox(height: 4),
              Text(
                'Carência até: ${_dateFormat.format(DateTime.parse(graceEnd).toLocal())}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventTile(Map<String, dynamic> event) {
    final createdAt = DateTime.parse(event['created_at'] as String).toLocal();
    return ListTile(
      title: Text(
        _eventTypeLabels[event['event_type'] as String] ??
            event['event_type'] as String,
      ),
      subtitle: Text('${event['store']} · ${_dateFormat.format(createdAt)}'),
    );
  }
}

String _planLabel(String? planCode) => switch (planCode) {
  'premium' => 'Premium',
  'free' => 'Gratuito',
  _ => planCode ?? '—',
};

class _OverrideGrantInput {
  const _OverrideGrantInput({
    required this.expiresAt,
    required this.justification,
  });

  final DateTime expiresAt;
  final String justification;
}

class _GrantOverrideDialog extends StatefulWidget {
  const _GrantOverrideDialog();

  @override
  State<_GrantOverrideDialog> createState() => _GrantOverrideDialogState();
}

class _GrantOverrideDialogState extends State<_GrantOverrideDialog> {
  final _justificationController = TextEditingController();
  DateTime? _expiresAt;

  @override
  void dispose() {
    _justificationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Conceder override de suporte'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Não representa um pagamento real — só libera o Premium até a '
            'data escolhida, com justificativa registrada na auditoria.',
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _pickDate,
            child: Text(
              _expiresAt == null
                  ? 'Escolher data de expiração'
                  : 'Expira em ${_dateFormat.format(_expiresAt!)}',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _justificationController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Justificativa'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _expiresAt == null
              ? null
              : () => Navigator.of(context).pop(
                  _OverrideGrantInput(
                    expiresAt: _expiresAt!,
                    justification: _justificationController.text.trim(),
                  ),
                ),
          child: const Text('Conceder'),
        ),
      ],
    );
  }
}

class _RevokeOverrideDialog extends StatefulWidget {
  const _RevokeOverrideDialog();

  @override
  State<_RevokeOverrideDialog> createState() => _RevokeOverrideDialogState();
}

class _RevokeOverrideDialogState extends State<_RevokeOverrideDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Revogar override de suporte'),
      content: TextField(
        controller: _reasonController,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Motivo'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_reasonController.text),
          child: const Text('Revogar'),
        ),
      ],
    );
  }
}
