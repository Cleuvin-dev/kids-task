import 'package:data_access/data_access.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifica o `go_router` para reavaliar `redirect` sempre que
/// [adminResolvedSessionProvider] mudar (login, logout, enrolamento ou
/// verificação de MFA). Mesmo padrão do app móvel — `ref.listen` em vez de
/// um redirect assíncrono evita a corrida em que o `go_router` invoca
/// `redirect` de novo antes do primeiro `await` terminar.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(
      adminResolvedSessionProvider,
      (previous, next) => notifyListeners(),
    );
  }
}
