import 'package:flutter/material.dart';

import '../tokens/kids_task_tokens.dart';
import 'kids_default_theme.dart';

/// Constrói o [ThemeData] de "Mundo dos Blocos" (`docs/06` seção 3, slug
/// `block_world`). Categoria ampla "blocos" — sem referência a nenhuma
/// marca de terceiros (`docs/06` seção 4).
ThemeData buildBlockWorldTheme() {
  const tokens = KidsTaskTokens(
    colorPrimary: Color(0xFFFF9F1C),
    colorOnPrimary: Color(0xFFFFFFFF),
    colorBackground: Color(0xFFFFF6E9),
    colorSurface: Color(0xFFFFFFFF),
    colorOnSurface: Color(0xFF1B1B1F),
    colorSuccess: Color(0xFF2E7D32),
    colorWarning: Color(0xFFED6C02),
    colorError: Color(0xFFD32F2F),
    colorCoin: Color(0xFFF5A623),
    colorXp: Color(0xFF7C4DFF),
    radiusCard: 12,
    radiusButton: 10,
    motionReward: Duration(milliseconds: 700),
    soundComplete: 'sound.complete.block_world',
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

/// Constrói o [ThemeData] de "Aventura Espacial" (slug `space_adventure`).
/// Categoria ampla "espaço" — nenhuma nave, personagem ou logotipo de
/// franquia existente.
ThemeData buildSpaceAdventureTheme() {
  const tokens = KidsTaskTokens(
    colorPrimary: Color(0xFF5C6BC0),
    colorOnPrimary: Color(0xFFFFFFFF),
    colorBackground: Color(0xFFEDEFFB),
    colorSurface: Color(0xFFFFFFFF),
    colorOnSurface: Color(0xFF1B1B2F),
    colorSuccess: Color(0xFF2E7D32),
    colorWarning: Color(0xFFED6C02),
    colorError: Color(0xFFD32F2F),
    colorCoin: Color(0xFFF5A623),
    colorXp: Color(0xFF9575CD),
    radiusCard: 16,
    radiusButton: 12,
    motionReward: Duration(milliseconds: 700),
    soundComplete: 'sound.complete.space_adventure',
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

/// Constrói o [ThemeData] de "Princesas e Castelos" (slug `castles_quest`).
/// Categoria ampla "fantasia rosa" — sem nenhuma princesa, castelo ou
/// logotipo de franquia existente (`docs/06` seção 4).
ThemeData buildCastlesQuestTheme() {
  const tokens = KidsTaskTokens(
    colorPrimary: Color(0xFFBA68C8),
    colorOnPrimary: Color(0xFFFFFFFF),
    colorBackground: Color(0xFFFBF1FB),
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
    soundComplete: 'sound.complete.castles_quest',
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

/// Resolve o [ThemeData] de um tema pelo slug persistido em
/// `child_profiles.theme_slug`/`themes.slug`.
///
/// Um slug desconhecido ou sem build ainda (tema `draft`, sem arte) nunca
/// pode quebrar a tela — cai no Tema Infantil Padrão (`docs/06` seção 6:
/// "Cada tema precisa de modo seguro de fallback").
ThemeData buildKidsThemeBySlug(String? slug) {
  return switch (slug) {
    'block_world' => buildBlockWorldTheme(),
    'space_adventure' => buildSpaceAdventureTheme(),
    'castles_quest' => buildCastlesQuestTheme(),
    _ => buildKidsDefaultTheme(),
  };
}
