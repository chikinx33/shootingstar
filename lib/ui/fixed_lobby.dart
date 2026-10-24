import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'lobby_cat_hero.dart';
import 'guardian_quest_screen.dart';

import 'supporter_cosmetic.dart';

import '../art/lobby_art.dart';
import '../art/toon_assets.dart';
import '../data/content.dart';
import '../data/profile.dart';
import 'components.dart';
import 'arcade_home_widgets.dart';
import 'ship_hangar.dart';
import 'armament_hangar.dart';

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
          return Column(
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
                                crossAxisAlignment: CrossAxisAlignment.center,
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
                                          ? worlds[profile.selectedStage ~/ 10]
                                                .name
                                          : stages[profile.selectedStage].name,
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
                    final tall = field.maxHeight > 280;
                    final shortcutGap = ((field.maxHeight - 144) / 2).clamp(
                      0.0,
                      6.0,
                    );
                    final actionHeight =
                        ((field.maxHeight - shortcutGap * 2) / 3).clamp(
                          48.0,
                          80.0,
                        );
                    final artHeight = math.max(
                      0.0,
                      field.maxHeight - (tall ? 82 : 4),
                    );
                    final extent = math.max(
                      0.0,
                      math.min(
                        248.0,
                        math.min(artHeight, field.maxWidth - 136),
                      ),
                    );
                    final ship = ships[profile.selectedShip];
                    void openShip() => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ShipHangar(profile: profile),
                      ),
                    );
                    Widget shortcut(
                      IconData icon,
                      String label,
                      String visible,
                      VoidCallback action,
                    ) => BridgeAction(
                      icon: icon,
                      label: label,
                      displayLabel: visible,
                      height: actionHeight,
                      compact: compactActions,
                      width: 64,
                      onTap: audible(action)!,
                    );
                    final shortcuts = [
                      shortcut(
                        Icons.assignment_turned_in,
                        '임무·출석',
                        '임무',
                        () => onActivity(1),
                      ),
                      shortcut(Icons.card_giftcard, '시즌 보상', '시즌', onSeason),
                      shortcut(Icons.explore, '순찰', '순찰', () => onActivity(3)),
                      shortcut(Icons.groups, '길드', '길드', onGuild),
                      shortcut(Icons.build, '격납고', '격납고', onHangar),
                      shortcut(
                        Icons.emoji_events,
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
                          Positioned(
                            top: 0,
                            left: 68,
                            right: 68,
                            bottom: 4,
                            child: Align(
                              alignment: tall
                                  ? const Alignment(0, .55)
                                  : Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    fit: FlexFit.loose,
                                    child: SupporterCosmetic(
                                      active:
                                          profile.commerce?.cosmeticActive ==
                                          true,
                                      child: LobbyCatHero(
                                        profile: profile,
                                        width: extent,
                                        height: artHeight,
                                        onSelectShip: openShip,
                                      ),
                                    ),
                                  ),
                                  if (tall) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      tr(ship.name),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFF3F7FF),
                                        shadows: [
                                          Shadow(
                                            color: Color(0xFF102033),
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),

                                      textAlign: TextAlign.center,
                                    ),
                                    OutlinedButton(
                                      style: GameUi.compactButton,
                                      onPressed: audible(
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) => ArmamentHangar(
                                              profile: profile,
                                            ),
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        message("{0} · Lv.{1}", [
                                          profile.moduleLoadout.signatureName,
                                          profile.moduleLoadout.airframeLevel,
                                        ]),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
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
                                    isLabelVisible: profile.questAttention > 0,
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
                  _launchSide('45초 훈련', '훈련', Icons.timer_outlined, onTraining),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Center(
                      child: GameActionButton(
                        key: const Key('launch'),
                        displayLabel: profile.hasSuspendedBattle
                            ? '이어하기'
                            : (tight ? '출격' : '출격 시작'),
                        primary: true,
                        icon: Icons.rocket_launch,
                        leading: const LobbyIcon(Icons.rocket_launch, size: 36),
                        panelColor: const Color(0xFFFFCC47),
                        onPressed: audible(onLaunch),
                        label: profile.hasSuspendedBattle
                            ? '저장된 전투 이어하기'
                            : '${stages[profile.selectedStage].name} · 출격',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _launchSide('비행 가이드', '가이드', Icons.help_outline, onGuide),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: RasterGauge(
                  value: profile.pilotXp / profile.pilotXpNeeded,
                  minHeight: 6,
                  color: const Color(0xFF64D4BD),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

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
    child: SizedBox(
      width: 52,
      height: 72,
      child: TextButton(
        onPressed: audible(action),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF253C53),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
            side: const BorderSide(color: Color(0xFF6B7C88)),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RasterIcon(icon, size: 28),
            const SizedBox(height: 3),
            Text(
              tr(visible),
              style: const TextStyle(
                fontSize: 13,
                height: 1.1,
                fontWeight: FontWeight.w900,
              ),

              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
