import 'package:go_router/go_router.dart';

import '../features/foundation/foundation_page.dart';

/// Rotas do app móvel.
///
/// No Marco 0 existe apenas a rota de fundação. A partir do Marco 1, a
/// entrada comum (splash/acesso) e os dois shells (responsável/criança)
/// entram aqui, cada um com seus próprios guards de autorização — nunca por
/// flag local, sempre validando o papel resolvido pelo backend
/// (`docs/03_USUARIOS_FAMILIA_E_AUTENTICACAO.md`, seção 2).
final kidsTaskRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const FoundationPage()),
  ],
);
