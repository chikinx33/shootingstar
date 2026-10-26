import 'package:flutter_test/flutter_test.dart';
import 'support/tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/settings_screen.dart';
import 'package:shootingstar/ui/fleet_activity_screen.dart';
import 'package:shootingstar/ui/battle.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/data/content.dart';
import 'package:shootingstar/game/survival_skills.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/l10n/app_language.dart';
import 'package:shootingstar/l10n/english_catalog.dart';
import 'package:shootingstar/data/profile.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguage.instance.load();
  });
  tearDown(() async {
    await AppLanguage.instance.load();
  });

  test(
    'catalog templates preserve all values without Korean leakage',
    () async {
      await AppLanguage.instance.select('en');
      final token = RegExp(r'\{(\d+)\}');
      for (final entry in englishCatalog.entries) {
        final input = entry.key.replaceAllMapped(token, (m) => 'VALUE${m[1]}');
        final expected = entry.value.replaceAllMapped(
          token,
          (m) => 'VALUE${m[1]}',
        );
        final indices = token
            .allMatches(entry.key)
            .map((m) => int.parse(m[1]!))
            .toList();
        final values = List.generate(
          indices.isEmpty ? 0 : indices.reduce((a, b) => a > b ? a : b) + 1,
          (i) => 'VALUE$i',
        );
        expect(message(entry.key, values), expected, reason: entry.key);
        if (!RegExp(r'[가-힣]').hasMatch(expected)) {
          expect(RegExp(r'[가-힣]').hasMatch(tr(input)), isFalse, reason: input);
        }
        expect(
          token.allMatches(entry.value).map((m) => m[1]).toSet(),
          token.allMatches(entry.key).map((m) => m[1]).toSet(),
          reason: entry.key,
        );
      }
      expect(tr('성운 수문장 선체 · Lv.3'), 'Nebula guardian hull · Lv.3');
      expect(tr('잔광 외곽 1-1'), 'Starlight outskirts 1-1');
      expect(tr('50 츄르 · 별가루 3 · 먹이 5'), '50 Churu · Stardust 3 · Food 5');
      expect(tr('한글사용자이름'), '한글사용자이름');
      for (final name in [
        ...stages.map((s) => s.name),
        ...worlds.map((w) => w.name),
        ...armaments.map((a) => a.name),
        ...survivalSkills.map((s) => s.name),
      ]) {
        expect(RegExp(r'[가-힣]').hasMatch(tr(name)), isFalse, reason: name);
      }
    },
  );

  test(
    'language persists separately from progress and last rapid choice wins',
    () async {
      final profile = await Profile.load();
      final before = profile.exportProgress();
      expect(AppLanguage.instance.code, 'ko');
      await AppLanguage.instance.select('en');
      expect(profile.exportProgress(), before);
      await AppLanguage.instance.load();
      expect(AppLanguage.instance.code, 'en');
      final a = AppLanguage.instance.select('ko');
      final b = AppLanguage.instance.select('en');
      await Future.wait([a, b]);
      await AppLanguage.instance.load();
      expect(AppLanguage.instance.code, 'en');
      await AppLanguage.instance.select('unknown');
      expect(AppLanguage.instance.code, 'en');
      expect(profile.exportProgress(), before);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppLanguage.storageKey, 'invalid');
      await AppLanguage.instance.load();
      expect(AppLanguage.instance.code, 'ko');
      profile.dispose();
    },
  );
  testWidgets('320px live language switch keeps routes, tab and battle state', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await (FontLoader(
      'NotoSansKR',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR.ttf'))).load();
    final p = await Profile.load();
    p.onboarded = true;
    p.reducedEffects = true;
    p.soundEnabled = false;
    final before = p.exportProgress();
    final app = ShootingstarApp(
      profile: p,
    ).build(t.element(find.byType(View))) as MaterialApp;
    var fontScale = 1.0;
    Widget mount(Widget home) => LanguageScope(
      child: MaterialApp(
        theme: app.theme,
        home: home,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(fontScale)),
          child: child!,
        ),
      ),
    );
    await t.pumpWidget(mount(FlightSettings(profile: p)));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('language-en')));
    await t.pumpAndSettle();
    expect(find.text('Options'), findsOneWidget);
    expect(find.text('Music\n50%'), findsOneWidget);
    expect(find.byType(Scrollable), findsNothing);
    expect(t.getRect(find.byType(Dialog)).bottom, lessThanOrEqualTo(568));
    expect(t.takeException(), isNull);
    // The English header and menu words must stay whole at large text too.
    fontScale = 1.3;
    await t.pumpWidget(mount(FlightSettings(profile: p)));
    await t.pumpAndSettle();
    for (final label in ['Options', 'Profile', 'Input', 'Legal']) {
      final text = t.widget<Text>(find.text(label));
      final element = t.element(find.text(label));
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: DefaultTextStyle.of(element).style.merge(text.style),
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.linear(fontScale),
      )..layout(maxWidth: t.getSize(find.text(label)).width);
      expect(painter.computeLineMetrics().length, 1, reason: label);
      painter.dispose();
    }
    expect(t.getRect(find.byType(Dialog)).bottom, lessThanOrEqualTo(568));
    expect(t.takeException(), isNull);
    fontScale = 1;
    await t.pumpWidget(mount(FlightSettings(profile: p)));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('language-ko')));
    await t.pumpAndSettle();
    expect(find.text('옵션'), findsOneWidget);
    expect(p.exportProgress(), before);

    await t.pumpWidget(mount(FleetActivityScreen(profile: p, initialPage: 1)));
    await t.pumpAndSettle();
    await t.tap(tabWithText('주간'));
    await t.pumpAndSettle();
    AppLanguage.instance.select('en');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('weekly-chests')), findsOneWidget);
    expect(tabWithText('Weekly'), findsOneWidget);
    for (final label in ['Check-in', 'Missions', 'House', 'Patrol']) {
      final textFinder = find.descendant(
        of: find.byType(FleetActivityTabs),
        matching: find.text(label),
      );
      expect(textFinder, findsOneWidget);
      final text = t.widget<Text>(textFinder);
      final element = t.element(textFinder);
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: DefaultTextStyle.of(element).style.merge(text.style),
        ),
        textDirection: TextDirection.ltr,
        textScaler: const TextScaler.linear(1),
      )..layout(maxWidth: t.getSize(textFinder).width);
      expect(painter.computeLineMetrics().length, 1, reason: label);
      painter.dispose();
    }

    expect(t.takeException(), isNull);

    int creations = 0;
    final game = GameEngine(
      stageIndex: 0,
      shipIndex: 0,
      attackLevel: 0,
      hullLevel: 0,
      magnetLevel: 0,
      equipmentIndex: 0,
      seed: 17,
    );
    game.paused = true;
    game.kills = 12;
    game.elapsed = 42;
    await t.pumpWidget(
      mount(
        BattleScreen(
          profile: p,
          engineFactory: () {
            creations++;
            return game;
          },
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 32));
    final state = t.state(find.byType(BattleScreen));
    AppLanguage.instance.select('ko');
    await t.pump(const Duration(milliseconds: 32));
    expect(t.state(find.byType(BattleScreen)), same(state));
    expect(creations, 1);
    expect(game.kills, 12);
    expect(game.elapsed, 42);
    expect(game.paused, isTrue);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    p.dispose();
  });
}
