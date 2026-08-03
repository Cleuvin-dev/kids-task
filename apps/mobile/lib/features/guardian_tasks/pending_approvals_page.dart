import 'dart:async';

import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/async_error_banner.dart';

/// Inbox de aprovações do responsável (docs/04 seção 6, fluxo manual).
class PendingApprovalsPage extends ConsumerStatefulWidget {
  const PendingApprovalsPage({super.key, required this.familyId});

  final String familyId;

  @override
  ConsumerState<PendingApprovalsPage> createState() =>
      _PendingApprovalsPageState();
}

class _PendingApprovalsPageState extends ConsumerState<PendingApprovalsPage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _pending = const [];
  Map<String, String> _childNames = const {};
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = ref
        .read(occurrenceRepositoryProvider)
        .watchFamilyOccurrences(widget.familyId)
        .listen((_) => _load());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final pending = await ref
          .read(occurrenceRepositoryProvider)
          .listPendingApprovals(widget.familyId);
      final children = await ref
          .read(childRepositoryProvider)
          .listChildren(widget.familyId);
      setState(() {
        _pending = pending;
        _childNames = {
          for (final child in children)
            child['id'] as String:
                (child['nickname'] as String?) ?? child['first_name'] as String,
        };
      });
    } catch (_) {
      setState(
        () => _errorMessage = 'Não foi possível carregar as aprovações agora.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(Map<String, dynamic> occurrence) async {
    try {
      await ref
          .read(occurrenceRepositoryProvider)
          .reviewOccurrence(
            occurrenceId: occurrence['id'] as String,
            decision: 'approve',
            idempotencyKey: newIdempotencyKey(),
            expectedVersion: occurrence['version'] as int,
          );
      _load();
    } catch (_) {
      _showError('Não foi possível aprovar agora.');
    }
  }

  Future<void> _reject(Map<String, dynamic> occurrence) async {
    final reason = await _promptForReason();
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await ref
          .read(occurrenceRepositoryProvider)
          .reviewOccurrence(
            occurrenceId: occurrence['id'] as String,
            decision: 'reject',
            idempotencyKey: newIdempotencyKey(),
            expectedVersion: occurrence['version'] as int,
            rejectionReason: reason.trim(),
          );
      _load();
    } catch (_) {
      _showError('Não foi possível rejeitar agora.');
    }
  }

  Future<String?> _promptForReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Motivo da rejeição'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'O que precisa ser corrigido?',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Rejeitar'),
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
      appBar: AppBar(title: const Text('Aprovações pendentes')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    AsyncErrorBanner(message: _errorMessage!),
                  if (_pending.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('Nenhuma aprovação pendente.')),
                    ),
                  ..._pending.map((occurrence) {
                    final childName =
                        _childNames[occurrence['child_id'] as String] ?? '—';
                    return Card(
                      child: ListTile(
                        title: Text(occurrence['task_title'] as String),
                        subtitle: Text(
                          '$childName · enviado em '
                          '${occurrence['submitted_at']}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _reject(occurrence),
                              icon: const Icon(Icons.close),
                              tooltip: 'Rejeitar',
                            ),
                            IconButton(
                              onPressed: () => _approve(occurrence),
                              icon: const Icon(Icons.check),
                              tooltip: 'Aprovar',
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}
