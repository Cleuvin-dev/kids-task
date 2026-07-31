import 'package:flutter/material.dart';

/// Tokens semânticos consumidos pelo app e por cada pacote de tema.
///
/// O código nunca usa cores/valores soltos: sempre lê
/// `Theme.of(context).extension<KidsTaskTokens>()`. Isso permite trocar um
/// tema (azul/rosa do responsável, ou o tema de uma criança) sem alterar
/// nenhuma tela. Ver `docs/06_TEMAS_DESIGN_E_FAIXAS_ETARIAS.md` seção 6.
///
/// Um tema ausente ou com asset faltante nunca pode quebrar uma tela: por
/// isso [KidsTaskTokens.fallback] fornece um conjunto seguro de valores.
@immutable
class KidsTaskTokens extends ThemeExtension<KidsTaskTokens> {
  const KidsTaskTokens({
    required this.colorPrimary,
    required this.colorOnPrimary,
    required this.colorBackground,
    required this.colorSurface,
    required this.colorOnSurface,
    required this.colorSuccess,
    required this.colorWarning,
    required this.colorError,
    required this.colorCoin,
    required this.colorXp,
    required this.radiusCard,
    required this.radiusButton,
    required this.motionReward,
    required this.soundComplete,
  });

  final Color colorPrimary;
  final Color colorOnPrimary;
  final Color colorBackground;
  final Color colorSurface;
  final Color colorOnSurface;
  final Color colorSuccess;
  final Color colorWarning;
  final Color colorError;
  final Color colorCoin;
  final Color colorXp;

  final double radiusCard;
  final double radiusButton;

  /// Duração da animação de recompensa (confete/moeda). Deve respeitar
  /// "reduzir movimento" na camada de apresentação.
  final Duration motionReward;

  /// Chave lógica do som de conclusão; a app resolve o asset real.
  final String soundComplete;

  /// Conjunto neutro e sempre disponível, usado quando um tema ou asset
  /// específico não pôde ser carregado.
  static const fallback = KidsTaskTokens(
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
  );

  @override
  KidsTaskTokens copyWith({
    Color? colorPrimary,
    Color? colorOnPrimary,
    Color? colorBackground,
    Color? colorSurface,
    Color? colorOnSurface,
    Color? colorSuccess,
    Color? colorWarning,
    Color? colorError,
    Color? colorCoin,
    Color? colorXp,
    double? radiusCard,
    double? radiusButton,
    Duration? motionReward,
    String? soundComplete,
  }) {
    return KidsTaskTokens(
      colorPrimary: colorPrimary ?? this.colorPrimary,
      colorOnPrimary: colorOnPrimary ?? this.colorOnPrimary,
      colorBackground: colorBackground ?? this.colorBackground,
      colorSurface: colorSurface ?? this.colorSurface,
      colorOnSurface: colorOnSurface ?? this.colorOnSurface,
      colorSuccess: colorSuccess ?? this.colorSuccess,
      colorWarning: colorWarning ?? this.colorWarning,
      colorError: colorError ?? this.colorError,
      colorCoin: colorCoin ?? this.colorCoin,
      colorXp: colorXp ?? this.colorXp,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusButton: radiusButton ?? this.radiusButton,
      motionReward: motionReward ?? this.motionReward,
      soundComplete: soundComplete ?? this.soundComplete,
    );
  }

  @override
  KidsTaskTokens lerp(ThemeExtension<KidsTaskTokens>? other, double t) {
    if (other is! KidsTaskTokens) return this;
    return KidsTaskTokens(
      colorPrimary: Color.lerp(colorPrimary, other.colorPrimary, t)!,
      colorOnPrimary: Color.lerp(colorOnPrimary, other.colorOnPrimary, t)!,
      colorBackground: Color.lerp(colorBackground, other.colorBackground, t)!,
      colorSurface: Color.lerp(colorSurface, other.colorSurface, t)!,
      colorOnSurface: Color.lerp(colorOnSurface, other.colorOnSurface, t)!,
      colorSuccess: Color.lerp(colorSuccess, other.colorSuccess, t)!,
      colorWarning: Color.lerp(colorWarning, other.colorWarning, t)!,
      colorError: Color.lerp(colorError, other.colorError, t)!,
      colorCoin: Color.lerp(colorCoin, other.colorCoin, t)!,
      colorXp: Color.lerp(colorXp, other.colorXp, t)!,
      radiusCard: radiusCard + (other.radiusCard - radiusCard) * t,
      radiusButton: radiusButton + (other.radiusButton - radiusButton) * t,
      motionReward: t < 0.5 ? motionReward : other.motionReward,
      soundComplete: t < 0.5 ? soundComplete : other.soundComplete,
    );
  }
}

/// Acesso seguro ao token do tema atual, com fallback garantido.
extension KidsTaskTokensContext on BuildContext {
  KidsTaskTokens get kidsTaskTokens =>
      Theme.of(this).extension<KidsTaskTokens>() ?? KidsTaskTokens.fallback;
}
