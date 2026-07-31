import 'package:data_access/data_access.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/access/access_page.dart';
import '../features/access/child_access_page.dart';
import '../features/access/guardian_sign_in_page.dart';
import '../features/access/guardian_sign_up_page.dart';
import '../features/child_home/child_home_page.dart';
import '../features/guardian_home/child_detail_page.dart';
import '../features/guardian_home/guardian_home_page.dart';
import '../features/onboarding/consent_page.dart';
import '../features/onboarding/create_child_page.dart';
import '../features/onboarding/create_family_page.dart';
import 'router_refresh_notifier.dart';

/// Rotas do app móvel e guard único de autorização.
///
/// O papel nunca é decidido pela rota: [redirect] sempre lê
/// [resolvedSessionProvider] (que consulta o backend) antes de decidir para
/// onde enviar o usuário — nenhuma sessão infantil consegue abrir o shell do
/// responsável apenas navegando (docs/03 seção 2; docs/15 seção 2).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: RouterRefreshNotifier(ref),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final sessionAsync = ref.read(resolvedSessionProvider);

      return sessionAsync.when(
        loading: () => null,
        error: (_, _) => loc.startsWith('/access') ? null : '/access',
        data: (session) => switch (session) {
          NoSession() => loc.startsWith('/access') ? null : '/access',
          UnboundAnonymousSession() =>
            loc == '/access/child' ? null : '/access/child',
          UnboundGuardianSession() =>
            loc.startsWith('/onboarding') ? null : '/onboarding/consent',
          GuardianSession() =>
            loc.startsWith('/guardian') ? null : '/guardian/home',
          ChildSession() => loc.startsWith('/child') ? null : '/child/home',
        },
      );
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _SplashPage()),
      GoRoute(path: '/access', builder: (context, state) => const AccessPage()),
      GoRoute(
        path: '/access/guardian/sign-in',
        builder: (context, state) => const GuardianSignInPage(),
      ),
      GoRoute(
        path: '/access/guardian/sign-up',
        builder: (context, state) => const GuardianSignUpPage(),
      ),
      GoRoute(
        path: '/access/child',
        builder: (context, state) => const ChildAccessPage(),
      ),
      GoRoute(
        path: '/onboarding/consent',
        builder: (context, state) => const ConsentPage(),
      ),
      GoRoute(
        path: '/onboarding/family',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CreateFamilyPage(
            documentVersion: extra?['documentVersion'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/onboarding/child',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final familyId =
              extra?['familyId'] as String? ?? _currentFamilyId(ref);
          return CreateChildPage(familyId: familyId!);
        },
      ),
      GoRoute(
        path: '/guardian/home',
        builder: (context, state) =>
            GuardianHomePage(familyId: _currentFamilyId(ref)!),
      ),
      GoRoute(
        path: '/guardian/children/:childId',
        builder: (context, state) =>
            ChildDetailPage(childId: state.pathParameters['childId']!),
      ),
      GoRoute(
        path: '/child/home',
        builder: (context, state) =>
            ChildHomePage(childId: _currentChildId(ref)!),
      ),
    ],
  );
});

String? _currentFamilyId(Ref ref) {
  final session = ref.read(resolvedSessionProvider).valueOrNull;
  return switch (session) {
    GuardianSession(:final familyId) => familyId,
    _ => null,
  };
}

String? _currentChildId(Ref ref) {
  final session = ref.read(resolvedSessionProvider).valueOrNull;
  return switch (session) {
    ChildSession(:final childId) => childId,
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
