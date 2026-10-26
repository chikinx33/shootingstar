import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game_decor.dart';

import '../data/content.dart';
import '../data/content_systems.dart';
import '../data/fleet_journal.dart';
import '../data/profile.dart';
import '../data/shop_ledger.dart';
import '../main.dart';
import 'components.dart';
import 'info_dialog.dart';
import '../data/houses.dart';
import 'game_slots.dart';
import 'reward_popup.dart';
import 'collection_screen.dart';
import 'catalog_screens.dart' show CatalogTabs;
import '../art/game_icons.dart';

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
  int missionCategory = 0, chestPeriod = 0, patrolCategory = 0;
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

  void act(bool Function() action, {AdOffer? adOffer}) {
    claimWithRewardPopup(context, p, action, adOffer: adOffer);
  }

  Widget claim(
    String name,
    bool enabled,
    bool Function() action, {
    bool claimed = false,
    String displayLabel = '보상 받기',
    AdOffer? adOffer,
  }) => Center(
    child: GameActionButton(
      label: name,
      displayLabel: claimed ? '수령 완료' : displayLabel,
      primary: true,
      image: GameIcons.chest,
      onPressed: audible(enabled ? () => act(action, adOffer: adOffer) : null),
    ),
  );

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      appBar: GameAppBar(
        title: Text(tr('함대 활동'), textAlign: TextAlign.center),
        actions: [InfoAction(label: '활동 규칙', onPressed: _rules)],
      ),
      body: Column(
        children: [
          FleetActivityTabs(
            selected: page,
            onSelected: (i) => setState(() => page = i),
          ),
          if (page == 1)
            CatalogTabs(
              labels: const ['일일', '주간'],
              selected: missionCategory,
              tight: true,
              onSelected: (i) => setState(() => missionCategory = i),
            ),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey('$page/$missionCategory/$chapter'),
              child: switch (page) {
                0 => ListView(
                  padding: const EdgeInsets.all(12),
                  children: signIn(),
                ),
                1 => missions(),
                2 => houses(),
                _ => patrol(),
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Reset times and payout rules live here, not as sentences on the page.
  void _rules() => showInfoDialog(
    context,
    title: '활동 규칙',
    children: const [
      InfoText('일일 임무·출석은 매일 0시(한국 시간), 주간 임무는 월요일 0시에 바뀝니다.'),
      gap8,
      InfoText('임무 보상을 받은 개수만큼 활동 상자가 열립니다. 훈련 기록은 주간 임무에 들어가지 않습니다.'),
      gap8,
      InfoText('집 보상은 집마다 한 번씩 받습니다.'),
      gap8,
      InfoText(
        '자동 순찰은 30분마다 츄르 20, 1시간마다 별가루 1과 먹이 5가 쌓이고 최대 8시간까지 모입니다. 빠른 순찰은 유효 출격 뒤 하루 한 번 받습니다.',
      ),
    ],
  );

  /// v12.15 attendance in the mobile-game form (user 2026-10-26): the
  /// cumulative chest track, the time to the next sign-in, six day cards and
  /// a wide seventh-day card. Rewards are picture slots with ×N badges; the
  /// glowing card is today's and claims on tap; claimed days carry a check.
  List<Widget> signIn() {
    final j = p.journal;
    final done = j.signedInToday ? (j.signIns - 1) % 7 + 1 : j.signIns % 7;
    SlotState state(int day) => day < done
        ? SlotState.claimed
        : day == done && !j.signedInToday
        ? SlotState.today
        : SlotState.open;
    Widget day(int i, double slot) => GameDayCard(
      grand: i == 6,
      label: message('{0}일', [i + 1]),
      rewards: GameReward.of(FleetJournal.signInRewards[i]),
      state: state(i),
      slotSize: slot,
      onTap: state(i) == SlotState.today
          ? () => act(() => p.claimSignIn())
          : null,
    );
    return [
      GameMilestoneTrack(
        count: j.signIns,
        targets: FleetJournal.signInTargets,
        claimed: j.signInChests.contains,
        onClaim: (i) => act(() => p.claimSignInChest(i)),
      ),
      gap(6),
      // the countdown, with the collection survey as a round shortcut
      Row(
        children: [
          // the countdown shrinks rather than overflow at large text
          const Expanded(
            child: FittedBox(fit: BoxFit.scaleDown, child: NextDayCountdown()),
          ),
          Semantics(
            button: true,
            label: tr('수집품 조사와 성장'),
            excludeSemantics: true,
            child: GestureDetector(
              onTap: audible(
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CollectionScreen(profile: p),
                  ),
                ),
              ),
              child: KitRound(
                size: 48,
                child: GameIconImage(GameIcons.collectTicket, size: 32),
              ),
            ),
          ),
        ],
      ),
      gap(8),
      LayoutBuilder(
        builder: (context, box) {
          const gapX = 8.0;
          final w = (box.maxWidth - gapX * 2) / 3;
          const slot = 52.0;
          return Column(
            children: [
              for (final row in const [
                [0, 1, 2],
                [3, 4, 5],
              ]) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final i in row) ...[
                      if (i != row.first) const SizedBox(width: gapX),
                      SizedBox(width: w, child: day(i, slot)),
                    ],
                  ],
                ),
                gap(8),
              ],
              day(6, 64),
            ],
          );
        },
      ),
    ];
  }

  /// v12.15 quest list (user 2026-10-26): the activity chest track and the
  /// reset clock on top, then compact rows — picture, name with gauge,
  /// reward slots, a small claim button.
  Widget missions() {
    final weekly = missionCategory == 1;
    final rows = weekly
        ? [
            for (var i = 0; i < 4; i++)
              QuestRow(
                key: ValueKey('weekly-mission-$i'),
                icon: const [
                  GameIcons.launch,
                  GameIcons.crosshair,
                  GameIcons.bomb,
                  GameIcons.hourglass,
                ][i],
                name: _weeklyNames[i],
                progress: p.journal.weeklyProgress(i),
                target: FleetJournal.weeklyTargets[i],
                rewards: GameReward.of(FleetJournal.weeklyReward),
                claimed: p.journal.weeklyClaims.contains(i),
                claimLabel: '주간 임무 ${i + 1} 보상 받기',
                onClaim: () => act(() => p.claimWeeklyMission(i)),
              ),
          ]
        : [
            for (var i = 0; i < 3; i++)
              QuestRow(
                key: ValueKey('daily-mission-$i'),
                icon: const [
                  GameIcons.launch,
                  GameIcons.crosshair,
                  'assets/art/menu_v13/growth.webp',
                ][i],
                name: ContentSystems.dailyNames[i],
                progress: p.dailyProgress(i),
                target: ContentSystems.dailyTargets[i],
                rewards: GameReward.of(
                  FleetReward(
                    credits: 50,
                    food: 10,
                    gearKeys: i == 0 ? 1 : 0,
                    techKeys: i == 1 ? 1 : 0,
                    eggs: i == 2 ? 1 : 0,
                  ),
                  seasonXp: 50,
                ),
                claimed: p.dailyClaims.contains(i),
                claimLabel: '일일 임무 ${i + 1} 보상 받기',
                onClaim: () => act(() => p.claimDaily(i)),
              ),
          ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: weekly
              ? GameMilestoneTrack(
                  key: const Key('weekly-chests'),
                  count: p.journal.weeklyClaims.length,
                  targets: const [2, 4],
                  unit: '개',
                  claimed: p.journal.weeklyChests.contains,
                  onClaim: (i) => act(() => p.claimWeeklyActivity(i)),
                )
              : GameMilestoneTrack(
                  key: const Key('daily-chests'),
                  count: p.dailyClaims.length,
                  targets: const [1, 2, 3],
                  unit: '개',
                  claimed: p.journal.dailyChests.contains,
                  onClaim: (i) => act(
                    () => p.claimDailyActivity(i),
                    adOffer: AdOffer.chestDouble,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        _ResetClock(weekly: weekly),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            children: [
              for (final row in rows)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: row),
            ],
          ),
        ),
      ],
    );
  }

  /// Display names (the data keeps its save keys).
  static const _weeklyNames = [
    '유효 출격 5회',
    '군집 1,200기 격파',
    '보스 3기 처치',
    '집 지키기 30분',
  ];

  /// Houses the player has reached, in order.
  List<int> get _houses => [
    for (int i = 0; i < stages.length; i++)
      if (p.canStage(i) ||
          p.clearedStages.contains(i) ||
          p.journal.chapterBest.containsKey(i))
        i,
  ];

  /// v12.15 house rewards: pick a house with the arrows, see its best run
  /// on a gauge, and claim the three milestone cards (⅓, ⅔, guarded).
  Widget houses() {
    final list = _houses;
    final at = list.indexOf(chapter);
    final cleared =
        p.clearedStages.contains(chapter) ||
        p.journal.chapterWins.contains(chapter);
    final duration = stages[chapter].duration;
    final seconds = cleared ? duration : p.journal.chapterBest[chapter] ?? 0;
    String clock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    void step(int by) {
      if (list.isEmpty) return;
      final next = list[((at < 0 ? 0 : at) + by) % list.length];
      setState(() => chapter = next);
    }

    SlotState state(int i) {
      if (p.journal.chapterClaims.contains(chapter * 3 + i)) {
        return SlotState.claimed;
      }
      return p.journal.canClaimChapter(chapter, i, duration, p.clearedStages)
          ? SlotState.today
          : SlotState.locked;
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            _Arrow(
              icon: Icons.chevron_left,
              label: '이전 집',
              onTap: list.length > 1 ? () => step(-1) : null,
            ),
            Expanded(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      houseMap(chapter),
                      height: 96,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -.5),
                      cacheWidth: 360,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tr(houseOf(chapter).place),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _Arrow(
              icon: Icons.chevron_right,
              label: '다음 집',
              onTap: list.length > 1 ? () => step(1) : null,
            ),
          ],
        ),
        gap(8),
        Row(
          children: [
            Expanded(child: KitGauge(seconds / duration, height: 14)),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  children: [
                    Text(
                      '${clock(seconds)} / ${clock(duration)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: GameUi.caption,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GameTag(
                      cleared ? '지킴' : '진행 중',
                      tone: cleared ? GameTone.good : GameTone.gold,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        gap(12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  label: tr('집 보상 받기 ${i + 1}'),
                  child: GameDayCard(
                    key: ValueKey('house-reward-$i'),
                    label: i == 2
                        ? '지키기'
                        : message('{0}초', [duration * (i + 1) ~/ 3]),
                    grand: i == 2,
                    rewards: GameReward.of(FleetJournal.chapterReward(i)),
                    state: state(i),
                    slotSize: 44,
                    onTap: state(i) == SlotState.today
                        ? () => act(() => p.claimChapterReward(chapter, i))
                        : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// v12.15 patrol on one screen: the idle stash (gauge, what claiming now
  /// gives, one button) and the once-a-day quick patrol row below.
  Widget patrol() {
    final minutes = p.patrolMinutes(DateTime.now());
    final ready = minutes >= 30;
    final stash = FleetReward(
      credits: math.max(1, minutes ~/ 30) * 20,
      plans: math.max(1, minutes ~/ 60),
      food: math.max(1, minutes ~/ 60) * 5,
    );
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Surface(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  const GameIconImage(
                    'assets/art/menu_v13/patrol.webp',
                    size: 64,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        const GameTag('자동 순찰'),
                        const SizedBox(height: 6),
                        KitGauge(minutes / 480, height: 14),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            message('{0}시간 {1}분 / 8시간', [
                              minutes ~/ 60,
                              minutes % 60,
                            ]),
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: GameUi.caption,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              gap(10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  for (final r in GameReward.of(stash))
                    GameRewardSlot(
                      r,
                      size: 56,
                      state: ready ? SlotState.open : SlotState.locked,
                    ),
                ],
              ),
              gap(10),
              claim(
                '순찰 보상 회수',
                ready,
                () => p.claimPatrol(DateTime.now()),
                displayLabel: '보상 회수',
                adOffer: AdOffer.patrolDouble,
              ),
            ],
          ),
        ),
        gap(12),
        QuestRow(
          key: const ValueKey('quick-patrol'),
          icon: GameIcons.fastForward,
          name: '빠른 순찰',
          progress: math.min(p.dailyRuns, 1),
          target: 1,
          rewards: GameReward.of(FleetJournal.quickPatrolReward),
          claimed: p.journal.quickPatrolClaimed,
          claimLabel: '빠른 순찰 보상 받기',
          onClaim: () => act(() => p.claimQuickPatrol()),
        ),
      ],
    );
  }
}

/// A round arrow for stepping through houses.
class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? .4 : 1,
    child: Semantics(
      button: true,
      label: tr(label),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: audible(onTap),
        child: KitRound(size: 44, child: Icon(icon, size: 32)),
      ),
    ),
  );
}

/// "초기화까지 3시간 12분" — to the next KST midnight or Monday.
class _ResetClock extends StatelessWidget {
  const _ResetClock({required this.weekly});
  final bool weekly;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
    final days = weekly ? (8 - kst.weekday) % 7 : 1;
    final next = DateTime.utc(
      kst.year,
      kst.month,
      kst.day + (days == 0 ? 7 : days),
    );
    final left = next.difference(kst);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const GameIconImage(GameIcons.hourglass, size: 20),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              left.inDays > 0
                  ? message('초기화까지 {0}일 {1}시간', [
                      left.inDays,
                      left.inHours % 24,
                    ])
                  : message('초기화까지 {0}시간 {1}분', [
                      left.inHours,
                      left.inMinutes % 60,
                    ]),
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GameTone.muted.color,
                fontSize: GameUi.caption,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// v12.15 mobile-game quest row: picture · name with gauge and count ·
/// reward slots · a small claim button (a check once claimed).
class QuestRow extends StatelessWidget {
  const QuestRow({
    super.key,
    required this.icon,
    required this.name,
    required this.progress,
    required this.target,
    required this.rewards,
    required this.claimed,
    required this.claimLabel,
    required this.onClaim,
    this.tag,
    this.iconSize = 44,
  });
  final String icon, name, claimLabel;
  final String? tag;
  final int progress, target;
  final List<GameReward> rewards;
  final bool claimed;
  final VoidCallback onClaim;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final ready = !claimed && progress >= target;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE614284A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ready ? const Color(0xFFFFC928) : const Color(0xFF0B1830),
          width: ready ? 3 : 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Opacity(
              opacity: claimed ? .5 : 1,
              child: GameIconImage(icon, size: iconSize),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tr(name),
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      if (tag != null) ...[
                        const SizedBox(width: 4),
                        GameTag(tag!, tone: GameTone.gold),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: KitGauge(
                          target == 0 ? 1 : progress / target,
                          height: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${progress.clamp(0, target)}/$target',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: GameUi.caption,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final r in rewards)
                        GameRewardSlot(
                          r,
                          size: 36,
                          state: claimed ? SlotState.claimed : SlotState.open,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: claimed
                  ? Semantics(
                      label: tr('받음'),
                      child: const GameIconImage(GameIcons.check, size: 40),
                    )
                  : Semantics(
                      button: true,
                      enabled: ready,
                      label: tr(claimLabel),
                      excludeSemantics: true,
                      child: FilledButton(
                        style: GameUi.compactButton,
                        onPressed: audible(ready ? onClaim : null),
                        child: Text(
                          tr('받기'),
                          maxLines: 1,
                          textAlign: TextAlign.center,
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
    ('출석', '출석', Icons.storefront),
    ('임무', '임무', Icons.assignment_turned_in),
    ('집 보상', '집', Icons.emoji_events),
    ('순찰', '순찰', Icons.explore),
  ];

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return ColoredBox(
      color: const Color(0x6614263A),
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
