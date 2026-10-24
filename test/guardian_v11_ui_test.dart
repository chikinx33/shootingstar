import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/ui/cat_gear_screen.dart';
import 'package:shootingstar/ui/guardian_quest_screen.dart';
import 'package:shootingstar/ui/prologue_screen.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('v11 screens fit $size at $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final p = await Profile.load();
        Future<void> mount(Widget home) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: home,
            ),
          );
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull, reason: '$home');
        }

        await mount(const PrologueScreen());
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.byKey(const Key('prologue-next')));
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
        }
        expect(find.text('수호묘, 출격!'), findsOneWidget);

        p.runs = 1; // first story step (one sortie) is ready
        await mount(GuardianQuestScreen(profile: p));
        expect(find.byKey(const Key('story-quest-title')), findsOneWidget);
        await tester.tap(find.byKey(const Key('story-quest-claim')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(p.quests.storyStep, 1);
        expect(tester.takeException(), isNull);

        await mount(Scaffold(body: CatGearScreen(profile: p)));
        expect(find.byKey(const Key('cat-gear-power')), findsOneWidget);
        await tester.tap(find.byKey(const Key('cat-gear-slot-nose')));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
