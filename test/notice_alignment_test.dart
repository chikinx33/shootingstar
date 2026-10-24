import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/ui/account_screen.dart';
import 'package:shootingstar/ui/components.dart';
import 'package:shootingstar/ui/guild_screen.dart';

void main() {
  testWidgets(
    'notices and dialog pages center visible groups and keep actions reachable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      p.soundEnabled = false;
      addTearDown(p.dispose);

      Future<void> show(Widget child) async {
        await tester.pumpWidget(
          MaterialApp(theme: ThemeData.dark(), home: child),
        );
        await tester.pump();
        await tester.pump();
      }

      void centered(double top, double bottom, Rect area) {
        expect((top + bottom) / 2, closeTo(area.center.dy, 1));
        expect(top, greaterThanOrEqualTo(area.top));
        expect(bottom, lessThanOrEqualTo(area.bottom));
        expect(tester.takeException(), isNull);
      }

      // A real full-height notice: content must center below its persistent header.
      tester.view.physicalSize = const Size(432, 932);
      await show(GuildScreen(profile: p));
      final icon = find.byWidgetPredicate(
        (w) => w is RasterIcon && w.size == 144,
      );
      centered(
        tester.getTopLeft(icon).dy,
        tester
            .getBottomLeft(
              find.byWidgetPredicate(
                (w) => w is GameActionButton && w.label == '계정 로그인 · 가입',
              ),
            )
            .dy,
        tester.getRect(find.byType(GamePages)),
      );
      expect(find.byKey(const Key('game-page-next')), findsNothing);

      await show(AccountScreen(profile: p));
      centered(
        tester
            .getTopLeft(
              find.byWidgetPredicate((w) => w is RasterIcon && w.size == 112),
            )
            .dy,
        tester.getBottomLeft(find.text('온라인 서비스를 준비하고 있습니다.')).dy,
        tester.getRect(find.byType(GamePages)),
      );

      // Compact notices center the current page and its navigation together.
      tester.view.physicalSize = const Size(320, 568);
      var accepted = false;
      await show(
        Scaffold(
          body: Center(
            child: SizedBox(
              height: 320,
              child: GamePages(
                centerContent: true,
                children: [
                  for (var i = 0; i < 3; i++)
                    SizedBox(
                      key: ValueKey('notice-$i'),
                      height: 160,
                      child: const RasterIcon(Icons.info, size: 96),
                    ),
                  GameActionButton(
                    label: '확인',
                    onPressed: () => accepted = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final pager = find.byType(GamePages);
      final footer = find.descendant(
        of: pager,
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 52,
        ),
      );
      centered(
        tester.getTopLeft(find.byKey(const ValueKey('notice-0'))).dy,
        tester.getBottomLeft(footer).dy,
        tester.getRect(pager),
      );
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('game-page-next')));
        await tester.pump();
        await tester.pump();
      }
      centered(
        tester.getTopLeft(find.byKey(const ValueKey('notice-2'))).dy,
        tester.getBottomLeft(footer).dy,
        tester.getRect(pager),
      );
      await tester.tap(find.text('확인'));
      expect(accepted, isTrue);

      // Confirmation/reward/resume dialogs share this centered, bounded panel.
      await show(
        GameDialog(
          title: '안내',
          child: const RasterIcon(Icons.info, size: 96),
          actions: [GameActionButton(label: '완료', onPressed: () {})],
        ),
      );
      final panel = tester.getRect(find.byKey(const Key('game-dialog-panel')));
      centered(panel.top, panel.bottom, const Rect.fromLTWH(0, 0, 320, 568));
      expect(find.byKey(const Key('game-page-next')), findsNothing);
      expect(find.text('완료').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
