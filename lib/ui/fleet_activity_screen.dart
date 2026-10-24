import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/content_systems.dart';
import '../data/fleet_journal.dart';
import '../data/profile.dart';
import '../main.dart';
import 'components.dart';
import 'reward_popup.dart';
import 'collection_screen.dart';
import 'catalog_screens.dart' show CatalogTabs;
import '../art/lobby_art.dart';

class FleetActivityScreen extends StatefulWidget {
  const FleetActivityScreen({
    super.key,
    required this.profile,
    this.initialPage = 0,
  });
  final Profile profile;
  final int initialPage;
  @override
  State<FleetActivityScreen> createState() => _FleetActivityScreenState();
}

class _FleetActivityScreenState extends State<FleetActivityScreen> {
  Profile get p => widget.profile;
  late int page = widget.initialPage.clamp(0, 3);
  late int chapter = p.selectedStage;
  int signInCategory = 0,
      missionCategory = 0,
      chestPeriod = 0,
      patrolCategory = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    if (p.refreshContentClock(DateTime.now())) p.contentChanged();
    p.addListener(refresh);
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (p.refreshContentClock(DateTime.now())) {
        p.contentChanged();
      } else {
        refresh();
      }
    });
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    timer?.cancel();
    p.removeListener(refresh);
    super.dispose();
  }

  void act(bool Function() action) {
    claimWithRewardPopup(context, p, action);
  }

  Widget card(Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Surface(child: child),
  );
  Widget heading(String title, String description) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          tr(title),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),

          textAlign: TextAlign.center,
        ),
        gap(5),
        Text(
          tr(description),
          style: const TextStyle(color: muted, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
  Widget claim(
    String name,
    bool enabled,
    bool Function() action, {
    bool claimed = false,
    String displayLabel = '보상 받기',
  }) => Center(
    child: GameActionButton(
      label: name,
      displayLabel: claimed ? '수령 완료' : displayLabel,
      primary: true,
      icon: Icons.card_giftcard,
      onPressed: audible(enabled ? () => act(action) : null),
    ),
  );

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('함대 활동'), textAlign: TextAlign.center)),
      body: Column(
        children: [
          FleetActivityTabs(
            selected: page,
            onSelected: (i) => setState(() => page = i),
          ),
          if (page == 0)
            CatalogTabs(
              labels: const ['7일 보급', '누적 출석'],
              selected: signInCategory,
              tight: true,
              onSelected: (i) => setState(() => signInCategory = i),
            ),
          if (page == 1)
            CatalogTabs(
              labels: const ['일일', '주간', '상자'],
              selected: missionCategory,
              tight: true,
              onSelected: (i) => setState(() => missionCategory = i),
            ),
          if (page == 1 && missionCategory == 2)
            CatalogTabs(
              labels: const ['일일 상자', '주간 상자'],
              selected: chestPeriod,
              tight: true,
              onSelected: (i) => setState(() => chestPeriod = i),
            ),
          if (page == 3)
            CatalogTabs(
              labels: const ['자동 순찰', '빠른 순찰'],
              selected: patrolCategory,
              tight: true,
              onSelected: (i) => setState(() => patrolCategory = i),
            ),
          Expanded(
            child: ListView(
              key: ValueKey(
                '$page/$signInCategory/$missionCategory/$chestPeriod/$patrolCategory/$chapter',
              ),
              padding: const EdgeInsets.all(12),
              children: switch (page) {
                0 => signIn(),
                1 => missions(),
                2 => chapters(),
                _ => patrol(),
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> signIn() => [
    if (signInCategory == 0) ...[
      heading('7일 함대 보급', '누적 출석 ${p.journal.signIns}일\n결석해도 다음 보급부터 계속'),
      card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RasterIcon(Icons.calendar_month, size: 64, color: cyan),
            gap(10),
            Text(
              message("오늘 보급\n{0}", [
                FleetJournal
                    .signInRewards[p.journal.signedInToday
                        ? (p.journal.signIns - 1) % 7
                        : p.journal.signInNext]
                    .summary,
              ]),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            gap(10),
            claim(
              p.journal.signedInToday ? '오늘 수령 완료' : '오늘 출석 보상 받기',
              !p.journal.signedInToday,
              () => p.claimSignIn(),
              claimed: p.journal.signedInToday,
            ),
          ],
        ),
      ),
      LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: 6,
          runSpacing: 8,
          children: [
            for (int i = 0; i < 7; i++)
              SizedBox(
                width: MediaQuery.textScalerOf(context).scale(1) > 1.15
                    ? (box.maxWidth - 6) / 2
                    : (box.maxWidth - 12) / 3,
                child: Surface(
                  padding: const EdgeInsets.all(8),
                  active:
                      i ==
                      (p.journal.signedInToday
                          ? (p.journal.signIns - 1) % 7
                          : p.journal.signInNext),
                  child: Column(
                    children: [
                      Text(
                        message("{0}일차", [i + 1]),
                        style: const TextStyle(fontWeight: FontWeight.w900),

                        textAlign: TextAlign.center,
                      ),
                      gap(8),
                      RasterIcon(
                        i == 6 ? Icons.workspace_premium : Icons.card_giftcard,
                        color: i == 6 ? cyan : const Color(0xFF9EC8FF),
                        size: 56,
                      ),
                      gap(8),
                      Text(
                        tr(FleetJournal.signInRewards[i].summary),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
    if (signInCategory == 1) ...[
      heading('누적 출석 상자', '7일 보급이 반복돼도 누적 기록 유지'),
      for (int i = 0; i < FleetJournal.signInTargets.length; i++)
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                message("{0}일 출석\n{1}", [
                  FleetJournal.signInTargets[i],
                  FleetJournal.signInChestRewards[i].summary,
                ]),

                textAlign: TextAlign.center,
              ),
              claim(
                p.journal.signInChests.contains(i)
                    ? '누적 상자 수령 완료'
                    : '${FleetJournal.signInTargets[i]}일 상자 받기',
                !p.journal.signInChests.contains(i) &&
                    p.journal.signIns >= FleetJournal.signInTargets[i],
                () => p.claimSignInChest(i),
                claimed: p.journal.signInChests.contains(i),
              ),
            ],
          ),
        ),
    ],
    OutlinedButton.icon(
      onPressed: audible(
        () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => CollectionScreen(profile: p)),
        ),
      ),
      icon: const RasterIcon(Icons.auto_awesome, size: 28),
      label: Text(tr('수집품 조사와 성장'), textAlign: TextAlign.center),
    ),
  ];

  List<Widget> missions() => [
    if (missionCategory == 0) ...[
      heading('일일 임무', '매일 0시 갱신 (한국 시간)\n임무 보상 수령 → 활동 상자 개방'),
      for (int i = 0; i < 3; i++)
        task(
          ContentSystems.dailyNames[i],
          p.dailyProgress(i),
          ContentSystems.dailyTargets[i],
          p.dailyClaims.contains(i),
          '일일 임무 ${i + 1} 보상 받기',
          () => p.claimDaily(i),
          '50 츄르 · 시즌 XP 50\n보급·육성 재료',
        ),
    ],
    if (missionCategory == 2 && chestPeriod == 0) ...[
      heading('일일 활동 상자', '매일 0시 갱신 (한국 시간)\n임무 보상 1·2·3개 수령 시 개방'),
      for (int i = 0; i < 3; i++)
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                message("임무 보상 {0}개 수령\n{1}", [
                  i + 1,
                  FleetJournal.dailyChestRewards[i].summary,
                ]),
                style: const TextStyle(fontWeight: FontWeight.w800),

                textAlign: TextAlign.center,
              ),
              claim(
                p.journal.dailyChests.contains(i)
                    ? '일일 상자 수령 완료'
                    : '일일 활동 상자 ${i + 1}',
                !p.journal.dailyChests.contains(i) &&
                    p.dailyClaims.length >= i + 1,
                () => p.claimDailyActivity(i),
                claimed: p.journal.dailyChests.contains(i),
              ),
            ],
          ),
        ),
    ],
    if (missionCategory == 1) ...[
      heading('주간 임무', '월요일 0시 갱신 (한국 시간)\n훈련 기록 제외'),
      for (int i = 0; i < 4; i++)
        task(
          FleetJournal.weeklyNames[i],
          p.journal.weeklyProgress(i),
          FleetJournal.weeklyTargets[i],
          p.journal.weeklyClaims.contains(i),
          '주간 임무 ${i + 1} 보상 받기',
          () => p.claimWeeklyMission(i),
          FleetJournal.weeklyReward.summary,
        ),
    ],
    if (missionCategory == 2 && chestPeriod == 1) ...[
      heading('주간 활동 상자', '월요일 0시 갱신 (한국 시간)\n임무 보상 2·4개 수령 시 개방'),
      for (int i = 0; i < 2; i++)
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                message("임무 보상 {0}개 수령\n{1}", [
                  (i + 1) * 2,
                  FleetJournal.weeklyChestRewards[i].summary,
                ]),

                textAlign: TextAlign.center,
              ),
              claim(
                p.journal.weeklyChests.contains(i)
                    ? '주간 상자 수령 완료'
                    : '주간 활동 상자 ${i + 1}',
                !p.journal.weeklyChests.contains(i) &&
                    p.journal.weeklyClaims.length >= (i + 1) * 2,
                () => p.claimWeeklyActivity(i),
                claimed: p.journal.weeklyChests.contains(i),
              ),
            ],
          ),
        ),
    ],
  ];

  Widget task(
    String name,
    int progress,
    int target,
    bool claimed,
    String label,
    bool Function() action,
    String reward,
  ) => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          tr(name),
          style: const TextStyle(fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        gap(6),
        RasterGauge(
          value: progress / target,
          minHeight: 8,
          color: const Color(0xFFA7E6B3),
        ),
        gap(5),
        Text(
          message("{0} / {1}", [progress.clamp(0, target), target]),
          style: const TextStyle(color: muted, fontSize: 14),

          textAlign: TextAlign.center,
        ),
        Text(
          tr(reward),
          style: const TextStyle(fontSize: 14),
          textAlign: TextAlign.center,
        ),
        claim(
          claimed ? '보상 수령 완료' : label,
          !claimed && progress >= target,
          action,
          claimed: claimed,
        ),
      ],
    ),
  );

  List<Widget> chapters() {
    final cleared =
        p.clearedStages.contains(chapter) ||
        p.journal.chapterWins.contains(chapter);
    final duration = stages[chapter].duration;
    final seconds = cleared ? duration : p.journal.chapterBest[chapter] ?? 0;
    return [
      heading('항로 보상', '최고 진행·클리어 기록 보상\n각 보상은 계정당 1회 수령'),
      DropdownButtonFormField<int>(
        onTap: audible(() {}),
        initialValue: chapter,
        isExpanded: true,
        decoration: InputDecoration(labelText: tr('보상 항로 선택')),
        items: [
          for (int i = 0; i < stages.length; i++)
            if (p.canStage(i) ||
                p.clearedStages.contains(i) ||
                p.journal.chapterBest.containsKey(i))
              DropdownMenuItem(
                value: i,
                child: Text(
                  tr(stages[i].name),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
        ],
        onChanged: audibleChange((i) {
          if (i != null) setState(() => chapter = i);
        }),
      ),
      gap(14),
      Text(
        message("최고 진행 {0}분 {1}초 · {2}", [
          seconds ~/ 60,
          seconds % 60,
          cleared ? "클리어" : "진행 중",
        ]),

        textAlign: TextAlign.center,
      ),
      gap(8),
      RasterGauge(value: seconds / duration, minHeight: 10),
      gap(16),
      for (int i = 0; i < 3; i++)
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RasterIcon(
                i == 2 ? Icons.emoji_events : Icons.inventory_2,
                size: 64,
                color: i == 2 ? cyan : const Color(0xFFA7E6B3),
              ),
              gap(8),
              Text(
                tr(i == 2 ? '항로 클리어' : '${duration * (i + 1) ~/ 3}초 진행'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              gap(5),
              Text(
                tr(FleetJournal.chapterReward(i).summary),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              claim(
                p.journal.chapterClaims.contains(chapter * 3 + i)
                    ? '항로 상자 수령 완료'
                    : '항로 보상 받기 ${i + 1}',
                p.journal.canClaimChapter(
                  chapter,
                  i,
                  duration,
                  p.clearedStages,
                ),
                () => p.claimChapterReward(chapter, i),
                claimed: p.journal.chapterClaims.contains(chapter * 3 + i),
              ),
            ],
          ),
        ),
    ];
  }

  List<Widget> patrol() => [
    if (patrolCategory == 0) ...[
      heading('자동 순찰', '30분부터 회수 · 최대 8시간\n실제 누적 시간 기준'),
      card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RasterIcon(Icons.explore, size: 64, color: Color(0xFFA7E6B3)),
            gap(8),
            Text(
              message("{0}분 / 480분", [p.patrolMinutes(DateTime.now())]),
              textAlign: TextAlign.center,
            ),
            gap(8),
            RasterGauge(
              value: p.patrolMinutes(DateTime.now()) / 480,
              minHeight: 10,
            ),
            gap(10),
            Text(
              tr('30분마다 20 츄르\n60분마다 별가루 1 · 먹이 5'),
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 14),
            ),
            claim(
              '순찰 보상 회수',
              p.patrolMinutes(DateTime.now()) >= 30,
              () => p.claimPatrol(DateTime.now()),
              displayLabel: '보상 회수',
            ),
          ],
        ),
      ),
    ],
    if (patrolCategory == 1) ...[
      heading('빠른 순찰', '유효 출격 후 하루 1회 지급\n자동 순찰 누적 시간 유지'),
      card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RasterIcon(Icons.fast_forward, color: cyan, size: 42),
            gap(10),
            Text(
              tr(FleetJournal.quickPatrolReward.summary),
              textAlign: TextAlign.center,
            ),
            gap(8),
            Text(
              message("오늘 유효 출격 {0}회", [p.dailyRuns]),
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 14),
            ),
            claim(
              p.journal.quickPatrolClaimed ? '빠른 순찰 수령 완료' : '빠른 순찰 보상 받기',
              !p.journal.quickPatrolClaimed && p.dailyRuns > 0,
              () => p.claimQuickPatrol(),
              claimed: p.journal.quickPatrolClaimed,
            ),
          ],
        ),
      ),
    ],
  ];
}

/// Four fixed icon destinations. Labels never determine the number of rows.
class FleetActivityTabs extends StatelessWidget {
  const FleetActivityTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  static const entries = [
    ('출석', '출석', Icons.card_giftcard),
    ('임무', '임무', Icons.assignment_turned_in),
    ('항로 보상', '항로', Icons.emoji_events),
    ('순찰', '순찰', Icons.explore),
  ];

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return ColoredBox(
      color: const Color(0xFF14263A),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          key: const Key('activity-icon-tabs'),
          children: [
            for (var i = 0; i < entries.length; i++)
              Expanded(
                child: Semantics(
                  key: ValueKey('activity-tab-$i'),
                  button: true,
                  selected: selected == i,
                  label: tr(entries[i].$1),
                  excludeSemantics: true,
                  onTap: audible(() => onSelected(i)),
                  child: InkWell(
                    onTap: audible(() => onSelected(i)),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LobbyIcon(entries[i].$3, size: 44),
                          const SizedBox(height: 3),
                          Text(
                            tr(entries[i].$2),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'NotoSansKR',
                              fontSize: GameUi.navigationLabel,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                              color: selected == i ? cyan : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 5),
                          SizedBox(
                            width: 36,
                            height: 3,
                            child: ColoredBox(
                              color: selected == i ? cyan : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
