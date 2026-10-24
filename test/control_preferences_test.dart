import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/control_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/ui/control_settings_screen.dart';
import 'package:shootingstar/ui/compact_choice.dart';

import 'ui_actions.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('default steering matches existing floating anchor, threshold and fast direction reversal', () {
    const prefs = ControlPreferences();
    expect(prefs.radius, 45);
    expect(prefs.threshold, 5);
    expect(prefs.steer(Offset.zero, const Offset(4, 0)).input, Offset.zero);
    final first = prefs.steer(Offset.zero, const Offset(240, 0));
    expect(first.input, const Offset(1, 0));
    expect(first.anchor, const Offset(195, 0));
    final second = prefs.steer(first.anchor, const Offset(180, 0));
    // v12.4 precision curve: a third of the reach gives (1/3)^1.4 input
    expect(second.input.dx, closeTo(-math.pow(1 / 3, 1.4), 1e-10));
    expect(prefs.followTouch, isTrue);
  });
  test('all sensitivity/dead-zone combinations preserve unit input bounds and reject nonfinite coordinates', () {
    for (var sensitivity = 0; sensitivity < 3; sensitivity++)
      for (var deadZone = 0; deadZone < 3; deadZone++) {
        final p = ControlPreferences(
          sensitivity: sensitivity,
          deadZone: deadZone,
        );
        for (final point in const [
          Offset.zero,
          Offset(1, 1),
          Offset(10, -12),
          Offset(-500, 500),
          Offset(1000000, 0),
        ]) {
          expect(
            p.steer(Offset.zero, point).input.distance,
            lessThanOrEqualTo(1.00000001),
          );
        }
        expect(
          p.steer(Offset.zero, const Offset(double.nan, 1)).input,
          Offset.zero,
        );
      }
    expect(
      ControlPreferences.restore({'sensitivity': 99, 'deadZone': -1}).toJson(),
      const ControlPreferences().toJson(),
    );
  });
  test('controls survive save/reload and can reset without changing progression or reward values', () async {
    final p = await Profile.load();
    p.updateControls(
      const ControlPreferences(sensitivity: 2, deadZone: 2, leftActions: true),
    );
    await p.save();
    final restored = await Profile.load();
    expect(restored.controls.sensitivity, 2);
    expect(restored.controls.leftActions, true);
    expect(restored.credits, 150);
    expect(restored.runs, 0);
    restored.updateControls(const ControlPreferences());
    expect(restored.controls.radius, 45);
    p.dispose();
    restored.dispose();
  });
  for (final width in [320.0, 360.0, 390.0, 430.0])
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'control choices and rehearsal stay fixed at $width / $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final p = await Profile.load();
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: ControlSettingsScreen(profile: p),
            ),
          );
          await tester.pumpAndSettle();
          final short = find.byWidgetPredicate(
            (w) => w is GameCompactChoice && w.title == '빠르게',
          );
          await revealUi(tester, short);
          await tester.tapAt(tester.getCenter(short));
          await tester.pumpAndSettle();
          expect(p.controls.sensitivity, 2);
          final pad = find.byKey(const Key('steering-test-pad'));
          await revealUi(tester, pad);
          await tester.drag(pad, const Offset(40, 0));
          await tester.pumpAndSettle();
          final left = find.byWidgetPredicate(
            (w) => w is GameCompactChoice && w.title == '왼쪽',
          );
          await revealUi(tester, left);
          await tester.tapAt(tester.getCenter(left));
          await tester.pumpAndSettle();
          expect(p.controls.leftActions, true);
          // v12.4.3: explanations moved from the page into the guide popup.
          await tester.tap(find.byKey(const Key('control-guide')));
          await tester.pumpAndSettle();
          expect(find.text('조작 안내'), findsOneWidget);
          await tester.tap(find.byTooltip('닫기'));
          await tester.pumpAndSettle();
          expect(find.text('조작 안내'), findsNothing);
          expect(p.credits, 150);
          expect(find.byType(Scrollable), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          p.dispose();
        },
      );
    }
}
