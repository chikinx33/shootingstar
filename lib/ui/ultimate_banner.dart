import 'package:flutter/material.dart';

import '../l10n/app_language.dart';

/// v12 weapon ultimate: a gold name banner over the slowed-down battle
/// while the weapon transforms. [t] runs 1 → 0.
class UltimateBanner extends StatelessWidget {
  const UltimateBanner({super.key, required this.name, required this.t});
  final String name;
  final double t;

  @override
  Widget build(BuildContext context) {
    final show = (t > .85 ? (1 - t) / .15 : t / .25).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -.35),
        child: Opacity(
          opacity: show,
          child: Transform.scale(
            scale: .8 + .2 * show,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE07A), Color(0xFFFFA92E)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF3A1A00), width: 3),
                boxShadow: const [
                  BoxShadow(color: Color(0x99FFC85C), blurRadius: 24),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('궁극 변신!'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF3A1A00),
                    ),
                  ),
                  Text(
                    tr(name),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF3A1A00),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
