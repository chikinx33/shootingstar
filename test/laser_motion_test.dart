import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/data/aircraft_assembly.dart';
import 'package:shootingstar/game/battle_painter.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/game/laser_beam.dart';

GameEngine arena({bool empty = false}) => GameEngine(
  stageIndex: 0,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
  seed: 56,
  aircraft: AircraftAssembly(
    parts: empty ? const {} : const {AircraftMount.main: 'cannon'},
  ),
)..xpNeeded = 1e8;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'laser light grows from a hairline, glows, and collapses to nothing',
    () async {
      final recorder = ui.PictureRecorder();
      final c = ui.Canvas(recorder);
      c.drawColor(const ui.Color(0xff182838), ui.BlendMode.src);
      final ages = [0.0, .02, .08, .20, .285, .30];
      for (var i = 0; i < ages.length; i++) {
        final x = 60.0 + i * 120;
        LaserBeam.paint(
          c,
          ui.Offset(x, 280),
          ui.Offset(x, 30),
          70,
          age: ages[i],
          duration: .30,
        );
      }
      final picture = recorder.endRecording(),
          image = await picture.toImage(720, 320);
      final raw = (await image.toByteData())!.buffer.asUint8List();
      final spans = <int>[];
      for (var i = 0; i < ages.length; i++) {
        var bright = 0;
        for (var x = i * 120; x < (i + 1) * 120; x++) {
          if (raw[(150 * 720 + x) * 4 + 2] > 76) bright++;
        }
        spans.add(bright);
      }
      expect(spans[1], greaterThan(spans[0]));
      expect(spans[2], greaterThan(spans[1]));
      expect(spans[4], lessThan(spans[2] / 4));
      expect(spans[5], 0);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      Directory('.local/feedback-v56').createSync(recursive: true);
      File('.local/feedback-v56/laser-phases.png')
          .writeAsBytesSync(png.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    },
  );
  test('level-up protection is silent, genuine damage flashes, and old checkpoints stay compatible', () {
    final g = arena()..xp = 1e8;
    // Drafts open when a gem reaches the cat (v12.4.1).
    g.crystals.add(g.position);
    g.update(.001);
    expect(g.choices, isNotEmpty);
    g.visuals.kick('main', const ui.Offset(0, 6));
    g.visuals.advance(.025);
    g.chooseUpgrade(g.choices.first.id);
    expect(g.hurtFlash, 0);
    expect(g.visuals.recoil('main'), ui.Offset.zero);
    final hp = g.hp;
    g.shots.add(Shot(g.position, ui.Offset.zero, 5, 4));
    g.update(.025);
    expect(g.hp, hp);
    for (var i = 0; i < 40; i++) {
      g.update(.025);
    }
    g.shots.add(Shot(g.position, ui.Offset.zero, 5, 4));
    g.update(.025);
    expect(g.hp, lessThan(hp));
    expect(g.hurtFlash, greaterThan(0));
    final saved = jsonDecode(jsonEncode(g.checkpoint())) as Map;
    expect(BattleCheckpoint.restore(saved).hurtFlash, g.hurtFlash);
    (saved['state'] as Map).remove('_damageFlash');
    expect(BattleCheckpoint.restore(saved).hurtFlash, 0);
    g.choices = [const UpgradeChoice('gun', 'gun', 'gun', 'gun')];
    g.chooseUpgrade('gun');
    expect(g.hurtFlash, 0);
  });
  test('weapon recoil never translates the aircraft hull or camera', () async {
    final g = arena(empty: true);
    Future<List<int>> pixels() async {
      final r = ui.PictureRecorder();
      BattlePainter(g).paint(ui.Canvas(r), const ui.Size(320, 568));
      final p = r.endRecording(), im = await p.toImage(320, 568);
      final data = (await im.toByteData())!.buffer.asUint8List().toList();
      im.dispose();
      p.dispose();
      return data;
    }

    final before = await pixels(), position = g.position, camera = g.camera;
    g.visuals.kick('main', const ui.Offset(0, 6));
    g.visuals.advance(.025);
    expect(await pixels(), before);
    expect(g.position, position);
    expect(g.camera, camera);
  });
}
