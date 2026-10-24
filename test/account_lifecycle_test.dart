import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/cloud_sync.dart';
import 'package:shootingstar/data/online_api.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/ui/components.dart';
import 'package:shootingstar/ui/storage_help_screen.dart';
import 'package:shootingstar/ui/delete_account_screen.dart';

import 'ui_actions.dart';

class AccountApi extends OnlineApi {
  bool reject = false;
  int deletions = 0, writes = 0;
  @override
  Future<void> setToken(String? value) async {
    token = value;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (path == 'auth/challenge')
      return {'salt': '11111111111111111111111111111111'};
    if (path == 'auth/delete') {
      deletions++;
      expect(data['username'], 'qa_user');
      expect((data['key'] as String).length, 64);
      if (reject) throw OnlineError(401, {'error': '비밀번호 확인'});
      return {'ok': true};
    }
    writes++;
    throw StateError('Unexpected network action');
  }
}

class DeletionUiCloud extends CloudSync {
  DeletionUiCloud(super.profile) : super(api: AccountApi());
  int attempts = 0;
  final response = Completer<void>();
  @override
  Future<void> deleteAccount(
    String password, {
    required String username,
  }) async {
    expect(username, 'qa_user');
    expect(password, 'local-test-password');
    attempts++;
    await response.future;
  }
}

GameEngine arena() => GameEngine(
  stageIndex: 0,
  shipIndex: 0,
  attackLevel: 0,
  hullLevel: 0,
  magnetLevel: 0,
  equipmentIndex: 0,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('pending sortie explains sync and blocks account switching/logout without a request', () async {
    final p = await Profile.load(), api = AccountApi();
    final c = CloudSync(p, api: api)
      ..ready = true
      ..account = {'id': 'one', 'username': 'qa_user'}
      ..boundId = 'one';
    await p.checkpointBattle('pending', arena());
    await c.sync();
    expect(c.status, contains('중단 출격 보관'));
    await expectLater(
      c.login('another', 'local-test-password'),
      throwsStateError,
    );
    await expectLater(c.logout(), throwsStateError);
    expect(api.writes, 0);
    expect(p.hasSuspendedBattle, true);
    c.dispose();
    p.dispose();
  });
  test('wrong deletion password preserves state; confirmed deletion clears local progress/backups and never uploads it', () async {
    final p = await Profile.load(), api = AccountApi();
    final prefs = await SharedPreferences.getInstance();
    final c = CloudSync(p, api: api)
      ..ready = true
      ..prefs = prefs
      ..account = {'id': 'one', 'username': 'qa_user'}
      ..boundId = 'one'
      ..dirty = true;
    p.credits = 950;
    await p.checkpointBattle('pending', arena());
    await prefs.setString('online.backup.one', 'old progress');
    await prefs.setString('online.backup.guest', 'guest progress');
    await prefs.setString(
      '${Profile.storageKey}.beforeCampaign',
      'migration progress',
    );
    api.reject = true;
    await expectLater(
      c.deleteAccount('local-test-password', username: 'qa_user'),
      throwsA(isA<OnlineError>()),
    );
    expect(p.credits, 950);
    expect(p.hasSuspendedBattle, true);
    expect(c.signedIn, true);
    api.reject = false;
    await c.deleteAccount('local-test-password', username: 'qa_user');
    expect(c.signedIn, false);
    expect(c.boundId, '');
    expect(c.dirty, false);
    expect(p.credits, 150);
    expect(p.hasSuspendedBattle, false);
    expect(
      prefs.getKeys().where((k) => k.startsWith('online.backup.')),
      isEmpty,
    );
    expect(api.writes, 0);
    expect(prefs.containsKey('${Profile.storageKey}.beforeCampaign'), false);
    final r = await Profile.load();
    expect(r.credits, 150);
    expect(r.hasSuspendedBattle, false);
    r.dispose();
    c.dispose();
    p.dispose();
  }, timeout: const Timeout(Duration(seconds: 30)));
  test(
    'diagnostic copy contains no account identity or credential material',
    () async {
      final p = await Profile.load();
      final c = CloudSync(p, api: AccountApi())
        ..account = {
          'id': 'private-id',
          'username': 'private-user',
          'nickname': 'private-name',
        }
        ..recoveryCode = 'private-recovery';
      final text = jsonEncode(storageDiagnostics(p));
      for (final secret in [
        'private-id',
        'private-user',
        'private-name',
        'private-recovery',
        'guildToken',
        'inventory',
      ])
        expect(text, isNot(contains(secret)));
      c.dispose();
      p.dispose();
    },
  );
  for (final width in [320.0, 360.0, 390.0, 430.0])
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'deletion confirmation and storage help stay reachable $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final p = await Profile.load();
          final c = DeletionUiCloud(p)
            ..ready = true
            ..account = {'id': 'one', 'username': 'qa_user'}
            ..boundId = 'one';
          Widget wrap(Widget w) => MaterialApp(
            theme: ThemeData.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: w,
          );
          await tester.pumpWidget(wrap(DeleteAccountScreen(profile: p)));
          await tester.pumpAndSettle();
          final action = find.byWidgetPredicate(
            (w) => w is GameActionButton && w.label == '계정과 저장 영구 삭제',
          );
          await revealUi(tester, action);
          expect(tester.widget<GameActionButton>(action).onPressed, isNull);
          await revealUi(tester, find.byKey(const Key('delete-account-user')));
          await tester.enterText(
            find.byKey(const Key('delete-account-user')),
            'qa_user',
          );
          await revealUi(
            tester,
            find.byKey(const Key('delete-account-password')),
          );
          await tester.enterText(
            find.byKey(const Key('delete-account-password')),
            'local-test-password',
          );
          await revealUi(tester, action);
          expect(tester.widget<GameActionButton>(action).onPressed, isNotNull);
          await tapUi(tester, action);
          expect(c.attempts, 1);
          await revealUi(tester, find.bySemanticsLabel('삭제 취소'));
          expect(
            tester
                .widget<GameActionButton>(
                  find.byWidgetPredicate(
                    (w) => w is GameActionButton && w.label == '삭제 취소',
                  ),
                )
                .onPressed,
            isNull,
          );
          c.response.completeError(StateError('테스트 재시도'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(c.attempts, 1);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(wrap(StorageHelpScreen(profile: p)));
          await tester.pumpAndSettle();
          await revealUi(tester, find.bySemanticsLabel('진단 정보 복사'));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          c.dispose();
          p.dispose();
        },
      );
    }
}
