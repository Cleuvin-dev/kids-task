import 'package:data_access/data_access.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/async_error_banner.dart';
import 'admin_support_ticket_list_page.dart';

final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

const _statusOrder = [
  'open',
  'in_progress',
  'waiting_on_family',
  'resolved',
  'closed',
];

/// Detalhe de um ticket (docs/12 seção 9): categoria/prioridade, timeline
/// de mensagens, resposta e mudança de status (encerramento/reabertura).
/// Sem impersonação — a família só aparece pelo nome, para contexto.
class AdminSupportTicketDetailPage extends ConsumerStatefulWidget {
  const AdminSupportTicketDetailPage({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<AdminSupportTicketDetailPage> createState() =>
      _AdminSupportTicketDetailPageState();
}

class _AdminSupportTicketDetailPageState
    extends ConsumerState<AdminSupportTicketDetailPage> {
  bool _loading = true;
  String? _errorMessage;
  Map<String, dynamic>? _ticket;
  String? _familyName;
  List<Map<String, dynamic>> _messages = const [];
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(adminSupportRepositoryProvider);
      final ticket = await repo.fetchTicket(widget.ticketId);
      final familyId = ticket?['family_id'] as String?;
      final familyName = familyId == null
          ? null
          : await repo.fetchFamilyName(familyId);
      final messages = await repo.listMessages(widget.ticketId);
      setState(() {
        _ticket = ticket;
        _familyName = familyName;
        _messages = messages;
        _errorMessage = null;
      });
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível carregar o ticket agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty) return;
    try {
      await ref
          .read(adminSupportRepositoryProvider)
          .addMessage(ticketId: widget.ticketId, body: body);
      _messageController.clear();
      await _load();
    } on DomainFailure catch (e) {
      _showError(e.message ?? 'Não foi possível enviar a mensagem agora.');
    }
  }

  Future<void> _changeStatus() async {
    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) =>
          _ChangeStatusDialog(currentStatus: _ticket?['status'] as String?),
    );
    if (newStatus == null) return;
    try {
      await ref
          .read(adminSupportRepositoryProvider)
          .updateStatus(ticketId: widget.ticketId, status: newStatus);
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
    final ticket = _ticket;
    return Scaffold(
      appBar: AppBar(title: Text(ticket?['subject'] as String? ?? 'Ticket')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    AsyncErrorBanner(message: _errorMessage!),
                  if (ticket == null)
                    const Text('Ticket não encontrado.')
                  else ...[
                    _buildOverviewCard(ticket),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _changeStatus,
                      child: const Text('Alterar status'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Timeline',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_messages.isEmpty)
                      const Text('Nenhuma mensagem ainda.'),
                    ..._messages.map(_buildMessageTile),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _messageController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Nova mensagem',
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _sendMessage,
                      child: const Text('Enviar'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCard(Map<String, dynamic> ticket) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: ${statusLabels[ticket['status']] ?? ticket['status']}',
            ),
            const SizedBox(height: 4),
            Text(
              'Categoria: ${categoryLabels[ticket['category']] ?? ticket['category']}',
            ),
            const SizedBox(height: 4),
            Text(
              'Prioridade: ${priorityLabels[ticket['priority']] ?? ticket['priority']}',
            ),
            const SizedBox(height: 4),
            Text('Família: ${_familyName ?? '—'}'),
            if (ticket['incident_ref'] != null) ...[
              const SizedBox(height: 4),
              Text('Incidente: ${ticket['incident_ref']}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTile(Map<String, dynamic> message) {
    return ListTile(
      title: Text(message['body'] as String),
      subtitle: Text(
        _dateFormat.format(
          DateTime.parse(message['created_at'] as String).toLocal(),
        ),
      ),
    );
  }
}

class _ChangeStatusDialog extends StatefulWidget {
  const _ChangeStatusDialog({required this.currentStatus});

  final String? currentStatus;

  @override
  State<_ChangeStatusDialog> createState() => _ChangeStatusDialogState();
}

class _ChangeStatusDialogState extends State<_ChangeStatusDialog> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final options = _statusOrder
        .where((s) => s != widget.currentStatus)
        .toList();
    return AlertDialog(
      title: const Text('Alterar status do ticket'),
      content: DropdownButtonFormField<String>(
        initialValue: _status,
        decoration: const InputDecoration(labelText: 'Novo status'),
        items: options
            .map(
              (s) =>
                  DropdownMenuItem(value: s, child: Text(statusLabels[s] ?? s)),
            )
            .toList(),
        onChanged: (value) => setState(() => _status = value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _status == null
              ? null
              : () => Navigator.of(context).pop(_status),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
