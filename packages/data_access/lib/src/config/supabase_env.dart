import 'package:meta/meta.dart';

/// Configuração de conexão Supabase para um ambiente (dev/staging/prod).
///
/// Nunca contém `service_role` nem outro segredo de backend: apenas a URL do
/// projeto e a chave publicável, que depende de RLS para segurança.
/// Ver `docs/08_ARQUITETURA_TECNICA.md` seção 12 e `docs/10_...LGPD.md` seção 8.
@immutable
class SupabaseEnv {
  const SupabaseEnv({required this.url, required this.publishableKey});

  final String url;
  final String publishableKey;

  /// Lê a configuração definida em tempo de build via
  /// `--dart-define-from-file=env/<ambiente>.json` (ver `.env.example`).
  ///
  /// Lança [StateError] cedo se as variáveis não foram fornecidas, para não
  /// deixar o app tentar se conectar a um backend inexistente.
  factory SupabaseEnv.fromDartDefine() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (url.isEmpty || publishableKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY precisam ser definidos via '
        '--dart-define-from-file. Veja .env.example na raiz do repositório.',
      );
    }
    return const SupabaseEnv(url: url, publishableKey: publishableKey);
  }
}
