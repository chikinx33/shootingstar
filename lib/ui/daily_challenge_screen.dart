import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import 'game_decor.dart';

import '../data/daily_challenge.dart';
import '../data/profile.dart';
import 'components.dart';
import 'catalog_screens.dart' show CatalogTabs;
import 'game_slots.dart';
import 'info_dialog.dart';
import '../art/game_icons.dart';
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

  /// Display names for today's twist (the data keeps its save keys).
  static const _variantNames = ['돌입 도전', '포화 도전', '고속 도전'];

  void _rules() => showInfoDialog(
    context,
    title: '도전 규칙',
    children: [
      InfoText(DailyChallengeBook.variantDescriptions[book.variant]),
      gap8,
      const InfoText('3분 생존 후 최종 보스를 격파하세요. 각 난도의 첫 승리에서만 토큰을 받습니다.'),
      gap8,
      const InfoText(
        '하루 총 16토큰 · 재도전 무료. 패배·중도 종료·날짜가 지난 출격은 토큰을 지급하지 않습니다. 보유 토큰은 날짜가 바뀌어도 유지됩니다.',
      ),
      gap8,
      const InfoText('교환 횟수는 매일 0시(한국 시간)에 초기화됩니다.'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      appBar: GameAppBar(
        title: Text(tr('일일 순환 도전'), textAlign: TextAlign.center),
        actions: [InfoAction(label: '도전 규칙', onPressed: _rules)],
      ),
      body: Column(
        children: [
          // today's twist and the token wallet in one strip
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: GameInset(
              tone: GameTone.gold,
              child: Row(
                children: [
                  const GameIconImage(
                    'assets/art/menu_v13/challenge.webp',
                    size: 52,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        const GameTag('오늘의 도전'),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tr(_variantNames[book.variant]),
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: message('보유 도전 토큰 {0}', [book.tokens]),
                    excludeSemantics: true,
                    child: Column(
                      children: [
                        const GameIconImage(GameIcons.token, size: 36),
                        Text(
                          '${book.tokens}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: GameTone.gold.color,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          CatalogTabs(
            labels: const ['출격', '토큰 교환'],
            selected: shop ? 1 : 0,
            tight: true,
            onSelected: launching ? null : (i) => setState(() => shop = i == 1),
          ),
          Expanded(
            child: ListView(
              key: ValueKey('daily-$shop'),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              children: shop ? exchanges() : sorties(),
            ),
          ),
        ],
      ),
    );
  }

  /// A compact list row: picture, middle column, a narrow action.
  Widget _row({
    required Widget picture,
    required Widget middle,
    required Widget action,
    bool active = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE614284A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? const Color(0xFFFFC928) : const Color(0xFF0B1830),
          width: active ? 3 : 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            picture,
            const SizedBox(width: 8),
            Expanded(child: middle),
            const SizedBox(width: 8),
            SizedBox(width: 76, child: action),
          ],
        ),
      ),
    ),
  );

  List<Widget> sorties() => [
    for (var tier = 0; tier < DailyChallengeBook.tierNames.length; tier++)
      _row(
        active: !book.cleared.contains(tier),
        picture: GameRewardSlot(
          GameReward(
            GameIcons.token,
            DailyChallengeBook.tokenRewards[tier],
            '첫 승리 토큰',
            rarity: tier + 1,
          ),
          size: 52,
          state: book.cleared.contains(tier)
              ? SlotState.claimed
              : SlotState.open,
        ),
        middle: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tr(DailyChallengeBook.tierNames[tier]),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  GameTag(
                    message('적 +{0}%', [tier * 15]),
                    tone: GameTone.danger,
                  ),
                  const SizedBox(width: 4),
                  GameTag(
                    message('내구 +{0}%', [tier * 20]),
                    tone: GameTone.danger,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: Semantics(
          button: true,
          label: tr(
            book.cleared.contains(tier)
                ? '다시 출격 · 추가 보상 없음'
                : '${DailyChallengeBook.tierNames[tier]} 도전 시작',
          ),
          excludeSemantics: true,
          child: FilledButton(
            key: ValueKey('daily-launch-$tier'),
            style: GameUi.compactButton,
            onPressed: audible(launching ? null : () => launch(tier)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tr(book.cleared.contains(tier) ? '다시' : '출격'),
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
  ];

  List<Widget> exchanges() => [
    for (var id = 0; id < DailyChallengeBook.exchanges.length; id++)
      _row(
        picture: GameRewardSlot(
          GameReward.of(DailyChallengeBook.exchanges[id].reward).first,
          size: 52,
          state: book.purchases[id] >= DailyChallengeBook.exchanges[id].limit
              ? SlotState.claimed
              : SlotState.open,
        ),
        middle: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tr(DailyChallengeBook.exchanges[id].name),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 4),
            GameTag(
              message('오늘 {0}/{1}', [
                DailyChallengeBook.exchanges[id].limit - book.purchases[id],
                DailyChallengeBook.exchanges[id].limit,
              ]),
              tone: GameTone.sky,
            ),
          ],
        ),
        action: Semantics(
          button: true,
          label: tr('토큰 ${DailyChallengeBook.exchanges[id].cost} · 교환'),
          excludeSemantics: true,
          child: FilledButton(
            key: ValueKey('daily-exchange-$id'),
            style: GameUi.compactButton,
            onPressed: audible(
              !launching && book.canExchange(id) ? () => exchange(id) : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GameIconImage(GameIcons.token, size: 22),
                  const SizedBox(width: 4),
                  Text(
                    '${DailyChallengeBook.exchanges[id].cost}',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
  ];
}
