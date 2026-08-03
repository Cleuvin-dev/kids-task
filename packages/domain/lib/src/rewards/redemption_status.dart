/// Estado de uma solicitação de resgate (docs/05 seção 5): `requested` ->
/// `approved`|`rejected`; `approved` -> `delivered`|`cancelled`.
enum RedemptionStatus {
  requested,
  approved,
  rejected,
  delivered,
  cancelled;

  String get wireName => switch (this) {
    RedemptionStatus.requested => 'requested',
    RedemptionStatus.approved => 'approved',
    RedemptionStatus.rejected => 'rejected',
    RedemptionStatus.delivered => 'delivered',
    RedemptionStatus.cancelled => 'cancelled',
  };

  /// KidsCoins só saem do saldo neste estado (docs/05 seção 5) — a partir
  /// daqui o responsável pode marcar entregue ou, excepcionalmente, cancelar.
  bool get isApprovedPending => this == RedemptionStatus.approved;

  bool get isTerminal => switch (this) {
    RedemptionStatus.rejected ||
    RedemptionStatus.delivered ||
    RedemptionStatus.cancelled => true,
    _ => false,
  };

  static RedemptionStatus fromWireName(String wireName) {
    return RedemptionStatus.values.firstWhere(
      (status) => status.wireName == wireName,
      orElse: () => throw ArgumentError.value(
        wireName,
        'wireName',
        'Estado de resgate desconhecido',
      ),
    );
  }
}
