import 'package:domain/domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// O que a sessão atual do painel administrativo resolve para.
///
/// Mesmo princípio do `SessionRoleResolver` do app móvel (docs/03 seção 2):
/// nunca é decidido por rota ou estado local, sempre por uma consulta que
/// só retorna a própria linha (RLS) mais o estado de MFA da sessão
/// (docs/12 seções 2 e 10: MFA obrigatório antes de qualquer módulo).
sealed class AdminResolvedSession {
  const AdminResolvedSession();
}

class AdminNoSession extends AdminResolvedSession {
  const AdminNoSession();
}

/// Autenticado no Supabase Auth, mas sem vínculo ativo em
/// `platform_admins`. Não deveria acontecer em uso normal, já que o painel
/// não tem autocadastro (provisionar admin é operação manual) — ainda
/// assim a UI precisa de um estado explícito em vez de um erro genérico.
class AdminUnauthorized extends AdminResolvedSession {
  const AdminUnauthorized();
}

/// Administrador válido, mas sem nenhum fator TOTP verificado ainda.
class AdminMfaEnrollmentRequired extends AdminResolvedSession {
  const AdminMfaEnrollmentRequired({required this.profileId});

  final String profileId;
}

/// Administrador com fator já verificado em enrolamento anterior, mas a
/// sessão atual está em aal1 — precisa completar o desafio de MFA.
class AdminMfaChallengeRequired extends AdminResolvedSession {
  const AdminMfaChallengeRequired({
    required this.profileId,
    required this.factorId,
  });

  final String profileId;
  final String factorId;
}

class AdminSession extends AdminResolvedSession {
  const AdminSession({required this.profileId, required this.role});

  final String profileId;
  final AdminRole role;
}

class AdminSessionResolver {
  AdminSessionResolver(this._client);

  final SupabaseClient _client;

  Future<AdminResolvedSession> resolve() async {
    final session = _client.auth.currentSession;
    if (session == null) return const AdminNoSession();

    try {
      final admin = await _client
          .from('platform_admins')
          .select('role, active')
          .eq('profile_id', session.user.id)
          .maybeSingle();

      if (admin == null || admin['active'] != true) {
        return const AdminUnauthorized();
      }

      final role = AdminRole.fromWireName(admin['role'] as String);

      final factors = await _client.auth.mfa.listFactors();
      if (factors.totp.isEmpty) {
        return AdminMfaEnrollmentRequired(profileId: session.user.id);
      }

      final assurance = _client.auth.mfa.getAuthenticatorAssuranceLevel();
      if (assurance.currentLevel != AuthenticatorAssuranceLevels.aal2) {
        return AdminMfaChallengeRequired(
          profileId: session.user.id,
          factorId: factors.totp.first.id,
        );
      }

      return AdminSession(profileId: session.user.id, role: role);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
