/// Política aplicada quando o prazo de uma ocorrência vence (docs/04 seção 5).
enum LatePolicy {
  allowLate,
  expireNoReward;

  String get wireName => switch (this) {
    LatePolicy.allowLate => 'allow_late',
    LatePolicy.expireNoReward => 'expire_no_reward',
  };

  static LatePolicy fromWireName(String wireName) {
    return LatePolicy.values.firstWhere(
      (policy) => policy.wireName == wireName,
      orElse: () => throw ArgumentError.value(
        wireName,
        'wireName',
        'Política de prazo desconhecida',
      ),
    );
  }
}
