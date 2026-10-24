part of 'engine.dart';

extension BossGearCombat on GameEngine {
  bool _setMainSource(String source) => const {
    'gun',
    'module-main',
    'primary',
    'soul',
    'havoc',
    'starforge',
    'lance',
    'void',
    'sword-array',
    'fissure',
  }.contains(source);
  double bossSetHitFactor(Foe target, String source) {
    if (bossSetWorld < 0) return 1;
    final main = _setMainSource(source);
    final auxiliary =
        bossSetWorld == 9 &&
        (survivalSkills.any(
              (s) => s.id == source && !s.passive && s.id != 'gun',
            ) ||
            source == 'missile-evo' ||
            source.startsWith('module-'));
    return switch (bossSetWorld) {
      0 when main && hp >= maxHp * .8 => 1.08,
      1 when target.kind == 3 && bossExposed => 1.10,
      2 when main && target.formationPattern != null => 1.10,
      3 when target.status == 2 && target.statusTime > 0 => 1.10,
      9
          when (main && target.kind == 3) ||
              (auxiliary && !main && target.kind != 3) =>
        1.06,
      _ => 1,
    };
  }

  double get bossSetReduction => switch (bossSetWorld) {
    5 when hp < maxHp * .5 => .06,
    7 when boss != null => .05,
    _ => 0,
  };
  double get bossSetSpeed => bossSetWorld == 6 && hp >= maxHp * .8 ? 1.08 : 1;
  double get bossSetCrit => bossSetWorld == 8 ? .04 : 0;
  void _updateBossGearSet(double dt) {
    if (bossSetWorld != 4) return;
    _bossSetHealClock -= dt;
    if (_bossSetHealClock <= 0) {
      _bossSetHealClock = 10;
      if (hp < maxHp * .5) hp = math.min(maxHp, hp + maxHp * .01);
    }
  }

  String get bossSetDescription => bossSetWorld >= 0
      ? '보스 세트 · ${content.worlds[bossSetWorld].name}\n${boss_catalog.gearCatalog[12 + bossSetWorld * 2].perk}'
      : '보스 세트 · 미장착\n같은 세계 희귀 이상 선체·추진기 2종 장착';
}
