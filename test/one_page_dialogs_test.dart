import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/tabs.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/hangar_preset.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/game/survival_skills.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/components.dart';
import 'package:shootingstar/ui/evolution_codex.dart';
import 'package:shootingstar/ui/hangar_presets.dart';
import 'package:shootingstar/ui/item_slots.dart';
import 'package:shootingstar/ui/settings_screen.dart';

import 'ui_actions.dart';

// v12.4.x (user 2026-10-25): on a normal phone these popups show on one page.
// Secondary details open from '자세히' in a second small popup.
void main() {
  setUpAll(
    () => LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks(
        ['qa-long-package'],
        List.generate(
          30,
          (i) =>
              'Paragraph $i. Permission is hereby granted, free of charge, to any person obtaining a copy of this software, to deal in the Software without restriction.',
        ).join('\n\n'),
      );
    }),
  );
  for (final (w, h) in const [(360.0, 720.0), (390.0, 844.0)]) {
    testWidgets('popups fit one page at $w x $h', (tester) async {
      tester.view.physicalSize = Size(w, h);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      p.soundEnabled = false;
      p.reducedEffects = true;
      final app = ShootingstarApp(
        profile: p,
      ).build(tester.element(find.byType(View).first)) as MaterialApp;
      Future<void> mount(Widget child) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            theme: app.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.noScaling),
              child: child!,
            ),
            home: child,
          ),
        );
        await tester.pumpAndSettle();
      }

      Finder action(String name) => find.byWidgetPredicate(
        (w) =>
            (w is GameActionButton && w.label == name) ||
            (w is GameItemSlot && w.semanticLabel == name),
      );
      Future<void> settle() async {
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
      }

      void onePage(String what, [List<Finder> visible = const []]) {
        expect(tester.takeException(), isNull, reason: what);
        expect(find.byType(GameDialog), findsWidgets, reason: what);
        expect(
          find.byKey(const Key('game-page-next')),
          findsNothing,
          reason: '$what must fit one page at $w x $h',
        );
        for (final target in visible) {
          expect(target.hitTestable(), findsWidgets, reason: '$what $target');
        }
      }

      Future<void> close() async {
        await tester.tap(find.byTooltip('닫기').last);
        await settle();
      }

      // 1. Pre-flight guide.
      var completed = 0;
      await mount(
        Scaffold(
          body: Builder(
            builder: (context) => GameActionButton(
              label: 'guide',
              onPressed: () => showGuide(context, () => completed++),
            ),
          ),
        ),
      );
      await tester.tap(action('guide'));
      await settle();
      onePage('비행 가이드', [action('비행 준비 완료')]);
      await tester.tap(action('비행 준비 완료'));
      await settle();
      expect(completed, 1);

      // 2. Saved sortie presets: empty slot, save name, filled slot, apply.
      await mount(HangarPresets(profile: p));
      await tester.tap(find.byType(GameItemSlot).first);
      await settle();
      onePage('출격 편성(빈 슬롯)', [find.byKey(const Key('preset-save-0'))]);
      await tester.tap(find.byKey(const Key('preset-save-0')));
      await settle();
      onePage('편성 저장', [action('저장'), action('취소')]);
      await tester.tap(action('저장'));
      await settle();
      await tester.pump(const Duration(seconds: 5));
      await settle();
      expect(p.hangarPresets[0], isNotNull);
      // A long worst-case summary: extra tech/pets and a missing item.
      final saved = p.hangarPresets[0]!;
      p.hangarPresets[0] = HangarPreset(
        name: '가장 긴 이름의 출격 구성 예시 24자',
        aircraft: saved.aircraft,
        ship: saved.ship,
        pilot: saved.pilot,
        armament: saved.armament,
        equipment: saved.equipment,
        gearIds: [...saved.gearIds, 999999],
        techIds: const [0, 1, 2],
        pet: 0,
        assistPets: const [1, 2],
      );
      p.contentChanged();
      await settle();
      onePage('출격 편성(저장 슬롯)', [
        find.byKey(const Key('preset-save-0')),
        find.byKey(const Key('preset-load-0')),
        action('이름 변경'),
        action('삭제'),
        action('편성 자세히'),
      ]);
      await tester.tap(action('편성 자세히'));
      await settle();
      onePage('편성 자세히');
      await close();
      await tester.tap(find.byKey(const Key('preset-load-0')));
      await settle();
      onePage('편성 적용', [action('적용 취소'), action('이 구성 적용')]);
      await tester.tap(action('적용 취소'));
      await settle();
      await tester.tap(find.byKey(const Key('preset-save-0')));
      await settle();
      onePage('편성 교체', [action('저장'), action('취소')]);
      await tester.tap(action('취소'));
      await settle();
      await close();

      // 3. Weapon evolution and support skill details, every entry.
      await mount(const Scaffold(body: EvolutionCodex()));
      for (final passive in [false, true]) {
        if (passive) {
          await tapUi(tester, tabWithText('보조'));
        }
        for (final skill in survivalSkills.where((s) => s.passive == passive)) {
          await tapUi(tester, action('${skill.name} 진화 상세'));
          await settle();
          onePage('${skill.name} 상세', [action('도감으로')]);
          await tester.tap(action('도감으로'));
          await settle();
        }
      }

      // 4. A long license text stays one page; only its paragraphs move.
      await mount(const GameLicensesScreen());
      await tapUi(tester, action('qa-long-package 라이선스 열기'));
      await settle();
      onePage('라이선스', [find.text('qa-long-package')]);
      final list = find.descendant(
        of: find.byType(GameDialog),
        matching: find.byType(ListView),
      );
      expect(list, findsOneWidget);
      expect(
        tester.getRect(list).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const Key('game-dialog-panel'))).bottom,
        ),
      );
      await tester.scrollUntilVisible(
        find.textContaining('Paragraph 29.'),
        300,
        scrollable: find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        ),
      );
      await settle();
      expect(
        find.textContaining('Paragraph 29.').hitTestable(),
        findsOneWidget,
      );
      // The dialog title stays fixed while the paragraphs move.
      expect(find.text('라이선스').hitTestable(), findsWidgets);
      await close();

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    });
  }
}
