import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'arcade_style.dart';
import 'toon_assets.dart';
import 'game_art.dart';

/// Generated scenery/enemy PNGs, with legacy loading fallbacks; no engine dependency.
abstract final class ArcadeWorld {
  // App-owned, lazy rasterizations of the complete vector artwork below.
  // Maximum RGBA pixels: 19,804,800 bytes (18.9 MiB), excluding engine overhead.
  // Faction colors remain exact cache keys; arbitrary callers cannot grow it.
  static final _tiles = <int, ui.Image>{};
  static final _bosses = <int, ui.Image>{};
  static final _enemies = <(int, Color), ui.Image>{};
  static final _imagePaint = Paint()..filterQuality = FilterQuality.low;
  static const _enemyResolution = 112;
  static const _bossResolution = 256;
  static const _tileResolution = 540;
  static const _enemyCapacity = 110;

  static ui.Image _cached<K>(
    Map<K, ui.Image> cache,
    K key,
    int resolution,
    void Function(Canvas) draw, {
    int capacity = 10,
  }) {
    final existing = cache[key];
    if (existing != null) return existing;
    final recorder = ui.PictureRecorder();
    draw(Canvas(recorder));
    final picture = recorder.endRecording();
    late final ui.Image image;
    try {
      // Supported by both this Flutter SDK's CanvasKit and Skwasm backends.
      // A synchronous handle keeps the first encounter visible in this frame.
      image = picture.toImageSync(resolution, resolution);
    } finally {
      picture.dispose();
    }
    if (cache.length >= capacity) {
      cache.remove(cache.keys.first)!.dispose();
    }
    cache[key] = image;
    return image;
  }

  static void _drawImage(Canvas canvas, ui.Image image, Rect target) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      target,
      _imagePaint,
    );
  }

  /// App-owned caches survive battle exits. Explicit teardown is also safe:
  /// subsequent draws lazily reconstruct the same complete artwork.
  static void disposeCachedArt() {
    for (final cache in [_tiles, _bosses]) {
      for (final image in cache.values) {
        image.dispose();
      }
      cache.clear();
    }
    for (final image in _enemies.values) {
      image.dispose();
    }
    _enemies.clear();
  }

  static const _grounds = [
    Color(0xFF425B6E),
    Color(0xFF59434F),
    Color(0xFF413E62),
    Color(0xFF57788A),
    Color(0xFF3F6054),
    Color(0xFF5A514A),
    Color(0xFF57453E),
    Color(0xFF354B68),
    Color(0xFF594C6A),
    Color(0xFF343C53),
  ];
  static const _accents = [
    Color(0xFF83C5CA),
    Color(0xFFE59278),
    Color(0xFFAE94D8),
    Color(0xFFB3E0EB),
    Color(0xFFABD082),
    Color(0xFFC5A476),
    Color(0xFFEFAC58),
    Color(0xFF79A5D9),
    Color(0xFFD5A4DA),
    Color(0xFFE27C9B),
  ];

  static Path _polygon(List<Offset> points) => Path()..addPolygon(points, true);

  static void _shape(Canvas canvas, Path path, Color fill, {double width = 3}) {
    canvas.drawPath(path, Paint()..color = fill);
    if (width == 0) return;
    canvas.drawPath(
      path,
      Paint()
        ..color = ArcadeStyle.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round,
    );
  }

  static Path _radial(
    int count,
    double outer,
    double inner, {
    double angle = -math.pi / 2,
  }) {
    return _polygon(
      List.generate(count * 2, (i) {
        final a = angle + i * math.pi / count;
        final r = i.isEven ? outer : inner;
        return Offset(math.cos(a), math.sin(a)) * r;
      }),
    );
  }

  static void _disc(
    Canvas canvas,
    Offset at,
    double radius,
    Color color, {
    double width = 3,
  }) {
    _shape(
      canvas,
      Path()..addOval(Rect.fromCircle(center: at, radius: radius)),
      color,
      width: width,
    );
  }

  static void _pod(Canvas canvas, Rect rect, Color color, {double radius = 4}) {
    _shape(
      canvas,
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius))),
      color,
    );
  }

  /// One 540-unit tile. Callers retain scrolling, mirror and clip behavior.
  static void paintTile(Canvas canvas, int world, Rect target) {
    if (target.isEmpty) return;
    if (GameArt.ready) {
      GameArt.paintWorld(canvas, world, target);
      return;
    }
    if (ToonAssets.rect(canvas, 'worlds', world.clamp(0, 9), target)) return;
    final key = world.clamp(0, 9);
    final image =
        _tiles[key] ??
        _cached(_tiles, key, _tileResolution, (recording) {
          _paintTileVector(recording, key, const Rect.fromLTWH(0, 0, 540, 540));
        });
    _drawImage(canvas, image, target);
  }

  static void _paintTileVector(Canvas canvas, int world, Rect target) {
    final w = world.clamp(0, 9);
    final ground = _grounds[w];
    final accent = _accents[w];
    final quiet = Color.lerp(ground, accent, .24)!;
    final dark = Color.lerp(ground, ArcadeStyle.outline, .24)!;
    canvas.save();
    canvas.clipRect(target);
    canvas.translate(target.left, target.top);
    canvas.scale(target.width / 540, target.height / 540);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 540, 540),
      Paint()..color = ground,
    );
    final line = Paint()
      ..color = dark
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    switch (w) {
      case 0:
        // Quiet city blocks and two orthogonal traffic corridors.
        for (final x in [0.0, 270.0]) {
          canvas.drawRect(
            Rect.fromLTWH(x + 108, 0, 54, 540),
            Paint()..color = dark,
          );
          canvas.drawRect(
            Rect.fromLTWH(0, x + 108, 540, 54),
            Paint()..color = dark,
          );
        }
        for (int y = 0; y < 4; y++) {
          for (int x = 0; x < 4; x++) {
            final rect = Rect.fromLTWH(x * 135 + 18, y * 135 + 18, 67, 66);
            canvas.drawRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(5)),
              Paint()..color = quiet,
            );
            canvas.drawLine(
              rect.topLeft + const Offset(8, 10),
              rect.topRight + const Offset(-8, 10),
              line,
            );
          }
        }
      case 1:
        for (int i = 0; i < 4; i++) {
          final y = i * 150.0 - 20;
          canvas.drawPath(
            Path()
              ..moveTo(-30, y)
              ..cubicTo(130, y - 65, 325, y + 100, 570, y + 42),
            Paint()
              ..color = quiet
              ..strokeWidth = 35
              ..style = PaintingStyle.stroke,
          );
        }
        for (final at in const [
          Offset(75, 75),
          Offset(440, 165),
          Offset(285, 375),
        ]) {
          canvas.save();
          canvas.translate(at.dx, at.dy);
          canvas.drawPath(_radial(5, 29, 24), Paint()..color = dark);
          canvas.restore();
        }
      case 2:
        for (final at in const [Offset(100, 100), Offset(390, 350)]) {
          canvas.save();
          canvas.translate(at.dx, at.dy);
          canvas.drawPath(_radial(6, 96, 83), Paint()..color = dark);
          canvas.drawPath(
            _radial(6, 72, 62),
            Paint()
              ..color = quiet
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5,
          );
          canvas.restore();
        }
        canvas.drawLine(const Offset(150, 150), const Offset(350, 300), line);
      case 3:
        for (int y = 0; y < 3; y++) {
          for (int x = 0; x < 3; x++) {
            final dx = x * 180.0, dy = y * 180.0;
            canvas.drawPath(
              _polygon([
                Offset(dx + 15, dy + 35),
                Offset(dx + 115, dy + 12),
                Offset(dx + 168, dy + 115),
                Offset(dx + 55, dy + 155),
              ]),
              Paint()..color = quiet,
            );
            canvas.drawLine(
              Offset(dx + 55, dy + 155),
              Offset(dx + 115, dy + 12),
              Paint()
                ..color = accent.withValues(alpha: .18)
                ..strokeWidth = 3,
            );
          }
        }
      case 4:
        for (final at in const [
          Offset(100, 110),
          Offset(390, 350),
          Offset(50, 470),
        ]) {
          canvas.drawCircle(at, 74, Paint()..color = dark);
          canvas.drawCircle(at, 57, Paint()..color = quiet);
          for (int i = 0; i < 5; i++) {
            final a = i * math.pi * 2 / 5;
            canvas.drawCircle(
              at + Offset(math.cos(a), math.sin(a)) * 34,
              10,
              Paint()..color = ground,
            );
          }
        }
      case 5:
        for (int y = 0; y < 3; y++) {
          for (int x = 0; x < 3; x++) {
            final r = Rect.fromLTWH(x * 180 + 9, y * 180 + 9, 160, 160);
            canvas.drawRRect(
              RRect.fromRectAndRadius(r, const Radius.circular(12)),
              Paint()..color = quiet,
            );
            canvas.drawRRect(
              RRect.fromRectAndRadius(r.deflate(8), const Radius.circular(7)),
              line,
            );
            canvas.drawCircle(
              r.topLeft + const Offset(15, 15),
              4,
              Paint()..color = dark,
            );
          }
        }
      case 6:
        for (int i = 0; i < 4; i++) {
          final x = i * 165.0;
          final path = Path()
            ..moveTo(x, -15)
            ..lineTo(x + 32, 135)
            ..lineTo(x - 12, 260)
            ..lineTo(x + 50, 405)
            ..lineTo(x + 18, 555);
          canvas.drawPath(
            path,
            Paint()
              ..color = dark
              ..strokeWidth = 28
              ..style = PaintingStyle.stroke
              ..strokeJoin = StrokeJoin.bevel,
          );
          canvas.drawPath(
            path,
            Paint()
              ..color = quiet
              ..strokeWidth = 9
              ..style = PaintingStyle.stroke
              ..strokeJoin = StrokeJoin.bevel,
          );
        }
      case 7:
        for (final at in const [Offset(95, 135), Offset(425, 415)]) {
          for (final radius in [40.0, 70.0, 100.0]) {
            canvas.drawCircle(
              at,
              radius,
              Paint()
                ..color = quiet
                ..strokeWidth = 4
                ..style = PaintingStyle.stroke,
            );
          }
          canvas.drawCircle(at, 11, Paint()..color = dark);
        }
        canvas.drawLine(const Offset(40, 475), const Offset(475, 40), line);
      case 8:
        for (int y = 0; y < 3; y++) {
          for (int x = 0; x < 3; x++) {
            final dx = x * 180.0 + (y.isOdd ? 25 : 0), dy = y * 180.0;
            canvas.drawPath(
              _polygon([
                Offset(dx + 70, dy + 8),
                Offset(dx + 128, dy + 80),
                Offset(dx + 78, dy + 157),
                Offset(dx + 15, dy + 82),
              ]),
              Paint()..color = quiet,
            );
            canvas.drawLine(
              Offset(dx + 70, dy + 8),
              Offset(dx + 78, dy + 157),
              line,
            );
          }
        }
      case 9:
        const center = Offset(270, 270);
        for (final radius in [90.0, 155.0, 225.0]) {
          canvas.drawCircle(
            center,
            radius,
            Paint()
              ..color = quiet
              ..style = PaintingStyle.stroke
              ..strokeWidth = 12,
          );
        }
        canvas.drawCircle(center, 65, Paint()..color = dark);
        for (int i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(
            center + Offset(math.cos(a), math.sin(a)) * 158,
            center + Offset(math.cos(a), math.sin(a)) * 225,
            Paint()
              ..color = ground
              ..strokeWidth = 17,
          );
        }
    }
    canvas.restore();
  }

  /// [role] follows EnemyRole.index; each weapon role has its own silhouette.
  static void paintEnemy(Canvas canvas, int role, double size, Color faction) {
    if (size <= 0) return;
    if (ToonAssets.sprite(
      canvas,
      'enemies',
      role.clamp(0, 10),
      Offset.zero,
      size,
    )) {
      return;
    }
    final normalizedRole = role >= 0 && role < 10 ? role : 10;
    final key = (normalizedRole, faction);
    final image =
        _enemies[key] ??
        _cached(_enemies, key, _enemyResolution, (recording) {
          recording.translate(_enemyResolution / 2, _enemyResolution / 2);
          _paintEnemyVector(
            recording,
            normalizedRole,
            _enemyResolution.toDouble(),
            faction,
          );
        }, capacity: _enemyCapacity);
    _drawImage(
      canvas,
      image,
      Rect.fromCenter(center: Offset.zero, width: size, height: size),
    );
  }

  static void _paintEnemyVector(
    Canvas canvas,
    int role,
    double size,
    Color faction,
  ) {
    canvas.save();
    canvas.scale(size / 100);
    final fill = Color.lerp(const Color(0xFFD98D77), faction, .16)!;
    const trim = Color(0xFF53617C), light = Color(0xFFFFD377);
    switch (role) {
      case 0:
        _shape(
          canvas,
          _polygon(const [
            Offset(0, -36),
            Offset(32, 22),
            Offset(0, 12),
            Offset(-32, 22),
          ]),
          fill,
        );
      case 1:
        _shape(
          canvas,
          _polygon(const [
            Offset(0, -22),
            Offset(43, 14),
            Offset(36, 30),
            Offset(0, 12),
            Offset(-36, 30),
            Offset(-43, 14),
          ]),
          fill,
        );
        _pod(canvas, const Rect.fromLTWH(-7, -25, 14, 47), trim);
      case 2:
        _shape(
          canvas,
          _polygon(const [
            Offset(-26, -28),
            Offset(26, -28),
            Offset(37, 6),
            Offset(0, 36),
            Offset(-37, 6),
          ]),
          fill,
        );
        _shape(
          canvas,
          _polygon(const [
            Offset(-18, -15),
            Offset(18, -15),
            Offset(23, 4),
            Offset(0, 23),
            Offset(-23, 4),
          ]),
          trim,
        );
      case 3:
        _shape(
          canvas,
          _polygon(const [
            Offset(0, -24),
            Offset(34, -4),
            Offset(28, 28),
            Offset(-28, 28),
            Offset(-34, -4),
          ]),
          fill,
        );
        for (final x in [-19.0, 0.0, 19.0]) {
          _pod(canvas, Rect.fromLTWH(x - 4, -35, 8, 25), trim);
        }
      case 4:
        _shape(
          canvas,
          _polygon(const [
            Offset(0, -44),
            Offset(13, -3),
            Offset(29, 26),
            Offset(0, 17),
            Offset(-29, 26),
            Offset(-13, -3),
          ]),
          fill,
        );
        _shape(
          canvas,
          _polygon(const [Offset(0, -37), Offset(4, -14), Offset(-4, -14)]),
          light,
          width: 0,
        );
      case 5:
        _disc(canvas, Offset.zero, 33, fill);
        _disc(canvas, Offset.zero, 22, trim);
        for (final x in [-34.0, 34.0]) {
          _pod(canvas, Rect.fromLTWH(x - 5, -11, 10, 22), light);
        }
      case 6:
        _shape(canvas, _radial(4, 39, 25, angle: 0), trim);
        _pod(canvas, const Rect.fromLTWH(-23, -23, 46, 46), fill);
        _disc(canvas, const Offset(0, -33), 5, light, width: 2);
      case 7:
        for (final x in [-17.0, 17.0]) {
          _shape(
            canvas,
            _polygon([
              Offset(x, -32),
              Offset(x + 13, -8),
              Offset(x + 11, 29),
              Offset(x - 11, 29),
              Offset(x - 13, -8),
            ]),
            fill,
          );
        }
        _pod(canvas, const Rect.fromLTWH(-11, -3, 22, 12), trim);
      case 8:
        _shape(
          canvas,
          _polygon(const [
            Offset(0, -15),
            Offset(27, 22),
            Offset(0, 13),
            Offset(-27, 22),
          ]),
          fill,
        );
        _pod(canvas, const Rect.fromLTWH(-5, -43, 10, 57), trim, radius: 2);
      case 9:
        _shape(
          canvas,
          _polygon(const [
            Offset(-16, -30),
            Offset(16, -30),
            Offset(40, 23),
            Offset(0, 32),
            Offset(-40, 23),
          ]),
          fill,
        );
        for (final x in [-23.0, 23.0]) {
          _pod(canvas, Rect.fromLTWH(x - 7, -9, 14, 31), trim);
        }
      default:
        _shape(
          canvas,
          _polygon(const [
            Offset(0, -42),
            Offset(30, 22),
            Offset(0, 8),
            Offset(-30, 22),
          ]),
          const Color(0xFFF16F55),
        );
        _shape(
          canvas,
          _polygon(const [
            Offset(0, -20),
            Offset(8, -1),
            Offset(0, -6),
            Offset(-8, -1),
          ]),
          light,
          width: 0,
        );
    }
    _disc(canvas, Offset.zero, role == 2 ? 7 : 5, light, width: 2);
    canvas.restore();
  }

  /// Ten world guardians: carrier, trident, crown, ice star, spore, fortress,
  /// solar gear, manta, prism and singularity. Combat hitboxes are caller-owned.
  static void paintBoss(Canvas canvas, int world, double size) {
    if (size <= 0) return;
    if (ToonAssets.sprite(
      canvas,
      'bosses',
      world.clamp(0, 9),
      Offset.zero,
      size,
    )) {
      return;
    }
    final key = world.clamp(0, 9);
    final image =
        _bosses[key] ??
        _cached(_bosses, key, _bossResolution, (recording) {
          recording.translate(_bossResolution / 2, _bossResolution / 2);
          _paintBossVector(recording, key, _bossResolution.toDouble());
        });
    _drawImage(
      canvas,
      image,
      Rect.fromCenter(center: Offset.zero, width: size, height: size),
    );
  }

  static void _paintBossVector(Canvas canvas, int world, double size) {
    final w = world.clamp(0, 9);
    final fill = _accents[w];
    const armor = Color(0xFF526078), core = Color(0xFFFFD36A);
    canvas.save();
    canvas.scale(size / 100);
    switch (w) {
      case 0:
        _shape(
          canvas,
          _polygon(const [
            Offset(0, -34),
            Offset(42, -10),
            Offset(39, 23),
            Offset(18, 33),
            Offset(-18, 33),
            Offset(-39, 23),
            Offset(-42, -10),
          ]),
          fill,
        );
        for (final x in [-28.0, 28.0]) {
          _pod(canvas, Rect.fromLTWH(x - 8, -27, 16, 61), armor);
        }
      case 1:
        _shape(
          canvas,
          _polygon(const [
            Offset(0, -45),
            Offset(9, -13),
            Offset(29, -38),
            Offset(41, -31),
            Offset(36, 25),
            Offset(0, 36),
            Offset(-36, 25),
            Offset(-41, -31),
            Offset(-29, -38),
            Offset(-9, -13),
          ]),
          fill,
        );
        _pod(canvas, const Rect.fromLTWH(-7, -20, 14, 42), armor);
      case 2:
        _shape(canvas, _radial(5, 44, 31), armor);
        _disc(canvas, Offset.zero, 28, fill);
        _disc(canvas, Offset.zero, 18, armor);
        for (final x in [-21.0, 0.0, 21.0]) {
          _pod(canvas, Rect.fromLTWH(x - 4, -40, 8, 16), fill);
        }
      case 3:
        _shape(canvas, _radial(6, 46, 19), fill);
        _shape(canvas, _radial(6, 24, 21), armor);
      case 4:
        for (int i = 0; i < 5; i++) {
          final a = i * math.pi * 2 / 5 - math.pi / 2;
          _disc(canvas, Offset(math.cos(a), math.sin(a)) * 26, 16, fill);
        }
        _shape(canvas, _radial(5, 26, 22), armor);
      case 5:
        _pod(canvas, const Rect.fromLTWH(-40, -26, 80, 55), fill, radius: 7);
        _pod(canvas, const Rect.fromLTWH(-24, -36, 48, 67), armor);
        for (final x in [-31.0, 31.0]) {
          _pod(canvas, Rect.fromLTWH(x - 5, -40, 10, 34), armor);
        }
      case 6:
        _shape(canvas, _radial(10, 45, 32), fill);
        _disc(canvas, Offset.zero, 26, armor);
        _disc(canvas, Offset.zero, 18, fill);
      case 7:
        _shape(
          canvas,
          _polygon(const [
            Offset(0, -32),
            Offset(13, -13),
            Offset(44, -26),
            Offset(38, 16),
            Offset(13, 23),
            Offset(0, 43),
            Offset(-13, 23),
            Offset(-38, 16),
            Offset(-44, -26),
            Offset(-13, -13),
          ]),
          fill,
        );
        _shape(
          canvas,
          _polygon(const [
            Offset(0, -23),
            Offset(12, -4),
            Offset(8, 21),
            Offset(-8, 21),
            Offset(-12, -4),
          ]),
          armor,
        );
      case 8:
        _shape(
          canvas,
          _polygon(const [
            Offset(0, -46),
            Offset(37, 0),
            Offset(0, 42),
            Offset(-37, 0),
          ]),
          fill,
        );
        _shape(
          canvas,
          _polygon(const [
            Offset(0, -31),
            Offset(22, 0),
            Offset(0, 28),
            Offset(-22, 0),
          ]),
          armor,
        );
        for (final x in [-37.0, 37.0]) {
          _disc(canvas, Offset(x, 0), 7, core, width: 2);
        }
      case 9:
        _shape(canvas, _radial(8, 45, 34), armor);
        _disc(canvas, Offset.zero, 30, fill);
        _disc(canvas, Offset.zero, 20, ArcadeStyle.outline);
        for (final x in [-35.0, 35.0]) {
          _pod(canvas, Rect.fromLTWH(x - 5, -23, 10, 46), fill);
        }
    }
    _disc(canvas, Offset.zero, w == 9 ? 9 : 10, core, width: 2.5);
    canvas.drawLine(
      const Offset(-4, -3),
      const Offset(2, -3),
      Paint()
        ..color = const Color(0xFFFFF0BF)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }
}
