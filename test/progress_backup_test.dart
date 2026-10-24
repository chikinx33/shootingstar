import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shootingstar/data/cloud_sync.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/progress_backup.dart';
import 'package:shootingstar/game/engine.dart';
import 'package:shootingstar/ui/components.dart';
import 'package:shootingstar/ui/progress_backup_screen.dart';

import 'ui_actions.dart';

class FailingStore extends InMemorySharedPreferencesStore {
  FailingStore(super.data, {required this.failKey}) : super.withData();
  final String failKey;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      key == failKey ? false : super.setValue(valueType, key, value);
}

Future<String> forged(Map<String, dynamic> progress) async {
  final body = jsonEncode({
    'version': 'v10.0.30',
    'createdAt': '2026-10-20T00:00:00Z',
    'progress': progress,
  });
  final digest = (await Sha256().hash(utf8.encode(body))).bytes
      .map((v) => v.toRadixString(16).padLeft(2, '0'))
      .join();
  return jsonEncode({
    'format': 'shootingstar.progress.backup',
    'schema': 1,
    'payload': body,
    'sha256': digest,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'memory-only progress can be exported when device storage is unavailable',
    () async {
      final p = await Profile.load(
        preferencesLoader: () async => throw StateError('storage denied'),
      );
      p.credits = 789;
      final backup = await ProgressBackup.decode(
        await ProgressBackup.encode(p),
      );
      expect(backup.progress['credits'], 789);
      await expectLater(
        p.restoreGuestBackup(backup.progress),
        throwsStateError,
      );
      await expectLater(
        ProgressBackup.encode(Profile.presentationCopy(p)),
        throwsStateError,
      );
      p.dispose();
    },
  );
  test('portable backup normalizes progress and excludes account bindings, paid rights and suspended runs', () async {
    final p = await Profile.load();
    p.credits = 654;
    p.guildToken = 'private-account-binding';
    p.guildNickname = 'private-nickname';
    p.guildReports.add({'runId': 'private-run'});
    final game = GameEngine(
      stageIndex: 0,
      shipIndex: 0,
      attackLevel: 0,
      hullLevel: 0,
      magnetLevel: 0,
      equipmentIndex: 0,
    );
    await p.checkpointBattle('private-checkpoint', game);
    final text = await ProgressBackup.encode(p, at: DateTime.utc(2026, 10, 20));
    expect(text, isNot(contains('private-')));
    expect(text, isNot(contains('_battle')));
    expect(text, isNot(contains('_flights')));
    final backup = await ProgressBackup.decode(text);
    expect(backup.progress['credits'], 654);
    expect(backup.progress['verifiedAdCredits'], 0);
    expect(backup.createdAt, DateTime.utc(2026, 10, 20));
    expect(p.hasSuspendedBattle, true);
    p.dispose();
  });
  test('corrupt, oversized, malformed, future schema, wrong game and invalid counters are rejected without mutation', () async {
    final p = await Profile.load(),
        text = await ProgressBackup.encode(await Profile.load());
    final doc = jsonDecode(text) as Map<String, dynamic>;
    for (final candidate in [
      '{broken',
      'x' * (ProgressBackup.maxBytes + 1),
      jsonEncode({...doc, 'schema': 2}),
      jsonEncode({...doc, 'format': 'another-game'}),
      jsonEncode({...doc, 'sha256': '0' * 64}),
    ]) {
      await expectLater(
        ProgressBackup.decode(candidate),
        throwsFormatException,
      );
    }
    for (final change in [
      {'version': 9},
      {'credits': -1},
      {'runs': 1.5},
      {'_battle': {}},
      {'_flights': []},
    ]) {
      await expectLater(
        ProgressBackup.decode(await forged({...p.exportProgress(), ...change})),
        throwsFormatException,
      );
    }
    expect(p.credits, 150);
    p.dispose();
  });
  test('restore persists once, retains the previous guest snapshot, supports undo and never mints paid ownership', () async {
    final p = await Profile.load();
    p.credits = 900;
    await p.save();
    final target = ProgressBackup(
      await Profile.load().then((p) => p.exportProgress()),
      DateTime.utc(2026),
      'v10.0.30',
    );
    target.progress['credits'] = 77;
    target.progress['supporter'] = true;
    target.progress['verifiedAdCredits'] = 999;
    await p.restoreGuestBackup(target.progress);
    expect(p.credits, 77);
    expect((await Profile.load()).credits, 77);
    expect(p.exportProgress().containsKey('supporter'), false);
    expect(p.exportProgress()['verifiedAdCredits'], 0);
    final previous = p.previousManualBackup()!;
    expect(previous['credits'], 900);
    await p.restoreGuestBackup(previous);
    expect(p.credits, 900);
    expect(p.previousManualBackup()!['credits'], 77);
    p.dispose();
  });
  test('signed-in, expired account, connecting, active or suspended battle and developer profiles cannot be overwritten', () async {
    final p = await Profile.load(), cloud = CloudSync(await Profile.load());
    p.online = cloud;
    for (final state in [0, 1, 2, 3, 4]) {
      cloud.ready = state != 0;
      cloud.account = state == 1 ? {'id': 'one'} : null;
      cloud.boundId = state == 2 ? 'expired' : '';
      cloud.inBattle = state == 3;
      cloud.busy = state == 4;
      await expectLater(
        p.restoreGuestBackup(Profile.freshProgress()),
        throwsStateError,
      );
    }
    cloud.busy = false;
    cloud.inBattle = false;
    p.online = null;
    await p.checkpointBattle(
      'pending',
      GameEngine(
        stageIndex: 0,
        shipIndex: 0,
        attackLevel: 0,
        hullLevel: 0,
        magnetLevel: 0,
        equipmentIndex: 0,
      ),
    );
    await expectLater(
      p.restoreGuestBackup(Profile.freshProgress()),
      throwsStateError,
    );
    expect(p.hasSuspendedBattle, true);
    final dev = Profile.developerCopy(p);
    await expectLater(
      dev.restoreGuestBackup(Profile.freshProgress()),
      throwsStateError,
    );
    dev.dispose();
    cloud.profile.dispose();
    cloud.dispose();
    p.dispose();
  });
  test('backup failure or final write failure preserves current memory and cached/disk progress', () async {
    for (final failingKey in [Profile.manualBackupKey, Profile.storageKey]) {
      SharedPreferences.setMockInitialValues({});
      final p = await Profile.load();
      p.credits = 555;
      await p.save();
      final prefs = await SharedPreferences.getInstance();
      final store = FailingStore({
        for (final key in prefs.getKeys()) 'flutter.$key': prefs.get(key)!,
      }, failKey: 'flutter.$failingKey');
      SharedPreferencesStorePlatform.instance = store;
      await expectLater(
        p.restoreGuestBackup({...Profile.freshProgress(), 'credits': 2}),
        throwsStateError,
      );
      expect(p.credits, 555);
      expect((await Profile.load()).credits, 555);
      expect(p.restoringBackup, false);
      p.dispose();
    }
  });
  test(
    'concurrent restore cannot overwrite a restore already in progress',
    () async {
      final p = await Profile.load();
      final first = p.restoreGuestBackup({
        ...Profile.freshProgress(),
        'credits': 12,
      });
      await expectLater(
        p.restoreGuestBackup({...Profile.freshProgress(), 'credits': 999}),
        throwsStateError,
      );
      await first;
      expect(p.credits, 12);
      p.dispose();
    },
  );
  testWidgets(
    'selecting and cancelling a backup cannot alter progress; confirmed restore and undo use fixed pages',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = await Profile.load();
      final encoded = await forged({...p.exportProgress(), 'credits': 321});
      await tester.pumpWidget(
        MaterialApp(
          home: ProgressBackupScreen(
            profile: p,
            pickText: () async => encoded,
            saveText: (_) async {},
          ),
        ),
      );
      final choose = find.byWidgetPredicate(
        (w) => w is GameActionButton && w.label == '백업 파일 선택',
      );
      await revealUi(tester, choose);
      await tester.tapAt(tester.getCenter(choose));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(p.credits, 150);
      final restore = find.byWidgetPredicate(
        (w) => w is GameActionButton && w.label == '백업 내용으로 복원',
      );
      await revealUi(tester, restore);
      await tester.tapAt(tester.getCenter(restore));
      await tester.pumpAndSettle();
      await revealUi(
        tester,
        find.byWidgetPredicate((w) => w is GameActionButton && w.label == '취소'),
      );
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(p.credits, 150);
      await revealUi(tester, restore);
      await tester.tapAt(tester.getCenter(restore));
      await tester.pumpAndSettle();
      final commit = find.byWidgetPredicate(
        (w) => w is GameActionButton && w.label == '이 진행으로 복원',
      );
      await revealUi(tester, commit);
      await tester.tapAt(tester.getCenter(commit));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(p.credits, 321);
      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsNothing);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
    },
  );
}
