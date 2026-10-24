import 'package:shootingstar/ui/item_slots.dart';
import 'package:shootingstar/ui/components.dart';

import 'ui_actions.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/fleet_journal.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/ui/collection_screen.dart';

FleetJournal reloadJournal(FleetJournal journal) =>
    FleetJournal.restore(jsonDecode(jsonEncode(journal.toJson())));

void atPastTime(Profile profile, DateTime utc) {
  profile.lastClock = 0;
  profile.lastPatrol = 0;
  profile.dayKey = '';
  profile.seasonKey = '';
  profile.journal = FleetJournal();
  profile.refreshContentClock(utc);
}

int finishRun(
  Profile p, {
  required String id,
  int stage = 0,
  int seconds = 180,
  int kills = 120,
  int bosses = 1,
  bool victory = false,
  bool training = false,
  bool challenge = false,
}) => p.completeRun(
  runId: id,
  stageIndex: stage,
  seconds: seconds,
  kills: kills,
  bossesDefeated: bosses,
  victory: victory,
  training: training,
  challenge: challenge,
  level: 3,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'KST midnight resets daily claims while Sunday retains the current week',
    () {
      final j = FleetJournal();
      j.advance(DateTime.utc(2026, 10, 10, 14, 59, 59));
      expect(j.day, '2026-10-10');
      expect(j.week, '2026-10-05');
      expect(j.claimSignIn(), isNotNull);
      expect(j.claimDailyChest(0, 1), isNotNull);
      expect(j.claimQuickPatrol(1), isNotNull);
      j.weeklyRuns = 4;
      j.chapterBest[0] = 120;

      expect(j.advance(DateTime.utc(2026, 10, 10, 15)), true);
      expect(j.day, '2026-10-11');
      expect(j.week, '2026-10-05');
      expect(j.weeklyRuns, 4);
      expect(j.dailyChests, isEmpty);
      expect(j.quickPatrolClaimed, false);
      expect(j.signedInToday, false);
      expect(j.signIns, 1);
      expect(j.chapterBest, {0: 120});
      expect(j.advance(DateTime.utc(2026, 10, 10, 15, 1)), false);
    },
  );

  test(
    'Monday at 15:00 UTC resets weekly progress without losing lifetime claims',
    () {
      final j = FleetJournal();
      j.advance(DateTime.utc(2026, 10, 11, 14, 59, 59));
      j.weeklyRuns = 5;
      j.weeklyKills = 1200;
      expect(j.claimWeekly(0), isNotNull);
      expect(j.claimWeekly(1), isNotNull);
      expect(j.claimWeeklyChest(0), isNotNull);
      j.signIns = 7;
      expect(j.claimSignInChest(0), isNotNull);
      expect(j.claimChapter(0, 0, 180, {0}), isNotNull);

      j.advance(DateTime.utc(2026, 10, 11, 15));
      expect(j.day, '2026-10-12');
      expect(j.week, '2026-10-12');
      expect(j.weeklyRuns, 0);
      expect(j.weeklyKills, 0);
      expect(j.weeklyClaims, isEmpty);
      expect(j.weeklyChests, isEmpty);
      expect(j.signIns, 7);
      expect(j.claimSignInChest(0), isNull);
      expect(j.claimChapter(0, 0, 180, {0}), isNull);
    },
  );

  test('Profile monotonic clock blocks rollback farming across the Monday boundary', () async {
    final p = await Profile.load();
    final sunday = DateTime.utc(2026, 10, 11, 14, 59, 59);
    final monday = DateTime.utc(2026, 10, 11, 15);
    atPastTime(p, sunday);
    p.journal.weeklyRuns = 4;
    p.refreshContentClock(monday);
    p.dailyRuns = 1;
    p.dailyClaims.add(0);
    expect(p.claimSignIn(now: monday), true);
    expect(p.claimDailyActivity(0, now: monday), true);
    expect(p.claimQuickPatrol(now: monday), true);
    final rewardSnapshot = p.exportProgress();
    final currentJournal = jsonEncode(p.journal.toJson());

    p.refreshContentClock(sunday);
    expect(p.lastClock, monday.millisecondsSinceEpoch);
    expect(p.dayKey, '2026-10-12');
    expect(p.journal.week, '2026-10-12');
    expect(p.journal.weeklyRuns, 0);
    expect(p.claimSignIn(now: sunday), false);
    expect(p.claimDailyActivity(0, now: sunday), false);
    expect(p.claimQuickPatrol(now: sunday), false);
    expect(jsonEncode(p.journal.toJson()), currentJournal);
    expect(p.credits, rewardSnapshot['credits']);
    expect(
      p.collections.keys,
      (rewardSnapshot['content'] as Map)['collections']['keys'],
    );
    await p.save();
    p.dispose();
  });

  test(
    'daily sign-in survives Profile reload and pays only once today',
    () async {
      final p = await Profile.load();
      final now = DateTime.now().toUtc();
      expect(p.claimSignIn(now: now), true);
      final earned = p.exportProgress();
      expect(p.claimSignIn(now: now), false);
      expect(p.exportProgress(), earned);
      await p.save();
      final q = await Profile.load();
      expect(q.journal.signedInToday, true);
      expect(q.claimSignIn(), false);
      expect(q.credits, p.credits);
      expect(q.collections.keys, p.collections.keys);
      expect(q.journal.signIns, 1);
      p.dispose();
      q.dispose();
    },
  );

  test('28 earned sign-ins repeat the seven-day rewards and pay cumulative chests once', () {
    var j = FleetJournal();
    final cycle = <String>[];
    final start = DateTime.utc(2026, 9, 19);
    for (var day = 0; day < 28; day++) {
      j.advance(start.add(Duration(days: day)));
      final reward = j.claimSignIn();
      expect(reward, isNotNull);
      if (day < 7) {
        cycle.add(reward!.summary);
      } else {
        expect(reward!.summary, cycle[day % 7]);
      }
      expect(j.claimSignIn(), isNull);
      for (var chest = 0; chest < 5; chest++) {
        if (j.signIns < FleetJournal.signInTargets[chest]) {
          expect(j.claimSignInChest(chest), isNull);
        } else if (!j.signInChests.contains(chest)) {
          expect(j.claimSignInChest(chest), isNotNull);
          expect(j.claimSignInChest(chest), isNull);
        }
      }
      // Restarting in the middle of each cycle must preserve both ledgers.
      if (day % 3 == 0) j = reloadJournal(j);
    }
    expect(j.signIns, 28);
    expect(j.signInNext, 0);
    expect(j.signInChests.length, 5);
    j = reloadJournal(j);
    for (var chest = 0; chest < 5; chest++) {
      expect(j.claimSignInChest(chest), isNull);
    }
  });

  test(
    'daily activity unlocks each threshold and is idempotent through reload',
    () {
      var j = FleetJournal()..advance(DateTime.utc(2026, 10, 15));
      expect(j.claimDailyChest(-1, 3), isNull);
      expect(j.claimDailyChest(3, 3), isNull);
      expect(j.claimDailyChest(0, 0), isNull);
      expect(j.claimDailyChest(0, 1), isNotNull);
      expect(j.claimDailyChest(1, 1), isNull);
      expect(j.claimDailyChest(1, 2), isNotNull);
      expect(j.claimDailyChest(2, 2), isNull);
      expect(j.claimDailyChest(2, 3), isNotNull);
      j = reloadJournal(j);
      for (var chest = 0; chest < 3; chest++) {
        expect(j.claimDailyChest(chest, 3), isNull);
      }
      j.advance(DateTime.utc(2026, 10, 16));
      expect(j.claimDailyChest(0, 1), isNotNull);
    },
  );

  test(
    'weekly mission and chest thresholds persist independently across restart',
    () {
      var j = FleetJournal()..advance(DateTime.utc(2026, 10, 15));
      j.weeklyRuns = 4;
      j.weeklyKills = 1199;
      j.weeklyBosses = 2;
      j.weeklySeconds = 1799;
      for (var id = 0; id < 4; id++) {
        expect(j.claimWeekly(id), isNull);
      }
      j.recordRun(stage: 0, seconds: 30, kills: 10, bosses: 1, victory: false);
      expect(j.claimWeekly(0), isNotNull);
      expect(j.claimWeeklyChest(0), isNull);
      expect(j.claimWeekly(1), isNotNull);
      expect(j.claimWeeklyChest(0), isNotNull);
      expect(j.claimWeeklyChest(1), isNull);
      j = reloadJournal(j);
      expect(j.claimWeekly(0), isNull);
      expect(j.claimWeekly(1), isNull);
      expect(j.claimWeeklyChest(0), isNull);
      expect(j.claimWeekly(2), isNotNull);
      expect(j.claimWeeklyChest(1), isNull);
      expect(j.claimWeekly(3), isNotNull);
      expect(j.claimWeeklyChest(1), isNotNull);
      expect(reloadJournal(j).claimWeeklyChest(1), isNull);
    },
  );

  test('weekly Profile rewards cannot repay after save and reload', () async {
    final p = await Profile.load();
    for (var run = 0; run < 5; run++) {
      finishRun(p, id: 'weekly-$run', kills: 240, bosses: 0);
    }
    expect(p.claimWeeklyMission(0), true);
    expect(p.claimWeeklyActivity(0), false);
    expect(p.claimWeeklyMission(1), true);
    expect(p.claimWeeklyActivity(0), true);
    final credits = p.credits;
    final keys = p.collections.keys;
    await p.save();
    final q = await Profile.load();
    expect(q.claimWeeklyMission(0), false);
    expect(q.claimWeeklyMission(1), false);
    expect(q.claimWeeklyActivity(0), false);
    expect(q.credits, credits);
    expect(q.collections.keys, keys);
    expect(q.journal.weeklyRuns, 5);
    p.dispose();
    q.dispose();
  });

  test('quick patrol requires a valid sortie, pays once and leaves idle accrual intact', () async {
    final p = await Profile.load();
    final now = DateTime.now().toUtc();
    p.lastPatrol = now
        .subtract(const Duration(hours: 3))
        .millisecondsSinceEpoch;
    final idleAnchor = p.lastPatrol;
    final idleMinutes = p.patrolMinutes(now);
    final before = p.credits;
    expect(p.claimQuickPatrol(now: now), false);
    expect(p.credits, before);
    expect(p.lastPatrol, idleAnchor);
    finishRun(p, id: 'patrol-sortie', seconds: 120, kills: 10, bosses: 0);
    expect(p.dailyRuns, 1);
    final afterBattle = p.credits;
    expect(p.claimQuickPatrol(now: now), true);
    expect(p.credits, greaterThan(afterBattle));
    expect(p.lastPatrol, idleAnchor);
    expect(p.patrolMinutes(now), idleMinutes);
    final afterQuickPatrol = p.credits;
    expect(p.claimQuickPatrol(now: now), false);
    await p.save();
    final q = await Profile.load();
    expect(q.claimQuickPatrol(), false);
    expect(q.credits, afterQuickPatrol);
    expect(q.lastPatrol, idleAnchor);
    expect(q.claimPatrol(now), true);
    expect(q.credits, greaterThan(afterQuickPatrol));
    p.dispose();
    q.dispose();
  });

  test('quick patrol resets on a new day and requires that new day to earn a sortie', () {
    final j = FleetJournal()..advance(DateTime.utc(2026, 10, 15));
    expect(j.claimQuickPatrol(0), isNull);
    expect(j.claimQuickPatrol(1), isNotNull);
    expect(j.claimQuickPatrol(2), isNull);
    j.advance(DateTime.utc(2026, 10, 16));
    expect(j.claimQuickPatrol(0), isNull);
    expect(j.claimQuickPatrol(1), isNotNull);
  });

  test('eligible sorties update journal; training, invalid and duplicate IDs do not', () async {
    final p = await Profile.load();
    final fresh = jsonEncode(p.journal.toJson());
    finishRun(p, id: 'training', victory: true, training: true);
    finishRun(p, id: 'invalid-negative', stage: -1, victory: true);
    finishRun(p, id: 'invalid-high', stage: 100, victory: true);
    finishRun(p, id: 'locked', stage: 2, victory: true);
    finishRun(p, id: 'too-short', seconds: 29, kills: 100);
    finishRun(p, id: 'too-few-kills', seconds: 180, kills: 9);
    expect(jsonEncode(p.journal.toJson()), fresh);
    finishRun(p, id: 'valid-normal', victory: true, kills: 40);
    expect(p.journal.weeklyRuns, 1);
    expect(p.journal.weeklyKills, 40);
    expect(p.journal.weeklyBosses, 1);
    expect(p.journal.weeklySeconds, 180);
    expect(p.journal.chapterBest, {0: 180});
    expect(p.journal.chapterWins, {0});
    final once = jsonEncode(p.journal.toJson());
    final credits = p.credits;
    expect(finishRun(p, id: 'valid-normal', victory: true, kills: 40), 0);
    expect(jsonEncode(p.journal.toJson()), once);
    expect(p.credits, credits);
    await p.save();
    final q = await Profile.load();
    expect(finishRun(q, id: 'valid-normal', victory: true, kills: 40), 0);
    expect(jsonEncode(q.journal.toJson()), once);
    p.dispose();
    q.dispose();
  });

  test(
    'challenge sorties count weekly but cannot improve normal chapter records',
    () async {
      final p = await Profile.load();
      p.clearedStages.add(0);
      finishRun(p, id: 'challenge', challenge: true, victory: true, kills: 50);
      expect(p.journal.weeklyRuns, 1);
      expect(p.journal.weeklyKills, 50);
      expect(p.journal.weeklyBosses, 1);
      expect(p.journal.weeklySeconds, 180);
      expect(p.journal.chapterBest, isEmpty);
      expect(p.journal.chapterWins, isEmpty);
      await p.save();
      p.dispose();
    },
  );

  test('chapter thirds depend on best depth, final chest requires victory', () {
    final j = FleetJournal();
    void run(int seconds, {bool victory = false}) => j.recordRun(
      stage: 0,
      seconds: seconds,
      kills: 10,
      bosses: 0,
      victory: victory,
    );
    run(59);
    expect(j.claimChapter(0, 0, 180, {}), isNull);
    run(60);
    expect(j.claimChapter(0, 0, 180, {}), isNotNull);
    run(60);
    expect(j.claimChapter(0, 1, 180, {}), isNull);
    run(120);
    expect(j.claimChapter(0, 1, 180, {}), isNotNull);
    run(180);
    expect(j.claimChapter(0, 2, 180, {}), isNull);
    run(180, victory: true);
    expect(j.claimChapter(0, 2, 180, {}), isNotNull);
    expect(reloadJournal(j).claimChapter(0, 2, 180, {}), isNull);
  });

  test(
    'legacy clears claim all three milestones once without consuming equipment',
    () async {
      final p = await Profile.load();
      p.clearedStages.add(0);
      final inventory = p.inventory.map((g) => g.toJson()).toList();
      final equipped = List.of(p.equippedGear);
      final initialCredits = p.credits;
      for (var milestone = 0; milestone < 3; milestone++) {
        expect(p.claimChapterReward(0, milestone), true);
        expect(p.claimChapterReward(0, milestone), false);
      }
      expect(p.credits, greaterThan(initialCredits));
      expect(p.collections.keys, greaterThan(0));
      expect(p.inventory.map((g) => g.toJson()).toList(), inventory);
      expect(p.equippedGear, equipped);
      expect(p.journal.chapterBest, isEmpty);
      expect(p.claimChapterReward(-1, 0), false);
      expect(p.claimChapterReward(100, 0), false);
      expect(p.claimChapterReward(0, 3), false);
      expect(p.claimChapterReward(1, 0), false);
      await p.save();
      final q = await Profile.load();
      final keys = q.collections.keys;
      for (var milestone = 0; milestone < 3; milestone++) {
        expect(q.claimChapterReward(0, milestone), false);
      }
      expect(q.collections.keys, keys);
      expect(q.inventory.map((g) => g.toJson()).toList(), inventory);
      p.dispose();
      q.dispose();
    },
  );

  test('replacing an account with an older save clears both new progression systems', () async {
    final p = await Profile.load();
    p.claimSignIn();
    p.collections.keys = 9;
    p.collections.shards[0] = 3;
    expect(p.collections.upgrade(0), true);
    p.journal.chapterBest[0] = 120;
    p.journal.chapterClaims.add(0);
    p.journal.weeklyRuns = 4;
    final olderAccount = Profile.freshProgress();
    final content = olderAccount['content'] as Map;
    content.remove('journal');
    content.remove('collections');
    await p.replaceProgress(olderAccount);
    expect(p.journal.signIns, 0);
    expect(p.journal.signInDay, isEmpty);
    expect(p.journal.weeklyRuns, 0);
    expect(p.journal.chapterClaims, isEmpty);
    expect(p.journal.chapterBest, isEmpty);
    expect(p.collections.keys, 0);
    expect(p.collections.discoveredCount, 0);
    expect(p.collections.shards.every((n) => n == 0), true);
    final q = await Profile.load();
    expect(q.journal.signIns, 0);
    expect(q.journal.chapterClaims, isEmpty);
    expect(q.collections.keys, 0);
    expect(q.collections.discoveredCount, 0);
    p.dispose();
    q.dispose();
  });

  testWidgets(
    '320px collections show real costs and review fragment crafting',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = await Profile.load();
      p.collections.keys = 1;
      p.collections.dust = 3;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: CollectionScreen(profile: p),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final supply = find.byWidgetPredicate(
        (w) => w is GameActionButton && w.label == '유물 조사 · 탐사권 1',
      );
      await tapUi(tester, supply);
      expect(p.collections.keys, 0);
      expect(p.collections.shards[0], 3);
      await tapUi(tester, find.widgetWithText(GameActionButton, '확인'));
      expect(tester.widget<GameActionButton>(supply).onPressed, isNull);
      await tapUi(tester, find.text('보관함'));
      await tapUi(
        tester,
        find.byWidgetPredicate(
          (w) => w is GameItemSlot && w.title == '초신성 프리즘',
        ),
      );
      await tapUi(tester, find.bySemanticsLabel('초신성 프리즘 상세').last);
      expect(tester.takeException(), isNull);
      final craft = find.byWidgetPredicate(
        (w) => w is GameActionButton && w.label == '조각 제작 · 가루 3',
      );
      await tapUi(tester, craft);
      expect(find.text('선택 조각 제작'), findsOneWidget);
      expect(p.collections.dust, 3);
      expect(p.collections.shards[0], 3);
      await tapUi(tester, find.text('취소'));
      await tester.pumpAndSettle();
      expect(p.collections.dust, 3);
      await tapUi(tester, craft);
      await tester.pumpAndSettle();
      await tapUi(tester, find.text('가루 3개 사용'));
      await tester.pumpAndSettle();
      expect(p.collections.dust, 0);
      expect(p.collections.shards[0], 4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await p.save();
      p.dispose();
    },
  );
}
