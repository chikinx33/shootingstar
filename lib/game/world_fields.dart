import 'dart:math' as math;
import 'dart:ui';

enum FieldShape { disc, ring, beam, outside }

/// Painter and damage use the same geometry; cues never track the aircraft
/// after lock-on. No extra actors, projectiles, currencies or random rolls.
class WorldField {
  const WorldField(this.shape, this.a, this.radius, [this.b]);
  final FieldShape shape;
  final Offset a;
  final Offset? b;
  final double radius;
  bool hits(Offset at) {
    final distance = (at - a).distance;
    switch (shape) {
      case FieldShape.disc:
        return distance < radius;
      case FieldShape.ring:
        return (distance - radius).abs() < 18;
      case FieldShape.outside:
        return distance > radius;
      case FieldShape.beam:
        final delta = b! - a;
        final t =
            (((at - a).dx * delta.dx + (at - a).dy * delta.dy) /
                    (delta.dx * delta.dx + delta.dy * delta.dy))
                .clamp(0.0, 1.0);
        return (at - (a + delta * t)).distance < radius;
    }
  }
}

const worldTactics = [
  '잔광 표식 · 원형 표식 밖으로',
  '성운 쌍열 · 두 세로선 사이로',
  '공허 고리 · 고리 안이나 밖으로',
  '빙결 봉쇄 · 가로선 사이로',
  '포자 군락 · 세 원 사이로',
  '철묘 십자 · 대각선으로 회피',
  '태양 방사 · 광선 사이로',
  '심해 수축 · 고리 바깥에 머무르기',
  '수정 반사 · X자 사선 이탈',
  '특이점 · 초록 안전 원 안으로',
];

List<WorldField> worldFields(int world, Offset c, double phase, int cycle) {
  WorldField beam(Offset a, Offset b, [double r = 22]) =>
      WorldField(FieldShape.beam, c + a, r, c + b);
  WorldField disc(Offset o, double r) => WorldField(FieldShape.disc, c + o, r);
  switch (world) {
    case 0:
      return [disc(Offset.zero, 58)];
    case 1:
      return [
        for (final x in [-92.0, 92.0])
          beam(Offset(x, -520), Offset(x, 520), 27),
      ];
    case 2:
      return [WorldField(FieldShape.ring, c, 145)];
    case 3:
      return [
        for (final y in [-100.0, 0.0, 100.0])
          beam(Offset(-520, y), Offset(520, y), 18),
      ];
    case 4:
      return [
        for (var i = 0; i < 3; i++)
          disc(
            Offset(
              math.cos(i * math.pi * 2 / 3) * 76,
              math.sin(i * math.pi * 2 / 3) * 76,
            ),
            46,
          ),
      ];
    case 5:
      return [
        beam(const Offset(-520, 0), const Offset(520, 0)),
        beam(const Offset(0, -520), const Offset(0, 520)),
      ];
    case 6:
      return [
        for (var i = 0; i < 3; i++)
          beam(
            Offset.zero,
            Offset(
              math.cos(-math.pi / 2 + i * math.pi * 2 / 3) * 520,
              math.sin(-math.pi / 2 + i * math.pi * 2 / 3) * 520,
            ),
            20,
          ),
      ];
    case 7:
      return [
        WorldField(
          FieldShape.ring,
          c,
          180 - 90 * ((phase - 13) / 2).clamp(0, 1),
        ),
      ];
    case 8:
      return [
        beam(const Offset(-520, -520), const Offset(520, 520)),
        beam(const Offset(520, -520), const Offset(-520, 520)),
      ];
    default:
      return [
        WorldField(
          FieldShape.outside,
          c + Offset(cycle.isEven ? 72 : -72, 0),
          135,
        ),
      ];
  }
}
