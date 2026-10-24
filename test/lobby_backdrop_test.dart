import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/art/refit_art.dart';
import 'package:shootingstar/art/flight_scene_art.dart';

void main() {
  Finder getPaint() => find.byKey(const Key('lobby-drifting-background'));
  double clock(WidgetTester t) =>
      (t.widget<CustomPaint>(getPaint()).painter! as RefitBackdropPainter)
          .clock!
          .value;
  Future<void> frames(WidgetTester t, [int count = 60]) async {
    for (var i = 0; i < count; i++) {
      await t.pump(const Duration(microseconds: 16667));
    }
  }

  testWidgets('slow paint clock keeps foreground fixed and interactive', (
    t,
  ) async {
    var builds = 0, taps = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RefitBackdrop(
            launch: true,
            child: Builder(
              builder: (_) {
                builds++;
                return Center(
                  child: FilledButton(
                    onPressed: () => taps++,
                    child: const Text('fixed action'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    final rect = t.getRect(find.byType(FilledButton));
    await frames(t);
    expect(clock(t), closeTo(.35, .01));
    expect(builds, 1, reason: 'Decorative ticks never rebuild controls');
    expect(t.getRect(find.byType(FilledButton)), rect);
    await t.tap(find.byType(FilledButton));
    expect(taps, 1);
    // Delayed frames cannot fast-forward the scenery.
    final before = clock(t);
    await t.pump(const Duration(seconds: 5));
    expect(clock(t) - before, lessThanOrEqualTo(.01751));
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });

  testWidgets('route cover and app background freeze then resume in place', (
    t,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(
          body: RefitBackdrop(launch: true, child: SizedBox.expand()),
        ),
      ),
    );
    await frames(t, 10);
    final before = clock(t);
    navigator.currentState!.push(
      DialogRoute<void>(
        context: navigator.currentContext!,
        builder: (_) => const Center(child: Text('modal')),
      ),
    );
    await t.pumpAndSettle();
    final covered = clock(t);
    await frames(t);
    expect(clock(t), covered);
    expect(covered - before, lessThan(.04));
    navigator.currentState!.pop();
    await t.pump();
    await frames(t, 25);
    expect(clock(t), greaterThan(covered));
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final paused = clock(t);
    await frames(t);
    expect(clock(t), paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(t, 10);
    expect(clock(t), greaterThan(paused));
    expect(clock(t) - paused, lessThan(.07));
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'reduced effects, system motion, tabs and ticker mode stop clock',
    (t) async {
      Future<void> mount({
        bool launch = true,
        bool motion = true,
        bool systemReduced = false,
        bool ticker = true,
      }) => t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: systemReduced),
            child: TickerMode(
              enabled: ticker,
              child: RefitBackdrop(
                launch: launch,
                motionEnabled: motion,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await mount();
      await frames(t, 10);
      final before = clock(t);
      for (final options in [0, 1, 2, 3]) {
        await mount(
          launch: options != 0,
          motion: options != 1,
          systemReduced: options == 2,
          ticker: options != 3,
        );
        await frames(t, 10);
        expect(clock(t), before, reason: 'stop reason $options');
      }
      await mount();
      await frames(t, 10);
      expect(clock(t), greaterThan(before));
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    },
  );

  test(
    'mirrored lobby scenery is continuous across both tile boundaries',
    () async {
      final old = FlightSceneArt.image;
      final recording = ui.PictureRecorder();
      final canvas = Canvas(recording);
      for (var y = 0; y < 4; y++) {
        canvas.drawRect(
          Rect.fromLTWH(0, y.toDouble(), 4, 1),
          Paint()
            ..color = [Colors.red, Colors.green, Colors.blue, Colors.white][y],
        );
      }
      final picture = recording.endRecording();
      final art = await picture.toImage(4, 4);
      picture.dispose();
      FlightSceneArt.image = art;
      try {
        Future<List<int>> pixels(double time) async {
          final r = ui.PictureRecorder();
          FlightSceneArt.paint(
            Canvas(r),
            const Size(40, 60),
            lobby: true,
            time: time,
          );
          final p = r.endRecording(), image = await p.toImage(40, 60);
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final bytes = data!.buffer.asUint8List().toList();
          image.dispose();
          p.dispose();
          return bytes;
        }

        for (final boundary in [15.0, 30.0]) {
          final a = await pixels(boundary - .001),
              b = await pixels(boundary + .001);
          var difference = 0;
          for (var i = 0; i < a.length; i++) {
            difference += (a[i] - b[i]).abs();
          }
          expect(
            difference / a.length,
            lessThan(1),
            reason: 'tile boundary $boundary',
          );
        }
      } finally {
        FlightSceneArt.image = old;
        art.dispose();
      }
    },
  );
}
