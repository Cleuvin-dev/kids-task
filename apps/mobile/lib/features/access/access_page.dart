import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Entrada comum do app único (docs/07_TELAS_E_FLUXOS.md, seção 2).
///
/// Não mostra nenhuma informação familiar antes da validação do backend.
/// A escolha entre "Sou responsável"/"Sou criança" só decide qual formulário
/// abrir a seguir — o papel real é sempre resolvido pelo backend depois.
class AccessPage extends StatelessWidget {
  const AccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(KidsTaskImages.accessBackground),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                const Spacer(),
                Image.asset(KidsTaskImages.wordmark, height: 56),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => context.go('/access/guardian/sign-in'),
                  child: const Text('Sou responsável'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                  ),
                  onPressed: () => context.go('/access/child'),
                  child: const Text('Sou criança'),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => _showPlaceholderSheet(
                    context,
                    title: 'Privacidade e ajuda',
                    body:
                        'A política de privacidade completa e o canal de ajuda '
                        'ficam disponíveis aqui antes do lançamento (docs/10). '
                        'Por enquanto, entre em contato pelo suporte informado '
                        'na loja.',
                  ),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  child: const Text('Privacidade e ajuda'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPlaceholderSheet(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(body),
          ],
        ),
      ),
    );
  }
}
