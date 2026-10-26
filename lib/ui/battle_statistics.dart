import '../l10n/app_language.dart';
import '../data/ship_modules.dart';

import 'audio_feedback.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/game_icons.dart';
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
  });
  final BattleDamageSummary damage;
  final List<BattleBuildEntry> weapons, passives;
  final String armament, pilot;
  final int pilotRank, mainRate, mainPower, mainCount, armamentLevel;
  final bool finished;
  final List<String> synergies;
  final String ultimate;
  final String mainLoadout;

  factory BattleStatisticsSnapshot.fromGame(GameEngine game) {
    final armament =
        armaments.where((a) => a.id == game.armament).firstOrNull?.name ??
        '장착 주무장';
    final pilot =
        pilots.where((p) => p.id == game.pilot).firstOrNull?.name ?? '조종사';
    List<BattleBuildEntry> build(Map<String, int> entries) =>
        List.unmodifiable([
          for (final entry in entries.entries.where((e) => e.value > 0))
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
    );
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
    'common-ultimate': '공용 궁극기 · 항성포',
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
                  Text(
                    tr(
                      snapshot.finished
                          ? '이번 출격의 최종 기록'
                          : '일시정지 중 · 이번 출격의 현재 기록',
                    ),
                    style: const TextStyle(color: muted, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  TabBar(
                    onTap: audibleChange((_) {}),
                    indicatorColor: const Color(0xFFFFB627),
                    labelColor: const Color(0xFFFFD447),
                    tabs: const [
                      Tab(text: '피해 기여'),
                      Tab(text: '현재 빌드'),
                    ],
                  ),
                  Expanded(child: TabBarView(children: [_damage(), _build()])),
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
        CountUp(
          key: const Key('battle-total-damage'),
          value: snapshot.damage.totalDamage,
          format: (v) => message("누적 피해 {0}", [_number(v)]),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFFFFE27A),
            shadows: [Shadow(color: Color(0xFF3A1A06), offset: Offset(0, 2))],
          ),
        ),
        gap(8),
        GameFactRow([
          GameFact(
            '전투 시간',
            message('{0}초', [snapshot.damage.combatSeconds.toStringAsFixed(1)]),
          ),
          GameFact('평균 DPS', _number(snapshot.damage.dps), tone: GameTone.gold),
        ]),
        gap(6),
        const GameHint('DPS = 피해 ÷ 전투 시간'),
        gap(12),
        if (snapshot.damage.entries.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              tr('아직 가한 피해가 없습니다. 전투 후 다시 확인하세요.'),
              textAlign: TextAlign.center,
            ),
          ),
        for (final (i, entry) in snapshot.damage.entries.indexed)
          StaggerIn(index: i, child: _damageRow(i, entry)),
      ],
    ),
  );

  /// One weapon: its card art, name, a bar that fills in, share and DPS.
  /// The top dealer wears the crown.
  Widget _damageRow(int i, DamageContribution entry) {
    final art = damageArt(entry.label);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: UiKitFrame(
        'slot',
        corner: 14,
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 10),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                art != null
                    ? Image.asset(art, width: 48, height: 48)
                    : const SizedBox.square(dimension: 48),
                if (i == 0)
                  Positioned(
                    top: -14,
                    left: -6,
                    child: Transform.rotate(
                      angle: -.3,
                      child: Image.asset(
                        'assets/art/menu_v13/trophy_bosses.webp',
                        width: 30,
                        height: 30,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(entry.label),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Text(
                        message("{0}%", [
                          (entry.share * 100).toStringAsFixed(1),
                        ]),
                        style: const TextStyle(
                          color: Color(0xFFFFD447),
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
                  gap(4),
                  Row(
                    children: [
                      Expanded(child: _rowFact('피해', _number(entry.damage))),
                      Expanded(child: _rowFact('DPS', _number(entry.dps))),
                    ],
                  ),
                ],
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
        // v12.14: labelled groups and fact tiles instead of six lines of
        // "영구 강화 … · 주무기 피해 …" text in one colour.
        GameInfoBlock(
          label: '주무장',
          lead: snapshot.armament,
          children: [
            const SizedBox(height: 6),
            GameFactRow([
              GameFact(
                '영구 강화',
                '${snapshot.armamentLevel}/10',
                tone: GameTone.gold,
              ),
              GameFact(
                '주무기 피해',
                '+${snapshot.armamentLevel * 2}%',
                tone: GameTone.good,
              ),
            ]),
          ],
        ),
        gap(8),
        GameFactRow([
          GameFact('R 연사', '${snapshot.mainRate}/5'),
          GameFact('P 출력', '${snapshot.mainPower}/5'),
          GameFact('N 발사', '${snapshot.mainCount}/4'),
          GameFact(
            '탄 수',
            message('{0}발', [snapshot.mainCount + 1]),
            tone: GameTone.gold,
          ),
        ]),
        gap(8),
        GameInfoBlock(
          label: '조종사',
          tone: GameTone.sky,
          lead: snapshot.pilot,
          children: [
            const SizedBox(height: 4),
            Center(
              child: GameTag(
                message('고유 모듈 {0}단계', [snapshot.pilotRank]),
                tone: GameTone.sky,
              ),
            ),
          ],
        ),
        gap(8),
        // v12.15: loadout, ultimate and synergies as tags, not paragraphs
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final line in snapshot.mainLoadout.split('\n'))
              if (line.trim().isNotEmpty)
                GameTag(line.trim(), tone: GameTone.sky),
            for (final line in snapshot.ultimate.split('\n'))
              if (line.trim().isNotEmpty) GameTag(line.trim()),
            for (final detail in snapshot.synergies)
              for (final (i, line) in detail.split('\n').indexed)
                if (line.trim().isNotEmpty)
                  GameTag(
                    line.trim(),
                    tone: i == 0 ? GameTone.good : GameTone.muted,
                  ),
          ],
        ),
        gap(16),
        Text(
          tr('보유 무기'),
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),

          textAlign: TextAlign.center,
        ),
        gap(8),
        _slotGrid(snapshot.weapons),
        gap(14),
        Text(
          tr('보유 보조 스킬'),
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),

          textAlign: TextAlign.center,
        ),
        if (snapshot.passives.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              tr('아직 보조 스킬이 없습니다.'),
              style: TextStyle(color: muted),
              textAlign: TextAlign.center,
            ),
          ),
        if (snapshot.passives.isNotEmpty) ...[
          gap(8),
          _slotGrid(snapshot.passives),
        ],
      ],
    ),
  );

  /// v12.15: owned skills as picture slots with their step badge; the
  /// recipe is the long-press tooltip (mobile inventory grid).
  Widget _slotGrid(List<BattleBuildEntry> entries) => Wrap(
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
                            child: RasterSkillIcon(e.id, size: 46),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: GameTag(
                          e.evolved ? 'EVO' : 'Lv.${e.rank}',
                          tone: e.evolved ? GameTone.good : GameTone.gold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    tr(e.name),
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

/// A small "label value" pair under a damage bar.
Widget _rowFact(String label, String value) => Text.rich(
  TextSpan(
    children: [
      TextSpan(
        text: '${tr(label)} ',
        style: TextStyle(color: GameTone.muted.color),
      ),
      TextSpan(
        text: value,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ],
  ),
  style: const TextStyle(fontSize: GameUi.caption),
  textAlign: TextAlign.center,
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
  if (label.contains('미사일')) return GameIcons.missile;
  if (label.contains('펫')) return 'assets/art/pets_v14/pet_0.webp';
  return null;
}
