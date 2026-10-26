import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'game_decor.dart';

import '../data/collection_book.dart';
import '../data/profile.dart';
import '../art/toon_assets.dart';
import '../main.dart';
import 'components.dart';
import 'catalog_screens.dart';
import 'reward_popup.dart';
import 'item_slots.dart';
import 'detail_widgets.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, required this.profile});
  final Profile profile;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  int tab = 0;
  Profile get p => widget.profile;
  CollectionBook get book => p.collections;
  static const _colors = [
    Color(0xFFFFBA60),
    Color(0xFF75D5AD),
    Color(0xFF77C6FF),
    Color(0xFFBAA1FF),
  ];
  static const _icons = [60, 42, 29, 54, 37, 30, 48, 0, 4, 33, 5, 22];

  @override
  void initState() {
    super.initState();
    p.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    p.removeListener(_refresh);
    super.dispose();
  }

  void _apply(bool Function() action, String message) {
    final before = RewardSnapshot(p);
    if (!action()) return;
    showTransactionFeedback(context, p, before);
    p.lastLoot = message;
    p.contentChanged();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(tr(message), textAlign: TextAlign.center)),
      );
  }

  Future<void> _confirm({
    required String title,
    required String body,
    required String confirm,
    required bool Function() action,
    required String message,
  }) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => GameDialog(
        title: title,
        actions: [
          GameActionButton(
            label: '취소',
            onPressed: audible(() => Navigator.pop(dialog, false)),
          ),
          GameActionButton(
            label: confirm,
            primary: true,
            icon: Icons.check,
            onPressed: audible(() => Navigator.pop(dialog, true)),
          ),
        ],
        child: Text(tr(body), textAlign: TextAlign.center),
      ),
    );
    if (accepted == true && mounted) _apply(action, message);
  }

  String _percent(double value) =>
      '${(value * 100).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}%';

  Widget _icon(int id, {double size = 48}) {
    final discovered = book.levels[id] > 0;
    final color = _colors[relicCatalog[id].setId];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: discovered ? color.withValues(alpha: .18) : panel,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: discovered ? color : muted, width: 2),
      ),
      child: Opacity(
        opacity: discovered ? 1 : .5,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ToonTile('icons', _icons[id], size: size * .8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      appBar: GameAppBar(title: Text(tr('항로 유물'), textAlign: TextAlign.center)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            CatalogHeader(
              title: '항로 유물',
              status:
                  '발견 ${book.discoveredCount}/12 · 활성 세트 ${book.activeSets.length}/2',
              icon: Icons.auto_awesome,
            ),
            CatalogTabs(
              labels: const ['조사', '세트', '보관함'],
              selected: tab,
              onSelected: audibleChange((v) => setState(() => tab = v)),
            ),
            Expanded(
              child: switch (tab) {
                0 => GamePages(
                  key: const Key('collection-investigation'),
                  children: [
                    Center(child: _icon(book.nextRelicId, size: 100)),
                    gap(12),
                    // v12.14: labelled next target and holdings; the rule is
                    // a quiet hint and the set bonuses sit in their own tiles.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const GameTag('다음 조사'),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            tr(relicCatalog[book.nextRelicId].name),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    gap(10),
                    // Align keeps the pairs on one line (the pager would
                    // otherwise stack each Wrap child).
                    Align(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 14,
                        runSpacing: 4,
                        children: [
                          _Pair('탐사권', '${book.keys}', tone: GameTone.good),
                          _Pair('유물 가루', '${book.dust}', tone: GameTone.sky),
                        ],
                      ),
                    ),
                    gap(8),
                    const GameHint('탐사권 1개로 유물 조각 3개를 획득합니다. 12종을 차례로 조사합니다.'),
                    gap(16),
                    Center(
                      child: GameActionButton(
                        label: '유물 조사 · 탐사권 1',
                        displayLabel: '유물 조사',
                        primary: true,
                        icon: Icons.travel_explore,
                        onPressed: audible(
                          book.canOpenSupply
                              ? () => claimWithRewardPopup(context, p, () {
                                  final name =
                                      relicCatalog[book.nextRelicId].name;
                                  if (!book.openSupply()) return false;
                                  p.lastLoot = '$name 조각 3개를 발견했습니다.';
                                  p.contentChanged();
                                  return true;
                                }, title: '조사 완료')
                              : null,
                        ),
                      ),
                    ),
                    gap(12),
                    GameFactRow([
                      for (final (label, value) in [
                        ('화력', book.damageBonus),
                        ('선체', book.hullBonus),
                        ('회수', book.pickupBonus),
                        ('쿨다운 단축', book.cooldownBonus),
                      ])
                        GameFact(
                          label,
                          '+${_percent(value)}',
                          tone: GameTone.good,
                        ),
                    ]),
                  ],
                ),
                1 => GameSlotList(
                  listKey: const Key('collection-set-items'),
                  children: [
                    for (var id = 0; id < relicSets.length; id++)
                      GameItemSlot(
                        title: relicSets[id].name,
                        image: _icon(id * 3, size: 56),
                        status: book.activeSets.contains(id) ? '활성 중' : '세트',
                        selected: book.activeSets.contains(id),
                        onTap: audible(
                          () => _slotDetail(
                            relicSets[id].name,
                            () => _setCard(id),
                          ),
                        ),
                      ),
                  ],
                ),
                _ => GameSlotList(
                  listKey: const Key('collection-relic-items'),
                  children: [
                    for (var id = 0; id < relicCatalog.length; id++)
                      GameItemSlot(
                        title: relicCatalog[id].name,
                        image: _icon(id, size: 56),
                        status: 'Lv.${book.levels[id]}',
                        onTap: audible(
                          () => _slotDetail(
                            relicCatalog[id].name,
                            () => _relicCard(id),
                          ),
                        ),
                      ),
                  ],
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  void _slotDetail(String title, Widget Function() contents) =>
      showDialog<void>(
        context: context,
        builder: (_) => AnimatedBuilder(
          animation: p,
          builder: (_, _) => GameDialog(title: title, child: contents()),
        ),
      );

  Widget _setCard(int id) {
    final set = relicSets[id];
    final discovered = book.levels
        .skip(id * 3)
        .take(3)
        .where((l) => l > 0)
        .length;
    final active = book.activeSets.contains(id);
    return Surface(
      active: active,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  message("{0} · {1}/3", [set.name, discovered]),
                  style: TextStyle(
                    color: _colors[id],
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),

                  textAlign: TextAlign.center,
                ),
              ),
              Text(
                tr(active ? '활성 중' : '대기'),
                style: const TextStyle(fontSize: 16),

                textAlign: TextAlign.center,
              ),
            ],
          ),
          gap(6),
          Text(
            tr(set.bonus),
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          gap(8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (var i = id * 3; i < id * 3 + 3; i++) _icon(i, size: 56),
            ],
          ),
          gap(8),
          Text(
            tr(
              active
                  ? '활성 중'
                  : discovered < 3
                  ? '유물 3종 복원 필요'
                  : book.activeSets.length >= 2
                  ? '다른 세트를 먼저 해제하세요'
                  : '활성화할 수 있습니다.',
            ),
            style: const TextStyle(fontSize: 16),

            textAlign: TextAlign.center,
          ),
          gap(12),
          Center(
            child: GameActionButton(
              label: active ? '세트 해제' : '세트 활성화',
              icon: Icons.auto_awesome,
              onPressed: audible(
                book.canToggleSet(id)
                    ? () => _apply(
                        () => book.toggleSet(id),
                        '${set.name} 세트 ${active ? '해제' : '활성화'}',
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _relicCard(int id) {
    final relic = relicCatalog[id];
    final level = book.levels[id];
    final cost = book.upgradeCost(id);
    return Surface(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          InkWell(
            onTap: audible(() => _details(id)),
            child: Semantics(
              button: true,
              label: message("{0} 상세", [relic.name]),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    _icon(id, size: 72),
                    gap(8),
                    Text(
                      tr(relic.name),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      tr(level == 0 ? '미복원' : '★ $level/5'),
                      style: TextStyle(
                        color: _colors[relic.setId],
                        fontSize: 16,
                      ),

                      textAlign: TextAlign.center,
                    ),
                    Text(
                      message("조각 {0}개", [book.shards[id]]),
                      style: const TextStyle(fontSize: 16),

                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          gap(8),
          Text(
            tr(level == CollectionBook.maxLevel ? '최고 등급' : '필요 조각 $cost개'),
            style: const TextStyle(fontSize: 16),

            textAlign: TextAlign.center,
          ),
          gap(12),
          GameActionButton(
            label: '${relic.name} ${level == 0 ? '복원' : '강화'}',
            displayLabel: level == CollectionBook.maxLevel
                ? '완료'
                : level == 0
                ? '복원'
                : '강화',
            primary: true,
            icon: Icons.upgrade,
            onPressed: audible(
              book.canUpgrade(id)
                  ? () => _apply(
                      () => book.upgrade(id),
                      '${relic.name} ${level + 1}등급',
                    )
                  : null,
            ),
          ),
          gap(12),
          GameActionButton(
            label: '${relic.name} 상세',
            displayLabel: '조각 관리',
            onPressed: audible(() => _details(id)),
          ),
        ],
      ),
    );
  }

  Future<void> _details(int id) => showDialog<void>(
    context: context,
    builder: (dialog) => AnimatedBuilder(
      animation: p,
      builder: (context, _) {
        final relic = relicCatalog[id];
        final refund = book.resetRefund(id);
        return GameDialog(
          title: relic.name,
          closeLabel: '유물 상세 닫기',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GameDetailHeader(
                image: _icon(id, size: 72),
                title: '등급 ${book.levels[id]}/5',
                status: message('보유 조각 {0} · 가루 {1}', [
                  book.shards[id],
                  book.dust,
                ]),
              ),
              Text(tr(relic.detail), textAlign: TextAlign.center),
              gap(8),
              GameInfoBlock(
                label: '세트 효과',
                tone: GameTone.good,
                lead: relicSets[relic.setId].passive,
              ),
              gap(8),
              const GameHint('원하는 조각 제작 · 가루 3개'),
              gap(12),
              GameDetailTools(
                children: [
                  GameActionButton(
                    label: '조각 제작 · 가루 3',
                    displayLabel: '조각 제작',
                    onPressed: audible(
                      book.canCraft(id)
                          ? () => _confirm(
                              title: '선택 조각 제작',
                              body: '가루 3개 → ${relic.name} 조각 1개',
                              confirm: '가루 3개 사용',
                              action: () => book.craft(id),
                              message: '${relic.name} 조각 1개 제작',
                            )
                          : null,
                    ),
                  ),
                  if (book.shards[id] > 0)
                    GameActionButton(
                      label: '조각 분해 · 1개 → 가루 1',
                      displayLabel: '조각 분해',
                      onPressed: audible(
                        book.dust < CollectionBook.resourceCap
                            ? () => _confirm(
                                title: '미사용 조각 분해',
                                body:
                                    '${relic.name} 조각 1개 → 가루 1개\n다시 제작하려면 가루 3개가 필요합니다.',
                                confirm: '조각 1개 분해',
                                action: () => book.recycle(id, 1),
                                message: '유물 가루 1개 획득',
                              )
                            : null,
                      ),
                    ),
                ],
              ),
              if (book.levels[id] > 1) ...[
                gap(12),
                Center(
                  child: GameActionButton(
                    label: '강화 초기화 · 조각 반환',
                    displayLabel: '강화 초기화',
                    icon: Icons.restart_alt,
                    onPressed: audible(
                      book.shards[id] <= CollectionBook.resourceCap - refund
                          ? () => _confirm(
                              title: '유물 강화 초기화',
                              body:
                                  '1등급으로 초기화 · 사용 조각 $refund개 반환\n발견·세트 완성 상태는 유지됩니다.',
                              confirm: '1등급으로 초기화',
                              action: () => book.reset(id),
                              message: '${relic.name} 초기화 · 조각 $refund개 반환',
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

/// "label value" inline: a coloured tag and its bold value.
class _Pair extends StatelessWidget {
  const _Pair(this.label, this.value, {this.tone = GameTone.gold});
  final String label, value;
  final GameTone tone;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameTag(label, tone: tone),
        const SizedBox(width: 4),
        Text(
          tr(value),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
