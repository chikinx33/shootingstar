part of 'engine.dart';

enum MainBranch {
  pulseFocus,
  pulseSpread,
  railPierce,
  railCharge,
  shellClose,
  shellSplit,
  needlePierce,
  needleSwarm,
  bladeLong,
  bladeFan,
  batRam,
  batOrbit,
  lightLance,
  lightCross,
  voidWell,
  voidDrift,
  soulPierce,
  soulRelease,
  lanceRing,
  lanceThrust,
}

class MainBranchSpec {
  const MainBranchSpec(this.branch, this.armament, this.name, this.description);
  final MainBranch branch;
  final String armament, name, description;
  String get id => 'main-${branch.name}';
  UpgradeChoice get choice =>
      UpgradeChoice(id, name, description, 'gun', specialization: true);
}

const mainBranches = [
  MainBranchSpec(
    MainBranch.pulseFocus,
    'pulse',
    '집속 펄스',
    '좁은 탄열 · 관통 +2\n단발 피해 −10%',
  ),
  MainBranchSpec(
    MainBranch.pulseSpread,
    'pulse',
    '확산 펄스',
    '넓은 부채꼴 · 탄수 +2\n개별 탄 피해 −28%',
  ),
  MainBranchSpec(
    MainBranch.railPierce,
    'revolver',
    '과관통 레일',
    '관통 +5 · 일렬 돌파\n단일 피해 −20%',
  ),
  MainBranchSpec(
    MainBranch.railCharge,
    'revolver',
    '축전 레일',
    '재장전 후 첫 사격 2배\n재장전 1.4 → 1.8초',
  ),
  MainBranchSpec(
    MainBranch.shellClose,
    'shotgun',
    '근접 압축',
    '좁은 산탄 · 근거리 1.5배\n거리 140부터 피해 감소',
  ),
  MainBranchSpec(
    MainBranch.shellSplit,
    'shotgun',
    '파편 확산',
    '넓은 산탄 · 명중 시 파편\n본탄 피해 −35%',
  ),
  MainBranchSpec(
    MainBranch.needlePierce,
    'kunai',
    '관통 유도',
    '유도 침 관통 +2\n개별 피해 −15%',
  ),
  MainBranchSpec(
    MainBranch.needleSwarm,
    'kunai',
    '군집 유도',
    '600 이내 여러 표적 · 탄수 +2\n개별 피해 −45% · 간격 +40%',
  ),
  MainBranchSpec(
    MainBranch.bladeLong,
    'katana',
    '장도 파동',
    '전후 사거리 +50% · 좁은 검기\n피해 +10% · 간격 +25%',
  ),
  MainBranchSpec(
    MainBranch.bladeFan,
    'katana',
    '부채 파동',
    '짧은 전방 검기 3갈래\n각 피해 −40% · 후방 공격 없음',
  ),
  MainBranchSpec(
    MainBranch.batRam,
    'bat',
    '돌파 타격',
    '긴 직선 타격 · 강한 밀치기\n간격 +25% · 진화 원형 타격 유지',
  ),
  MainBranchSpec(
    MainBranch.batOrbit,
    'bat',
    '회전 타격',
    '짧은 원형 공격으로 포위 대응\n기본 타격 피해 −30%',
  ),
  MainBranchSpec(
    MainBranch.lightLance,
    'lightchaser',
    '장광 참격',
    '긴 전방 검기 · 폭 축소\n간격 +15% · 진화 검진 유지',
  ),
  MainBranchSpec(
    MainBranch.lightCross,
    'lightchaser',
    '십자 참격',
    '짧은 사방 검기\n각 타격 피해 −50% · 진화 검진 유지',
  ),
  MainBranchSpec(
    MainBranch.voidWell,
    'void',
    '응축 공허',
    '작은 고밀도 고정 중력장\n반경 −30% · 간격 1.8 → 2.2초',
  ),
  MainBranchSpec(
    MainBranch.voidDrift,
    'void',
    '이동 공허',
    '비행 방향으로 흐르는 넓은 장\n틱 피해 −30% · 지속 시간 단축',
  ),
  MainBranchSpec(
    MainBranch.soulPierce,
    'disorder',
    '혼령 관통',
    '영혼탄 관통 +2 · 중첩당 강화 확대\n기본 피해 −20%',
  ),
  MainBranchSpec(
    MainBranch.soulRelease,
    'disorder',
    '영혼 방출',
    '직선 확산탄 · 중첩 최대10 소비 강화\n유도 없음 · 기본 피해 −20%',
  ),
  MainBranchSpec(
    MainBranch.lanceRing,
    'lance',
    '광환 전개',
    '큰 빛 고리 · 짧고 약한 찌르기\n간격 1.2 → 1.3초',
  ),
  MainBranchSpec(
    MainBranch.lanceThrust,
    'lance',
    '암창 집중',
    '긴 집중 찌르기 · 작고 약한 고리\n간격 1.2 → 1.4초',
  ),
];

extension MainSpecializations on GameEngine {
  MainBranchSpec? get mainBranchSpec {
    for (final spec in mainBranches) {
      if (spec.branch == mainBranch)
        return modular
            ? MainBranchSpec(
                spec.branch,
                spec.armament,
                spec.name,
                moduleBranchDescription(spec.branch),
              )
            : spec;
    }
    return null;
  }

  List<UpgradeChoice> get availableMainBranches => mainBranch != null
      ? const []
      : [
          for (final spec in mainBranches)
            if (spec.armament == armament)
              modular
                  ? UpgradeChoice(
                      spec.id,
                      spec.name,
                      moduleBranchDescription(spec.branch),
                      'gun',
                      specialization: true,
                    )
                  : spec.choice,
        ];

  bool _choiceIsPassive(UpgradeChoice c) =>
      !c.specialization && c.id != 'repair' && isPassiveSkill(c.id);

  void _applyPulseBranch(int start) {
    if (mainBranch != MainBranch.pulseFocus &&
        mainBranch != MainBranch.pulseSpread) {
      return;
    }
    final spread = mainBranch == MainBranch.pulseSpread;
    final bullets = shots.sublist(start);
    if (spread && bullets.isNotEmpty) {
      for (int i = 0; i < 2; i++) {
        final extra = Shot(
          position + const Offset(0, -17),
          const Offset(0, -420),
          bullets.first.damage,
          0,
          weapon: 'gun',
          radius: mainWidth,
          pierce: techSpecial('gun') ? 1 : 0,
        );
        shots.add(extra);
        bullets.add(extra);
      }
    }
    for (int i = 0; i < bullets.length; i++) {
      final s = bullets[i];
      s.damage *= spread ? .72 : .9;
      if (spread) {
        final angle = -math.pi / 2 + (i - (bullets.length - 1) / 2) * .14;
        s.velocity = _direction(angle) * s.velocity.distance;
        s.position = position + const Offset(0, -17);
      } else {
        s.position = Offset(
          position.dx + (s.position.dx - position.dx) * .35,
          s.position.dy,
        );
        s.pierce += 2;
        if (frontBreakRemaining > 0) s.pierce++;
      }
    }
  }

  // Shards are deferred until after collision iteration; they never split again.
  double _primaryHitDamage(Shot s) {
    if (!s.closeRange) return s.damage;
    return s.damage * (s.distanceTravelled <= 140 ? 1.5 : .55);
  }

  void _splitShell(Shot s, Foe hit) {
    if (!s.splitOnHit) return;
    s.splitOnHit = false;
    final angle = math.atan2(s.velocity.dy, s.velocity.dx);
    for (final turn in [-.65, .65]) {
      final shard = Shot(
        s.position,
        _direction(angle + turn) * 330 * skillSpeed,
        s.damage * .4,
        0,
        weapon: 'gun',
        life: .45,
        radius: 3,
      );
      shard.hitTargets.add(hit);
      shard.triggersSynergies = false;
      _deferredShots.add(shard);
    }
  }
}
