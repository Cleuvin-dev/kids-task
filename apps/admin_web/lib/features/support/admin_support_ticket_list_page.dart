import 'package:data_access/data_access.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/async_error_banner.dart';

final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

const categoryLabels = {
  'billing': 'Cobrança',
  'technical': 'Técnico',
  'account': 'Conta',
  'content': 'Conteúdo',
  'other': 'Outro',
};

const priorityLabels = {
  'low': 'Baixa',
  'medium': 'Média',
  'high': 'Alta',
  'urgent': 'Urgente',
};

const statusLabels = {
  'open': 'Aberto',
  'in_progress': 'Em andamento',
  'waiting_on_family': 'Aguardando família',
  'resolved': 'Resolvido',
  'closed': 'Encerrado',
};

/// Módulo "Suporte" (docs/12 seção 9): fila de tickets — categoria,
/// prioridade, status — com criação de novo ticket. Sem impersonação:
/// nenhuma ação daqui acessa a sessão de um responsável ou criança.
class AdminSupportTicketListPage extends ConsumerStatefulWidget {
  const AdminSupportTicketListPage({super.key});

  @override
  ConsumerState<AdminSupportTicketListPage> createState() =>
      _AdminSupportTicketListPageState();
}

class _AdminSupportTicketListPageState
    extends ConsumerState<AdminSupportTicketListPage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _tickets = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tickets = await ref
          .read(adminSupportRepositoryProvider)
          .listTickets();
      setState(() {
        _tickets = tickets;
        _errorMessage = null;
      });
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível carregar os tickets agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTicket() async {
    final input = await showDialog<_NewTicketInput>(
      context: context,
      builder: (context) => const _CreateTicketDialog(),
    );
    if (input == null) return;
    try {
      final ticketId = await ref
          .read(adminSupportRepositoryProvider)
          .createTicket(
            familyId: input.familyId,
            subject: input.subject,
            category: input.category,
            priority: input.priority,
            incidentRef: input.incidentRef,
          );
      await _load();
      if (mounted) context.push('/admin/support/$ticketId');
    } on DomainFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Não foi possível criar o ticket agora.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suporte'),
        actions: [
          IconButton(
            tooltip: 'Novo ticket',
            icon: const Icon(Icons.add),
            onPressed: _createTicket,
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
                  if (_tickets.isEmpty) const Text('Nenhum ticket ainda.'),
                  ..._tickets.map(_buildTicketTile),
                ],
              ),
            ),
    );
  }

  Widget _buildTicketTile(Map<String, dynamic> ticket) {
    return Card(
      child: ListTile(
        title: Text(ticket['subject'] as String),
        subtitle: Text(
          '${statusLabels[ticket['status']] ?? ticket['status']} · '
          '${categoryLabels[ticket['category']] ?? ticket['category']} · '
          '${priorityLabels[ticket['priority']] ?? ticket['priority']} · '
          '${_dateFormat.format(DateTime.parse(ticket['updated_at'] as String).toLocal())}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/admin/support/${ticket['id']}'),
      ),
    );
  }
}

class _NewTicketInput {
  const _NewTicketInput({
    required this.familyId,
    required this.subject,
    required this.category,
    required this.priority,
    required this.incidentRef,
  });

  final String? familyId;
  final String subject;
  final String category;
  final String priority;
  final String? incidentRef;
}

class _CreateTicketDialog extends StatefulWidget {
  const _CreateTicketDialog();

  @override
  State<_CreateTicketDialog> createState() => _CreateTicketDialogState();
}

class _CreateTicketDialogState extends State<_CreateTicketDialog> {
  final _familyIdController = TextEditingController();
  final _subjectController = TextEditingController();
  final _incidentRefController = TextEditingController();
  String _category = 'technical';
  String _priority = 'medium';

  @override
  void dispose() {
    _familyIdController.dispose();
    _subjectController.dispose();
    _incidentRefController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo ticket'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _familyIdController,
              decoration: const InputDecoration(
                labelText: 'ID da família (opcional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Assunto'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: categoryLabels.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _category = value!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Prioridade'),
              items: priorityLabels.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _priority = value!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _incidentRefController,
              decoration: const InputDecoration(
                labelText: 'Referência de incidente (opcional)',
              ),
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
          onPressed: _subjectController.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  _NewTicketInput(
                    familyId: _familyIdController.text.trim().isEmpty
                        ? null
                        : _familyIdController.text.trim(),
                    subject: _subjectController.text.trim(),
                    category: _category,
                    priority: _priority,
                    incidentRef: _incidentRefController.text.trim().isEmpty
                        ? null
                        : _incidentRefController.text.trim(),
                  ),
                ),
          child: const Text('Criar'),
        ),
      ],
    );
  }
}
