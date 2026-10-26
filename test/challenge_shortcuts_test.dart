import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/art/game_icons.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/l10n/app_language.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/content_hub.dart';
import 'package:shootingstar/ui/guild_screen.dart';
import 'package:shootingstar/ui/survival_meta.dart';

void main() {
  testWidgets(
    '320px challenge shortcuts stay in one row and keep destinations',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await (FontLoader(
        'NotoSansKR',
      )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
      SharedPreferences.setMockInitialValues({});
      await AppLanguage.instance.load();
      final p = await Profile.load();
      p.soundEnabled = false;
      var dailyOpened = 0;
      final theme = (ShootingstarApp(
        profile: p,
      ).build(t.element(find.byType(View))) as MaterialApp).theme;
      await t.pumpWidget(
        LanguageScope(
          child: MaterialApp(
            theme: theme,
            home: Scaffold(
              body: SurvivalMeta(
                profile: p,
                section: 3,
                onChallenge: (_) {},
                onDailyChallenge: () => dailyOpened++,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final row = find.byKey(const Key('challenge-shortcuts'));
      void checkRow(List<String> labels) {
        final boxes = [
          for (final id in ['daily', 'season', 'guild'])
            t.getRect(find.byKey(ValueKey('challenge-shortcut-$id'))),
        ];
        for (var i = 0; i < boxes.length; i++) {
          expect(boxes[i].top, boxes.first.top);
          expect(boxes[i].width, greaterThanOrEqualTo(48));
          expect(boxes[i].height, greaterThanOrEqualTo(48));
          if (i > 0)
            expect(boxes[i].left, greaterThanOrEqualTo(boxes[i - 1].right));
        }
        expect(boxes.last.right, lessThanOrEqualTo(320));
        expect(
          find.descendant(of: row, matching: find.byType(LobbyIcon)),
          findsNWidgets(3),
        );
        for (final label in labels) {
          final caption = find.descendant(of: row, matching: find.text(label));
          expect(caption, findsOneWidget);
          final paragraph = t.renderObject<RenderParagraph>(caption);
          final painter = TextPainter(
            text: paragraph.text,
            textDirection: TextDirection.ltr,
            textScaler: paragraph.textScaler,
          )..layout(maxWidth: paragraph.size.width);
          expect(painter.computeLineMetrics(), hasLength(1), reason: label);
          painter.dispose();
        }
        expect(t.takeException(), isNull);
      }

      checkRow(['일일', '시즌', '길드']);
      await t.tap(find.byKey(const ValueKey('challenge-shortcut-daily')));
      await t.pumpAndSettle();
      expect(dailyOpened, 1);
      await t.tap(find.byKey(const ValueKey('challenge-shortcut-season')));
      await t.pumpAndSettle();
      expect(t.widget<ContentHub>(find.byType(ContentHub)).initialPage, 4);
      expect(t.takeException(), isNull);
      Navigator.of(t.element(find.byType(ContentHub))).pop();
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('challenge-shortcut-guild')));
      await t.pumpAndSettle();
      expect(t.widget<GuildScreen>(find.byType(GuildScreen)).profile, same(p));
      expect(t.takeException(), isNull);
      Navigator.of(t.element(find.byType(GuildScreen))).pop();
      await t.pumpAndSettle();
      AppLanguage.instance.select('en');
      await t.pumpAndSettle();
      checkRow(['Daily', 'Season', 'Guild']);
      AppLanguage.instance.select('ko');
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
    },
  );
}
