/// Papel de um usuário autenticado dentro do Kid's Task.
///
/// O papel nunca é escolhido nem alterado pelo cliente: ele é resolvido pelo
/// backend a partir de vínculos persistidos (`family_members`,
/// `child_device_bindings`, `platform_admins`). Ver `docs/03_USUARIOS_FAMILIA_E_AUTENTICACAO.md`.
enum UserRole {
  /// Responsável que criou a família (`family_owner`).
  familyOwner,

  /// Responsável convidado por outro responsável (`family_guardian`).
  familyGuardian,

  /// Perfil infantil (`child`).
  child,

  /// Integrante autorizado da equipe Kid's Task (`platform_admin`).
  platformAdmin;

  /// Identificador técnico persistido no backend.
  String get wireName => switch (this) {
    UserRole.familyOwner => 'family_owner',
    UserRole.familyGuardian => 'family_guardian',
    UserRole.child => 'child',
    UserRole.platformAdmin => 'platform_admin',
  };

  /// Responsáveis (proprietário ou convidado) administram tarefas, crianças,
  /// recompensas, temas e assinatura. Ver docs/03 seção 1.
  bool get isGuardian =>
      this == UserRole.familyOwner || this == UserRole.familyGuardian;

  static UserRole fromWireName(String wireName) {
    return UserRole.values.firstWhere(
      (role) => role.wireName == wireName,
      orElse: () =>
          throw ArgumentError.value(wireName, 'wireName', 'Papel desconhecido'),
    );
  }
}
