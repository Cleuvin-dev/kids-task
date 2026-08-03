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
import '../features/guardian_home/child_theme_page.dart';
import '../features/guardian_home/guardian_home_page.dart';
import '../features/child_home/child_rewards_page.dart';
import '../features/guardian_rewards/guardian_reward_list_page.dart';
import '../features/guardian_rewards/pending_redemptions_page.dart';
import '../features/guardian_rewards/reward_form_page.dart';
import '../features/guardian_tasks/guardian_task_list_page.dart';
import '../features/guardian_tasks/pending_approvals_page.dart';
import '../features/guardian_tasks/task_form_page.dart';
import '../features/guardian_tasks/task_template_picker_page.dart';
import '../features/onboarding/consent_page.dart';
import '../features/onboarding/create_child_page.dart';
import '../features/onboarding/create_family_page.dart';
import '../features/onboarding/theme_request_page.dart';
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
      ShellRoute(
        builder: (context, state, child) =>
            _GuardianThemeShell(familyId: _currentFamilyId(ref), child: child),
        routes: [
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
            path: '/guardian/children/:childId/tasks',
            builder: (context, state) =>
                GuardianTaskListPage(childId: state.pathParameters['childId']!),
          ),
          GoRoute(
            path: '/guardian/children/:childId/theme',
            builder: (context, state) => ChildThemePage(
              childId: state.pathParameters['childId']!,
              familyId: _currentFamilyId(ref)!,
            ),
          ),
          GoRoute(
            path: '/guardian/tasks/new',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return TaskFormPage(
                childId: extra?['childId'] as String,
                template: extra?['template'] as Map<String, dynamic>?,
              );
            },
          ),
          GoRoute(
            path: '/guardian/tasks/:taskId/edit',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return TaskFormPage(
                taskId: state.pathParameters['taskId'],
                childId: extra?['childId'] as String,
                initialTask: extra?['task'] as Map<String, dynamic>?,
                initialSchedule: extra?['schedule'] as Map<String, dynamic>?,
              );
            },
          ),
          GoRoute(
            path: '/guardian/tasks/templates',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return TaskTemplatePickerPage(
                childId: extra?['childId'] as String,
              );
            },
          ),
          GoRoute(
            path: '/guardian/approvals',
            builder: (context, state) =>
                PendingApprovalsPage(familyId: _currentFamilyId(ref)!),
          ),
          GoRoute(
            path: '/guardian/rewards',
            builder: (context, state) =>
                GuardianRewardListPage(familyId: _currentFamilyId(ref)!),
          ),
          GoRoute(
            path: '/guardian/rewards/new',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return RewardFormPage(
                familyId:
                    extra?['familyId'] as String? ?? _currentFamilyId(ref)!,
              );
            },
          ),
          GoRoute(
            path: '/guardian/rewards/:rewardId/edit',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return RewardFormPage(
                familyId:
                    extra?['familyId'] as String? ?? _currentFamilyId(ref)!,
                rewardId: state.pathParameters['rewardId'],
                initialReward: extra?['reward'] as Map<String, dynamic>?,
              );
            },
          ),
          GoRoute(
            path: '/guardian/redemptions',
            builder: (context, state) =>
                PendingRedemptionsPage(familyId: _currentFamilyId(ref)!),
          ),
          GoRoute(
            path: '/guardian/theme-requests/new',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return ThemeRequestPage(
                familyId:
                    extra?['familyId'] as String? ?? _currentFamilyId(ref)!,
              );
            },
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) =>
            _ChildThemeShell(childId: _currentChildId(ref), child: child),
        routes: [
          GoRoute(
            path: '/child/home',
            builder: (context, state) =>
                ChildHomePage(childId: _currentChildId(ref)!),
          ),
          GoRoute(
            path: '/child/rewards',
            builder: (context, state) =>
                ChildRewardsPage(childId: _currentChildId(ref)!),
          ),
        ],
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

/// Aplica o tema azul/rosa escolhido pela família a todas as telas do
/// responsável (docs/06 seção 1). Slug ausente/ainda carregando cai no
/// azul — nunca quebra a tela (docs/06 seção 6).
class _GuardianThemeShell extends ConsumerWidget {
  const _GuardianThemeShell({required this.familyId, required this.child});

  final String? familyId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeValue = familyId == null
        ? null
        : ref.watch(familyGuardianThemeProvider(familyId!)).valueOrNull;
    final option = themeValue == 'pink'
        ? GuardianThemeOption.pink
        : GuardianThemeOption.blue;
    return Theme(data: buildGuardianTheme(option), child: child);
  }
}

/// Aplica o tema individual da criança (docs/06 seção 2) a todas as telas
/// infantis. Slug ausente/ainda carregando ou sem build cai no Tema
/// Infantil Padrão — nunca quebra a tela (docs/06 seção 6).
class _ChildThemeShell extends ConsumerWidget {
  const _ChildThemeShell({required this.childId, required this.child});

  final String? childId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slug = childId == null
        ? null
        : ref.watch(childThemeSlugProvider(childId!)).valueOrNull;
    return Theme(data: buildKidsThemeBySlug(slug), child: child);
  }
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
