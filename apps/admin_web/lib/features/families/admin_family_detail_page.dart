import 'package:data_access/data_access.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/async_error_banner.dart';
import 'admin_family_search_page.dart' show familyStatusLabel;

final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

const _ageModeLabels = {
  'young': '2–7 anos',
  'middle': '8–10 anos',
  'teen': '11–13+ anos',
};

/// Alterar o status de uma família nunca oferece "excluída" como destino
/// direto por engano de clique: as opções mais usadas pelo suporte
/// (docs/12 seção 11) vêm primeiro, mas todos os estados válidos aparecem
/// — a função no banco já valida tudo de novo.
const _statusOrder = [
  'active',
  'restricted',
  'blocked',
  'deletion_pending',
  'deleted',
];

/// Detalhe de família (docs/12 seções 4 e 11): responsáveis, plano,
/// crianças (identidade oculta até revelar com justificativa), aparelhos,
/// consentimentos e alteração de status.
class AdminFamilyDetailPage extends ConsumerStatefulWidget {
  const AdminFamilyDetailPage({super.key, required this.familyId});

  final String familyId;

  @override
  ConsumerState<AdminFamilyDetailPage> createState() =>
      _AdminFamilyDetailPageState();
}

class _AdminFamilyDetailPageState extends ConsumerState<AdminFamilyDetailPage> {
  bool _loading = true;
  String? _errorMessage;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _children = const [];
  List<Map<String, dynamic>> _devices = const [];
  List<Map<String, dynamic>> _consents = const [];
  final Map<String, Map<String, dynamic>> _revealedChildren = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(adminFamilyRepositoryProvider);
      final summaryResults = await repo.searchFamilies(widget.familyId);
      final children = await repo.listChildren(widget.familyId);
      final childIds = children.map((c) => c['child_id'] as String).toList();
      final devices = await repo.listDevices(childIds);
      final consents = await repo.listConsents(widget.familyId);
      setState(() {
        _summary = summaryResults.isEmpty ? null : summaryResults.first;
        _children = children;
        _devices = devices;
        _consents = consents;
        _errorMessage = null;
      });
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível carregar a família agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revealChild(String childId) async {
    final justification = await showDialog<String>(
      context: context,
      builder: (context) => const _JustificationDialog(
        title: 'Revelar identidade da criança',
        description:
            'A identidade fica visível só nesta sessão do painel e a ação '
            'é registrada na auditoria.',
        actionLabel: 'Revelar',
      ),
    );
    if (justification == null || justification.trim().isEmpty) return;
    try {
      final identity = await ref
          .read(adminFamilyRepositoryProvider)
          .revealChildIdentity(
            childId: childId,
            justification: justification.trim(),
          );
      setState(() => _revealedChildren[childId] = identity);
    } on DomainFailure catch (e) {
      _showError(e.message ?? 'Não foi possível revelar a identidade agora.');
    }
  }

  Future<void> _changeStatus() async {
    final currentStatus = _summary?['status'] as String?;
    final result = await showDialog<_StatusChangeInput>(
      context: context,
      builder: (context) => _ChangeStatusDialog(currentStatus: currentStatus),
    );
    if (result == null) return;
    try {
      await ref
          .read(adminFamilyRepositoryProvider)
          .setFamilyStatus(
            familyId: widget.familyId,
            newStatus: result.newStatus,
            reason: result.reason,
            idempotencyKey: newIdempotencyKey(),
          );
      await _load();
    } on DomainFailure catch (e) {
      _showError(e.message ?? 'Não foi possível alterar o status agora.');
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
    final summary = _summary;

    return Scaffold(
      appBar: AppBar(
        title: Text(summary?['family_name'] as String? ?? 'Família'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    AsyncErrorBanner(message: _errorMessage!),
                  if (summary == null)
                    const Text('Família não encontrada.')
                  else ...[
                    _buildOverviewCard(summary),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _changeStatus,
                      child: const Text('Alterar status'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Crianças',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_children.isEmpty)
                      const Text('Nenhuma criança cadastrada.'),
                    ..._children.map(_buildChildTile),
                    const SizedBox(height: 24),
                    Text(
                      'Aparelhos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_devices.isEmpty) const Text('Nenhum aparelho.'),
                    ..._devices.map(_buildDeviceTile),
                    const SizedBox(height: 24),
                    Text(
                      'Consentimentos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_consents.isEmpty) const Text('Nenhum registro.'),
                    ..._consents.map(_buildConsentTile),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCard(Map<String, dynamic> summary) {
    final guardianEmails = List<String>.from(
      summary['guardian_emails'] as List? ?? const [],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${familyStatusLabel(summary['status'] as String?)}'),
            const SizedBox(height: 4),
            Text('Plano: ${_planLabel(summary['plan_code'] as String?)}'),
            const SizedBox(height: 4),
            Text('Responsáveis: ${guardianEmails.join(', ')}'),
            const SizedBox(height: 4),
            Text('Crianças: ${summary['children_count']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildChildTile(Map<String, dynamic> child) {
    final childId = child['child_id'] as String;
    final revealed = _revealedChildren[childId];
    final title = revealed == null
        ? 'Criança (identidade oculta)'
        : '${revealed['first_name']}'
              '${revealed['nickname'] != null ? ' (${revealed['nickname']})' : ''}';
    return ListTile(
      title: Text(title),
      subtitle: Text(
        '${familyStatusLabel(child['status'] as String?)} · '
        '${_ageModeLabels[child['age_mode']] ?? child['age_mode']}',
      ),
      trailing: revealed == null
          ? TextButton(
              onPressed: () => _revealChild(childId),
              child: const Text('Revelar identidade'),
            )
          : null,
    );
  }

  Widget _buildDeviceTile(Map<String, dynamic> device) {
    final revokedAt = device['revoked_at'] as String?;
    return ListTile(
      title: Text(device['device_name'] as String),
      subtitle: Text(
        revokedAt == null
            ? 'Ativo · última atividade ${_dateFormat.format(DateTime.parse(device['last_seen_at'] as String).toLocal())}'
            : 'Revogado em ${_dateFormat.format(DateTime.parse(revokedAt).toLocal())}',
      ),
    );
  }

  Widget _buildConsentTile(Map<String, dynamic> consent) {
    return ListTile(
      title: Text('${consent['document']} · v${consent['document_version']}'),
      subtitle: Text(
        '${consent['purpose']} · ${consent['status']} · '
        '${_dateFormat.format(DateTime.parse(consent['created_at'] as String).toLocal())}',
      ),
    );
  }
}

String _planLabel(String? planCode) => switch (planCode) {
  'premium' => 'Premium',
  'free' => 'Gratuito',
  _ => planCode ?? '—',
};

class _JustificationDialog extends StatefulWidget {
  const _JustificationDialog({
    required this.title,
    required this.description,
    required this.actionLabel,
  });

  final String title;
  final String description;
  final String actionLabel;

  @override
  State<_JustificationDialog> createState() => _JustificationDialogState();
}

class _JustificationDialogState extends State<_JustificationDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.description),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
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
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}

class _StatusChangeInput {
  const _StatusChangeInput({required this.newStatus, required this.reason});

  final String newStatus;
  final String reason;
}

class _ChangeStatusDialog extends StatefulWidget {
  const _ChangeStatusDialog({required this.currentStatus});

  final String? currentStatus;

  @override
  State<_ChangeStatusDialog> createState() => _ChangeStatusDialogState();
}

class _ChangeStatusDialogState extends State<_ChangeStatusDialog> {
  final _reasonController = TextEditingController();
  String? _newStatus;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = _statusOrder
        .where((status) => status != widget.currentStatus)
        .toList();

    return AlertDialog(
      title: const Text('Alterar status da família'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Não apaga nenhum dado. Bloquear/excluir revoga os aparelhos '
            'infantis vinculados e notifica os responsáveis.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _newStatus,
            decoration: const InputDecoration(labelText: 'Novo status'),
            items: options
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(familyStatusLabel(status)),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _newStatus = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(labelText: 'Motivo'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _newStatus == null
              ? null
              : () => Navigator.of(context).pop(
                  _StatusChangeInput(
                    newStatus: _newStatus!,
                    reason: _reasonController.text.trim(),
                  ),
                ),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
