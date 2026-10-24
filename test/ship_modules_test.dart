import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/ship_modules.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/hangar_preset.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/art/module_aircraft_art.dart';
import 'package:shootingstar/ui/module_workshop.dart';
import 'package:shootingstar/ui/item_slots.dart';
import 'package:shootingstar/ui/reward_popup.dart';
import 'package:shootingstar/ui/upgrade_slots.dart';
import 'package:shootingstar/ui/battle_hud.dart';
import 'package:shootingstar/ui/battle_statistics.dart';

import 'ui_actions.dart';

GameEngine arena(String mount, {String part = 'gun_vulcan', int level = 3}) =>
    GameEngine(
      stageIndex: 0,
      shipIndex: 0,
      aircraft: AircraftAssembly(
        hull: 0,
        modules: ModuleSnapshot(0, 1, {
          mount: OwnedModulePart('test-instance', part, level),
        }),
      ),
      attackLevel: 0,
      hullLevel: 0,
      magnetLevel: 0,
      equipmentIndex: -1,
      seed: 66,
    )..xpNeeded = 1e8;
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'one instance moves among four mounts without changing level or attributes',
    () {
      final fleet = ModuleFleet()..seed(0);
      final part = fleet.add('gun_vulcan', level: 3);
      for (final mount in moduleProfiles.where((m) => m.weapon)) {
        expect(fleet.equip(0, mount.id, part.instanceId), isTrue);
        final snap = fleet.snapshot(0);
        expect(
          snap.parts.values.where((p) => p.instanceId == part.instanceId),
          hasLength(1),
        );
        expect(snap.parts[mount.id]!.level, 3);
        expect(snap.parts[mount.id]!.definition.homing, isFalse);
      }
      final stats = [
        for (final m in moduleProfiles.where((m) => m.weapon))
          resolvePartStats(part, m),
      ];
      expect(stats.map((s) => s.count).toList(), [2, 1, 3, 1]);
      expect(stats[1].damage, greaterThan(stats[0].damage));
      expect(stats[1].pierce, 1);
      for (final m in moduleProfiles.where((m) => m.weapon)) {
        final a = resolvePartStats(part, m),
            b = resolvePartStats(part.leveled(), m);
        expect(b.damage / a.damage, closeTo(1.24 / 1.16, 1e-9));
      }
      final shield = fleet.add('shield'), copy = fleet.add('shield');
      expect(fleet.equip(0, 'S1', shield.instanceId), isTrue);
      expect(fleet.equip(0, 'S2', copy.instanceId), isFalse);
      expect(fleet.equip(0, 'W1', shield.instanceId), isFalse);
      expect(fleet.equip(0, 'S2', shield.instanceId), isTrue);
      expect(fleet.snapshot(0).parts.containsKey('S1'), isFalse);
    },
  );
  test(
    'same gun produces actual outward, heavy, rear fan and turret projectiles',
    () {
      for (final mount in ['W1', 'W2', 'W3', 'W4']) {
        final g = arena(mount);
        g.enemies.add(Foe(g.position + const Offset(120, 0), 10000, 0, 10, 0));
        g.update(.001);
        final shots = g.shots
            .where((s) => s.weapon.startsWith('part:$mount:'))
            .toList();
        expect(
          shots,
          hasLength(
            mount == 'W1'
                ? 2
                : mount == 'W3'
                ? 3
                : 1,
          ),
          reason: mount,
        );
        if (mount == 'W1') {
          expect(shots.first.velocity.dx, lessThan(0));
          expect(shots.last.velocity.dx, greaterThan(0));
          expect(shots.every((s) => s.velocity.dy < 0), isTrue);
        } else if (mount == 'W2') {
          expect(shots.single.velocity.dx, closeTo(0, 1e-9));
          expect(shots.single.velocity.dy, lessThan(0));
        } else if (mount == 'W3') {
          expect(shots.every((s) => s.velocity.dy > 0), isTrue);
        } else {
          expect(shots.single.velocity.dx, greaterThan(0));
        }
        expect(shots.every((s) => s.kind == 0), isTrue);
      }
    },
  );
  test('ground masks, empty mounts, checkpoint and module choices follow new loadout', () {
    final g = arena('W1');
    final ground = Foe(
      g.position,
      1000,
      0,
      10,
      0,
      plane: AircraftTarget.ground,
    );
    expect(g.partSourceHits('part:W1:gun_vulcan', ground), isFalse);
    expect(g.partSourceHits('part:W2:gun_vulcan', ground), isTrue);
    expect(g.partSourceHits('part:W4:missile_hawk', ground), isTrue);
    expect(g.partSourceHits('module-main', ground), isFalse);
    g.update(.02);
    final copy = BattleCheckpoint.restore(
      jsonDecode(jsonEncode(g.checkpoint())),
    );
    expect(copy.moduleLoadout!.toJson(), g.moduleLoadout!.toJson());
    g.choices = [const UpgradeChoice('part:W1', 'W1 강화', '파츠 강화', 'gun')];
    g.chooseUpgrade('part:W1');
    expect(g.upgrades['part:W1'], 1);
    expect(g.missingPartners, isEmpty);
    expect(g.canEvolve('part:W1'), isFalse);
    g.upgrades['part:W1'] = 2;
    final strengthened = BattleCheckpoint.restore(
      jsonDecode(jsonEncode(g.checkpoint())),
    );
    expect(strengthened.upgrades['part:W1'], 2);
    final invalid =
        jsonDecode(jsonEncode(g.checkpoint())) as Map<String, dynamic>;
    (invalid['upgrades'] as Map)['part:W2'] = 1;
    expect(() => BattleCheckpoint.restore(invalid), throwsFormatException);
    g.xpNeeded = 1;
    g.xp = 1;
    g.nextGrowthAt = 0;
    g.update(.02);
    expect(g.choices, isNotEmpty);
    final decision = BattleCheckpoint.restore(
      jsonDecode(jsonEncode(g.checkpoint())),
    );
    expect(decision.choices.map((c) => c.id), g.choices.map((c) => c.id));
    expect(
      g.choices
          .where((c) => c.id.startsWith('part:'))
          .every((c) => c.id == 'part:W1'),
      isTrue,
    );
    final empty = GameEngine(
      stageIndex: 0,
      shipIndex: 0,
      aircraft: AircraftAssembly(modules: ModuleSnapshot(0, 1, {})),
      attackLevel: 0,
      hullLevel: 0,
      magnetLevel: 0,
      equipmentIndex: -1,
    );
    empty.update(.01);
    expect(empty.shots.any((s) => s.weapon == 'module-main'), isTrue);
    expect(empty.shots.any((s) => s.weapon.startsWith('part:')), isFalse);
  });
  test('legacy inventory migrates once and preserves per-ship loadouts and upgrade ownership', () async {
    final p = await Profile.load();
    final legacyCount = p.inventory.length;
    final id = p.moduleLoadout.parts['W1']!.instanceId;
    p.credits = 10000;
    p.blueprints = 100;
    expect(p.upgradeModule(id), isTrue);
    final level = p.shipModules.owned[id]!.level;
    expect(p.equipModule('W2', id), isTrue);
    expect(p.moduleLoadout.parts.containsKey('W1'), isFalse);
    p.unlockedShips.add(1);
    p.selectShip(1);
    expect(p.moduleLoadout.hull, 1);
    p.selectShip(0);
    expect(p.moduleLoadout.parts['W2']!.instanceId, id);
    await p.save();
    final data = jsonEncode(p.shipModules.toJson());
    final copy = await Profile.load();
    expect(copy.moduleLoadout.parts['W2']!.level, level);
    expect(copy.inventory.length, legacyCount);
    expect(jsonEncode(copy.shipModules.toJson()), data);
    Directory('.local/module-v66').createSync(recursive: true);
    File('.local/module-v66/fixture.json')
        .writeAsStringSync(jsonEncode(copy.exportProgress()));
    p.dispose();
    copy.dispose();
  });
  test('preview never grants parts, presets retain upgrades, salvage protects every hull', () async {
    final p = await Profile.load();
    p.credits = 10000;
    p.blueprints = 100;
    final fleet = p.shipModules, count = fleet.owned.length;
    fleet.preview(2);
    expect(fleet.owned.length, count);
    expect(fleet.loadouts.containsKey(2), isFalse);
    final preset = HangarPreset.capture(p, 'new modules');
    final id = p.moduleLoadout.parts['W1']!.instanceId;
    expect(p.upgradeModule(id), isTrue);
    final level = fleet.owned[id]!.level;
    p.equipModule('W2', id);
    expect(preset.apply(p), isTrue);
    expect(p.moduleLoadout.parts['W1']!.level, level);
    expect(p.canSalvageModule(id), isFalse);
    final spare = fleet.add('drone_wasp');
    expect(p.salvageModule(spare.instanceId), isTrue);
    expect(fleet.owned.containsKey(spare.instanceId), isFalse);
    p.dispose();
  });
  test('new supply consumes keys, grants independent parts and shows actual receipt', () async {
    final p = await Profile.load();
    p.gearKeys = 3;
    p.petEggs = 7;
    final before = RewardSnapshot(p), start = p.shipModules.owned.length;
    for (var i = 0; i < 3; i++) expect(p.openModuleSupply(), isTrue);
    for (var i = 0; i < 7; i++)
      expect(p.openModuleSupply(support: true), isTrue);
    expect(p.shipModules.owned.length, start + 10);
    expect(
      before.earned(p).where((e) => e.modulePartId != null),
      hasLength(10),
    );
    expect(p.gearKeys, 0);
    expect(p.petEggs, 0);
    expect(p.openModuleSupply(), isFalse);
    expect(p.openModuleSupply(support: true), isFalse);
    p.dispose();
  });
  test('airframe level affects its primary, not detachable part power', () {
    GameEngine make(int level) => GameEngine(
      stageIndex: 0,
      shipIndex: 0,
      aircraft: AircraftAssembly(
        modules: ModuleSnapshot(0, level, {
          'W2': const OwnedModulePart('same', 'gun_vulcan', 3),
        }),
      ),
      attackLevel: 0,
      hullLevel: 0,
      magnetLevel: 0,
      equipmentIndex: -1,
    );
    final a = make(1), b = make(10);
    expect(b.damageFactor, greaterThan(a.damageFactor));
    expect(b.partStats('W2').damage, closeTo(a.partStats('W2').damage, 1e-9));
  });
  test('missiles retain homing and hit ground on every mount; top salvo divides targets', () {
    for (final mount in ['W1', 'W2', 'W3', 'W4']) {
      final g = arena(mount, part: 'missile_hawk');
      final target = Foe(
        g.position + Offset(0, mount == 'W3' ? 110 : -110),
        10000,
        0,
        18,
        0,
        plane: AircraftTarget.ground,
      );
      g.enemies.add(target);
      for (var i = 0; i < 90; i++) g.update(1 / 60);
      expect(
        g.damageByWeapon['part:$mount:missile_hawk'] ?? 0,
        greaterThan(0),
        reason: mount,
      );
      expect(target.hp, lessThan(target.maxHp), reason: mount);
    }
    final g = arena('W4', part: 'missile_hawk');
    final targets = [
      for (final dx in [-160.0, 0.0, 160.0])
        Foe(g.position + Offset(dx, 110), 10000, 0, 12, 0),
    ];
    g.enemies.addAll(targets);
    // The top carrier now visibly ascends, then releases real falling rockets.
    for (var i = 0; i < 70; i++) g.update(1 / 60);
    expect(targets.every((f) => f.hp < f.maxHp), isTrue);
  });
  test('drones use four formations and preserve independent damaged health on resume', () {
    for (final mount in ['W1', 'W2', 'W3', 'W4']) {
      final g = arena(mount, part: 'drone_wasp', level: 1);
      final part = g.moduleLoadout!.parts[mount]!,
          count = g.partStats(mount).count;
      final points = g.droneFormation(mount, part, count);
      expect(points, hasLength(count));
      if (mount == 'W1') {
        expect(points.first.dx, lessThan(g.position.dx));
        expect(points.last.dx, greaterThan(g.position.dx));
      } else if (mount == 'W2') {
        expect(points.single.dy, lessThan(g.position.dy));
      } else if (mount == 'W3') {
        expect(points.every((at) => at.dy > g.position.dy), isTrue);
      } else {
        expect((points.single - g.position).distance, closeTo(52, 1e-8));
      }
      g.enemies.add(Foe(points.first, 10000, 0, 12, 0));
      g.update(.01);
      expect(g.droneHealth(mount, 0), lessThan(g.partStats(mount).droneHealth));
      final copy = BattleCheckpoint.restore(
        jsonDecode(jsonEncode(g.checkpoint())),
      );
      expect(copy.droneHealth(mount, 0), g.droneHealth(mount, 0));
    }
  });
  testWidgets(
    'part growth card, details and statistics accept the actual mounted skill id',
    (tester) async {
      final g = arena('W3');
      g.choices = [
        const UpgradeChoice(
          'enh|part:W3',
          '발칸 건',
          '강화 1/3 · 피해 +25%',
          'part:W3',
          growth: 'enh',
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpgradeSlots(
              game: g,
              onChoose: g.chooseUpgrade,
              onReroll: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('upgrade-enh|part:W3')));
      expect(g.enh('part:W3'), 1);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BattleLoadoutDetails(game: g)),
        ),
      );
      await tester.pumpAndSettle();
      expect(g.combatSkill('part:W3').name, contains('발칸 건'));
      expect(g.evolutionHint('part:W3'), contains('장착 파츠'));
      expect(g.synergyDetails.join(), contains('W3'));
      expect(tester.takeException(), isNull);
      // A real chest grants one free weapon growth step (v12).
      g.choices = [];
      g.supplies.add(Supply(g.position, 3));
      g.update(.01);
      expect(g.pickupNotice, contains('무기 성장'));
      final report = BattleStatisticsSnapshot.fromGame(g);
      expect(report.weapons.any((w) => w.name.contains('발칸 건')), isTrue);
    },
  );
  testWidgets(
    '320px unified seven slots, picker, mount stats, move and eye geometry',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = await Profile.load();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ModuleWorkshop(profile: p, embedded: true)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GameItemSlot), findsNWidgets(7));
      await tapUi(tester, find.bySemanticsLabel('W1 모듈 편집'));
      await tester.pumpAndSettle();
      final id = p.moduleLoadout.parts['W1']!.instanceId;
      await tapUi(tester, find.byKey(ValueKey('module-item-$id')));
      await tester.pumpAndSettle();
      expect(find.textContaining('전방 ±15°'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('닫기').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('닫기').last);
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ModuleAircraftPreview(
                profile: p,
                width: 160,
                height: 232,
                onSelectShip: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lobby-slot-eye')));
      await tester.pumpAndSettle();
      for (final id in ['W1', 'W2', 'W3', 'W4'])
        expect(find.byKey(ValueKey('module-socket-$id-0')), findsOneWidget);
      expect(find.byKey(const Key('module-socket-W1-1')), findsOneWidget);
      for (final id in ['S1', 'S2', 'S3'])
        expect(find.bySemanticsLabel('$id 보조 슬롯'), findsOneWidget);
      final rects = [
        for (final id in ['W2', 'W3', 'W4'])
          tester.getRect(find.byKey(ValueKey('module-socket-$id-0'))),
      ];
      for (var i = 0; i < rects.length; i++)
        for (var j = 0; j < i; j++)
          expect(rects[i].overlaps(rects[j]), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
  test('render layered top view, empty sockets and gun variants', () async {
    final recorder = ui.PictureRecorder(),
        canvas = Canvas(ui.PictureRecorder());
    // One figure shows identical gun sprites in all physical mount positions.
    final c = Canvas(recorder)
      ..drawColor(const Color(0xff23384e), BlendMode.src);
    for (var i = 0; i < 4; i++) {
      final m = moduleProfiles[i];
      final snap = ModuleSnapshot(i % 3, 1, {
        m.id: const OwnedModulePart('same', 'gun_vulcan', 3),
      });
      ModuleAircraftArt.paint(c, Offset(130 + i * 260, 160), 230, snap);
    }
    final picture = recorder.endRecording(),
        image = await picture.toImage(1040, 330);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    Directory('.local/module-v66').createSync(recursive: true);
    File('.local/module-v66/mount-variants.png')
        .writeAsBytesSync(bytes.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
