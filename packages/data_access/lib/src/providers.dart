import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/guardian_auth_repository.dart';
import 'auth/session_role_resolver.dart';
import 'child_access/child_access_repository.dart';
import 'client/kids_task_supabase.dart';
import 'family/child_repository.dart';
import 'family/family_repository.dart';

/// Providers de infraestrutura compartilhados pelos dois apps Flutter. Só
/// devem ser lidos depois de `KidsTaskSupabase.initialize(...)` em `main()`.

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => KidsTaskSupabase.client,
);

final guardianAuthRepositoryProvider = Provider<GuardianAuthRepository>(
  (ref) => GuardianAuthRepository(ref.watch(supabaseClientProvider)),
);

final familyRepositoryProvider = Provider<FamilyRepository>(
  (ref) => FamilyRepository(ref.watch(supabaseClientProvider)),
);

final childRepositoryProvider = Provider<ChildRepository>(
  (ref) => ChildRepository(ref.watch(supabaseClientProvider)),
);

final childAccessRepositoryProvider = Provider<ChildAccessRepository>(
  (ref) => ChildAccessRepository(ref.watch(supabaseClientProvider)),
);

final sessionRoleResolverProvider = Provider<SessionRoleResolver>(
  (ref) => SessionRoleResolver(ref.watch(supabaseClientProvider)),
);

/// Emite a cada mudança de estado de autenticação do Supabase (login,
/// logout, refresh, sessão anônima criada).
final authStateChangesProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(guardianAuthRepositoryProvider).authStateChanges,
);

/// Fonte única de verdade para "quem é este usuário": recalcula sempre que
/// o estado de autenticação muda, consultando o backend — nunca a partir de
/// rota ou estado local (docs/03 seção 2).
final resolvedSessionProvider = FutureProvider<ResolvedSession>((ref) async {
  ref.watch(authStateChangesProvider);
  return ref.watch(sessionRoleResolverProvider).resolve();
});
