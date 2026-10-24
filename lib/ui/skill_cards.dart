import 'package:flutter/material.dart';

import '../game/engine.dart';

/// v12.7 skill cards (user 2026-10-25): every choice is an illustrated card
/// whose frame grows richer with the skill's stage, gray → blue → green →
/// orange-red → gold → purple.
abstract final class SkillCardArt {
  static const root = 'assets/art/cards_v13/';

  static String frame(int tier) => '${root}frame_${tier.clamp(1, 6)}.webp';

  /// Each frame's size (px) and its inner window (fractions of that size),
  /// measured on the cut sheet. Windows line up across tiers; the richer
  /// ornaments of higher tiers spill outside them.
  static const frames = [
    (Size(300, 367), Rect.fromLTRB(.131, .192, .866, .886)),
    (Size(300, 366), Rect.fromLTRB(.137, .216, .866, .888)),
    (Size(300, 384), Rect.fromLTRB(.164, .214, .831, .798)),
    (Size(300, 331), Rect.fromLTRB(.220, .225, .780, .879)),
    (Size(300, 317), Rect.fromLTRB(.200, .256, .800, .881)),
    (Size(300, 334), Rect.fromLTRB(.193, .271, .805, .848)),
  ];

  static const effects = [
    'rays', 'glow', 'sparkle', 'ring', 'vortex', 'particles', 'lightning', //
    'flare',
  ];

  /// Everything a draft can show, for precaching before the first one.
  static List<String> get preload => [
    for (var t = 1; t <= 6; t++) frame(t),
    for (final e in effects) fx(e),
    for (final a in all) '$root$a.webp',
  ];
  static String fx(String name) => '${root}fx_$name.webp';

  /// Illustration for [choice], or null when it has none (special cards).
  static String? art(UpgradeChoice choice) {
    final id = choice.id.contains('|')
        ? choice.id.substring(choice.id.indexOf('|') + 1)
        : choice.id;
    final base = _weapons[id] ?? _passives[id];
    if (base == null) return null;
    final ultimate = choice.growth == 'ult' && _weapons.containsKey(id);
    return '$root${ultimate ? 'ult_$base' : base}.webp';
  }

  static const _weapons = {
    'part:W1': 'vulcan',
    'part:W4': 'vulcan',
    'part:W3': 'mortar',
    'paw:bounce': 'bounce',
    'paw:crescent': 'crescent',
    'paw:laser': 'laser',
    'paw:orbit': 'orbit',
    'paw:yarn': 'yarn',
    'paw:zap': 'zap',
  };
  static const _passives = {
    'attack': 'attack',
    'cooldown': 'cooldown',
    'hull': 'hull',
    'magnet': 'magnet',
    'speed': 'speed',
    'repair': 'repair',
  };

  static const all = [
    'vulcan', 'mortar', 'bounce', 'crescent', 'laser', 'orbit', 'yarn', //
    'zap', 'attack', 'cooldown', 'hull', 'magnet', 'speed', 'repair',
    'ult_vulcan', 'ult_mortar', 'ult_bounce', 'ult_crescent', 'ult_laser',
    'ult_orbit', 'ult_yarn', 'ult_zap',
  ];
}

/// The look of one card tier.
class SkillTier {
  const SkillTier(this.level, this.color, this.deep, this.name);
  final int level;
  final Color color, deep;
  final String name;

  static const all = [
    SkillTier(1, Color(0xFFC3CCD6), Color(0xFF3B4652), '일반'),
    SkillTier(2, Color(0xFF52B0FF), Color(0xFF123A66), '고급'),
    SkillTier(3, Color(0xFF4FDB8C), Color(0xFF0F4A33), '희귀'),
    SkillTier(4, Color(0xFFFF7A3D), Color(0xFF5C1E0E), '영웅'),
    SkillTier(5, Color(0xFFFFD447), Color(0xFF5E4300), '전설'),
    SkillTier(6, Color(0xFFC77DFF), Color(0xFF34105A), '신화'),
  ];

  static SkillTier of(int level) => all[level.clamp(1, 6) - 1];

  /// Gold and purple cards carry light rays; purple adds a cosmic vortex.
  bool get radiant => level >= 5;
  bool get mythic => level >= 6;
}

/// Tier for [choice] from the stage it leads to: a new weapon is gray,
/// 강화 1–2 blue, 강화 3 green, 진화 1–2 orange-red, 진화 3 gold and the
/// 궁극 transformation purple. Support skills climb with their level.
int skillCardTier(GameEngine game, UpgradeChoice choice) {
  final id = choice.id.contains('|')
      ? choice.id.substring(choice.id.indexOf('|') + 1)
      : choice.id;
  switch (choice.growth) {
    case 'ult':
      return 6;
    case 'evo':
      return game.evo(id) + 1 >= 3 ? 5 : 4;
    case 'enh':
      return game.enh(id) + 1 >= 3 ? 3 : 2;
    case 'new':
      return 1;
  }
  if (choice.specialization) return 4;
  if (choice.evolution) return 5;
  if (choice.id == 'repair') return 1;
  return (skillRank(game, choice) + 1).clamp(1, 5);
}

/// Current level of a plain (support or legacy weapon) skill card; 0 for
/// growth, special and recovery cards, which are not skills.
int skillRank(GameEngine game, UpgradeChoice choice) {
  final id = choice.id;
  if (choice.growth.isNotEmpty ||
      choice.specialization ||
      id == 'repair' ||
      id.contains('|') ||
      id.contains(':')) {
    return 0;
  }
  try {
    final passive = game.isPassiveSkill(id);
    return (passive ? game.passives : game.upgrades)[id] ?? 0;
  } on StateError {
    return 0;
  }
}
