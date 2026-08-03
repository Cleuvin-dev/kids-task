/// Período do dia sugerido para uma tarefa (docs/04 seção 4).
enum TaskPeriod {
  morning,
  afternoonEvening,
  anytime;

  String get wireName => switch (this) {
    TaskPeriod.morning => 'morning',
    TaskPeriod.afternoonEvening => 'afternoon_evening',
    TaskPeriod.anytime => 'anytime',
  };

  static TaskPeriod fromWireName(String wireName) {
    return TaskPeriod.values.firstWhere(
      (period) => period.wireName == wireName,
      orElse: () => throw ArgumentError.value(
        wireName,
        'wireName',
        'Período desconhecido',
      ),
    );
  }
}
