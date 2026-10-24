import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'menu_art.dart';
import 'flight_scene_art.dart';

/// Original v16 PNGs override shared addresses, including live combat craft.
abstract final class RefitArt {
  static const root = 'assets/art/refit_v16/';
  static Future<void>? _loading;
  static Future<void> load() => _loading ??= _load();
  static Future<void> _load() async {
    final map =
        jsonDecode(await rootBundle.loadString('${root}manifest.json')) as Map;
    await Future.wait(
      map.entries.map((entry) async {
        final meta = entry.value as Map;
        final bytes = await rootBundle.load('$root${entry.key}.webp');
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
          targetWidth: meta['background'] == true ? 900 : 512,
        );
        final name = 'lobby/${entry.key}';
        MenuArt.images[name] = (await codec.getNextFrame()).image;
        codec.dispose();
        final b = (meta['bounds'] as List).cast<num>();
        MenuArt.bounds[name] = Rect.fromLTRB(
          b[0].toDouble(),
          b[1].toDouble(),
          b[2].toDouble(),
          b[3].toDouble(),
        );
      }),
    );
    for (final alias in MenuArt.aliases.entries) {
      if (MenuArt.images.containsKey(alias.value)) {
        MenuArt.images[alias.key] = MenuArt.images[alias.value]!;
        MenuArt.bounds[alias.key] = MenuArt.bounds[alias.value]!;
      }
    }
  }
}

/// The lobby backdrop: the cats' living room, a still picture under fixed
/// controls. It repaints once, when the picture finishes decoding.
class RefitBackdrop extends StatelessWidget {
  const RefitBackdrop({super.key, required this.child, this.launch = false});
  final Widget child;
  final bool launch;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              key: const Key('lobby-background'),
              painter: RefitBackdropPainter(launch),
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

class RefitBackdropPainter extends CustomPainter {
  RefitBackdropPainter(this.launch)
    : super(repaint: FlightSceneArt.lobbyRevision);
  final bool launch;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(rect, Paint()..color = const Color(0xFF142236));
    final home = launch
        ? FlightSceneArt.lobbyHome
        : FlightSceneArt.menuBackdrop ?? FlightSceneArt.lobbyHome;
    if (home != null) FlightSceneArt.paintCover(canvas, size, home);
    if (!launch) {
      // v12.9: the attic hangar stays visible; a soft shade keeps panels
      // readable (was a near-opaque navy wash over the living room).
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x66091224), Color(0x33091224), Color(0x88091224)],
            stops: [0, .55, 1],
          ).createShader(rect),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RefitBackdropPainter old) => old.launch != launch;
}
