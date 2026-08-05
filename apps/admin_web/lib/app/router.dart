import 'package:data_access/data_access.dart';
import 'package:design_system/design_system.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/access/admin_sign_in_page.dart';
import '../features/dashboard/admin_audit_log_page.dart';
import '../features/dashboard/admin_dashboard_page.dart';
import '../features/families/admin_family_detail_page.dart';
import '../features/families/admin_family_search_page.dart';
import '../features/home/admin_home_page.dart';
import '../features/mfa/admin_mfa_challenge_page.dart';
import '../features/mfa/admin_mfa_enroll_page.dart';
import '../features/notifications/admin_notification_history_page.dart';
import '../features/subscriptions/admin_subscription_detail_page.dart';
import '../features/subscriptions/admin_subscription_search_page.dart';
import '../features/support/admin_support_ticket_detail_page.dart';
import '../features/support/admin_support_ticket_list_page.dart';
import '../features/themes/admin_theme_catalog_page.dart';
import '../features/unauthorized/admin_unauthorized_page.dart';
import 'router_refresh_notifier.dart';

/// Papéis que enxergam o módulo "Assinaturas" (docs/12 seção 2: billing =
/// "planos, produtos e assinaturas"; super_admin sempre tem visão geral).
const _subscriptionModuleRoles = {AdminRole.superAdmin, AdminRole.billing};

/// Papéis que enxergam o módulo "Famílias e usuários" (docs/12 seção 11:
/// bloquear/revelar identidade são ações de suporte e segurança — billing
/// tem leitura entre famílias no banco só para o módulo Assinaturas, não
/// ganha este módulo próprio).
const _familyModuleRoles = {AdminRole.superAdmin, AdminRole.support};

/// Papéis que enxergam o módulo "Temas e conteúdo" (docs/12 seção 2:
/// content = "temas, assets, avatares e textos").
const _themeModuleRoles = {AdminRole.superAdmin, AdminRole.content};

/// Papéis que enxergam o módulo "Suporte" (docs/12 seção 2: support =
/// "suporte com dados mínimos").
const _supportModuleRoles = {AdminRole.superAdmin, AdminRole.support};

/// Papéis que enxergam o módulo "Notificações" do painel (docs/12 seção
/// 8) — mesmo conjunto de Suporte: aviso operacional é uma ação de
/// suporte/operação, não tem papel próprio na tabela de docs/12 seção 2.
const _notificationModuleRoles = {AdminRole.superAdmin, AdminRole.support};

/// Só `super_admin` enxerga o dashboard (docs/12 seção 2: "configuração
/// geral" — visão cross-domínio).
const _dashboardModuleRoles = {AdminRole.superAdmin};

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
          AdminSession(:final role) => switch (loc) {
            _ when loc.startsWith('/admin/home') => null,
            _ when loc.startsWith('/admin/subscriptions') =>
              _subscriptionModuleRoles.contains(role) ? null : '/admin/home',
            _ when loc.startsWith('/admin/families') =>
              _familyModuleRoles.contains(role) ? null : '/admin/home',
            _ when loc.startsWith('/admin/themes') =>
              _themeModuleRoles.contains(role) ? null : '/admin/home',
            _ when loc.startsWith('/admin/support') =>
              _supportModuleRoles.contains(role) ? null : '/admin/home',
            _ when loc.startsWith('/admin/notifications') =>
              _notificationModuleRoles.contains(role) ? null : '/admin/home',
            _
                when loc.startsWith('/admin/dashboard') ||
                    loc.startsWith('/admin/audit-log') =>
              _dashboardModuleRoles.contains(role) ? null : '/admin/home',
            _ => '/admin/home',
          },
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
      GoRoute(
        path: '/admin/subscriptions',
        builder: (context, state) => const AdminSubscriptionSearchPage(),
      ),
      GoRoute(
        path: '/admin/subscriptions/:familyId',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AdminSubscriptionDetailPage(
            familyId: state.pathParameters['familyId']!,
            familyName: extra?['familyName'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/admin/families',
        builder: (context, state) => const AdminFamilySearchPage(),
      ),
      GoRoute(
        path: '/admin/families/:familyId',
        builder: (context, state) =>
            AdminFamilyDetailPage(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: '/admin/themes',
        builder: (context, state) => const AdminThemeCatalogPage(),
      ),
      GoRoute(
        path: '/admin/support',
        builder: (context, state) => const AdminSupportTicketListPage(),
      ),
      GoRoute(
        path: '/admin/support/:ticketId',
        builder: (context, state) => AdminSupportTicketDetailPage(
          ticketId: state.pathParameters['ticketId']!,
        ),
      ),
      GoRoute(
        path: '/admin/notifications',
        builder: (context, state) => const AdminNotificationHistoryPage(),
      ),
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: '/admin/audit-log',
        builder: (context, state) => const AdminAuditLogPage(),
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
