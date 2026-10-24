import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/battle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'compact HUD preserves slots and expands flight area $size / $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final profile = await Profile.load();
          profile.onboarded = true;
          profile.soundEnabled = false;
          final game = GameEngine(
            stageIndex: 0,
            shipIndex: 0,
            attackLevel: 0,
            hullLevel: 0,
            magnetLevel: 0,
            equipmentIndex: 0,
            seed: 17,
          );
          game.waveNoticeTime = 2;
          game.upgrades.addAll({
            'missile': 3,
            'guardian': 3,
            'drone': 3,
            'ball': 3,
            'laser': 3,
            'mine': 3,
          });
          game.passives.addAll({
            'attack': 2,
            'hull': 2,
            'magnet': 2,
            'speed': 2,
            'cooldown': 2,
            'armor': 2,
          });
          final app = ShootingstarApp(
            profile: profile,
          ).build(tester.element(find.byType(View).first)) as MaterialApp;
          await tester.pumpWidget(
            MaterialApp(
              theme: app.theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: BattleScreen(profile: profile, engineFactory: () => game),
            ),
          );
          await tester.pump(const Duration(milliseconds: 32));
          final hud = tester.getRect(find.byKey(const Key('battle-hud-panel')));
          final notice = tester.getRect(
            find.byKey(const Key('battle-wave-banner')),
          );
          expect(hud.height, lessThanOrEqualTo(90));
          expect(notice.top, greaterThanOrEqualTo(hud.bottom));
          expect(notice.bottom, lessThan(size.height * .6));
          final field = tester.getRect(
            find.byKey(const Key('battle-playing-viewport')),
          );
          print(
            'HUD_COMPACT ${size.width} $scale ${hud.height} ${field.height}',
          );
          expect(notice.top, greaterThanOrEqualTo(field.top));
          expect(notice.bottom, lessThanOrEqualTo(field.bottom));
          expect(field.height, greaterThan(size.height * .75));
          expect(find.textContaining('슬로모션 5%'), findsNothing);
          expect(find.textContaining('손을 떼어'), findsNothing);
          expect(
            find.byKey(const ValueKey('combat-slot-weapon-0')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('combat-slot-passive-0')),
            findsNothing,
          );
          game.waveNoticeTime = 0;
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            tester.getRect(find.byKey(const Key('battle-playing-viewport'))),
            field,
          );
          game.elapsed = game.nextBossAt;
          game.update(.001);
          await tester.pump(const Duration(milliseconds: 16));
          expect(game.boss, isNotNull);
          expect(
            tester.getRect(find.byKey(const Key('battle-playing-viewport'))),
            field,
          );
          final before = game.combatTime;
          await tester.tap(find.byTooltip('전투 정보'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(game.paused, isTrue);
          await tester.pump(const Duration(milliseconds: 500));
          expect(game.combatTime, before);
          expect(find.text('전투 정보'), findsOneWidget);
          for (final type in ['weapon', 'passive']) {
            expect(
              tester.getSize(find.byKey(ValueKey('combat-$type-label'))).height,
              lessThan(30),
            );
            for (var slot = 0; slot < 6; slot++) {
              final box = tester.getSize(
                find.byKey(ValueKey('combat-slot-$type-$slot')),
              );
              expect(box.height, closeTo(34, .01));
              // These are decorative 28px slots inside the padded info dialog.
              expect(box.width, greaterThanOrEqualTo(34));
            }
          }
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('전투 정보 닫기'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(game.paused, isFalse);
          await tester.tap(find.byTooltip('일시정지'));
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.text('계속 비행'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          profile.dispose();
        },
      );
    }
  }
}
