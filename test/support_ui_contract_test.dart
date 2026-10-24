import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/cloud_sync.dart';
import 'package:shootingstar/main.dart';
import 'package:shootingstar/ui/account_screen.dart';
import 'package:shootingstar/ui/settings_screen.dart';
import 'package:shootingstar/ui/item_slots.dart';
import 'package:shootingstar/ui/evolution_codex.dart';
import 'package:shootingstar/ui/components.dart';

import 'ui_actions.dart';

class UiSync extends CloudSync {
  UiSync(super.profile) {
    ready = true;
    status = '게스트 · 기기에 저장';
  }
  final actions = <String>[];
  bool fail = false;
  String? loginUser, nicknameInput, recoveryInput;
  @override
  void changed() {}
  @override
  Future<void> login(
    String user,
    String password, {
    String? nickname,
    String? recovery,
  }) async {
    loginUser = user;
    nicknameInput = nickname;
    recoveryInput = recovery;
    actions.add(
      nickname != null
          ? 'register'
          : recovery != null
          ? 'recover'
          : 'login',
    );
    account = {'id': 'qa', 'username': user, 'nickname': nickname ?? '검증 조종사'};
    recoveryCode = nickname != null
        ? '0123456789abcdef0123456789abcdef0123456789abcdef'
        : '';
    status = '클라우드 저장 완료';
    notifyListeners();
  }

  @override
  Future<void> sync() async {
    if (fail) throw StateError('검증용 연결 실패');
    actions.add('sync');
    notifyListeners();
  }

  @override
  Future<void> resolve({required bool useCloud}) async {
    actions.add(useCloud ? 'resolve-cloud' : 'resolve-device');
    conflict = null;
    notifyListeners();
  }

  @override
  Future<void> logout({bool all = false}) async {
    actions.add(all ? 'logout-all' : 'logout');
    account = null;
    conflict = null;
    recoveryCode = '';
    notifyListeners();
  }
}

void main() {
  setUpAll(
    () => LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks(
        ['qa-ui-package'],
        'QA license text\n\n${List.filled(25, 'Permission and copyright notice remain readable on fixed pages.').join(' ')}',
      );
    }),
  );
  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'account settings guide codex preserve progress $size / $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          SharedPreferences.setMockInitialValues({});
          final p = await Profile.load();
          p.soundEnabled = false;
          final before = jsonEncode(p.exportProgress());
          final online = UiSync(p);
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
            (w) =>
                (w is GameActionButton && w.label == name) ||
                (w is GameItemSlot && w.semanticLabel == name),
          );
          Future<void> field(String key, String value) async {
            final f = find.byKey(Key(key));
            await revealUi(tester, f);
            await tester.enterText(f, value);
          }

          void fixed() {
            final scope = find.byType(GameDialog).evaluate().isNotEmpty
                ? find.byType(GameDialog).last
                : find.byType(Scaffold).last;
            expect(
              find.descendant(of: scope, matching: find.byType(ListView)),
              findsNothing,
            );
            expect(
              find.byType(GamePages),
              find.byType(FlightSettings).evaluate().isEmpty
                  ? findsWidgets
                  : findsNothing,
            );
          }

          await mount(AccountScreen(profile: p));
          fixed();
          for (final label in ['로그인', '가입', '복구']) {
            final f = find.descendant(
              of: find.widgetWithText(ChoiceChip, label),
              matching: find.text(label),
            );
            final text = tester.renderObject<RenderParagraph>(f);
            expect(text.didExceedMaxLines, isFalse);
            expect(
              text.size.width + .1,
              greaterThanOrEqualTo(text.getMaxIntrinsicWidth(double.infinity)),
            );
          }
          await tapUi(tester, action('로그인'));
          expect(online.actions, isEmpty);
          await revealUi(tester, find.text('아이디는 영문·숫자·밑줄 4~24자로 입력하세요.'));
          await field('account-user', 'QA_USER');
          await field('account-password', 'short');
          await tapUi(tester, action('로그인'));
          expect(online.actions, isEmpty);
          await revealUi(tester, find.text('비밀번호는 12~128자로 입력하세요.'));
          tester.view.viewInsets = const FakeViewPadding(bottom: 220);
          await tester.pumpAndSettle();
          await field('account-password', 'qa-password-only-123');
          fixed();
          await tapUi(tester, action('로그인'));
          expect(online.loginUser, 'qa_user');
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          await tapUi(tester, action('지금 동기화'));
          expect(online.actions, contains('sync'));
          online.fail = true;
          await tapUi(tester, action('지금 동기화'));
          await revealUi(tester, find.text('검증용 연결 실패'));
          online.fail = false;
          online.conflict = {'profile': p.exportProgress(), 'revision': 2};
          online.notifyListeners();
          await tester.pumpAndSettle();
          await tapUi(
            tester,
            find.byWidgetPredicate(
              (w) => w is GameChoiceTile && w.title == '서버 진행 사용',
            ),
          );
          fixed();
          await tapUi(tester, action('취소'));
          expect(online.actions, isNot(contains('resolve-cloud')));
          await tapUi(
            tester,
            find.byWidgetPredicate(
              (w) => w is GameChoiceTile && w.title == '이 기기 진행 저장',
            ),
          );
          await tapUi(tester, action('선택한 진행 사용'));
          expect(online.actions, contains('resolve-device'));
          online.busy = true;
          online.notifyListeners();
          await tester.pump(const Duration(milliseconds: 300));
          await revealUi(tester, action('지금 동기화'));
          expect(
            tester.widget<GameActionButton>(action('지금 동기화')).onPressed,
            isNull,
          );
          online.busy = false;
          online.notifyListeners();
          await tester.pumpAndSettle();
          await tapUi(tester, action('로그아웃 · 게스트로 돌아가기'));
          await tapUi(tester, find.widgetWithText(ChoiceChip, '복구'));
          await field('account-recovery', '0' * 48);
          await field('account-password', 'qa-new-password-123');
          await tapUi(tester, action('계정 복구'));
          expect(online.recoveryInput, '0' * 48);
          await tapUi(tester, action('로그아웃 · 게스트로 돌아가기'));
          await tapUi(tester, find.widgetWithText(ChoiceChip, '가입'));
          await field('account-name', '검증 조종사');
          await field('account-password', 'qa-new-password-123');
          await tapUi(tester, action('현재 진행으로 계정 만들기'));
          expect(online.nicknameInput, '검증 조종사');
          expect(online.recoveryCode, isNotEmpty);
          await tapUi(tester, action('별도로 보관했습니다'));
          expect(online.recoveryCode, isEmpty);
          // v12.4.3: rare account-wide actions live in the 계정 관리 popup.
          await tapUi(tester, find.byKey(const Key('account-manage')));
          await tapUi(tester, action('모든 기기 로그아웃'));
          expect(online.actions, contains('logout-all'));
          expect(jsonEncode(p.exportProgress()), before);
          await mount(
            Scaffold(
              body: Builder(
                builder: (context) => GameActionButton(
                  label: 'open',
                  onPressed: () => showFlightSettings(context, p),
                ),
              ),
            ),
          );
          await tapUi(tester, action('open'));
          fixed();
          final heading = tester.renderObject<RenderParagraph>(
            find.text('음악·효과음'),
          );
          expect(heading.text.style!.color, app.theme!.colorScheme.onSurface);
          expect(heading.text.style!.decoration, TextDecoration.none);
          await tapUi(tester, find.text('음악·효과음'));
          expect(p.soundEnabled, isTrue);
          await tapUi(tester, find.byTooltip('음량 높이기'));
          expect(p.volume, closeTo(.6, .001));
          await tapUi(tester, find.text('시각 효과 줄이기'));
          expect(p.reducedEffects, isTrue);
          await tapUi(tester, find.widgetWithText(InkWell, '라이선스').last);
          await tapUi(tester, action('qa-ui-package 라이선스 열기'));
          // One popup: only the license paragraphs move in a bounded list.
          expect(find.byKey(const Key('game-page-next')), findsNothing);
          expect(
            find.descendant(
              of: find.byType(GameDialog).last,
              matching: find.byKey(const Key('license-paragraphs')),
            ),
            findsOneWidget,
          );
          expect(find.text('qa-ui-package').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('닫기').last);
          await tester.pumpAndSettle();
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          await tapUi(tester, find.byTooltip('닫기').last);
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
          await tapUi(tester, action('guide'));
          fixed();
          await tester.tap(find.byTooltip('닫기'));
          await tester.pumpAndSettle();
          expect(completed, 0);
          await tapUi(tester, action('guide'));
          for (final label in ['이동', '자동 발사', '보석과 레벨업', '일시정지']) {
            await revealUi(tester, find.text(label));
          }
          // v12.6.0 (user): the guide has no '자세히' page any more.
          expect(find.text('자세히'), findsNothing);
          expect(completed, 0);
          await tapUi(tester, action('비행 준비 완료'));
          expect(completed, 1);
          final readOnly = jsonEncode(p.exportProgress());
          await mount(const Scaffold(body: EvolutionCodex()));
          final title = tester.getRect(find.text('진화 도감'));
          await tester.drag(find.byType(ListView), const Offset(0, -180));
          await tester.pumpAndSettle();
          expect(tester.getRect(find.text('진화 도감')), title);
          for (final label in ['펄스 블래스터', '요격 드론', '구급 요격대']) {
            await tapUi(tester, action('$label 진화 상세'));
            fixed();
            await tapUi(tester, action('도감으로'));
          }
          await tapUi(tester, find.widgetWithText(ChoiceChip, '보조'));
          await tapUi(tester, action('고밀도 탄약 진화 상세'));
          fixed();
          await tapUi(tester, action('도감으로'));
          expect(jsonEncode(p.exportProgress()), readOnly);
          await p.save();
          final q = await Profile.load();
          expect(q.soundEnabled, isTrue);
          expect(q.volume, closeTo(.6, .001));
          expect(q.reducedEffects, isTrue);
          expect(
            jsonEncode(q.inventory.map((g) => g.toJson()).toList()),
            jsonEncode(p.inventory.map((g) => g.toJson()).toList()),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          online.dispose();
          p.dispose();
          q.dispose();
        },
      );
    }
  }
}
