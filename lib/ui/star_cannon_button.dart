import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import 'audio_feedback.dart';

/// v12.16 (user 2026-10-27): the airframe ultimate is a small round button
/// that rides beside the craft. While it charges it stays faint (a thin ring
/// fills around the cat's own emblem) so it never distracts; once full it
/// turns vivid with a gold rim and a soft pulse. It ignores touches until it
/// is ready, so dragging over it still steers. The label stays available to
/// screen readers.
class StarCannonButton extends StatefulWidget {
  const StarCannonButton({
    super.key,
    required this.charge,
    required this.ready,
    required this.firing,
    required this.onPressed,
    this.size = 46,
    this.emblem,
  });

  /// 0..100 charge percentage.
  final double charge;
  final bool ready, firing;
  final VoidCallback? onPressed;
  final double size;

  /// The cat's own ultimate picture (missile storm / clones / shield).
  final String? emblem;

  String get label => ready
      ? '궁극기 항성포 발사'
      : firing
      ? '궁극기 항성포 발사 중'
      : '궁극기 충전 ${charge.floor()}%';

  @override
  State<StarCannonButton> createState() => _StarCannonButtonState();
}

class _StarCannonButtonState extends State<StarCannonButton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(StarCannonButton old) {
    super.didUpdateWidget(old);
    if (old.ready != widget.ready) _sync();
  }

  void _sync() {
    if (widget.ready) {
      // a few beats when it becomes ready, then it rests vivid
      _pulse.repeat(reverse: true, count: 8);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFC94D), cyan = Color(0xFF6FE3F5);
    final size = widget.size, ready = widget.ready;
    final ink = ready || widget.firing ? gold : cyan;
    final face = Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xCC1B2A3F),
            border: Border.all(color: ink, width: ready ? 3 : 1.5),
            boxShadow: ready
                ? const [BoxShadow(color: Color(0xAAFFC94D), blurRadius: 12)]
                : null,
          ),
        ),
        if (!ready)
          SizedBox.square(
            dimension: size - 6,
            child: CircularProgressIndicator(
              value: widget.firing
                  ? null
                  : (widget.charge / 100).clamp(0.0, 1.0),
              strokeWidth: 3,
              color: ink,
              backgroundColor: Colors.white.withValues(alpha: .1),
            ),
          ),
        if (widget.emblem != null)
          Image.asset(
            widget.emblem!,
            width: size * .64,
            height: size * .64,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          )
        else
          Icon(Icons.bolt, size: size * .52, color: ink),
      ],
    );
    return Semantics(
      // own node: never merge "disabled" into the field/HUD around it
      container: true,
      button: true,
      enabled: widget.onPressed != null,
      label: tr(widget.label),
      excludeSemantics: true,
      child: IgnorePointer(
        ignoring: !ready,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: ready ? 1 : (widget.firing ? .6 : .35),
          child: ScaleTransition(
            scale: Tween(
              begin: 1.0,
              end: 1.12,
            ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
            child: SizedBox.square(
              dimension: size,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: audible(widget.onPressed),
                  child: face,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
