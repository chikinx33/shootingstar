part of 'engine.dart';

/// v12.16 in-flight assembly (user 2026-10-27). A sortie opens on the full
/// craft, which sheds its parts in the intro; the cat flies on with only the
/// base hull, its pilot and the pet. Every level-up then offers one shed part
/// as a card: picking it sends the craft soaring (it grows, untouchable),
/// the part flies back and locks on with a flash, and the craft settles to
/// combat size. Weapons fire, and gear stats apply, only once attached.
/// [assembleInFlight] is set by real sorties; engines built elsewhere
/// (tests, previews) keep the whole craft attached.
extension InFlightAssembly on GameEngine {
  /// Every detachable part (v12.17: they come back in a random order).
  static const order = [
    'W1',
    'nose',
    'W2',
    'wings',
    'W3',
    'armor',
    'S1',
    'engines',
  ];
  static const gearParts = {'nose', 'armor', 'wings', 'engines'};

  /// Ship sprite layers carried by each part.
  static const layers = {
    'W1': ['gun_l', 'gun_r'],
    'W2': ['missile_l', 'missile_r'],
    'W3': ['rear_gun'],
    'S1': ['shield'],
    'nose': ['nose'],
    'armor': ['armor'],
    'wings': ['wing_l', 'wing_r'],
    'engines': ['engine_l', 'engine_r', 'flame_l', 'flame_r'],
  };
  static const names = {
    'W1': '윙건',
    'W2': '미사일',
    'W3': '자주포',
    'S1': '보조 장치',
    'nose': '기수',
    'armor': '동체 장갑',
    'wings': '날개',
    'engines': '추진기',
  };

  /// Base sprite file of a gear part inside the ship's folder.
  static const _gearFiles = {
    'nose': 'nose',
    'armor': 'armor',
    'wings': 'wing_left',
    'engines': 'engine_left',
  };

  /// v12.17 (user 2026-10-27): a quick beat on the real clock — it never
  /// slows down when the finger lifts or during an ultimate's cut-in.
  static const mergeSeconds = 1.2;

  /// Fraction of the merge when the part locks on.
  static const lockAt = .62;

  bool partAttached(String id) => !assembleInFlight || attached.contains(id);

  /// Parts this craft actually carries (empty weapon bays have none).
  List<String> get assemblyParts => [
    for (final id in order)
      if (gearParts.contains(id) || moduleLoadout?.parts[id] != null) id,
  ];

  /// Sprite layers still missing from the craft (a merging part is drawn
  /// by the painter with its own fly-in progress).
  Set<String> get detachedLayers => !assembleInFlight
      ? const {}
      : {
          for (final id in order)
            if (!attached.contains(id) && id != mergingPart) ...layers[id]!,
        };

  /// Every detachable layer (the intro sheds these).
  static Set<String> get allLayers => {for (final l in layers.values) ...l};

  double get mergeProgress =>
      mergingPart == null ? 1 : 1 - mergeTime / mergeSeconds;

  /// The craft soars while a part merges: bigger at the middle of the beat.
  double get mergeScale =>
      mergingPart == null ? 1 : 1 + .7 * math.sin(math.pi * mergeProgress);

  /// 0..1 fly-in of the merging part's layers.
  double get mergeAttach =>
      ((mergeProgress - .18) / (lockAt - .18)).clamp(0.0, 1.0);

  /// Called once by a real sortie right after the engine is built.
  void startDisassembled() {
    if (!unifiedModules || assembleInFlight) return;
    assembleInFlight = true;
    attached.clear();
    // gear stats wait for their parts: drop the armour's share of hull now
    maxHp /= 1 + gearHull;
    hp = maxHp;
    gearShare = 0;
    xpNeeded = GameEngine.firstGrowthCost * assemblyXpFactor;
  }

  /// While parts are still shed, drafts come quicker so the craft is whole
  /// again early in the run (the base hull alone only has its main gun).
  double get assemblyXpFactor =>
      assembleInFlight && assemblyParts.any((id) => !attached.contains(id))
      ? .7
      : 1;

  /// Shed parts not yet back on the craft.
  List<String> get shedParts => [
    for (final id in assemblyParts)
      if (!attached.contains(id) && id != mergingPart) id,
  ];

  /// A random shed part as a level-up card, or null when whole again.
  UpgradeChoice? rollMergeChoice() {
    if (!assembleInFlight || mergingPart != null) return null;
    final shed = shedParts;
    if (shed.isEmpty) return null;
    return mergeChoiceFor(shed[random.nextInt(shed.length)]);
  }

  UpgradeChoice mergeChoiceFor(String id) {
    {
      final name = names[id]!;
      final icon = gearParts.contains(id)
          ? 'asset:${ShipSpriteArt.battleAssets[layers[id]!.first] ?? 'assets/art/ship_parts/${ShipSpriteArt.shipFor(shipIndex)}/${_gearFiles[id]}.webp'}'
          : 'part:$id';
      return UpgradeChoice(
        'merge:$id',
        '$name 합체',
        '하늘로 올라 $name와(과) 합체 · 합체하는 동안 무적',
        icon,
        growth: 'merge',
      );
    }
  }

  void _beginMerge(String id) {
    mergingPart = id;
    mergeTime = mergeSeconds;
    _mergeLocked = false;
    visuals.emit(CombatCueKind.level, position, radius: 70);
    pickupNotice = '${names[id]} 합체!';
    noticeTime = 2;
    onEvent?.call('launch');
  }

  void _updateMerge(double dt) {
    final id = mergingPart;
    if (id == null) return;
    mergeTime = math.max(0, mergeTime - dt);
    if (!_mergeLocked && mergeProgress >= lockAt) {
      _mergeLocked = true;
      attached.add(id);
      if (gearParts.contains(id)) {
        final before = 1 + gearHull * gearShare;
        gearShare = math.min(1, gearShare + .25);
        final grow = (1 + gearHull * gearShare) / before;
        maxHp *= grow;
        hp *= grow;
      }
      visuals.emit(CombatCueKind.evolution, position, radius: 96);
      onEvent?.call('equip');
    }
    if (mergeTime <= 0) mergingPart = null;
  }
}
