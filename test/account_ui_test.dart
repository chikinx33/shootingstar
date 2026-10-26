import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/cloud_sync.dart';
import 'package:shootingstar/ui/account_screen.dart';
import 'package:shootingstar/ui/components.dart';

import 'ui_actions.dart';

void main() {
  testWidgets('account forms and conflict choices fit a 360px display', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = await Profile.load();
    final c = CloudSync(p)..ready = true;
    await tester.pumpWidget(MaterialApp(home: AccountScreen(profile: p)));
    await tester.pumpAndSettle();
    expect(find.text('계정'), findsOneWidget);
    expect(find.byType(ProfileCard), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('가입'));
    await tester.pumpAndSettle();
    await revealUi(
      tester,
      find.byWidgetPredicate(
        (w) => w is GameActionButton && w.label == '현재 진행으로 계정 만들기',
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('복구'));
    await tester.pumpAndSettle();
    await revealUi(tester, find.byKey(const Key('account-recovery')));
    expect(tester.takeException(), isNull);
    c.account = {'id': 'one', 'username': 'qa', 'nickname': 'QA'};
    c.conflict = {'revision': 2, 'profile': Profile.freshProgress()};
    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(key: const ValueKey('signed-in'), profile: p),
      ),
    );
    await tester.pumpAndSettle();
    await revealUi(
      tester,
      find.byWidgetPredicate(
        (w) => w is GameChoiceTile && w.title == '서버 진행 사용',
      ),
    );
    await revealUi(
      tester,
      find.byWidgetPredicate(
        (w) => w is GameChoiceTile && w.title == '이 기기 진행 저장',
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    p.dispose();
  });
}
