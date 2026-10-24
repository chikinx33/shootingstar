import 'package:flutter/material.dart';

import '../art/raster_assets.dart';
import '../l10n/app_language.dart';
import 'audio_feedback.dart';

/// v12.4 (user 2026-10-24): the common ultimate is a round, text-free button
/// on the side of the field so it never covers the flight path. Charge reads
/// as a ring; the label stays available to screen readers.
class StarCannonButton extends StatelessWidget {
  const StarCannonButton({
    super.key,
    required this.charge,
    required this.ready,
    required this.firing,
    required this.onPressed,
    this.size = 64,
  });

  /// 0..100 charge percentage.
  final double charge;
  final bool ready, firing;
  final VoidCallback? onPressed;
  final double size;

  String get label => ready
      ? '궁극기 항성포 발사'
      : firing
      ? '궁극기 항성포 발사 중'
      : '궁극기 충전 ${charge.floor()}%';

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFC94D), cyan = Color(0xFF6FE3F5);
    final ink = ready || firing ? gold : cyan;
    return Semantics(
      // own node: never merge "disabled" into the field/HUD around it
      container: true,
      button: true,
      enabled: onPressed != null,
      label: tr(label),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: audible(onPressed),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: RasterDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xCC1B2A3F),
                    border: Border.all(
                      color: ink.withValues(alpha: ready ? 1 : .55),
                      width: ready ? 3 : 2,
                    ),
                  ),
                ),
                if (ready)
                  // ready halo
                  Container(
                    margin: const EdgeInsets.all(5),
                    decoration: RasterDecoration(
                      shape: BoxShape.circle,
                      color: gold.withValues(alpha: .22),
                    ),
                  ),
                if (!ready)
                  SizedBox.square(
                    dimension: size - 10,
                    child: CircularProgressIndicator(
                      value: firing ? null : (charge / 100).clamp(0.0, 1.0),
                      strokeWidth: 4,
                      color: ink,
                      backgroundColor: Colors.white.withValues(alpha: .12),
                    ),
                  ),
                Icon(
                  Icons.bolt,
                  size: size * .52,
                  color: ready ? gold : Colors.white.withValues(alpha: .7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
