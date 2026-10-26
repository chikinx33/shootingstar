import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import '../art/ship_sprite_art.dart';
import '../art/game_icons.dart';

import '../game/engine.dart';
import '../data/aircraft_assembly.dart';
import '../data/ship_modules.dart';
import '../game/survival_skills.dart';
import 'components.dart';

/// Essential flight information only; the loadout belongs in the info dialog.
class BattleHud extends StatelessWidget {
  const BattleHud({
    super.key,
    required this.game,
    required this.title,
    required this.timer,
    required this.onPause,
    required this.onDetails,
  });
  final GameEngine game;
  final String title, timer;
  final VoidCallback? onPause, onDetails;
  static const accent = Color(0xFFFFD43D);
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Semantics(
      label: tr('전투 HUD'),
      container: true,
      explicitChildNodes: true,
      child: Container(
        key: const Key('battle-hud-panel'),
        decoration: const BoxDecoration(
          color: Color(0xFF192C40),
          border: Border(bottom: BorderSide(color: Color(0xFF476174))),
        ),
        padding: const EdgeInsets.fromLTRB(10, 0, 6, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Semantics(
                    header: true,
                    label: tr(title),
                    excludeSemantics: true,
                    child: Text(
                      '${game.worldIndex + 1}-${game.stage.sector + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      label: tr(timer),
                      excludeSemantics: true,
                      child: Text(
                        timer.split(' / ').first,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr('전투 정보'),
                    onPressed: audible(onDetails),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    // v12.15: kit pictures, not system glyphs
                    icon: const GameIconImage(GameIcons.codex, size: 30),
                  ),
                  IconButton(
                    tooltip: tr('일시정지'),
                    onPressed: audible(onPause),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const GameIconImage(GameIcons.pause, size: 28),
                  ),
                ],
              ),
            ),
            SizedBox(
              // Only font scale changes this row's height, never game state.
              height: MediaQuery.textScalerOf(context).scale(14) * 1.25 + 8,
              child: Row(
                children: [
                  Expanded(
                    child: _meter(
                      '체력',
                      'HP ${game.hp.ceil()}/${game.maxHp.ceil()}',
                      '${game.hp.ceil()}',
                      game.hp / game.maxHp,
                      const Color(0xFF7DDD78),
                      const Key('combat-hp'),
                      image: GameIcons.heart,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _meter(
                      '경험치',
                      'Lv.${game.level} · XP ${(game.xp / game.xpNeeded * 100).clamp(0, 100).floor()}%',
                      'Lv.${game.level}',
                      game.xp / game.xpNeeded,
                      const Color(0xFF60DAF5),
                      const Key('combat-xp'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meter(
    String name,
    String full,
    String visible,
    double value,
    Color color,
    Key key, {
    String? image,
  }) => Semantics(
    label: message('{0} · {1}', [name, full]),
    excludeSemantics: true,
    child: Row(
      children: [
        if (image != null) ...[
          GameIconImage(image, size: 18),
          const SizedBox(width: 4),
        ],
        Text(
          visible,
          key: key,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: RasterGauge(
            value: value.clamp(0, 1),
            minHeight: 7,
            color: color,
            backgroundColor: const Color(0xFF0A1728),
          ),
        ),
      ],
    ),
  );
}

/// The same physical mounts and skill slots remain available on demand.
class BattleLoadoutDetails extends StatelessWidget {
  const BattleLoadoutDetails({super.key, required this.game});
  final GameEngine game;
  static const accent = BattleHud.accent;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (game.modular) _modules() else _skills(context, false),
      _skills(context, true),
    ],
  );
  Widget _skills(BuildContext context, bool passive) {
    final entries = (passive ? game.passives : game.upgrades).entries
        .where((e) => e.key != 'gun')
        .toList();
    return Row(
      children: [
        SizedBox(
          width: (MediaQuery.textScalerOf(context).scale(12) * 2 + 2).clamp(
            26.0,
            48.0,
          ),
          child: Text(
            tr(passive ? '보조' : '무기'),
            key: ValueKey('combat-${passive ? 'passive' : 'weapon'}-label'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),

            textAlign: TextAlign.center,
          ),
        ),
        for (var i = 0; i < 6; i++)
          Expanded(
            child: _slot(passive, i, i < entries.length ? entries[i] : null),
          ),
      ],
    );
  }

  Widget _modules() => game.unifiedModules
      ? Row(
          children: [
            for (final mount in moduleProfiles)
              Expanded(
                child: Tooltip(
                  message: tr(
                    '${mount.id} · ${game.moduleLoadout!.parts[mount.id]?.definition.name ?? '빈 슬롯'}',
                  ),
                  child: SizedBox(
                    key: ValueKey('combat-module-${mount.id}'),
                    height: 36,
                    child: game.moduleLoadout!.parts[mount.id] == null
                        ? const Center(
                            child: Text('·', textAlign: TextAlign.center),
                          )
                        : ShipSpriteArt.partSprite(
                            game.moduleLoadout!.parts[mount.id]!.definition,
                            32,
                          ),
                  ),
                ),
              ),
          ],
        )
      : Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                tr('부품'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final mount in const [
              AircraftMount.main,
              AircraftMount.auxiliary,
              AircraftMount.wings,
              AircraftMount.rear,
              AircraftMount.ground,
              AircraftMount.armor,
            ])
              Expanded(child: _moduleSlot(mount)),
          ],
        );

  Widget _moduleSlot(AircraftMount mount) {
    final id = game.aircraft!.parts[mount];
    final part = id == null ? null : aircraftPart(id);
    final group = moduleSkillGroups[mount] ?? const <String>[];
    final rank = mount == AircraftMount.main
        ? (game.upgrades['gun'] ?? 1)
        : 1 + group.fold<int>(0, (v, k) => v + (game.upgrades[k] ?? 0));
    final evolved = group.any(game.evolved.contains);
    final label = part == null ? '빈 장착부' : '${part.name} · $rank';
    return Semantics(
      label: tr(label),
      image: part != null,
      child: Tooltip(
        message: tr(label),
        child: Container(
          key: ValueKey('combat-module-${mount.name}'),
          height: 32,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: part == null
                ? const Color(0xFF152539)
                : const Color(0xFF304B62),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: evolved ? accent : const Color(0xFF476174),
            ),
          ),
          child: part == null
              ? const Center(child: Text('·', textAlign: TextAlign.center))
              : Stack(
                  children: [
                    Center(
                      child: GameIconImage(
                        mount == AircraftMount.main
                            ? GameIcons.crosshair
                            : GameIcons.shield,
                        size: 28,
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Text(
                        evolved ? 'E' : '$rank',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _slot(bool passive, int index, MapEntry<String, int>? entry) {
    final evolved = entry != null && game.evolved.contains(entry.key);
    final name = entry == null
        ? '빈 슬롯'
        : '${skillFor(entry.key).name} · ${entry.value}단계${evolved ? ' · 진화' : ''}\n${game.weaponRoleLabel(entry.key)}';
    return Semantics(
      label: message("{0} {1}: {2}", [passive ? '보조' : '무기', index + 1, name]),
      image: entry != null,
      child: Tooltip(
        message: tr(name),
        child: Container(
          key: ValueKey('combat-slot-${passive ? 'passive' : 'weapon'}-$index'),
          height: 32,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: entry == null
                ? const Color(0xFF152539)
                : const Color(0xFF304B62),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: evolved ? accent : const Color(0xFF476174),
            ),
          ),
          child: entry == null
              ? Center(
                  child: Text(
                    tr('·'),
                    style: TextStyle(fontSize: 14, color: Color(0xFF6F8B9E)),

                    textAlign: TextAlign.center,
                  ),
                )
              : Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: RasterSkillIcon(entry.key, size: 28),
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Text(
                        tr(evolved ? 'E' : '${entry.value}'),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: accent,
                          shadows: [
                            Shadow(
                              color: Color(0xFF091421),
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),

                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Only actionable boss information remains over the battlefield.
class BattleHudStatus extends StatelessWidget {
  const BattleHudStatus({super.key, required this.game});
  final GameEngine game;
  static const accent = BattleHud.accent;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    if (game.boss == null) return const SizedBox.shrink();
    return ColoredBox(
      color: const Color(0xE6192C40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: message('보스 {0}단계, {1}', [
                game.bossPhase + 1,
                game.bossCue,
              ]),
              child: Text(
                message('{0}단계 · {1}', [game.bossPhase + 1, game.bossCue]),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            RasterGauge(
              value: game.bossHealth.clamp(0, 1),
              minHeight: 6,
              color: game.bossExposed ? accent : const Color(0xFFFF7357),
            ),
          ],
        ),
      ),
    );
  }
}
