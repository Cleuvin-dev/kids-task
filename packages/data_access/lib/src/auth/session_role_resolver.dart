import 'package:domain/domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// O que a sessão atual do Supabase resolve para, segundo o próprio backend.
///
/// Nunca é decidido por rota ou estado local: cada campo vem de uma consulta
/// que só retorna a linha do próprio usuário graças à RLS
/// (docs/03_USUARIOS_FAMILIA_E_AUTENTICACAO.md, seção 2:
/// "Não deve existir parâmetro de rota... capaz de transformar uma sessão
/// infantil em responsável").
sealed class ResolvedSession {
  const ResolvedSession();
}

class NoSession extends ResolvedSession {
  const NoSession();
}

class GuardianSession extends ResolvedSession {
  const GuardianSession({
    required this.profileId,
    required this.familyId,
    required this.role,
  });

  final String profileId;
  final String familyId;
  final UserRole role; // familyOwner ou familyGuardian
}

class ChildSession extends ResolvedSession {
  const ChildSession({
    required this.childId,
    required this.familyId,
    required this.deviceBindingId,
  });

  final String childId;
  final String familyId;
  final String deviceBindingId;
}

/// Sessão anônima existe (login infantil em andamento), mas ainda não foi
/// vinculada a nenhuma criança — precisa passar pelo fluxo de acesso.
class UnboundAnonymousSession extends ResolvedSession {
  const UnboundAnonymousSession();
}

/// Responsável autenticado (e-mail confirmado), mas sem família ativa —
/// precisa passar por consentimento e criação da família (onboarding).
class UnboundGuardianSession extends ResolvedSession {
  const UnboundGuardianSession({required this.profileId});

  final String profileId;
}

class SessionRoleResolver {
  SessionRoleResolver(this._client);

  final SupabaseClient _client;

  Future<ResolvedSession> resolve() async {
    final session = _client.auth.currentSession;
    if (session == null) return const NoSession();

    final isAnonymous = session.user.isAnonymous;

    try {
      if (!isAnonymous) {
        final membership = await _client
            .from('family_members')
            .select('family_id, role')
            .eq('profile_id', session.user.id)
            .eq('status', 'active')
            .limit(1)
            .maybeSingle();

        if (membership == null) {
          return UnboundGuardianSession(profileId: session.user.id);
        }

        return GuardianSession(
          profileId: session.user.id,
          familyId: membership['family_id'] as String,
          role: UserRole.fromWireName(membership['role'] as String),
        );
      }

      final binding = await _client
          .from('child_device_bindings')
          .select('id, child_id')
          .eq('auth_user_id', session.user.id)
          .isFilter('revoked_at', null)
          .limit(1)
          .maybeSingle();

      if (binding == null) return const UnboundAnonymousSession();

      final child = await _client
          .from('child_profiles')
          .select('family_id')
          .eq('id', binding['child_id'] as String)
          .single();

      return ChildSession(
        childId: binding['child_id'] as String,
        familyId: child['family_id'] as String,
        deviceBindingId: binding['id'] as String,
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
