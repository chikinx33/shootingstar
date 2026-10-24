import '../l10n/app_language.dart';

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lobby_art.dart';
import 'menu_art.dart';
import 'flight_scene_art.dart';
import 'gear_art.dart';

/// One art vocabulary shared by gameplay, inventory, guides and reward screens.
abstract final class GameArt {
  static const _worldBadgeIcons = [
    ('lobby/guild', 'game/rock', 1.0),
    ('game/rock', 'game/rock', .7),
    ('game/gear-core', 'game/ring', .8),
    ('game/crystal', 'game/ice', .75),
    ('game/mushroom', 'game/mushroom', 1.1),
    ('game/gear-hull', 'game/gear-engine', 1.0),
    ('game/rock', 'game/fire', .8),
    ('game/rock', 'game/ring', 1.2),
    ('game/crystal', 'game/crystal', 1.1),
    ('game/gear-core', 'game/ring', 1.25),
  ];

  static const root = 'assets/art/game_v10/';
  static bool ready = false;
  static bool battleReady = false;
  static Future<void>? _loading;
  static Future<void>? _battleLoading;
  static Map<dynamic, dynamic> _manifest = {};
  static bool battleOnly(String name) => name.startsWith('enemy-');
  static const gear = [
    'gear-gun',
    'gear-sensor',
    'gear-core',
    'gear-hull',
    'gear-belt',
    'gear-engine',
  ];
  static Future<void> load() => _loading ??= _load();
  static Future<void> _load() async {
    final map =
        jsonDecode(await rootBundle.loadString('${root}manifest.json')) as Map;
    if (map.length != 51) {
      throw StateError('Game art pack is incomplete: ${map.length}/51');
    }
    _manifest = map;
    await Future.wait([
      for (final entry in map.entries)
        if (!battleOnly(entry.key as String))
          _decode(entry.key as String, entry.value as Map),
    ]);
    await GearArt.load();
    MenuArt.aliases.addAll({
      'hero': 'lobby/hero',
      'hero-vector': 'lobby/vector',
      'hero-monolith': 'lobby/monolith',
      'hangar': 'lobby/backdrop',
      'growth': 'lobby/backdrop',
      'supply': 'game/menu-purple',
      'gear-cargo': 'lobby/chest',
      'tech-cargo': 'game/gear-core',
      'pet-cargo': 'game/pet-0',
      'growth-badge': 'lobby/growth',
      'challenge-badge': 'lobby/challenge',
      for (var i = 0; i < gear.length; i++)
        'module-${const ['gun', 'sensor', 'core', 'hull', 'belt', 'engine'][i]}':
            'game/${gear[i]}',
    });
    for (final alias in MenuArt.aliases.entries) {
      MenuArt.images[alias.key] = MenuArt.images[alias.value]!;
      MenuArt.bounds[alias.key] = MenuArt.bounds[alias.value]!;
    }
    ready = true;
  }

  static Future<void> _decode(String name, Map meta) async {
    final key = 'game/$name';
    if (MenuArt.images.containsKey(key)) return;
    final data = await rootBundle.load('$root$name.webp');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: name.startsWith('boss-') ? 384 : 256,
    );
    MenuArt.images[key] = (await codec.getNextFrame()).image;
    codec.dispose();
    final b = (meta['bounds'] as List).cast<num>();
    MenuArt.bounds[key] = Rect.fromLTRB(
      b[0].toDouble(),
      b[1].toDouble(),
      b[2].toDouble(),
      b[3].toDouble(),
    );
  }

  /// Enemy art is fetched on first sortie. Boss thumbnails remain usable in UI.
  static Future<void> loadBattle() => _battleLoading ??= _loadBattle();
  static Future<void> _loadBattle() async {
    try {
      await load();
      await Future.wait([
        for (final entry in _manifest.entries)
          if (battleOnly(entry.key as String))
            _decode(entry.key as String, entry.value as Map),
      ]);
      battleReady = true;
    } catch (_) {
      _battleLoading = null;
      rethrow;
    }
  }

  static String? address(String atlas, int id) {
    if (atlas == 'ships') {
      return id < 3
          ? 'lobby/${LobbyArt.ship(id)}'
          : 'game/pet-${(id - 3).clamp(0, 2)}';
    }
    if (atlas == 'enemies') {
      return id == 11 ? 'game/shield' : 'game/enemy-${id.clamp(0, 10)}';
    }
    if (atlas == 'bosses') return 'game/boss-${id.clamp(0, 9)}';
    if (atlas == 'equipment') {
      return GearArt.address(id);
    }
    if (atlas == 'icons') return icons[id];
    if (atlas == 'projectiles') {
      return 'game/${const ['pulse', 'pulse', 'missile', 'pulse', 'pulse', 'pulse', 'pulse', 'ball', 'drill', 'mine', 'boomerang', 'lightning', 'fire', 'laser', 'mine', 'pulse', 'pulse', 'laser', 'missile', 'gear-gun', 'mine', 'gem', 'pet-0', 'fire'][id.clamp(0, 23)]}';
    }
    if (atlas == 'effects') {
      return 'game/${const ['impact', 'impact', 'impact', 'spark', 'spark', 'lightning', 'ring', 'spark', 'shield', 'ring', 'fire', 'ice', 'ring', 'ring', 'spark', 'impact'][id.clamp(0, 15)]}';
    }
    return null;
  }

  static const icons = <int, String>{
    0: 'lobby/radar',
    1: 'lobby/hero',
    2: 'lobby/chest',
    3: 'lobby/challenge',
    4: 'lobby/research',
    9: 'game/medkit',
    10: 'game/medkit',
    11: 'game/magnet',
    12: 'game/mine',
    13: 'lobby/chest',
    14: 'lobby/growth',
    15: 'game/gear-core',
    16: 'lobby/growth',
    17: 'game/gear-gun',
    18: 'game/missile',
    19: 'game/pet-0',
    20: 'game/shield',
    21: 'game/ball',
    22: 'game/drill',
    23: 'game/laser',
    24: 'game/shield',
    25: 'game/gear-hull',
    26: 'game/boomerang',
    27: 'game/mine',
    28: 'game/mine',
    29: 'game/fire',
    30: 'game/shield',
    31: 'game/lightning',
    32: 'game/fire',
    36: 'game/gem',
    37: 'game/gear-core',
    38: 'game/gear-hull',
    39: 'game/medkit',
    40: 'lobby/challenge',
    41: 'lobby/coin',
    43: 'game/gear-gun',
    44: 'lobby/hero',
    45: 'lobby/coin',
    46: 'game/ice',
    47: 'game/medkit',
    48: 'lobby/radar',
    49: 'lobby/chest',
    52: 'lobby/chest',
    55: 'lobby/guild',
    58: 'lobby/chest',
    59: 'lobby/key',
    60: 'game/gem',
    61: 'lobby/blueprint',
    62: 'game/pet-0',
    63: 'lobby/mission',
  };
  static const glyphs = <int, IconData>{
    5: Icons.settings,
    6: Icons.volume_up,
    7: Icons.volume_off,
    8: Icons.pause,
    33: Icons.hourglass_bottom,
    34: Icons.zoom_out_map,
    35: Icons.speed,
    42: Icons.gps_fixed,
    50: Icons.lock,
    51: Icons.check_circle,
    53: Icons.refresh,
    54: Icons.cloud_done,
    56: Icons.arrow_back,
    57: Icons.close,
  };

  static bool paint(
    Canvas c,
    String atlas,
    int id,
    Rect target, {
    double opacity = 1,
    Color? tint,
  }) {
    if (target.isEmpty) return false;
    if (atlas == 'equipment' && GearArt.ready)
      return GearArt.paint(c, id, target, opacity: opacity);
    if (!ready) return false;
    if (atlas == 'worlds') {
      paintWorldBadge(c, id, target, opacity: opacity);
      return true;
    }
    final name = address(atlas, id);
    if (name != null) {
      final hue =
          tint ??
          (atlas == 'effects' && [12, 13].contains(id)
              ? const Color(0xFFFF7657)
              : atlas == 'effects' && id == 6
              ? const Color(0xFF6BE7DC)
              : atlas == 'effects' && id == 9
              ? const Color(0xFFBE8EFF)
              : atlas == 'projectiles' && [4, 15, 16, 20].contains(id)
              ? const Color(0xFFFF7657)
              : null);
      if (atlas == 'projectiles' && [2, 18].contains(id)) {
        c.save();
        c.translate(target.center.dx, target.center.dy);
        c.rotate(-.7853981633974483);
        final painted = MenuArt.paint(
          c,
          name,
          Rect.fromCenter(
            center: Offset.zero,
            width: target.width,
            height: target.height,
          ),
          opacity: opacity,
          tint: hue,
        );
        c.restore();
        return painted;
      }
      return MenuArt.paint(c, name, target, opacity: opacity, tint: hue);
    }
    final glyph = atlas == 'icons' ? glyphs[id] : null;
    if (glyph == null) return false;
    final extent = target.shortestSide * .78;
    TextPainter text(Paint paint) => TextPainter(
      text: TextSpan(
        text: tr(String.fromCharCode(glyph.codePoint)),
        style: TextStyle(
          fontFamily: glyph.fontFamily,
          fontSize: extent,
          foreground: paint,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final edge = text(
      Paint()
        ..color = const Color(0xFF111318).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final fill = text(
      Paint()
        ..color = (tint ?? const Color(0xFFFFD43D)).withValues(alpha: opacity),
    );
    final at = target.center - Offset(fill.width / 2, fill.height / 2);
    edge.paint(c, at);
    fill.paint(c, at);
    return true;
  }

  static const groundColors = [
    Color(0xFFB9D5B4),
    Color(0xFFE9AF91),
    Color(0xFFB8ACD6),
    Color(0xFFC9E8EF),
    Color(0xFFB5D89D),
    Color(0xFFC7C1AB),
    Color(0xFFF3C783),
    Color(0xFF9FC3D9),
    Color(0xFFDBC2E6),
    Color(0xFFA9B4D0),
  ];

  /// World thumbnails combine the distant sky and explicit route icons. A 540px terrain tile made props unreadable in 56/72px UI slots.
  static void paintWorldBadge(
    Canvas c,
    int world,
    Rect target, {
    double opacity = 1,
  }) {
    final id = world.clamp(0, 9), props = _worldBadgeIcons[world.clamp(0, 9)];
    if (opacity < 1) {
      c.saveLayer(
        target,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    } else {
      c.save();
    }
    final frame = RRect.fromRectAndRadius(
      target.deflate(1),
      Radius.circular(target.shortestSide * .14),
    );
    c.clipRRect(frame);
    c.drawRect(target, Paint()..color = const Color(0xFF142C43));
    // v11: the world's own ground with its fleet commander on top.
    final ground = FlightSceneArt.worldImages[id];
    if (ground != null) {
      final side = ground.width.toDouble();
      c.drawImageRect(
        ground,
        Rect.fromLTWH(0, (ground.height - side) / 2, side, side),
        target,
        Paint()..filterQuality = FilterQuality.medium,
      );
      final extent = target.shortestSide;
      MenuArt.paint(
        c,
        'game/boss-$id',
        Rect.fromCenter(
          center: target.center,
          width: extent * .86,
          height: extent * .86,
        ),
      );
      c.drawRRect(
        frame,
        Paint()
          ..color = groundColors[id]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      c.restore();
      return;
    }
    c.drawRect(
      target,
      Paint()..color = groundColors[id].withValues(alpha: .22),
    );
    if (id == 2 || id == 9) {
      MenuArt.paint(
        c,
        'game/ring',
        target.deflate(target.width * .04),
        opacity: .8,
      );
    }
    final extent = target.shortestSide;
    MenuArt.paint(
      c,
      props.$1,
      Rect.fromCenter(
        center: target.center + Offset(-extent * .07, -extent * .07),
        width: extent * .82,
        height: extent * .82,
      ),
    );
    MenuArt.paint(
      c,
      props.$2,
      Rect.fromCenter(
        center: target.center + Offset(extent * .24, extent * .25),
        width: extent * .44,
        height: extent * .44,
      ),
    );
    c.drawRRect(
      frame,
      Paint()
        ..color = groundColors[id]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    c.restore();
  }

  static void paintWorld(Canvas c, int world, Rect target) {
    final id = world.clamp(0, 9), base = groundColors[id];
    c.save();
    c.clipRect(target, doAntiAlias: false);
    c.translate(target.left, target.top);
    c.scale(target.width / 540, target.height / 540);
    c.drawRect(const Rect.fromLTWH(-1, -1, 542, 542), Paint()..color = base);
    // Flat quiet terrain; isolated AI props cannot create atlas or tile seams.
    final track = Color.lerp(base, const Color(0xFF5B7387), .34)!;
    if (id == 0 || id == 5) {
      c.drawRect(
        const Rect.fromLTWH(193, -1, 154, 542),
        Paint()..color = track,
      );
      final edge = Paint()
        ..color = Color.lerp(base, Colors.white, .35)!
        ..strokeWidth = 4;
      c.drawLine(const Offset(191, 0), const Offset(191, 540), edge);
      c.drawLine(const Offset(349, 0), const Offset(349, 540), edge);
    } else {
      for (final patch in const [
        Rect.fromLTWH(25, 30, 210, 190),
        Rect.fromLTWH(305, 280, 190, 220),
      ]) {
        c.drawOval(
          patch,
          Paint()..color = Color.lerp(base, Colors.white, .12)!,
        );
      }
    }
    final prop = const [
      'lobby/guild',
      'game/rock',
      'game/gear-core',
      'game/crystal',
      'game/mushroom',
      'game/gear-hull',
      'game/rock',
      'game/rock',
      'game/crystal',
      'game/gear-core',
    ][id];
    final transform = c.getTransform();
    final flipX = transform[0] < 0 ? -1.0 : 1.0;
    final flipY = transform[5] < 0 ? -1.0 : 1.0;
    for (final at in const [Offset(88, 105), Offset(448, 355)]) {
      // The floor can mirror to repeat; illustrated scenery stays upright.
      c.save();
      c.translate(at.dx, at.dy);
      c.scale(flipX, flipY);
      MenuArt.paint(
        c,
        prop,
        const Rect.fromLTWH(-45, -45, 90, 90),
        opacity: .52,
      );
      c.restore();
    }
    if (id == 0 || id == 5) {
      for (final y in const [40.0, 220.0, 400.0]) {
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(263, y, 14, 48),
            const Radius.circular(4),
          ),
          Paint()..color = Color.lerp(base, Colors.white, .5)!,
        );
      }
    }
    c.restore();
  }
}
