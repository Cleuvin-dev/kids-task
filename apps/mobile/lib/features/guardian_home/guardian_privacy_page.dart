import 'dart:convert';

import 'package:data_access/data_access.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/async_error_banner.dart';

final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
const _jsonEncoder = JsonEncoder.withIndent('  ');

const _deletionStatusLabels = {
  'pending_approval': 'Aguardando aprovação do outro responsável',
  'approved': 'Aprovada — agendada',
};

/// Direitos de privacidade do responsável (docs/10 seção 12): ver
/// consentimentos, exportar dados e solicitar/aprovar/cancelar a exclusão
/// da família (docs/10 seção 10).
class GuardianPrivacyPage extends ConsumerStatefulWidget {
  const GuardianPrivacyPage({super.key, required this.familyId});

  final String familyId;

  @override
  ConsumerState<GuardianPrivacyPage> createState() =>
      _GuardianPrivacyPageState();
}

class _GuardianPrivacyPageState extends ConsumerState<GuardianPrivacyPage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _consents = const [];
  Map<String, dynamic>? _deletionRequest;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(privacyRepositoryProvider);
      final consents = await repo.listConsents(widget.familyId);
      final deletionRequest = await repo.fetchActiveDeletionRequest(
        widget.familyId,
      );
      setState(() {
        _consents = consents;
        _deletionRequest = deletionRequest;
        _errorMessage = null;
      });
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível carregar esta tela agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportData() async {
    try {
      final data = await ref.read(privacyRepositoryProvider).exportFamilyData();
      if (!mounted) return;
      final text = _jsonEncoder.convert(data);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Seus dados'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: SelectableText(text)),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Copiado.')));
                }
              },
              child: const Text('Copiar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } on DomainFailure catch (e) {
      _showError(e.message ?? 'Não foi possível exportar seus dados agora.');
    }
  }

  Future<void> _requestDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _RequestDeletionDialog(),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(privacyRepositoryProvider)
          .requestFamilyDeletion(newIdempotencyKey());
      await _load();
    } on DomainFailure catch (e) {
      _showError(e.message ?? 'Não foi possível solicitar a exclusão agora.');
    }
  }

  Future<void> _respond(bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _promptForText(
        title: 'Rejeitar exclusão',
        label: 'Motivo',
      );
      if (reason == null || reason.trim().isEmpty) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Aprovar exclusão'),
          content: const Text(
            'A família será excluída em 7 dias. Qualquer responsável pode '
            'cancelar antes disso.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Aprovar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await ref
          .read(privacyRepositoryProvider)
          .respondFamilyDeletion(
            requestId: _deletionRequest!['id'] as String,
            approve: approve,
            rejectionReason: reason,
          );
      await _load();
    } on DomainFailure catch (e) {
      _showError(e.message ?? 'Não foi possível responder agora.');
    }
  }

  Future<void> _revokeConsent(String consentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revogar consentimento'),
        content: const Text(
          'Isso pode limitar o uso do app enquanto o consentimento não for '
          'concedido de novo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revogar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(privacyRepositoryProvider).revokeConsent(consentId);
      await _load();
    } on DomainFailure catch (e) {
      _showError(e.message ?? 'Não foi possível revogar agora.');
    }
  }

  Future<void> _cancelDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar exclusão'),
        content: const Text('O pedido de exclusão da família será cancelado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar exclusão'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(privacyRepositoryProvider)
          .cancelFamilyDeletion(_deletionRequest!['id'] as String);
      await _load();
    } on DomainFailure catch (e) {
      _showError(e.message ?? 'Não foi possível cancelar agora.');
    }
  }

  Future<String?> _promptForText({
    required String title,
    required String label,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(resolvedSessionProvider).valueOrNull;
    final myProfileId = switch (session) {
      GuardianSession(:final profileId) => profileId,
      _ => null,
    };
    final request = _deletionRequest;
    final isRequester =
        request != null && request['requested_by'] == myProfileId;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacidade')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    AsyncErrorBanner(message: _errorMessage!),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.download_outlined),
                      title: const Text('Seus dados'),
                      subtitle: const Text(
                        'Ver e exportar os dados da sua família',
                      ),
                      trailing: TextButton(
                        onPressed: _exportData,
                        child: const Text('Exportar'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Consentimentos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_consents.isEmpty) const Text('Nenhum registro ainda.'),
                  ..._consents.map(
                    (c) => Card(
                      child: ListTile(
                        title: Text(
                          '${c['document']} · v${c['document_version']}',
                        ),
                        subtitle: Text(
                          '${c['purpose']} · ${c['status'] == 'granted' ? 'concedido' : 'revogado'} · '
                          '${_dateFormat.format(DateTime.parse(c['created_at'] as String).toLocal())}',
                        ),
                        trailing: c['status'] == 'granted'
                            ? TextButton(
                                onPressed: () =>
                                    _revokeConsent(c['id'] as String),
                                child: const Text('Revogar'),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Excluir família',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (request == null)
                    Card(
                      child: ListTile(
                        title: const Text('Solicitar exclusão'),
                        subtitle: const Text(
                          'Apaga/anonimiza os dados após um período de '
                          'segurança de 7 dias. Ação séria e, depois do '
                          'prazo, irreversível.',
                        ),
                        trailing: TextButton(
                          onPressed: _requestDeletion,
                          child: const Text('Solicitar'),
                        ),
                      ),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _deletionStatusLabels[request['status']] ??
                                  request['status'] as String,
                            ),
                            if (request['scheduled_for'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Agendada para '
                                '${_dateFormat.format(DateTime.parse(request['scheduled_for'] as String).toLocal())}',
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (!isRequester &&
                                    request['status'] ==
                                        'pending_approval') ...[
                                  FilledButton(
                                    onPressed: () => _respond(true),
                                    child: const Text('Aprovar'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _respond(false),
                                    child: const Text('Rejeitar'),
                                  ),
                                ],
                                OutlinedButton(
                                  onPressed: _cancelDeletion,
                                  child: const Text('Cancelar exclusão'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _RequestDeletionDialog extends StatefulWidget {
  const _RequestDeletionDialog();

  @override
  State<_RequestDeletionDialog> createState() => _RequestDeletionDialogState();
}

class _RequestDeletionDialogState extends State<_RequestDeletionDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Solicitar exclusão da família'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se houver outro responsável ativo, ele precisa aprovar. Depois '
            'de aprovada, a exclusão acontece em 7 dias — qualquer '
            'responsável pode cancelar antes disso. Passado o prazo, a ação '
            'é irreversível.',
          ),
          CheckboxListTile(
            value: _understood,
            onChanged: (value) => setState(() => _understood = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Entendo e quero continuar'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: _understood ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Solicitar exclusão'),
        ),
      ],
    );
  }
}
