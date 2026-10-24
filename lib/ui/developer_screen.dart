import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'game_decor.dart';

import '../art/arcade_aircraft.dart';
import '../art/menu_art.dart';
import '../art/toon_assets.dart';
import '../data/profile.dart';
import '../data/content.dart';
import '../data/content_catalog.dart';
import '../game/developer_battle.dart';
import '../game/engine.dart';
import '../game/waves.dart';
import '../game/survival_skills.dart';
import 'components.dart';
import 'catalog_screens.dart';
import 'content_hub.dart';
import 'home.dart';
import 'battle.dart';
import 'presentation_replay_screen.dart';
import 'ship_part_editor_screen.dart';
import '../game/presentation_replay.dart';
import 'armament_hangar.dart';
import 'boss_gear_hangar.dart';
import 'collection_screen.dart';
import 'hangar_presets.dart';
import 'talent_screen.dart';
import 'fleet_activity_screen.dart';
import 'daily_challenge_screen.dart';
import 'evolution_codex.dart';
import 'item_slots.dart';

Future<void> exitDeveloperMode(BuildContext context, Profile profile) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (await profile.endDeveloperSession()) {
    navigator.popUntil((route) => route.isFirst);
  }
}

class DeveloperSessionHost extends StatelessWidget {
  const DeveloperSessionHost({super.key, required this.profile});
  final Profile profile;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return AnimatedBuilder(
      animation: profile,
      builder: (_, _) {
        final session = profile.developerSession;
        return session == null
            ? HomeScreen(key: ObjectKey(profile), profile: profile)
            : DeveloperSessionScreen(
                key: ObjectKey(session),
                source: profile,
                session: session,
              );
      },
    );
  }
}

/// Developer progress has its own storage and survives workspace navigation.
class DeveloperSessionScreen extends StatefulWidget {
  const DeveloperSessionScreen({
    super.key,
    required this.source,
    required this.session,
  });
  final Profile source;
  final Profile session;
  @override
  State<DeveloperSessionScreen> createState() => _DeveloperSessionScreenState();
}

class _DeveloperSessionScreenState extends State<DeveloperSessionScreen> {
  Profile get sandbox => widget.session;
  @override
  void dispose() {
    sandbox.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Navigator(
      observers: [AudioNavigationObserver()],
      onGenerateInitialRoutes: (_, _) => [
        MaterialPageRoute<void>(builder: (_) => HomeScreen(profile: sandbox)),
        if (sandbox.developerSettings['location'] == 'lab')
          MaterialPageRoute<void>(
            builder: (_) => DeveloperTestScreen(profile: sandbox),
          ),
      ],
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => HomeScreen(profile: sandbox)),
    );
  }
}

class DeveloperTestScreen extends StatefulWidget {
  const DeveloperTestScreen({super.key, required this.profile});
  final Profile profile;
  @override
  State<DeveloperTestScreen> createState() => _DeveloperTestScreenState();
}

class _DeveloperTestScreenState extends State<DeveloperTestScreen> {
  Profile get p => widget.profile;
  late final DeveloperBattleConfig config;
  static const menus = [
    [
      '출격 · 무기 · 기체',
      '레벨 · 주포 성장',
      '스킬 · 진화 · 시너지',
      '보스 · 편대 · 항로',
      '성능 · 연출',
      '연출 즉시 재현',
    ],
    [
      '주무기 소유·강화',
      '장비 장착·성장',
      '펫 성장·각성',
      '기술 부품',
      '영구 진화 연구',
      '아이템 직접 지급',
      '수집품',
      '출격 편성',
      '보스 전용 장비',
    ],
    ['보급·무료 구매', '일일 순환 도전', '출석·임무·보상', '시즌·우편', '무기 진화 도감'],
  ];
  static const shortMenus = [
    ['무기·기체', '레벨·주포', '스킬·시너지', '보스·편대', '성능·연출', '연출 재현'],
    ['주무기', '장비', '펫', '기술 부품', '영구 연구', '아이템 지급', '수집품', '편성', '보스 장비'],
    ['보급', '도전', '출석·보상', '시즌·우편', '진화 도감'],
  ];
  int group = 0, menu = 0, preset = 0, spec = 0, rank = 2, gearLevel = 0;
  int selectionTab = 0, stageTab = 0, encounterTab = 2;
  String? receipt;
  @override
  void initState() {
    super.initState();
    config = DeveloperBattleConfig.restore(p.developerSettings['battle']);
    if (!mainBranches.any(
      (b) =>
          b.armament == armaments[p.activeArmamentIndex].id &&
          b.branch == config.branch,
    ))
      config.branch = null;
    final ui = p.developerSettings['ui'];
    if (ui is Map) {
      int n(String k, int fallback, int max) =>
          ui[k] is int ? (ui[k] as int).clamp(0, max) : fallback;
      group = n('group', 0, 2);
      menu = n('menu', 0, menus[group].length - 1);
      preset = n('preset', 0, 6);
      spec = n('spec', 0, gearCatalog.length - 1);
      rank = n('rank', 2, 5);
      gearLevel = n('gearLevel', 0, 20 + rank * 10);
      selectionTab = n('selectionTab', 0, 3);
      stageTab = n('stageTab', 0, 1);
      encounterTab = n('encounterTab', 2, 2);
    }
    p.addListener(refresh);
    persist();
  }

  @override
  void dispose() {
    p.removeListener(refresh);
    super.dispose();
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  void persist({String location = 'lab'}) {
    p.developerSettings = {
      ...p.developerSettings,
      'location': location,
      'battle': config.toJson(),
      'ui': {
        'group': group,
        'menu': menu,
        'preset': preset,
        'spec': spec,
        'rank': rank,
        'gearLevel': gearLevel,
        'selectionTab': selectionTab,
        'stageTab': stageTab,
        'encounterTab': encounterTab,
      },
    };
    p.save();
  }

  Widget select<T>(
    String label,
    T value,
    List<(T, String)> entries,
    ValueChanged<T> onChange,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<T>(
      onTap: audible(() {}),
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      itemHeight: null,
      decoration: InputDecoration(
        labelText: tr(label),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      style: const TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
      items: [
        for (final e in entries)
          DropdownMenuItem(
            value: e.$1,
            child: Text(tr(e.$2), textAlign: TextAlign.center),
          ),
      ],
      onChanged: audibleChange((next) {
        if (next != null) {
          setState(() => onChange(next));
          persist();
        }
      }),
    ),
  );
  Widget number(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> change,
  ) => select<int>(label, value, [
    for (var i = min; i <= max; i++) (i, '$i'),
  ], change);
  Widget toggle(String label, bool value, ValueChanged<bool> change) =>
      RasterSwitchListTile(
        contentPadding: EdgeInsets.zero,
        semanticLabel: label,
        title: Text(
          tr(label),
          style: const TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
        value: value,
        onChanged: audibleChange((next) {
          setState(() => change(next));
          persist();
        }),
      );

  Future<void> launch() async {
    if (!p.developerMode) return;
    persist();
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => BattleScreen(
          profile: p,
          developerConfig: config,
          engineFactory: () => config.build(p),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    if (!p.developerMode) {
      return Scaffold(
        body: Center(
          child: Text(tr('개발자 모드가 필요합니다.'), textAlign: TextAlign.center),
        ),
      );
    }
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) persist(location: 'home');
      },
      child: Scaffold(
        appBar: GameAppBar(
          title: Text(tr('테스트'), textAlign: TextAlign.center),
          actions: [
            IconButton(
              tooltip: tr('연출 바로 재현'),
              key: const Key('developer-presentations'),
              icon: const Icon(Icons.auto_awesome, size: 28),
              onPressed: audible(
                () => setState(() {
                  group = 0;
                  menu = 5;
                  receipt = null;
                  persist();
                }),
              ),
            ),
            IconButton(
              tooltip: tr('기체 조립 편집기'),
              key: const Key('developer-ship-editor'),
              icon: const Icon(Icons.tune, size: 28),
              onPressed: audible(
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ShipPartEditorScreen(),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: tr('개발자 모드 종료 · 일반 사용자로 전환'),
              onPressed: audible(() => exitDeveloperMode(context, p)),
              icon: const Icon(Icons.lock_open, size: 28),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              if (MediaQuery.sizeOf(context).height >= 740)
                CatalogTabs(
                  labels: const ['전투', '성장', '콘텐츠'],
                  selected: group,
                  onSelected: audibleChange(
                    (i) => setState(() {
                      group = i;
                      menu = 0;
                      receipt = null;
                      persist();
                    }),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: select<int>(
                  '테스트 메뉴',
                  group * 100 + menu,
                  [
                    for (var g = 0; g < 3; g++)
                      for (var i = 0; i < menus[g].length; i++)
                        (
                          g * 100 + i,
                          '${const ['전투', '성장', '콘텐츠'][g]} / ${shortMenus[g][i]}',
                        ),
                  ],
                  (i) {
                    group = i ~/ 100;
                    menu = i % 100;
                    receipt = null;
                  },
                ),
              ),
              Expanded(
                child: group == 0 || (group == 1 && menu == 5)
                    ? content()
                    : Semantics(
                        container: true,
                        explicitChildNodes: true,
                        child: Navigator(
                          key: ValueKey('lab-$group-$menu'),
                          onGenerateRoute: (_) => MaterialPageRoute<void>(
                            builder: (_) => AnimatedBuilder(
                              animation: p,
                              builder: (_, _) => content(),
                            ),
                          ),
                        ),
                      ),
              ),
              if (group == 0 && menu != 5)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Center(
                    child: GameActionButton(
                      label: '테스트 출격',
                      primary: true,
                      icon: Icons.rocket_launch,
                      onPressed: audible(launch),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget content() {
    if (group == 0) {
      if (menu == 5) {
        return GameSlotList(
          listKey: const Key('presentation-replays'),
          children: [
            for (final kind in PresentationReplay.values)
              GameItemSlot(
                key: ValueKey('replay-${kind.name}'),
                title: kind.label.replaceFirst(' ', '\n'),
                semanticLabel: '${kind.label} 바로 재현',
                image: switch (kind) {
                  PresentationReplay.magnet => const RasterSkillIcon(
                    'magnet',
                    size: 56,
                  ),
                  PresentationReplay.boss => ToonTile(
                    'bosses',
                    p.selectedStage ~/ 10,
                    size: 56,
                  ),
                  PresentationReplay.reward => const RasterIcon(
                    Icons.card_giftcard,
                    size: 56,
                  ),
                  PresentationReplay.purchase => const RasterIcon(
                    Icons.inventory_2,
                    size: 56,
                  ),
                  PresentationReplay.damage => const RasterIcon(
                    Icons.flash_on,
                    size: 56,
                  ),
                  PresentationReplay.evolution => const RasterSkillIcon(
                    'missile',
                    size: 56,
                  ),
                  PresentationReplay.ultimate => const RasterSkillIcon(
                    'pilot',
                    size: 56,
                  ),
                  PresentationReplay.shieldCounter => const RasterSkillIcon(
                    'guardian',
                    size: 56,
                  ),
                },
                onTap: audible(
                  () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PresentationReplayScreen(source: p, kind: kind),
                    ),
                  ),
                ),
              ),
          ],
        );
      }
      if (menu == 0 || menu == 3) return selectionPanel();
      return GamePages(key: ValueKey('combat-$menu'), children: combatFields());
    }
    if (group == 1) {
      return switch (menu) {
        0 => ArmamentHangar(profile: p),
        1 => ContentHub(profile: p, showNavigation: false),
        2 => ContentHub(profile: p, initialPage: 1, showNavigation: false),
        3 => ContentHub(profile: p, initialPage: 2, showNavigation: false),
        4 => TalentScreen(profile: p),
        5 => GamePages(children: grantFields()),
        6 => CollectionScreen(profile: p),
        7 => HangarPresets(profile: p),
        _ => BossGearHangar(profile: p),
      };
    }
    return switch (menu) {
      0 => SupplyShop(profile: p),
      1 => DailyChallengeScreen(
        profile: p,
        onLaunch: (entry) async {
          await Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => BattleScreen(profile: p, dailyEntry: entry),
            ),
          );
        },
        onExchange: p.exchangeDailyChallenge,
      ),
      2 => FleetActivityScreen(profile: p),
      3 => SeasonMailbox(profile: p),
      _ => const EvolutionCodex(),
    };
  }

  List<Widget> combatFields() {
    if (menu == 0) {
      return [
        select<int>(
          '발사 특화',
          config.branch == null ? -1 : config.branch!.index,
          [
            (-1, '기본 발사'),
            for (final b in mainBranches.where(
              (b) => b.armament == armaments[p.activeArmamentIndex].id,
            ))
              (b.branch.index, b.name),
          ],
          (i) => config.branch = i < 0 ? null : MainBranch.values[i],
        ),
        select<int>('파일럿', p.selectedPilot, [
          for (var i = 0; i < pilots.length; i++) (i, pilots[i].name),
        ], p.selectPilot),
        select<int>('출격 장비', p.equipment, [
          for (var i = 0; i < equipmentOptions.length; i++)
            (i, equipmentOptions[i].name),
        ], p.selectEquipment),
      ];
    }
    if (menu == 1) {
      return [
        number('전투 시작 레벨', config.level, 1, 100, (i) => config.level = i),
        number('연사 R', config.rate, 0, 5, (i) => config.rate = i),
        number('출력 P', config.power, 0, 5, (i) => config.power = i),
        number('발사 수 N', config.count, 0, 4, (i) => config.count = i),
        number(
          '주무기 영구 강화',
          p.activeArmamentLevel,
          0,
          10,
          (i) => p.developerConfigure(armamentLevel: i),
        ),
        number(
          '파일럿 레벨',
          p.pilotLevel.clamp(0, 100),
          0,
          100,
          (i) => p.developerConfigure(pilotLevel: i),
        ),
        number(
          '영구 연구 단계',
          p.attackLevel,
          0,
          maxUpgradeLevel,
          (i) => p.developerConfigure(researchLevel: i),
        ),
        select<double>('시작 체력', config.healthPercent, const [
          (100, '100%'),
          (80, '80%'),
          (49, '49%'),
          (10, '10%'),
        ], (i) => config.healthPercent = i),
        toggle(
          '공용 궁극기 충전 완료',
          config.ultimateReady,
          (v) => config.ultimateReady = v,
        ),
        select<int>('전투 보급 아이템', config.supplyKind, const [
          (-1, '없음'),
          (0, '선체 회복'),
          (1, '자석'),
          (2, '충격파 폭탄'),
          (3, '보스 보급 상자'),
          (4, '연사 R'),
          (5, '출력 P'),
          (6, '발사 수 N'),
        ], (i) => config.supplyKind = i),
      ];
    }
    if (menu == 2) {
      return [
        select<int>(
          '빠른 빌드',
          preset,
          const [
            (0, '직접 구성'),
            (1, '정면 돌파'),
            (2, '폭발 확산'),
            (3, '방패 역습'),
            (4, '태양 기뢰'),
            (5, '전격 기뢰'),
            (6, '구급 요격대'),
          ],
          (i) {
            preset = i;
            config.preset(i);
            if (i == 1) p.selectArmament(0);
            if (i == 2) p.selectArmament(4);
          },
        ),
        Text(
          tr('공격 6 · 보조 6슬롯 유지. 아래에서 개별 단계와 진화를 지정합니다.'),
          style: TextStyle(fontSize: 16),

          textAlign: TextAlign.center,
        ),
        ...survivalSkills.where((s) => s.id != 'pilot').map((s) => skillRow(s)),
      ];
    }
    if (menu == 3) {
      return [
        number(
          '캠페인 순환',
          p.campaignLoop.clamp(0, 20),
          0,
          20,
          (i) => p.developerConfigure(loop: i),
        ),
        select<int>('교전 시작', config.scene, const [
          (0, '선택 항로 웨이브'),
          (1, '세계 보스'),
          (2, '방패·중장 편대'),
          (3, '돌입 편대'),
          (4, '일렬 편대'),
          (5, '펼침 편대'),
          (6, '성능 임시 스테이지'),
        ], (i) => config.scene = i),
        select<int>('보스 단계', config.phase, const [
          (0, '1단계'),
          (1, '2단계'),
          (2, '3단계'),
        ], (i) => config.phase = i),
        select<int>('웨이브 시작 시각', config.startSeconds, const [
          (0, '0초'),
          (30, '30초'),
          (60, '60초'),
          (90, '90초'),
          (120, '120초'),
          (150, '150초'),
        ], (i) => config.startSeconds = i),
        Text(
          tr('보스·편대는 대기 없이 시작합니다. 전투 결과는 임시 프로필에만 적용됩니다.'),
          style: TextStyle(fontSize: 16),

          textAlign: TextAlign.center,
        ),
      ];
    }
    return [
      toggle(
        'FPS · 적 · 탄환 · 효과 표시',
        config.showPerformance,
        (v) => config.showPerformance = v,
      ),
      toggle('무적', config.invincible, (v) => config.invincible = v),
      toggle('레벨업 자동 선택', config.autoChoose, (v) => config.autoChoose = v),
      toggle(
        '시각 효과 줄이기',
        p.reducedEffects,
        (v) => p.updateSettings(reducedEffects: v),
      ),
      select<double>('진행 속도', config.speed, const [
        (.5, '0.5배'),
        (1, '1배'),
        (2, '2배'),
        (4, '4배'),
      ], (i) => config.speed = i),
      select<int>('재현 시드', config.seed, const [
        (623, '623'),
        (1, '1'),
        (42, '42'),
        (20261018, '20261018'),
      ], (i) => config.seed = i),
      select<int>('초기 적 수', config.enemyCount, const [
        (0, '0'),
        (50, '50'),
        (100, '100'),
        (200, '200'),
        (260, '260'),
      ], (i) => config.enemyCount = i),
      select<int>('초기 적 탄환 수', config.shotCount, const [
        (0, '0'),
        (100, '100'),
        (200, '200'),
        (500, '500'),
        (1000, '1000'),
      ], (i) => config.shotCount = i),
      select<int>('초기 효과 수', config.sparkCount, const [
        (0, '0'),
        (80, '80'),
        (160, '160'),
      ], (i) => config.sparkCount = i),
      Center(
        child: GameActionButton(
          label: '성능 스테이지 선택',
          icon: Icons.speed,
          onPressed: audible(
            () => setState(() {
              config.scene = 6;
              receipt = '성능 부하 설정 적용 · 하단 테스트 출격';
              persist();
            }),
          ),
        ),
      ),
      if (receipt != null)
        Text(
          tr(receipt!),
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      Text(
        tr('FPS는 이 브라우저의 실시간 측정값입니다. 초기 부하는 전투 중 처치·수명에 따라 줄어듭니다.'),
        style: TextStyle(fontSize: 16),

        textAlign: TextAlign.center,
      ),
    ];
  }

  void choose(VoidCallback change) {
    setState(change);
    persist();
  }

  Widget selectionPanel() {
    final encounter = menu == 3;
    final tab = encounter ? encounterTab : selectionTab;
    final stages = !encounter && tab == 2;
    return Column(
      children: [
        CatalogTabs(
          tight: true,
          labels: encounter
              ? const ['세계', '항로', '교전']
              : const ['무기', '기체', '항로', '설정'],
          selected: tab,
          onSelected: audibleChange(
            (i) => choose(() {
              if (encounter) {
                encounterTab = i;
              } else {
                selectionTab = i;
              }
            }),
          ),
        ),
        if (stages)
          CatalogTabs(
            tight: true,
            labels: const ['세계', '세부 항로'],
            selected: stageTab,
            onSelected: audibleChange((i) => choose(() => stageTab = i)),
          ),
        Expanded(
          child: (!encounter && tab == 3) || (encounter && tab == 2)
              ? GamePages(
                  key: ValueKey('combat-settings-$menu'),
                  children: combatFields(),
                )
              : slotChoices(
                  encounter
                      ? tab + 2
                      : stages
                      ? stageTab + 2
                      : tab,
                ),
        ),
      ],
    );
  }

  Widget slotChoices(int category) => GameSlotList(
    listKey: ValueKey('test-selection-$category'),
    children: [
      if (category == 0)
        for (var i = 0; i < armaments.length; i++)
          GameItemSlot(
            key: ValueKey('test-weapon-$i'),
            title: armaments[i].name,
            semanticLabel: '주무기 ${armaments[i].name}',
            image: weaponPicture(i),
            selected: p.activeArmamentIndex == i,
            status: p.activeArmamentIndex == i ? '선택 중' : '',
            onTap: audible(
              () => choose(() {
                p.selectArmament(i);
                config.branch = null;
                preset = 0;
              }),
            ),
          ),
      if (category == 1)
        for (var i = 0; i < ships.length; i++)
          GameItemSlot(
            key: ValueKey('test-ship-$i'),
            title: ships[i].name,
            semanticLabel: '비행기 ${ships[i].name}',
            image: ArcadeAircraft(shipIndex: i, size: 56),
            selected: p.selectedShip == i,
            status: p.selectedShip == i ? '선택 중' : '',
            onTap: audible(() => choose(() => p.selectShip(i))),
          ),
      if (category == 2)
        for (var i = 0; i < worlds.length; i++)
          GameItemSlot(
            key: ValueKey('test-world-$i'),
            title: worlds[i].name,
            semanticLabel: '세계 ${worlds[i].name}',
            image: ToonTile('worlds', i, size: 56),
            selected: p.selectedStage ~/ 10 == i,
            status: p.selectedStage ~/ 10 == i ? '선택 중' : '${i + 1}세계',
            onTap: audible(
              () => choose(() => p.selectStage(i * 10 + p.selectedStage % 10)),
            ),
          ),
      if (category == 3)
        for (var i = 0; i < 10; i++)
          GameItemSlot(
            key: ValueKey('test-route-$i'),
            title: routeWavePlans[i].name,
            semanticLabel: '항로 ${i + 1} ${routeWavePlans[i].name}',
            image: Stack(
              alignment: Alignment.center,
              children: [
                ToonTile('worlds', p.selectedStage ~/ 10, size: 56),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  color: const Color(0xCC142139),
                  child: Text(
                    message("{0}-{1}", [p.selectedStage ~/ 10 + 1, i + 1]),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),

                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            selected: p.selectedStage % 10 == i,
            status: p.selectedStage % 10 == i
                ? '${i + 1}항로 · 선택 중'
                : '${i + 1}항로',
            onTap: audible(
              () => choose(() => p.selectStage(p.selectedStage ~/ 10 * 10 + i)),
            ),
          ),
    ],
  );

  // Existing weapon/effect PNGs describe the firing family without new assets.
  Widget weaponPicture(int i) => Stack(
    alignment: Alignment.center,
    children: [
      MenuImage(
        'game/${const ['pulse', 'missile', 'boomerang', 'impact', 'gear-gun', 'laser', 'boomerang', 'ring', 'boomerang', 'drill'][i]}',
        size: 56,
      ),
      if ([6, 8, 9].contains(i))
        Positioned(
          right: 0,
          bottom: 0,
          child: MenuImage(
            'game/${i == 6
                ? 'lightning'
                : i == 8
                ? 'fire'
                : 'ring'}',
            size: 28,
          ),
        ),
    ],
  );

  Widget skillRow(SurvivalSkill s) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      select<int>(
        s.name,
        config.skills[s.id] ?? 0,
        [for (var i = 0; i <= 5; i++) (i, i == 0 ? '미장착' : 'Lv.$i')],
        (i) {
          final same = config.skills.keys
              .where((id) => skillFor(id).passive == s.passive && id != 'gun')
              .length;
          if (i > 0 &&
              !config.skills.containsKey(s.id) &&
              s.id != 'gun' &&
              same >= 6) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  tr('같은 분류는 최대 6슬롯입니다.'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
            return;
          }
          if (i == 0) {
            config.skills.remove(s.id);
            config.evolutions.remove(s.id);
          } else {
            config.skills[s.id] = i;
          }
        },
      ),
      if (!s.passive && s.evolution != null && (config.skills[s.id] ?? 0) > 0)
        toggle('${s.name} 진화', config.evolutions.contains(s.id), (v) {
          if (v) {
            config.evolutions.add(s.id);
            config.skills[s.id] = 5;
          } else {
            config.evolutions.remove(s.id);
          }
        }),
    ],
  );

  List<Widget> grantFields() => [
    Center(
      child: GameActionButton(
        label: '보상 조건 충족',
        icon: Icons.card_giftcard,
        onPressed: audible(() {
          p.developerRewardConditions();
          setState(() => receipt = '임시 프로필의 출석·임무·시즌·항로 보상을 열었습니다.');
        }),
      ),
    ),
    select<int>('장비', spec, [
      for (var i = 0; i < gearCatalog.length; i++) (i, gearCatalog[i].name),
    ], (i) => spec = i),
    select<int>('등급', rank, [
      for (var i = 0; i < qualityNames.length; i++) (i, qualityNames[i]),
    ], (i) => rank = i),
    number(
      '장비 레벨',
      gearLevel.clamp(0, 20 + rank * 10),
      0,
      20 + rank * 10,
      (i) => gearLevel = i,
    ),
    Center(
      child: GameActionButton(
        label: '장비 지급·장착',
        primary: true,
        icon: Icons.inventory_2,
        onPressed: audible(() {
          final g = p.developerGear(spec, rank, gearLevel);
          if (g != null) {
            p.equipItem(g.id);
            setState(() => receipt = '${g.definition.name} 장착 완료');
          }
        }),
      ),
    ),
    if (receipt != null)
      Text(
        tr(receipt!),
        style: const TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
      ),
    number(
      '기술 부품 등급',
      p.techRank(0),
      -1,
      5,
      (i) => p.developerConfigure(techLevel: i),
    ),
    number(
      '펫 등급',
      p.petRanks[0],
      0,
      5,
      (i) => p.developerConfigure(petRank: i),
    ),
    number(
      '펫 레벨',
      p.petLevels[0],
      1,
      20 + p.petRanks[0] * 10,
      (i) => p.developerConfigure(petLevel: i),
    ),
    number(
      '펫 각성',
      p.petBond.awakening[0],
      0,
      3,
      (i) => p.developerConfigure(petAwakening: i),
    ),
  ];
}
