import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'menu_art.dart';
import 'flight_scene_art.dart';

/// Original v16 PNGs override shared addresses, including live combat craft.
abstract final class RefitArt {
  static const root = 'assets/art/refit_v16/';
  static Future<void>? _loading;
  static Future<void> load() => _loading ??= _load();
  static Future<void> _load() async {
    final map =
        jsonDecode(await rootBundle.loadString('${root}manifest.json')) as Map;
    await Future.wait(
      map.entries.map((entry) async {
        final meta = entry.value as Map;
        final bytes = await rootBundle.load('$root${entry.key}.png');
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
          targetWidth: meta['background'] == true ? 900 : 512,
        );
        final name = 'lobby/${entry.key}';
        MenuArt.images[name] = (await codec.getNextFrame()).image;
        codec.dispose();
        final b = (meta['bounds'] as List).cast<num>();
        MenuArt.bounds[name] = Rect.fromLTRB(
          b[0].toDouble(),
          b[1].toDouble(),
          b[2].toDouble(),
          b[3].toDouble(),
        );
      }),
    );
    for (final alias in MenuArt.aliases.entries) {
      if (MenuArt.images.containsKey(alias.value)) {
        MenuArt.images[alias.key] = MenuArt.images[alias.value]!;
        MenuArt.bounds[alias.key] = MenuArt.bounds[alias.value]!;
      }
    }
  }
}

/// A paint-only lobby clock; foreground controls are retained between frames.
class RefitBackdrop extends StatefulWidget {
  const RefitBackdrop({
    super.key,
    required this.child,
    this.launch = false,
    this.motionEnabled = true,
  });
  final Widget child;
  final bool launch, motionEnabled;
  @override
  State<RefitBackdrop> createState() => _RefitBackdropState();
}

class _RefitBackdropState extends State<RefitBackdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _clock = ValueNotifier<double>(0);
  late final Ticker _ticker;
  Duration? _lastTick;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _ticker = createTicker(_tick);
    WidgetsBinding.instance.addObserver(this);
  }

  void _tick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null) return;
    // 0.35 scene seconds/second: far 1.4, middle 4.2, near 8.4 px/s.
    // A resumed or heavily delayed frame never catches up with a large jump.
    final dt = ((elapsed - previous).inMicroseconds / 1000000).clamp(0.0, .05);
    _clock.value += dt * .35;
  }

  void _sync() {
    // The v11 living room is a still picture: no clock needed under it.
    final enabled =
        widget.launch &&
        FlightSceneArt.lobbyHome == null &&
        widget.motionEnabled &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        (ModalRoute.isCurrentOf(context) ?? true);
    if (enabled && !_ticker.isActive) {
      _lastTick = null;
      _ticker.start();
    } else if (!enabled && _ticker.isActive) {
      _ticker.stop();
      _lastTick = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RefitBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              key: const Key('lobby-drifting-background'),
              painter: RefitBackdropPainter(widget.launch, clock: _clock),
            ),
          ),
        ),
      ),
      widget.child,
    ],
  );
}

class RefitBackdropPainter extends CustomPainter {
  const RefitBackdropPainter(this.launch, {this.clock}) : super(repaint: clock);
  final bool launch;
  final ValueListenable<double>? clock;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF142236));
    final home = FlightSceneArt.lobbyHome;
    if (launch && home != null) {
      // v11: the main lobby is the cats' living room.
      FlightSceneArt.paintCover(canvas, size, home);
      return;
    }
    FlightSceneArt.paint(canvas, size, lobby: true, time: clock?.value ?? 0);
    if (!launch) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xF01E334C), Color(0xF50E1D30)],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(RefitBackdropPainter old) =>
      old.launch != launch || old.clock != clock;
}
