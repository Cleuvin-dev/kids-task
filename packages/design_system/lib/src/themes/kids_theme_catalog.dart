import '../assets/kids_task_images.dart';
import 'kids_default_theme.dart';

/// Plano necessário para usar um tema, espelhando `plans.code` no backend.
enum ThemePlanTier { free, premium }

/// Entrada do catálogo de temas infantis (`docs/06_TEMAS_DESIGN_E_FAIXAS_ETARIAS.md`,
/// seção 3). `backgroundAsset` é `null` quando a arte final ainda não existe;
/// a tela de seleção (Marco 5) deve tratar isso como indisponível, nunca
/// quebrar.
class KidsThemeCatalogEntry {
  const KidsThemeCatalogEntry({
    required this.slug,
    required this.name,
    required this.planTier,
    this.backgroundAsset,
  });

  final String slug;
  final String name;
  final ThemePlanTier planTier;
  final String? backgroundAsset;
}

/// Catálogo com os temas para os quais já existe arte processada. Os demais
/// temas do catálogo pretendido (`docs/06`, seção 3) entram quando a arte
/// correspondente for produzida — a lista cresce sem exigir mudança de
/// navegação (contrato de tema, `docs/06`, seção 5).
const kidsThemeCatalog = <KidsThemeCatalogEntry>[
  KidsThemeCatalogEntry(
    slug: kidsDefaultThemeSlug,
    name: "Tema Infantil Padrão",
    planTier: ThemePlanTier.free,
  ),
  KidsThemeCatalogEntry(
    slug: 'block_world',
    name: 'Mundo dos Blocos',
    planTier: ThemePlanTier.free,
    backgroundAsset: KidsTaskImages.blockWorldBackground,
  ),
  KidsThemeCatalogEntry(
    slug: 'space_adventure',
    name: 'Aventura Espacial',
    planTier: ThemePlanTier.premium,
    backgroundAsset: KidsTaskImages.spaceAdventureBackground,
  ),
  KidsThemeCatalogEntry(
    slug: 'castles_quest',
    name: 'Princesas e Castelos',
    planTier: ThemePlanTier.premium,
    backgroundAsset: KidsTaskImages.castlesQuestBackground,
  ),
];
