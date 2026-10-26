import 'package:flutter/material.dart';

import 'flight_scene_art.dart';

/// The lobby backdrop: the cats' living room, a still picture under fixed
/// controls. It repaints once, when the picture finishes decoding.
class GameBackdrop extends StatelessWidget {
  const GameBackdrop({super.key, required this.child, this.launch = false});
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
              painter: GameBackdropPainter(launch),
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

class GameBackdropPainter extends CustomPainter {
  GameBackdropPainter(this.launch)
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
  bool shouldRepaint(GameBackdropPainter old) => old.launch != launch;
}
