/// Papel de um administrador da plataforma dentro do painel Web.
///
/// Nunca é escolhido nem alterado pelo cliente: vem de
/// `platform_admins.role`, resolvido pelo backend a partir de um vínculo
/// persistido — mesmo princípio de [UserRole].
/// Ver `docs/12_PAINEL_ADMINISTRATIVO_WEB.md`, seção 2.
enum AdminRole {
  /// Configuração geral e administração de papéis.
  superAdmin,

  /// Suporte com acesso a dados mínimos.
  support,

  /// Temas, assets, avatares e textos.
  content,

  /// Planos, produtos e assinaturas.
  billing;

  /// Identificador técnico persistido no backend.
  String get wireName => switch (this) {
    AdminRole.superAdmin => 'super_admin',
    AdminRole.support => 'support',
    AdminRole.content => 'content',
    AdminRole.billing => 'billing',
  };

  static AdminRole fromWireName(String wireName) {
    return AdminRole.values.firstWhere(
      (role) => role.wireName == wireName,
      orElse: () => throw ArgumentError.value(
        wireName,
        'wireName',
        'Papel de administrador desconhecido',
      ),
    );
  }
}
