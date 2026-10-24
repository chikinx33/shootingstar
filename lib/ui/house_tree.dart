import 'package:flutter/material.dart';

import '../data/houses.dart';
import '../l10n/app_language.dart';
import 'audio_feedback.dart';

/// v12 neighbourhood map: the ten houses of one neighbourhood as a tech
/// tree. The road runs from the first house at the top (the one you can
/// play now is in view first) down to the cats' own home; clearing a house
/// opens the next one.
class HouseTree extends StatelessWidget {
  const HouseTree({
    super.key,
    required this.firstStage,
    required this.selected,
    required this.cleared,
    required this.available,
    required this.onPick,
  });
  final int firstStage;
  final int selected;
  final bool Function(int stage) cleared, available;
  final void Function(int stage) onPick;

  // zig-zag lanes for houses 0..9, top to bottom
  static const lanes = [0.0, .62, 0.0, -.62, 0.0, .62, 0.0, -.62, 0.0, 0.0];

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final rows = <Widget>[];
    for (var n = 0; n < 10; n++) {
      rows.add(
        Align(
          alignment: Alignment(lanes[n], 0),
          child: HouseNode(
            key: ValueKey('house-node-${firstStage + n}'),
            stage: firstStage + n,
            selected: selected == firstStage + n,
            cleared: cleared(firstStage + n),
            available: available(firstStage + n),
            onPressed: () => onPick(firstStage + n),
          ),
        ),
      );
      if (n < 9) {
        rows.add(
          SizedBox(
            height: 26,
            child: CustomPaint(
              size: Size.infinite,
              painter: _RoadPainter(
                from: lanes[n],
                to: lanes[n + 1],
                open: cleared(firstStage + n),
              ),
            ),
          ),
        );
      }
    }
    return Column(children: rows);
  }
}

class _RoadPainter extends CustomPainter {
  _RoadPainter({required this.from, required this.to, required this.open});
  final double from, to;
  final bool open;
  @override
  void paint(Canvas canvas, Size size) {
    double x(double a) => size.width / 2 + a * (size.width / 2 - 70);
    final start = Offset(x(from), 0), end = Offset(x(to), size.height);
    final paint = Paint()
      ..color = open ? const Color(0xFFFFC93C) : const Color(0x66FFFFFF)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final d = end - start;
    const dash = 9.0;
    final steps = (d.distance / dash).floor();
    for (var i = 0; i < steps; i += 2) {
      canvas.drawLine(
        start + d * (i / steps),
        start + d * ((i + 1) / steps),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) =>
      old.from != from || old.to != to || old.open != open;
}

class HouseNode extends StatelessWidget {
  const HouseNode({
    super.key,
    required this.stage,
    required this.selected,
    required this.cleared,
    required this.available,
    required this.onPressed,
  });
  final int stage;
  final bool selected, cleared, available;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final house = houseOf(stage);
    final status = selected
        ? '선택 중'
        : cleared
        ? '지켜 냄'
        : available
        ? '출격 가능'
        : '잠김';
    final border = selected
        ? const Color(0xFFFFC93C)
        : cleared
        ? const Color(0xFF7DE08A)
        : const Color(0xFF2B1A0E);
    return Semantics(
      button: true,
      selected: selected,
      enabled: available,
      label: '${tr(house.place)} · ${tr(status)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: audible(available ? onPressed : null),
        child: Opacity(
          opacity: available ? 1 : .55,
          child: SizedBox(
            width: 136,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 128,
                      height: 88,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: border, width: 4),
                        boxShadow: [
                          if (selected)
                            const BoxShadow(
                              color: Color(0x99FFC93C),
                              blurRadius: 14,
                            ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ColorFiltered(
                        colorFilter: available
                            ? const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.dst,
                              )
                            : const ColorFilter.matrix([
                                .33, .33, .33, 0, 0, //
                                .33, .33, .33, 0, 0,
                                .33, .33, .33, 0, 0,
                                0, 0, 0, 1, 0,
                              ]),
                        child: Image.asset(
                          houseMap(stage),
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -.5),
                          cacheWidth: 256,
                        ),
                      ),
                    ),
                    Positioned(
                      left: -8,
                      bottom: -10,
                      child: Image.asset(
                        houseOwner(stage),
                        width: 50,
                        height: 50,
                        cacheWidth: 128,
                      ),
                    ),
                    if (!available || cleared)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: cleared
                              ? const Color(0xFF3FAF5A)
                              : const Color(0xFF3A2A1E),
                          child: Icon(
                            cleared ? Icons.check : Icons.lock,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  tr(house.place),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  tr(status),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: selected ? const Color(0xFFFFC93C) : null,
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
