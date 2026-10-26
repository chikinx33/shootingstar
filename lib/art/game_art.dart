import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/houses.dart';
import 'game_icons.dart';
import 'menu_art.dart';

/// v12.15 (user 2026-10-26: every old picture must go): the one registry for
/// pictures drawn through the legacy atlas slots (`ToonTile`, `MenuImage`,
/// battle sprites). Every name resolves to the current art only — the Vacuum
/// Empire machines, the chick pets and the cat-kit icons. The removed v9/v10/
/// v16/v52 folders have no path here.
abstract final class GameArt {
  static bool ready = false;
  static bool battleReady = false;
  static Future<void>? _loading;
  static Future<void>? _battleLoading;

  static const _enemies = 'assets/art/enemies_v14/';
  static const _pets = 'assets/art/pets_v14/';

  /// Names drawn in menus as well as battle (decoded at boot).
  static final Map<String, String> _menuPictures = {
    for (var i = 0; i < 10; i++) 'boss-$i': '${_enemies}boss_$i.webp',
    for (var i = 0; i < 3; i++) 'pet-$i': '${_pets}pet_$i.webp',
    for (final asset in GameIcons.all) asset: asset,
    // supply shelf / reward names
    'gear-cargo': GameIcons.chest,
    'tech-cargo': GameIcons.techTicket,
    'pet-cargo': 'assets/art/ship_parts/orbs/shield.webp',
    'hero': GameIcons.launch,
    'growth-badge': 'assets/art/menu_v13/growth.webp',
    'challenge-badge': 'assets/art/menu_v13/challenge.webp',
    'module-gun': GameIcons.crosshair,
    'module-sensor': GameIcons.gem,
    'module-core': GameIcons.bolt,
    'module-hull': GameIcons.shield,
    'module-belt': GameIcons.coin,
    'module-engine': GameIcons.speed,
    for (var w = 0; w < neighborhoods.length; w++)
      'world-$w': '${houseRoot}house_${w * 10}.jpg',
  };

  /// Enemy sprites are fetched on the first sortie.
  static final Map<String, String> _battlePictures = {
    for (var i = 0; i < 11; i++) 'enemy-$i': '${_enemies}enemy_$i.webp',
  };

  static Future<void> load() => _loading ??= _load();
  static Future<void> _load() async {
    try {
      await Future.wait([
        for (final e in _menuPictures.entries) _decode(e.key, e.value),
      ]);
      ready = true;
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  static Future<void> loadBattle() => _battleLoading ??= _loadBattle();
  static Future<void> _loadBattle() async {
    try {
      await load();
      await Future.wait([
        for (final e in _battlePictures.entries) _decode(e.key, e.value),
      ]);
      battleReady = true;
    } catch (_) {
      _battleLoading = null;
      rethrow;
    }
  }

  static Future<void> _decode(String name, String asset) async {
    if (MenuArt.images.containsKey(name)) return;
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: name.startsWith('boss-')
          ? 384
          : name.startsWith('world-')
          ? 192
          : 256,
    );
    MenuArt.images[name] = (await codec.getNextFrame()).image;
    MenuArt.bounds[name] = const Rect.fromLTRB(0, 0, 1, 1);
    codec.dispose();
  }

  /// The registry name drawn for a legacy atlas slot.
  static String? address(String atlas, int id) {
    switch (atlas) {
      case 'ships':
        return id < 3 ? GameIcons.launch : 'pet-${(id - 3).clamp(0, 2)}';
      case 'enemies':
        return id == 11 ? GameIcons.shield : 'enemy-${id.clamp(0, 10)}';
      case 'bosses':
        return 'boss-${id.clamp(0, 9)}';
      case 'equipment':
        return const [
          'module-gun',
          'module-sensor',
          'module-core',
          'module-hull',
          'module-belt',
          'module-engine',
        ][id % 6];
      case 'icons':
        return icons[id];
      case 'projectiles':
        return const [
          'assets/art/fx_v11/player_bolt.webp',
          'assets/art/fx_v11/player_missile.webp',
          'assets/art/fx_v11/enemy_orb.webp',
        ][id == 2 || id == 18
            ? 1
            : [4, 15, 16, 20].contains(id)
            ? 2
            : 0];
      case 'effects':
        return const [
          'assets/art/fx_v11/explosion.webp',
          'assets/art/fx_v11/hit_spark.webp',
          'assets/art/fx_v11/level_burst.webp',
        ][switch (id) {
          0 || 1 || 2 || 10 || 15 => 0,
          6 || 9 || 12 || 13 => 2,
          _ => 1,
        }];
    }
    return null;
  }

  /// Legacy icon slots → current pictures. Slots without an entry are plain
  /// controls (close / back) that stay as outlined glyphs.
  static final icons = <int, String>{
    0: 'assets/art/menu_v13/patrol.webp',
    1: GameIcons.launch,
    2: GameIcons.chest,
    3: 'assets/art/menu_v13/challenge.webp',
    4: GameIcons.codex,
    5: GameIcons.settings,
    8: GameIcons.pause,
    9: GameIcons.heart,
    10: GameIcons.heal,
    11: GameIcons.magnet,
    12: GameIcons.bomb,
    13: GameIcons.bossChest,
    14: GameIcons.fastForward,
    15: 'assets/art/menu_v13/hangar.webp',
    16: 'assets/art/menu_v13/growth.webp',
    17: GameIcons.crosshair,
    18: GameIcons.missile,
    19: GameIcons.chick,
    20: GameIcons.shield,
    21: 'assets/art/icons_v12/paw_bounce.webp',
    22: 'assets/art/icons_v12/satellite.webp',
    23: 'assets/art/icons_v12/paw_laser.webp',
    24: GameIcons.shield,
    25: GameIcons.shield,
    26: 'assets/art/icons_v12/paw_crescent.webp',
    27: GameIcons.bomb,
    28: 'assets/art/icons_v12/paw_orbit.webp',
    29: 'assets/art/icons_v12/paw_yarn.webp',
    30: GameIcons.shield,
    31: GameIcons.bolt,
    32: 'assets/art/icons_v12/paw_zap.webp',
    33: GameIcons.hourglass,
    35: GameIcons.speed,
    36: GameIcons.gem,
    37: GameIcons.bolt,
    38: GameIcons.shield,
    39: GameIcons.heal,
    40: 'assets/art/menu_v13/challenge.webp',
    41: GameIcons.coin,
    42: GameIcons.crosshair,
    43: GameIcons.crosshair,
    44: GameIcons.launch,
    45: GameIcons.coin,
    46: GameIcons.gem,
    47: GameIcons.heal,
    48: 'assets/art/menu_v13/patrol.webp',
    49: GameIcons.chest,
    50: GameIcons.lock,
    51: GameIcons.check,
    52: GameIcons.chest,
    53: GameIcons.refresh,
    55: 'assets/art/menu_v13/guild.webp',
    58: GameIcons.chest,
    59: GameIcons.key,
    60: GameIcons.gem,
    61: GameIcons.techTicket,
    62: GameIcons.chick,
    63: GameIcons.calendar,
  };

  static bool paint(
    Canvas c,
    String atlas,
    int id,
    Rect target, {
    double opacity = 1,
    Color? tint,
  }) {
    if (target.isEmpty || !ready) return false;
    if (atlas == 'worlds') {
      paintWorldBadge(c, id, target, opacity: opacity);
      return true;
    }
    final name = address(atlas, id);
    if (name == null) return false;
    return MenuArt.paint(c, name, target, opacity: opacity, tint: tint);
  }

  /// A neighbourhood badge: its first house seen from the sky, in a frame.
  static void paintWorldBadge(
    Canvas c,
    int world,
    Rect target, {
    double opacity = 1,
  }) {
    final frame = RRect.fromRectAndRadius(
      target.deflate(1),
      Radius.circular(target.shortestSide * .18),
    );
    c.save();
    c.clipRRect(frame);
    c.drawRect(target, Paint()..color = const Color(0xFF142C43));
    MenuArt.paint(
      c,
      'world-${world % neighborhoods.length}',
      target,
      cover: true,
      opacity: opacity,
    );
    c.restore();
    c.drawRRect(
      frame,
      Paint()
        ..color = const Color(0xFFFFD447).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}
