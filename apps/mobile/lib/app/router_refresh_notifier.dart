import 'package:data_access/data_access.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifica o `go_router` para reavaliar `redirect` sempre que
/// [resolvedSessionProvider] mudar de valor (login, logout, criação de
/// família/criança, autorização de aparelho etc.).
///
/// Usar `ref.listen` em vez de um redirect assíncrono evita uma corrida em
/// que `go_router` invoca `redirect` de novo antes do primeiro `await`
/// terminar, deixando a navegação presa no `initialLocation`.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(resolvedSessionProvider, (previous, next) => notifyListeners());
  }
}
