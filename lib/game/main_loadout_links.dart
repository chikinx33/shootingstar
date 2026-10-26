part of 'engine.dart';

extension MainLoadoutLinks on GameEngine {
  bool get precisionLinkActive => mainPrecisionLink && techSpecial('gun');
  bool get cycleLinkActive => mainCycleLink && techSpecial('gun');

  /// v12.17: only the three cat guns remain; the 구름 rail aims.
  bool get _aimedMain => armament == 'revolver';
  double get mainReachFactor => precisionLinkActive && !_aimedMain ? 1.15 : 1;

  String get mainTechEffect => '본탄 관통 +1';
  String get mainLoadoutDescription => unifiedModules
      ? '${moduleLoadout!.signatureName} · 고유 주포 · 공중 전방 공격\n기체 Lv.${moduleLoadout!.airframeLevel} · ${moduleLoadout!.ultimateName}'
      : modular
      ? [
          '전방 주포 · 공중 전용',
          '정밀 연계 · 전방 주포 피해 +8%',
          '순환 방호 · 주포 8회마다 최대 선체3% 차폐 · 상한15%',
          bossSetDescription,
        ].join('\n')
      : [
          bossSetDescription,
          '관통 증폭기 · ${techRanks.containsKey('gun') ? '피해 +${((techDamage('gun') - 1) * 100).round()}%' : '미장착'}',
          '${techSpecial('gun') ? '특수 활성' : '희귀 등급부터'} · $mainTechEffect',
          '정밀 연계 · ${precisionLinkActive ? '활성' : '필요: 희귀 관통 증폭기 + 우수 매의 눈 센서 장착'}\n'
              '${_aimedMain ? '600 이내 최대 선체 표적 우선 조준' : '주무기 사거리·범위 +15%'}',
          '순환 방호 · ${cycleLinkActive ? '활성' : '필요: 희귀 관통 증폭기 + 우수 순환 에너지 코어 장착'}\n'
              '주포 공격 4회마다 근접 탄막 1발 차단 · 최소2초 간격 · $_mainLinkBlocks회',
        ].join('\n');

  Foe? _mainTarget({Set<Foe> exclude = const {}}) {
    if (!precisionLinkActive && exclude.isEmpty) return _nearest();
    Foe? best;
    var distance = precisionLinkActive && _aimedMain ? 600.0 : double.infinity;
    for (final e in enemies) {
      if (e.hp <= 0 || e.retired || exclude.contains(e)) continue;
      final d = (e.position - position).distance;
      if (precisionLinkActive && _aimedMain) {
        if (d <= 600 &&
            (best == null ||
                e.maxHp > best.maxHp ||
                (e.maxHp == best.maxHp && d < distance))) {
          best = e;
          distance = d;
        }
      } else if (d < distance) {
        best = e;
        distance = d;
      }
    }
    // A precision link does not make an out-of-range ordinary target disappear.
    return best ?? (exclude.isEmpty ? _nearest() : null);
  }

  bool _applyMainLoadout(int start) {
    final fired = shots.length > start || _mainAttackDidDamage;
    for (int i = start; i < shots.length; i++) {
      final s = shots[i];
      if ((s.kind == 0 || s.kind == 9) && s.damage > 0) {
        if (techSpecial('gun') && armament != 'pulse') s.pierce++;
        if (armament == 'pulse' && frontBreakRemaining > 0) s.pierce++;
        if (precisionLinkActive && !_aimedMain) s.life *= 1.15;
      } else if (s.kind == 13 && s.damage > 0) {
        if (precisionLinkActive && !_aimedMain) s.radius *= 1.15;
      }
    }
    if (!fired || !cycleLinkActive) return fired;
    _mainLinkVolleys++;
    if (_mainLinkVolleys % 4 != 0 || combatTime < _mainLinkBlockReadyAt) {
      return fired;
    }
    Shot? nearest;
    var distance = 90.0;
    for (final s in shots) {
      if (!s.interceptable || s.life <= 0 || s.damage <= 0) continue;
      final d = (s.position - position).distance;
      if (d <= distance) {
        nearest = s;
        distance = d;
      }
    }
    if (nearest == null) return fired;
    shots.remove(nearest);
    _mainLinkBlocks++;
    _mainLinkBlockReadyAt = combatTime + 2;
    // This is not a guardian block and must never arm shield counter.
    _burst(position, 1, 4);
    return fired;
  }
}
