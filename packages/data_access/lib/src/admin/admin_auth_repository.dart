import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/supabase_error_mapper.dart';

/// Login do painel administrativo Web — conta separada do app móvel, sem
/// autocadastro (docs/12_PAINEL_ADMINISTRATIVO_WEB.md seção 10: "login
/// separado do app infantil"). Provisionar um administrador é operação
/// manual (service_role); ver docs/IMPLEMENTATION_STATUS.md.
class AdminAuthRepository {
  AdminAuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

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
