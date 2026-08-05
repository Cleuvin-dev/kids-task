import 'package:data_access/data_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Tela mostrada quando `families.status` está fora de `active`/`restricted`
/// (docs/12 seção 11): a família foi bloqueada, tem exclusão pendente ou foi
/// excluída pelo painel administrativo. Linguagem clara, nunca punitiva
/// (docs/06), sem detalhe interno — o motivo fica na auditoria do painel,
/// não exposto ao responsável aqui.
class FamilyBlockedPage extends ConsumerWidget {
  const FamilyBlockedPage({super.key, required this.status});

  final String status;

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
                const Icon(Icons.info_outline, size: 40),
                const SizedBox(height: 16),
                Text(_message(status), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    await ref.read(guardianAuthRepositoryProvider).signOut();
                    ref.invalidate(resolvedSessionProvider);
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

  String _message(String status) => switch (status) {
    'deletion_pending' =>
      'Uma exclusão de conta foi solicitada para sua família. Se isso não '
          'foi você, fale com o suporte.',
    'deleted' => 'A conta da sua família foi encerrada.',
    _ =>
      'O acesso da sua família foi temporariamente bloqueado. Fale com o '
          'suporte para mais informações.',
  };
}
