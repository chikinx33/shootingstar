import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Each generated object has its own PNG. No atlas or sliced texture is used.
abstract final class MenuArt {
  static const root = 'assets/art/menu_v8/';
  static final images = <String, ui.Image>{};
  static final bounds = <String, Rect>{};
  static final aliases = <String, String>{};
  static const _opaqueCutout = ColorFilter.matrix([
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1.04,
    -8,
  ]);
  static Future<void>? _loading;
  static Future<void> load() => _loading ??= _load();
  static Future<void> _load() async {
    final map =
        jsonDecode(await rootBundle.loadString('${root}manifest.json')) as Map;
    await Future.wait(
      map.entries.map((entry) async {
        final name = entry.key as String, meta = entry.value as Map;
        final bytes = await rootBundle.load('$root$name.png');
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
          targetWidth: meta['background'] == true ? 768 : 512,
        );
        images[name] = (await codec.getNextFrame()).image;
        codec.dispose();
        final b = meta['bounds'] as List;
        bounds[name] = Rect.fromLTRB(
          (b[0] as num).toDouble(),
          (b[1] as num).toDouble(),
          (b[2] as num).toDouble(),
          (b[3] as num).toDouble(),
        );
      }),
    );
  }

  static bool paint(
    Canvas canvas,
    String name,
    Rect target, {
    bool cover = false,
    double opacity = 1,
    Color? tint,
  }) {
    name = aliases[name] ?? name;
    final im = images[name];
    if (im == null || target.isEmpty) return false;
    final b = bounds[name]!;
    final source = Rect.fromLTRB(
      b.left * im.width,
      b.top * im.height,
      b.right * im.width,
      b.bottom * im.height,
    );
    final fit = applyBoxFit(
      cover ? BoxFit.cover : BoxFit.contain,
      source.size,
      target.size,
    );
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (!cover) {
      // Generated alpha can contain stray 1..7/255 pixels outside the ink.
      // Suppress those at render time; preserve the original PNG and AA edge.
      paint.colorFilter = tint == null && opacity == 1
          ? _opaqueCutout
          : ColorFilter.matrix([
              tint?.r ?? 1,
              0,
              0,
              0,
              0,
              0,
              tint?.g ?? 1,
              0,
              0,
              0,
              0,
              0,
              tint?.b ?? 1,
              0,
              0,
              0,
              0,
              0,
              1.04 * opacity,
              -8 * opacity,
            ]);
    }
    canvas.drawImageRect(
      im,
      Alignment.center.inscribe(fit.source, source),
      Alignment.center.inscribe(fit.destination, target),
      paint,
    );
    return true;
  }
}

class MenuImage extends StatelessWidget {
  const MenuImage(this.name, {super.key, this.size = 64});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _MenuPainter(name, false)),
  );
}

class MenuBackdrop extends StatelessWidget {
  const MenuBackdrop(this.name, {super.key, required this.child});
  final String name;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _MenuPainter(name, true), child: child);
}

class _MenuPainter extends CustomPainter {
  const _MenuPainter(this.name, this.cover);
  final String name;
  final bool cover;
  @override
  bool hitTest(Offset position) => false;
  @override
  void paint(Canvas canvas, Size size) {
    MenuArt.paint(canvas, name, Offset.zero & size, cover: cover);
  }

  @override
  bool shouldRepaint(_MenuPainter old) =>
      old.name != name || old.cover != cover;
}
