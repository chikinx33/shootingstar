import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// v12.8 game UI kit (user 2026-10-25: screens looked like office slides).
/// One generated sheet (assets/concept/gen_v13/ui_kit_raw.png) cut into
/// stretchable pieces; [ArcadeStyle.paintPanel] draws panels, buttons, tabs
/// and plates with them, so every screen shares the same game look.
abstract final class UiKit {
  static const root = 'assets/art/ui_v13/';

  /// Square frames: the ornate corners (paw bolts, rivet plates) inside
  /// these source-pixel insets are never stretched.
  static final _frames = {
    'panel': EdgeInsets.all(74),
    'slot': EdgeInsets.all(46),
    // v12.9 rarity slots (gray, green, blue, purple, gold, red rims)
    for (var r = 0; r < 6; r++) 'slot_r$r': const EdgeInsets.all(84),
  };

  /// Horizontal-only pieces with fixed end caps (source px): only the
  /// middle stretches, the height follows the target.
  static const _caps = {'ribbon': (72.0, 72.0)};

  /// The ribbon's flat red band (source px rows) - text sits centred in it,
  /// clear of the gold edge lines.
  static const ribbonBand = (top: 20.0, bottom: 84.0, height: 109.0);

  /// Pills: rounded caps scale with the height, only the middle stretches.
  static const _pills = {
    'btn_yellow',
    'btn_blue',
    'tab_on',
    'tab_off',
    'plate',
    'track',
  };

  static final images = <String, ui.Image>{};
  static Future<void>? _loading;
  static Future<void> load() => _loading ??= _load();
  static Future<void> _load() async {
    await Future.wait([
      for (final name in [..._frames.keys, ..._pills, ..._caps.keys])
        () async {
          final data = await rootBundle.load('$root$name.webp');
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
          try {
            images[name] = (await codec.getNextFrame()).image;
          } finally {
            codec.dispose();
          }
        }(),
    ]);
  }

  /// Picks the kit piece for a classic panel skin: wide short shapes are
  /// buttons/tabs/plates, everything else a framed panel. Null keeps the
  /// code-drawn panel (tinted or tiny surfaces, unused skins).
  static String? pieceFor(int skin, Rect target, Color? color) {
    if (target.height < 24 || target.width < 24) return null;
    if (color != null && skin != 2) return null;
    final pill = target.height <= 84 && target.width >= target.height * 1.15;
    return switch (skin) {
      0 => pill ? 'plate' : 'panel',
      1 => pill ? 'tab_on' : 'slot',
      2 => pill ? 'btn_yellow' : 'panel',
      3 => pill ? 'btn_blue' : 'panel',
      4 => pill ? 'tab_off' : 'slot',
      _ => null,
    };
  }

  /// Draws [name] stretched over [dst]; false while it is not loaded.
  ///
  /// Slices are drawn one by one with mipmapped smoothing, so scaled-down
  /// edges stay clean on every renderer. Corners keep their proportions:
  /// pills scale to the target height, frames to [corner] logical pixels.
  static bool paint(
    Canvas canvas,
    String name,
    Rect dst, {
    double corner = 24,
    double opacity = 1,
  }) {
    final image = images[name];
    if (image == null || dst.isEmpty) return false;
    final w = image.width.toDouble(), h = image.height.toDouble();
    final EdgeInsets inset;
    double k;
    final horizontal = _pills.contains(name) || _caps.containsKey(name);
    if (_caps.containsKey(name)) {
      final (left, right) = _caps[name]!;
      inset = EdgeInsets.fromLTRB(left, 0, right, 0);
      k = dst.height / h;
    } else if (_pills.contains(name)) {
      inset = EdgeInsets.fromLTRB(h * .5, 0, h * .5, 0);
      k = dst.height / h;
    } else {
      inset = _frames[name]!;
      k = corner / inset.top;
    }
    // both corners of each axis must fit inside the target
    k = math.min(
      k,
      math.min(
        dst.width / (inset.horizontal + 1),
        horizontal ? k : dst.height / (inset.vertical + 1),
      ),
    );
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true
      ..color = Colors.white.withValues(alpha: opacity.clamp(0, 1));
    // Source column/row edges. The stretched middle comes from a thin strip
    // at the flat centre, so it is only ever enlarged: squeezing a wide
    // strip into a narrow button picks a blurry mipmap (smeared edges).
    final sx = [0.0, inset.left, w / 2 - 4, w / 2 + 4, w - inset.right, w];
    final sy = horizontal
        ? [0.0, 0.0, 0.0, h, h, h]
        : [0.0, inset.top, h / 2 - 4, h / 2 + 4, h - inset.bottom, h];
    final dx = [
      dst.left,
      dst.left + inset.left * k,
      dst.right - inset.right * k,
      dst.right,
    ];
    final dy = horizontal
        ? [dst.top, dst.top, dst.bottom, dst.bottom]
        : [
            dst.top,
            dst.top + inset.top * k,
            dst.bottom - inset.bottom * k,
            dst.bottom,
          ];
    // (source index pairs) caps, centre strip, caps
    const spans = [(0, 1), (2, 3), (4, 5)];
    // Centre first, then edges, corners last: every slice reaches 1px under
    // its neighbours, so no hairline gap shows between them.
    const order = [
      (1, 1), (1, 0), (1, 2), (0, 1), (2, 1), //
      (0, 0), (0, 2), (2, 0), (2, 2),
    ];
    for (final (r, c) in order) {
      final (sy0, sy1) = spans[r];
      final (sx0, sx1) = spans[c];
      if (sy[sy1] <= sy[sy0] || sx[sx1] <= sx[sx0]) continue;
      canvas.drawImageRect(
        image,
        Rect.fromLTRB(sx[sx0], sy[sy0], sx[sx1], sy[sy1]),
        Rect.fromLTRB(
          dx[c] - (c > 0 ? 1 : 0),
          dy[r] - (r > 0 && dy[r] > dst.top ? 1 : 0),
          dx[c + 1] + (c < 2 ? 1 : 0),
          dy[r + 1] + (r < 2 && dy[r + 1] < dst.bottom ? 1 : 0),
        ),
        paint,
      );
    }
    return true;
  }
}

/// A kit piece as a widget background, e.g. a ribbon title or a plate.
class UiKitFrame extends StatelessWidget {
  const UiKitFrame(
    this.piece, {
    super.key,
    required this.child,
    this.corner = 24,
    this.padding = EdgeInsets.zero,
  });
  final String piece;
  final Widget child;
  final double corner;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _KitPainter(piece, corner),
    child: Padding(padding: padding, child: child),
  );
}

class _KitPainter extends CustomPainter {
  const _KitPainter(this.piece, this.corner);
  final String piece;
  final double corner;
  @override
  void paint(Canvas canvas, Size size) =>
      UiKit.paint(canvas, piece, Offset.zero & size, corner: corner);
  @override
  bool shouldRepaint(_KitPainter old) =>
      old.piece != piece || old.corner != corner;
}
