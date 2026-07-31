import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tema azul usa a cor primária #2F80ED', () {
    final theme = buildGuardianTheme(GuardianThemeOption.blue);
    final tokens = theme.extension<KidsTaskTokens>()!;
    expect(tokens.colorPrimary, const Color(0xFF2F80ED));
  });

  test('tema rosa usa a cor primária #E95D9A', () {
    final theme = buildGuardianTheme(GuardianThemeOption.pink);
    final tokens = theme.extension<KidsTaskTokens>()!;
    expect(tokens.colorPrimary, const Color(0xFFE95D9A));
  });

  test('os dois temas do responsável usam a mesma geometria', () {
    final blue = buildGuardianTheme(
      GuardianThemeOption.blue,
    ).extension<KidsTaskTokens>()!;
    final pink = buildGuardianTheme(
      GuardianThemeOption.pink,
    ).extension<KidsTaskTokens>()!;
    expect(blue.radiusCard, pink.radiusCard);
    expect(blue.radiusButton, pink.radiusButton);
  });

  test('Tema Infantil Padrão expõe o slug kids_default', () {
    expect(kidsDefaultThemeSlug, 'kids_default');
    final theme = buildKidsDefaultTheme();
    expect(theme.extension<KidsTaskTokens>(), isNotNull);
  });
}
