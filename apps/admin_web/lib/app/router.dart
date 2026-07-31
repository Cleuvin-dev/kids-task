import 'package:go_router/go_router.dart';

import '../features/foundation/foundation_page.dart';

/// Rotas do painel administrativo Web.
///
/// No Marco 0 existe apenas a rota de fundação. O login com MFA obrigatório
/// e os módulos por papel (`super_admin`, `support`, `content`, `billing`)
/// entram a partir do Marco 7 (`docs/12_PAINEL_ADMINISTRATIVO_WEB.md`).
final kidsTaskAdminRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const FoundationPage()),
  ],
);
