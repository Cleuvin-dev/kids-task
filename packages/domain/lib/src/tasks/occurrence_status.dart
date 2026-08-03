/// Estado de uma ocorrência de tarefa.
///
/// Ver `docs/04_TAREFAS_APROVACOES_E_ROTINA.md` seção 7 para o diagrama
/// completo de transições. O backend é a única fonte de verdade sobre
/// transições válidas; este enum só espelha o vocabulário para a UI.
enum OccurrenceStatus {
  pending,
  awaitingApproval,
  approved,
  late,
  expired,
  needsCorrection,
  cancelled,
  skippedByGuardian;

  /// Identificador técnico persistido no backend.
  String get wireName => switch (this) {
    OccurrenceStatus.pending => 'pending',
    OccurrenceStatus.awaitingApproval => 'awaiting_approval',
    OccurrenceStatus.approved => 'approved',
    OccurrenceStatus.late => 'late',
    OccurrenceStatus.expired => 'expired',
    OccurrenceStatus.needsCorrection => 'needs_correction',
    OccurrenceStatus.cancelled => 'cancelled',
    OccurrenceStatus.skippedByGuardian => 'skipped_by_guardian',
  };

  /// A criança pode tocar em "Concluir" nesse estado
  /// (docs/04 seção 7: pending/late/needs_correction levam a
  /// awaiting_approval ou approved via complete_task_occurrence).
  bool get isCompletable => switch (this) {
    OccurrenceStatus.pending ||
    OccurrenceStatus.late ||
    OccurrenceStatus.needsCorrection => true,
    _ => false,
  };

  /// Estado final: a ocorrência não transiciona mais (docs/04 seção 7).
  bool get isTerminal => switch (this) {
    OccurrenceStatus.approved ||
    OccurrenceStatus.expired ||
    OccurrenceStatus.cancelled ||
    OccurrenceStatus.skippedByGuardian => true,
    _ => false,
  };

  static OccurrenceStatus fromWireName(String wireName) {
    return OccurrenceStatus.values.firstWhere(
      (status) => status.wireName == wireName,
      orElse: () => throw ArgumentError.value(
        wireName,
        'wireName',
        'Estado de ocorrência desconhecido',
      ),
    );
  }
}
