import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'router.dart';

/// Raiz do aplicativo móvel único (responsável + criança).
class KidsTaskApp extends StatelessWidget {
  const KidsTaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildGuardianTheme(GuardianThemeOption.blue),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: kidsTaskRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
