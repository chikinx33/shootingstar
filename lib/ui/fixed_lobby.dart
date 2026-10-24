import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/ui_kit.dart';

import 'lobby_cat_hero.dart';
import 'guardian_quest_screen.dart';

import 'supporter_cosmetic.dart';

import '../art/flight_scene_art.dart';
import '../art/toon_assets.dart';
import '../data/content.dart';
import '../data/profile.dart';
import 'components.dart';
import 'arcade_home_widgets.dart';
import 'ship_hangar.dart';

/// Fixed launch board. Only the showcase yields space on shorter phones.
class FixedLobby extends StatelessWidget {
  const FixedLobby({
    super.key,
    required this.profile,
    required this.onChapter,
    required this.onLaunch,
    required this.onTraining,
    required this.onGuide,
    required this.onActivity,
    required this.onSeason,
    required this.onGuild,
    required this.onHangar,
  });
  final Profile profile;
  final VoidCallback onChapter,
      onLaunch,
      onTraining,
      onGuide,
      onSeason,
      onGuild,
      onHangar;
  final ValueChanged<int> onActivity;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Padding(
      key: const Key('fixed-lobby'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: LayoutBuilder(
        builder: (context, board) {
          final tight = board.maxHeight < 400;
          return Stack(
            children: [
              ..._standingCat(context, board, tight),
              Column(
                children: [
                  Semantics(
                    button: true,
                    label: tr('챕터 선택'),
                    excludeSemantics: true,
                    onTap: audible(onChapter),
                    child: InkWell(
                      onTap: audible(onChapter),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: RasterPanel(
                          skin: 4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                if (!tight)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: ToonTile(
                                      'worlds',
                                      profile.selectedStage ~/ 10,
                                      size: 44,
                                    ),
                                  ),
                                if (!tight) const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      if (!tight)
                                        Text(
                                          message("WORLD {0}  /  {1}순환", [
                                            profile.selectedStage ~/ 10 + 1,
                                            profile.campaignLoop + 1,
                                          ]),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            height: 1.2,
                                            color: Color(0xFF89C9DC),
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                          ),

                                          textAlign: TextAlign.center,
                                        ),
                                      if (!tight) const SizedBox(height: 3),
                                      Text(
                                        tr(
                                          tight
                                              ? worlds[profile.selectedStage ~/
                                                        10]
                                                    .name
                                              : stages[profile.selectedStage]
                                                    .name,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          height: 1.15,
                                          fontWeight: FontWeight.w900,
                                        ),

                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                                if (tight) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    message("{0}항로", [
                                      profile.selectedStage % 10 + 1,
                                    ]),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFFFD261),
                                    ),

                                    textAlign: TextAlign.center,
                                  ),
                                ],
                                const Icon(
                                  Icons.chevron_right,
                                  size: 28,
                                  color: Color(0xFFFFD261),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, field) {
                        final compactActions = field.maxHeight < 146;
                        final shortcutGap = ((field.maxHeight - 144) / 2).clamp(
                          0.0,
                          6.0,
                        );
                        final actionHeight =
                            ((field.maxHeight - shortcutGap * 2) / 3).clamp(
                              48.0,
                              80.0,
                            );
                        Widget shortcut(
                          String art,
                          String label,
                          String visible,
                          VoidCallback action,
                        ) => BridgeAction(
                          art: art,
                          label: label,
                          displayLabel: visible,
                          height: actionHeight,
                          compact: compactActions,
                          width: 64,
                          onTap: audible(action)!,
                        );
                        final shortcuts = [
                          shortcut(
                            'mission',
                            '임무·출석',
                            '임무',
                            () => onActivity(1),
                          ),
                          shortcut('season', '시즌 보상', '시즌', onSeason),
                          shortcut('patrol', '순찰', '순찰', () => onActivity(3)),
                          shortcut('guild', '길드', '길드', onGuild),
                          shortcut('hangar', '격납고', '격납고', onHangar),
                          shortcut(
                            'achievement',
                            profile.questAttention > 0
                                ? '모모 대장의 임무 · 보상 ${profile.questAttention}개'
                                : '모모 대장의 임무',
                            '업적',
                            () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    GuardianQuestScreen(profile: profile),
                              ),
                            ),
                          ),
                        ];
                        return SizedBox(
                          key: const Key('fixed-lobby-field'),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ...[
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  child: Column(
                                    children: [
                                      shortcuts[0],
                                      SizedBox(height: shortcutGap),
                                      shortcuts[1],
                                      SizedBox(height: shortcutGap),
                                      shortcuts[4],
                                    ],
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Column(
                                    children: [
                                      shortcuts[2],
                                      SizedBox(height: shortcutGap),
                                      shortcuts[3],
                                      SizedBox(height: shortcutGap),
                                      Badge(
                                        isLabelVisible:
                                            profile.questAttention > 0,
                                        label: Text(
                                          '${profile.questAttention}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        child: shortcuts[5],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _launchSide(
                        '45초 훈련',
                        '훈련',
                        Icons.timer_outlined,
                        onTraining,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Center(
                          child: GameActionButton(
                            key: const Key('launch'),
                            displayLabel: '출격',
                            primary: true,
                            panelColor: const Color(0xFFFFCC47),
                            onPressed: audible(onLaunch),
                            label: '${stages[profile.selectedStage].name} · 출격',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _launchSide(
                        '비행 가이드',
                        '가이드',
                        Icons.question_mark,
                        onGuide,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// The cat stands on the cushion painted in the living room: its feet go
  /// where [RefitBackdrop] draws the cushion for this screen size. On short
  /// screens it is lifted only as far as its name needs above the launch row.
  List<Widget> _standingCat(
    BuildContext context,
    BoxConstraints board,
    bool tight,
  ) {
    // The board sits inside the backdrop with this padding (see build).
    const inset = Offset(12, 8);
    final cushion =
        FlightSceneArt.coverPoint(
          Size(board.maxWidth + 24, board.maxHeight + 12),
          FlightSceneArt.lobbyArtSize,
          FlightSceneArt.lobbyCushion,
        ) -
        inset;
    final nameHeight = tight
        ? 0.0
        : MediaQuery.textScalerOf(context).scale(24) * 1.3 + 6;
    // chapter panel above, launch row below
    const top = 74.0, bottom = 90.0;
    final floor = math.min(cushion.dy, board.maxHeight - bottom - nameHeight);
    final feet = LobbyCatHero.feetOf(profile);
    // The picture's box stays clear of the 64px shortcut columns.
    const side = 68.0;
    final size = [
      230.0,
      (floor - top) / feet.dy,
      (cushion.dx - side) / feet.dx,
      (board.maxWidth - side - cushion.dx) / (1 - feet.dx),
    ].reduce(math.min).clamp(64.0, 230.0);
    final ship = ships[profile.selectedShip];
    return [
      Positioned(
        left: cushion.dx - feet.dx * size,
        top: floor - feet.dy * size,
        child: SupporterCosmetic(
          active: profile.commerce?.cosmeticActive == true,
          child: LobbyCatHero(
            profile: profile,
            size: size,
            onSelectShip: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ShipHangar(profile: profile),
              ),
            ),
          ),
        ),
      ),
      if (!tight)
        Positioned(
          left: 0,
          right: 0,
          top: floor + size * .045,
          child: IgnorePointer(
            child: Text(
              message("Lv.{0}  {1}", [profile.pilotLevel + 1, tr(ship.name)]),
              key: const Key('lobby-cat-name'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFFF3F7FF),
                shadows: [
                  Shadow(color: Color(0xFF102033), offset: Offset(0, 1)),
                  Shadow(color: Color(0xFF102033), blurRadius: 4),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
    ];
  }

  /// Training/guide beside the launch: kit slot tiles (v12.9), the same
  /// framed look as the item slots instead of the old flat grey boxes.
  Widget _launchSide(
    String label,
    String visible,
    IconData icon,
    VoidCallback action,
  ) => Semantics(
    label: tr(label),
    button: true,
    excludeSemantics: true,
    onTap: audible(action),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: audible(action),
      child: SizedBox(
        width: 60,
        height: 72,
        child: UiKitFrame(
          'slot',
          corner: 16,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RasterIcon(icon, size: 30),
              const SizedBox(height: 2),
              Text(
                tr(visible),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
