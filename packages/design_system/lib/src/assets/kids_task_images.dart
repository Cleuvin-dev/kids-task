/// Caminhos dos assets de imagem do Kid's Task.
///
/// Centralizados aqui para que nenhuma tela use uma string de asset solta.
/// As imagens têm origem no material de identidade visual em `img/` (raiz do
/// repositório) e foram processadas (remoção de fundo de croma e recorte)
/// para `packages/design_system/assets/`. Ver `packages/design_system/assets/README.md`.
class KidsTaskImages {
  KidsTaskImages._();

  static const _pkg = 'packages/design_system/assets';

  /// Logotipo "KID'S TASK" com fundo transparente, para uso sobre qualquer cor.
  static const wordmark = '$_pkg/brand/wordmark.png';

  /// Fundo decorativo da tela comum de acesso (`docs/07`, seção 2).
  static const accessBackground = '$_pkg/backgrounds/access_background.jpg';

  /// Banner decorativo do início do responsável (`docs/07`, seção 4.1).
  static const dashboardBanner = '$_pkg/backgrounds/dashboard_banner.jpg';

  /// Fundo reservado para a tela de relatórios (Marco 2/7 — ainda não construída).
  static const reportsBackground = '$_pkg/backgrounds/reports_background.jpg';

  /// Fundo decorativo genérico (onboarding, telas neutras da criança).
  static const journeyBackground = '$_pkg/backgrounds/journey_background.jpg';

  /// Ícone do KidsCoin — usar sempre com o token [KidsTaskTokens.colorCoin]
  /// como referência de cor complementar, nunca como substituto do valor
  /// numérico do saldo.
  static const kidsCoin = '$_pkg/coins/kidscoin.png';

  /// Duas variantes de cor do sparkle de XP. Nomeadas por cor, não por
  /// gênero: o Kid's Task não coleta gênero (`CLAUDE.md`) e não oferece
  /// seleção de avatar por gênero. A escolha entre as duas é puramente
  /// estética/decorativa.
  static const xpSparkleTeal = '$_pkg/xp/xp_sparkle_teal.png';
  static const xpSparkleViolet = '$_pkg/xp/xp_sparkle_violet.png';

  /// Fundos do catálogo de temas infantis (`docs/06`, seção 3).
  static const blockWorldBackground = '$_pkg/themes/block_world_background.jpg';
  static const spaceAdventureBackground =
      '$_pkg/themes/space_adventure_background.jpg';
  static const castlesQuestBackground =
      '$_pkg/themes/castles_quest_background.jpg';
}
