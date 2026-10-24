import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../art/ship_sprite_art.dart';
import '../data/ship_layout_store.dart';
import '../data/ship_part_layout.dart';
import '../l10n/app_language.dart';
import 'audio_feedback.dart';
import 'game_ui.dart';

/// Master-only ship assembly editor (developer mode).
///
/// Every part sprite of an airframe is placed by hand here: position, size,
/// rotation, pivot, draw order, visibility and flip. Left/right pairs (wings,
/// missiles, wing guns, thrusters) are one entry and move as a mirror image:
/// the buttons work on the right-hand piece and the left follows across the
/// centre line. Saving writes assets/data/ship_layouts.json on the loopback
/// preview (tools/play_web.py), otherwise this browser keeps it until the
/// JSON is copied into the project. The game reads the same file.
class ShipPartEditorScreen extends StatefulWidget {
  const ShipPartEditorScreen({
    super.key,
    this.shipId = 'sunshine',
    this.store = const ShipLayoutStore(),
  });

  final String shipId;
  final ShipLayoutStore store;

  @override
  State<ShipPartEditorScreen> createState() => _ShipPartEditorScreenState();
}

enum _Tab { move, size, pivot, order }

class _ShipPartEditorScreenState extends State<ShipPartEditorScreen>
    with SingleTickerProviderStateMixin {
  static const _backgrounds = [
    Color(0xFF14243A),
    Color(0xFF26688C),
    Color(0xFFFFC45C),
  ];
  static const _stepNames = ['미세', '보통', '크게'];

  ShipLayoutBook? _book;
  ShipLayoutBook? _saved;
  ShipLayoutSource _source = ShipLayoutSource.bundled;

  /// Always an independent layer (never a mirror); a pair is selected by
  /// its source piece.
  String? _selected;

  /// Which piece of a pair a canvas drag holds: +1 right, -1 left.
  int _dragSide = 1;

  /// Magnifier steps; 80% starts with the whole ship and a margin in view.
  static const _zoomLevels = [
    .4, .5, .6, .7, .8, .9, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0, 4.0, //
  ];
  Offset _pan = Offset.zero;
  final List<ShipLayoutBook> _history = [];
  _Tab _tab = _Tab.move;
  int _step = 1;
  int _background = 0;
  double _zoom = .8;
  bool _dimOthers = false;
  bool _saving = false;
  String? _notice;
  double _seconds = 0;
  late final Ticker _ticker = createTicker(
    (elapsed) => setState(() => _seconds = elapsed.inMicroseconds / 1e6),
  );
  Timer? _repeat;

  late String _shipId = widget.shipId;
  ShipLayout? get _ship => _book?.ships[_shipId];

  /// Cycles through every authored cat airframe (Sunshine, Nightfall, ...).
  void _nextShip() {
    final ids = _book?.ships.keys.toList() ?? const <String>[];
    if (ids.length < 2) return;
    setState(() {
      _shipId = ids[(ids.indexOf(_shipId) + 1) % ids.length];
      final ship = _ship;
      _selected = ship == null
          ? null
          : (ship.layer('canopy') ?? _choices(ship).first).id;
      _notice = message('편집 기체: {0}', [tr(ship?.label ?? _shipId)]);
    });
  }

  bool get _dirty =>
      _book != null &&
      _saved != null &&
      ShipLayoutStore.encode(_book!) != ShipLayoutStore.encode(_saved!);

  @override
  void initState() {
    super.initState();
    _ticker.start();
    unawaited(_load());
  }

  @override
  void dispose() {
    _repeat?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loaded = await widget.store.load();
    if (!mounted) return;
    setState(() {
      _book = loaded.book;
      _saved = loaded.book;
      _source = loaded.source;
      final ship = _ship;
      if (ship != null && ship.layers.isNotEmpty) {
        _selected = (ship.layer('canopy') ?? _choices(ship).first).id;
      }
    });
  }

  // ---- pairs ---------------------------------------------------------------

  /// What the part list offers: every layer that is not someone's mirror.
  List<ShipPartLayer> _choices(ShipLayout ship) =>
      [...ship.layers.where((l) => l.mirrorOf == null)]
        ..sort((a, b) => b.z.compareTo(a.z));

  /// The mirror layer following [sourceId], if any.
  ShipPartLayer? _mirrorOf(String sourceId) {
    for (final l in _ship?.layers ?? const <ShipPartLayer>[]) {
      if (l.mirrorOf == sourceId) return l;
    }
    return null;
  }

  ShipPartLayer? get _layer =>
      _selected == null ? null : _ship?.layer(_selected!);
  bool get _paired => _layer != null && _mirrorOf(_layer!.id) != null;

  /// The selected part as drawn on [side] (+1 right, -1 left). For a single
  /// part this is just the layer.
  ShipPartLayer? _view([int side = 1]) {
    final layer = _layer;
    if (layer == null) return null;
    final mirror = _mirrorOf(layer.id);
    if (mirror == null) return layer;
    final mirrored = mirror.mirroredFrom(layer);
    final layerSide = layer.x >= 0 ? 1 : -1;
    return layerSide == side ? layer : mirrored;
  }

  String _labelOf(ShipPartLayer l) {
    if (_mirrorOf(l.id) != null) return message('{0} · 좌우 함께', [tr(l.label)]);
    if (_partnerOf(l.id) != null && l.id.endsWith('_l')) {
      return message('{0} (왼쪽)', [tr(l.label)]);
    }
    return tr(l.label);
  }

  // ---- editing -------------------------------------------------------------

  void _remember() {
    _history.add(_book!);
    if (_history.length > 80) _history.removeAt(0);
  }

  /// Applies [change] to the selected part as seen on [side]. For a pair the
  /// result is written into the source piece (mirrored back when the right
  /// view is the mirror), so both sides always stay symmetric. Parts attached
  /// to it (thruster flames, the canopy on the pod) ride along.
  void _edit(
    ShipPartLayer Function(ShipPartLayer view) change, {
    int side = 1,
    bool remember = true,
  }) {
    final layer = _layer, ship = _ship, view = _view(side);
    if (layer == null || ship == null || view == null) return;
    if (remember) _remember();
    final next = change(view);
    var source = next.id == layer.id
        ? next
        : layer.mirroredFrom(next).copyWith(clearMirror: true);
    source = source.copyWith(z: next.z, visible: next.visible);
    var updated = ship.update(source);
    final mirror = _mirrorOf(layer.id);
    if (mirror != null) {
      updated = updated.replace(
        mirror.copyWith(z: next.z, visible: next.visible),
      );
    }
    setState(() {
      _book = _book!.withShip(updated);
      _notice = null;
    });
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _book = _history.removeLast();
      if (_selected != null && _layer == null) {
        _selected = _choices(_ship!).first.id;
      }
      _notice = tr('한 단계 되돌렸습니다.');
    });
  }

  void _revert() {
    if (_saved == null) return;
    _remember();
    setState(() {
      _book = _saved;
      if (_selected != null && _layer == null) {
        _selected = _choices(_ship!).first.id;
      }
      _notice = tr('마지막 저장 상태로 돌렸습니다.');
    });
  }

  Future<void> _save() async {
    final book = _book;
    if (book == null || _saving) return;
    setState(() => _saving = true);
    final result = await widget.store.save(book);
    // The lobby and battle pick the saved layout up straight away.
    unawaited(ShipSpriteArt.reload(result.book));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _book = result.book;
      _saved = result.book;
      _source = result.project
          ? ShipLayoutSource.project
          : ShipLayoutSource.browser;
      _notice = result.project
          ? message('저장 완료 r{0} · 프로젝트 파일에 기록', [result.book.revision])
          : message('저장 완료 r{0} · 이 브라우저에만 저장됨. JSON 복사로 전달하세요.', [
              result.book.revision,
            ]);
    });
  }

  Future<void> _copyJson() async {
    final book = _book;
    if (book == null) return;
    await Clipboard.setData(ClipboardData(text: ShipLayoutStore.encode(book)));
    if (mounted) setState(() => _notice = tr('JSON을 클립보드에 복사했습니다.'));
  }

  double get _posStep => const [.001, .005, .02][_step];
  double get _rotStep => const [.5, 5.0, 15.0][_step];
  double get _pivotStep => const [.01, .05, .1][_step];

  /// [sign] follows the screen: +1 is right / down / bigger / clockwise /
  /// in front. Pairs use the right-hand piece, so +1 on x spreads them apart.
  void _nudge(String field, int sign, {bool remember = true}) => _edit(
    remember: remember,
    (l) => switch (field) {
      'x' => l.copyWith(x: l.x + sign * _posStep),
      'y' => l.copyWith(y: l.y + sign * _posStep),
      'width' => l.copyWith(width: math.max(.005, l.width + sign * _posStep)),
      'rotation' => l.copyWith(rotation: _wrap(l.rotation + sign * _rotStep)),
      'pivotX' => l.withPivot(_unit(l.pivotX + sign * _pivotStep), l.pivotY),
      'pivotY' => l.withPivot(l.pivotX, _unit(l.pivotY + sign * _pivotStep)),
      'z' => l.copyWith(z: l.z + sign),
      _ => l,
    },
  );

  static double _wrap(double degrees) {
    var d = degrees % 360;
    if (d > 180) d -= 360;
    if (d <= -180) d += 360;
    return d;
  }

  static double _unit(double v) => v.clamp(0.0, 1.0).toDouble();

  /// The other side's layer id by name (wing_l ↔ wing_r).
  String? _partnerOf(String id) {
    final ship = _ship;
    if (ship == null) return null;
    for (final (a, b) in [
      ('_r', '_l'),
      ('_l', '_r'),
      ('_right', '_left'),
      ('_left', '_right'),
    ]) {
      if (id.endsWith(a)) {
        final other = '${id.substring(0, id.length - a.length)}$b';
        if (ship.layer(other) != null) return other;
      }
    }
    return null;
  }

  void _toggleLink() {
    final layer = _layer, ship = _ship;
    if (layer == null || ship == null) return;
    final mirror = _mirrorOf(layer.id);
    _remember();
    if (mirror != null) {
      // Keep how both sides look now, then each is edited on its own.
      setState(() {
        _book = _book!.withShip(
          ship.replace(mirror.mirroredFrom(layer).copyWith(clearMirror: true)),
        );
        _notice = tr('좌우 연동을 해제했습니다. 이제 한쪽씩 움직입니다.');
      });
      return;
    }
    final partner = _partnerOf(layer.id);
    if (partner == null) return;
    // The left piece leads; the right one becomes its mirror.
    final left = layer.id.endsWith('_l') || layer.id.endsWith('_left')
        ? layer
        : ship.layer(partner)!;
    final right = left.id == layer.id ? ship.layer(partner)! : layer;
    setState(() {
      _book = _book!.withShip(ship.replace(right.copyWith(mirrorOf: left.id)));
      _selected = left.id;
      _notice = tr('좌우를 다시 함께 움직입니다.');
    });
  }

  // ---- canvas --------------------------------------------------------------

  /// Canvas side and the ship centre inside a viewport of [size]. [_pan]
  /// is how far the master dragged the view (empty-space drag).
  (double, Offset) _frame(Size size) {
    final side = math.min(size.width, size.height) * .92 * _zoom;
    return (side, size.center(Offset.zero) + _pan);
  }

  /// Steps the magnifier through [_zoomLevels], keeping the middle of the
  /// screen where it is.
  void _zoomBy(int dir) {
    final i = _zoomLevels.indexWhere((z) => (z - _zoom).abs() < 1e-6);
    final next = _zoomLevels[(i + dir).clamp(0, _zoomLevels.length - 1)];
    setState(() {
      _pan = _pan * (next / _zoom);
      _zoom = next;
    });
  }

  void _drag(DragUpdateDetails d, double side) {
    final delta = d.delta / side;
    if (_tab == _Tab.pivot) {
      _edit(
        (l) {
          final a = -l.rotation * math.pi / 180;
          final lx = delta.dx * math.cos(a) - delta.dy * math.sin(a);
          final ly = delta.dx * math.sin(a) + delta.dy * math.cos(a);
          return l.withPivot(
            _unit(l.pivotX + lx / l.width),
            _unit(l.pivotY + ly / l.height),
          );
        },
        side: _dragSide,
        remember: false,
      );
    } else {
      _edit(
        (l) => l.copyWith(x: l.x + delta.dx, y: l.y + delta.dy),
        side: _dragSide,
        remember: false,
      );
    }
  }

  /// Topmost visible layer under [local], as drawn.
  ShipPartLayer? _hit(Offset local, double side, Offset centre) {
    final ship = _ship;
    if (ship == null) return null;
    final p = (local - centre) / side;
    for (final l in ship.resolved.reversed) {
      if (!l.visible) continue;
      final a = -l.rotation * math.pi / 180;
      final dx = p.dx - l.x, dy = p.dy - l.y;
      final u = (dx * math.cos(a) - dy * math.sin(a)) / l.width + l.pivotX;
      final v = (dx * math.sin(a) + dy * math.cos(a)) / l.height + l.pivotY;
      if (u >= 0 && u <= 1 && v >= 0 && v <= 1) return l;
    }
    return null;
  }

  /// Tapping a part selects it; tapping empty background clears the
  /// selection (then a drag moves the view instead of a part).
  void _tapSelect(Offset local, double side, Offset centre) {
    final hit = _hit(local, side, centre);
    setState(() {
      _selected = hit == null ? null : hit.mirrorOf ?? hit.id;
      _dragSide = hit == null || hit.x >= 0 ? 1 : -1;
    });
  }

  Widget _canvas() {
    final ship = _ship!;
    return LayoutBuilder(
      builder: (context, box) {
        final (side, centre) = _frame(box.biggest);
        final layer = _layer;
        final mirror = layer == null ? null : _mirrorOf(layer.id);
        final selected = [
          ?layer,
          if (mirror != null && layer != null) mirror.mirroredFrom(layer),
        ];
        return GestureDetector(
          key: const Key('ship-editor-canvas'),
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) {
            if (_layer == null) return; // nothing selected: the drag pans
            _remember();
            // Dragging grabs whichever side of a pair is under the finger.
            final p = (d.localPosition - centre) / side;
            _dragSide = p.dx >= 0 ? 1 : -1;
          },
          onPanUpdate: (d) =>
              _layer == null ? setState(() => _pan += d.delta) : _drag(d, side),
          onTapUp: (d) =>
              audible(() => _tapSelect(d.localPosition, side, centre))!(),
          child: ClipRect(
            child: ColoredBox(
              color: _backgrounds[_background],
              child: Stack(
                children: [
                  for (final l in ship.resolved)
                    if (l.visible)
                      _sprite(
                        l,
                        side,
                        centre,
                        selected.any((s) => s.id == l.id),
                      ),
                  if (selected.isNotEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _SelectionPainter(selected, side, centre),
                        ),
                      ),
                    ),
                  Positioned(left: 4, top: 4, child: _canvasTools()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sprite(ShipPartLayer l, double side, Offset centre, bool isSelected) {
    final w = l.width * side, h = l.height * side;
    final dim = _dimOthers && !isSelected;
    return Positioned(
      left: centre.dx + l.x * side - l.pivotX * w,
      top: centre.dy + l.y * side - l.pivotY * h,
      width: w,
      height: h,
      child: IgnorePointer(
        child: Opacity(
          opacity: dim ? .35 : 1,
          child: Transform.rotate(
            angle: l.rotation * math.pi / 180,
            alignment: Alignment(l.pivotX * 2 - 1, l.pivotY * 2 - 1),
            child: Transform.flip(
              flipX: l.flipX,
              child: Image.asset(
                l.frameAsset(_seconds),
                fit: BoxFit.fill,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _canvasTools() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _toolIcon(
        Icons.format_color_fill,
        '배경색 바꾸기',
        () => setState(
          () => _background = (_background + 1) % _backgrounds.length,
        ),
      ),
      _toolIcon(
        _dimOthers ? Icons.visibility : Icons.visibility_outlined,
        '선택 외 흐리게',
        () => setState(() => _dimOthers = !_dimOthers),
      ),
      _toolIcon(
        Icons.zoom_out,
        '작게 보기',
        _zoom <= _zoomLevels.first ? null : () => _zoomBy(-1),
      ),
      Container(
        constraints: const BoxConstraints(minWidth: 52, minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xCC0E1726),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${(_zoom * 100).round()}%',
          key: const Key('ship-editor-zoom'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      _toolIcon(
        Icons.zoom_in,
        '크게 보기',
        _zoom >= _zoomLevels.last ? null : () => _zoomBy(1),
      ),
      _toolIcon(
        Icons.center_focus_strong,
        '가운데로',
        _pan == Offset.zero ? null : () => setState(() => _pan = Offset.zero),
      ),
    ],
  );

  Widget _toolIcon(IconData icon, String tip, VoidCallback? onPressed) =>
      IconButton(
        tooltip: tr(tip),
        onPressed: audible(onPressed),
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: const Color(0xCC0E1726),
          foregroundColor: Colors.white,
        ),
        icon: Icon(icon, size: 26),
      );

  // ---- panel ---------------------------------------------------------------

  Widget _button(
    String label,
    VoidCallback? onPressed, {
    Key? key,
    bool strong = false,
  }) => FilledButton(
    key: key,
    style: GameUi.compactButton.copyWith(
      backgroundColor: strong
          ? const WidgetStatePropertyAll(Color(0xFFFFB72C))
          : null,
      foregroundColor: strong
          ? const WidgetStatePropertyAll(Color(0xFF1B1B2A))
          : null,
    ),
    onPressed: audible(onPressed),
    child: Text(label, textAlign: TextAlign.center),
  );

  /// Tap nudges once; holding keeps nudging and undoes as one step.
  Widget _repeatButton(String label, String field, int sign) => GestureDetector(
    onLongPressStart: (_) {
      _remember();
      _repeat?.cancel();
      _repeat = Timer.periodic(
        const Duration(milliseconds: 70),
        (_) => _nudge(field, sign, remember: false),
      );
    },
    onLongPressEnd: (_) => _repeat?.cancel(),
    child: _button(
      label,
      () => _nudge(field, sign),
      key: Key('ship-editor-$field-$sign'),
    ),
  );

  /// [less]/[more] name the direction of -1/+1 on screen.
  Widget _directionRow(
    String caption,
    String field,
    String value,
    String less,
    String more,
  ) => ConstrainedBox(
    // Grows when a caption wraps (large text) instead of clipping it.
    constraints: const BoxConstraints(minHeight: 52),
    child: Row(
      children: [
        Expanded(flex: 3, child: _repeatButton(less, field, -1)),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                caption,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB8C7DA)),
              ),
              Text(
                value,
                key: Key('ship-editor-value-$field'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        Expanded(flex: 3, child: _repeatButton(more, field, 1)),
      ],
    ),
  );

  Widget _tabs() => Row(
    children: [
      for (final (tab, label) in [
        (_Tab.move, '위치'),
        (_Tab.size, '크기·회전'),
        (_Tab.pivot, '기준점'),
        (_Tab.order, '순서·표시'),
      ])
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            // The shared button skin paints over colours, so the current
            // choice is the only one at full strength.
            child: Opacity(
              opacity: _tab == tab ? 1 : .45,
              child: FilledButton(
                key: Key('ship-editor-tab-${tab.name}'),
                style: GameUi.compactButton,
                onPressed: audible(() => setState(() => _tab = tab)),
                child: Text(tr(label), textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _controls(ShipPartLayer l) {
    String f(double v) => v.toStringAsFixed(3);
    final pair = _paired;
    return switch (_tab) {
      _Tab.move => Column(
        children: [
          pair
              ? _directionRow(
                  tr('좌우 간격'),
                  'x',
                  f(l.x.abs()),
                  tr('→← 안쪽으로'),
                  tr('바깥쪽으로 ←→'),
                )
              : _directionRow(
                  tr('가로'),
                  'x',
                  f(l.x),
                  tr('← 왼쪽으로'),
                  tr('오른쪽으로 →'),
                ),
          _directionRow(tr('세로'), 'y', f(l.y), tr('↑ 위로'), tr('↓ 아래로')),
        ],
      ),
      _Tab.size => Column(
        children: [
          _directionRow(
            tr('크기'),
            'width',
            '${(l.width * 100).toStringAsFixed(1)}%',
            tr('작게'),
            tr('크게'),
          ),
          _directionRow(
            pair ? tr('회전 · 좌우 대칭') : tr('회전'),
            'rotation',
            '${l.rotation.toStringAsFixed(1)}°',
            pair ? tr('↺ 바깥쪽 들기') : tr('↺ 반시계'),
            pair ? tr('바깥쪽 내리기 ↻') : tr('시계 ↻'),
          ),
        ],
      ),
      _Tab.pivot => Column(
        children: [
          _directionRow(
            tr('기준점 가로'),
            'pivotX',
            f(l.pivotX),
            tr('← 왼쪽으로'),
            tr('오른쪽으로 →'),
          ),
          _directionRow(
            tr('기준점 세로'),
            'pivotY',
            f(l.pivotY),
            tr('↑ 위로'),
            tr('↓ 아래로'),
          ),
        ],
      ),
      _Tab.order => Column(
        children: [
          _directionRow(
            tr('그리는 순서'),
            'z',
            '${l.z}',
            tr('뒤로 보내기'),
            tr('앞으로 가져오기'),
          ),
          SizedBox(
            height: 52,
            child: Row(
              children: [
                Expanded(
                  child: _button(
                    tr(l.visible ? '숨기기' : '보이기'),
                    () => _edit((d) => d.copyWith(visible: !d.visible)),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _button(
                    tr('좌우 반전'),
                    () => _edit((d) => d.copyWith(flipX: !d.flipX)),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _button(
                    tr(pair ? '한쪽씩 편집' : '좌우 함께'),
                    pair || _partnerOf(_layer!.id) != null ? _toggleLink : null,
                    key: const Key('ship-editor-link'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    };
  }

  Future<void> _pickLayer() async {
    final ship = _ship;
    if (ship == null) return;
    final picked = await showDialog<String>(
      context: context,
      // Two columns across the whole screen width: every part fits one
      // fixed board even on a 320x568 phone, with no scrolling.
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF14243A),
        insetPadding: const EdgeInsets.all(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(
            builder: (context, box) {
              final cell = math.min(220.0, (box.maxWidth - 6) / 2);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      tr('편집할 부위'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final l in _choices(ship))
                        SizedBox(
                          width: cell,
                          child: Opacity(
                            opacity: l.id == _selected ? 1 : .7,
                            child: FilledButton(
                              style: GameUi.compactButton,
                              onPressed: audible(
                                () => Navigator.pop(context, l.id),
                              ),
                              child: Text(
                                l.id == _selected
                                    ? '✓ ${_labelOf(l)}'
                                    : _labelOf(l),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selected = picked;
        _dragSide = 1;
      });
    }
  }

  void _cycleLayer(int dir) {
    final ship = _ship;
    if (ship == null) return;
    final layers = _choices(ship);
    final i = layers.indexWhere((l) => l.id == _selected);
    setState(() {
      _selected = layers[(i + dir) % layers.length].id;
      _dragSide = 1;
    });
  }

  Widget _panel() {
    final view = _view();
    final layer = _layer;
    return Container(
      color: const Color(0xFF0E1726),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _toolIcon(Icons.chevron_left, '이전 부위', () => _cycleLayer(-1)),
              Expanded(
                child: _button(
                  layer == null ? tr('부위 선택') : _labelOf(layer),
                  _pickLayer,
                  key: const Key('ship-editor-layer'),
                ),
              ),
              _toolIcon(Icons.chevron_right, '다음 부위', () => _cycleLayer(1)),
            ],
          ),
          const SizedBox(height: 4),
          _tabs(),
          const SizedBox(height: 4),
          if (view != null)
            _controls(view)
          else
            SizedBox(
              height: 104,
              child: Center(
                child: Text(
                  tr('부위를 눌러 선택하세요. 빈 곳을 끌면 화면이 움직입니다.'),
                  key: const Key('ship-editor-no-selection'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFFB8C7DA),
                  ),
                ),
              ),
            ),
          SizedBox(
            height: 52,
            child: Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Opacity(
                        opacity: _step == i ? 1 : .45,
                        child: FilledButton(
                          key: Key('ship-editor-step-$i'),
                          style: GameUi.compactButton,
                          onPressed: audible(() => setState(() => _step = i)),
                          child: Text(
                            message('{0} 단계', [tr(_stepNames[i])]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _notice!,
                key: const Key('ship-editor-notice'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFFFFD27A)),
              ),
            ),
          const SizedBox(height: 4),
          SizedBox(
            height: 52,
            child: Row(
              children: [
                Expanded(
                  child: _button(
                    tr(_saving ? '저장 중' : '저장'),
                    _dirty && !_saving ? _save : null,
                    key: const Key('ship-editor-save'),
                    strong: true,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(child: _button(tr('저장본으로'), _dirty ? _revert : null)),
                const SizedBox(width: 4),
                Expanded(child: _button(tr('JSON 복사'), _copyJson)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('저장하지 않은 변경이 있습니다'), textAlign: TextAlign.center),
        content: Text(
          tr('저장하지 않고 나가면 변경이 사라집니다.'),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          _button(tr('계속 편집'), () => Navigator.pop(context, false)),
          _button(tr('나가기'), () => Navigator.pop(context, true)),
        ],
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final ship = _ship;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          setState(() => _saved = _book);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0E1726),
        appBar: AppBar(
          title: Text(
            ship == null
                ? tr('기체 조립 편집기')
                : message('기체 조립 편집기 · {0}', [tr(ship.label)]),
            textAlign: TextAlign.center,
          ),
          actions: [
            IconButton(
              key: const Key('ship-editor-next-ship'),
              tooltip: tr('다른 기체 편집'),
              onPressed: audible(
                (_book?.ships.length ?? 0) > 1 ? _nextShip : null,
              ),
              icon: const Icon(Icons.swap_horiz, size: 28),
            ),
            IconButton(
              tooltip: tr('되돌리기'),
              onPressed: audible(_history.isEmpty ? null : _undo),
              icon: const Icon(Icons.undo, size: 28),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(22),
            child: Text(
              message('r{0} · {1}{2}', [
                _book?.revision ?? 0,
                tr(switch (_source) {
                  ShipLayoutSource.project => '프로젝트 파일',
                  ShipLayoutSource.bundled => '게임 기본값',
                  ShipLayoutSource.browser => '이 브라우저 저장본',
                }),
                _dirty ? tr(' · 저장 안 됨') : '',
              ]),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFFB8C7DA)),
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ship == null
              ? Center(
                  child: Text(
                    _book == null ? tr('불러오는 중') : tr('편집할 기체 배치가 없습니다.'),
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  children: [
                    Expanded(child: _canvas()),
                    _panel(),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Outline and pivot cross of the selected sprites (editor guide only).
class _SelectionPainter extends CustomPainter {
  _SelectionPainter(this.layers, this.side, this.centre);

  final List<ShipPartLayer> layers;
  final double side;
  final Offset centre;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = const Color(0xFFFFE066)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final cross = Paint()
      ..color = const Color(0xFFFF4D6D)
      ..strokeWidth = 2;
    for (final layer in layers) {
      Offset p(double u, double v) => centre + layer.canvasPoint(u, v) * side;
      canvas.drawPath(
        Path()..addPolygon([p(0, 0), p(1, 0), p(1, 1), p(0, 1)], true),
        outline,
      );
      final pivot = centre + Offset(layer.x, layer.y) * side;
      canvas.drawLine(
        pivot - const Offset(10, 0),
        pivot + const Offset(10, 0),
        cross,
      );
      canvas.drawLine(
        pivot - const Offset(0, 10),
        pivot + const Offset(0, 10),
        cross,
      );
      canvas.drawCircle(
        pivot,
        4,
        Paint()
          ..color = const Color(0xFFFF4D6D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_SelectionPainter old) => true;
}
