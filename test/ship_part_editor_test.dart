import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/ship_layout_store.dart';
import 'package:shootingstar/data/ship_part_layout.dart';
import 'package:shootingstar/ui/ship_part_editor_screen.dart';

ShipLayoutBook bundled() => ShipLayoutBook.fromJson(
  jsonDecode(File('assets/data/ship_layouts.json').readAsStringSync())
      as Map<String, dynamic>,
);

Future<ShipLayout> savedShip() async {
  final raw = (await SharedPreferences.getInstance()).getString(
    shipLayoutsStorageKey,
  )!;
  return ShipLayoutBook.fromJson(jsonDecode(raw) as Map<String, dynamic>)
      .ships['sunshine']!;
}

Future<void> openEditor(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ShipPartEditorScreen()));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
}

Future<void> pick(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('ship-editor-layer')));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text(label));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('ship-editor-save')));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
}

void main() {
  test('bundled Sunshine: pairs mirror, flames ride their thruster', () {
    final ship = bundled().ships['sunshine']!;
    for (final pair in ['wing', 'engine', 'missile', 'gun', 'flame']) {
      final left = ship.layer('${pair}_l')!;
      final right = ship.resolved.firstWhere((l) => l.id == '${pair}_r');
      expect(ship.layer('${pair}_r')!.mirrorOf, '${pair}_l');
      expect(right.x, -left.x);
      expect(right.flipX, !left.flipX);
    }
    expect(ship.layer('flame_l')!.attachTo, 'engine_l');
    expect(ship.layer('canopy')!.attachTo, 'base');
    for (final l in ship.layers) {
      for (final asset in [l.asset, ...l.frames]) {
        expect(File(asset).existsSync(), isTrue, reason: asset);
      }
    }
    // The canopy (cat) draws above the armour so the pilot stays visible.
    expect(ship.layer('canopy')!.z, greaterThan(ship.layer('armor')!.z));
  });

  test('moving the pivot keeps a rotated sprite in place', () {
    const layer = ShipPartLayer(
      id: 'a',
      label: 'a',
      asset: 'x',
      aspect: 2,
      x: .1,
      y: -.2,
      width: .3,
      rotation: 37,
    );
    final corner = layer.canvasPoint(0, 0);
    final after = layer.withPivot(.2, .9).canvasPoint(0, 0);
    expect(after.dx, closeTo(corner.dx, 1e-9));
    expect(after.dy, closeTo(corner.dy, 1e-9));
  });

  test('an attached flame follows its thruster moving and growing', () {
    final ship = bundled().ships['sunshine']!;
    final engine = ship.layer('engine_l')!, flame = ship.layer('flame_l')!;
    final moved = ship.update(
      engine.copyWith(x: engine.x - .05, y: engine.y + .02),
    );
    expect(moved.layer('flame_l')!.x, closeTo(flame.x - .05, 1e-9));
    expect(moved.layer('flame_l')!.y, closeTo(flame.y + .02, 1e-9));
    final grown = ship.update(engine.copyWith(width: engine.width * 2));
    expect(grown.layer('flame_l')!.width, closeTo(flame.width * 2, 1e-9));
  });

  test('the store loads the newest revision and saves the next one', () async {
    SharedPreferences.setMockInitialValues({
      shipLayoutsStorageKey: jsonEncode(
        ShipLayoutBook(revision: 99, ships: bundled().ships).toJson(),
      ),
    });
    const store = ShipLayoutStore();
    final load = await store.load();
    expect(load.book.revision, 99);
    expect(load.source, ShipLayoutSource.browser);
    final saved = await store.save(load.book);
    expect(saved.book.revision, 100);
    expect(saved.project, isFalse); // tests are not the loopback preview
  });

  testWidgets('a pair is one entry and moves as a mirror image', (
    tester,
  ) async {
    await openEditor(tester, const Size(360, 640));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('ship-editor-layer')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('(오른쪽)'), findsNothing);
    await tester.tap(find.text('날개 · 좌우 함께'));
    await tester.pump(const Duration(milliseconds: 400));
    final start = bundled().ships['sunshine']!.layer('wing_l')!;

    await tester.tap(find.text('바깥쪽으로 ←→'));
    await tester.pump();
    await tester.tap(find.text('↑ 위로'));
    await tester.pump();
    await save(tester);

    final ship = await savedShip();
    final left = ship.layer('wing_l')!;
    final right = ship.resolved.firstWhere((l) => l.id == 'wing_r');
    expect(left.x, closeTo(start.x - .005, 1e-6)); // left went further left
    expect(right.x, closeTo(-left.x, 1e-9)); // right went further right
    expect(left.y, closeTo(start.y - .005, 1e-6)); // both went up
    expect(right.y, left.y);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unlinking lets one side move alone', (tester) async {
    await openEditor(tester, const Size(390, 844));
    await pick(tester, '미사일 · 좌우 함께');
    await tester.tap(find.byKey(const Key('ship-editor-tab-order')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ship-editor-link')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ship-editor-tab-move')));
    await tester.pump();
    await tester.tap(find.text('↓ 아래로'));
    await tester.pump();
    await save(tester);
    final ship = await savedShip();
    expect(ship.layer('missile_r')!.mirrorOf, isNull);
    expect(ship.layer('missile_l')!.y, isNot(ship.layer('missile_r')!.y));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping empty background clears the selection; zoom steps', (
    tester,
  ) async {
    await openEditor(tester, const Size(390, 844));
    expect(find.text('80%'), findsOneWidget);
    final canvas = tester.getRect(find.byKey(const Key('ship-editor-canvas')));
    await tester.tapAt(canvas.bottomRight - const Offset(8, 8));
    await tester.pump();
    expect(find.byKey(const Key('ship-editor-no-selection')), findsOneWidget);
    await tester.tap(find.byTooltip('작게 보기'));
    await tester.pump();
    expect(find.text('70%'), findsOneWidget);
    // with nothing selected a drag moves the view, not a part
    await tester.drag(
      find.byKey(const Key('ship-editor-canvas')),
      const Offset(30, 0),
    );
    await tester.pump();
    expect(find.text('저장'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
