import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/game_icons.dart';
import '../art/toon_assets.dart';
import '../data/fleet_journal.dart';
import 'game_info.dart';
import 'game_ui.dart';

/// v12.15 mobile-game reward language (user 2026-10-26, compared with a
/// typical mobile attendance popup): a reward is a picture slot with a
/// "×N" badge, never a sentence; state is an overlay (받음 check, 오늘 glow,
/// 잠김 lock); days have a coloured header band; cumulative goals are a
/// milestone track. Names stay available to screen readers.
class GameReward {
  const GameReward(this.asset, this.amount, this.name, {this.rarity = -1});
  final String asset, name;
  final int amount;

  /// Slot rim: -1 neutral kit slot, 0..5 gray→red.
  final int rarity;

  /// The pictures of a currency bundle, biggest first.
  static List<GameReward> of(FleetReward r, {int seasonXp = 0}) => [
    if (r.credits > 0) GameReward(GameIcons.churu, r.credits, '츄르'),
    if (r.plans > 0) GameReward(GameIcons.stardust, r.plans, '별가루'),
    if (r.gearKeys > 0)
      GameReward(GameIcons.gearTicket, r.gearKeys, '장비 보급권', rarity: 2),
    if (r.techKeys > 0)
      GameReward(GameIcons.techTicket, r.techKeys, '테크 보급권', rarity: 2),
    if (r.eggs > 0) GameReward(GameIcons.petTicket, r.eggs, '펫 구조권', rarity: 3),
    if (r.collectionKeys > 0)
      GameReward(
        GameIcons.collectTicket,
        r.collectionKeys,
        '수집품 보급권',
        rarity: 3,
      ),
    if (r.food > 0) GameReward(GameIcons.food, r.food, '먹이'),
    if (seasonXp > 0) GameReward(GameIcons.season, seasonXp, '시즌 XP'),
  ];
}

enum SlotState { open, today, claimed, locked }

/// One reward picture in a kit slot with its amount badge and state overlay.
class GameRewardSlot extends StatelessWidget {
  const GameRewardSlot(
    this.reward, {
    super.key,
    this.size = 64,
    this.state = SlotState.open,
  });
  final GameReward reward;
  final double size;
  final SlotState state;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final dim = state == SlotState.claimed || state == SlotState.locked;
    return Semantics(
      label: '${tr(reward.name)} ${reward.amount}',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: dim ? .5 : 1,
                child: ToonRarityFrame(
                  rank: reward.rarity < 0 ? 0 : reward.rarity,
                  child: Padding(
                    padding: EdgeInsets.all(size * .12),
                    child: GameIconImage(reward.asset, size: size),
                  ),
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: AmountBadge(reward.amount, size: size * .26),
            ),
            if (state == SlotState.claimed)
              Positioned.fill(
                child: Center(
                  child: GameIconImage(GameIcons.check, size: size * .62),
                ),
              ),
            if (state == SlotState.locked)
              Positioned(
                left: -2,
                top: -2,
                child: GameIconImage(GameIcons.lock, size: size * .36),
              ),
          ],
        ),
      ),
    );
  }
}

/// "×N" in outlined white on a dark pill, sized to the slot.
class AmountBadge extends StatelessWidget {
  const AmountBadge(this.amount, {super.key, this.size = 16});
  final int amount;
  final double size;
  @override
  Widget build(BuildContext context) {
    final label = '×$amount';
    final style = TextStyle(
      fontSize: math.max(GameUi.minimumLabel, size),
      height: 1.1,
      fontWeight: FontWeight.w900,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE60B1830),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Stack(
          children: [
            // the outline is a raw RichText: only the fill is a Text widget
            RichText(
              textAlign: TextAlign.center,
              textScaler: MediaQuery.textScalerOf(context),
              text: TextSpan(
                text: label,
                style: DefaultTextStyle.of(context).style.merge(
                  style.copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 3
                      ..color = const Color(0xFF0B1830),
                  ),
                ),
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: style.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// A day (or step) card: coloured header band with its label, the reward
/// slots below. Today glows gold and is the tap target; claimed days dim
/// under a check; future days are plain.
class GameDayCard extends StatelessWidget {
  const GameDayCard({
    super.key,
    required this.label,
    required this.rewards,
    this.state = SlotState.open,
    this.slotSize = 56,
    this.onTap,
    this.grand = false,
  });

  /// The last, biggest reward of a cycle: purple band and gold rim.
  final bool grand;
  final String label;
  final List<GameReward> rewards;
  final SlotState state;
  final double slotSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final today = state == SlotState.today;
    final band = today
        ? const Color(0xFFFFC928)
        : grand
        ? const Color(0xFF8E4FD6)
        : const Color(0xFF3A5A8C);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF14284A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: today
              ? const Color(0xFFFFE07A)
              : grand
              ? const Color(0xFFFFC928)
              : const Color(0xFF0B1830),
          width: today || grand ? 3 : 2,
        ),
        boxShadow: today
            ? const [BoxShadow(color: Color(0x88FFC928), blurRadius: 10)]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: band,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                tr(label),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: today ? const Color(0xFF3A2410) : Colors.white,
                  fontSize: GameUi.caption + 1,
                  height: 1.3,
                  fontWeight: FontWeight.w900,
                  shadows: const [],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            // rewards sit side by side; slots shrink to fit the card
            child: LayoutBuilder(
              builder: (context, box) {
                final n = math.max(1, rewards.length);
                final side = math.min(
                  slotSize,
                  (box.maxWidth - 6 * (n - 1)) / n,
                );
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < rewards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      GameRewardSlot(
                        rewards[i],
                        size: side,
                        state: state == SlotState.claimed
                            ? SlotState.claimed
                            : SlotState.open,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: tr(label),
      child: GestureDetector(
        onTap: audible(onTap),
        child: today ? _Pulse(child: card) : card,
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  @override
  void initState() {
    super.initState();
    // a few beats, then rest (tests and screenshots settle)
    _c.repeat(reverse: true, count: 6);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween(
      begin: 1.0,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
    child: widget.child,
  );
}

/// A cumulative goal track: the count so far on the left, then chests at
/// each target along a gauge. A reached, unclaimed chest bounces and is the
/// tap target; claimed chests carry a check.
class GameMilestoneTrack extends StatelessWidget {
  const GameMilestoneTrack({
    super.key,
    required this.count,
    required this.targets,
    required this.claimed,
    required this.onClaim,
    this.unit = '일',
  });
  final int count;
  final List<int> targets;
  final bool Function(int index) claimed;
  final void Function(int index) onClaim;
  final String unit;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return GameInset(
      tone: GameTone.gold,
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 6),
      child: Row(
        children: [
          // the running count
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1830),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GameTone.gold.color, width: 2),
            ),
            child: Column(
              children: [
                Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: GameTone.gold.color,
                    fontSize: 22,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  tr(unit),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: GameUi.minimumLabel,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                const chest = 34.0;
                final w = box.maxWidth - chest;
                return SizedBox(
                  height: chest + 18,
                  child: Stack(
                    children: [
                      // gauge
                      Positioned(
                        left: chest / 2,
                        right: chest / 2,
                        top: chest / 2 - 4,
                        height: 8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _fill(count, targets),
                            backgroundColor: const Color(0xFF0B1830),
                            color: GameTone.gold.color,
                          ),
                        ),
                      ),
                      for (var i = 0; i < targets.length; i++)
                        Positioned(
                          left: targets.length < 2
                              ? w
                              : w * i / (targets.length - 1),
                          top: 0,
                          width: chest,
                          child: _MilestoneChest(
                            target: targets[i],
                            unit: unit,
                            size: chest,
                            reached: count >= targets[i],
                            claimed: claimed(i),
                            onTap: count >= targets[i] && !claimed(i)
                                ? () => onClaim(i)
                                : null,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Gauge fill with chests evenly spaced: each segment between two targets
/// fills in proportion to the count inside it.
double _fill(int count, List<int> targets) {
  if (targets.length < 2) return count >= targets.first ? 1 : 0;
  for (var i = 1; i < targets.length; i++) {
    if (count < targets[i]) {
      final from = targets[i - 1], to = targets[i];
      final part = ((count - from) / (to - from)).clamp(0.0, 1.0);
      return ((i - 1) + part) / (targets.length - 1);
    }
  }
  return 1;
}

class _MilestoneChest extends StatelessWidget {
  const _MilestoneChest({
    required this.target,
    required this.unit,
    required this.size,
    required this.reached,
    required this.claimed,
    required this.onTap,
  });
  final int target;
  final String unit;
  final double size;
  final bool reached, claimed;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final chest = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: reached || claimed ? 1 : .55,
          child: GameIconImage(GameIcons.chest, size: size),
        ),
        if (claimed) GameIconImage(GameIcons.check, size: size * .7),
      ],
    );
    return Semantics(
      button: onTap != null,
      label: message('{0}{1} 상자', [target, tr(unit)]),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: audible(onTap),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            onTap != null ? _Pulse(child: chest) : chest,
            Text(
              '$target',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: reached ? GameTone.gold.color : GameTone.muted.color,
                fontSize: GameUi.minimumLabel + 1,
                height: 1.2,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "다음 출석까지 3시간 12분" with the hourglass: time until the next KST day.
class NextDayCountdown extends StatelessWidget {
  const NextDayCountdown({super.key, this.label = '다음 출석까지'});
  final String label;

  static Duration untilNextKstDay([DateTime? now]) {
    final kst = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 9));
    final next = DateTime.utc(kst.year, kst.month, kst.day + 1);
    return next.difference(kst);
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final left = untilNextKstDay();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GameIconImage(GameIcons.hourglass, size: 22),
        const SizedBox(width: 6),
        Text(
          message('{0} {1}시간 {2}분', [
            tr(label),
            left.inHours,
            left.inMinutes % 60,
          ]),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: GameTone.muted.color,
            fontSize: GameUi.caption + 1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
