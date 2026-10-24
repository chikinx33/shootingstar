import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Input distance only. Does not change speed, damage, time or reward rules.
class ControlPreferences {
  const ControlPreferences({
    this.sensitivity = 1,
    this.deadZone = 1,
    this.leftActions = false,
    this.followTouch = true,
  });
  final int sensitivity, deadZone;
  final bool leftActions;

  /// v12.4 (user 2026-10-24): true flies the cat to the touched point (it
  /// follows the finger); false is drag steering in the house stages — the
  /// cat moves as far as the finger slides and stops when it stops.
  final bool followTouch;
  double get radius => const [60.0, 45.0, 32.0][sensitivity];
  double get threshold => const [0.0, 5.0, 10.0][deadZone];

  /// Finger offset above which the cat settles in follow mode, so the
  /// thumb never hides the airframe (420-wide view units, about 1.6 cm on a
  /// phone; v12.4.2 user: 56 still left the cat under the thumb).
  static const followLift = 104.0;

  /// Drag steering: view units the cat moves per view unit of finger slide.
  double get dragScale => const [.9, 1.15, 1.4][sensitivity];
  static int _choice(dynamic value) =>
      value is int && value >= 0 && value <= 2 ? value : 1;
  factory ControlPreferences.restore(dynamic raw) => raw is Map
      ? ControlPreferences(
          sensitivity: _choice(raw['sensitivity']),
          deadZone: _choice(raw['deadZone']),
          leftActions: raw['leftActions'] == true,
          followTouch: raw['followTouch'] != false,
        )
      : const ControlPreferences();
  Map<String, dynamic> toJson() => {
    'sensitivity': sensitivity,
    'deadZone': deadZone,
    'leftActions': leftActions,
    'followTouch': followTouch,
  };

  /// The floating anchor follows a long drag so direction can reverse quickly.
  /// Small deflections are eased (precision curve) so the cat can make fine
  /// dodges without sliding past the gap; full deflection is still 1.
  ({Offset anchor, Offset input}) steer(Offset anchor, Offset position) {
    if (!anchor.dx.isFinite ||
        !anchor.dy.isFinite ||
        !position.dx.isFinite ||
        !position.dy.isFinite) {
      return (anchor: Offset.zero, input: Offset.zero);
    }
    var delta = position - anchor;
    if (!delta.distance.isFinite) return (anchor: position, input: Offset.zero);
    if (delta.distance > radius) {
      anchor = position - delta / delta.distance * radius;
      delta = position - anchor;
    }
    if (delta.distance < threshold || delta.distance == 0) {
      return (anchor: anchor, input: Offset.zero);
    }
    final reach = (delta.distance / radius).clamp(0.0, 1.0);
    return (
      anchor: anchor,
      input: delta / delta.distance * math.pow(reach, 1.4).toDouble(),
    );
  }
}
