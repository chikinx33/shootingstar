import '../l10n/app_language.dart';
import '../data/ship_modules.dart';

import 'audio_feedback.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

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
    'support',
    'dive',
    'sound',
    'sai',
    'dualblade',
    'bo',
    'martial',
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
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 460,
        height: math.min(680, MediaQuery.sizeOf(context).height - 48),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('전투 통계'),
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),

                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      key: const Key('close-battle-statistics'),
                      tooltip: tr('통계 닫기'),
                      onPressed: audible(() => Navigator.of(context).pop()),
                      icon: const RasterIcon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  tr(
                    snapshot.finished
                        ? '이번 출격의 최종 기록'
                        : '일시정지 중 · 이번 출격의 현재 기록',
                  ),
                  style: const TextStyle(color: muted, fontSize: 14),

                  textAlign: TextAlign.center,
                ),
              ),
              TabBar(
                onTap: audibleChange((_) {}),
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
    );
  }

  Widget _damage() => GameItemList(
    key: const Key('battle-damage-scroll'),
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message("누적 피해 {0}", [_number(snapshot.damage.totalDamage)]),
          key: const Key('battle-total-damage'),
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: cyan,
          ),

          textAlign: TextAlign.center,
        ),
        gap(6),
        Text(
          message("전투 {0}초 · 평균 {1} DPS", [
            snapshot.damage.combatSeconds.toStringAsFixed(1),
            _number(snapshot.damage.dps),
          ]),

          textAlign: TextAlign.center,
        ),
        gap(7),
        Text(
          tr('DPS = 실제 가한 피해 ÷ 실제 전투 시간\n일시정지·스킬 선택 시간과 초과 피해는 제외합니다.'),
          style: TextStyle(fontSize: 14, color: muted),

          textAlign: TextAlign.center,
        ),
        gap(16),
        if (snapshot.damage.entries.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              tr('아직 가한 피해가 없습니다. 전투 후 다시 확인하세요.'),
              textAlign: TextAlign.center,
            ),
          ),
        for (final entry in snapshot.damage.entries) ...[
          Text(
            tr(entry.label),
            style: const TextStyle(fontWeight: FontWeight.w800),

            textAlign: TextAlign.center,
          ),
          gap(4),
          Row(
            children: [
              Expanded(
                child: Text(
                  message("{0} 피해 · {1} DPS", [
                    _number(entry.damage),
                    _number(entry.dps),
                  ]),
                  style: const TextStyle(fontSize: 14, color: muted),

                  textAlign: TextAlign.center,
                ),
              ),
              Text(
                message("{0}%", [(entry.share * 100).toStringAsFixed(1)]),
                style: const TextStyle(
                  color: cyan,
                  fontWeight: FontWeight.w800,
                ),

                textAlign: TextAlign.center,
              ),
            ],
          ),
          gap(6),
          RasterGauge(
            key: ValueKey('damage-share-${entry.source}'),
            value: entry.share,
            minHeight: 9,
            color: cyan,
          ),
          gap(17),
        ],
      ],
    ),
  );

  Widget _build() => GameItemList(
    key: const Key('battle-build-scroll'),
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message("{0}\n영구 강화 {1}/10 · 주무기 피해 +{2}%", [
            snapshot.armament,
            snapshot.armamentLevel,
            snapshot.armamentLevel * 2,
          ]),
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: cyan,
          ),

          textAlign: TextAlign.center,
        ),
        gap(6),
        Text(
          message("주포 보급 · R 연사 {0}/5 · P 출력 {1}/5\nN 발사 수 {2}/4 · {3}발", [
            snapshot.mainRate,
            snapshot.mainPower,
            snapshot.mainCount,
            snapshot.mainCount + 1,
          ]),

          textAlign: TextAlign.center,
        ),
        gap(10),
        Text(
          message("{0} · 고유 모듈 {1}단계", [snapshot.pilot, snapshot.pilotRank]),
          textAlign: TextAlign.center,
        ),
        gap(10),
        Text(
          tr(snapshot.mainLoadout),
          style: const TextStyle(fontSize: 14, color: cyan),

          textAlign: TextAlign.center,
        ),
        if (snapshot.ultimate.isNotEmpty) ...[
          gap(10),
          Text(
            tr(snapshot.ultimate),
            style: const TextStyle(fontSize: 14, color: cyan),

            textAlign: TextAlign.center,
          ),
        ],
        for (final detail in snapshot.synergies) ...[
          gap(12),
          Text(
            tr(detail),
            style: const TextStyle(fontSize: 14, color: cyan),
            textAlign: TextAlign.center,
          ),
        ],
        gap(16),
        Text(
          tr('보유 무기'),
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),

          textAlign: TextAlign.center,
        ),
        for (final e in snapshot.weapons) _buildRow(e),
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
        for (final e in snapshot.passives) _buildRow(e),
      ],
    ),
  );

  Widget _buildRow(BattleBuildEntry e) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RasterSkillIcon(e.id, size: 25, color: e.evolved ? cyan : Colors.white),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                message("{0} · {1}{2}단계", [
                  e.name,
                  e.evolved ? 'EVO · ' : '',
                  e.rank,
                ]),
                style: const TextStyle(fontWeight: FontWeight.w800),

                textAlign: TextAlign.center,
              ),
              gap(4),
              Text(
                tr(e.recipe),
                style: const TextStyle(color: muted, fontSize: 14),

                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _number(double value) {
  if (!value.isFinite) return '표시 범위 초과';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 10000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toStringAsFixed(1);
}
