import '../l10n/app_language.dart';

import 'package:flutter/material.dart';

import 'components.dart';

/// A cosmetic frame over the game's original ship art. No gameplay modifier.
class SupporterCosmetic extends StatelessWidget {
  const SupporterCosmetic({super.key, required this.child, this.active = true});
  final Widget child;
  final bool active;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return !active
        ? child
        : Semantics(
            label: tr('잔광 후원 프레임'),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFFD261), width: 3),
                borderRadius: BorderRadius.circular(18),
                gradient: const RadialGradient(
                  colors: [Color(0x223EDAF0), Color(0x335A4270)],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  child,
                  const Positioned(
                    right: 4,
                    top: 4,
                    child: RasterIcon(
                      Icons.star,
                      color: Color(0xFFFFD261),
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}
