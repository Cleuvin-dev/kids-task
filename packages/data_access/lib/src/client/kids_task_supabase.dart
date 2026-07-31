import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_env.dart';

/// Ponto único de inicialização e acesso ao cliente Supabase do app.
///
/// Repositórios de features (tarefas, carteira, recompensas etc.) recebem
/// [SupabaseClient] por injeção de dependência; esta classe existe apenas
/// para centralizar a inicialização feita uma vez em `main()`.
class KidsTaskSupabase {
  KidsTaskSupabase._();

  static bool _initialized = false;

  static Future<void> initialize(SupabaseEnv env) async {
    if (_initialized) return;
    await Supabase.initialize(url: env.url, publishableKey: env.publishableKey);
    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
}
