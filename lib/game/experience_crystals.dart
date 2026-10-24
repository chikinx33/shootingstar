import 'dart:ui';

import 'seeded_random.dart';

/// Coordinates remain compatible with legacy 2-XP pickup fixtures/checkpoints.
/// Translating a value-bearing pickup must retain its experience.
class ExperienceCrystal extends Offset {
  const ExperienceCrystal(super.dx, super.dy, this.experience);
  ExperienceCrystal.at(Offset point, this.experience)
    : super(point.dx, point.dy);
  final double experience;
  static double valueOf(Offset point) =>
      point is ExperienceCrystal ? point.experience : 2;
  static int grade(double value) => value >= 16
      ? 2
      : value >= 8
      ? 1
      : 0;
  @override
  ExperienceCrystal operator +(Offset other) =>
      ExperienceCrystal(dx + other.dx, dy + other.dy, experience);
}

/// Shootingstar tuning, not recovered Survivor.io constants. Fewer, richer
/// drops support deliberate collection rather than automatic upgrade chains.
class ExperienceDrops {
  ExperienceDrops(this.random);
  final CombatRandom random;
  int misses = 0;
  static ({double value, double chance, int maxMisses}) plan(double progress) =>
      progress < 1 / 3
      ? (value: 4, chance: .20, maxMisses: 14)
      : progress < 2 / 3
      ? (value: 8, chance: .10, maxMisses: 29)
      : (value: 16, chance: .05, maxMisses: 59);

  double ordinary(double progress, {bool armored = false}) {
    final rule = plan(progress);
    // A separate portable RNG avoids coupling drop rolls to enemy AI/spawns.
    final roll = random.nextDouble();
    if (roll < rule.chance * (armored ? 1.5 : 1) || misses >= rule.maxMisses) {
      misses = 0;
      return armored && rule.value < 8 ? 8 : rule.value;
    }
    misses++;
    return 0;
  }
}
