import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shootingstar/art/game_backdrop.dart';
import 'package:shootingstar/art/flight_scene_art.dart';

void main() {
  testWidgets('still living room keeps foreground fixed and interactive', (
    t,
  ) async {
    var builds = 0, taps = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameBackdrop(
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
    // Settles at once: a still picture has no lobby clock to keep ticking.
    await t.pumpAndSettle();
    // The room finishing its decode repaints the picture, not the controls.
    FlightSceneArt.lobbyRevision.value++;
    await t.pump();
    expect(builds, 1);
    expect(t.getRect(find.byType(FilledButton)), rect);
    await t.tap(find.byType(FilledButton));
    expect(taps, 1);
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });

  test('lobby paints the living room once it is decoded', () async {
    final old = FlightSceneArt.lobbyHome;
    final recording = ui.PictureRecorder();
    Canvas(recording).drawRect(
      const Rect.fromLTWH(0, 0, 4, 4),
      Paint()..color = const Color(0xFFFF0000),
    );
    final picture = recording.endRecording();
    final room = await picture.toImage(4, 4);
    picture.dispose();
    Future<List<int>> centre() async {
      final r = ui.PictureRecorder();
      GameBackdropPainter(true).paint(Canvas(r), const Size(40, 60));
      final p = r.endRecording(), image = await p.toImage(40, 60);
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      image.dispose();
      p.dispose();
      final i = (30 * 40 + 20) * 4;
      return data.sublist(i, i + 4);
    }

    try {
      FlightSceneArt.lobbyHome = null;
      expect(await centre(), [0x14, 0x22, 0x36, 255]);
      FlightSceneArt.lobbyHome = room;
      expect(await centre(), [255, 0, 0, 255]);
    } finally {
      FlightSceneArt.lobbyHome = old;
      room.dispose();
    }
  });
}
