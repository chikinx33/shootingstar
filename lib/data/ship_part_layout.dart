import 'dart:math' as math;
import 'dart:ui' show Offset;

/// One sprite of an assembled airframe, as authored in the ship editor.
///
/// Coordinates live on a square ship canvas: the centre is (0, 0) and one
/// unit is the canvas side. [x]/[y] place the sprite's pivot, [width] is the
/// sprite width and its height follows [aspect] (height / width). [pivotX]
/// and [pivotY] pick the pivot inside the sprite (0..1, after [flipX]), and
/// [rotation] turns the sprite clockwise around it in degrees. Higher [z]
/// draws on top. A layer with [mirrorOf] is the mirror image of that layer
/// across the centre line, so a pair is edited once. A layer with [attachTo]
/// rides on that layer: moving, turning or resizing the parent carries it.
class ShipPartLayer {
  const ShipPartLayer({
    required this.id,
    required this.label,
    required this.asset,
    required this.aspect,
    this.x = 0,
    this.y = 0,
    this.width = .2,
    this.rotation = 0,
    this.pivotX = .5,
    this.pivotY = .5,
    this.z = 0,
    this.flipX = false,
    this.visible = true,
    this.mirrorOf,
    this.attachTo,
    this.frames = const [],
    this.fps = 12,
  });

  final String id;
  final String label;
  final String asset;
  final double aspect;
  final double x;
  final double y;
  final double width;
  final double rotation;
  final double pivotX;
  final double pivotY;
  final int z;
  final bool flipX;
  final bool visible;
  final String? mirrorOf;
  final String? attachTo;

  /// Animation frames (a thruster flame). Empty for a still sprite.
  final List<String> frames;
  final double fps;

  double get height => width * aspect;
  bool get animated => frames.length > 1;
  String frameAsset(double seconds) =>
      animated ? frames[(seconds * fps).floor() % frames.length] : asset;

  ShipPartLayer copyWith({
    double? x,
    double? y,
    double? width,
    double? rotation,
    double? pivotX,
    double? pivotY,
    int? z,
    bool? flipX,
    bool? visible,
    String? mirrorOf,
    bool clearMirror = false,
  }) => ShipPartLayer(
    id: id,
    label: label,
    asset: asset,
    aspect: aspect,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    rotation: rotation ?? this.rotation,
    pivotX: pivotX ?? this.pivotX,
    pivotY: pivotY ?? this.pivotY,
    z: z ?? this.z,
    flipX: flipX ?? this.flipX,
    visible: visible ?? this.visible,
    mirrorOf: clearMirror ? null : mirrorOf ?? this.mirrorOf,
    attachTo: attachTo,
    frames: frames,
    fps: fps,
  );

  /// This layer drawn as the mirror image of [source].
  ShipPartLayer mirroredFrom(ShipPartLayer source) => ShipPartLayer(
    id: id,
    label: label,
    asset: source.asset,
    aspect: source.aspect,
    x: -source.x,
    y: source.y,
    width: source.width,
    rotation: -source.rotation,
    pivotX: 1 - source.pivotX,
    pivotY: source.pivotY,
    z: z,
    flipX: !source.flipX,
    visible: visible,
    mirrorOf: mirrorOf,
    attachTo: attachTo,
    frames: source.frames,
    fps: source.fps,
  );

  /// Canvas position of a point inside the sprite (fractions, after flip).
  Offset canvasPoint(double u, double v) {
    final a = rotation * math.pi / 180;
    final dx = (u - pivotX) * width;
    final dy = (v - pivotY) * height;
    return Offset(
      x + dx * math.cos(a) - dy * math.sin(a),
      y + dx * math.sin(a) + dy * math.cos(a),
    );
  }

  /// Moves the pivot without moving the sprite on the canvas.
  ShipPartLayer withPivot(double u, double v) {
    final at = canvasPoint(u, v);
    return copyWith(pivotX: u, pivotY: v, x: at.dx, y: at.dy);
  }

  static double _number(Object? value, double fallback) =>
      value is num && value.isFinite ? value.toDouble() : fallback;

  factory ShipPartLayer.fromJson(Map<String, dynamic> json) {
    final frames = json['frames'] is List
        ? [
            for (final f in json['frames'] as List)
              if (f is String) f,
          ]
        : const <String>[];
    return ShipPartLayer(
      id: json['id'] as String,
      label: json['label'] as String? ?? json['id'] as String,
      asset: json['asset'] as String? ?? (frames.isEmpty ? '' : frames.first),
      aspect: _number(json['aspect'], 1),
      x: _number(json['x'], 0),
      y: _number(json['y'], 0),
      width: _number(json['width'], .2),
      rotation: _number(json['rotation'], 0),
      pivotX: _number(json['pivotX'], .5),
      pivotY: _number(json['pivotY'], .5),
      z: _number(json['z'], 0).round(),
      flipX: json['flipX'] == true,
      visible: json['visible'] != false,
      mirrorOf: json['mirrorOf'] as String?,
      attachTo: json['attachTo'] as String?,
      frames: frames,
      fps: _number(json['fps'], 12),
    );
  }

  static double _round(double v) => (v * 10000).roundToDouble() / 10000;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'asset': asset,
    'aspect': _round(aspect),
    'x': _round(x),
    'y': _round(y),
    'width': _round(width),
    'rotation': _round(rotation),
    'pivotX': _round(pivotX),
    'pivotY': _round(pivotY),
    'z': z,
    'flipX': flipX,
    'visible': visible,
    if (mirrorOf != null) 'mirrorOf': mirrorOf,
    if (attachTo != null) 'attachTo': attachTo,
    if (frames.isNotEmpty) 'frames': frames,
    if (frames.isNotEmpty) 'fps': fps,
  };
}

/// Every layer of one airframe.
class ShipLayout {
  const ShipLayout({
    required this.id,
    required this.label,
    required this.layers,
  });

  final String id;
  final String label;
  final List<ShipPartLayer> layers;

  ShipPartLayer? layer(String id) {
    for (final l in layers) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Layers with mirrors resolved, in draw order (low z first). Equal z
  /// keeps the file order, so a tie always draws the same way.
  List<ShipPartLayer> get resolved {
    final out = [
      for (final l in layers)
        if (l.mirrorOf != null && layer(l.mirrorOf!) != null)
          l.mirroredFrom(layer(l.mirrorOf!)!)
        else
          l,
    ];
    final order = {for (var i = 0; i < layers.length; i++) layers[i].id: i};
    out.sort((a, b) {
      final byZ = a.z.compareTo(b.z);
      return byZ != 0 ? byZ : order[a.id]!.compareTo(order[b.id]!);
    });
    return out;
  }

  ShipLayout replace(ShipPartLayer next) => ShipLayout(
    id: id,
    label: label,
    layers: [for (final l in layers) l.id == next.id ? next : l],
  );

  /// Replaces a layer and carries everything attached to it, as if the
  /// children were glued to the parent sprite (its centre, turn and size).
  ShipLayout update(ShipPartLayer next) {
    final before = layer(next.id);
    var out = replace(next);
    if (before == null) return out;
    final from = before.canvasPoint(.5, .5), to = next.canvasPoint(.5, .5);
    final turn = next.rotation - before.rotation;
    final scale = before.width == 0 ? 1.0 : next.width / before.width;
    final flipped = before.flipX != next.flipX;
    final a0 = -before.rotation * math.pi / 180;
    final a1 = next.rotation * math.pi / 180;
    for (final child in layers.where((l) => l.attachTo == next.id)) {
      final d = Offset(child.x - from.dx, child.y - from.dy);
      var lx = d.dx * math.cos(a0) - d.dy * math.sin(a0);
      final ly = d.dx * math.sin(a0) + d.dy * math.cos(a0);
      if (flipped) lx = -lx;
      final mx = lx * scale, my = ly * scale;
      out = out.update(
        child.copyWith(
          x: to.dx + mx * math.cos(a1) - my * math.sin(a1),
          y: to.dy + mx * math.sin(a1) + my * math.cos(a1),
          width: child.width * scale,
          rotation: (flipped ? -child.rotation : child.rotation) + turn,
          flipX: flipped ? !child.flipX : child.flipX,
        ),
      );
    }
    return out;
  }

  factory ShipLayout.fromJson(String id, Map<String, dynamic> json) =>
      ShipLayout(
        id: id,
        label: json['label'] as String? ?? id,
        layers: [
          for (final l in (json['layers'] as List? ?? const []))
            if (l is Map<String, dynamic>) ShipPartLayer.fromJson(l),
        ],
      );

  Map<String, dynamic> toJson() => {
    'label': label,
    'layers': [for (final l in layers) l.toJson()],
  };
}

/// The whole authored file (assets/data/ship_layouts.json).
///
/// [revision] grows on every save, so the newest of the bundled file, the
/// local project file and this browser's copy wins on load.
class ShipLayoutBook {
  const ShipLayoutBook({required this.revision, required this.ships});

  final int revision;
  final Map<String, ShipLayout> ships;

  ShipLayoutBook withShip(ShipLayout ship) =>
      ShipLayoutBook(revision: revision, ships: {...ships, ship.id: ship});

  ShipLayoutBook nextRevision() =>
      ShipLayoutBook(revision: revision + 1, ships: ships);

  factory ShipLayoutBook.fromJson(Map<String, dynamic> json) {
    final ships = json['ships'] is Map<String, dynamic>
        ? json['ships'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return ShipLayoutBook(
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      ships: {
        for (final e in ships.entries)
          if (e.value is Map<String, dynamic>)
            e.key: ShipLayout.fromJson(e.key, e.value as Map<String, dynamic>),
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'revision': revision,
    'ships': {for (final e in ships.entries) e.key: e.value.toJson()},
  };
}
