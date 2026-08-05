import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/async_error_banner.dart';

final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

/// Log de auditoria (docs/12 seção 10): `audit_logs` já tem RLS pronta
/// desde a fatia 2 — super_admin vê tudo, outro papel só as próprias
/// ações; esta tela só lista o que a policy já filtrou.
///
/// "Exportação de auditoria" (docs/12 seção 10) aqui é copiar CSV para a
/// área de transferência, não baixar um arquivo — evita depender de APIs
/// específicas do Flutter Web sem um jeito de testar num navegador real
/// neste ambiente; o operador cola direto numa planilha.
class AdminAuditLogPage extends ConsumerStatefulWidget {
  const AdminAuditLogPage({super.key});

  @override
  ConsumerState<AdminAuditLogPage> createState() => _AdminAuditLogPageState();
}

class _AdminAuditLogPageState extends ConsumerState<AdminAuditLogPage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final entries = await ref
          .read(adminDashboardRepositoryProvider)
          .listAuditLog();
      setState(() {
        _entries = entries;
        _errorMessage = null;
      });
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível carregar a auditoria agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyAsCsv() async {
    final buffer = StringBuffer(
      'created_at,actor_role,action,resource_type,resource_id,result\n',
    );
    for (final entry in _entries) {
      buffer.writeln(
        [
          entry['created_at'],
          entry['actor_role'],
          entry['action'],
          entry['resource_type'],
          entry['resource_id'] ?? '',
          entry['result'],
        ].map((v) => '"${v.toString().replaceAll('"', '""')}"').join(','),
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV copiado para a área de transferência.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log de auditoria'),
        actions: [
          IconButton(
            tooltip: 'Copiar CSV',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: _entries.isEmpty ? null : _copyAsCsv,
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
                  if (_entries.isEmpty)
                    const Text('Nenhuma ação registrada ainda.'),
                  ..._entries.map(_buildEntryTile),
                ],
              ),
            ),
    );
  }

  Widget _buildEntryTile(Map<String, dynamic> entry) {
    return Card(
      child: ListTile(
        title: Text(entry['action'] as String),
        subtitle: Text(
          '${entry['actor_role']} · ${entry['resource_type']}'
          '${entry['resource_id'] != null ? ' #${entry['resource_id']}' : ''} · '
          '${entry['result']} · '
          '${_dateFormat.format(DateTime.parse(entry['created_at'] as String).toLocal())}',
        ),
      ),
    );
  }
}
