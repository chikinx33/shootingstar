import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../data/aircraft_assembly.dart';
import '../data/ship_modules.dart';
import 'aircraft_assembly_art.dart';

/// The shared assembled aircraft, used in lobby, hangar, rewards and combat.
class ArcadeAircraft extends StatelessWidget {
  const ArcadeAircraft({
    super.key,
    required this.shipIndex,
    this.size = 160,
    this.width,
    this.height,
    this.bank = 0,
    this.exhaust = true,
    this.semanticLabel,
    this.assembly,
    this.preservePartScale = false,
    this.visualScale = 1,
    this.targetSize = 0,
  });
  final int shipIndex;
  final double size, bank, visualScale, targetSize;
  final double? width, height;
  final bool exhaust;
  final String? semanticLabel;
  final AircraftAssembly? assembly;
  final bool preservePartScale;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Semantics(
      container: true,
      excludeSemantics: true,
      image: true,
      label: tr(semanticLabel),
      child: SizedBox(
        width: width ?? size,
        height: height ?? size,
        child: CustomPaint(
          painter: _AircraftPainter(
            assembly ??
                AircraftAssembly(
                  hull: shipIndex,
                  modules: ModuleSnapshot(shipIndex, 1, {}),
                ),
            bank,
            preservePartScale,
            visualScale,
            targetSize,
          ),
        ),
      ),
    );
  }

  static void paintShip(
    Canvas canvas,
    Offset center,
    double size,
    int shipIndex, {
    double bank = 0,
    bool exhaust = false,
    AircraftAssembly? assembly,
  }) {
    final config =
        assembly ??
        AircraftAssembly(
          hull: shipIndex,
          modules: ModuleSnapshot(shipIndex, 1, {}),
        );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(bank.clamp(-.12, .12));
    AircraftAssemblyArt.paintAssembly(canvas, Offset.zero, size, config);
    canvas.restore();
  }
}

class _AircraftPainter extends CustomPainter {
  const _AircraftPainter(
    this.assembly,
    this.bank,
    this.preservePartScale,
    this.visualScale,
    this.targetSize,
  );
  final AircraftAssembly assembly;
  final double bank, visualScale, targetSize;
  final bool preservePartScale;
  @override
  void paint(Canvas canvas, Size size) {
    if (assembly.modules == null && AircraftAssemblyArt.hulls.length != 3)
      return;
    final view = AssemblyViewport.layout(
      size,
      assembly,
      preservePartScale: preservePartScale,
      visualScale: visualScale,
      targetSize: targetSize,
    );
    ArcadeAircraft.paintShip(
      canvas,
      view.center,
      view.extent,
      assembly.hull,
      assembly: assembly,
      bank: bank,
    );
  }

  @override
  bool shouldRepaint(_AircraftPainter old) =>
      old.assembly != assembly ||
      old.bank != bank ||
      old.visualScale != visualScale ||
      old.targetSize != targetSize ||
      old.preservePartScale != preservePartScale;
}
