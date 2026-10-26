import '../l10n/app_language.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/game_icons.dart';

import 'reward_popup.dart';

/// A real, currently visible resource/inventory destination, not a guessed pixel.
class RewardTarget extends StatefulWidget {
  const RewardTarget({super.key, required this.name, required this.child});
  final String name;
  final Widget child;
  @override
  State<RewardTarget> createState() => _RewardTargetState();
}

class _RewardTargetState extends State<RewardTarget> {
  static final targets = <_RewardTargetState>{};
  @override
  void initState() {
    super.initState();
    targets.add(this);
  }

  @override
  void dispose() {
    targets.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return widget.child;
  }
}

abstract final class RewardFlights {
  static OverlayEntry? _active;
  static Future<void> show(
    BuildContext context,
    List<RewardEntry> entries, {
    Offset? from,
    bool spending = false,
  }) async {
    if (!context.mounted || entries.isEmpty) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final root = overlay?.context.findRenderObject();
    if (overlay == null || root is! RenderBox || !root.hasSize) return;
    final size = root.size;
    final originBox = context.findRenderObject();
    final origin =
        from ??
        (originBox is RenderBox && originBox.hasSize
            ? originBox.localToGlobal(originBox.size.center(Offset.zero))
            : size.center(Offset.zero));
    final starts = <Offset>[], ends = <Offset>[], fallback = <bool>[];
    for (final entry in entries) {
      Offset? destination;
      for (final target in _RewardTargetState.targets) {
        if (!target.mounted ||
            target.widget.name != entry.name ||
            ModalRoute.of(target.context)?.isCurrent != true) {
          continue;
        }
        final box = target.context.findRenderObject();
        if (box is RenderBox && box.hasSize && box.attached) {
          final at = box.localToGlobal(box.size.center(Offset.zero));
          if ((Offset.zero & size).contains(at)) {
            destination = at;
          }
        }
      }
      fallback.add(destination == null);
      destination ??= Offset(
        size.width - 54,
        MediaQuery.paddingOf(context).top + 62,
      );
      final a = root.globalToLocal(origin), b = root.globalToLocal(destination);
      starts.add(spending ? b : a);
      ends.add(spending ? a : b);
    }
    // One bounded decorative layer; transactions and saved rewards are already final.
    _active?.remove();
    final reduced = MediaQuery.disableAnimationsOf(context);
    late OverlayEntry layer;
    layer = OverlayEntry(
      builder: (_) => _FlightLayer(
        entries: entries,
        starts: starts,
        ends: ends,
        fallback: fallback,
        spending: spending,
        reduced: reduced,
        onDone: () {
          if (_active == layer) {
            layer.remove();
            _active = null;
          }
        },
      ),
    );
    _active = layer;
    overlay.insert(layer);
  }
}

class _FlightLayer extends StatefulWidget {
  const _FlightLayer({
    required this.entries,
    required this.starts,
    required this.ends,
    required this.fallback,
    required this.spending,
    required this.reduced,
    required this.onDone,
  });
  final List<RewardEntry> entries;
  final List<Offset> starts, ends;
  final List<bool> fallback;
  final bool spending, reduced;
  final VoidCallback onDone;
  @override
  State<_FlightLayer> createState() => _FlightLayerState();
}

class _FlightLayerState extends State<_FlightLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController clock =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1250),
        )
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onDone();
        })
        ..forward();
  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: clock,
          builder: (context, _) {
            final t = clock.value;
            final entries = widget.entries;
            return Stack(
              key: const Key('reward-flight-layer'),
              children: [
                if (widget.fallback.any((v) => v))
                  Positioned(
                    right: 12,
                    top: MediaQuery.paddingOf(context).top + 18,
                    child: Opacity(
                      opacity: ((1 - t) * 5).clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xF0173046),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFFFD167),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const GameIconImage(GameIcons.chest, size: 34),
                            Text(
                              tr(widget.spending ? '재화 사용' : '보관함'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),

                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                for (var i = 0; i < entries.length && i < 12; i++)
                  for (
                    var copy = 0;
                    copy < (entries[i].amount > 1 ? 3 : 1);
                    copy++
                  )
                    _mote(i, copy, t),
                for (var i = 0; i < entries.length && i < 12; i++)
                  if (t > .64)
                    Positioned(
                      left: widget.ends[i].dx - 28,
                      top: widget.ends[i].dy - 28,
                      child: Opacity(
                        opacity: ((1 - t) * 2.5).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: .7 + (t - .64) * 2,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFFD167),
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                for (var i = 0; i < entries.length && i < 12; i++)
                  if (t > .64)
                    Positioned(
                      left: widget.ends[i].dx - 44,
                      top: widget.ends[i].dy - 34 - (t - .64) * 50,
                      child: Opacity(
                        opacity: ((1 - t) * 3).clamp(0.0, 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          color: const Color(0xE00B1D2D),
                          child: Text(
                            message("{0}{1}", [
                              widget.spending ? '−' : '+',
                              entries[i].amount,
                            ]),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFFDA75),
                            ),

                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _mote(int i, int copy, double t) {
    final p = ((t - (i % 4) * .035 - copy * .045) / .64).clamp(0.0, 1.0);
    final ease = Curves.easeInOutCubic.transform(p);
    final a = widget.starts[i] + Offset((i % 3 - 1) * 28.0 + copy * 10, 0);
    final b = widget.ends[i];
    final at =
        Offset.lerp(a, b, ease)! -
        Offset(
          0,
          widget.reduced ? 0 : math.sin(p * math.pi) * (65 + copy * 12),
        );
    return Positioned(
      left: at.dx - 18,
      top: at.dy - 18,
      child: Opacity(
        opacity: p >= 1 ? 0 : (p * 8).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: widget.reduced ? 0 : math.sin(p * math.pi) * .3,
          child: RewardIcon(entry: widget.entries[i], size: 36),
        ),
      ),
    );
  }
}

class RewardReveal extends StatelessWidget {
  const RewardReveal({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: .84 + .16 * t, child: child),
      ),
      child: child,
    );
  }
}
