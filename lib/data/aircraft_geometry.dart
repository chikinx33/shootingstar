import 'dart:ui';

import 'aircraft_assembly.dart';

abstract final class AircraftGeometry {
  static const bodySize = 100.0;
  // Battle-only scale; lobby/hangar composition and part proportions stay intact.
  static const combatScale = .5;
  static const combatBodySize = bodySize * combatScale;

  // Large readable modules, sized against the complete airframe silhouette.
  static double partWidth(AircraftMount mount) => switch (mount) {
    AircraftMount.main => .24,
    AircraftMount.auxiliary => .24,
    AircraftMount.wings => .26,
    AircraftMount.rear => .22,
    AircraftMount.ground => .20,
    AircraftMount.armor => .20,
    _ => .27,
  };
  static Offset partPivot(AircraftMount mount) => switch (mount) {
    AircraftMount.main || AircraftMount.wings => const Offset(.5, .86),
    AircraftMount.rear => const Offset(.5, .14),
    _ => const Offset(.5, .5),
  };
  static const sensorAnchor = Offset(.5, .38);
  static const coreAnchor = Offset(.32, .74);
  static const beltAnchor = Offset(.68, .74);
  static const fittingWidth = .18;
  static const thrusterWidth = .24;
  static const previewSpan = 1.60;
  static const previewLift = .22;
  static Rect mountedRect(
    Offset at,
    double width,
    Rect source, {
    Offset pivot = const Offset(.5, .5),
    bool mirror = false,
  }) => Rect.fromLTWH(
    at.dx - width * (mirror ? 1 - pivot.dx : pivot.dx),
    at.dy - width * source.height / source.width * pivot.dy,
    width,
    width * source.height / source.width,
  );
  static Offset anchor(int hull, AircraftMount mount) {
    final points = switch (hull) {
      1 => const [
        Offset(.500, .280),
        Offset(.500, .560),
        Offset(.230, .440),
        Offset(.500, .900),
        Offset(.500, .740),
        Offset(.200, .620),
      ],
      2 => const [
        Offset(.500, .300),
        Offset(.500, .550),
        Offset(.200, .440),
        Offset(.500, .870),
        Offset(.500, .730),
        Offset(.230, .610),
      ],
      _ => const [
        Offset(.500, .260),
        Offset(.500, .540),
        Offset(.200, .630),
        Offset(.500, .860),
        Offset(.500, .720),
        Offset(.260, .650),
      ],
    };
    return switch (mount) {
      AircraftMount.main => points[0],
      AircraftMount.auxiliary => points[1],
      AircraftMount.wings => points[2],
      AircraftMount.rear => points[3],
      AircraftMount.ground => points[4],
      AircraftMount.armor => points[5],
      AircraftMount.supportLeft => const Offset(.02, 1.05),
      AircraftMount.supportRight => const Offset(.98, 1.05),
      AircraftMount.supportRear => const Offset(.50, 1.24),
    };
  }

  static Offset engineAnchor(int hull) => switch (hull) {
    1 => const Offset(.35, .87),
    2 => const Offset(.16, .83),
    _ => const Offset(.33, .84),
  };
  // Source-alpha aspect ratios * mounted width * front-facing pivot.
  static double mainMuzzleReach(int spec) => spec == 0
      ? partWidth(AircraftMount.main) * combatBodySize * (292 / 189) * .86
      : spec == 1
      ? partWidth(AircraftMount.main) * combatBodySize * (244 / 237) * .86
      : 10 * combatScale;
  // Atlas source aspects: cannon237x336, turret279x318,
  // wing311x316, rear273x306. The pivot is the physical mount.
  static double moduleMuzzleReach(AircraftMount mount) =>
      partWidth(mount) *
      combatBodySize *
      switch (mount) {
        AircraftMount.main => (336 / 237) * .86,
        AircraftMount.wings => (316 / 311) * .86,
        AircraftMount.rear => (306 / 273) * .86,
        AircraftMount.auxiliary => (318 / 279) * .5,
        _ => 0,
      };
  static Offset offset(int hull, AircraftMount mount, {bool right = false}) {
    var at = anchor(hull, mount);
    if (right) at = Offset(1 - at.dx, at.dy);
    return Offset(
      (at.dx - .5) * combatBodySize,
      (at.dy - .54) * combatBodySize,
    );
  }
}
