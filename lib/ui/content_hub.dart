import '../art/game_icons.dart';
import 'item_info_card.dart';
import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/profile.dart';
import '../art/ui_kit.dart';
import '../data/content_catalog.dart';
import 'components.dart';
import 'reward_popup.dart';
import 'pet_bond_screen.dart';
import 'catalog_screens.dart';
import 'item_slots.dart';
import 'cat_gear_screen.dart';

class ContentHub extends StatefulWidget {
  const ContentHub({
    super.key,
    required this.profile,
    this.initialPage = 0,
    this.showNavigation = true,
  });
  final Profile profile;
  final int initialPage;
  final bool showNavigation;
  @override
  State<ContentHub> createState() => _ContentHubState();
}

class _ContentHubState extends State<ContentHub> {
  late int page = widget.initialPage;
  Profile get p => widget.profile;
  Timer? timer;
  @override
  void initState() {
    super.initState();
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

  void act(bool Function() action, {RewardEntry? item}) {
    final before = RewardSnapshot(p);
    final done = action();
    if (done) showTransactionFeedback(context, p, before, item: item);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            done
                ? (p.lastLoot.isEmpty ? '적용했습니다.' : p.lastLoot)
                : '재료·츄르·장착 슬롯을 확인하세요.',
          ),

          textAlign: TextAlign.center,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    p.lastLoot = '';
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Column(
      children: [
        if (widget.showNavigation)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
            child: LayoutBuilder(
              builder: (context, c) => Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final i in [0, 1, 2])
                    SizedBox(
                      width: (c.maxWidth - 12) / 3,
                      child: GameTab(
                        label: ['장비', '무기', '병아리'][i],
                        selected: page == i,
                        onTap: () {
                          p.refreshContentClock(DateTime.now());
                          setState(() => page = i);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        Expanded(
          // v12.10.1: equipment and weapons are one screen whose slots swap
          child: page <= 1
              ? CatGearScreen(profile: p, weapons: page == 1)
              : page == 2
              ? petsPage()
              : page == 3
              ? SupplyShop(profile: p)
              : SeasonMailbox(profile: p),
        ),
      ],
    );
  }

  /// The pet being looked at below the pet slots (default: the deployed one).
  int? petPick;

  /// v12.10.1 (user 2026-10-26): a pet slot shows its details in the free
  /// space under the slots instead of a popup.
  /// v12.17 (user 2026-10-27): nine chick kinds as picture slots; up to six
  /// carry a numbered 출전 badge (their order in the battle tail).
  Widget petsPage() {
    final i = (petPick ?? math.max(0, p.activePet)).clamp(
      0,
      petNames.length - 1,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GameTag(
                message('출전 {0}/{1}', [
                  p.deployedChicks.length,
                  maxDeployedChicks,
                ]),
                tone: GameTone.good,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          // three kit slots on screen, the rest a swipe away
          child: LayoutBuilder(
            builder: (context, box) {
              const gap = 6.0;
              final w = (box.maxWidth - gap * 2) / 3;
              // the web test build swipes with a mouse as well as a finger
              return ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                child: SingleChildScrollView(
                  key: const Key('pet-slots'),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var k = 0; k < petNames.length; k++)
                        Padding(
                          padding: EdgeInsets.only(left: k == 0 ? 0 : gap),
                          child: SizedBox(
                            width: w,
                            child: GameItemSlot(
                              key: ValueKey('pet-slot-$k'),
                              title: petNames[k],
                              image: Opacity(
                                opacity: p.chickOwned(k) ? 1 : .45,
                                child: GameIconImage(
                                  'assets/art/pets_v14/pet_$k.webp',
                                  size: 56,
                                ),
                              ),
                              status: !p.chickOwned(k)
                                  ? '미구조'
                                  : p.deployedChicks.contains(k)
                                  ? message('출전 {0}', [
                                      p.deployedChicks.indexOf(k) + 1,
                                    ])
                                  : 'Lv.${p.petLevels[k]}',
                              selected: p.deployedChicks.contains(k),
                              rarity: p.petRanks[k],
                              onTap: audible(
                                () => setState(() => petPick = k),
                                cue: 'select',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Align(
              child: UiKitFrame(
                'panel',
                key: const Key('pet-detail'),
                corner: 18,
                child: GamePages(
                  key: ValueKey('pet-detail-$i'),
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  children: petDetail(i),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> petDetail(int i) {
    final rescued = p.petLevels[i] > 0;
    final active = p.deployedChicks.contains(i);
    final maxLevel = 20 + p.petRanks[i] * 10;
    final food = p.petLevels[i] * 10;
    final shards = 3 * (p.petRanks[i] + 1);
    // v12.15: the chick in its grade frame with state/level/grade pills,
    // one line of flavour, then icon lines for food, cost and shards.
    return [
      ItemHero(
        image: GameIconImage('assets/art/pets_v14/pet_$i.webp', size: 64),
        name: petNames[i],
        rarity: p.petRanks[i],
        chips: [
          (
            active ? '출전 중' : (rescued ? '대기 중' : '미구조'),
            active
                ? const Color(0xFF7CE08A)
                : (rescued ? const Color(0xFF8FD3FF) : const Color(0xFF8A98AE)),
          ),
          if (rescued) ('Lv.${p.petLevels[i]}', const Color(0xFFFFD43D)),
          (qualityNames[p.petRanks[i]], const Color(0xFF8FD3FF)),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        tr(petDescriptions[i]),
        textAlign: TextAlign.center,
        maxLines: 2,
        style: TextStyle(
          fontSize: 15,
          height: 1.3,
          color: GameTone.muted.color,
        ),
      ),
      const SizedBox(height: 8),
      StatGrid(
        rescued
            ? [
                StatLine(
                  label: '보유 먹이',
                  value: '${p.petFood}',
                  icon: GameIcons.food,
                  color: const Color(0xFFFFD43D),
                ),
                StatLine(
                  label: '육성',
                  value: p.petLevels[i] < maxLevel ? '$food' : '최대',
                  icon: GameIcons.food,
                  color: p.petFood >= food
                      ? const Color(0xFF7CE08A)
                      : const Color(0xFFFF7A6B),
                ),
                StatLine(
                  label: '승급 조각',
                  value: '${p.petShards[i]}/$shards',
                  icon: GameIcons.gene,
                  color: p.petShards[i] >= shards
                      ? const Color(0xFF7CE08A)
                      : Colors.white,
                ),
              ]
            : [
                StatLine(
                  label: '구조용 알',
                  value: '${p.petEggs}',
                  icon: GameIcons.petTicket,
                  color: const Color(0xFFFFD43D),
                ),
              ],
      ),
      const SizedBox(height: 12),
      if (rescued) ...[
        // deployment on one line, growth on the next
        GameActionStrip(
          children: [
            // v12.17: one 출전 card toggle (up to six cards)
            GameActionTile(
              key: const Key('pet-deploy'),
              label: active ? '출전 해제' : '출전',
              icon: Icons.rocket_launch,
              image: 'assets/art/ui_v13/act_launch.webp',
              primary: !active,
              onPressed: active || p.deployedChicks.length < maxDeployedChicks
                  ? () => act(() => p.toggleDeployChick(i))
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        GameActionStrip(
          children: [
            GameActionTile(
              key: const Key('pet-feed'),
              label: '펫 육성',
              displayLabel: '육성',
              icon: Icons.upgrade,
              image: 'assets/art/ui_v13/act_feed.webp',
              onPressed: p.petFood >= food && p.petLevels[i] < maxLevel
                  ? () => act(() => p.feedPet(i))
                  : null,
            ),
            GameActionTile(
              key: const Key('pet-evolve'),
              label: '펫 승급',
              displayLabel: '승급',
              icon: Icons.auto_awesome,
              image: 'assets/art/ui_v13/act_promote.webp',
              onPressed: p.petRanks[i] < 5 && p.petShards[i] >= shards
                  ? () => act(() => p.evolvePet(i))
                  : null,
            ),
            GameActionTile(
              key: const Key('pet-bond'),
              label: '각성·호감도',
              displayLabel: '호감도',
              icon: Icons.favorite,
              image: 'assets/art/ui_v13/act_heart.webp',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PetBondScreen(profile: p, pet: i),
                ),
              ),
            ),
          ],
        ),
      ] else
        GameActionButton(
          label: '펫 구조하기',
          primary: true,
          image: GameIcons.petTicket,
          onPressed: audible(
            p.petEggs > 0
                ? () => claimWithRewardPopup(context, p, p.rescuePet)
                : null,
          ),
        ),
    ];
  }
}
