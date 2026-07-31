import 'package:flutter/material.dart';

import '../tokens/kids_task_tokens.dart';

/// Slug do Tema Infantil Padrão no catálogo (`docs/06`, seção 3). Gratuito.
const kidsDefaultThemeSlug = 'kids_default';

/// Tema Infantil Padrão com placeholder de cores.
///
/// As artes finais deste tema ainda não existem (`docs/18_PENDENCIAS_NAO_BLOQUEANTES.md`,
/// seção 2). Este placeholder usa apenas cores e formas — nenhum asset de
/// terceiro — e deve ser substituído pela equipe de conteúdo sem mudar a
/// navegação nem os tokens consumidos pelas telas.
ThemeData buildKidsDefaultTheme() {
  const tokens = KidsTaskTokens(
    colorPrimary: Color(0xFF3DBEFF),
    colorOnPrimary: Color(0xFFFFFFFF),
    colorBackground: Color(0xFFF0FBFF),
    colorSurface: Color(0xFFFFFFFF),
    colorOnSurface: Color(0xFF1B1B1F),
    colorSuccess: Color(0xFF2E7D32),
    colorWarning: Color(0xFFED6C02),
    colorError: Color(0xFFD32F2F),
    colorCoin: Color(0xFFF5A623),
    colorXp: Color(0xFF7C4DFF),
    radiusCard: 20,
    radiusButton: 16,
    motionReward: Duration(milliseconds: 700),
    soundComplete: 'sound.complete.kids_default',
  );

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
    extensions: const [tokens],
  );
}
