/// Tipo de agenda de uma tarefa (docs/04 seção 2). "Bônus", "sem horário" e
/// "com prazo" são combinações de flags sobre `once`/`recurring`, não tipos
/// à parte.
enum ScheduleType {
  once,
  recurring;

  String get wireName => switch (this) {
    ScheduleType.once => 'once',
    ScheduleType.recurring => 'recurring',
  };

  static ScheduleType fromWireName(String wireName) {
    return ScheduleType.values.firstWhere(
      (type) => type.wireName == wireName,
      orElse: () => throw ArgumentError.value(
        wireName,
        'wireName',
        'Tipo de agenda desconhecido',
      ),
    );
  }
}
