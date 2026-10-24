import 'combat_loadout.dart';

/// Permanent weapon identities and bounded reinforcement, independent of R/P/N.
class ArmamentCollection {
  ArmamentCollection._(this._levels);
  factory ArmamentCollection.fresh() => ArmamentCollection._({'pulse': 0});
  final Map<String, int> _levels;
  static const maxLevel = 10, unlockCredits = 300, unlockBlueprints = 3;
  static int upgradeCredits(int level) => 120 + 80 * level;
  static int upgradeBlueprints(int level) => 1 + level ~/ 3;
  static double damageBonus(int level) => level.clamp(0, maxLevel) * .02;
  static bool valid(String id) => armaments.any((a) => a.id == id);

  static ArmamentCollection restore(dynamic raw, {required bool legacy}) {
    final levels = <String, int>{'pulse': 0};
    if (legacy) {
      for (final a in armaments) {
        levels[a.id] = 0;
      }
    } else if (raw is Map) {
      for (final a in armaments) {
        final level = raw[a.id];
        if (level is int && level >= 0) {
          levels[a.id] = level.clamp(0, maxLevel);
        }
      }
    }
    return ArmamentCollection._(levels);
  }

  bool owns(String id) => _levels.containsKey(id);
  int level(String id) => _levels[id] ?? 0;
  int get ownedCount => _levels.length;
  Map<String, int> toJson() => Map.of(_levels);
  bool unlock(String id) {
    if (!valid(id) || owns(id)) return false;
    _levels[id] = 0;
    return true;
  }

  bool upgrade(String id) {
    if (!owns(id) || level(id) >= maxLevel) return false;
    _levels[id] = level(id) + 1;
    return true;
  }

  int refundCredits(String id) {
    var total = 0;
    for (var i = 0; i < level(id); i++) {
      total += upgradeCredits(i);
    }
    return total;
  }

  int refundBlueprints(String id) {
    var total = 0;
    for (var i = 0; i < level(id); i++) {
      total += upgradeBlueprints(i);
    }
    return total;
  }

  void reset(String id) {
    if (owns(id)) _levels[id] = 0;
  }
}
