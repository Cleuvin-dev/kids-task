import 'package:flutter/material.dart';

/// Avatar padrão de uma criança (`child_profiles.avatar_id`).
///
/// Lista mínima e neutra quanto a gênero (docs/03 seção 6: "escolhe seu
/// avatar/apelido em uma lista mínima"; CLAUDE.md: "Não coletar gênero").
/// Ícone + cor, sem fotos nem personagens de terceiros — foto real
/// permanece opcional e privada, fora deste catálogo.
class ChildAvatarOption {
  const ChildAvatarOption({
    required this.id,
    required this.icon,
    required this.color,
  });

  final String id;
  final IconData icon;
  final Color color;
}

const childAvatarCatalog = <ChildAvatarOption>[
  ChildAvatarOption(
    id: 'default',
    icon: Icons.face_rounded,
    color: Color(0xFF2F80ED),
  ),
  ChildAvatarOption(
    id: 'star',
    icon: Icons.star_rounded,
    color: Color(0xFFF5A623),
  ),
  ChildAvatarOption(
    id: 'rocket',
    icon: Icons.rocket_launch_rounded,
    color: Color(0xFF7C4DFF),
  ),
  ChildAvatarOption(
    id: 'leaf',
    icon: Icons.eco_rounded,
    color: Color(0xFF2E7D32),
  ),
  ChildAvatarOption(
    id: 'wave',
    icon: Icons.water_drop_rounded,
    color: Color(0xFF3DBEFF),
  ),
  ChildAvatarOption(
    id: 'heart',
    icon: Icons.favorite_rounded,
    color: Color(0xFFE95D9A),
  ),
];

ChildAvatarOption childAvatarById(String id) => childAvatarCatalog.firstWhere(
  (a) => a.id == id,
  orElse: () => childAvatarCatalog.first,
);
