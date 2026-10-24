import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/content.dart';
import 'package:shootingstar/data/cloud_sync.dart';
import 'package:shootingstar/data/online_api.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/house_tree.dart';
import 'package:shootingstar/ui/components.dart';
import 'package:shootingstar/ui/guild_screen.dart';
import 'package:shootingstar/ui/hangar_presets.dart';
import 'package:shootingstar/ui/talent_screen.dart';
import 'package:shootingstar/ui/campaign_selector.dart';

import 'ui_actions.dart';

import 'package:shootingstar/ui/item_slots.dart';

class GuildApi extends OnlineApi {
  bool joined = false, fail = false;
  int coins = 20, checked = 0;
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic> data = const {},
  ]) async {
    calls.add(path);
    if (fail) throw Exception('검증용 연결 실패');
    if (path.endsWith('/create') || path.endsWith('/join')) joined = true;
    if (path.endsWith('/leave')) joined = false;
    if (path.endsWith('/checkin')) {
      coins += 10;
      checked = 1;
    }
    if (path.endsWith('/donate')) coins -= 10;
    return {
      'guild': joined ? {'name': '별빛 원정대', 'id': 'QA1234', 'xp': 400} : null,
      'directory': [
        {'name': '모집 함대', 'id': 'QA0001', 'members': 3},
      ],
      'user': {'coins': coins, 'checkday': checked},
      'day': 1,
      'members': List.generate(20, (i) => {'name': '길드원 ${i + 1}'}),
      'week': 'QA 주간',
      'damage': 100000,
      'attempts': 1,
      if (path.endsWith('/shop'))
        'rewards': [
          {'id': 'qa-supply', 'food': 30, 'plans': 2},
        ],
      if (path.endsWith('/raid'))
        'rewards': [
          {'id': 'qa-raid', 'credits': 100},
        ],
    };
  }
}

class QuietSync extends CloudSync {
  QuietSync(super.profile, {required super.api});
  @override
  void changed() {}
}

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'command screens preserve actions and fixed pages $size / $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final p = await Profile.load();
          p.onboarded = true;
          p.soundEnabled = false;
          p.credits = 10000;
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
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: child,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }

          Finder action(String name) => find.byWidgetPredicate(
            (w) => w is GameActionButton && w.label == name,
          );
          final inventory = jsonEncode(
            p.inventory.map((g) => g.toJson()).toList(),
          );
          await mount(HangarPresets(profile: p));
          final header = tester.getRect(find.text('출격 구성'));
          await tester.drag(find.byType(ListView), const Offset(0, -180));
          await tester.pumpAndSettle();
          expect(tester.getRect(find.text('출격 구성')), header);
          await tapUi(tester, find.byType(GameItemSlot).first);
          await tapUi(tester, find.byKey(const Key('preset-save-0')));
          tester.view.viewInsets = const FakeViewPadding(bottom: 220);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          expect(find.byType(GamePages), findsWidgets);
          expect(
            find.descendant(
              of: find.byType(GameDialog).evaluate().isNotEmpty
                  ? find.byType(GameDialog)
                  : find.byType(Scaffold).last,
              matching: find.byType(ListView),
            ),
            findsNothing,
          );
          await revealUi(tester, find.byType(TextField));
          await tester.enterText(find.byType(TextField), '보존 편성');
          await tapUi(tester, action('저장'));
          expect(p.hangarPresets[0]?.name, '보존 편성');
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          await tapUi(tester, find.byKey(const Key('preset-load-0')));
          expect(find.byType(GamePages), findsWidgets);
          expect(
            find.descendant(
              of: find.byType(GameDialog).evaluate().isNotEmpty
                  ? find.byType(GameDialog)
                  : find.byType(Scaffold).last,
              matching: find.byType(ListView),
            ),
            findsNothing,
          );
          await tapUi(tester, action('적용 취소'));
          expect(p.selectedShip, 0);
          await tapUi(tester, find.byKey(const Key('preset-load-0')));
          await tapUi(tester, action('이 구성 적용'));
          await tapUi(tester, action('이름 변경'));
          await revealUi(tester, find.byType(TextField));
          await tester.enterText(find.byType(TextField), '새 편성');
          await tapUi(tester, action('저장'));
          expect(p.hangarPresets[0]?.name, '새 편성');
          await tapUi(tester, action('삭제'));
          await tapUi(tester, action('취소'));
          expect(p.hangarPresets[0], isNotNull);
          final levels = [p.attackLevel, p.hullLevel, p.magnetLevel],
              credits = p.credits;
          await mount(Scaffold(body: TalentScreen(profile: p)));
          await tapUi(tester, find.byType(GameItemSlot).first);
          await tapUi(tester, find.byKey(const ValueKey('research-attack-0')));
          expect(p.attackLevel, levels[0] + 1);
          expect(p.credits, credits - upgradeCost(0));
          await tapUi(tester, find.byTooltip('닫기').last);
          await tapUi(tester, find.widgetWithText(ChoiceChip, '선체'));
          await tapUi(tester, find.byType(GameItemSlot).first);
          await tapUi(tester, find.byKey(const ValueKey('research-hull-0')));
          expect(p.hullLevel, levels[1] + 1);
          await tapUi(tester, find.byTooltip('닫기').last);
          await tapUi(tester, find.widgetWithText(ChoiceChip, '회수'));
          await tapUi(tester, find.byType(GameItemSlot).first);
          await tapUi(tester, find.byKey(const ValueKey('research-magnet-0')));
          expect(p.magnetLevel, levels[2] + 1);
          p.clearedStages.add(0);
          await mount(Scaffold(body: CampaignSelector(profile: p)));
          await tapUi(tester, find.byKey(const ValueKey('house-node-1')));
          expect(find.byType(GameDialog), findsOneWidget);
          expect(find.byType(GamePages), findsWidgets);
          expect(
            find.descendant(
              of: find.byType(GameDialog).evaluate().isNotEmpty
                  ? find.byType(GameDialog)
                  : find.byType(Scaffold).last,
              matching: find.byType(ListView),
            ),
            findsNothing,
          );
          await tapUi(tester, action('이 집 지키기'));
          expect(p.selectedStage, 1);
          final locked = tester.widget<HouseNode>(
            find.byKey(const ValueKey('house-node-2')),
          );
          expect(locked.available, isFalse);
          await mount(GuildScreen(profile: p));
          expect(find.byType(GamePages), findsWidgets);
          expect(
            find.descendant(
              of: find.byType(GameDialog).evaluate().isNotEmpty
                  ? find.byType(GameDialog)
                  : find.byType(Scaffold).last,
              matching: find.byType(ListView),
            ),
            findsNothing,
          );
          await revealUi(tester, action('계정 로그인 · 가입'));
          final api = GuildApi();
          final sync = QuietSync(p, api: api)
            ..account = {'id': 'qa', 'nickname': 'QA'};
          await mount(GuildScreen(profile: p));
          expect(find.byType(GamePages), findsWidgets);
          expect(
            find.descendant(
              of: find.byType(GameDialog).evaluate().isNotEmpty
                  ? find.byType(GameDialog)
                  : find.byType(Scaffold).last,
              matching: find.byType(ListView),
            ),
            findsNothing,
          );
          await revealUi(tester, find.widgetWithText(TextField, '새 길드 이름'));
          tester.view.viewInsets = const FakeViewPadding(bottom: 220);
          await tester.pumpAndSettle();
          await revealUi(tester, find.widgetWithText(TextField, '새 길드 이름'));
          await tester.enterText(
            find.widgetWithText(TextField, '새 길드 이름'),
            '별빛 원정대',
          );
          await tapUi(tester, action('길드 창설'));
          expect(api.joined, isTrue);
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          for (final label in ['현황', '토벌', '보급', '길드원']) {
            final text = tester.renderObject<RenderParagraph>(find.text(label));
            expect(text.didExceedMaxLines, isFalse);
            expect(
              text.size.width + .1,
              greaterThanOrEqualTo(text.getMaxIntrinsicWidth(double.infinity)),
            );
          }
          await tapUi(tester, action('출석 · 코인 +10'));
          expect(api.coins, 30);
          await revealUi(tester, action('오늘 출석 완료'));
          expect(
            tester.widget<GameActionButton>(action('오늘 출석 완료')).onPressed,
            isNull,
          );
          await tapUi(tester, action('기여 · 코인 10'));
          expect(api.coins, 20);
          await tapUi(tester, find.widgetWithText(ChoiceChip, '토벌'));
          expect(find.byType(GamePages), findsWidgets);
          expect(
            find.descendant(
              of: find.byType(GameDialog).evaluate().isNotEmpty
                  ? find.byType(GameDialog)
                  : find.byType(Scaffold).last,
              matching: find.byType(ListView),
            ),
            findsNothing,
          );
          await tapUi(tester, action('토벌 보상 우편 수령'));
          expect(p.mail.where((m) => m.id == 'qa-raid').length, 1);
          await tapUi(tester, action('토벌 보상 우편 수령'));
          expect(p.mail.where((m) => m.id == 'qa-raid').length, 1);
          await tapUi(tester, find.widgetWithText(ChoiceChip, '보급'));
          await tapUi(tester, action('길드 코인 10 · 우편 지급'));
          expect(p.mail.where((m) => m.id == 'qa-supply').length, 1);
          await tapUi(tester, find.widgetWithText(ChoiceChip, '길드원'));
          expect(find.byType(ListView), findsOneWidget);
          final gh = tester.getRect(find.text('함께하는 함대'));
          await tester.drag(find.byType(ListView), const Offset(0, -250));
          await tester.pumpAndSettle();
          expect(tester.getRect(find.text('함께하는 함대')), gh);
          await tapUi(tester, find.widgetWithText(ChoiceChip, '현황'));
          await tapUi(tester, action('길드 탈퇴'));
          await tapUi(tester, action('취소'));
          expect(api.joined, isTrue);
          await tapUi(tester, action('길드 탈퇴'));
          await tapUi(tester, action('탈퇴'));
          expect(api.joined, isFalse);
          await tapUi(tester, find.widgetWithText(ChoiceChip, '모집'));
          await tapUi(tester, action('모집 함대 가입'));
          expect(api.joined, isTrue);
          api.fail = true;
          await tapUi(tester, find.byTooltip('길드 새로고침'));
          expect(find.byType(GamePages), findsWidgets);
          expect(
            find.descendant(
              of: find.byType(GameDialog).evaluate().isNotEmpty
                  ? find.byType(GameDialog)
                  : find.byType(Scaffold).last,
              matching: find.byType(ListView),
            ),
            findsNothing,
          );
          api.fail = false;
          await tapUi(tester, action('서버 다시 연결'));
          expect(tester.takeException(), isNull);
          expect(
            jsonEncode(p.inventory.map((g) => g.toJson()).toList()),
            inventory,
          );
          await p.save();
          final q = await Profile.load();
          expect(q.hangarPresets[0]?.name, '새 편성');
          expect(q.selectedStage, 1);
          expect(q.attackLevel, 1);
          expect(q.mail.where((m) => m.id == 'qa-raid').length, 1);
          expect(
            jsonEncode(q.inventory.map((g) => g.toJson()).toList()),
            inventory,
          );
          await tester.pumpWidget(const SizedBox());
          sync.dispose();
          p.dispose();
          q.dispose();
        },
      );
    }
  }
}
