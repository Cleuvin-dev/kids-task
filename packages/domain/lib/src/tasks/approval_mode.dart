/// Regra de aprovação de uma tarefa (docs/04 seção 6).
enum ApprovalMode {
  automatic,
  manual;

  String get wireName => switch (this) {
    ApprovalMode.automatic => 'automatic',
    ApprovalMode.manual => 'manual',
  };

  static ApprovalMode fromWireName(String wireName) {
    return ApprovalMode.values.firstWhere(
      (mode) => mode.wireName == wireName,
      orElse: () => throw ArgumentError.value(
        wireName,
        'wireName',
        'Modo de aprovação desconhecido',
      ),
    );
  }
}
