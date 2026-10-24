part of 'engine.dart';

/// v12 weapon growth (docs/WEAPON_EVOLUTION_DESIGN.md, user 2026-10-24):
/// every weapon has three *enhance* steps (its numbers), three *evolve* steps
/// (its traits) and, once both are full, one *ultimate* that changes its
/// name, look and behaviour. Picks come from the level-up cards.
class GrowthPlan {
  const GrowthPlan(
    this.name,
    this.enhance,
    this.evolve,
    this.ultimate,
    this.ultimateText,
    this.icon,
    this.ultimateIcon,
  );
  final String name, ultimate, ultimateText, icon, ultimateIcon;
  final List<String> enhance, evolve;
}

const growthPlans = <String, GrowthPlan>{
  // main guns (fixed per cat)
  'pulse': GrowthPlan(
    '냥냥 연사포',
    ['피해 +25%', '연사 +30%', '탄 크기·탄속 +25%'],
    ['2줄 발사', '관통 1', '3줄 + 관통 2'],
    '태양 냥냥 개틀링',
    '회전 개틀링 · 열이 차면 2초간 태양 광선',
    'gun',
    'gun',
  ),
  'revolver': GrowthPlan(
    '정밀 냥냥포',
    ['피해 +30%', '탄속 +40% · 사거리 증가', '치명타 확률 +15%'],
    ['관통 2', '명중 시 파편 3개 분리', '화면 끝까지 관통'],
    '구름 레일건',
    '화면 세로 전체를 꿰뚫는 레일 빔 · 감전 표식',
    'gun',
    'gun',
  ),
  'shotgun': GrowthPlan(
    '꾹꾹 산탄포',
    ['피해 +25%', '발사 간격 −25%', '퍼짐 사거리 +30%'],
    ['탄 2발 추가', '맞은 탄이 1회 튕김', '근거리 넉백 + 기절'],
    '밤하늘 발톱 폭풍',
    '거대한 발톱 충격파 세 줄 · 적 탄도 지움',
    'gun',
    'gun',
  ),
  // weapons mounted on the airframe
  'gun_vulcan': GrowthPlan(
    '발칸 건',
    ['피해 +25%', '연사 +35%', '사거리·탄속 +30%'],
    ['좌우 2연장', '관통 1', '약한 유도'],
    '트윈 회전 포탑',
    '날개 끝 포탑 두 개가 360° 각자 조준 · 연사 1.5배 · 적 탄 요격',
    'gun',
    'icon:turret',
  ),
  'missile_hawk': GrowthPlan(
    '고등어 미사일',
    ['폭발 피해 +30%', '재장전 −25%', '폭발 반경 +35%'],
    ['동시 2발', '강한 유도 · 가장 강한 적 우선', '명중 시 새끼 고등어 4발'],
    '참치 순항 미사일',
    '거대 참치가 대폭발 · 고등어 떼 8발이 사방으로',
    'missile',
    'icon:tuna',
  ),
  'drone_wasp': GrowthPlan(
    '정찰 드론',
    ['드론 공격력 +25%', '체력 +40% · 재정비 −30%', '드론 연사 +30%'],
    ['드론 2대', '드론 3대 + 적 탄 요격', '자율 비행 · 가까운 적 추격'],
    '공수 정찰 모선',
    '모선이 자율 비행하며 소형 공수 정찰기 10대를 투하',
    'drone',
    'icon:mothership',
  ),
  'mortar_cat': GrowthPlan(
    '후방 자주포',
    ['피해 +25%', '재장전 −25%', '폭발 반경 +30%'],
    ['2연발', '착탄 지점 끈끈이(둔화)', '3갈래로 퍼져 떨어짐'],
    '냥냥 융단 폭격',
    '3초마다 화면 위쪽 한 줄에 포탄 6발',
    'icon:mortar',
    'icon:mortar',
  ),
  // level-up item attacks
  'paw:orbit': GrowthPlan(
    '꾹꾹 냥펀치',
    ['피해 +25%', '회전·펀치 빨라짐', '궤도·발 크기 +30%'],
    ['발 +1', '넉백 강화 + 적 탄 튕겨냄', '발 5개 + 펀치 충격파'],
    '거대 냥냥 펀치',
    '6초마다 거대한 앞발이 내려와 쾅',
    'paw:orbit',
    'icon:paw',
  ),
  'paw:yarn': GrowthPlan(
    '털실 폭탄',
    ['피해 +30%', '쿨타임 −25%', '폭발 반경 +35%'],
    ['2개 동시', '터진 자리에 털실 그물(둔화)', '작은 털실 4개로 분열'],
    '털실 대폭풍',
    '거대 털실이 굴러다니며 연속 폭발',
    'paw:yarn',
    'paw:yarn',
  ),
  'paw:laser': GrowthPlan(
    '레이저 포인터',
    ['초당 피해 +30%', '지속 +40%', '쿨타임 −30%'],
    ['처치 시 즉시 다음 적', '빔 2개', '맞은 적 주변 범위 피해'],
    '레드닷 위성',
    '위성이 거대한 레드닷 빔을 계속 내림',
    'paw:laser',
    'icon:satellite',
  ),
  'paw:crescent': GrowthPlan(
    '발톱 반달',
    ['피해 +25%', '속도·사거리 +30%', '크기 +35%'],
    ['2개', '돌아올 때 피해 2배', '처치 시 작은 반달 분열'],
    '태풍 반달',
    '거대 회전 반달 3개가 화면을 휩쓸며 적 탄도 지움',
    'paw:crescent',
    'paw:crescent',
  ),
  'paw:bounce': GrowthPlan(
    '통통 공',
    ['피해 +25%', '크기 +30%', '속도·지속 +30%'],
    ['공 2개', '튕길 때마다 커지고 강해짐', '튕길 때 작은 공 분열'],
    '왕 털공 핀볼',
    '거대 공이 적을 범퍼처럼 튕겨 연쇄 피해',
    'paw:bounce',
    'paw:bounce',
  ),
  'paw:zap': GrowthPlan(
    '수염 번개',
    ['피해 +25%', '쿨타임 −30%', '연쇄 거리 +40%'],
    ['연쇄 +2', '감전(둔화)', '두 갈래로 시작'],
    '천둥 구름 수염',
    '천둥 구름이 2초마다 낙뢰 5개를 떨어뜨림',
    'paw:zap',
    'icon:cloud',
  ),
};

extension WeaponGrowth on GameEngine {
  /// The plan behind a growth id: 'gun', 'part:W#' or 'paw:*'.
  String? planKey(String id) {
    if (id == 'gun') {
      return growthPlans.containsKey(armament) ? armament : 'pulse';
    }
    if (id.startsWith('part:')) {
      final part = moduleLoadout?.parts[id.substring(5)];
      return part != null && growthPlans.containsKey(part.partId)
          ? part.partId
          : null;
    }
    return growthPlans.containsKey(id) ? id : null;
  }

  int enh(String id) => growthEnhance[id] ?? 0;
  int evo(String id) => growthEvolve[id] ?? 0;
  bool ult(String id) => growthUltimates.contains(id);

  /// Multiplier [v] once enhance step [step] of [id] is owned.
  double gUp(String id, int step, double v) => enh(id) >= step ? v : 1;
  bool gEvo(String id, int step) => evo(id) >= step;

  /// Weapons that can grow in this run.
  List<String> get growthWeapons => [
    'gun',
    if (unifiedModules)
      for (final e in moduleLoadout!.parts.entries)
        if (e.value.definition.weapon && planKey('part:${e.key}') != null)
          'part:${e.key}',
    ...ownedPaws,
  ];

  /// Weapons and their total growth steps (for statistics and the HUD).
  Map<String, int> get growthLevels => {
    for (final id in growthWeapons)
      id: 1 + enh(id) + evo(id) + (ult(id) ? 1 : 0),
  };

  String growthIcon(String id) {
    final plan = growthPlans[planKey(id)]!;
    if (id.startsWith('part:') && plan.icon != 'icon:mortar') return id;
    return plan.icon;
  }

  /// House stages (user 2026-10-24): the main gun ('총알') and the mackerel
  /// missiles grow only from field drops, never from level-up cards.
  bool dropOnlyGrowth(String id) =>
      screenMode && (id == 'gun' || planKey(id) == 'missile_hawk');

  List<String> get missileGrowth =>
      growthWeapons.where((id) => planKey(id) == 'missile_hawk').toList();

  /// The least-grown missile bay that can still grow.
  String? get nextMissileGrowth {
    final open = missileGrowth.where((id) => !ult(id)).toList()
      ..sort((a, b) => (enh(a) + evo(a)).compareTo(enh(b) + evo(b)));
    return open.isEmpty ? null : open.first;
  }

  /// One growth step from a drop: enhance and evolve alternate, then the
  /// ultimate (with its slow-motion transformation) once both are full.
  bool dropGrowthStep(String id) {
    if (planKey(id) == null || ult(id)) return false;
    final e = enh(id), v = evo(id);
    if (e >= 3 && v >= 3) return applyGrowthChoice('ult|$id');
    return applyGrowthChoice(
      (e <= v && e < 3) || v >= 3 ? 'enh|$id' : 'evo|$id',
    );
  }

  List<UpgradeChoice> growthChoices() {
    final out = <UpgradeChoice>[];
    // v12.9 (user 2026-10-25: the same card twice in one draft): when one
    // part sits in two bays, only the less grown bay is offered.
    final offered = <String, String>{};
    for (final id in growthWeapons) {
      final key = planKey(id);
      if (key == null || ult(id) || dropOnlyGrowth(id)) continue;
      if (enh(id) >= 3 && evo(id) >= 3) continue; // its ultimate always shows
      final rival = offered[key];
      if (rival == null || enh(id) + evo(id) < enh(rival) + evo(rival)) {
        offered[key] = id;
      }
    }
    for (final id in growthWeapons) {
      final key = planKey(id);
      if (key == null || ult(id) || dropOnlyGrowth(id)) continue;
      final ready = enh(id) >= 3 && evo(id) >= 3;
      if (!ready && offered[key] != id) continue;
      final plan = growthPlans[key]!;
      final e = enh(id), v = evo(id);
      // the same part can sit in two bays: say which one
      final bay = id.startsWith('part:')
          ? '${mountProfile(id.substring(5)).name} · '
          : '';
      if (e >= 3 && v >= 3) {
        out.add(
          UpgradeChoice(
            'ult|$id',
            plan.ultimate,
            // short on the card; the long-press detail has the whole text
            '$bay${plan.ultimateText.split(' · ').first}',
            plan.ultimateIcon,
            evolution: true,
            growth: 'ult',
          ),
        );
        continue;
      }
      if (e < 3) {
        out.add(
          UpgradeChoice(
            'enh|$id',
            plan.name,
            '$bay강화 ${e + 1}/3 · ${plan.enhance[e]}',
            growthIcon(id),
            growth: 'enh',
          ),
        );
      }
      // an evolution step follows the enhance step of the same rank, so a
      // fresh weapon starts on plain enhance cards (user 2026-10-25)
      if (v < 3 && v < e) {
        out.add(
          UpgradeChoice(
            'evo|$id',
            plan.name,
            '$bay진화 ${v + 1}/3 · ${plan.evolve[v]}',
            growthIcon(id),
            growth: 'evo',
          ),
        );
      }
    }
    if (ownedPaws.length < PawWeapons.maxPawWeapons) {
      for (final paw in pawSkills) {
        if (pawLevel(paw.id) > 0) continue;
        out.add(
          UpgradeChoice(
            paw.id,
            paw.name,
            paw.description,
            paw.id,
            growth: 'new',
          ),
        );
      }
    }
    return out;
  }

  /// Full long-press text of an ultimate card (the card shows a summary).
  String? growthDetail(UpgradeChoice choice) {
    if (!choice.id.startsWith('ult|')) return null;
    final id = choice.id.substring(4);
    final key = planKey(id);
    if (key == null) return null;
    final bay = id.startsWith('part:')
        ? '${mountProfile(id.substring(5)).name} · '
        : '';
    return '$bay궁극 · ${growthPlans[key]!.ultimateText}';
  }

  /// Applies an 'enh|', 'evo|' or 'ult|' card; false for other ids.
  bool applyGrowthChoice(String choice) {
    final bar = choice.indexOf('|');
    if (bar < 0) return false;
    final kind = choice.substring(0, bar), id = choice.substring(bar + 1);
    switch (kind) {
      case 'enh':
        growthEnhance[id] = math.min(3, enh(id) + 1);
      case 'evo':
        growthEvolve[id] = math.min(3, evo(id) + 1);
      case 'ult':
        growthUltimates.add(id);
        final plan = growthPlans[planKey(id)]!;
        // the transformation beat: slow motion, a gold name banner
        ultimateBanner = plan.ultimate;
        ultimateShow = 1.6;
        onEvent?.call('transform');
        visuals.emit(
          CombatCueKind.evolution,
          position,
          source: id,
          radius: 120,
        );
        firstEvolutionAt ??= combatTime;
      default:
        return false;
    }
    _pawTimers.remove(id);
    return true;
  }

  /// A free step from a boss supply crate: the first open track.
  bool freeGrowthStep() {
    for (final id in growthWeapons) {
      if (planKey(id) == null || ult(id)) continue;
      if (enh(id) < 3) return applyGrowthChoice('enh|$id');
      if (evo(id) < 3) return applyGrowthChoice('evo|$id');
    }
    return false;
  }
}
