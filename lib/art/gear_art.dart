import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/content_catalog.dart';
import '../data/aircraft_geometry.dart';
import 'menu_art.dart';

/// One independent sprite per catalogue spec, across every item surface.
abstract final class GearArt {
  static const root = 'assets/art/gear_v52/';
  static final images = <ui.Image>[];
  static final cells = <Rect>[];
  static final revision = ValueNotifier<int>(0);
  static Future<void>? _loading;
  static bool get ready => cells.length == gearCatalog.length;
  static String address(int spec) => 'gear/v52/${spec.clamp(0, 31)}';
  static Future<void> load() => _loading ??= _load().catchError((Object e) {
    _loading = null;
    throw e;
  });
  static Future<void> _load() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('${root}manifest.json')) as Map;
    final loaded = <ui.Image>[], rects = <Rect>[];
    try {
      for (final name in ['basic', 'boss']) {
        final data = await rootBundle.load('$root$name.png');
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          targetWidth: 1024,
        );
        final im = (await codec.getNextFrame()).image;
        codec.dispose();
        loaded.add(im);
        final meta = manifest[name] as Map;
        final sx = im.width / (meta['width'] as num),
            sy = im.height / (meta['height'] as num);
        rects.addAll([
          for (final r in meta['cells'])
            Rect.fromLTRB(r[0] * sx, r[1] * sy, r[2] * sx, r[3] * sy),
        ]);
      }
      if (rects.length != gearCatalog.length)
        throw StateError('Incomplete equipment atlas');
      images.addAll(loaded);
      cells.addAll(rects);
      for (var id = 0; id < cells.length; id++) {
        final im = images[id < 12 ? 0 : 1], r = cells[id];
        MenuArt.images[address(id)] = im;
        MenuArt.bounds[address(id)] = Rect.fromLTRB(
          r.left / im.width,
          r.top / im.height,
          r.right / im.width,
          r.bottom / im.height,
        );
      }
      revision.value++;
    } catch (_) {
      for (final im in loaded) {
        im.dispose();
      }
      rethrow;
    }
  }

  static bool paint(Canvas c, int spec, Rect target, {double opacity = 1}) {
    if (!ready || spec < 0 || spec >= cells.length || target.isEmpty)
      return false;
    final src = cells[spec];
    final dst = Alignment.center.inscribe(
      applyBoxFit(BoxFit.contain, src.size, target.size).destination,
      target,
    );
    c.drawImageRect(
      images[spec < 12 ? 0 : 1],
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Colors.white.withValues(alpha: opacity.clamp(0, 1)),
    );
    return true;
  }

  static void mounted(
    Canvas c,
    int spec,
    Offset anchor,
    double width, {
    Offset pivot = const Offset(.5, .5),
    bool mirror = false,
  }) {
    if (!ready || spec < 0 || spec >= cells.length) return;
    final src = cells[spec];
    c.save();
    c.translate(anchor.dx, anchor.dy);
    if (mirror) c.scale(-1, 1);
    c.drawImageRect(
      images[spec < 12 ? 0 : 1],
      src,
      AircraftGeometry.mountedRect(Offset.zero, width, src, pivot: pivot),
      Paint()..filterQuality = FilterQuality.medium,
    );
    c.restore();
  }
}

class GearIcon extends StatelessWidget {
  const GearIcon(this.spec, {super.key, this.size = 56});
  final int spec;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _GearPainter(spec)),
  );
}

class _GearPainter extends CustomPainter {
  _GearPainter(this.spec) : super(repaint: GearArt.revision);
  final int spec;
  @override
  void paint(Canvas canvas, Size size) =>
      GearArt.paint(canvas, spec, Offset.zero & size);
  @override
  bool shouldRepaint(_GearPainter old) => old.spec != spec;
}
