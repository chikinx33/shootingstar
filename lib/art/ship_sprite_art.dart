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

  static const droneAsset = 'assets/art/ship_parts/sunshine/drone.webp';

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
  static String fxAsset(String name) => 'assets/art/fx_v11/$name.webp';

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

    /// v12.9.3 sortie intro: 0..1 attach progress per layer id. Wings and
    /// engines slam in sideways, everything else along its own offset,
    /// speeding up into place so the lock-on lands as a hit.
    double Function(String layerId)? attach,

    /// 0..1 white flash over the whole ship (the beat of an attach).
    double flash = 0,

    /// v12.9.4 depth (user 2026-10-25): -1..1 sideways roll. Layers drawn
    /// under the pilot (canopy) slide against the turn, layers over it with
    /// it, farther layers more, and the hull narrows a little, so the craft
    /// seems to turn its body instead of sliding flat.
    double bank = 0,

    /// Flame length: longer flying forward, a little shorter backing off.
    double flameScale = 1,
  }) {
    final ship = book?.ships[shipId];
    if (ship == null) return false;
    final saved = canvas.getSaveCount();
    if (flash > 0) {
      canvas.saveLayer(
        null,
        Paint()
          ..colorFilter = ColorFilter.mode(
            Colors.white.withValues(alpha: flash.clamp(0, 1)),
            BlendMode.srcATop,
          ),
      );
    }
    var order = -1;
    final ink = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Colors.white.withValues(alpha: opacity);
    final drawn = [
      for (final l in ship.resolved)
        if (l.visible &&
            !hidden.contains(l.id) &&
            !(l.attachTo != null && hidden.contains(l.attachTo)))
          l.id,
    ];
    var pilot = drawn.indexOf('canopy');
    if (pilot < 0) pilot = drawn.indexOf('base');
    if (pilot < 0) pilot = drawn.length ~/ 2;
    final span = math.max(1, math.max(pilot, drawn.length - 1 - pilot));
    final roll = bank.clamp(-1.0, 1.0);
    if (roll != 0) {
      canvas.save();
      canvas.translate(center.dx, 0);
      canvas.scale(1 - .1 * roll.abs(), 1);
      canvas.translate(-center.dx, 0);
    }
    var depth = -1;
    for (final l in ship.resolved) {
      if (!l.visible || hidden.contains(l.id)) continue;
      if (l.attachTo != null && hidden.contains(l.attachTo)) continue;
      order++;
      depth++;
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
      } else if (attach != null) {
        final t = attach(l.id).clamp(0.0, 1.0);
        if (t <= 0) continue;
        final away = 1 - Curves.easeInCubic.transform(t);
        final sideways = sidewaysLayer(l.id);
        final dir = sideways ? Offset(l.x < 0 ? -1 : 1, 0) : Offset(l.x, l.y);
        final unit = dir.distance < .02
            ? const Offset(0, -1)
            : dir / dir.distance;
        dx = unit.dx * away * 1.4 * side;
        dy = unit.dy * away * 1.4 * side;
        alpha = opacity * math.min(1, t * 4);
      }
      if (roll != 0) dx += roll * (depth - pilot) / span * .1 * side;
      // Equipped gear swaps the sprite (a mirror follows its source layer);
      // the slot keeps its authored width, height follows the new art.
      final swap = assets[l.mirrorOf ?? l.id];
      final image = images[swap ?? l.frameAsset(time)];
      if (image == null) continue;
      final w = l.width * side;
      var h = swap == null ? l.height * side : w * image.height / image.width;
      if (flameScale != 1 && l.id.startsWith('flame')) h *= flameScale;
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
    canvas.restoreToCount(saved);
    return true;
  }

  /// Wings, engines and their flames attach from the sides.
  static bool sidewaysLayer(String id) =>
      id.startsWith('wing') ||
      id.startsWith('engine') ||
      id == 'flame_l' ||
      id == 'flame_r';

  /// Canvas-unit pivots of [shipId]'s visible layers chosen by [where]
  /// (attach points for the sortie intro's impact sparks).
  static List<Offset> layerPoints(
    String shipId,
    bool Function(String id) where, {
    Set<String> hidden = const {},
  }) => [
    for (final l in book?.ships[shipId]?.resolved ?? const <ShipPartLayer>[])
      if (l.visible && !hidden.contains(l.id) && where(l.id)) Offset(l.x, l.y),
  ];
}

/// A ship drawn to fit its box, flames animating (lobby, hangar, menus).
class ShipSprite extends StatefulWidget {
  const ShipSprite({
    super.key,
    required this.hull,
    this.loadout,
    this.assets = const {},
    this.semanticLabel,
    this.bank = 0,
    this.flameScale = 1,
  });

  final int hull;
  final ModuleSnapshot? loadout;

  /// Layered roll and flame length, as in flight (ShipSpriteArt.paint).
  final double bank, flameScale;

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
        widget.bank,
        widget.flameScale,
      ),
    ),
  );
}

class _ShipSpritePainter extends CustomPainter {
  _ShipSpritePainter(
    this.shipId,
    this.hidden,
    this.assets,
    this.time,
    this.bank,
    this.flameScale,
  );
  final String shipId;
  final Set<String> hidden;
  final Map<String, String> assets;
  final double time, bank, flameScale;

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
      bank: bank,
      flameScale: flameScale,
    );
  }

  @override
  bool shouldRepaint(_ShipSpritePainter old) =>
      old.time != time ||
      old.shipId != shipId ||
      old.hidden != hidden ||
      old.bank != bank ||
      old.flameScale != flameScale;
}
