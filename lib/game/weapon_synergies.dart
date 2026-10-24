part of 'engine.dart';

class WeaponSynergy {
  const WeaponSynergy(
    this.id,
    this.name,
    this.armament,
    this.description, {
    this.branch,
    this.weapons = const {},
    this.passives = const {},
    this.tags = const {},
    this.weaponMinimums = const {},
  });
  final String id, name, description;
  final String? armament;
  final MainBranch? branch;
  final Set<String> weapons, passives;
  final Set<WeaponTag> tags;
  final Map<String, int> weaponMinimums;
}

const weaponSynergies = [
  WeaponSynergy(
    'shield-counter',
    '방패 역습',
    null,
    '수호자 3단계 + 반응 장갑. 수호자가 실제 탄막을 차단하면 3초 내 다음 주포 공격 한 번 피해 50% 증가. 4초 간격, 중첩 없음.',
    weapons: {'guardian'},
    passives: {'armor'},
    tags: {WeaponTag.guard},
    weaponMinimums: {'guardian': 3},
  ),
  WeaponSynergy(
    'front-break',
    '정면 돌파',
    'pulse',
    '레이저 명중으로 일반 적을 0.8초 감속. 감속된 적에 주포 3회 연속 명중하면 1.25초 동안 새 주포탄 관통 +1. 전체 재발동 3초.',
    branch: MainBranch.pulseFocus,
    weapons: {'laser'},
    tags: {WeaponTag.pierce},
  ),
  WeaponSynergy(
    'explosive-spread',
    '폭발 확산',
    'shotgun',
    '산탄 본탄으로 일반 적을 처치하면 주변 적에게 유도 폭발 파편 2발. 1.5초 간격, 파편은 시너지를 재발동하지 않음.',
    weapons: {'missile'},
    passives: {'area'},
    tags: {WeaponTag.explosive},
  ),
];

extension WeaponSynergies on GameEngine {
  Set<WeaponTag> get auxiliaryTags => {
    for (final e in upgrades.entries)
      if (e.value > 0)
        ...?weaponRoleFor(e.key, evolved: evolved.contains(e.key))?.tags,
  };

  String weaponRoleLabel(String id, {bool? evolution}) {
    if (unifiedModules && id.startsWith('part:')) {
      final mount = id.substring(5);
      if (moduleLoadout!.parts.containsKey(mount))
        return mountProfile(mount).direction;
    }
    if (modular) {
      final mount = moduleSkillMount(id);
      if (mount != null) return moduleMountLabel(mount);
    }
    return weaponRoleFor(
          id,
          evolved: evolution ?? evolved.contains(id),
        )?.label ??
        '';
  }

  List<String> synergyMissing(WeaponSynergy spec) => [
    if (spec.armament != null && armament != spec.armament)
      spec.armament == 'pulse' ? '펄스 주포' : '산탄 캐논',
    if (spec.branch != null && mainBranch != spec.branch)
      mainBranches.firstWhere((s) => s.branch == spec.branch).name,
    for (final id in spec.weapons)
      if ((upgrades[id] ?? 0) < (spec.weaponMinimums[id] ?? 1))
        '${skillFor(id).name}${(spec.weaponMinimums[id] ?? 1) > 1 ? ' ${spec.weaponMinimums[id]}단계' : ''}',
    for (final id in spec.passives)
      if ((passives[id] ?? 0) <= 0) skillFor(id).name,
    // Equipment requirements supply these tags; use live post-fusion membership.
    if (spec.weapons.every((id) => (upgrades[id] ?? 0) > 0))
      for (final tag in spec.tags)
        if (!auxiliaryTags.contains(tag)) '${tag.label} 태그',
  ];

  bool synergyReady(String id) {
    if (modular &&
        ((id == 'shield-counter' && !moduleSkillAvailable('guardian')) ||
            (id == 'front-break' && !moduleSkillAvailable('laser')) ||
            (id == 'explosive-spread' && !moduleSkillAvailable('missile'))))
      return false;
    final spec = weaponSynergies.firstWhere((s) => s.id == id);
    if ((spec.armament != null && armament != spec.armament) ||
        (spec.branch != null && mainBranch != spec.branch)) {
      return false;
    }
    if (spec.weapons.any(
          (key) => (upgrades[key] ?? 0) < (spec.weaponMinimums[key] ?? 1),
        ) ||
        spec.passives.any((key) => (passives[key] ?? 0) <= 0)) {
      return false;
    }
    final tags = auxiliaryTags;
    return spec.tags.every(tags.contains);
  }

  int synergyTriggers(String id) => _synergyTriggers[id] ?? 0;
  double get frontBreakRemaining => synergyReady('front-break')
      ? math.max(0, _frontBreakUntil - combatTime)
      : 0;
  String get synergyHudText {
    final labels = <String>[];
    for (final spec in weaponSynergies) {
      if (!synergyReady(spec.id)) continue;
      final active = spec.id == 'front-break' && frontBreakRemaining > 0;
      labels.add(
        '${spec.name} · ${active
            ? '관통 +1'
            : spec.id == 'shield-counter' && shieldCounterPending
            ? '역습 장전'
            : '준비'} · ${synergyTriggers(spec.id)}회',
      );
    }
    return labels.join('\n');
  }

  List<String> get synergyDetails => unifiedModules
      ? [
          for (final e in moduleLoadout!.parts.entries)
            '${e.key} · ${e.value.definition.name}\n${e.value.definition.weapon ? mountProfile(e.key).direction : e.value.definition.effect}',
        ]
      : modular
      ? [
          '장갑 연계 · 수호자 강화 시 근접 탄환1발 차단 · 2초 간격',
          '정면 돌파 · 보조 레이저 강화로 감속 · 주포 3회 명중 시 관통 +1',
          '폭발 확산 · 산탄·날개 로켓·고출력 연료 · 처치 시 전방 폭발',
        ]
      : [
          for (final spec in weaponSynergies.where(
            (s) =>
                s.armament == armament ||
                (s.armament == null &&
                    (s.weapons.any((id) => (upgrades[id] ?? 0) > 0) ||
                        s.passives.any((id) => (passives[id] ?? 0) > 0))),
          ))
            '${spec.name} · ${synergyMissing(spec).isEmpty ? '활성' : '필요: ${synergyMissing(spec).join(' + ')}'}'
                ' · ${synergyTriggers(spec.id)}회${spec.id == 'shield-counter' ? ' / 역습 $_shieldCounterAttacks회' : ''}\n${spec.description}',
        ];

  String choiceDetail(UpgradeChoice choice) {
    if (modular) return growthDetail(choice) ?? choice.description;
    final role = weaponRoleLabel(
      choice.id,
      evolution: choice.evolution || evolved.contains(choice.id),
    );
    final hint = switch ((armament, choice.id)) {
      ('pulse', 'laser') ||
      ('pulse', 'main-pulseFocus') => '연계: 집속 펄스 + 레이저 → 정면 돌파',
      ('shotgun', 'missile') ||
      ('shotgun', 'area') ||
      ('shotgun', 'main-shellClose') ||
      ('shotgun', 'main-shellSplit') => '연계: 산탄 + 로켓 + 고출력 연료 → 폭발 확산',
      (_, 'guardian') || (_, 'armor') => '연계: 수호자 3 + 반응 장갑 → 방패 역습',
      _ => '',
    };
    return [
      choice.description,
      if (role.isNotEmpty) role,
      if (hint.isNotEmpty) hint,
    ].join('\n');
  }

  void _synergyFeedback(String id, String message) {
    visuals.emit(CombatCueKind.synergy, position, source: id, radius: 70);
    _synergyTriggers[id] = synergyTriggers(id) + 1;
    pickupNotice = message;
    noticeTime = 1.25;
    _burst(position, 1, 4);
  }

  bool get shieldCounterPending =>
      _shieldCounterArmed &&
      combatTime < _shieldCounterUntil &&
      synergyReady('shield-counter');

  void _onGuardianBlock() {
    visuals.emit(
      CombatCueKind.shield,
      position,
      radius: 60,
      throttle: 'block',
      interval: .15,
    );
    if (!synergyReady('shield-counter') ||
        combatTime < _shieldCounterReadyAt ||
        shieldCounterPending) {
      return;
    }
    _shieldCounterArmed = true;
    _shieldCounterUntil = combatTime + 3;
    _shieldCounterReadyAt = combatTime + 4;
    _synergyFeedback('shield-counter', '방패 역습 · 다음 주포 공격 +50%');
  }

  void _resolveSynergyHit(Shot shot, Foe target, double previousHp) {
    if (!shot.triggersSynergies ||
        shot.kind != 0 ||
        (shot.weapon.isNotEmpty && shot.weapon != 'gun') ||
        target.kind == 3 ||
        target.retired ||
        previousHp <= target.hp) {
      return;
    }
    final frontReady = synergyReady('front-break');
    if (frontReady && (target.status != 2 || target.statusTime <= 0)) {
      target.frontBreakHits = 0;
    }
    if (frontReady &&
        target.hp > 0 &&
        target.status == 2 &&
        target.statusTime > 0 &&
        combatTime >= _frontBreakReadyAt &&
        combatTime >= target.frontBreakReadyAt) {
      target.frontBreakHits = combatTime - target.frontBreakLastHit <= 1.1
          ? target.frontBreakHits + 1
          : 1;
      target.frontBreakLastHit = combatTime;
      if (target.frontBreakHits >= 3) {
        target.frontBreakHits = 0;
        target.frontBreakReadyAt = combatTime + 4;
        _frontBreakReadyAt = combatTime + 3;
        _frontBreakUntil = combatTime + 1.25;
        _synergyFeedback('front-break', '정면 돌파 · 주포 관통 +1');
      }
    }
    if (synergyReady('explosive-spread') &&
        target.hp <= 0 &&
        combatTime >= _explosiveSpreadReadyAt) {
      Foe? next;
      var nearest = 260.0;
      for (final e in enemies) {
        if (e.hp <= 0 || e.retired) continue;
        final d = (e.position - target.position).distance;
        if (d < nearest) {
          next = e;
          nearest = d;
        }
      }
      if (next == null) return;
      final direction = _unit(next.position - target.position);
      final angle = math.atan2(direction.dy, direction.dx);
      for (final turn in [-.22, .22]) {
        _deferredShots.add(
          Shot(
            target.position,
            _direction(angle + turn) * 275,
            _primaryHitDamage(shot) * .45,
            1,
            weapon: 'synergy-explosive',
            target: next,
            life: 1.2,
            radius: 4,
          )..triggersSynergies = false,
        );
      }
      _explosiveSpreadReadyAt = combatTime + 1.5;
      _synergyFeedback('explosive-spread', '폭발 확산 · 유도 파편 2발');
    }
  }
}
