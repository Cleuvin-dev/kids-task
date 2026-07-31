import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Cadastro e login do responsável via e-mail/senha (Supabase Auth).
/// Ver docs/03_USUARIOS_FAMILIA_E_AUTENTICACAO.md, seção 3.
class GuardianAuthRepository {
  GuardianAuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  /// Não coleta gênero nem qualquer dado além do necessário para a conta
  /// (CLAUDE.md). `displayName` é o único metadado enviado.
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      throw mapSupabaseError(error);
    }
  }
}
