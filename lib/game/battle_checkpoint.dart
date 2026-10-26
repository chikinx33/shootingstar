part of 'engine.dart';

// Schema 1: gameplay state only. Transient paint/audio cues are excluded.
const battleCheckpointSchema = 1;
List<double>? _point(Offset? p) => p == null ? null : [p.dx, p.dy];
double _d(dynamic v) {
  if (v is! num || !v.isFinite || v.abs() > 1e12) {
    throw const FormatException('Invalid number');
  }
  return v.toDouble();
}

int _i(dynamic v) {
  final d = _d(v);
  if (d != d.truncateToDouble()) throw const FormatException('Invalid integer');
  return d.toInt();
}

bool _b(dynamic v) {
  if (v is! bool) throw const FormatException('Invalid flag');
  return v;
}

String _s(dynamic v) {
  if (v is! String || v.length > 1000) {
    throw const FormatException('Invalid string');
  }
  return v;
}

Offset _o(dynamic v) {
  if (v is! List || v.length != 2) throw const FormatException('Invalid point');
  return Offset(_d(v[0]), _d(v[1]));
}

Map<String, dynamic> _m(dynamic v) {
  if (v is! Map<String, dynamic>) throw const FormatException('Invalid object');
  return v;
}

List<dynamic> _l(dynamic v, [int max = 8192]) {
  if (v is! List || v.length > max) {
    throw const FormatException('Too many actors');
  }
  return v;
}

Map<String, int> _im(dynamic v) => _m(v).map((k, v) => MapEntry(k, _i(v)));
Map<String, double> _dm(dynamic v) => _m(v).map((k, v) => MapEntry(k, _d(v)));

extension BattleCheckpointWriter on GameEngine {
  Map<String, dynamic> checkpoint() {
    final pool = <Foe>{
      ...enemies,
      ..._plasmaCooldown.keys,
      if (bossResolution != null) bossResolution!.foe,
    };
    for (final s in [...shots, ..._deferredShots]) {
      if (s.target != null) pool.add(s.target!);
      pool.addAll(s.hitTargets);
    }
    final actors = pool.toList();
    final ids = {for (var i = 0; i < actors.length; i++) actors[i]: i};
    Map<String, dynamic> shotData(Shot s) => {
      'kind': s.kind,
      'weapon': s.weapon,
      'target': ids[s.target],
      'hits': [for (final f in s.hitTargets) ids[f]],
      'life': s.life,
      'damage': s.damage,
      'radius': s.radius,
      'hitCooldown': s.hitCooldown,
      'age': s.age,
      'distanceTravelled': s.distanceTravelled,
      'fuse': s.fuse,
      'pierce': s.pierce,
      'closeRange': s.closeRange,
      'splitOnHit': s.splitOnHit,
      'triggersSynergies': s.triggersSynergies,
      'position': _point(s.position),
      'velocity': _point(s.velocity),
      'anchor': _point(s.anchor),
    };
    return {
      'schema': battleCheckpointSchema,
      'rng': random.state,
      'xpDrops': {
        'rng': experienceDrops.random.state,
        'misses': experienceDrops.misses,
      },
      'config': {
        'stageIndex': stageIndex,
        if (aircraft != null) 'aircraft': aircraft!.toJson(),
        if (gearSpecs.isNotEmpty) 'gearSpecs': gearSpecs,
        if (aircraft != null) 'supportLevels': supportLevels,
        'shipIndex': shipIndex,
        'attackLevel': attackLevel,
        'hullLevel': hullLevel,
        'magnetLevel': magnetLevel,
        'equipmentIndex': equipmentIndex,
        'campaignLoop': campaignLoop,
        'armamentLevel': armamentLevel,
        'bossSetWorld': bossSetWorld,
        'petKind': petKind,
        'petLevel': petLevel,
        'petRank': petRank,
        'mainPrecisionLink': mainPrecisionLink,
        'mainCycleLink': mainCycleLink,
        'training': training,
        'challenge': challenge,
        'regeneration': regeneration,
        'armament': armament,
        'pilot': pilot,
        'traitLevel': traitLevel,
        'petAwakePower': petAwakePower,
        'petAwakeCooldown': petAwakeCooldown,
        'gearDamage': gearDamage,
        'gearHull': gearHull,
        'hurtGuard': hurtGuard,
        'bonusPickup': bonusPickup,
        'bonusCooldown': bonusCooldown,
        'damageReduction': damageReduction,
        'techRanks': techRanks,
        'daily': dailyEntry == null
            ? null
            : {
                'day': dailyEntry!.day,
                'variant': dailyEntry!.variant,
                'tier': dailyEntry!.tier,
                'seed': dailyEntry!.seed,
              },
      },
      'state': {
        '_absorptionSettle': _absorptionSettle,
        if (aircraft != null)
          'modular': {
            'timers': Map<String, double>.of(_moduleTimers),
            'shield': moduleShield,
            'groundClock': moduleGroundClock,
            'groundSerial': moduleGroundSerial,
            'gearVolleys': gearVolleys,
            'gearSalvage': gearSalvage,
          },
        '_bossSetHealClock': _bossSetHealClock,
        '_mainLinkBlockReadyAt': _mainLinkBlockReadyAt,
        '_regenClock': _regenClock,
        '_ultimateCharge': _ultimateCharge,
        '_ultimateUntil': _ultimateUntil,
        '_shieldCounterUntil': _shieldCounterUntil,
        '_shieldCounterReadyAt': _shieldCounterReadyAt,
        '_mainAttackMultiplier': _mainAttackMultiplier,
        '_frontBreakUntil': _frontBreakUntil,
        '_frontBreakReadyAt': _frontBreakReadyAt,
        '_explosiveSpreadReadyAt': _explosiveSpreadReadyAt,
        'pilotShield': pilotShield,
        'pilotSync': pilotSync,
        'pilotBuff': pilotBuff,
        'pilotAbilityCooldown': pilotAbilityCooldown,
        'magnetPulse': magnetPulse,
        '_magnetClock': _magnetClock,
        '_mainClock': _mainClock,
        '_supplyClock': _supplyClock,
        '_cloudOut': _cloudOut,
        '_guardian': _guardian,
        '_lightning': _lightning,
        'noticeTime': noticeTime,
        'viewportHeight': viewportHeight,
        'atmosphereTime': atmosphereTime,
        '_formationRestUntil': _formationRestUntil,
        '_dailySpawnRemainder': _dailySpawnRemainder,
        '_formationClock': _formationClock,
        '_flightFormationClock': _flightFormationClock,
        'waveNoticeTime': waveNoticeTime,
        'movementAngle': movementAngle,
        'elapsed': elapsed,
        'hp': hp,
        'maxHp': maxHp,
        'xp': xp,
        'xpNeeded': xpNeeded,
        if (legacyArena) 'legacyArena': true,
        'combatTime': combatTime,
        'laserLife': laserLife,
        '_laser': _laser,
        'bossCycle': bossCycle,
        '_spawn': _spawn,
        '_gun': _gun,
        '_missile': _missile,
        '_drone': _drone,
        '_side': _side,
        '_mine': _mine,
        '_trail': _trail,
        '_hurt': _hurt,
        '_damageFlash': _damageFlash,
        '_audio': _audio,
        '_mainLinkVolleys': _mainLinkVolleys,
        '_mainLinkBlocks': _mainLinkBlocks,
        'bossesDefeated': bossesDefeated,
        '_bossWave': _bossWave,
        'chests': chests,
        '_primaryStrikes': _primaryStrikes,
        'revolverAmmo': revolverAmmo,
        'pilotStance': pilotStance,
        '_ultimateUses': _ultimateUses,
        '_shieldCounterAttacks': _shieldCounterAttacks,
        'mainRate': mainRate,
        'mainPower': mainPower,
        'mainCount': mainCount,
        '_mainDrop': _mainDrop,
        '_lastEncounter': _lastEncounter,
        '_formationSerial': _formationSerial,
        '_flightFormationSerial': _flightFormationSerial,
        'level': level,
        'kills': kills,
        'rerolls': rerolls,
        'passiveReplacements': passiveReplacements,
        '_lastBossPhase': _lastBossPhase,
        'bossRound': bossRound,
        'bossAttacks': bossAttacks,
        '_hazardCycle': _hazardCycle,
        '_shieldCounterArmed': _shieldCounterArmed,
        '_mainAttackDidDamage': _mainAttackDidDamage,
        '_mainAttackInProgress': _mainAttackInProgress,
        'pilotMech': pilotMech,
        'chestSelection': chestSelection,
        'paused': paused,
        'finished': finished,
        'victory': victory,
        '_bossSpawned': _bossSpawned,
        '_bossDefeated': _bossDefeated,
        'position': _point(position),
        'input': _point(input),
        'laserOrigin': _point(laserOrigin),
        'bossAim': _point(bossAim),
        'bossOrigin': _point(bossOrigin),
        'bossTarget': _point(bossTarget),
        'hazardCenter': _point(hazardCenter),
        'pickupNotice': pickupNotice,
        'lastDamageSource': lastDamageSource,
        'firstEvolutionAt': firstEvolutionAt,
      },
      'passives': Map.of(passives),
      'upgrades': Map.of(upgrades),
      'evolved': evolved.toList(),
      if (growthEnhance.isNotEmpty) 'growthEnhance': Map.of(growthEnhance),
      if (growthEvolve.isNotEmpty) 'growthEvolve': Map.of(growthEvolve),
      if (growthUltimates.isNotEmpty)
        'growthUltimates': growthUltimates.toList(),
      'timers': Map.of(_extraTimers),
      'synergies': Map.of(_synergyTriggers),
      'damage': Map.of(damageByWeapon),
      'taken': Map.of(damageTakenBySource),
      'foes': [
        for (final f in actors)
          {
            'kind': f.kind,
            'plane': f.plane.name,
            'groundKind': f.groundKind,
            'role': f.role.name,
            'flight': f.flight.name,
            'formation': f.formationPattern?.name,
            'hp': f.hp,
            'maxHp': f.maxHp,
            'speed': f.speed,
            'radius': f.radius,
            'phase': f.phase,
            'frontBreakLastHit': f.frontBreakLastHit,
            'frontBreakReadyAt': f.frontBreakReadyAt,
            'heading': f.heading,
            'orbitSign': f.orbitSign,
            'attackClock': f.attackClock,
            'tell': f.tell,
            'statusTime': f.statusTime,
            'vulnerable': f.vulnerable,
            'statusTick': f.statusTick,
            'frontBreakHits': f.frontBreakHits,
            'formationId': f.formationId,
            'formationOrder': f.formationOrder,
            'status': f.status,
            'generation': f.generation,
            'lastSource': f.lastSource,
            'retired': f.retired,
            'elite': f.elite,
            'position': _point(f.position),
            'velocity': _point(f.velocity),
            'formationFacing': _point(f.formationFacing),
            'aim': _point(f.aim),
            'targetPoint': _point(f.targetPoint),
            'formationOrigin': _point(f.formationOrigin),
            'formationDestination': _point(f.formationDestination),
          },
      ],
      'enemies': [for (final f in enemies) ids[f]],
      'plasma': [
        for (final e in _plasmaCooldown.entries) [ids[e.key], e.value],
      ],
      'shots': shots.map(shotData).toList(),
      'deferred': _deferredShots.map(shotData).toList(),
      'crystals': crystals.map(_point).toList(),
      'crystalXp': crystals.map(ExperienceCrystal.valueOf).toList(),
      'supplies': [
        for (final s in supplies) {'p': _point(s.position), 'kind': s.kind},
      ],
      'absorption': [
        for (final a in absorbingCrystals)
          {
            'origin': _point(a.origin),
            'p': _point(a.position),
            'duration': a.duration,
            'bend': a.bend,
            'value': a.value,
            'age': a.age,
          },
      ],
      'resolution': bossResolution == null
          ? null
          : {
              'foe': ids[bossResolution!.foe],
              'final': bossResolution!.finalBoss,
              'rotation': bossResolution!.rotation,
              'time': bossResolution!.time,
              'bursts': bossResolution!.bursts,
            },
      'choices': [
        for (final c in choices)
          {
            'id': c.id,
            'title': c.title,
            'description': c.description,
            'icon': c.iconKey,
            'evolution': c.evolution,
            'specialization': c.specialization,
          },
      ],
    };
  }
}

abstract final class BattleCheckpoint {
  static GameEngine restore(dynamic raw) {
    final data = _m(raw);
    if (data['schema'] != battleCheckpointSchema) {
      throw const FormatException('Unsupported checkpoint');
    }
    var v = _m(data['config']);
    final daily = v['daily'] == null ? null : _m(v['daily']);
    final game = GameEngine(
      stageIndex: _i(v['stageIndex']),
      aircraft: v['aircraft'] == null
          ? null
          : AircraftAssembly.decode(
              v['aircraft'],
              hull: _i(v['shipIndex']),
            ).withGear(
              v['gearSpecs'] == null
                  ? const []
                  : _l(v['gearSpecs'], 6).map(_i).toList(),
            ),
      supportLevels: v['supportLevels'] == null
          ? const {}
          : _im(v['supportLevels']),
      shipIndex: _i(v['shipIndex']),
      attackLevel: _i(v['attackLevel']),
      hullLevel: _i(v['hullLevel']),
      magnetLevel: _i(v['magnetLevel']),
      equipmentIndex: _i(v['equipmentIndex']),
      campaignLoop: _i(v['campaignLoop']),
      armamentLevel: _i(v['armamentLevel']),
      bossSetWorld: _i(v['bossSetWorld']),
      petKind: _i(v['petKind']),
      petLevel: _i(v['petLevel']),
      petRank: _i(v['petRank']),
      mainPrecisionLink: _b(v['mainPrecisionLink']),
      mainCycleLink: _b(v['mainCycleLink']),
      training: _b(v['training']),
      challenge: _b(v['challenge']),
      regeneration: _b(v['regeneration']),
      armament: _s(v['armament']),
      pilot: _s(v['pilot']),
      traitLevel: v['traitLevel'] is int ? v['traitLevel'] as int : 1,
      petAwakePower: _d(v['petAwakePower']),
      petAwakeCooldown: _d(v['petAwakeCooldown']),
      gearDamage: _d(v['gearDamage']),
      gearHull: _d(v['gearHull']),
      hurtGuard: _d(v['hurtGuard']),
      bonusPickup: _d(v['bonusPickup']),
      bonusCooldown: _d(v['bonusCooldown']),
      damageReduction: _d(v['damageReduction']),
      techRanks: _im(v['techRanks']),
      dailyEntry: daily == null
          ? null
          : DailyChallengeEntry(
              day: _s(daily['day']),
              variant: _i(daily['variant']),
              tier: _i(daily['tier']),
              seed: _i(daily['seed']),
            ),
    );
    if (game.stageIndex < 0 ||
        game.stageIndex > 99 ||
        game.shipIndex < 0 ||
        game.shipIndex >= content.ships.length ||
        !content.armaments.any((a) => a.id == game.armament) ||
        !content.pilots.any((p) => p.id == game.pilot) ||
        game.training) {
      throw const FormatException('Invalid loadout');
    }
    if (game.aircraft != null &&
        game.aircraft!.modules == null &&
        (!game.aircraft!.parts.containsKey(AircraftMount.main) ||
            game.supportLevels.length > 3 ||
            game.supportLevels.entries.any(
              (e) =>
                  !AircraftAssembly.petParts.contains(e.key) ||
                  e.value < 1 ||
                  e.value > 30,
            ))) {
      throw const FormatException('Invalid modular loadout');
    }
    final rng = _i(data['rng']);
    if (rng <= 0 || rng > 0xffffffff) {
      throw const FormatException('Invalid RNG');
    }
    game.random.state = rng;
    if (data['xpDrops'] != null) {
      final drops = _m(data['xpDrops']);
      final dropRng = _i(drops['rng']), misses = _i(drops['misses']);
      if (dropRng <= 0 || dropRng > 0xffffffff || misses < 0 || misses > 59) {
        throw const FormatException('Invalid XP drop state');
      }
      game.experienceDrops.random.state = dropRng;
      game.experienceDrops.misses = misses;
    }
    v = _m(data['state']);
    game._absorptionSettle = _d(v['_absorptionSettle']);
    if (game.aircraft != null) {
      final modular = _m(v['modular']);
      game._moduleTimers.addAll(_dm(modular['timers']));
      game.moduleShield = _d(modular['shield']);
      game.moduleGroundClock = _d(modular['groundClock']);
      game.moduleGroundSerial = _i(modular['groundSerial']);
      game.gearVolleys = modular['gearVolleys'] == null
          ? 0
          : _i(modular['gearVolleys']);
      game.gearSalvage = modular['gearSalvage'] == null
          ? 0
          : _i(modular['gearSalvage']);
      if (game._moduleTimers.length > (game.unifiedModules ? 96 : 32) ||
          game.moduleShield < 0 ||
          game.moduleShield > game.maxHp * 2 ||
          game.moduleGroundSerial < 0 ||
          game.gearVolleys < 0 ||
          game.gearSalvage < 0) {
        throw const FormatException('Invalid module state');
      }
    }
    game._bossSetHealClock = _d(v['_bossSetHealClock']);
    game._mainLinkBlockReadyAt = _d(v['_mainLinkBlockReadyAt']);
    game._regenClock = _d(v['_regenClock']);
    game._ultimateCharge = _d(v['_ultimateCharge']);
    game._ultimateUntil = _d(v['_ultimateUntil']);
    game._shieldCounterUntil = _d(v['_shieldCounterUntil']);
    game._shieldCounterReadyAt = _d(v['_shieldCounterReadyAt']);
    game._mainAttackMultiplier = _d(v['_mainAttackMultiplier']);
    game._frontBreakUntil = _d(v['_frontBreakUntil']);
    game._frontBreakReadyAt = _d(v['_frontBreakReadyAt']);
    game._explosiveSpreadReadyAt = _d(v['_explosiveSpreadReadyAt']);
    game.pilotShield = _d(v['pilotShield']);
    game.pilotSync = _d(v['pilotSync']);
    game.pilotBuff = _d(v['pilotBuff']);
    game.pilotAbilityCooldown = _d(v['pilotAbilityCooldown']);
    game.magnetPulse = _d(v['magnetPulse']);
    game._magnetClock = _d(v['_magnetClock']);
    game._mainClock = _d(v['_mainClock']);
    game._supplyClock = _d(v['_supplyClock']);
    game._cloudOut = v['_cloudOut'] == null ? 0 : _d(v['_cloudOut']);
    game._guardian = _d(v['_guardian']);
    game._lightning = _d(v['_lightning']);
    game.noticeTime = _d(v['noticeTime']);
    game.viewportHeight = _d(v['viewportHeight']);
    game.atmosphereTime = _d(v['atmosphereTime']);
    game._formationRestUntil = _d(v['_formationRestUntil']);
    game._dailySpawnRemainder = _d(v['_dailySpawnRemainder']);
    game._formationClock = _d(v['_formationClock']);
    game._flightFormationClock = _d(v['_flightFormationClock']);
    game.waveNoticeTime = _d(v['waveNoticeTime']);
    game.movementAngle = _d(v['movementAngle']);
    game.elapsed = _d(v['elapsed']);
    game.hp = _d(v['hp']);
    game.maxHp = _d(v['maxHp']);
    game.xp = _d(v['xp']);
    game.xpNeeded = _d(v['xpNeeded']);
    game.legacyArena = v['legacyArena'] == true;
    game.combatTime = _d(v['combatTime']);
    game.laserLife = _d(v['laserLife']);
    game._laser = _d(v['_laser']);
    game.bossCycle = _d(v['bossCycle']);
    game._spawn = _d(v['_spawn']);
    game._gun = _d(v['_gun']);
    game._missile = _d(v['_missile']);
    game._drone = _d(v['_drone']);
    game._side = _d(v['_side']);
    game._mine = _d(v['_mine']);
    game._trail = _d(v['_trail']);
    game._hurt = _d(v['_hurt']);
    game._damageFlash = _d(v['_damageFlash'] ?? 0);
    game._audio = _d(v['_audio']);
    game._mainLinkVolleys = _i(v['_mainLinkVolleys']);
    game._mainLinkBlocks = _i(v['_mainLinkBlocks']);
    game.bossesDefeated = _i(v['bossesDefeated']);
    game._bossWave = _i(v['_bossWave']);
    game.chests = _i(v['chests']);
    game._primaryStrikes = _i(v['_primaryStrikes']);
    game.revolverAmmo = _i(v['revolverAmmo']);
    game.pilotStance = _i(v['pilotStance']);
    game._ultimateUses = _i(v['_ultimateUses']);
    game._shieldCounterAttacks = _i(v['_shieldCounterAttacks']);
    game.mainRate = _i(v['mainRate']);
    game.mainPower = _i(v['mainPower']);
    game.mainCount = _i(v['mainCount']);
    game._mainDrop = _i(v['_mainDrop']);
    game._lastEncounter = _i(v['_lastEncounter']);
    game._formationSerial = _i(v['_formationSerial']);
    game._flightFormationSerial = _i(v['_flightFormationSerial']);
    game.level = _i(v['level']);
    game.kills = _i(v['kills']);
    game.rerolls = _i(v['rerolls']);
    game.passiveReplacements = _i(v['passiveReplacements']);
    game._lastBossPhase = _i(v['_lastBossPhase']);
    game.bossRound = _i(v['bossRound']);
    game.bossAttacks = _i(v['bossAttacks']);
    game._hazardCycle = _i(v['_hazardCycle']);
    game._shieldCounterArmed = _b(v['_shieldCounterArmed']);
    game._mainAttackDidDamage = _b(v['_mainAttackDidDamage']);
    game._mainAttackInProgress = _b(v['_mainAttackInProgress']);
    game.pilotMech = _b(v['pilotMech']);
    game.chestSelection = _b(v['chestSelection']);
    game.paused = _b(v['paused']);
    game.finished = _b(v['finished']);
    game.victory = _b(v['victory']);
    game._bossSpawned = _b(v['_bossSpawned']);
    game._bossDefeated = _b(v['_bossDefeated']);
    game.position = _o(v['position']);
    game.input = _o(v['input']);
    game.laserOrigin = _o(v['laserOrigin']);
    game.bossAim = _o(v['bossAim']);
    game.bossOrigin = _o(v['bossOrigin']);
    game.bossTarget = _o(v['bossTarget']);
    game.hazardCenter = _o(v['hazardCenter']);
    game.pickupNotice = _s(v['pickupNotice']);
    game.lastDamageSource = _s(v['lastDamageSource']);
    game.firstEvolutionAt = v['firstEvolutionAt'] == null
        ? null
        : _d(v['firstEvolutionAt']);
    if (game.hp < 0 ||
        game.maxHp <= 0 ||
        game.hp > game.maxHp ||
        game.elapsed < 0 ||
        game.elapsed > game.duration + .1 ||
        game.combatTime < 0 ||
        game.kills < 0 ||
        game.level < 1 ||
        game.level > 10000 ||
        game.position.dx < 0 ||
        game.position.dx > GameEngine.worldWidth ||
        game.position.dy < 0 ||
        game.position.dy > GameEngine.worldHeight) {
      throw const FormatException('Invalid combat state');
    }
    // old checkpoints may carry a removed main-gun 'branch': ignored
    game.upgrades
      ..clear()
      ..addAll(_im(data['upgrades']));
    game.passives.addAll(_im(data['passives']));
    game.evolved.addAll(_l(data['evolved'], 64).map(_s));
    if (data['growthEnhance'] != null) {
      game.growthEnhance.addAll(_im(data['growthEnhance']));
    }
    if (data['growthEvolve'] != null) {
      game.growthEvolve.addAll(_im(data['growthEvolve']));
    }
    if (data['growthUltimates'] != null) {
      game.growthUltimates.addAll(_l(data['growthUltimates'], 32).map(_s));
    }
    final mountedSkills = {
      if (game.unifiedModules)
        for (final e in game.moduleLoadout!.parts.entries)
          if (e.value.definition.weapon) 'part:${e.key}',
    };
    for (final e in game.upgrades.entries.where(
      (e) => e.key.startsWith('part:'),
    )) {
      if (!mountedSkills.contains(e.key) || e.value < 1 || e.value > 5)
        throw const FormatException('Invalid mounted part upgrade');
    }
    for (final id in {
      ...game.upgrades.keys,
      ...game.passives.keys,
      ...game.evolved,
    }) {
      if (!survivalSkills.any((s) => s.id == id) &&
          !pawSkills.any((s) => s.id == id) &&
          !(mountedSkills.contains(id) &&
              !game.passives.containsKey(id) &&
              !game.evolved.contains(id))) {
        throw const FormatException('Unknown skill');
      }
    }
    game._extraTimers.addAll(_dm(data['timers']));
    game._synergyTriggers.addAll(_im(data['synergies']));
    game.damageByWeapon.addAll(_dm(data['damage']));
    game.damageTakenBySource.addAll(_dm(data['taken']));
    final actors = <Foe>[];
    for (final raw in _l(data['foes'], 4096)) {
      v = _m(raw);
      final f = Foe(
        _o(v['position']),
        _d(v['hp']),
        _d(v['speed']),
        _d(v['radius']),
        _i(v['kind']),
        role: content.EnemyRole.values.byName(_s(v['role'])),
      );
      f.hp = _d(v['hp']);
      f.maxHp = _d(v['maxHp']);
      f.speed = _d(v['speed']);
      f.radius = _d(v['radius']);
      f.phase = _d(v['phase']);
      f.frontBreakLastHit = _d(v['frontBreakLastHit']);
      f.frontBreakReadyAt = _d(v['frontBreakReadyAt']);
      f.heading = _d(v['heading']);
      f.orbitSign = _d(v['orbitSign']);
      f.attackClock = _d(v['attackClock']);
      f.tell = _d(v['tell']);
      f.statusTime = _d(v['statusTime']);
      f.vulnerable = _d(v['vulnerable']);
      f.statusTick = _d(v['statusTick']);
      f.frontBreakHits = _i(v['frontBreakHits']);
      f.formationId = _i(v['formationId']);
      f.formationOrder = _i(v['formationOrder']);
      f.status = _i(v['status']);
      f.generation = _i(v['generation']);
      f.lastSource = _s(v['lastSource']);
      f.retired = _b(v['retired']);
      f.elite = v['elite'] == true;
      f.position = _o(v['position']);
      f.velocity = _o(v['velocity']);
      f.formationFacing = _o(v['formationFacing']);
      f.aim = _o(v['aim']);
      f.targetPoint = v['targetPoint'] == null ? null : _o(v['targetPoint']);
      f.formationOrigin = v['formationOrigin'] == null
          ? null
          : _o(v['formationOrigin']);
      f.formationDestination = v['formationDestination'] == null
          ? null
          : _o(v['formationDestination']);
      f.plane = v['plane'] == null
          ? AircraftTarget.air
          : AircraftTarget.values.byName(_s(v['plane']));
      f.groundKind = v['groundKind'] == null ? 0 : _i(v['groundKind']);
      if (f.groundKind < 0 || f.groundKind > 2)
        throw const FormatException('Invalid ground enemy');
      f.flight = content.EnemyFlight.values.byName(_s(v['flight']));
      f.formationPattern = v['formation'] == null
          ? null
          : FlightFormation.values.byName(_s(v['formation']));
      actors.add(f);
    }
    Foe actor(dynamic n) => actors[_i(n)];
    game.enemies.addAll(_l(data['enemies'], game.enemyLimit).map(actor));
    for (final entry in _l(data['plasma'])) {
      final p = _l(entry, 2);
      game._plasmaCooldown[actor(p[0])] = _d(p[1]);
    }
    Shot restoreShot(dynamic raw) {
      final v = _m(raw);
      final s = Shot(
        _o(v['position']),
        _o(v['velocity']),
        _d(v['damage']),
        _i(v['kind']),
        weapon: _s(v['weapon']),
        target: v['target'] == null ? null : actor(v['target']),
      );
      s.life = _d(v['life']);
      s.damage = _d(v['damage']);
      s.radius = _d(v['radius']);
      s.hitCooldown = _d(v['hitCooldown']);
      s.age = _d(v['age']);
      s.distanceTravelled = _d(v['distanceTravelled']);
      s.fuse = _d(v['fuse']);
      s.pierce = _i(v['pierce']);
      s.closeRange = _b(v['closeRange']);
      s.splitOnHit = _b(v['splitOnHit']);
      s.triggersSynergies = _b(v['triggersSynergies']);
      s.position = _o(v['position']);
      s.velocity = _o(v['velocity']);
      s.anchor = v['anchor'] == null ? null : _o(v['anchor']);
      s.hitTargets.addAll(_l(v['hits'], 4096).map(actor));
      return s;
    }

    game.shots.addAll(_l(data['shots']).map(restoreShot));
    game._deferredShots.addAll(_l(data['deferred']).map(restoreShot));
    // Older builds could save the short overflow between deaths and the next
    // supply update. Recover that bounded legacy state without losing XP.
    final points = _l(data['crystals'], 4096);
    final values = data['crystalXp'] == null
        ? List<double>.filled(points.length, 2)
        : _l(data['crystalXp'], 4096).map(_d).toList();
    if (values.length != points.length ||
        values.any((v) => v <= 0 || v > 1e9)) {
      throw const FormatException('Invalid crystal experience');
    }
    for (var i = 0; i < points.length; i++) {
      game.crystals.add(ExperienceCrystal.at(_o(points[i]), values[i]));
    }
    game._consolidateCrystals();
    for (final raw in _l(data['supplies'], 1024)) {
      final v = _m(raw);
      game.supplies.add(Supply(_o(v['p']), _i(v['kind'])));
    }
    var overflowMote = 0;
    for (final raw in _l(data['absorption'], 4096)) {
      final v = _m(raw);
      final a =
          AbsorbingCrystal(
              _o(v['origin']),
              _d(v['duration']),
              _d(v['bend']),
              _d(v['value']),
            )
            ..position = _o(v['p'])
            ..age = _d(v['age']);
      if (a.duration <= 0 || a.value < 0) {
        throw const FormatException('Invalid pickup');
      }
      if (game.absorbingCrystals.length < GameEngine.crystalLimit) {
        game.absorbingCrystals.add(a);
      } else {
        game
                .absorbingCrystals[overflowMote++ % GameEngine.crystalLimit]
                .value +=
            a.value;
      }
    }
    if (data['resolution'] != null) {
      final v = _m(data['resolution']);
      game.bossResolution =
          BossResolution(actor(v['foe']), _b(v['final']), _d(v['rotation']))
            ..time = _d(v['time'])
            ..bursts = _i(v['bursts']);
    }
    for (final raw in _l(data['choices'], 10)) {
      final v = _m(raw);
      if (game.unifiedModules &&
          !{
            'gun',
            'attack',
            'cooldown',
            'hull',
            'speed',
            'magnet',
            'repair',
            ...mountedSkills,
            // item attacks (paw weapons) and weapon growth steps
            for (final paw in pawSkills) paw.id,
          }.contains(_s(v['id'])) &&
          !RegExp(r'^(enh|evo|ult)\|').hasMatch(_s(v['id'])))
        throw const FormatException('Invalid module upgrade choice');
      game.choices.add(
        UpgradeChoice(
          _s(v['id']),
          _s(v['title']),
          _s(v['description']),
          _s(v['icon']),
          evolution: _b(v['evolution']),
          specialization: _b(v['specialization']),
        ),
      );
    }
    if (game.unifiedModules && game.choices.length > 3)
      throw const FormatException('Too many module choices');
    return game;
  }
}
