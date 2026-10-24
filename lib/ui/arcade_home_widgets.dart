import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/toon_assets.dart';
import '../art/lobby_art.dart';
import '../main.dart';
import 'game_ui.dart';
import 'reward_flight.dart';

/// Original Flutter art informed by the supplied reference's hierarchy:
/// strong silhouettes, outlined surfaces and a larger central battle tab.
class FlightNavigation extends StatelessWidget {
  const FlightNavigation({
    super.key,
    required this.selected,
    required this.onSelect,
  });
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Container(
      color: const Color(0xFF13243A),
      foregroundDecoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0xFF151A23), width: 3),
        ),
      ),
      child: SizedBox(
        height:
            88 +
            24 * (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0, 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in const [
              (5, '보급', Icons.storefront, Color(0xFF78DDA8)),
              (2, '성장', Icons.build, Color(0xFFA3C7FF)),
              (0, '출격', Icons.rocket_launch, Color(0xFFFFD447)),
              (3, '도전', Icons.emoji_events, Color(0xFFFFA766)),
              (4, '연구', Icons.account_tree, Color(0xFFD1A7FF)),
            ])
              Expanded(
                // The reference prefab expands the battle slot to 344 vs 184.
                flex: entry.$1 == 0 ? 12 : 10,
                child: Semantics(
                  selected:
                      selected == entry.$1 || (selected == 1 && entry.$1 == 2),
                  button: true,
                  child: InkWell(
                    onTap: audible(() => onSelect(entry.$1)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin: const EdgeInsets.fromLTRB(1, 0, 1, 0),
                      decoration: BoxDecoration(
                        color:
                            selected == entry.$1 ||
                                (selected == 1 && entry.$1 == 2)
                            ? const Color(0xFF2A465F)
                            : const Color(0xFF192C42),
                        borderRadius: BorderRadius.zero,
                        border: selected == entry.$1
                            ? const Border(
                                top: BorderSide(
                                  color: Color(0xFFFFD261),
                                  width: 3,
                                ),
                              )
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LobbyIcon(
                            entry.$3,
                            size: entry.$1 == 0 ? 52 : GameUi.navigationIcon,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppLanguage.instance.english && entry.$1 == 4
                                ? 'Lab'
                                : AppLanguage.instance.english && entry.$1 == 3
                                ? 'Trials'
                                : tr(entry.$2),
                            style: TextStyle(
                              fontSize: GameUi.navigationLabel,
                              fontWeight: FontWeight.w900,
                              color:
                                  selected == entry.$1 ||
                                      (selected == 1 && entry.$1 == 2)
                                  ? const Color(0xFFFFD261)
                                  : const Color(0xFFB7CDDC),
                              height: 1.2,
                            ),

                            textAlign: TextAlign.center,
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

class ResourceCounter extends StatelessWidget {
  const ResourceCounter({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return RewardTarget(
      name: label,
      child: Semantics(
        label: '${tr(label)} $value',
        button: true,
        excludeSemantics: true,
        child: InkWell(
          onTap: audible(onTap),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF213B54), Color(0xFF0D1D30)],
              ),
              border: Border.all(color: const Color(0xFF49617A), width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LobbyIcon(icon, size: 26),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    tr(_shortValue(value)),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BridgeAction extends StatelessWidget {
  const BridgeAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = cyan,
    this.displayLabel,
    this.height = 84,
    this.width = 76,
    this.compact = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final String? displayLabel;
  final double height, width;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Semantics(
      label: tr(label),
      button: true,
      excludeSemantics: true,
      onTap: audible(onTap),
      child: SizedBox(
        width: width,
        height: height,
        child: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            foregroundColor: Colors.white,
            backgroundColor: Colors.transparent,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          onPressed: audible(onTap),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Fill the existing shortcut area without squeezing the label.
              Flexible(child: LobbyIcon(icon, size: 56)),
              const SizedBox(height: 2),
              Text(
                tr(displayLabel ?? label),
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: Color(0xFF111318),
                      offset: Offset(1, 1),
                      blurRadius: 2,
                    ),
                    Shadow(
                      color: Color(0xFF111318),
                      offset: Offset(-1, -1),
                      blurRadius: 2,
                    ),
                  ],
                ),

                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Original landing field illustration; no extracted reference imagery.
class LandingFieldPainter extends CustomPainter {
  const LandingFieldPainter(this.world);
  final int world;
  static const palettes = [
    Color(0xFF719B81),
    Color(0xFF729DAE),
    Color(0xFFAC9676),
    Color(0xFF7E8CA7),
    Color(0xFF8A829F),
    Color(0xFF6C9A98),
    Color(0xFF8F8F94),
    Color(0xFFA0807F),
    Color(0xFF6D849B),
    Color(0xFF737F9E),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    if (ToonAssets.cover(canvas, 'worlds', 11, Offset.zero & size)) return;
    final bg = palettes[world % palettes.length];
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    // Blocks, access roads and roof highlights remain legible at 320px.
    final road = Paint()..color = const Color(0xFF526472);
    final edge = Paint()
      ..color = const Color(0xFF243447)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final roadX = size.width * .5;
    canvas.drawRect(Rect.fromLTWH(roadX - 48, 0, 96, size.height), road);
    canvas.drawRect(Rect.fromLTWH(0, size.height * .45, size.width, 64), road);
    final stripe = Paint()
      ..color = const Color(0x99E2DCAE)
      ..strokeWidth = 3;
    for (double y = 12; y < size.height; y += 28) {
      canvas.drawLine(Offset(roadX, y), Offset(roadX, y + 12), stripe);
    }
    for (int i = 0; i < 12; i++) {
      final left = i.isEven;
      final row = i ~/ 2;
      final x = left ? 12.0 : size.width - 70;
      final y = row * 82.0 - 16;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, 56, 48),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        r.shift(const Offset(4, 5)),
        Paint()..color = const Color(0x44202F3C),
      );
      canvas.drawRRect(
        r,
        Paint()..color = Color.lerp(bg, const Color(0xFFCCE0CF), .28)!,
      );
      canvas.drawRRect(r, edge);
      canvas.drawLine(
        Offset(x + 7, y + 7),
        Offset(x + 48, y + 7),
        Paint()
          ..color = const Color(0x66FFFFFF)
          ..strokeWidth = 3,
      );
      for (int w = 0; w < 3; w++) {
        canvas.drawRect(
          Rect.fromLTWH(x + 9 + w * 14, y + 23, 8, 9),
          Paint()..color = const Color(0xFF3E5966),
        );
      }
    }
    final center = Offset(size.width * .5, size.height * .51);
    final radius = math.min(size.width * .29, size.height * .30);
    canvas.drawCircle(
      center + const Offset(0, 5),
      radius,
      Paint()..color = const Color(0x55213240),
    );
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF70818C));
    canvas.drawCircle(center, radius, edge..strokeWidth = 3);
    canvas.drawCircle(
      center,
      radius - 9,
      Paint()
        ..color = const Color(0xFFD6CB94)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final pad = Paint()
      ..color = const Color(0xFFD6CB94)
      ..strokeWidth = 5;
    canvas.drawLine(
      center + Offset(-radius * .32, -radius * .4),
      center + Offset(-radius * .32, radius * .4),
      pad,
    );
    canvas.drawLine(
      center + Offset(radius * .32, -radius * .4),
      center + Offset(radius * .32, radius * .4),
      pad,
    );
    canvas.drawLine(
      center + Offset(-radius * .32, 0),
      center + Offset(radius * .32, 0),
      pad,
    );
  }

  @override
  bool shouldRepaint(LandingFieldPainter oldDelegate) =>
      oldDelegate.world != world;
}

// Full values remain available to screen readers through ResourceCounter.
String _shortValue(int value) => value >= 1000000
    ? '${(value / 1000000).round()}M'
    : value >= 1000
    ? '${(value / 1000).round()}K'
    : '$value';
