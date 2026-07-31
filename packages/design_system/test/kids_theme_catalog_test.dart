import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('todo asset referenciado por KidsTaskImages existe em disco', () {
    const paths = [
      KidsTaskImages.wordmark,
      KidsTaskImages.accessBackground,
      KidsTaskImages.dashboardBanner,
      KidsTaskImages.reportsBackground,
      KidsTaskImages.journeyBackground,
      KidsTaskImages.kidsCoin,
      KidsTaskImages.xpSparkleTeal,
      KidsTaskImages.xpSparkleViolet,
      KidsTaskImages.blockWorldBackground,
      KidsTaskImages.spaceAdventureBackground,
      KidsTaskImages.castlesQuestBackground,
    ];

    for (final assetPath in paths) {
      final relative = assetPath.replaceFirst('packages/design_system/', '');
      final file = File(relative);
      expect(file.existsSync(), isTrue, reason: '$relative deveria existir');
    }
  });

  test(
    'catálogo de temas usa slugs exatos de docs/06 e tem arte para os não-placeholder',
    () {
      final slugs = kidsThemeCatalog.map((e) => e.slug).toSet();
      expect(slugs, {
        'kids_default',
        'block_world',
        'space_adventure',
        'castles_quest',
      });

      for (final entry in kidsThemeCatalog) {
        if (entry.slug == 'kids_default') {
          expect(entry.backgroundAsset, isNull);
        } else {
          expect(entry.backgroundAsset, isNotNull);
        }
      }

      final freeSlugs = kidsThemeCatalog
          .where((e) => e.planTier == ThemePlanTier.free)
          .map((e) => e.slug)
          .toSet();
      expect(freeSlugs, {'kids_default', 'block_world'});
    },
  );
}
