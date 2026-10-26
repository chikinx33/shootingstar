import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/houses.dart';

enum FlightDepth { far, middle, near }

/// Independent world-space planes. Factors are camera displacement ratios;
/// drift is logical pixels per scene second, never tied to display dimensions.
class FlightSceneLayer {
  const FlightSceneLayer(this.depth, this.asset, this.cameraFactor, this.drift);
  final FlightDepth depth;
  final String asset;
  final double cameraFactor, drift;

  Offset displacement(double time, Offset camera) => Offset(
    -camera.dx * cameraFactor,
    -camera.dy * cameraFactor + time * drift,
  );
}

abstract final class FlightSceneArt {
  static const layers = [
    FlightSceneLayer(FlightDepth.far, 'far', .10, 4),
    FlightSceneLayer(FlightDepth.middle, 'middle', .28, 12),
    FlightSceneLayer(FlightDepth.near, 'near', .55, 24),
  ];

  /// All three planes tile in both axes. A two-tile mirror period preserves
  /// parity at wrap, even at negative world coordinates and over long runs.
  static void paintLayer(
    Canvas c,
    Size size,
    FlightSceneLayer layer,
    ui.Image art, {
    double time = 0,
    Offset camera = Offset.zero,
    double opacity = 1,
  }) {
    if (size.isEmpty) return;
    final width = math.max(size.width, size.height * art.width / art.height);
    final height = width * art.height / art.width;
    final travel = layer.displacement(time, camera);
    final x = travel.dx % (width * 2), y = travel.dy % (height * 2);
    final firstCol = (-x / width).floor();
    final lastCol = ((size.width - x) / width).ceil();
    final firstRow = (-y / height).floor();
    final lastRow = ((size.height - y) / height).ceil();
    final source = Rect.fromLTWH(
      0,
      0,
      art.width.toDouble(),
      art.height.toDouble(),
    );
    final target = Rect.fromLTWH(0, 0, width, height);
    final ink = Paint()
      ..filterQuality = FilterQuality.low
      ..isAntiAlias = false
      ..color = Colors.white.withValues(alpha: opacity);
    c.save();
    c.clipRect(Offset.zero & size, doAntiAlias: false);
    for (var row = firstRow; row <= lastRow; row++) {
      for (var col = firstCol; col <= lastCol; col++) {
        final left = col * width + x, top = row * height + y;
        if (left >= size.width ||
            top >= size.height ||
            left + width <= 0 ||
            top + height <= 0)
          continue;
        c.save();
        c.translate(
          left + (col.isOdd ? width : 0),
          top + (row.isOdd ? height : 0),
        );
        c.scale(col.isOdd ? -1 : 1, row.isOdd ? -1 : 1);
        c.drawImageRect(art, source, target, ink);
        c.restore();
      }
    }
    c.restore();
  }

  /// v11 per-world ground (far plane) and a shared cloud overlay (near
  /// plane). Loaded lazily; until one is ready a plain tinted sky draws.
  static const cloudsAsset = 'assets/art/houses_v12/clouds.webp';
  static const worldCount = 10;
  static ui.Image? clouds;

  /// v11 lobby: the cats' living room at dusk, loaded first at boot.
  static ui.Image? lobbyHome;

  /// Bumped once the living room is decoded so the lobby repaints.
  static final lobbyRevision = ValueNotifier<int>(0);

  /// v12.9 background of every other screen: the cats' attic hangar.
  static ui.Image? menuBackdrop;

  static Future<void> loadLobbyHome() async {
    if (lobbyHome != null) return;
    try {
      lobbyHome = await _decodeAsset('assets/art/lobby_v11/home.jpg', 720);
      lobbyRevision.value++;
    } catch (_) {
      // keep the plain lobby colour
    }
    try {
      menuBackdrop = await _decodeAsset('assets/art/ui_v13/menu_bg.webp', 720);
      lobbyRevision.value++;
    } catch (_) {
      // keep the plain background colour
    }
  }

  /// The living-room picture's size and the middle of its cat cushion, in
  /// picture pixels (assets/art/lobby_v11/home.jpg).
  static const lobbyArtSize = Size(720, 1279);
  static const lobbyCushion = Offset(360, 900);

  /// Where [point] of a [art]-sized picture lands when painted by
  /// [paintCover] into [size].
  static Offset coverPoint(Size size, Size art, Offset point) {
    final scale = math.max(size.width / art.width, size.height / art.height);
    return Offset(
      (size.width - art.width * scale) / 2 + point.dx * scale,
      (size.height - art.height * scale) / 2 + point.dy * scale,
    );
  }

  /// Paints [art] to cover [size], keeping its centre in view.
  static void paintCover(Canvas c, Size size, ui.Image art) {
    final scale = math.max(size.width / art.width, size.height / art.height);
    final w = art.width * scale, h = art.height * scale;
    c.drawImageRect(
      art,
      Rect.fromLTWH(0, 0, art.width.toDouble(), art.height.toDouble()),
      Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  static Future<ui.Image> _decodeAsset(String asset, int width) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      targetWidth: width,
    );
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  /// The drifting cloud veil shared by every stage (the old per-world
  /// grounds are gone; house stages draw their own street).
  static Future<void> ensureWorld(int world) => _cloudLoad ??= () async {
    try {
      clouds ??= await _decodeAsset(cloudsAsset, 720);
    } catch (_) {
      _cloudLoad = null; // missing art keeps the plain sky
    }
  }();
  static Future<void>? _cloudLoad;

  /// v12 house stages: a long top-down strip — the neighbourhood street
  /// (alternately mirrored so the tiles join) ending at the owner's house.
  /// It scrolls down under the cat so the house arrives with the boss.
  static final houseImages = <int, ui.Image>{};
  static final streets = <int, ui.Image>{};
  static final _houseLoads = <int, Future<void>>{};
  static const streetTiles = 6;
  static final _parts = <int, ui.Image>{};

  /// House boss art: fortress parts (1 spray turret, 2 shield generator)
  /// and whole bodies (3 barrage sprinkler station, 4 duelist robo-vac);
  /// missiles (5 the cats' mackerel missile, 6 the empire's spray rocket).
  static ui.Image? partArt(int kind) => _parts[kind];

  /// v12 weapon ultimate sprites (assets/art/icons_v12/<name>.webp).
  static const growthSprites = [
    'mothership',
    'para',
    'tuna',
    'turret',
    'paw',
    'satellite',
    'cloud',
    'mortar',
    // v12.4 field drops: bullet / missile power-ups and the mid-boss box
    'item_bullet',
    'item_missile',
    'item_elite',
  ];
  static final _sprites = <String, ui.Image>{};
  static ui.Image? sprite(String name) => _sprites[name];

  /// Loads the strip for stage [stageIndex]: its neighbourhood's street and
  /// the house at the end (plus the shared house-stage sprites).
  static Future<void> ensureHouse(int stageIndex) {
    final h = houseArt(stageIndex), n = neighborhoodOf(stageIndex);
    return _houseLoads[h] ??= () async {
      // Every picture is fetched and decoded at once: one by one, each
      // network round trip queued behind the last and launch took seconds.
      Future<void> part(int slot, String asset, int width) async =>
          _parts[slot] ??= await _decodeAsset(asset, width);
      try {
        await Future.wait(
          [
            () async =>
                streets[n] ??= await _decodeAsset(streetMap(stageIndex), 720),
            () async =>
                houseImages[h] = await _decodeAsset(houseMap(stageIndex), 720),
            () async => clouds ??= await _decodeAsset('$cloudsAsset', 720),
            () => part(1, 'assets/art/houses_v12/part_turret.webp', 200),
            () => part(2, 'assets/art/houses_v12/part_shield.webp', 200),
            () => part(3, 'assets/art/houses_v12/boss_barrage.webp', 360),
            () => part(4, 'assets/art/houses_v12/boss_duelist.webp', 360),
            () => part(5, 'assets/art/houses_v12/missile_fish.webp', 96),
            () => part(6, 'assets/art/houses_v12/missile_spray.webp', 96),
            for (final name in growthSprites)
              () async => _sprites[name] ??= await _decodeAsset(
                'assets/art/icons_v12/$name.webp',
                160,
              ),
          ].map((load) => load()),
        );
      } catch (_) {
        _houseLoads.remove(h);
      }
    }();
  }

  /// Paints the house stage ground; false while its art is still loading.
  ///
  /// v12.4 (user 2026-10-24): the street tiles loop endlessly while the
  /// formations fly; the owner's house is a separate boss map that a cloud
  /// veil ([paintCloudVeil]) swaps in, so the two scales never meet on screen.
  static bool paintHouse(
    Canvas c,
    Size size,
    int house, {
    double scroll = 0,
    bool houseMap = false,
    double time = 0,
  }) {
    // v12.17 safety net: a missing picture never leaves a blank sky — any
    // street already decoded stands in until this house's art arrives
    final road =
        streets[neighborhoodOf(house)] ??
        (streets.isEmpty ? null : streets.values.first);
    final art = houseImages[houseArt(house)];
    if (road == null || size.isEmpty) return false;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    c.save();
    c.clipRect(Offset.zero & size);
    if (houseMap && art != null) {
      // the boss's house fills the view (cover fit, centred)
      final scale = math.max(size.width / art.width, size.height / art.height);
      final w = art.width * scale, h = art.height * scale;
      c.drawImageRect(
        art,
        Rect.fromLTWH(0, 0, art.width.toDouble(), art.height.toDouble()),
        Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h),
        paint,
      );
    } else {
      final tile = size.width * road.height / road.width;
      final src = Rect.fromLTWH(
        0,
        0,
        road.width.toDouble(),
        road.height.toDouble(),
      );
      // every other tile is mirrored so the road joins seamlessly; the
      // offset repeats every two tiles so the mirroring never flips
      final offset = scroll % (tile * 2);
      for (var k = -2; k * tile + offset < size.height; k++) {
        final y = k * tile + offset;
        if (y + tile < 0) continue;
        final dst = Rect.fromLTWH(0, y, size.width, tile + .5);
        if (k.isOdd) {
          c.save();
          c.translate(0, dst.center.dy * 2);
          c.scale(1, -1);
          c.drawImageRect(road, src, dst, paint);
          c.restore();
        } else {
          c.drawImageRect(road, src, dst, paint);
        }
      }
    }
    if (clouds != null) {
      // drifting cloud shadows: the cat flies above the rooftops
      final cw = size.width * 1.4, ch = cw * clouds!.height / clouds!.width;
      final dy = (time * 38 + scroll * .3) % ch;
      for (var y = dy - ch; y < size.height; y += ch) {
        c.drawImageRect(
          clouds!,
          Rect.fromLTWH(
            0,
            0,
            clouds!.width.toDouble(),
            clouds!.height.toDouble(),
          ),
          Rect.fromLTWH(-size.width * .2, y, cw, ch),
          Paint()
            ..color = Colors.white.withValues(alpha: .22)
            ..filterQuality = FilterQuality.low,
        );
      }
    }
    c.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x18102030), Color(0x00102030), Color(0x40102030)],
        ).createShader(Offset.zero & size),
    );
    c.restore();
    return true;
  }

  /// A thick bank of clouds streaming past the cat. At [cover] 1 the view is
  /// hidden, which is when the street and the boss house swap.
  static void paintCloudVeil(Canvas c, Size size, double cover, double time) {
    if (cover <= 0 || size.isEmpty) return;
    c.save();
    c.clipRect(Offset.zero & size);
    c.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0xFFF2F5FF)
            .withValues(alpha: (cover * 1.2 - .2).clamp(0.0, .94)),
    );
    final puff = clouds;
    if (puff != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        puff.width.toDouble(),
        puff.height.toDouble(),
      );
      for (var layer = 0; layer < 4; layer++) {
        final cw = size.width * (1.3 + layer * .3);
        final ch = cw * puff.height / puff.width;
        final dy = (time * (300 + layer * 120) + layer * 173) % ch;
        final dx = -cw * (.1 + .08 * layer) + math.sin(layer * 1.7) * 30;
        for (var y = dy - ch; y < size.height; y += ch) {
          c.drawImageRect(
            puff,
            src,
            Rect.fromLTWH(dx, y, cw, ch),
            Paint()
              ..color = Colors.white.withValues(
                alpha: (cover * 1.6).clamp(0.0, 1.0),
              )
              ..filterQuality = FilterQuality.low,
          );
        }
      }
    }
    c.restore();
  }

  /// Warms the lobby and the cloud veil in the background.
  static Future<void> preloadWorlds() async {
    await loadLobbyHome();
    await ensureWorld(0);
  }

  static void paint(
    Canvas c,
    Size size, {
    double time = 0,
    Offset camera = Offset.zero,
    int world = 0,
    bool lobby = false,
  }) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    c.save();
    c.clipRect(rect);
    c.drawRect(rect, Paint()..color = const Color(0xFF122D43));
    // Tint and a quiet contrast veil sit below all combat cues, not above them.
    const tones = [
      Color(0xFF3280A0),
      Color(0xFF6674AD),
      Color(0xFF8D744F),
      Color(0xFF72B5CB),
      Color(0xFF388E77),
      Color(0xFF466074),
      Color(0xFFA87F5B),
      Color(0xFF20547E),
      Color(0xFF837DAB),
      Color(0xFF3E8298),
    ];
    c.drawRect(
      rect,
      Paint()
        ..color = tones[world.clamp(0, 9)].withValues(alpha: lobby ? .04 : .12),
    );
    c.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x22102030), Color(0x10102030), Color(0x66102030)],
        ).createShader(rect),
    );
    c.restore();
  }
}
