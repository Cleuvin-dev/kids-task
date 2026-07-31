import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Tela provisória do Marco 0 — Fundação.
///
/// Não é a tela de acesso real (`docs/07_TELAS_E_FLUXOS.md`, seção 2), que
/// chega no Marco 1 com splash, restauração de sessão e os dois botões de
/// entrada. Existe apenas para provar que o app compila com tema, l10n e
/// roteamento configurados ponta a ponta.
class FoundationPage extends StatelessWidget {
  const FoundationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.kidsTaskTokens;
    return Scaffold(
      backgroundColor: tokens.colorBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.appTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.foundationPlaceholder,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
