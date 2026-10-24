import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/aircraft_assembly.dart';
import '../data/aircraft_geometry.dart';
import 'gear_art.dart';
import 'module_aircraft_art.dart';

class AssemblyPlacement {
  const AssemblyPlacement(
    this.mount,
    this.part,
    this.anchor,
    this.width, {
    this.pivot = const Offset(.5, .5),
    this.mirror = false,
  });
  final AircraftMount mount;
  final String part;
  final Offset anchor, pivot;
  final double width;
  final bool mirror;
}

/// A visible component rectangle; paired pieces share one logical slot.
class AssemblySocket {
  const AssemblySocket(
    this.rect, {
    this.gearSlot,
    this.mount,
    this.side = 0,
    this.occupied = true,
  });
  final Rect rect;
  final int? gearSlot;
  final AircraftMount? mount;
  final int side;
  final bool occupied;
  String get slotId => gearSlot == null ? mount!.name : 'gear-$gearSlot';
  String get id => '$slotId-$side';
}

/// The exact same body-to-widget transform is used by art and slot overlays.
class AssemblyViewport {
  const AssemblyViewport(this.origin, this.extent);
  final Offset origin;
  final double extent;
  Offset get center => origin + const Offset(.5, .54) * extent;
  Rect project(Rect rect) => Rect.fromLTWH(
    origin.dx + rect.left * extent,
    origin.dy + rect.top * extent,
    rect.width * extent,
    rect.height * extent,
  );
  factory AssemblyViewport.layout(
    Size size,
    AircraftAssembly assembly, {
    bool preservePartScale = false,
    double visualScale = 1,
    double targetSize = 0,
  }) {
    final bounds = AircraftAssemblyArt.previewBounds(assembly);
    var extent =
        (preservePartScale
            ? math.min(size.width, size.height) / AircraftGeometry.previewSpan
            : math.min(size.width / bounds.width, size.height / bounds.height) *
                  .94) *
        visualScale;
    if (targetSize > 0 && !preservePartScale) {
      for (final socket in AircraftAssemblyArt.sockets(assembly)) {
        final delta = socket.rect.center - bounds.center;
        if (delta.dx.abs() > .001) {
          extent = math.min(
            extent,
            math.max(0, size.width - targetSize) / (2 * delta.dx.abs()),
          );
        }
        if (delta.dy.abs() > .001) {
          extent = math.min(
            extent,
            math.max(0, size.height - targetSize) / (2 * delta.dy.abs()),
          );
        }
      }
    }
    final origin = preservePartScale
        ? size.center(Offset(0, -extent * AircraftGeometry.previewLift)) -
              const Offset(.5, .54) * extent
        : size.center(Offset.zero) - bounds.center * extent;
    return AssemblyViewport(origin, extent);
  }
}

/// Matching physical hardpoints, in each full source canvas's coordinates.
/// Modules change anchors with the chassis; no pixel stretching or recoloring.
abstract final class AircraftAssemblyArt {
  static const root = 'assets/art/airframe_v52/';
  static final hulls = <ui.Image>[];
  static ui.Image? modules;
  static final cells = <Rect>[];
  static Future<void>? _loading;
  static Future<void> load() => _loading ??= _load().catchError((Object error) {
    _loading = null;
    throw error;
  });
  static Future<void> _load() async {
    final loaded = <ui.Image>[];
    try {
      for (final name in ['aurora', 'vector', 'monolith', 'modules']) {
        final bytes = await rootBundle.load('$root$name.png');
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          targetWidth: name == 'modules' ? 1024 : 768,
        );
        try {
          loaded.add((await codec.getNextFrame()).image);
        } finally {
          codec.dispose();
        }
      }
      await GearArt.load();
      final map = jsonDecode(
        await rootBundle.loadString('${root}manifest.json'),
      ) as Map;
      final meta = map['modules'] as Map;
      final sx = loaded[3].width / (meta['width'] as num);
      final sy = loaded[3].height / (meta['height'] as num);
      final bounds = [
        for (final raw in meta['cells'] as List)
          Rect.fromLTRB(raw[0] * sx, raw[1] * sy, raw[2] * sx, raw[3] * sy),
      ];
      hulls.addAll(loaded.take(3));
      modules = loaded[3];
      cells.addAll(bounds);
    } catch (_) {
      for (final art in loaded) {
        art.dispose();
      }
      rethrow;
    }
  }

  static Offset anchor(int hull, AircraftMount mount) =>
      AircraftGeometry.anchor(hull, mount);

  static List<AssemblyPlacement> placements(
    AircraftAssembly assembly, {
    bool includeEmpty = false,
  }) {
    final result = <AssemblyPlacement>[];
    for (final mount in [
      AircraftMount.armor,
      AircraftMount.ground,
      AircraftMount.main,
      AircraftMount.wings,
      AircraftMount.rear,
      AircraftMount.auxiliary,
      ...supportMounts,
    ]) {
      final id =
          assembly.parts[mount] ??
          (includeEmpty
              ? AircraftAssembly.demo(assembly.hull).parts[mount]
              : null);
      if (id == null) continue;
      final at = anchor(assembly.hull, mount);
      final width = AircraftGeometry.partWidth(mount);
      final pivot = AircraftGeometry.partPivot(mount);
      result.add(AssemblyPlacement(mount, id, at, width, pivot: pivot));
      if (mount == AircraftMount.wings || mount == AircraftMount.armor) {
        result.add(
          AssemblyPlacement(
            mount,
            id,
            Offset(1 - at.dx, at.dy),
            width,
            pivot: pivot,
            mirror: mount == AircraftMount.armor,
          ),
        );
      }
    }
    return result;
  }

  static Rect placementRect(AircraftAssembly assembly, AssemblyPlacement p) {
    final slot = p.mount == AircraftMount.main
        ? 0
        : p.mount == AircraftMount.armor
        ? 3
        : -1;
    final source = assembly.gearSpecs.length == 6 && GearArt.ready && slot >= 0
        ? GearArt.cells[assembly.gearSpecs[slot]]
        : partRect(aircraftPart(p.part));
    return AircraftGeometry.mountedRect(
      p.anchor,
      p.width,
      source,
      pivot: p.pivot,
      mirror: p.mirror,
    );
  }

  static List<AssemblySocket> sockets(AircraftAssembly assembly) {
    if (cells.isEmpty || !GearArt.ready) return const [];
    final result = <AssemblySocket>[];
    // Empty optional mounts retain their physical position and can be equipped.
    for (final p in placements(assembly, includeEmpty: true)) {
      final rect = placementRect(assembly, p);
      final side = p.anchor.dx > .5 ? 1 : 0;
      result.add(
        AssemblySocket(
          rect,
          mount: p.mount,
          side: side,
          occupied: assembly.parts.containsKey(p.mount),
        ),
      );
      final slot = p.mount == AircraftMount.main
          ? 0
          : p.mount == AircraftMount.armor
          ? 3
          : null;
      if (slot != null)
        result.add(AssemblySocket(rect, gearSlot: slot, side: side));
    }
    final gear = assembly.gearSpecs;
    if (gear.length == 6) {
      for (final (slot, at) in [
        (1, AircraftGeometry.sensorAnchor),
        (2, AircraftGeometry.coreAnchor),
        (4, AircraftGeometry.beltAnchor),
        (5, AircraftGeometry.engineAnchor(assembly.hull)),
      ]) {
        final width = slot == 5
            ? AircraftGeometry.thrusterWidth
            : AircraftGeometry.fittingWidth;
        for (var side = 0; side < (slot == 5 ? 2 : 1); side++) {
          result.add(
            AssemblySocket(
              AircraftGeometry.mountedRect(
                side == 0 ? at : Offset(1 - at.dx, at.dy),
                width,
                GearArt.cells[gear[slot]],
              ),
              gearSlot: slot,
              side: side,
            ),
          );
        }
      }
    }
    return result;
  }

  static void paintAssembly(
    Canvas canvas,
    Offset center,
    double extent,
    AircraftAssembly assembly, {
    Map<AircraftMount, double> angles = const {},
    double? rightWingAngle,
    Map<AircraftMount, Offset> recoil = const {},
    Offset rightWingRecoil = Offset.zero,
    Map<AircraftMount, Offset> drift = const {},
    Map<int, Offset> gearDrift = const {},
    bool supports = true,
  }) {
    if (assembly.modules != null) {
      ModuleAircraftArt.paint(
        canvas,
        center + Offset(0, -extent * .04),
        extent,
        assembly.modules!,
      );
      return;
    }
    if (hulls.length != 3 || modules == null || extent <= 0) return;
    final origin = center - Offset(extent * .5, extent * .54);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(extent);
    final hull = hulls[assembly.hull];
    canvas.drawImageRect(
      hull,
      Rect.fromLTWH(0, 0, hull.width.toDouble(), hull.height.toDouble()),
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final gear = assembly.gearSpecs;
    if (gear.length == 6 && GearArt.ready) {
      GearArt.mounted(
        canvas,
        gear[4],
        AircraftGeometry.beltAnchor +
            (gearDrift[4] ?? Offset.zero) / AircraftGeometry.bodySize,
        AircraftGeometry.fittingWidth,
      );
      GearArt.mounted(
        canvas,
        gear[2],
        AircraftGeometry.coreAnchor +
            (gearDrift[2] ?? Offset.zero) / AircraftGeometry.bodySize,
        AircraftGeometry.fittingWidth,
      );
      final engine = AircraftGeometry.engineAnchor(assembly.hull);
      final engineLag =
          (gearDrift[5] ?? Offset.zero) / AircraftGeometry.bodySize;
      GearArt.mounted(
        canvas,
        gear[5],
        engine + engineLag,
        AircraftGeometry.thrusterWidth,
      );
      GearArt.mounted(
        canvas,
        gear[5],
        Offset(1 - engine.dx, engine.dy) + engineLag * .92,
        AircraftGeometry.thrusterWidth,
      );
    }
    for (final placement in placements(assembly)) {
      if (!supports && supportMounts.contains(placement.mount)) continue;
      final isRight =
          placement.mount == AircraftMount.wings && placement.anchor.dx > .5;
      final kick =
          (isRight ? rightWingRecoil : recoil[placement.mount] ?? Offset.zero) /
          AircraftGeometry.bodySize;
      final lag =
          (drift[placement.mount] ?? Offset.zero) / AircraftGeometry.bodySize;
      final at = placement.anchor + kick + lag * (isRight ? .92 : 1);
      if (gear.length == 6 &&
          GearArt.ready &&
          (placement.mount == AircraftMount.main ||
              placement.mount == AircraftMount.armor)) {
        GearArt.mounted(
          canvas,
          gear[placement.mount == AircraftMount.main ? 0 : 3],
          at,
          placement.width,
          pivot: placement.pivot,
          mirror: placement.mirror,
        );
        continue;
      }
      final src = partRect(aircraftPart(placement.part));
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(
        isRight
            ? (rightWingAngle ?? angles[placement.mount] ?? 0)
            : (angles[placement.mount] ?? 0),
      );
      if (placement.mirror) canvas.scale(-1, 1);
      canvas.drawImageRect(
        modules!,
        src,
        AircraftGeometry.mountedRect(
          Offset.zero,
          placement.width,
          src,
          pivot: placement.pivot,
        ),
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
    }
    if (gear.length == 6 && GearArt.ready) {
      GearArt.mounted(
        canvas,
        gear[1],
        AircraftGeometry.sensorAnchor +
            (gearDrift[1] ?? Offset.zero) / AircraftGeometry.bodySize,
        AircraftGeometry.fittingWidth,
      );
    }
    canvas.restore();
  }

  static Rect partRect(AircraftPart part) => cells[part.cell];

  /// Full static assembly bounds for small catalogue cells and the hangar.
  /// The main lobby uses its own tall space to retain the full part scale.
  static Rect previewBounds(AircraftAssembly assembly) {
    var bounds = const Rect.fromLTWH(0, 0, 1, 1);
    if (assembly.modules != null) return bounds;
    if (cells.isEmpty) return bounds;
    // Reserve the same physical hardpoints even while optional parts are empty.
    for (final socket in sockets(assembly)) {
      bounds = bounds.expandToInclude(socket.rect);
    }
    void include(
      Offset at,
      double width,
      Rect source,
      Offset pivot, {
      bool mirror = false,
    }) {
      final height = width * source.height / source.width;
      bounds = bounds.expandToInclude(
        Rect.fromLTWH(
          at.dx - width * (mirror ? 1 - pivot.dx : pivot.dx),
          at.dy - height * pivot.dy,
          width,
          height,
        ),
      );
    }

    final gear = assembly.gearSpecs;
    for (final p in placements(assembly)) {
      final spec = p.mount == AircraftMount.main
          ? 0
          : p.mount == AircraftMount.armor
          ? 3
          : -1;
      final src = gear.length == 6 && GearArt.ready && spec >= 0
          ? GearArt.cells[gear[spec]]
          : partRect(aircraftPart(p.part));
      include(p.anchor, p.width, src, p.pivot, mirror: p.mirror);
    }
    if (gear.length == 6 && GearArt.ready) {
      for (final entry in [
        (1, AircraftGeometry.sensorAnchor),
        (2, AircraftGeometry.coreAnchor),
        (4, AircraftGeometry.beltAnchor),
      ]) {
        include(
          entry.$2,
          AircraftGeometry.fittingWidth,
          GearArt.cells[gear[entry.$1]],
          const Offset(.5, .5),
        );
      }
      final engine = AircraftGeometry.engineAnchor(assembly.hull);
      for (final at in [engine, Offset(1 - engine.dx, engine.dy)]) {
        include(
          at,
          AircraftGeometry.thrusterWidth,
          GearArt.cells[gear[5]],
          const Offset(.5, .5),
        );
      }
    }
    return bounds;
  }

  static void paintPart(Canvas canvas, AircraftPart part, Rect target) {
    final art = modules;
    if (art == null) return;
    final src = partRect(part);
    final scale = math.min(
      target.width / src.width,
      target.height / src.height,
    );
    final dst = Rect.fromCenter(
      center: target.center,
      width: src.width * scale,
      height: src.height * scale,
    );
    canvas.drawImageRect(
      art,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}

class AssemblyPartIcon extends StatelessWidget {
  const AssemblyPartIcon(this.part, {super.key, this.size = 56});
  final AircraftPart part;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _PartPainter(part)),
  );
}

class _PartPainter extends CustomPainter {
  const _PartPainter(this.part);
  final AircraftPart part;
  @override
  void paint(Canvas canvas, Size size) =>
      AircraftAssemblyArt.paintPart(canvas, part, Offset.zero & size);
  @override
  bool shouldRepaint(_PartPainter old) => old.part != part;
}

class AircraftAssemblyView extends StatelessWidget {
  const AircraftAssemblyView({super.key, required this.assembly});
  final AircraftAssembly assembly;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: AircraftAssemblyPainter(assembly),
      size: Size.infinite,
    ),
  );
}

class AircraftAssemblyPainter extends CustomPainter {
  const AircraftAssemblyPainter(this.assembly);
  final AircraftAssembly assembly;
  @override
  void paint(Canvas canvas, Size size) {
    if (AircraftAssemblyArt.hulls.length != 3 || size.isEmpty) return;
    final bounds = AircraftAssemblyArt.previewBounds(assembly);
    final extent =
        math.min(size.width / bounds.width, size.height / bounds.height) * .94;
    AircraftAssemblyArt.paintAssembly(
      canvas,
      size.center(Offset.zero) -
          (bounds.center - const Offset(.5, .54)) * extent,
      extent,
      assembly,
    );
  }

  @override
  bool shouldRepaint(AircraftAssemblyPainter old) => old.assembly != assembly;
}
