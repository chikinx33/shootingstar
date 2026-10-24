import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/cloud_sync.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/ui/account_screen.dart';
import 'package:shootingstar/ui/components.dart';
import 'package:shootingstar/ui/progress_backup_screen.dart';
import 'package:shootingstar/ui/storage_help_screen.dart';
import 'package:shootingstar/ui/supporter_screen.dart';

// v12.4.3 (user 2026-10-25): account forms, signed-in states and the help
// screens fit one page on phones; their explanations open in popups that
// also fit without page arrows.
void main() {
  for (final (w, h) in const [(360.0, 720.0), (390.0, 844.0)]) {
    testWidgets('account states and info popups fit one page at $w x $h', (
      tester,
    ) async {
      tester.view.physicalSize = Size(w, h);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      p.soundEnabled = false;
      p.reducedEffects = true;
      final c = CloudSync(p)
        ..ready = true
        ..status = '게스트 · 기기에 저장';

      Future<void> settle() async {
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      Future<void> show(Widget screen) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(MaterialApp(home: screen));
        await settle();
      }

      void onePage(String state) {
        expect(tester.takeException(), isNull, reason: state);
        expect(
          find.byKey(const Key('game-page-next')),
          findsNothing,
          reason: '$state must not split into pages',
        );
      }

      Finder action(String label) => find.byWidgetPredicate(
        (w) => w is GameActionButton && w.label == label,
      );

      Future<void> popup(
        Finder opener,
        String state, [
        List<String>? then,
      ]) async {
        await tester.tap(opener);
        await settle();
        expect(find.byType(GameDialog), findsOneWidget, reason: state);
        onePage('$state popup');
        for (final label in then ?? const <String>[]) {
          expect(action(label).hitTestable(), findsOneWidget, reason: label);
        }
        await tester.tap(find.byTooltip('닫기'));
        await settle();
        expect(find.byType(GameDialog), findsNothing);
      }

      await show(AccountScreen(profile: p));
      onePage('login form');
      c.busy = true;
      c.notifyListeners();
      await settle();
      onePage('login busy');
      c.busy = false;
      c.notifyListeners();
      await settle();
      await popup(find.byKey(const Key('account-info')), 'login info');
      await tester.tap(action('로그인'));
      await settle();
      expect(find.text('아이디는 영문·숫자·밑줄 4~24자로 입력하세요.'), findsOneWidget);
      onePage('login error');
      for (final (tab, submit) in const [
        ('가입', '현재 진행으로 계정 만들기'),
        ('복구', '계정 복구'),
      ]) {
        await tester.tap(find.widgetWithText(ChoiceChip, tab));
        await settle();
        onePage('$tab form');
        await tester.tap(action(submit));
        await settle();
        expect(find.text('아이디는 영문·숫자·밑줄 4~24자로 입력하세요.'), findsOneWidget);
        onePage('$tab error');
      }

      c
        ..account = {'id': 'qa', 'username': 'qa_pilot', 'nickname': '검증 조종사'}
        ..revision = 12
        ..updatedAt = 1760000000
        ..status = '클라우드 저장 완료';
      await show(AccountScreen(key: const ValueKey('signed'), profile: p));
      onePage('signed in');
      c.busy = true;
      c.notifyListeners();
      await settle();
      onePage('sync busy');
      c.busy = false;
      c.notifyListeners();
      await settle();
      await popup(find.byKey(const Key('account-info')), 'signed-in info');
      await popup(find.byKey(const Key('account-manage')), 'account manage', [
        '모든 기기 로그아웃',
        '계정 영구 삭제',
      ]);
      c.recoveryCode = '0123456789abcdef0123456789abcdef0123456789abcdef';
      await show(AccountScreen(key: const ValueKey('code'), profile: p));
      onePage('recovery code');
      c
        ..recoveryCode = ''
        ..conflict = {'revision': 13, 'profile': Profile.freshProgress()};
      await show(AccountScreen(key: const ValueKey('conflict'), profile: p));
      onePage('save conflict');
      c.conflict = null;

      await show(StorageHelpScreen(profile: p));
      onePage('storage help');
      await popup(find.byKey(const Key('storage-help-details')), 'storage');
      await show(SupporterScreen(profile: p));
      onePage('supporter');
      await popup(find.byKey(const Key('supporter-details')), 'supporter');
      await show(ProgressBackupScreen(profile: p));
      onePage('progress backup');
      await popup(find.byKey(const Key('backup-details')), 'backup');

      await tester.pumpWidget(const SizedBox());
      c.dispose();
      p.dispose();
    });
  }
}
