import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/ship_modules.dart';

/// Separate native layers: airframe, fixed sockets, detachable top-view parts.
/// No perspective, muzzle openings or support devices painted on the airframe.
abstract final class ModuleAircraftArt {
  static const ink = Color(0xff101c2a),
      steel = Color(0xffdce5eb),
      dark = Color(0xff34495e);
  static Paint fill(Color color) => Paint()..color = color;
  static Paint line([Color color = ink]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = .018
    ..strokeJoin = StrokeJoin.round;
  static void polygon(
    Canvas c,
    List<Offset> points,
    Color color, {
    double stroke = .018,
  }) {
    final p = Path()..addPolygon(points, true);
    c.drawPath(p, fill(color));
    c.drawPath(p, line()..strokeWidth = stroke);
  }

  static void box(
    Canvas c,
    Rect rect,
    Color color, {
    double radius = .015,
    double stroke = .018,
  }) {
    final r = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    c.drawRRect(r, fill(color));
    c.drawRRect(r, line()..strokeWidth = stroke);
  }

  static void paint(
    Canvas c,
    Offset center,
    double extent,
    ModuleSnapshot snap, {
    Map<String, double> angles = const {},
    Map<String, Offset> recoil = const {},
    Map<String, Offset> sideRecoil = const {},
    bool inBattle = false,
  }) {
    c.save();
    c.translate(center.dx - extent * .5, center.dy - extent * .5);
    c.scale(extent);
    final accent = const [
      Color(0xffff704a),
      Color(0xff20c7bb),
      Color(0xff528bfa),
    ][snap.hull];
    polygon(c, const [
      Offset(.5, .015),
      Offset(.66, .32),
      Offset(.98, .48),
      Offset(.96, .62),
      Offset(.68, .55),
      Offset(.67, .78),
      Offset(.81, .94),
      Offset(.62, .9),
      Offset(.59, 1),
      Offset(.41, 1),
      Offset(.38, .9),
      Offset(.19, .94),
      Offset(.33, .78),
      Offset(.32, .55),
      Offset(.04, .62),
      Offset(.02, .48),
      Offset(.34, .32),
    ], steel);
    polygon(c, const [
      Offset(.04, .50),
      Offset(.34, .35),
      Offset(.32, .46),
      Offset(.06, .59),
    ], accent);
    polygon(c, const [
      Offset(.96, .50),
      Offset(.66, .35),
      Offset(.68, .46),
      Offset(.94, .59),
    ], accent);
    polygon(c, const [
      Offset(.5, .035),
      Offset(.60, .23),
      Offset(.58, .80),
      Offset(.5, .92),
      Offset(.42, .80),
      Offset(.40, .23),
    ], accent);
    box(c, const Rect.fromLTWH(.445, .24, .11, .08), const Color(0xff33cff0));
    // The signature gun belongs to the hull and has no detachable slot.
    box(c, const Rect.fromLTWH(.46, .095, .08, .145), dark);
    box(c, const Rect.fromLTWH(.477, .065, .046, .11), steel, radius: 0);
    for (final x in [.35, .59]) {
      box(c, Rect.fromLTWH(x, .83, .06, .12), dark);
      box(c, Rect.fromLTWH(x + .008, .93, .044, .05), const Color(0xff35d7fa));
    }
    for (final mount in moduleProfiles.where((m) => m.weapon)) {
      final points = ModuleGeometry.anchors(mount.id);
      for (var i = 0; i < points.length; i++) {
        final at = points[i];
        socket(c, mount.id, at);
        final part = snap.parts[mount.id];
        if (part == null ||
            (inBattle && part.definition.category == PartCategory.drone))
          continue;
        c.save();
        final lag =
            sideRecoil['${mount.id}:$i'] ?? recoil[mount.id] ?? Offset.zero;
        c.translate(at.dx + lag.dx, at.dy + lag.dy);
        c.rotate(angles[mount.id] ?? ModuleGeometry.angle(mount.id, i));
        final size = ModuleGeometry.partScale(mount.id);
        c.scale(size);
        paintPart(c, part.definition);
        c.restore();
      }
    }
    c.restore();
  }

  static void socket(Canvas c, String id, Offset at) {
    c.save();
    c.translate(at.dx, at.dy);
    final size = ModuleGeometry.size(id);
    c.scale(size.width, size.height);
    if (id == 'W1')
      partPolygon(c, const [
        Offset(0, -.5),
        Offset(.5, 0),
        Offset(0, .5),
        Offset(-.5, 0),
      ], const Color(0xff3489cf));
    else if (id == 'W2')
      partBox(c, const Rect.fromLTWH(-.5, -.5, 1, 1), dark, radius: .05);
    else if (id == 'W3') {
      c.drawCircle(Offset.zero, .5, fill(steel));
      c.drawCircle(Offset.zero, .5, line()..strokeWidth = .08);
      for (final a in [-math.pi / 2, math.pi / 6, 5 * math.pi / 6])
        c.drawCircle(
          Offset(math.cos(a) * .23, math.sin(a) * .23),
          .09,
          fill(ink),
        );
    } else
      partPolygon(c, [
        for (var i = 0; i < 6; i++)
          Offset(
            math.cos(math.pi / 3 * i) * .5,
            math.sin(math.pi / 3 * i) * .5,
          ),
      ], const Color(0xff54829d));
    if (id != 'W3')
      partBox(c, const Rect.fromLTWH(-.23, -.20, .46, .40), steel, radius: .04);
    if (id == 'W2')
      for (final x in [-.39, .39])
        for (final y in [-.32, .32])
          c.drawCircle(Offset(x, y), .045, fill(ink));
    if (id == 'W4')
      for (var i = 0; i < 6; i++)
        c.drawCircle(
          Offset(
            math.cos(i * math.pi / 3) * .36,
            math.sin(i * math.pi / 3) * .36,
          ),
          .04,
          fill(ink),
        );
    c.restore();
  }

  static void partBox(
    Canvas c,
    Rect rect,
    Color color, {
    double radius = .015,
  }) => box(c, rect, color, radius: radius, stroke: .08);
  static void partPolygon(Canvas c, List<Offset> points, Color color) =>
      polygon(c, points, color, stroke: .08);
  static void paintPart(Canvas c, ModulePart part) {
    // A normalized, upward-facing sprite. Its pivot is the socket centre.
    if (part.category == PartCategory.gun) {
      partBox(
        c,
        const Rect.fromLTWH(-.32, -.12, .64, .53),
        const Color(0xffffb72c),
      );
      partBox(c, const Rect.fromLTWH(-.13, -.70, .26, .72), steel, radius: 0);
      partBox(c, const Rect.fromLTWH(-.20, .14, .40, .34), dark, radius: .02);
    } else if (part.category == PartCategory.missile) {
      partPolygon(c, const [
        Offset(0, -.70),
        Offset(.20, -.35),
        Offset(.20, .37),
        Offset(-.20, .37),
        Offset(-.20, -.35),
      ], steel);
      partPolygon(c, const [
        Offset(0, -.70),
        Offset(.2, -.35),
        Offset(-.2, -.35),
      ], const Color(0xffff6848));
      partPolygon(c, const [
        Offset(-.2, .1),
        Offset(-.4, .43),
        Offset(.4, .43),
        Offset(.2, .1),
      ], const Color(0xffffb72c));
      partBox(c, const Rect.fromLTWH(-.13, -.25, .26, .57), steel);
    } else if (part.category == PartCategory.drone) {
      for (final x in [-.4, .25])
        for (final y in [-.37, .22])
          partBox(c, Rect.fromLTWH(x, y, .17, .17), const Color(0xff41cff5));
      partPolygon(c, const [
        Offset(0, -.55),
        Offset(.3, -.1),
        Offset(.25, .35),
        Offset(-.25, .35),
        Offset(-.3, -.1),
      ], steel);
      partBox(
        c,
        const Rect.fromLTWH(-.11, -.24, .22, .33),
        const Color(0xffffb72c),
      );
      partBox(c, const Rect.fromLTWH(-.055, -.62, .11, .31), dark, radius: 0);
    } else {
      final color = switch (part.id) {
        'repair' => const Color(0xff62d9a5),
        'armor' => const Color(0xffa3aac7),
        'thruster' => const Color(0xffff9740),
        _ => const Color(0xff3cd6f0),
      };
      partPolygon(c, const [
        Offset(-.44, -.23),
        Offset(-.24, -.44),
        Offset(.24, -.44),
        Offset(.44, -.23),
        Offset(.44, .23),
        Offset(.24, .44),
        Offset(-.24, .44),
        Offset(-.44, .23),
      ], steel);
      partBox(c, const Rect.fromLTWH(-.26, -.26, .52, .52), color);
      if (part.id == 'repair') {
        c.drawRect(const Rect.fromLTWH(-.19, -.055, .38, .11), fill(ink));
        c.drawRect(const Rect.fromLTWH(-.055, -.19, .11, .38), fill(ink));
      } else if (part.id == 'sensor') {
        c.drawCircle(Offset.zero, .14, fill(dark));
        c.drawCircle(Offset.zero, .06, fill(steel));
      } else if (part.id == 'magnet')
        c.drawArc(
          const Rect.fromLTWH(-.18, -.2, .36, .4),
          0,
          math.pi,
          false,
          line()..strokeWidth = .09,
        );
      else
        c.drawRect(const Rect.fromLTWH(-.15, -.05, .30, .10), fill(ink));
    }
  }
}

class ModulePartIcon extends StatelessWidget {
  const ModulePartIcon(this.part, {super.key, this.size = 56});
  final ModulePart part;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: part.id == 'mortar_cat'
        ? Image.asset('assets/art/icons_v12/mortar.png')
        : CustomPaint(painter: _PartPainter(part)),
  );
}

class _PartPainter extends CustomPainter {
  const _PartPainter(this.part);
  final ModulePart part;
  @override
  void paint(Canvas c, Size size) {
    c.translate(size.width / 2, size.height * .57);
    c.scale(size.shortestSide * .65);
    ModuleAircraftArt.paintPart(c, part);
  }

  @override
  bool shouldRepaint(_PartPainter old) => old.part != part;
}
