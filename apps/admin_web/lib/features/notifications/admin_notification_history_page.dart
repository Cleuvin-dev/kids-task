import 'package:data_access/data_access.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/async_error_banner.dart';

final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

/// Módulo "Notificações" do painel (docs/12 seção 8): histórico de
/// entrega do canal interno e envio de aviso operacional aos
/// responsáveis. Sem push real ainda (bloqueio de projeto Firebase,
/// docs/IMPLEMENTATION_STATUS.md), então "templates", "reprocessamento" e
/// "teste para aparelhos internos" ficam fora — não há pipeline pra
/// sustentar essas telas sem fingir uma entrega que não acontece.
class AdminNotificationHistoryPage extends ConsumerStatefulWidget {
  const AdminNotificationHistoryPage({super.key});

  @override
  ConsumerState<AdminNotificationHistoryPage> createState() =>
      _AdminNotificationHistoryPageState();
}

class _AdminNotificationHistoryPageState
    extends ConsumerState<AdminNotificationHistoryPage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _history = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final history = await ref
          .read(adminNotificationRepositoryProvider)
          .listHistory();
      setState(() {
        _history = history;
        _errorMessage = null;
      });
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível carregar o histórico agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendNotice() async {
    final input = await showDialog<_NoticeInput>(
      context: context,
      builder: (context) => const _SendNoticeDialog(),
    );
    if (input == null) return;
    try {
      final count = await ref
          .read(adminNotificationRepositoryProvider)
          .sendOperationalNotice(
            familyId: input.familyId,
            title: input.title,
            body: input.body,
            idempotencyKey: newIdempotencyKey(),
          );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aviso enviado a $count responsável(is).')),
      );
    } on DomainFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Não foi possível enviar o aviso agora.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          IconButton(
            tooltip: 'Enviar aviso operacional',
            icon: const Icon(Icons.campaign_outlined),
            onPressed: _sendNotice,
          ),
        ],
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
                  const Text(
                    'Histórico do canal interno (central de notificações do '
                    'app) — sem push real ainda, ver '
                    'docs/IMPLEMENTATION_STATUS.md.',
                  ),
                  const SizedBox(height: 12),
                  if (_history.isEmpty)
                    const Text('Nenhuma notificação ainda.'),
                  ..._history.map(_buildHistoryTile),
                ],
              ),
            ),
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> notification) {
    return Card(
      child: ListTile(
        title: Text(notification['title'] as String),
        subtitle: Text(
          '${notification['event_type']} · '
          '${notification['recipient_type'] == 'guardian' ? 'Responsável' : 'Criança'} · '
          '${_dateFormat.format(DateTime.parse(notification['created_at'] as String).toLocal())}',
        ),
      ),
    );
  }
}

class _NoticeInput {
  const _NoticeInput({
    required this.familyId,
    required this.title,
    required this.body,
  });

  final String familyId;
  final String title;
  final String body;
}

class _SendNoticeDialog extends StatefulWidget {
  const _SendNoticeDialog();

  @override
  State<_SendNoticeDialog> createState() => _SendNoticeDialogState();
}

class _SendNoticeDialogState extends State<_SendNoticeDialog> {
  final _familyIdController = TextEditingController();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void dispose() {
    _familyIdController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enviar aviso operacional'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Chega só aos responsáveis ativos da família, nunca à '
              'criança.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _familyIdController,
              decoration: const InputDecoration(labelText: 'ID da família'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Mensagem'),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed:
              _familyIdController.text.trim().isEmpty ||
                  _titleController.text.trim().isEmpty ||
                  _bodyController.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  _NoticeInput(
                    familyId: _familyIdController.text.trim(),
                    title: _titleController.text.trim(),
                    body: _bodyController.text.trim(),
                  ),
                ),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}
