import 'dart:ui';

import '../data/content.dart';
import '../data/profile.dart';
import 'engine.dart';
import '../data/aircraft_assembly.dart';

enum PresentationReplay {
  magnet('자석 흡수'),
  boss('보스 클리어'),
  reward('보상 수령'),
  purchase('구매 연출'),
  damage('피격'),
  evolution('스킬 진화'),
  ultimate('궁극기'),
  shieldCounter('방패 역습');

  const PresentationReplay(this.label);
  final String label;

  bool get battle => this != reward && this != purchase;

  /// Short combat demonstrations play at normal speed without holding input.
  bool get autoplay => index >= damage.index;
}

/// Uses the real battle paths; setup never modifies a profile or its settings.
GameEngine buildPresentationReplay(Profile p, PresentationReplay kind) {
  final g = GameEngine(
    aircraft: AircraftAssembly.demo(),
    stageIndex: p.selectedStage.clamp(0, 99),
    shipIndex: p.selectedShip,
    attackLevel: 0,
    hullLevel: 0,
    magnetLevel: 0,
    equipmentIndex: 0,
    armament: kind == PresentationReplay.shieldCounter
        ? 'pulse'
        : armaments[p.selectedShip.clamp(0, armaments.length - 1)].id,
    seed: 623,
  )..developerInvincible = true;
  if (kind == PresentationReplay.boss) {
    g.xpNeeded = 1e9;
    for (var i = 0; i < g.requiredBosses; i++) {
      g.elapsed = g.nextBossAt;
      g.update(.001);
      if (i < g.requiredBosses - 1) {
        g.boss!.hp = 0;
        g.update(.001);
        while (g.resolvingBoss) {
          g.update(.05);
        }
        g.supplies.clear();
        g.crystals.clear();
        g.choices = [];
      }
    }
  } else if (kind == PresentationReplay.magnet) {
    g.xpNeeded = 12;
    g.crystals.addAll(
      List.generate(
        56,
        (i) => g.position + Offset((i % 8 - 3.5) * 46, (i ~/ 8 - 4) * 42.0),
      ),
    );
  } else if (kind.autoplay) {
    g.xpNeeded = 1e9;
    g.upgrades.clear();
  }
  return g;
}

/// Trigger after the actual battle viewport has been laid out.
void triggerPresentationReplay(GameEngine game, PresentationReplay kind) {
  if (kind == PresentationReplay.boss) {
    game.boss?.hp = 0;
  }
  if (kind == PresentationReplay.magnet) {
    game.supplies.add(Supply(game.position, 1));
  }
  if (!kind.autoplay) return;
  if (kind == PresentationReplay.damage) {
    // A real hostile collision drives health loss, hit sound and hurt flash.
    game.developerInvincible = false;
    game.shots.add(
      Shot(game.position + const Offset(0, -70), const Offset(0, 160), 18, 4),
    );
    return;
  }
  for (final offset in [const Offset(0, -170), const Offset(35, -255)]) {
    game.enemies.add(
      Foe(game.position + offset, 5000, 0, 20, 0)..attackClock = 1e6,
    );
  }
  switch (kind) {
    case PresentationReplay.evolution:
      game.upgrades['missile'] = 5;
      game.passives['area'] = 1;
      // The genuine boss supply resolves the eligible evolution automatically.
      game.supplies.add(Supply(game.position, 3));
    case PresentationReplay.ultimate:
      game.developerPrepare(scene: 0, ultimateReady: true);
      game.activateCommonUltimate();
    case PresentationReplay.shieldCounter:
      game.upgrades['gun'] = 1;
      game.mainCount = 2;
      game.upgrades['guardian'] = 3;
      game.passives['armor'] = 1;
      // Interception arms the synergy; the next real volley consumes it.
      game.shots.add(
        Shot(game.position + const Offset(0, -100), const Offset(0, 180), 9, 4),
      );
    default:
      break;
  }
}
