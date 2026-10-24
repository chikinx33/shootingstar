import 'dart:async';

import '../l10n/app_language.dart';

import '../ui/audio_feedback.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'ship_sprite_art.dart';

import 'arcade_style.dart';
import 'arcade_world.dart';
import 'toon_assets.dart';
import 'menu_art.dart';
import 'lobby_art.dart';
import 'game_art.dart';
import 'refit_art.dart';
import 'flight_scene_art.dart';
import 'aircraft_assembly_art.dart';
import 'ground_art.dart';

/// Shared decoded atlases. Battle exits never dispose these app-owned images.
class RasterAssets {
  static const root = 'assets/art/raster_v6/';
  static const grids = <String, (int, int)>{
    'enemies': (4, 3),
    'bosses': (4, 3),
    'projectiles': (6, 4),
    'effects': (4, 4),
    'icons': (8, 8),
    'panels': (2, 4),
    'worlds': (4, 3),
  };
  static final images = <String, ui.Image>{};
  static final revision = ValueNotifier<int>(0);
  static Future<void>? _loading;
  static Future<void> load() => _loading ??= _load();
  static Future<void> _load() async {
    try {
      await FlightSceneArt.load();
      await RefitArt.load();
      await LobbyArt.load();
      await GameArt.load();
      await AircraftAssemblyArt.load();
      await GroundArt.load();
      GroundArt.installAircraftAliases();
      try {
        await ShipSpriteArt.load();
      } catch (_) {
        // The authored ship is optional at boot; the module art still draws.
      }
      // World grounds stream in behind the lobby; battles wait only for
      // their own world (see BattleScreen).
      unawaited(FlightSceneArt.preloadWorlds());
      revision.value++;
    } catch (_) {
      _loading = null; // Allow an explicit retry after a failed network load.
      rethrow;
    }
  }

  static Rect source(String atlas, int index) {
    final image = images[atlas]!;
    final (cols, rows) = grids[atlas]!;
    assert(index >= 0 && index < cols * rows);
    if (ToonAssets.images.containsKey(atlas)) {
      return ToonAssets.source(atlas, index);
    }
    if (atlas == 'panels') {
      // Hand-checked generated panel bounds; gutters are outside the skin.
      const bounds = [
        Rect.fromLTRB(.002, .002, .494, .304),
        Rect.fromLTRB(.504, .002, .998, .304),
        Rect.fromLTRB(.002, .319, .494, .620),
        Rect.fromLTRB(.504, .319, .998, .620),
        Rect.fromLTRB(.002, .634, .494, .966),
        Rect.fromLTRB(.504, .634, .998, .966),
      ];
      final r = bounds[index];
      return Rect.fromLTRB(
        r.left * image.width,
        r.top * image.height,
        r.right * image.width,
        r.bottom * image.height,
      );
    }
    final w = image.width / cols, h = image.height / rows;
    return Rect.fromLTWH(index % cols * w, index ~/ cols * h, w, h).deflate(.5);
  }

  static void rect(
    Canvas canvas,
    String atlas,
    int index,
    Rect target, {
    double opacity = 1,
    Color? tint,
  }) {
    if (GameArt.paint(
      canvas,
      atlas,
      index,
      target,
      opacity: opacity,
      tint: tint,
    )) {
      return;
    }
    final image = images[atlas];
    if (image == null || target.isEmpty) return;
    final paint = Paint()
      ..filterQuality = FilterQuality.low
      ..color = Colors.white.withValues(alpha: opacity.clamp(0, 1));
    if (tint != null) {
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    }
    canvas.drawImageRect(image, source(atlas, index), target, paint);
  }

  static void sprite(
    Canvas canvas,
    String atlas,
    int index,
    Offset at,
    double size, {
    double rotation = 0,
    double opacity = 1,
    Color? tint,
  }) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (rotation != 0) canvas.rotate(rotation);
    rect(
      canvas,
      atlas,
      index,
      Rect.fromCenter(center: Offset.zero, width: size, height: size),
      opacity: opacity,
      tint: tint,
    );
    canvas.restore();
  }

  /// Panels are drawn in code; sprite atlas interfaces remain battle-owned.
  static void panel(
    Canvas canvas,
    int index,
    Rect target, {
    double border = 12,
  }) => ArcadeStyle.paintPanel(canvas, index, target, border: border);
}

class RasterTile extends StatelessWidget {
  const RasterTile(
    this.atlas,
    this.index, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });
  final String atlas;
  final int index;
  final double? width, height;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return FutureBuilder<void>(
      future: RasterAssets.load(),
      builder: (context, snapshot) => SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: RasterTilePainter(atlas, index, fit)),
      ),
    );
  }
}

class RasterTilePainter extends CustomPainter {
  RasterTilePainter(this.atlas, this.index, this.fit)
    : super(repaint: RasterAssets.revision);
  final String atlas;
  final int index;
  final BoxFit fit;
  @override
  bool hitTest(Offset position) => false;
  @override
  void paint(Canvas canvas, Size size) {
    if (GameArt.paint(canvas, atlas, index, Offset.zero & size)) return;
    if (size.isEmpty) return;
    if (atlas == 'worlds' && !ToonAssets.images.containsKey('worlds')) {
      // Pure code art can also render before the battle atlases finish loading.
      final fitted = applyBoxFit(fit, const Size.square(540), size);
      final target = Alignment.center.inscribe(
        fitted.destination,
        Offset.zero & size,
      );
      final source = Alignment.center.inscribe(
        fitted.source,
        const Rect.fromLTWH(0, 0, 540, 540),
      );
      canvas.save();
      canvas.clipRect(target);
      canvas.translate(target.left, target.top);
      canvas.scale(target.width / source.width, target.height / source.height);
      canvas.translate(-source.left, -source.top);
      ArcadeWorld.paintTile(canvas, index, const Rect.fromLTWH(0, 0, 540, 540));
      canvas.restore();
      return;
    }
    if (!RasterAssets.images.containsKey(atlas)) return;
    final src = RasterAssets.source(atlas, index);
    final fitted = applyBoxFit(fit, src.size, size);
    final from = Alignment.center.inscribe(fitted.source, src);
    final to = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      RasterAssets.images[atlas]!,
      from,
      to,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(RasterTilePainter old) =>
      old.atlas != atlas || old.index != index || old.fit != fit;
}

class RasterPanel extends StatelessWidget {
  const RasterPanel({
    super.key,
    required this.child,
    this.skin = 0,
    this.border = 12,
    this.color,
  });
  final Widget child;
  final int skin;
  final double border;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return CustomPaint(
      painter: _PanelPainter(skin, border, color),
      child: child,
    );
  }
}

class _PanelPainter extends CustomPainter {
  _PanelPainter(this.skin, this.border, this.color);
  final int skin;
  final double border;
  final Color? color;
  @override
  bool hitTest(Offset position) => false;
  @override
  void paint(Canvas canvas, Size size) => ArcadeStyle.paintPanel(
    canvas,
    skin,
    Offset.zero & size,
    border: border,
    color: color,
  );
  @override
  bool shouldRepaint(_PanelPainter old) =>
      old.skin != skin || old.border != border || old.color != color;
}

/// Crisp symbols retain caller color, text direction, and accessibility labels.
class RasterIcon extends StatelessWidget {
  const RasterIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });
  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final extent = size ?? IconTheme.of(context).size ?? 24;
    final menuName = <IconData, String>{
      Icons.storefront: 'gear-cargo',
      Icons.inventory_2: 'gear-cargo',
      Icons.precision_manufacturing: 'tech-cargo',
      Icons.pets: 'pet-cargo',
      Icons.rocket_launch: 'hero',
      Icons.emoji_events: 'challenge-badge',
      Icons.account_tree: 'lobby/research',
      Icons.school: 'lobby/research',
      Icons.build: 'growth-badge',
      Icons.auto_fix_high: 'growth-badge',
    }[icon];
    if (menuName != null && MenuArt.images.containsKey(menuName)) {
      return Semantics(
        label: tr(semanticLabel),
        image: semanticLabel != null,
        child: ExcludeSemantics(child: MenuImage(menuName, size: extent)),
      );
    }
    const controls = [
      Icons.close,
      Icons.arrow_back,
      Icons.arrow_back_ios,
      Icons.add,
      Icons.remove,
      Icons.check,
      Icons.check_circle,
      Icons.check_circle_outline,
    ];
    final atlasIndex = indexFor(icon);
    if ((GameArt.ready || ToonAssets.images.containsKey('icons')) &&
        !controls.contains(icon) &&
        atlasIndex >= 0) {
      return Semantics(
        label: tr(semanticLabel),
        image: semanticLabel != null,
        child: ExcludeSemantics(
          child: ToonTile('icons', atlasIndex, size: extent),
        ),
      );
    }
    final theme = IconTheme.of(context);

    final foreground = color ?? theme.color ?? Colors.white;
    final stroke = (extent / 22).clamp(.75, 1.5);
    return Semantics(
      label: tr(semanticLabel),
      image: semanticLabel != null,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: extent,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              for (final offset in [
                Offset(-stroke, 0),
                Offset(stroke, 0),
                Offset(0, -stroke),
                Offset(0, stroke),
              ])
                Transform.translate(
                  offset: offset,
                  child: Icon(
                    icon,
                    size: extent,
                    color: ArcadeStyle.outline.withValues(alpha: foreground.a),
                  ),
                ),
              Icon(icon, size: extent, color: foreground),
            ],
          ),
        ),
      ),
    );
  }

  static int indexFor(IconData? icon) {
    if (icon == null) return 48;
    final groups = <int, List<IconData>>{
      0: [Icons.radar, Icons.explore, Icons.travel_explore],
      1: [Icons.rocket_launch, Icons.rocket_launch_outlined, Icons.flight],
      2: [Icons.inventory_2_outlined, Icons.storefront],
      3: [Icons.emoji_events_outlined, Icons.emoji_events, Icons.event_repeat],
      4: [Icons.auto_stories_outlined, Icons.auto_stories, Icons.account_tree],
      5: [Icons.tune, Icons.settings],
      6: [Icons.volume_up],
      7: [Icons.volume_off],
      8: [Icons.pause_circle_outline, Icons.pause],
      9: [Icons.favorite, Icons.favorite_border],
      10: [Icons.healing],
      11: [Icons.track_changes],
      12: [Icons.blur_on],
      13: [Icons.inventory_2, Icons.card_giftcard],
      14: [Icons.fast_forward],
      15: [Icons.precision_manufacturing],
      16: [Icons.compare_arrows],
      17: [Icons.bolt, Icons.battery_charging_full],
      18: [Icons.navigation],
      19: [Icons.airplanemode_active],
      20: [Icons.shield_outlined],
      21: [Icons.sports_soccer],
      22: [Icons.satellite_alt],
      23: [Icons.light_mode, Icons.wb_sunny],
      24: [Icons.circle_outlined, Icons.hexagon_outlined],
      25: [Icons.view_agenda],
      26: [Icons.rotate_right],
      27: [Icons.spa, Icons.eco],
      28: [Icons.blur_circular],
      29: [Icons.waves],
      30: [Icons.shield],
      31: [Icons.flash_on, Icons.electric_bolt],
      32: [Icons.local_fire_department, Icons.whatshot],
      33: [Icons.hourglass_bottom],
      34: [Icons.zoom_out_map],
      35: [Icons.speed],
      36: [Icons.school, Icons.diamond],
      37: [Icons.battery_full],
      38: [Icons.security],
      39: [Icons.add],
      40: [Icons.workspace_premium],
      41: [Icons.savings],
      42: [Icons.gps_fixed],
      44: [Icons.person, Icons.person_outline],
      45: [Icons.hexagon],
      46: [Icons.ac_unit],
      47: [Icons.medical_services],
      48: [
        Icons.map_outlined,
        Icons.explore_outlined,
        Icons.location_city,
        Icons.brightness_2,
        Icons.flare,
      ],
      50: [Icons.lock_outline, Icons.lock],
      51: [Icons.check_circle, Icons.check_circle_outline],
      53: [Icons.refresh, Icons.screen_rotation],
      54: [Icons.cloud_done_outlined],
      55: [Icons.groups_outlined, Icons.groups],
      56: [Icons.arrow_back, Icons.arrow_back_ios],
      57: [Icons.close],
      60: [Icons.auto_awesome],
      61: [Icons.description],
      62: [Icons.pets],
      59: [Icons.vpn_key],
      63: [Icons.calendar_month, Icons.assignment_turned_in],
    };
    for (final group in groups.entries) {
      if (group.value.contains(icon)) return group.key;
    }
    // Unknown symbols retain their actual glyph, never an unrelated gift icon.
    return -1;
  }
}

class RasterGauge extends StatelessWidget {
  const RasterGauge({
    super.key,
    this.value,
    this.minHeight = 6,
    this.color,
    this.backgroundColor,
  });
  final double? value;
  final double minHeight;
  final Color? color, backgroundColor;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Semantics(
      value: tr(
        value == null ? '불러오는 중' : '${(value!.clamp(0, 1) * 100).round()}%',
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: value?.clamp(0, 1),
          minHeight: minHeight,
          color: color ?? ArcadeStyle.gold,
          backgroundColor: backgroundColor ?? ArcadeStyle.outline,
        ),
      ),
    );
  }
}

/// Keep the existing API while honoring the complete BoxDecoration contract.
class RasterDecoration extends BoxDecoration {
  const RasterDecoration({
    super.color,
    super.border,
    super.borderRadius,
    super.gradient,
    super.shape = BoxShape.rectangle,
  });
}

Widget _skinDialog(Widget original) {
  final dialog = original as Dialog;
  return Dialog(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    semanticsRole: dialog.semanticsRole,
    constraints: dialog.constraints,
    insetPadding: dialog.insetPadding,
    shape: dialog.shape,
    clipBehavior: Clip.antiAlias,
    child: RasterPanel(child: dialog.child!),
  );
}

class RasterAlertDialog extends AlertDialog {
  const RasterAlertDialog({
    super.key,
    super.title,
    super.content,
    super.actions,
  });
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return _skinDialog(super.build(context));
  }
}

class RasterSimpleDialog extends SimpleDialog {
  const RasterSimpleDialog({super.key, super.title, super.children});
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return _skinDialog(super.build(context));
  }
}

class RasterSkillIcon extends StatelessWidget {
  const RasterSkillIcon(this.id, {super.key, this.size = 24, this.color});
  final String id;
  final double size;
  final Color? color;
  static const icons = <String, int>{
    'gun': 17,
    'missile': 18,
    'drone': 19,
    'droneB': 20,
    'ball': 21,
    'drill': 22,
    'laser': 23,
    'forcefield': 24,
    'brick': 25,
    'boomerang': 26,
    'durian': 27,
    'mine': 28,
    'trail': 29,
    'guardian': 30,
    'lightning': 31,
    'attack': 32,
    'cooldown': 33,
    'area': 34,
    'speed': 35,
    'xp': 36,
    'duration': 37,
    'armor': 38,
    'regen': 39,
    'projectile': 40,
    'gold': 41,
    'crit': 42,
    'side': 43,
    'pilot': 44,
    'infernoMine': 45,
    'thunderMine': 46,
    'medicDrone': 47,
    'hull': 9,
    'repair': 10,
    'magnet': 11,
  };
  static const symbols = <String, IconData>{
    'gun': Icons.bolt,
    'missile': Icons.rocket_launch,
    'drone': Icons.airplanemode_active,
    'droneB': Icons.shield,
    'ball': Icons.sports_soccer,
    'drill': Icons.satellite_alt,
    'laser': Icons.wb_sunny,
    'forcefield': Icons.hexagon,
    'brick': Icons.view_agenda,
    'boomerang': Icons.rotate_right,
    'durian': Icons.spa,
    'mine': Icons.blur_circular,
    'trail': Icons.waves,
    'guardian': Icons.shield,
    'lightning': Icons.electric_bolt,
    'attack': Icons.local_fire_department,
    'cooldown': Icons.hourglass_bottom,
    'area': Icons.zoom_out_map,
    'speed': Icons.speed,
    'xp': Icons.diamond,
    'duration': Icons.battery_full,
    'armor': Icons.security,
    'regen': Icons.add,
    'projectile': Icons.grain,
    'gold': Icons.savings,
    'crit': Icons.gps_fixed,
    'side': Icons.compare_arrows,
    'pilot': Icons.person,
    'infernoMine': Icons.whatshot,
    'thunderMine': Icons.ac_unit,
    'medicDrone': Icons.medical_services,
    'hull': Icons.favorite,
    'repair': Icons.healing,
    'magnet': Icons.track_changes,
  };
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    if (id.startsWith('icon:')) {
      // v12 weapon growth art (mortar, ultimate forms)
      return Image.asset(
        'assets/art/icons_v12/${id.substring(5)}.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
      );
    }
    if (id.startsWith('paw:')) {
      // v12 paw weapons have their own painted icons
      return Image.asset(
        'assets/art/icons_v12/paw_${id.substring(4)}.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
      );
    }
    if (GameArt.ready || ToonAssets.images.containsKey('icons')) {
      // Fusion artwork combines the existing weapon and its actual effect.
      // Atlas slots 45/46 are currencies, not inferno/thunder mine pictures.
      if (id == 'infernoMine' || id == 'thunderMine' || id == 'medicDrone') {
        return SizedBox.square(
          dimension: size,
          child: Stack(
            children: [
              if (id == 'medicDrone')
                ToonTile('ships', 3, size: size)
              else
                ToonTile('icons', 28, size: size),
              Positioned(
                right: 0,
                bottom: 0,
                child: ToonTile(
                  'icons',
                  id == 'infernoMine'
                      ? 32
                      : id == 'thunderMine'
                      ? 31
                      : 47,
                  size: size * .45,
                ),
              ),
            ],
          ),
        );
      }
      if (id == 'gun' || id == 'missile') {
        return ToonTile('equipment', id == 'gun' ? 0 : 1, size: size);
      }
      if (id == 'drone' || id == 'droneB') {
        return ToonTile('ships', id == 'drone' ? 3 : 5, size: size);
      }
      return ToonTile('icons', icons[id] ?? 60, size: size);
    }
    return RasterIcon(
      symbols[id] ?? Icons.auto_awesome,
      size: size,
      color: color,
    );
  }
}

class RasterSwitchListTile extends StatelessWidget {
  const RasterSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.contentPadding,
    this.semanticLabel,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title, subtitle;
  final EdgeInsetsGeometry? contentPadding;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Semantics(
      label: tr(semanticLabel),
      excludeSemantics: semanticLabel != null,
      toggled: value,
      enabled: onChanged != null,
      onTap: audible(onChanged == null ? null : () => onChanged!(!value)),
      child: ListTile(
        contentPadding: contentPadding,
        title: title,
        subtitle: subtitle,
        onTap: audible(onChanged == null ? null : () => onChanged!(!value)),
        trailing: Switch(value: value, onChanged: audibleChange(onChanged)),
      ),
    );
  }
}

class RasterSliderThumb extends SliderComponentShape {
  const RasterSliderThumb();
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(26, 26);
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
      center,
      12,
      Paint()
        ..color = Color.lerp(
          sliderTheme.disabledThumbColor ?? ArcadeStyle.muted,
          sliderTheme.thumbColor ?? ArcadeStyle.gold,
          enableAnimation.value,
        )!,
    );
    canvas.drawCircle(
      center,
      12,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = ArcadeStyle.outline,
    );
    canvas.drawLine(
      center + const Offset(-4, -4),
      center + const Offset(4, -4),
      Paint()
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: .7),
    );
  }
}

class RasterSliderTrack extends RoundedRectSliderTrackShape {
  const RasterSliderTrack();
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    ArcadeStyle.paintPanel(
      context.canvas,
      4,
      rect,
      border: 2,
      color: sliderTheme.inactiveTrackColor,
    );
    ArcadeStyle.paintPanel(
      context.canvas,
      2,
      textDirection == TextDirection.rtl
          ? Rect.fromLTRB(thumbCenter.dx, rect.top, rect.right, rect.bottom)
          : Rect.fromLTRB(rect.left, rect.top, thumbCenter.dx, rect.bottom),
      border: 2,
      color: isEnabled
          ? sliderTheme.activeTrackColor
          : sliderTheme.disabledActiveTrackColor,
    );
  }
}
