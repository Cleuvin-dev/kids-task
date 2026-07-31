import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Tela provisória do Marco 0 — Fundação do painel administrativo.
///
/// O login com MFA obrigatório e os módulos por papel chegam no Marco 7
/// (`docs/12_PAINEL_ADMINISTRATIVO_WEB.md`). Existe apenas para provar que o
/// app Web compila com tema, l10n e roteamento configurados ponta a ponta.
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
