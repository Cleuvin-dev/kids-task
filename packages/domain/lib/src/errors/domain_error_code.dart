/// Códigos de erro de domínio padronizados.
///
/// Correspondem exatamente aos códigos definidos em
/// `docs/14_APIS_FUNCOES_E_EVENTOS.md`, seção 11. A camada de apresentação
/// traduz cada código para uma mensagem amigável em pt-BR; nunca exibe
/// stack trace ou erro de SQL ao usuário.
enum DomainErrorCode {
  authRequired,
  forbidden,
  sessionRevoked,
  familyNotFound,
  planChildLimit,
  planDailyTaskLimit,
  taskNotCompletable,
  taskExpired,
  versionConflict,
  alreadyProcessed,
  insufficientCoins,
  redemptionNotPending,
  themeNotEntitled,
  subscriptionNotVerified,
  rateLimited,
  validationError,
}

extension DomainErrorCodeWireName on DomainErrorCode {
  /// Nome estável usado na API/backend (ex.: `PLAN_DAILY_TASK_LIMIT`).
  String get wireName => switch (this) {
    DomainErrorCode.authRequired => 'AUTH_REQUIRED',
    DomainErrorCode.forbidden => 'FORBIDDEN',
    DomainErrorCode.sessionRevoked => 'SESSION_REVOKED',
    DomainErrorCode.familyNotFound => 'FAMILY_NOT_FOUND',
    DomainErrorCode.planChildLimit => 'PLAN_CHILD_LIMIT',
    DomainErrorCode.planDailyTaskLimit => 'PLAN_DAILY_TASK_LIMIT',
    DomainErrorCode.taskNotCompletable => 'TASK_NOT_COMPLETABLE',
    DomainErrorCode.taskExpired => 'TASK_EXPIRED',
    DomainErrorCode.versionConflict => 'VERSION_CONFLICT',
    DomainErrorCode.alreadyProcessed => 'ALREADY_PROCESSED',
    DomainErrorCode.insufficientCoins => 'INSUFFICIENT_COINS',
    DomainErrorCode.redemptionNotPending => 'REDEMPTION_NOT_PENDING',
    DomainErrorCode.themeNotEntitled => 'THEME_NOT_ENTITLED',
    DomainErrorCode.subscriptionNotVerified => 'SUBSCRIPTION_NOT_VERIFIED',
    DomainErrorCode.rateLimited => 'RATE_LIMITED',
    DomainErrorCode.validationError => 'VALIDATION_ERROR',
  };

  static DomainErrorCode fromWireName(String wireName) {
    return DomainErrorCode.values.firstWhere(
      (code) => code.wireName == wireName,
      orElse: () => DomainErrorCode.validationError,
    );
  }
}
