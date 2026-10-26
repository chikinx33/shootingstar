import 'dart:math' as math;

import '../l10n/app_language.dart';

import 'audio_feedback.dart';
import 'module_workshop.dart';

import 'package:flutter/material.dart';

import 'game_decor.dart';
import 'game_motion.dart';
import 'reward_popup.dart';

import '../art/game_icons.dart';
import 'item_info_card.dart';
import '../art/ship_sprite_art.dart';
import '../art/ui_kit.dart';
import '../data/content.dart';
import '../data/profile.dart';
import 'components.dart';
import 'item_slots.dart';
import 'lobby_cat_hero.dart';

/// Guardian cat + craft selection (v12.9 redesign, user 2026-10-25: the
/// old screen was three tiny jet cards on an empty page). The focused cat
/// stands on the hangar pedestal with its own craft hovering beside it; its
/// role, fixed main gun and stats sit in one game panel above the single
/// decision, and the three cats are big portrait slots at the bottom.
class ShipHangar extends StatefulWidget {
  const ShipHangar({super.key, required this.profile});
  final Profile profile;

  @override
  State<ShipHangar> createState() => _ShipHangarState();
}

class _ShipHangarState extends State<ShipHangar> {
  late int _focus = widget.profile.selectedShip.clamp(0, ships.length - 1);
  Profile get p => widget.profile;

  static const _guns = ['냥냥 연사포', '정밀 냥냥포', '꾹꾹 산탄포'];
  static const _ultimates = ['별똥별 광선', '냥냥 미사일 폭풍', '꾹꾹이 충격파'];

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      appBar: GameAppBar(
        title: Text(tr('기체 선택'), textAlign: TextAlign.center),
        actions: [
          IconButton(
            tooltip: tr('조합형 기체 설계'),
            icon: const Icon(Icons.design_services),
            onPressed: audible(
              () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ModuleWorkshop(profile: p),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: p,
          builder: (context, _) => LayoutBuilder(
            builder: (context, box) {
              final compact = box.maxHeight < 600;
              return Column(
                children: [
                  Expanded(child: _showcase(_focus)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _info(_focus, compact),
                  ),
                  const SizedBox(height: 8),
                  _decision(_focus),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: GameSlotRows(
                      children: [
                        for (var i = 0; i < ships.length; i++) _slot(i),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// The cat on the glowing pedestal, its craft hovering at its shoulder.
  Widget _showcase(int i) {
    final owned = p.unlockedShips.contains(i);
    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight, w = box.maxWidth;
        final pedestal = math.min(w * .62, h * .9);
        final cat = math.min(h * .92, w * .62);
        final craft = math.min(h * .5, w * .32);
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -h * .1,
              child: GlowRays(
                size: math.max(w * .9, h * 1.1),
                color: ships[i].color,
                opacity: .35,
              ),
            ),
            Positioned(
              bottom: 0,
              child: Image.asset(
                '${UiKit.root}pedestal.webp',
                width: pedestal,
                filterQuality: FilterQuality.medium,
              ),
            ),
            // the cat stands on the pedestal's top face
            Positioned(
              bottom: pedestal * .3,
              left: w / 2 - cat * .62,
              child: KeyedSubtree(
                key: ValueKey('ship-cat-$i'),
                child: PopIn(
                  child: ColorFiltered(
                    colorFilter: owned
                        ? const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.dst,
                          )
                        : const ColorFilter.mode(
                            Color(0xCC101828),
                            BlendMode.srcATop,
                          ),
                    child: Image.asset(
                      LobbyCatHero.portraits[i],
                      width: cat,
                      height: cat,
                      filterQuality: FilterQuality.medium,
                      semanticLabel: tr(ships[i].name),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: w * .04,
              top: h * .04,
              child: Bob(
                height: 6,
                period: 2600,
                child: SizedBox.square(
                  dimension: craft,
                  child: ShipSprite(
                    key: ValueKey('ship-craft-$i'),
                    hull: i,
                    loadout: i == p.selectedShip ? p.moduleLoadout : null,
                    assets: i == p.selectedShip ? p.shipLayerAssets : const {},
                    semanticLabel: message('{0} 고유 기체', [tr(ships[i].name)]),
                  ),
                ),
              ),
            ),
            if (!owned)
              Positioned(
                bottom: pedestal * .42,
                child: GameIconImage(GameIcons.lock, size: 58),
              ),
          ],
        );
      },
    );
  }

  /// Name ribbon, role, the fixed main gun and the stat gauges.
  Widget _info(int i, bool compact) {
    final ship = ships[i];
    double top(double Function(ShipSpec s) f) => ships.map(f).reduce(math.max);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 22),
          child: Surface(
            padding: EdgeInsets.fromLTRB(24, compact ? 26 : 30, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!compact)
                  Text(
                    tr(ship.tagline),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFD43D),
                    ),
                  ),
                // v12.9.2: the cat is the pilot; its fixed trait
                // v12.14: labelled — a "특기" tag, the trait name, its effect
                Row(
                  key: ValueKey('ship-trait-$i'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const GameTag('특기', tone: GameTone.good),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: tr(catTraitFor(i).name),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF8FF0C8),
                              ),
                            ),
                            if (!compact)
                              TextSpan(
                                text: '  ${tr(catTraitFor(i).short)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: GameTone.muted.color,
                                ),
                              ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                // the smallest phones keep the gun line for the stats only
                if (!compact) ...[
                  const SizedBox(height: 6),
                  StatGrid([
                    StatLine(
                      label: '고유 주포',
                      value: _guns[i],
                      color: const Color(0xFFFF8A5C),
                    ),
                    StatLine(
                      label: '궁극기',
                      value: _ultimates[i],
                      color: const Color(0xFFD9A8FF),
                    ),
                  ]),
                ],
                if (compact) ...[
                  const SizedBox(height: 6),
                  GameFactRow([
                    GameFact('선체', '${ship.health.toInt()}'),
                    GameFact(
                      '화력',
                      '${(ship.damage * 100).round()}%',
                      tone: GameTone.danger,
                    ),
                  ]),
                ] else ...[
                  const SizedBox(height: 6),
                  _gauge(
                    '선체',
                    ship.health / top((s) => s.health),
                    '${ship.health.toInt()}',
                    i,
                  ),
                  _gauge(
                    '화력',
                    ship.damage / top((s) => s.damage),
                    '${(ship.damage * 100).round()}%',
                    i,
                  ),
                ],
              ],
            ),
          ),
        ),
        RibbonTitle(ship.name, width: 270, height: 48, size: 21),
      ],
    );
  }

  /// A kit track filled with a yellow pill up to [value] (0..1).
  Widget _gauge(String label, double value, String text, int i) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        // v12.15: the stat is its picture (heart, boots, crosshair)
        SizedBox(
          width: 44,
          child: Semantics(
            label: tr(label),
            child: GameIconImage(StatIcons.of(label), size: 28),
          ),
        ),
        Expanded(
          child: KitGauge(
            value.clamp(.08, 1),
            key: ValueKey('gauge-$label-$i'),
            height: 18,
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );

  Widget _decision(int i) {
    final ship = ships[i];
    final owned = p.unlockedShips.contains(i);
    final selected = p.selectedShip == i;
    return GameActionButton(
      key: ValueKey('ship-select-$i'),
      primary: true,
      label: selected
          ? '${ship.name} 장착 중'
          : owned
          ? '${ship.name} 선택'
          : '${ship.name} ${ship.unlockCost} 츄르 해금·선택',
      displayLabel: selected
          ? '장착 중'
          : owned
          ? '이 고양이로 출격'
          : message('해금 {0}', [ship.unlockCost]),
      icon: selected
          ? Icons.check
          : (owned ? Icons.play_arrow : Icons.lock_open),
      // the unlock price is the churu picture beside its number
      image: selected || owned ? null : GameIcons.churu,
      onPressed: selected || (!owned && p.credits < ship.unlockCost)
          ? null
          : () {
              if (owned || p.unlockShip(i)) {
                p.selectShip(i);
                RewardFlights.show(context, [
                  RewardEntry(
                    ship.name,
                    1,
                    Icons.rocket_launch,
                    atlas: 'hero',
                    index: i,
                  ),
                ]);
              }
            },
    );
  }

  Widget _slot(int i) => GameItemSlot(
    title: ships[i].name,
    image: Image.asset(
      LobbyCatHero.faces[i],
      width: 84,
      height: 84,
      filterQuality: FilterQuality.medium,
      color: p.unlockedShips.contains(i) ? null : const Color(0xFF8090A8),
      colorBlendMode: BlendMode.modulate,
    ),
    status: p.unlockedShips.contains(i)
        ? (p.selectedShip == i ? '장착 중' : '보유')
        : '${ships[i].unlockCost} 츄르',
    selected: _focus == i,
    onTap: () => setState(() => _focus = i),
  );
}
