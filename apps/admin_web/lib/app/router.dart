import 'package:data_access/data_access.dart';
import 'package:design_system/design_system.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/access/admin_sign_in_page.dart';
import '../features/home/admin_home_page.dart';
import '../features/mfa/admin_mfa_challenge_page.dart';
import '../features/mfa/admin_mfa_enroll_page.dart';
import '../features/unauthorized/admin_unauthorized_page.dart';
import 'router_refresh_notifier.dart';

/// Rotas do painel administrativo Web e guard único de autorização.
///
/// O papel nunca é decidido pela rota: [redirect] sempre lê
/// [adminResolvedSessionProvider] (que consulta o backend e o estado de MFA
/// da sessão) antes de decidir para onde enviar o usuário — mesmo princípio
/// do `apps/mobile/lib/app/router.dart` (docs/03 seção 2, aplicado aqui a
/// `platform_admins`).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: RouterRefreshNotifier(ref),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final sessionAsync = ref.read(adminResolvedSessionProvider);

      return sessionAsync.when(
        loading: () => null,
        error: (_, _) =>
            loc.startsWith('/admin/access') ? null : '/admin/access',
        data: (session) => switch (session) {
          AdminNoSession() =>
            loc.startsWith('/admin/access') ? null : '/admin/access',
          AdminUnauthorized() =>
            loc == '/admin/unauthorized' ? null : '/admin/unauthorized',
          AdminMfaEnrollmentRequired() =>
            loc == '/admin/mfa/enroll' ? null : '/admin/mfa/enroll',
          AdminMfaChallengeRequired() =>
            loc == '/admin/mfa/challenge' ? null : '/admin/mfa/challenge',
          AdminSession() =>
            loc.startsWith('/admin/home') ? null : '/admin/home',
        },
      );
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _SplashPage()),
      GoRoute(
        path: '/admin/access',
        builder: (context, state) => const AdminSignInPage(),
      ),
      GoRoute(
        path: '/admin/mfa/enroll',
        builder: (context, state) =>
            AdminMfaEnrollPage(profileId: _currentProfileId(ref)!),
      ),
      GoRoute(
        path: '/admin/mfa/challenge',
        builder: (context, state) => AdminMfaChallengePage(
          profileId: _currentProfileId(ref)!,
          factorId: _currentFactorId(ref)!,
        ),
      ),
      GoRoute(
        path: '/admin/unauthorized',
        builder: (context, state) => const AdminUnauthorizedPage(),
      ),
      GoRoute(
        path: '/admin/home',
        builder: (context, state) => AdminHomePage(role: _currentRole(ref)!),
      ),
    ],
  );
});

String? _currentProfileId(Ref ref) {
  final session = ref.read(adminResolvedSessionProvider).valueOrNull;
  return switch (session) {
    AdminMfaEnrollmentRequired(:final profileId) => profileId,
    AdminMfaChallengeRequired(:final profileId) => profileId,
    _ => null,
  };
}

String? _currentFactorId(Ref ref) {
  final session = ref.read(adminResolvedSessionProvider).valueOrNull;
  return switch (session) {
    AdminMfaChallengeRequired(:final factorId) => factorId,
    _ => null,
  };
}

AdminRole? _currentRole(Ref ref) {
  final session = ref.read(adminResolvedSessionProvider).valueOrNull;
  return switch (session) {
    AdminSession(:final role) => role,
    _ => null,
  };
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Image(image: AssetImage(KidsTaskImages.wordmark), width: 200),
      ),
    );
  }
}
