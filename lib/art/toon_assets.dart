import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_art.dart';
import 'refit_art.dart';

/// Generated PNG artwork. The original reference screenshots are never loaded
/// by the game; sources and complete prompts live beside these project assets.
abstract final class ToonAssets {
  static const root = 'assets/art/toon_v7/';
  static const grids = <String, (int, int)>{
    'ships': (3, 2),
    'enemies': (4, 3),
    'bosses': (4, 3),
    'equipment': (4, 3),
    'icons': (8, 8),
    'panels': (2, 4),
    'worlds': (4, 3),
    'projectiles': (6, 4),
    'effects': (4, 4),
  };
  static final images = <String, ui.Image>{};
  static List<Rect> _iconRegions = [];
  static Future<void>? _loading;
  static Future<void> load() => _loading ??= _load();
  static Future<void> _load() async {
    try {
      await Future.wait(
        grids.keys.map((name) async {
          if (images.containsKey(name)) return;
          final bytes = await rootBundle.load('$root$name.png');
          final codec = await ui.instantiateImageCodec(
            bytes.buffer.asUint8List(),
          );
          final frame = await codec.getNextFrame();
          codec.dispose();
          images[name] = frame.image;
        }),
      );
      final regions = jsonDecode(
        await rootBundle.loadString('assets/art/ui_icon_regions.json'),
      ) as Map;
      _iconRegions = [
        for (final row in regions['regions'] as List)
          Rect.fromLTRB(
            (row[0] as num).toDouble(),
            (row[1] as num).toDouble(),
            (row[2] as num).toDouble(),
            (row[3] as num).toDouble(),
          ),
      ];
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  static Rect source(String name, int index) {
    final im = images[name]!, grid = grids[name]!;
    final id = index.clamp(0, grid.$1 * grid.$2 - 1);
    if (name == 'icons' && _iconRegions.length == 64) return _iconRegions[id];
    final w = im.width / grid.$1, h = im.height / grid.$2;
    return Rect.fromLTWH(id % grid.$1 * w, id ~/ grid.$1 * h, w, h).deflate(.7);
  }

  static bool rect(
    Canvas c,
    String name,
    int id,
    Rect dst, {
    double opacity = 1,
  }) {
    if (GameArt.paint(c, name, id, dst, opacity: opacity)) return true;
    final im = images[name];
    if (im == null || dst.isEmpty) return false;
    final src = source(name, id);
    final target = name == 'icons' && _iconRegions.length == 64
        ? Alignment.center.inscribe(
            applyBoxFit(BoxFit.contain, src.size, dst.size).destination,
            dst,
          )
        : dst;
    c.drawImageRect(
      im,
      src,
      target,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Colors.white.withValues(alpha: opacity.clamp(0, 1)),
    );
    return true;
  }

  static bool cover(Canvas c, String name, int id, Rect dst) {
    if (GameArt.paint(c, name, id, dst)) return true;
    if (!images.containsKey(name) || dst.isEmpty) return false;
    final src = source(name, id);
    final fit = applyBoxFit(BoxFit.cover, src.size, dst.size);
    c.drawImageRect(
      images[name]!,
      Alignment.center.inscribe(fit.source, src),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    return true;
  }

  static bool sprite(
    Canvas c,
    String name,
    int id,
    Offset center,
    double size, {
    double rotation = 0,
    double opacity = 1,
  }) {
    if (!GameArt.ready && !images.containsKey(name)) return false;
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(rotation);
    rect(
      c,
      name,
      id,
      Rect.fromCenter(center: Offset.zero, width: size, height: size),
      opacity: opacity,
    );
    c.restore();
    return true;
  }
}

class ToonTile extends StatelessWidget {
  const ToonTile(this.atlas, this.index, {super.key, this.size = 48});
  final String atlas;
  final int index;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _ToonPainter(atlas, index)),
  );
}

class ToonRarityFrame extends StatelessWidget {
  const ToonRarityFrame({super.key, required this.rank, required this.child});
  final int rank;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _RarityPainter(rank), child: child);
}

class _RarityPainter extends CustomPainter {
  _RarityPainter(this.rank);
  final int rank;
  static const colors = [
    Color(0xFF9BA3AE),
    Color(0xFF7AE622),
    Color(0xFF20AAFF),
    Color(0xFFBA22FF),
    Color(0xFFFFC500),
    Color(0xFFFF4E45),
  ];
  @override
  void paint(Canvas c, Size size) {
    final r = (Offset.zero & size).deflate(2);
    final color = colors[rank.clamp(0, 5)];
    final shape = RRect.fromRectAndRadius(r, const Radius.circular(8));
    c.drawRRect(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF20364D), color, .34)!,
            const Color(0xFF12263C),
          ],
        ).createShader(r),
    );
    c.drawRRect(
      shape,
      Paint()
        ..color = const Color(0xFF111318)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    c.drawRRect(
      shape,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(r.deflate(5), const Radius.circular(4)),
      Paint()
        ..color = color.withValues(alpha: .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    c.drawLine(
      Offset(r.left + 11, r.top + 5),
      Offset(r.right - 11, r.top + 5),
      Paint()
        ..color = color.withValues(alpha: .6)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_RarityPainter old) => old.rank != rank;
}

class _ToonPainter extends CustomPainter {
  _ToonPainter(this.atlas, this.index);
  final String atlas;
  final int index;
  @override
  void paint(Canvas c, Size size) =>
      ToonAssets.rect(c, atlas, index, Offset.zero & size);
  @override
  bool shouldRepaint(_ToonPainter old) =>
      old.atlas != atlas || old.index != index;
}

class ToonBackdrop extends StatelessWidget {
  const ToonBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => RefitBackdrop(child: child);
}
