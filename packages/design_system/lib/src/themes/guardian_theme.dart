import 'package:flutter/material.dart';

import '../tokens/kids_task_tokens.dart';

/// As duas opções de tema da área do responsável.
///
/// A escolha é manual e não tem relação com gênero — nem do responsável, nem
/// da criança. Ver `docs/06_TEMAS_DESIGN_E_FAIXAS_ETARIAS.md` seção 1 e
/// `CLAUDE.md` ("Não coletar gênero").
enum GuardianThemeOption { blue, pink }

/// Constrói o [ThemeData] da área do responsável para a opção escolhida.
///
/// Os dois temas compartilham a mesma arquitetura de informação, contraste e
/// componentes; apenas as cores semânticas mudam.
ThemeData buildGuardianTheme(GuardianThemeOption option) {
  final tokens = switch (option) {
    GuardianThemeOption.blue => const KidsTaskTokens(
      colorPrimary: Color(0xFF2F80ED),
      colorOnPrimary: Color(0xFFFFFFFF),
      colorBackground: Color(0xFFF4F8FF),
      colorSurface: Color(0xFFFFFFFF),
      colorOnSurface: Color(0xFF1B1B1F),
      colorSuccess: Color(0xFF2E7D32),
      colorWarning: Color(0xFFED6C02),
      colorError: Color(0xFFD32F2F),
      colorCoin: Color(0xFFF5A623),
      colorXp: Color(0xFF7C4DFF),
      radiusCard: 16,
      radiusButton: 12,
      motionReward: Duration(milliseconds: 600),
      soundComplete: 'sound.complete.default',
    ),
    GuardianThemeOption.pink => const KidsTaskTokens(
      colorPrimary: Color(0xFFE95D9A),
      colorOnPrimary: Color(0xFFFFFFFF),
      colorBackground: Color(0xFFFFF5FA),
      colorSurface: Color(0xFFFFFFFF),
      colorOnSurface: Color(0xFF1B1B1F),
      colorSuccess: Color(0xFF2E7D32),
      colorWarning: Color(0xFFED6C02),
      colorError: Color(0xFFD32F2F),
      colorCoin: Color(0xFFF5A623),
      colorXp: Color(0xFF7C4DFF),
      radiusCard: 16,
      radiusButton: 12,
      motionReward: Duration(milliseconds: 600),
      soundComplete: 'sound.complete.default',
    ),
  };

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: tokens.colorBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: tokens.colorPrimary,
      brightness: Brightness.light,
      primary: tokens.colorPrimary,
      onPrimary: tokens.colorOnPrimary,
      surface: tokens.colorSurface,
      onSurface: tokens.colorOnSurface,
      error: tokens.colorError,
    ),
    extensions: [tokens],
  );
}
