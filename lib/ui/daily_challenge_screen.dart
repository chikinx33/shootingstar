import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/daily_challenge.dart';
import '../data/profile.dart';
import '../main.dart';
import 'components.dart';
import 'reward_popup.dart';

/// Menu only: parent creates and settles the real engine with the captured entry.
class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({
    super.key,
    required this.profile,
    required this.onLaunch,
    required this.onExchange,
  });
  final Profile profile;
  final Future<void> Function(DailyChallengeEntry entry) onLaunch;
  final bool Function(int item) onExchange;
  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  Profile get p => widget.profile;
  DailyChallengeBook get book => p.dailyChallenge;
  Timer? timer;
  bool shop = false, launching = false;

  @override
  void initState() {
    super.initState();
    refreshClock();
    p.addListener(refresh);
    timer = Timer.periodic(const Duration(seconds: 30), (_) => refreshClock());
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  void refreshClock() {
    if (p.refreshContentClock(DateTime.now())) p.contentChanged();
    refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    p.removeListener(refresh);
    super.dispose();
  }

  Future<void> launch(int tier) async {
    if (launching) return;
    refreshClock();
    final entry = book.begin(tier);
    if (entry == null) return;
    setState(() => launching = true);
    try {
      await widget.onLaunch(entry);
    } finally {
      if (mounted) {
        setState(() => launching = false);
        refreshClock();
      }
    }
  }

  void exchange(int id) {
    refreshClock();
    claimWithRewardPopup(
      context,
      p,
      () => widget.onExchange(id),
      title: '교환 보상',
    );
  }

  Widget panel(Widget child, {bool active = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Surface(active: active, child: child),
  );

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('일일 순환 도전'), textAlign: TextAlign.center)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Center(
                  child: RasterIcon(Icons.emoji_events, size: 96, color: cyan),
                ),
                gap(16),
                const Eyebrow('DAILY FLIGHT'),
                gap(6),
                Text(
                  tr(DailyChallengeBook.variantNames[book.variant]),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),

                  textAlign: TextAlign.center,
                ),
                gap(5),
                Text(
                  message("{0} · 매일 00:00 KST 교체", [book.day]),
                  style: const TextStyle(fontSize: 14, color: muted),

                  textAlign: TextAlign.center,
                ),
                gap(8),
                Text(
                  tr(DailyChallengeBook.variantDescriptions[book.variant]),
                  textAlign: TextAlign.center,
                ),
                gap(10),
                Text(
                  message("도전 토큰 {0}", [book.tokens]),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: cyan,
                  ),

                  textAlign: TextAlign.center,
                ),
              ],
            ),
            active: true,
          ),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  key: const ValueKey('daily-tab-sortie'),
                  selected: !shop,
                  label: Text(
                    tr('오늘의 도전'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  onSelected: audibleChange(
                    launching ? null : (_) => setState(() => shop = false),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  key: const ValueKey('daily-tab-exchange'),
                  selected: shop,
                  label: Text(
                    tr('토큰 교환소'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  onSelected: audibleChange(
                    launching ? null : (_) => setState(() => shop = true),
                  ),
                ),
              ),
            ],
          ),
          gap(10),
          if (!shop) ...sorties() else ...exchanges(),
        ],
      ),
    );
  }

  List<Widget> sorties() => [
    Text(
      tr('3분 생존 후 최종 보스를 격파하세요. 각 난도의 첫 승리에서만 토큰을 받습니다.'),
      style: TextStyle(fontSize: 14, color: muted),

      textAlign: TextAlign.center,
    ),
    gap(10),
    for (var tier = 0; tier < DailyChallengeBook.tierNames.length; tier++)
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              tr(DailyChallengeBook.tierNames[tier]),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),

              textAlign: TextAlign.center,
            ),
            gap(12),
            Center(child: RasterIcon(Icons.rocket_launch, size: 72)),
            gap(12),
            Text(
              message("적 밀도 +{0}% · 적 내구 +{1}%", [tier * 15, tier * 20]),
              textAlign: TextAlign.center,
            ),
            gap(6),
            Text(
              tr(
                book.cleared.contains(tier)
                    ? '오늘 첫 승리 보상 수령 완료'
                    : '첫 승리 보상 · 도전 토큰 ${DailyChallengeBook.tokenRewards[tier]}',
              ),
              style: const TextStyle(color: cyan),

              textAlign: TextAlign.center,
            ),
            gap(8),
            Center(
              child: GameActionButton(
                key: ValueKey('daily-launch-$tier'),
                primary: true,
                icon: Icons.rocket_launch,
                onPressed: audible(launching ? null : () => launch(tier)),
                label: book.cleared.contains(tier)
                    ? '다시 출격 · 추가 보상 없음'
                    : '${DailyChallengeBook.tierNames[tier]} 도전 시작',
              ),
            ),
          ],
        ),
      ),
    panel(
      Text(
        tr(
          '하루 총 16토큰 · 재도전 무료\n'
          '패배·중도 종료·날짜가 지난 출격은 토큰을 지급하지 않습니다. '
          '일일 도전은 일반 항로 진행과 일반 출격 보상을 올리지 않습니다. '
          '보유 토큰은 날짜가 바뀌어도 유지됩니다.',
        ),
        style: TextStyle(fontSize: 14, color: muted),

        textAlign: TextAlign.center,
      ),
    ),
  ];

  List<Widget> exchanges() => [
    Text(
      tr('오늘 교환 횟수는 00:00 KST에 초기화됩니다. 보유 토큰으로만 교환합니다.'),
      style: TextStyle(fontSize: 14, color: muted),

      textAlign: TextAlign.center,
    ),
    gap(10),
    for (var id = 0; id < DailyChallengeBook.exchanges.length; id++)
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: RasterIcon(
                [
                  Icons.description,
                  Icons.pets,
                  Icons.auto_awesome,
                  Icons.vpn_key,
                ][id],
                size: 72,
              ),
            ),
            gap(12),
            Text(
              tr(DailyChallengeBook.exchanges[id].name),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),

              textAlign: TextAlign.center,
            ),
            gap(5),
            Text(
              tr(
                '오늘 남은 교환 ${DailyChallengeBook.exchanges[id].limit - book.purchases[id]} / '
                '${DailyChallengeBook.exchanges[id].limit}',
              ),
              style: const TextStyle(fontSize: 14, color: muted),

              textAlign: TextAlign.center,
            ),
            gap(8),
            GameCostLine(
              '필요 토큰 ${DailyChallengeBook.exchanges[id].cost}',
              icon: Icons.emoji_events,
            ),
            Center(
              child: GameActionButton(
                key: ValueKey('daily-exchange-$id'),
                primary: true,
                icon: Icons.card_giftcard,
                label: '토큰 ${DailyChallengeBook.exchanges[id].cost} · 교환',
                onPressed: audible(
                  !launching && book.canExchange(id)
                      ? () => exchange(id)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
  ];
}
