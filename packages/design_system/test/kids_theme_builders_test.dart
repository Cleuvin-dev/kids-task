import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildKidsThemeBySlug resolve cada slug conhecido', () {
    expect(
      buildKidsThemeBySlug(
        'block_world',
      ).extension<KidsTaskTokens>()!.colorPrimary,
      buildBlockWorldTheme().extension<KidsTaskTokens>()!.colorPrimary,
    );
    expect(
      buildKidsThemeBySlug(
        'space_adventure',
      ).extension<KidsTaskTokens>()!.colorPrimary,
      buildSpaceAdventureTheme().extension<KidsTaskTokens>()!.colorPrimary,
    );
    expect(
      buildKidsThemeBySlug(
        'castles_quest',
      ).extension<KidsTaskTokens>()!.colorPrimary,
      buildCastlesQuestTheme().extension<KidsTaskTokens>()!.colorPrimary,
    );
  });

  test(
    'buildKidsThemeBySlug cai no Tema Infantil Padrão para slug desconhecido ou nulo',
    () {
      final fallbackForUnknown = buildKidsThemeBySlug('does_not_exist');
      final fallbackForNull = buildKidsThemeBySlug(null);
      final defaultTheme = buildKidsDefaultTheme();

      expect(
        fallbackForUnknown.extension<KidsTaskTokens>()!.colorPrimary,
        defaultTheme.extension<KidsTaskTokens>()!.colorPrimary,
      );
      expect(
        fallbackForNull.extension<KidsTaskTokens>()!.colorPrimary,
        defaultTheme.extension<KidsTaskTokens>()!.colorPrimary,
      );
    },
  );
}
