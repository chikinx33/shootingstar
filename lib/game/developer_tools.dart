part of 'engine.dart';

/// Called only by the password-unlocked, detached developer profile.
extension DeveloperEngineTools on GameEngine {
  void developerPrepare({
    required int scene,
    int phase = 0,
    int startSeconds = 0,
    int enemyCount = 100,
    int shotCount = 200,
    int sparkCount = 80,
    double healthPercent = 100,
    bool ultimateReady = false,
    int supplyKind = -1,
  }) {
    elapsed = startSeconds.clamp(0, duration.toInt() - 10).toDouble();
    combatTime = elapsed;
    if (scene == 1) {
      elapsed = nextBossAt;
      update(.001);
      enemies.removeWhere((e) => e.kind != 3);
      if (boss != null) {
        boss!.hp = boss!.maxHp * const [1.0, .64, .29][phase.clamp(0, 2)];
        _lastBossPhase = bossPhase;
        bossCycle = 0;
        _lockBossAttack();
      }
    } else if (scene == 2 || scene == 3) {
      // An isolated formation test must not be blocked by a late-wave window.
      elapsed = combatTime = 0;
      _spawnNewFlightFormation(
        scene == 2 ? FlightFormation.bulwark : FlightFormation.assault,
        scene == 2 ? 3 : 6,
      );
    } else if (scene == 4 || scene == 5) {
      elapsed = combatTime = 0;
      _spawnBasicFlightFormation(
        scene == 4 ? FlightFormation.column : FlightFormation.fan,
      );
    } else if (scene == 6) {
      for (var i = 0; i < enemyCount.clamp(0, enemyLimit); i++) {
        _spawnEnemy(
          at: position + Offset((i % 13 - 6) * 27, -80 - (i ~/ 13) * 24),
        );
      }
      for (var i = 0; i < shotCount.clamp(0, 1000); i++) {
        shots.add(
          Shot(
            position + Offset((i % 20 - 10) * 18, -70 - (i ~/ 20) * 8),
            Offset((i % 3 - 1) * 12, 35),
            1,
            4,
            life: 12,
          ),
        );
      }
      _burst(position + const Offset(0, -100), 1, sparkCount.clamp(0, 160));
    }
    hp = maxHp * healthPercent.clamp(1, 100) / 100;
    if (ultimateReady) _ultimateCharge = 100;
    if (supplyKind >= 0 && supplyKind <= 6) {
      supplies.add(Supply(position + const Offset(0, -55), supplyKind));
    }
    choices = [];
    pickupNotice = '개발자 테스트 · 일반 저장에 반영되지 않음';
    noticeTime = 3;
  }
}
