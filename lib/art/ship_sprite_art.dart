import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../data/cat_gear.dart';
import '../data/ship_layout_store.dart';
import '../data/ship_part_layout.dart';
import '../data/ship_modules.dart';

/// Draws a guardian cat's airframe from its authored part layout
/// (assets/data/ship_layouts.json, edited in the ship assembly editor).
///
/// Every part is a separate PNG; equipment and weapons are layered on the
/// cat's own base airframe exactly as the editor shows them, flames animate.
/// One ship-canvas unit in battle, logical pixels. The authored Sunshine is
/// about 1.15 units wide, so the craft reads at roughly 90px on a phone.
const shipCombatSide = 78.0;

abstract final class ShipSpriteArt {
  /// Idle loops (flames, the lobby cat's breathing) only run in the real
  /// app: widget tests settle frames and must not wait on endless motion,
  /// and players who switch on reduced motion get a still ship.
  static bool liveMotion(BuildContext context) =>
      !MediaQuery.of(context).disableAnimations &&
      !WidgetsBinding.instance.runtimeType.toString().contains('Test');

  static ShipLayoutBook? book;
  static final images = <String, ui.Image>{};

  /// Equipped gear sprites for the battle in progress (layer id → asset).
  static Map<String, String> battleAssets = const {};
  static Future<void>? _loading;
  static bool get ready => book != null;

  /// Hull index (selected cat) → authored ship id: 0 Cheese (balanced),
  /// 1 Gureum (fast), 2 Kami (heavy). Cats without their own
  /// layout yet fly Sunshine's frame so the game always has a full ship.
  static const shipIds = ['sunshine', 'cloud', 'nightfall'];
  static String shipFor(int hull) {
    final id = shipIds[hull.clamp(0, shipIds.length - 1)];
    return book?.ships[id] != null ? id : 'sunshine';
  }

  static Future<void> load({ShipLayoutStore store = const ShipLayoutStore()}) =>
      _loading ??= _load(store);

  static Future<void> _load(ShipLayoutStore store) async {
    try {
      final loaded = (await store.load()).book;
      final assets = <String>{
        for (final ship in loaded.ships.values)
          for (final l in ship.layers) ...[l.asset, ...l.frames],
        for (final set in catGearSets)
          for (final slot in CatGearSlot.values) set.asset(slot),
        droneAsset,
        mortarMountAsset,
        for (final n in fxNames) fxAsset(n),
      };
      await Future.wait([
        for (final asset in assets)
          if (!images.containsKey(asset)) _decode(asset),
      ]);
      book = loaded;
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  /// Picks up an editor save without restarting the game.
  static Future<void> reload(ShipLayoutBook next) async {
    await Future.wait([
      for (final ship in next.ships.values)
        for (final l in ship.layers)
          for (final asset in [l.asset, ...l.frames])
            if (!images.containsKey(asset)) _decode(asset),
    ]);
    book = next;
  }

  static Future<void> _decode(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    images[asset] = (await codec.getNextFrame()).image;
    codec.dispose();
  }

  /// Battle offset (logical px from the ship centre) of a layer's pivot,
  /// or with [muzzle] of its front edge, for the cat flying [hull]. Null
  /// until the layout is loaded, so the engine keeps its own geometry
  /// (tests, first frames).
  static Offset? mountPoint(int hull, String layerId, {bool muzzle = false}) {
    final ship = book?.ships[shipFor(hull)];
    if (ship == null) return null;
    for (final l in ship.resolved) {
      if (l.id != layerId || !l.visible) continue;
      final at = muzzle ? l.canvasPoint(.5, 0) : Offset(l.x, l.y);
      return at * shipCombatSide;
    }
    return null;
  }

  static const droneAsset = 'assets/art/ship_parts/sunshine/drone.png';

  static const fxNames = [
    'enemy_orb',
    'enemy_big',
    'player_bolt',
    'player_missile',
    'explosion',
    'hit_spark',
    'churu_pickup',
    'level_burst',
  ];
  static String fxAsset(String name) => 'assets/art/fx_v11/$name.png';

  /// Draws an fx_v11 sprite [size] px across at [at], turned by [rotation].
  static bool paintFx(
    Canvas canvas,
    String name,
    Offset at,
    double size,
    double rotation, {
    double opacity = 1,
  }) {
    final image = images[fxAsset(name)];
    if (image == null) return false;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (rotation != 0) canvas.rotate(rotation);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: size, height: size),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Colors.white.withValues(alpha: opacity.clamp(0, 1)),
    );
    canvas.restore();
    return true;
  }

  /// Draws a combat drone [size] px wide at the canvas origin, facing up.
  static bool paintDrone(Canvas canvas, double size) {
    final image = images[droneAsset];
    if (image == null) return false;
    final h = size * image.height / image.width;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: size, height: h),
      Paint()..filterQuality = FilterQuality.medium,
    );
    return true;
  }

  /// Weapon layers shown for a module loadout: W1 = wing guns, W3 = rear
  /// self-propelled gun, W2/W4 = missiles (the remaining weapon bays).
  static Set<String> hiddenFor(ModuleSnapshot? loadout) {
    if (loadout == null) return const {};
    final parts = loadout.parts;
    return {
      if (parts['W1'] == null) ...{'gun_l', 'gun_r'},
      if (parts['W2'] == null && parts['W4'] == null) ...{
        'missile_l',
        'missile_r',
      },
      if (parts['W3'] == null) 'rear_gun',
    };
  }

  /// Visible extent of a ship in canvas units (it may exceed the -0.5..0.5
  /// frame). Used to fit the ship into a box without clipping.
  static Rect bounds(String shipId) {
    final ship = book?.ships[shipId];
    if (ship == null) return const Rect.fromLTRB(-.5, -.5, .5, .5);
    Rect? out;
    for (final l in ship.resolved) {
      if (!l.visible) continue;
      final corners = [
        l.canvasPoint(0, 0),
        l.canvasPoint(1, 0),
        l.canvasPoint(0, 1),
        l.canvasPoint(1, 1),
      ];
      for (final c in corners) {
        final r = Rect.fromCenter(center: c, width: 0, height: 0);
        out = out == null ? r : out.expandToInclude(r);
      }
    }
    return out ?? const Rect.fromLTRB(-.5, -.5, .5, .5);
  }

  /// Paints [shipId] with its canvas centre at [center]; one canvas unit is
  /// [side] pixels. [time] drives the flame frames.
  static bool paint(
    Canvas canvas,
    String shipId,
    Offset center,
    double side, {
    double time = 0,
    Set<String> hidden = const {},
    Map<String, String> assets = const {},
    double opacity = 1,

    /// Assembly animation: 0..1 progress for the n-th drawn layer (null =
    /// fully assembled). Parts fly in from outside along their own offset.
    double Function(int order)? assembly,
  }) {
    final ship = book?.ships[shipId];
    if (ship == null) return false;
    var order = -1;
    final ink = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Colors.white.withValues(alpha: opacity);
    for (final l in ship.resolved) {
      if (!l.visible || hidden.contains(l.id)) continue;
      if (l.attachTo != null && hidden.contains(l.attachTo)) continue;
      order++;
      var dx = 0.0, dy = 0.0, alpha = opacity;
      if (assembly != null) {
        final t = assembly(order).clamp(0.0, 1.0);
        if (t <= 0) continue;
        final away = 1 - Curves.easeOutBack.transform(t);
        // fly in from beyond the ship, outward along the part's own offset
        final dir = Offset(l.x, l.y);
        final unit = dir.distance < .02
            ? const Offset(0, -1)
            : dir / dir.distance;
        dx = unit.dx * away * 1.6 * side;
        dy = unit.dy * away * 1.6 * side;
        alpha = opacity * math.min(1, t * 3);
      }
      // Equipped gear swaps the sprite (a mirror follows its source layer);
      // the slot keeps its authored width, height follows the new art.
      final swap = assets[l.mirrorOf ?? l.id];
      final image = images[swap ?? l.frameAsset(time)];
      if (image == null) continue;
      final w = l.width * side;
      final h = swap == null ? l.height * side : w * image.height / image.width;
      canvas.save();
      canvas.translate(
        center.dx + l.x * side + dx,
        center.dy + l.y * side + dy,
      );
      if (l.rotation != 0) canvas.rotate(l.rotation * math.pi / 180);
      final dst = Rect.fromLTWH(-l.pivotX * w, -l.pivotY * h, w, h);
      if (l.flipX) {
        canvas.translate(dst.center.dx, 0);
        canvas.scale(-1, 1);
        canvas.translate(-dst.center.dx, 0);
      }
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        dst,
        alpha == opacity
            ? ink
            : (Paint()
                ..filterQuality = FilterQuality.medium
                ..color = Colors.white.withValues(alpha: alpha)),
      );
      canvas.restore();
    }
    return true;
  }
}

/// A ship drawn to fit its box, flames animating (lobby, hangar, menus).
class ShipSprite extends StatefulWidget {
  const ShipSprite({
    super.key,
    required this.hull,
    this.loadout,
    this.assets = const {},
    this.semanticLabel,
  });

  final int hull;
  final ModuleSnapshot? loadout;

  /// Equipped gear sprites (CatGearState.layerAssets).
  final Map<String, String> assets;
  final String? semanticLabel;

  @override
  State<ShipSprite> createState() => _ShipSpriteState();
}

class _ShipSpriteState extends State<ShipSprite>
    with SingleTickerProviderStateMixin {
  double _time = 0;
  late final Ticker _ticker = createTicker(
    (elapsed) => setState(() => _time = elapsed.inMicroseconds / 1e6),
  );

  bool _started = false;

  void _start() {
    if (_started || !mounted) return;
    _started = true;
    if (ShipSpriteArt.liveMotion(context)) {
      _ticker.start();
    } else {
      setState(() {}); // one still frame once the art is in
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ShipSpriteArt.ready) {
      _start();
    } else {
      unawaited(ShipSpriteArt.load().then((_) => _start(), onError: (_) {}));
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticLabel,
    image: widget.semanticLabel != null,
    child: CustomPaint(
      size: Size.infinite,
      painter: _ShipSpritePainter(
        ShipSpriteArt.shipFor(widget.hull),
        ShipSpriteArt.hiddenFor(widget.loadout),
        widget.assets,
        _time,
      ),
    ),
  );
}

class _ShipSpritePainter extends CustomPainter {
  _ShipSpritePainter(this.shipId, this.hidden, this.assets, this.time);
  final String shipId;
  final Set<String> hidden;
  final Map<String, String> assets;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    if (!ShipSpriteArt.ready) return;
    final b = ShipSpriteArt.bounds(shipId);
    final side = math.min(size.width / b.width, size.height / b.height) * .96;
    final center = size.center(Offset.zero) - b.center * side;
    ShipSpriteArt.paint(
      canvas,
      shipId,
      center,
      side,
      time: time,
      hidden: hidden,
      assets: assets,
    );
  }

  @override
  bool shouldRepaint(_ShipSpritePainter old) =>
      old.time != time || old.shipId != shipId || old.hidden != hidden;
}
