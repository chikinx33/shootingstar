import 'dart:ui';

import '../game/experience_crystals.dart';

/// Original, flat-color facets. Tier differs in size and cuts as well as color.
abstract final class ExperienceGemArt {
  static void paint(
    Canvas canvas,
    Offset point,
    double experience, {
    double rotation = 0,
  }) {
    final grade = ExperienceCrystal.grade(experience);
    final width = 5.0 + grade * 1.5, height = 7.0 + grade * 1.5;
    final color = const [
      Color(0xFF73DF80),
      Color(0xFF50BFFF),
      Color(0xFFFFCE4A),
    ][grade];
    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.rotate(rotation);
    final shape = Path()
      ..moveTo(0, -height)
      ..lineTo(width, 0)
      ..lineTo(0, height)
      ..lineTo(-width, 0)
      ..close();
    canvas.drawPath(shape, Paint()..color = color);
    canvas.drawPath(
      shape,
      Paint()
        ..color = const Color(0xFF163142)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, -height + 2)
        ..lineTo(0, height - 2)
        ..lineTo(-width + 2, 0)
        ..close(),
      Paint()..color = const Color(0xBFFFFFFF),
    );
    if (grade > 0) {
      canvas.drawLine(
        Offset(-width + 1, 0),
        Offset(width - 1, 0),
        Paint()
          ..color = const Color(0xFF2479A2)
          ..strokeWidth = 1,
      );
    }
    if (grade == 2) {
      canvas.drawLine(
        Offset(0, -height + 2),
        Offset(width - 2, 0),
        Paint()
          ..color = const Color(0xFFFFF3B4)
          ..strokeWidth = 2,
      );
    }
    canvas.restore();
  }
}
