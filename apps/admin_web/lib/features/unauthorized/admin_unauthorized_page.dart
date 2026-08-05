import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Estado explícito para uma conta autenticada no Supabase Auth sem
/// vínculo ativo em `platform_admins`. O painel não tem autocadastro —
/// provisionar um administrador é operação manual — então isto só deveria
/// acontecer por erro operacional; ainda assim precisa de uma tela clara em
/// vez de um erro genérico.
class AdminUnauthorizedPage extends ConsumerWidget {
  const AdminUnauthorizedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Esta conta não tem acesso ao painel administrativo. '
                  'Se você deveria ser um administrador, peça para alguém '
                  'da equipe com acesso de super_admin confirmar seu '
                  'cadastro.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    await ref.read(adminAuthRepositoryProvider).signOut();
                    ref.invalidate(adminResolvedSessionProvider);
                    if (context.mounted) context.go('/');
                  },
                  child: const Text('Sair'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
