import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin/admin_audit_log_repository.dart';
import 'admin/admin_auth_repository.dart';
import 'admin/admin_family_repository.dart';
import 'admin/admin_mfa_repository.dart';
import 'admin/admin_session_resolver.dart';
import 'admin/admin_subscription_repository.dart';
import 'auth/guardian_auth_repository.dart';
import 'auth/session_role_resolver.dart';
import 'child_access/child_access_repository.dart';
import 'client/kids_task_supabase.dart';
import 'family/child_repository.dart';
import 'family/family_repository.dart';
import 'notifications/notification_repository.dart';
import 'rewards/redemption_repository.dart';
import 'rewards/reward_repository.dart';
import 'tasks/occurrence_repository.dart';
import 'tasks/progress_repository.dart';
import 'tasks/task_repository.dart';
import 'tasks/task_template_repository.dart';
import 'tasks/wallet_repository.dart';
import 'themes/theme_repository.dart';

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

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(supabaseClientProvider)),
);

final occurrenceRepositoryProvider = Provider<OccurrenceRepository>(
  (ref) => OccurrenceRepository(ref.watch(supabaseClientProvider)),
);

final taskTemplateRepositoryProvider = Provider<TaskTemplateRepository>(
  (ref) => TaskTemplateRepository(ref.watch(supabaseClientProvider)),
);

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepository(ref.watch(supabaseClientProvider)),
);

final rewardRepositoryProvider = Provider<RewardRepository>(
  (ref) => RewardRepository(ref.watch(supabaseClientProvider)),
);

final redemptionRepositoryProvider = Provider<RedemptionRepository>(
  (ref) => RedemptionRepository(ref.watch(supabaseClientProvider)),
);

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(supabaseClientProvider)),
);

final themeRepositoryProvider = Provider<ThemeRepository>(
  (ref) => ThemeRepository(ref.watch(supabaseClientProvider)),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(supabaseClientProvider)),
);

/// Tema do responsável, resolvido a partir de `families.guardian_theme`
/// (docs/06 seção 1). Cai em [GuardianThemeOption.blue] se ainda não
/// carregou ou se o valor for desconhecido — nunca quebra a tela.
final familyGuardianThemeProvider = FutureProvider.family<String, String>((
  ref,
  familyId,
) async {
  final family = await ref.read(familyRepositoryProvider).fetchFamily(familyId);
  return family?['guardian_theme'] as String? ?? 'blue';
});

/// Slug do tema da criança, resolvido a partir de
/// `child_profiles.theme_slug` (docs/06 seção 2).
final childThemeSlugProvider = FutureProvider.family<String, String>((
  ref,
  childId,
) async {
  final child = await ref
      .read(supabaseClientProvider)
      .from('child_profiles')
      .select('theme_slug')
      .eq('id', childId)
      .single();
  return child['theme_slug'] as String? ?? 'kids_default';
});

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

/// Providers do painel administrativo Web (`apps/admin_web`), paralelos aos
/// de cima — conta separada do app móvel, mesmo padrão de injeção
/// (docs/12 seção 10).

final adminAuthRepositoryProvider = Provider<AdminAuthRepository>(
  (ref) => AdminAuthRepository(ref.watch(supabaseClientProvider)),
);

final adminMfaRepositoryProvider = Provider<AdminMfaRepository>(
  (ref) => AdminMfaRepository(ref.watch(supabaseClientProvider)),
);

final adminAuditLogRepositoryProvider = Provider<AdminAuditLogRepository>(
  (ref) => AdminAuditLogRepository(ref.watch(supabaseClientProvider)),
);

final adminSessionResolverProvider = Provider<AdminSessionResolver>(
  (ref) => AdminSessionResolver(ref.watch(supabaseClientProvider)),
);

final adminSubscriptionRepositoryProvider =
    Provider<AdminSubscriptionRepository>(
      (ref) => AdminSubscriptionRepository(ref.watch(supabaseClientProvider)),
    );

final adminFamilyRepositoryProvider = Provider<AdminFamilyRepository>(
  (ref) => AdminFamilyRepository(ref.watch(supabaseClientProvider)),
);

final adminAuthStateChangesProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(adminAuthRepositoryProvider).authStateChanges,
);

/// Fonte única de verdade para "quem é este administrador", incluindo o
/// estado de MFA da sessão — recalculada a cada mudança de autenticação ou
/// verificação de fator (docs/12 seções 2 e 10).
final adminResolvedSessionProvider = FutureProvider<AdminResolvedSession>((
  ref,
) async {
  ref.watch(adminAuthStateChangesProvider);
  return ref.watch(adminSessionResolverProvider).resolve();
});
