import '../l10n/app_language.dart';
import '../data/ship_modules.dart';

import 'audio_feedback.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/game_icons.dart';
import '../art/ship_sprite_art.dart';
import '../art/toon_assets.dart';
import '../art/ui_kit.dart';
import 'skill_cards.dart';
import 'game_motion.dart';
import 'game_decor.dart';

import '../data/content.dart';
import '../game/engine.dart';
import '../game/survival_skills.dart';
import '../main.dart';
import 'components.dart';

@immutable
class DamageContribution {
  const DamageContribution(
    this.source,
    this.label,
    this.damage,
    this.share,
    this.dps,
  );
  final String source, label;
  final double damage, share, dps;
}

/// Uses actual health removed, as recorded by GameEngine; no estimated damage.
@immutable
class BattleDamageSummary {
  const BattleDamageSummary._(
    this.entries,
    this.totalDamage,
    this.combatSeconds,
  );
  final List<DamageContribution> entries;
  final double totalDamage, combatSeconds;
  double get dps => combatSeconds > 0 ? totalDamage / combatSeconds : 0;

  factory BattleDamageSummary.from(
    Map<String, double> damage,
    double combatSeconds, {
    String Function(String)? labelFor,
  }) {
    final seconds = combatSeconds.isFinite && combatSeconds > 0
        ? combatSeconds
        : 0.0;
    final valid =
        damage.entries
            .where(
              (e) => e.key.trim().isNotEmpty && e.value.isFinite && e.value > 0,
            )
            .toList()
          ..sort((a, b) {
            final byDamage = b.value.compareTo(a.value);
            return byDamage == 0 ? a.key.compareTo(b.key) : byDamage;
          });
    final largest = valid.isEmpty ? 0.0 : valid.first.value;
    // Normalize before summing so shares remain valid even for extreme input.
    final weight = valid.fold<double>(0, (sum, e) => sum + e.value / largest);
    final total = valid.fold<double>(0, (sum, e) => sum + e.value);
    return BattleDamageSummary._(
      List.unmodifiable([
        for (final e in valid)
          DamageContribution(
            e.key,
            labelFor?.call(e.key) ?? '기타 공격',
            e.value,
            (total.isFinite ? e.value / total : e.value / largest / weight)
                .clamp(0, 1),
            seconds > 0 ? e.value / seconds : 0,
          ),
      ]),
      total,
      seconds,
    );
  }
}

@immutable
class BattleBuildEntry {
  const BattleBuildEntry({
    required this.id,
    required this.name,
    required this.rank,
    required this.evolved,
    required this.recipe,
  });
  final String id, name, recipe;
  final int rank;
  final bool evolved;
}

/// v12.16 one mounted part of the craft (weapon bay or gear piece): its
/// picture, level (weapons) and whether it has merged back in flight.
@immutable
class BattlePartEntry {
  const BattlePartEntry({
    required this.id,
    required this.name,
    required this.attached,
    this.part,
    this.asset,
    this.level = 0,
  });
  final String id, name;
  final bool attached;
  final ModulePart? part;
  final String? asset;
  final int level;
}

/// Frozen at opening: the result remains available until the user retries/exits.
@immutable
class BattleStatisticsSnapshot {
  const BattleStatisticsSnapshot._({
    required this.damage,
    required this.weapons,
    required this.passives,
    required this.armament,
    required this.pilot,
    required this.pilotRank,
    required this.mainRate,
    required this.mainPower,
    required this.mainCount,
    required this.finished,
    required this.synergies,
    required this.ultimate,
    required this.armamentLevel,
    required this.mainLoadout,
    this.shipIndex = 0,
    this.shipName = '',
    this.airframeLevel = 1,
    this.attackPercent = 100,
    this.maxHp = 0,
    this.pickupRadius = 0,
    this.parts = const [],
    this.mainGunName = '',
    this.mainGunLevel = 1,
    this.ultimateKind = -1,
    this.ultimateName = '',
    this.ultimateCharge = 0,
  });
  final BattleDamageSummary damage;
  final List<BattleBuildEntry> weapons, passives;
  final String armament, pilot;
  final int pilotRank, mainRate, mainPower, mainCount, armamentLevel;
  final bool finished;
  final List<String> synergies;
  final String ultimate;
  final String mainLoadout;

  /// v12.16 item view of the build (craft card, parts, main gun, ultimate).
  final int shipIndex, airframeLevel, attackPercent, mainGunLevel;
  final int ultimateKind;
  final String shipName, mainGunName, ultimateName;
  final double maxHp, pickupRadius, ultimateCharge;
  final List<BattlePartEntry> parts;

  factory BattleStatisticsSnapshot.fromGame(GameEngine game) {
    final armament =
        armaments.where((a) => a.id == game.armament).firstOrNull?.name ??
        '장착 주무장';
    final pilot =
        pilots.where((p) => p.id == game.pilot).firstOrNull?.name ?? '조종사';
    List<BattleBuildEntry> build(Map<String, int> entries) =>
        List.unmodifiable([
          for (final entry in entries.entries.where((e) => e.value > 0))
            // a weapon bay still shed in flight is not held yet
            if (!entry.key.startsWith('part:') ||
                game.partAttached(entry.key.substring(5)))
              _buildEntry(game, entry.key, entry.value, armament, pilot),
        ]);
    return BattleStatisticsSnapshot._(
      synergies: List.unmodifiable(game.synergyDetails),
      ultimate: game.ultimateDescription,
      damage: BattleDamageSummary.from(
        game.damageByWeapon,
        game.combatTime,
        labelFor: (source) => source == 'common-ultimate' && game.unifiedModules
            ? game.moduleLoadout!.ultimateName
            : damageSourceLabel(source, armament: armament, pilot: pilot),
      ),
      weapons: build(game.unifiedModules ? game.growthLevels : game.upgrades),
      passives: build(game.passives),
      armament: armament,
      armamentLevel: game.armamentLevel,
      mainLoadout: game.mainLoadoutDescription,
      pilot: pilot,
      pilotRank: game.pilotSkillLevel,
      mainRate: game.mainRate,
      mainPower: game.mainPower,
      mainCount: game.mainCount,
      finished: game.finished,
      shipIndex: game.shipIndex,
      shipName: ships[game.shipIndex.clamp(0, ships.length - 1)].name,
      airframeLevel: game.moduleLoadout?.airframeLevel ?? 1,
      attackPercent: (game.damageFactor * 100).round(),
      maxHp: game.maxHp,
      pickupRadius: game.collectionRadius,
      parts: _parts(game),
      mainGunName: growthPlans[game.planKey('gun')]?.name ?? armament,
      mainGunLevel: game.growthLevels['gun'] ?? 1,
      ultimateKind: game.hasCommonUltimate ? game.ultimateKind : -1,
      ultimateName: game.hasCommonUltimate ? game.ultimateName : '',
      ultimateCharge: game.ultimateCharge,
    );
  }

  /// Gear pieces use their equipped sprite (or the shared default one).
  static const _gearFiles = {
    'nose': 'nose',
    'armor': 'armor',
    'wings': 'wing_left',
    'engines': 'engine_left',
  };

  static List<BattlePartEntry> _parts(GameEngine game) {
    final loadout = game.moduleLoadout;
    if (loadout == null) return const [];
    return List.unmodifiable([
      for (final id in InFlightAssembly.order)
        if (InFlightAssembly.gearParts.contains(id))
          BattlePartEntry(
            id: id,
            name: InFlightAssembly.names[id]!,
            attached: game.partAttached(id),
            asset:
                ShipSpriteArt.battleAssets[InFlightAssembly
                    .layers[id]!
                    .first] ??
                'assets/art/ship_parts/sunshine/${_gearFiles[id]}.webp',
          )
        else if (loadout.parts[id] case final owned?)
          BattlePartEntry(
            id: id,
            name: InFlightAssembly.names[id]!,
            attached: game.partAttached(id),
            part: owned.definition,
            level: owned.level,
          ),
    ]);
  }

  static BattleBuildEntry _buildEntry(
    GameEngine game,
    String id,
    int rank,
    String armament,
    String pilot,
  ) {
    final skill = survivalSkills.where((s) => s.id == id).firstOrNull;
    final evo = game.evolved.contains(id);
    final name = id == 'gun'
        ? armament
        : id == 'pilot'
        ? '$pilot 고유 모듈'
        : id.startsWith('part:') && game.unifiedModules
        ? game.combatSkill(id).name
        : (evo ? skill?.evolution : null) ?? skill?.name ?? '기타 모듈';
    final recipe = id == 'gun'
        ? '보급 R 3 · P 3 · N 2 → 주포 독립 진화'
        : game.unifiedModules && id.startsWith('part:')
        ? game.evolutionHint(id)
        : skill == null
        ? '진화 정보 없음'
        : evo
        ? '진화 완료 · ${skill.recipeHint ?? skill.name}'
        : game.evolutionHint(id);
    return BattleBuildEntry(
      id: id,
      name: name,
      rank: rank,
      evolved: evo,
      recipe: [
        recipe,
        if (game.weaponRoleLabel(id).isNotEmpty) game.weaponRoleLabel(id),
      ].join('\n'),
    );
  }
}

String damageSourceLabel(
  String source, {
  required String armament,
  required String pilot,
}) {
  if (source.startsWith('part:')) {
    final bits = source.split(':');
    if (bits.length == 3 && moduleParts.any((p) => p.id == bits[2]))
      return '${bits[1]} · ${modulePart(bits[2]).name}';
  }
  if (source == 'gun' || source == 'module-main') return armament;
  if (source == 'primary') return '$armament · 추적탄';
  const extras = {
    'gear-seeker': '유성 추적 로켓',
    'ult-missile': '생선 미사일 폭풍',
    'module-auxiliary': '회전 포탑',
    'module-wings': '날개 포드',
    'module-rear': '후방 방어포',
    'module-ground': '지상 폭격창',
    'pet': '펫 지원',
    'bomb': '전장 폭탄',
    'status': '지속 상태 피해',
    'void': '공허 투사기',
    'soul': '영혼 추적검',
    'sword-array': '광자 검진',
    'starforge': '성창 · 빛 고리',
    'havoc': '성창 · 어둠 찌르기',
    'fissure': '성창 · 균열',
    'lance': '성창 · 관통',
    'inferno': '태양 기뢰 · 화염',
    'spike': '가시 위성 · 파편',
    'synergy-explosive': '폭발 확산 · 유도 파편',
    'common-ultimate': '항성포 · 필살기',
  };
  if (extras.containsKey(source)) return extras[source]!;
  const pilotSources = {
    'pilot-active',
    'medic',
    'bug',
    'emp',
    'pistol',
    'palm',
    'element',
    'funnel',
    'blood',
    'shield-counter',
    'divine-fire',
    'forge',
    'illusion',
    'moon',
    'weakpoint',
    'sync',
    'mech',
    'adrenaline',
  };
  if (pilotSources.contains(source)) return '$pilot · 고유 능력';
  final evo = source.endsWith('-evo');
  final id = evo ? source.substring(0, source.length - 4) : source;
  final skill = survivalSkills.where((s) => s.id == id).firstOrNull;
  return (evo ? skill?.evolution : null) ?? skill?.name ?? '기타 공격';
}

class BattleStatisticsDialog extends StatelessWidget {
  const BattleStatisticsDialog({super.key, required this.snapshot});
  final BattleStatisticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(10),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: PopIn(
        child: UiKitFrame(
          'panel',
          corner: 26,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
          child: SizedBox(
            width: 460,
            height: math.min(680, MediaQuery.sizeOf(context).height - 48),
            // v12.16 (user 2026-10-27): the build opens first; both tabs are
            // pictures and numbers, no sentences.
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Row(
                    children: [
                      const MascotImage(Mascot.stats, size: 62),
                      const Expanded(
                        child: Center(
                          child: RibbonTitle(
                            '전투 통계',
                            width: 300,
                            height: 54,
                            size: 22,
                          ),
                        ),
                      ),
                      KitCloseButton(
                        key: const Key('close-battle-statistics'),
                        tooltip: '통계 닫기',
                        onPressed: audible(() => Navigator.of(context).pop()),
                      ),
                    ],
                  ),
                  TabBar(
                    onTap: audibleChange((_) {}),
                    indicatorColor: const Color(0xFFFFB627),
                    labelColor: const Color(0xFFFFD447),
                    tabs: const [
                      Tab(text: '현재 빌드'),
                      Tab(text: '피해 기여'),
                    ],
                  ),
                  Expanded(child: TabBarView(children: [_build(), _damage()])),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _damage() => GameItemList(
    key: const Key('battle-damage-scroll'),
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _statTile(
                GameIcons.hourglass,
                '전투 시간',
                message('{0}초', [
                  snapshot.damage.combatSeconds.toStringAsFixed(1),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statTile(
                GameIcons.bolt,
                '평균 DPS',
                _number(snapshot.damage.dps),
              ),
            ),
          ],
        ),
        gap(12),
        if (snapshot.damage.entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Opacity(
                opacity: .45,
                child: GameIconImage(GameIcons.crosshair, size: 48),
              ),
            ),
          ),
        for (final (i, entry) in snapshot.damage.entries.indexed)
          StaggerIn(index: i, child: _damageRow(i, entry)),
      ],
    ),
  );

  /// One weapon: its picture, name, a bar that fills in and the damage.
  /// The top dealer wears the crown.
  Widget _damageRow(int i, DamageContribution entry) {
    final art = damageArt(entry.label);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: UiKitFrame(
        'slot',
        corner: 14,
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                art != null
                    ? Image.asset(art, width: 44, height: 44)
                    : const SizedBox.square(dimension: 44),
                if (i == 0)
                  Positioned(
                    top: -14,
                    left: -6,
                    child: Transform.rotate(
                      angle: -.3,
                      child: Image.asset(
                        'assets/art/menu_v13/trophy_bosses.webp',
                        width: 28,
                        height: 28,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tr(entry.label),
                      maxLines: 1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  gap(4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: entry.share),
                    duration: Duration(milliseconds: 700 + i * 90),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => RasterGauge(
                      key: ValueKey('damage-share-${entry.source}'),
                      value: value,
                      minHeight: 10,
                      color: i == 0 ? const Color(0xFFFFB627) : cyan,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 64,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _number(entry.damage),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: i == 0 ? const Color(0xFFFFD447) : Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build() => GameItemList(
    key: const Key('battle-build-scroll'),
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _craftCard(),
        if (snapshot.parts.isNotEmpty) ...[gap(10), _partsRow()],
        gap(10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _mainGun()),
            if (snapshot.ultimateKind >= 0) ...[
              const SizedBox(width: 8),
              Expanded(child: _ultimate()),
            ],
          ],
        ),
        gap(14),
        const _Heading('보유 무기'),
        gap(8),
        _slotGrid(snapshot.weapons.where((e) => e.id != 'gun').toList()),
        gap(14),
        const _Heading('보유 보조 스킬'),
        gap(8),
        _slotGrid(snapshot.passives),
      ],
    ),
  );

  /// The cat's craft: its sprite, name, level and three stats.
  Widget _craftCard() => UiKitFrame(
    'slot',
    corner: 16,
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
    child: Row(
      children: [
        SizedBox.square(
          dimension: 72,
          child: ShipSprite(hull: snapshot.shipIndex),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tr(snapshot.shipName),
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _LvBadge('Lv.${snapshot.airframeLevel}'),
                ],
              ),
              gap(6),
              Row(
                children: [
                  Expanded(
                    child: _miniStat(
                      GameIcons.crosshair,
                      '${snapshot.attackPercent}%',
                      '공격력',
                    ),
                  ),
                  Expanded(
                    child: _miniStat(
                      GameIcons.heart,
                      snapshot.maxHp.round().toString(),
                      '체력',
                    ),
                  ),
                  Expanded(
                    child: _miniStat(
                      GameIcons.magnet,
                      snapshot.pickupRadius.round().toString(),
                      '흡수 범위',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// Mounted parts in one row; a part still shed in flight is dim + locked.
  Widget _partsRow() => LayoutBuilder(
    builder: (context, box) {
      final n = snapshot.parts.length;
      final side = math.min(54.0, (box.maxWidth - 6 * (n - 1)) / n);
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _partSlot(snapshot.parts[i], side),
          ],
        ],
      );
    },
  );

  Widget _partSlot(BattlePartEntry e, double side) => Tooltip(
    message: tr(e.name),
    child: Semantics(
      label:
          '${tr(e.name)}${e.level > 0 ? ' Lv.${e.level}' : ''}'
          '${e.attached ? '' : ' ${tr('분리됨')}'}',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: side,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: e.attached ? 1 : .4,
                child: ToonRarityFrame(
                  rank: e.part == null ? 0 : 2,
                  child: Padding(
                    padding: EdgeInsets.all(side * .14),
                    child: e.part != null
                        ? ShipSpriteArt.partSprite(e.part!, side, mount: e.id)
                        : GameIconImage(e.asset!, size: side),
                  ),
                ),
              ),
            ),
            // a small corner lock keeps the dimmed part recognisable
            if (!e.attached)
              Positioned(
                left: -4,
                top: -4,
                child: GameIconImage(GameIcons.lock, size: side * .36),
              ),
            if (e.level > 0)
              Positioned(
                right: -3,
                bottom: -3,
                child: _LvBadge('${e.level}', small: true),
              ),
          ],
        ),
      ),
    ),
  );

  /// The cat's own main gun: picture, level and its three drop stats.
  Widget _mainGun() => UiKitFrame(
    'slot',
    corner: 14,
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
    child: Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Image.asset(
              'assets/art/ship_parts/${ShipSpriteArt.shipIds[snapshot.shipIndex.clamp(0, 2)]}/maingun.webp',
              width: 52,
              height: 52,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
            Positioned(
              right: -10,
              bottom: -4,
              child: _LvBadge('Lv.${snapshot.mainGunLevel}', small: true),
            ),
          ],
        ),
        gap(4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            tr(snapshot.mainGunName),
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
        gap(4),
        Row(
          children: [
            Expanded(
              child: _miniStat(
                GameIcons.fastForward,
                '${snapshot.mainRate}',
                '연사',
              ),
            ),
            Expanded(
              child: _miniStat(GameIcons.bolt, '${snapshot.mainPower}', '출력'),
            ),
            Expanded(
              child: _miniStat(
                GameIcons.crosshair,
                '${snapshot.mainCount + 1}',
                '발사 수',
              ),
            ),
          ],
        ),
      ],
    ),
  );

  /// The airframe ultimate: the cat's emblem, its name and the charge.
  Widget _ultimate() {
    final full = snapshot.ultimateCharge >= 100;
    return UiKitFrame(
      'slot',
      corner: 14,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        children: [
          Opacity(
            opacity: full ? 1 : .6,
            child: GameIconImage(
              CommonUltimate.ultimateAssets[snapshot.ultimateKind.clamp(0, 2)],
              size: 52,
            ),
          ),
          gap(4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              tr(snapshot.ultimateName),
              maxLines: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
          gap(6),
          KitGauge((snapshot.ultimateCharge / 100).clamp(0.0, 1.0)),
          gap(2),
          Text(
            '${snapshot.ultimateCharge.floor()}%',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: full ? GameTone.gold.color : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  /// The mounted part behind a 'part:W1' weapon skill, if any.
  BattlePartEntry? _bayPart(String id) => id.startsWith('part:')
      ? snapshot.parts
            .where((p) => p.id == id.substring(5) && p.part != null)
            .firstOrNull
      : null;

  /// Owned skills as picture slots with their step badge; the details are
  /// the long-press tooltip (mobile inventory grid).
  Widget _slotGrid(List<BattleBuildEntry> entries) => entries.isEmpty
      ? Center(
          child: Opacity(
            opacity: .45,
            child: GameIconImage(GameIcons.lock, size: 40),
          ),
        )
      : Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in entries)
              Tooltip(
                message: '${tr(e.name)}\n${tr(e.recipe)}',
                child: SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      SizedBox.square(
                        dimension: 64,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: ToonRarityFrame(
                                rank: e.evolved ? 4 : (e.rank >= 3 ? 2 : 0),
                                child: Padding(
                                  padding: const EdgeInsets.all(9),
                                  child: switch (_bayPart(e.id)) {
                                    final bay? => ShipSpriteArt.partSprite(
                                      bay.part!,
                                      46,
                                      mount: bay.id,
                                    ),
                                    _ => RasterSkillIcon(e.id, size: 46),
                                  },
                                ),
                              ),
                            ),
                            Positioned(
                              right: -3,
                              bottom: -3,
                              child: _LvBadge(
                                e.evolved ? 'EVO' : 'Lv.${e.rank}',
                                small: true,
                                evo: e.evolved,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          // a weapon bay drops its 'W1 · ' prefix under the picture
                          tr(_bayPart(e.id)?.part?.name ?? e.name),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
}

/// A centred section heading in the build tab.
class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    tr(text),
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
    textAlign: TextAlign.center,
  );
}

/// A dark pill with a gold level (or green EVO) label.
class _LvBadge extends StatelessWidget {
  const _LvBadge(this.text, {this.small = false, this.evo = false});
  final String text;
  final bool small, evo;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xE60B1830),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: evo ? GameTone.good.color : GameTone.gold.color,
        width: 1.5,
      ),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: small ? 5 : 8, vertical: 1),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: evo ? GameTone.good.color : GameTone.gold.color,
          fontSize: small ? GameUi.minimumLabel : GameUi.caption,
          height: 1.2,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

/// A picture over a number (the stat name is the tooltip/screen reader).
Widget _miniStat(String asset, String value, String label) => Semantics(
  label: '${tr(label)} $value',
  excludeSemantics: true,
  child: Tooltip(
    message: tr(label),
    child: Column(
      children: [
        GameIconImage(asset, size: 24),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  ),
);

/// A wide icon tile: picture, label and a big number.
Widget _statTile(String asset, String label, String value) => UiKitFrame(
  'slot',
  corner: 14,
  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      GameIconImage(asset, size: 32),
      const SizedBox(width: 6),
      Flexible(
        child: Column(
          children: [
            Text(
              tr(label),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GameTone.muted.color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);

String _number(double value) {
  if (!value.isFinite) return '표시 범위 초과';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 10000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toStringAsFixed(1);
}

/// The card illustration for a damage source, by its weapon name.
String? damageArt(String label) {
  const art = [
    ('발칸', 'vulcan'),
    ('자주포', 'mortar'),
    ('통통 공', 'bounce'),
    ('반달', 'crescent'),
    ('레이저', 'laser'),
    ('펀치', 'orbit'),
    ('털실', 'yarn'),
    ('번개', 'zap'),
    ('포탑', 'ult_vulcan'),
    ('폭격', 'ult_mortar'),
    ('위성', 'ult_laser'),
    ('천둥', 'ult_zap'),
  ];
  for (final (word, name) in art) {
    if (label.contains(word)) return '${SkillCardArt.root}$name.webp';
  }
  if (label.contains('주포')) return 'assets/art/menu_v13/launch.webp';
  if (label.contains('미사일') || label.contains('로켓')) {
    return GameIcons.missile;
  }
  if (label.contains('펫')) return 'assets/art/pets_v14/pet_0.webp';
  return null;
}
