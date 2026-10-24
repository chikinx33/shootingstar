import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/settings_screen.dart';
import 'package:shootingstar/ui/developer_screen.dart';
import 'package:shootingstar/ui/game_ui.dart';
import 'package:shootingstar/app_version.dart';

void main() {
  testWidgets(
    'all developer menu panels fit the smallest phone at 130 percent',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final normal = await Profile.load(),
          p = Profile.developerCopy(await Profile.load());
      final app = ShootingstarApp(
        profile: p,
      ).build(tester.element(find.byType(View).first)) as MaterialApp;
      await tester.pumpWidget(
        MaterialApp(
          theme: app.theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.3)),
            child: child!,
          ),
          home: DeveloperTestScreen(profile: p),
        ),
      );
      await tester.pumpAndSettle();
      final top = tester.getRect(find.text('테스트 메뉴'));
      for (var group = 0; group < 3; group++) {
        for (var menu = 0; menu < [6, 9, 5][group]; menu++) {
          final field = find.byWidgetPredicate(
            (w) =>
                w is DropdownButtonFormField<int> &&
                w.decoration.labelText == '테스트 메뉴',
          );
          tester.widget<DropdownButtonFormField<int>>(field).onChanged!(
            group * 100 + menu,
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'group $group menu $menu',
          );
          expect(tester.getRect(find.text('테스트 메뉴')), top);
          final labels = <String>[];
          void visit(dynamic node) {
            labels.add(node.getSemanticsData().label as String);
            node.visitChildren((dynamic child) {
              visit(child);
              return true;
            });
          }

          visit(
            tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!,
          );
          expect(
            labels.join('\n'),
            contains('테스트 메뉴'),
            reason: 'menu accessibility $group / $menu',
          );
          expect(
            find.text('테스트 출격'),
            group == 0 && menu != 5 ? findsOneWidget : findsNothing,
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
      normal.dispose();
      p.dispose();
      semanticsHandle.dispose();
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('single options board and developer lab $size scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final original = await Profile.load();
        final dev = Profile.developerCopy(original);
        final theme = (ShootingstarApp(
          profile: original,
        ).build(tester.element(find.byType(View).first)) as MaterialApp).theme;
        Future<void> mount(Widget child) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: child,
            ),
          );
          await tester.pumpAndSettle();
        }

        for (final p in [original, dev]) {
          await mount(
            Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: GameActionButton(
                    label: 'open',
                    onPressed: () => showFlightSettings(context, p),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(find.text(AppVersion.label), findsOneWidget);
          expect(find.byKey(const Key('game-page-next')), findsNothing);
          expect(find.text('2 / 2'), findsNothing);
          expect(tester.takeException(), isNull);
          if (p.developerMode) {
            expect(find.byKey(const Key('exit-developer')), findsOneWidget);
            final button = find.widgetWithText(GameActionButton, '테스트');
            final bounds = tester.getRect(button);
            expect(bounds.bottom, lessThanOrEqualTo(size.height));
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(find.byType(DeveloperTestScreen), findsOneWidget);
            expect(find.text('테스트 메뉴'), findsOneWidget);
            expect(find.text('테스트 출격'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        }
        original.dispose();
        dev.dispose();
      });
    }
  }
  testWidgets(
    '3 second hold, wrong code, unlock and lock preserve original save',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      // Static layout fixtures opt out of ambient lobby motion.
      p.reducedEffects = true;
      await tester.pumpWidget(ShootingstarApp(profile: p));
      await tester.pumpAndSettle();
      final before = jsonEncode(p.exportProgress());
      await tester.tap(find.byTooltip('설정'));
      await tester.pumpAndSettle();
      final held = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('settings-version'))),
      );
      await tester.pump(const Duration(milliseconds: 2900));
      expect(find.byType(DeveloperPasswordDialog), findsNothing);
      await tester.pump(const Duration(milliseconds: 150));
      await held.up();
      await tester.pumpAndSettle();
      expect(find.byType(DeveloperPasswordDialog), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('developer-password')),
        '1111',
      );
      await tester.tap(find.text('개발자 모드 시작'));
      await tester.pumpAndSettle();
      expect(find.text('비밀번호가 올바르지 않습니다.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('developer-password')),
        '0623',
      );
      await tester.tap(find.text('개발자 모드 시작'));
      await tester.pumpAndSettle();
      expect(find.byType(DeveloperSessionScreen), findsOneWidget);
      await tester.tap(find.byTooltip('설정').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exit-developer')));
      await tester.pumpAndSettle();
      expect(find.byType(DeveloperSessionScreen), findsNothing);
      expect(jsonEncode(p.exportProgress()), before);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
