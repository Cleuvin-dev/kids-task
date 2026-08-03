import 'dart:async';

import 'package:data_access/data_access.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tela "Hoje" da criança: tarefas do dia e a ação de concluir
/// (docs/04 seções 6-7). Nunca usa linguagem punitiva para tarefa
/// perdida/expirada (docs/04 seção 14: "sem punição automática").
class ChildTodaySection extends ConsumerStatefulWidget {
  const ChildTodaySection({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<ChildTodaySection> createState() => _ChildTodaySectionState();
}

class _ChildTodaySectionState extends ConsumerState<ChildTodaySection> {
  bool _loading = true;
  List<Map<String, dynamic>> _occurrences = const [];
  final Set<String> _submitting = {};
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = ref
        .read(occurrenceRepositoryProvider)
        .watchChildOccurrences(widget.childId)
        .listen((_) => _load());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final occurrences = await ref
          .read(occurrenceRepositoryProvider)
          .listToday(childId: widget.childId);
      if (mounted) setState(() => _occurrences = occurrences);
    } catch (_) {
      // Falha silenciosa: a criança só vê a lista vazia/desatualizada; o
      // próximo pull-to-refresh ou evento Realtime tenta de novo.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _complete(Map<String, dynamic> occurrence) async {
    final id = occurrence['id'] as String;
    setState(() => _submitting.add(id));
    try {
      await ref
          .read(occurrenceRepositoryProvider)
          .completeOccurrence(
            occurrenceId: id,
            idempotencyKey: newIdempotencyKey(),
            expectedVersion: occurrence['version'] as int,
          );
    } on DomainFailure catch (_) {
      // TASK_EXPIRED/VERSION_CONFLICT: outro evento já mudou a ocorrência;
      // recarregar mostra o estado atual em vez de um erro técnico.
    } finally {
      if (mounted) setState(() => _submitting.remove(id));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_occurrences.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Nenhuma tarefa para hoje ainda.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(children: _occurrences.map(_buildOccurrenceCard).toList());
  }

  Widget _buildOccurrenceCard(Map<String, dynamic> occurrence) {
    final status = OccurrenceStatus.fromWireName(
      occurrence['status'] as String,
    );
    final title = occurrence['title_snapshot'] as String;
    final coinReward = occurrence['coin_reward_snapshot'] as int;
    final isSubmitting = _submitting.contains(occurrence['id']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('+$coinReward'),
              ],
            ),
            const SizedBox(height: 4),
            Text(_statusLabel(status, occurrence)),
            if (status == OccurrenceStatus.needsCorrection &&
                occurrence['rejection_reason'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Motivo: ${occurrence['rejection_reason']}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (status.isCompletable) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: isSubmitting ? null : () => _complete(occurrence),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        status == OccurrenceStatus.needsCorrection
                            ? 'Corrigir e reenviar'
                            : 'Concluir',
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(
    OccurrenceStatus status,
    Map<String, dynamic> occurrence,
  ) {
    return switch (status) {
      OccurrenceStatus.pending => 'Pendente',
      OccurrenceStatus.late => 'Atrasada, ainda dá tempo',
      OccurrenceStatus.awaitingApproval => 'Aguardando aprovação',
      OccurrenceStatus.needsCorrection => 'Precisa de um ajuste',
      OccurrenceStatus.approved => 'Concluída',
      OccurrenceStatus.expired => 'Prazo encerrado',
      OccurrenceStatus.skippedByGuardian => 'Dispensada',
      OccurrenceStatus.cancelled => 'Cancelada',
    };
  }
}
