import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/content_systems.dart';
import 'package:shootingstar/data/fleet_journal.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/components.dart';
import 'package:shootingstar/ui/fleet_activity_screen.dart';

import 'ui_actions.dart';

import 'package:shootingstar/l10n/app_language.dart';
import 'package:shootingstar/art/lobby_art.dart';

void main() {
  testWidgets(
    '320px activity categories isolate lists and preserve earned claims',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await (FontLoader(
        'NotoSansKR',
      )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      p.soundEnabled = false;
      p.refreshContentClock(DateTime.now());
      p.dailyRuns = 1;
      final theme = (ShootingstarApp(
        profile: p,
      ).build(t.element(find.byType(View))) as MaterialApp).theme;
      await t.pumpWidget(
        LanguageScope(
          child: MaterialApp(
            theme: theme,
            home: FleetActivityScreen(profile: p, initialPage: 1),
          ),
        ),
      );
      await t.pumpAndSettle();
      Future<void> category(String name) async {
        final root = ['출석', '임무', '항로', '순찰'].indexOf(name);
        await t.tap(
          root >= 0
              ? find.byKey(ValueKey('activity-tab-$root'))
              : find.widgetWithText(ChoiceChip, name),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }

      Finder action(String name) => find.byWidgetPredicate(
        (w) => w is GameActionButton && w.label == name,
      );
      // Actual constrained text must fit each deliberate fact on one line.
      void checkBriefCopy() {
        for (final element in find.byType(Text).evaluate()) {
          final text = element.widget as Text;
          final copy = text.data;
          if (copy == null || element.size == null) continue;
          // Reward-grid entries are item lists, not brief action/guide copy.
          if (element.findAncestorWidgetOfExactType<Wrap>() != null) continue;
          final style = DefaultTextStyle.of(element).style.merge(text.style);
          final painter = TextPainter(
            text: TextSpan(text: copy, style: style),
            textDirection: TextDirection.ltr,
            textScaler: MediaQuery.textScalerOf(element),
          )..layout(maxWidth: element.size!.width);
          expect(
            painter.computeLineMetrics().length,
            copy.split('\n').length,
            reason: 'Unexpected wrapping: $copy',
          );
          painter.dispose();
        }
      }

      void checkIconRow() {
        final boxes = [
          for (var i = 0; i < 4; i++)
            t.getRect(find.byKey(ValueKey('activity-tab-$i'))),
        ];
        for (var i = 0; i < 4; i++) {
          expect(boxes[i].top, boxes.first.top);
          expect(boxes[i].height, greaterThanOrEqualTo(48));
          expect(boxes[i].width, greaterThanOrEqualTo(48));
          if (i > 0)
            expect(boxes[i].left, greaterThanOrEqualTo(boxes[i - 1].right));
        }
        expect(boxes.last.right, lessThanOrEqualTo(320));
        expect(
          find.descendant(
            of: find.byType(FleetActivityTabs),
            matching: find.byType(LobbyIcon),
          ),
          findsNWidgets(4),
        );
      }

      checkIconRow();
      checkBriefCopy();
      expect(find.text(ContentSystems.dailyNames.first), findsOneWidget);
      expect(find.text('주간 임무'), findsNothing);
      expect(action('일일 활동 상자 1'), findsNothing);
      final fixed = t.getRect(find.widgetWithText(ChoiceChip, '주간'));
      await t.drag(find.byType(ListView), const Offset(0, -500));
      await t.pumpAndSettle();
      expect(t.getRect(find.widgetWithText(ChoiceChip, '주간')), fixed);
      await category('주간');
      expect(find.text(FleetJournal.weeklyNames.first), findsOneWidget);
      expect(find.text(ContentSystems.dailyNames.first), findsNothing);
      expect(t.getTopLeft(find.text('주간 임무')).dy, lessThan(240));
      checkBriefCopy();
      await category('일일');
      final before = p.credits;
      await tapUi(t, action('일일 임무 1 보상 받기'));
      await tapUi(t, action('확인'));
      expect(p.credits, before + 50);
      expect(p.dailyClaims, contains(0));
      expect(find.text('수령 완료'), findsOneWidget);
      checkBriefCopy();
      await category('상자');
      expect(find.text('일일 활동 상자'), findsOneWidget);
      checkBriefCopy();
      expect(action('일일 임무 2 보상 받기'), findsNothing);
      await tapUi(t, action('일일 활동 상자 1'));
      await tapUi(t, action('확인'));
      expect(p.journal.dailyChests, contains(0));
      await category('주간 상자');
      expect(find.text('주간 활동 상자'), findsOneWidget);
      checkBriefCopy();
      expect(find.text('일일 활동 상자'), findsNothing);
      await category('일일');
      expect(p.claimDaily(0), isFalse);
      expect(p.claimDailyActivity(0), isFalse);
      await category('출석');
      expect(action('오늘 출석 보상 받기'), findsOneWidget);
      checkBriefCopy();
      await category('누적 출석');
      expect(action('오늘 출석 보상 받기'), findsNothing);
      expect(find.text('누적 출석 상자'), findsOneWidget);
      await category('순찰');
      expect(action('순찰 보상 회수'), findsOneWidget);
      expect(action('빠른 순찰 보상 받기'), findsNothing);
      checkBriefCopy();
      await category('빠른 순찰');
      expect(action('순찰 보상 회수'), findsNothing);
      expect(action('빠른 순찰 보상 받기'), findsOneWidget);
      checkBriefCopy();
      AppLanguage.instance.select('en');
      await t.pumpAndSettle();
      checkIconRow();
      for (final label in ['Check-in', 'Missions', 'Routes', 'Patrol']) {
        final f = find.descendant(
          of: find.byType(FleetActivityTabs),
          matching: find.text(label),
        );
        expect(f, findsOneWidget);
        expect(t.getSize(f).height, lessThan(20));
      }
      AppLanguage.instance.select('ko');
      await t.pumpAndSettle();
      await p.save();
      final restored = await Profile.load();
      expect(restored.dailyClaims, contains(0));
      expect(restored.journal.dailyChests, contains(0));
      await t.pumpWidget(const SizedBox());
      p.dispose();
      restored.dispose();
    },
  );
}
