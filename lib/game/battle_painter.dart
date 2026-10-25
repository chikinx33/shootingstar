import '../art/flight_scene_art.dart';
import '../l10n/app_language.dart';

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../art/ship_sprite_art.dart';
import 'glow_shots.dart';

import 'package:flutter/foundation.dart' show listEquals;

import '../art/raster_assets.dart';
import '../art/experience_gem_art.dart';
import '../art/game_art.dart';
import '../art/toon_assets.dart';
import '../art/arcade_aircraft.dart';
import '../art/aircraft_assembly_art.dart';
import '../art/ground_art.dart';
import '../art/module_aircraft_art.dart';
import '../data/ship_modules.dart';
import '../data/aircraft_assembly.dart';
import '../data/aircraft_geometry.dart';
import '../data/content.dart' as content;
import 'engine.dart';
import 'world_art.dart';
import 'combat_vfx.dart';
import 'laser_beam.dart';
import 'resolution_vfx.dart';

class BattlePainter extends CustomPainter {
  final GameEngine game;
  final bool reducedEffects;
  // The reference path is retained for pixel comparison and CPU diagnosis.
  final bool cacheProjectiles;

  /// The sortie intro draws the cat's craft itself until it lands in place.
  final bool hideHero;
  BattlePainter(
    this.game, {
    this.reducedEffects = false,
    this.cacheProjectiles = true,
    this.hideHero = false,
  }) : super(repaint: RasterAssets.revision);

  /// Impact/explosion family (0-2, 15) → v11 cartoon explosion; sparks
  /// (3, 4, 7, 14) → v11 hit star. Other effect cells keep their art.
  void _fx(
    Canvas canvas,
    int index,
    Offset at,
    double diameter, {
    double opacity = 1,
    double rotation = 0,
  }) {
    final v11 = switch (index) {
      0 || 1 || 2 || 15 => 'explosion',
      3 || 4 || 7 || 14 => 'hit_spark',
      _ => null,
    };
    if (v11 != null &&
        ShipSpriteArt.paintFx(
          canvas,
          v11,
          at,
          diameter,
          rotation,
          opacity: opacity,
        )) {
      return;
    }
    _fxLegacy(
      canvas,
      index,
      at,
      diameter,
      opacity: opacity,
      rotation: rotation,
    );
  }

  void _fxLegacy(
    Canvas canvas,
    int index,
    Offset at,
    double diameter, {
    double opacity = 1,
    double rotation = 0,
  }) => RasterAssets.sprite(
    canvas,
    'effects',
    index,
    at,
    diameter,
    opacity: opacity,
    rotation: rotation,
  );
  void _beam(
    Canvas canvas,
    Offset from,
    Offset to,
    double width, {
    bool hostile = false,
    double opacity = 1,
  }) {
    if ((to - from).distance < .01) return;
    final alpha = opacity.clamp(0.0, 1.0);
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = const Color(0xFF17202C).withValues(alpha: alpha)
        ..strokeWidth = width + 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = (hostile ? const Color(0xFFFF674B) : const Color(0xFF4DE0FA))
            .withValues(alpha: alpha)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    if (width >= 8) {
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = const Color(0xFFFFF5C9).withValues(alpha: alpha)
          ..strokeWidth = width * .35
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _gauge(Canvas canvas, Offset at, double width, double value) {
    RasterAssets.panel(
      canvas,
      4,
      Rect.fromLTWH(at.dx - width / 2, at.dy, width, 4),
      border: 1,
    );
    RasterAssets.panel(
      canvas,
      2,
      Rect.fromLTWH(at.dx - width / 2, at.dy, width * value.clamp(0, 1), 4),
      border: 1,
    );
  }

  static final _projectilePictures = <(int, double, Color, bool), ui.Picture>{};
  static final _gemPictures = <int, ui.Picture>{};
  static final _crystalFields = <(List<(Offset, int)>, ui.Picture)>[];
  static int _pictureRevision = -1;

  @visibleForTesting
  static int get cachedProjectilePictures => _projectilePictures.length;
  @visibleForTesting
  static int get cachedCrystalFields => _crystalFields.length;

  void _ensurePictureRevision() {
    final revision = RasterAssets.revision.value;
    if (_pictureRevision == revision) return;
    for (final picture in _projectilePictures.values) {
      picture.dispose();
    }
    _projectilePictures.clear();
    for (final picture in _gemPictures.values) {
      picture.dispose();
    }
    _gemPictures.clear();
    for (final field in _crystalFields) {
      field.$2.dispose();
    }
    _crystalFields.clear();
    _pictureRevision = revision;
  }

  void _crystal(Canvas canvas, Offset at, double rotation) {
    final value = ExperienceCrystal.valueOf(at);
    final grade = ExperienceCrystal.grade(value);
    // v12.4.2 user: house-stage gems read too small on a phone
    final scale = game.screenMode ? 1.9 : 1.0;
    if (!cacheProjectiles || !GameArt.ready) {
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.scale(scale);
      ExperienceGemArt.paint(canvas, Offset.zero, value, rotation: rotation);
      canvas.restore();
      return;
    }
    _ensurePictureRevision();
    if (!_gemPictures.containsKey(grade)) {
      final recorder = ui.PictureRecorder();
      ExperienceGemArt.paint(Canvas(recorder), Offset.zero, value);
      _gemPictures[grade] = recorder.endRecording();
    }
    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (rotation != 0) canvas.rotate(rotation);
    canvas.scale(scale);
    canvas.drawPicture(_gemPictures[grade]!);
    canvas.restore();
  }

  void _crystalField(Canvas canvas, bool Function(Offset, double) onScreen) {
    if (cacheProjectiles && reducedEffects && GameArt.ready) {
      final visible = [
        for (final point in game.crystals)
          if (onScreen(point, 24))
            (point, ExperienceCrystal.grade(ExperienceCrystal.valueOf(point))),
      ];
      if (visible.length >= 128 && visible.length <= 1536) {
        _ensurePictureRevision();
        var index = 0;
        for (var start = 0; start < visible.length; start += 128) {
          final points = visible.sublist(
            start,
            math.min(start + 128, visible.length),
          );
          if (index >= _crystalFields.length ||
              !listEquals(points, _crystalFields[index].$1)) {
            final recorder = ui.PictureRecorder(), field = Canvas(recorder);
            for (final point in points) {
              _crystal(field, point.$1, 0);
            }
            final entry = (points, recorder.endRecording());
            if (index < _crystalFields.length) {
              _crystalFields[index].$2.dispose();
              _crystalFields[index] = entry;
            } else {
              _crystalFields.add(entry);
            }
          }
          canvas.drawPicture(_crystalFields[index++].$2);
        }
        for (var i = index; i < _crystalFields.length; i++) {
          _crystalFields[i].$2.dispose();
        }
        _crystalFields.removeRange(index, _crystalFields.length);
        return;
      }
    }
    for (final crystal in game.crystals) {
      if (!onScreen(crystal, 12)) continue;
      _crystal(
        canvas,
        crystal,
        reducedEffects ? 0 : math.sin(game.combatTime * 3 + crystal.dx) * .15,
      );
    }
  }

  bool _cachedShot(Canvas canvas, Shot shot) {
    // Only invariant, moving pulse sprites/trails. Missiles, laser/area cues,
    // fuses and age-dependent effects always use the original path.
    if (!cacheProjectiles ||
        !GameArt.ready ||
        (shot.kind != 0 && shot.kind != 4) ||
        shot.velocity.distance <= 10) {
      return false;
    }
    _ensurePictureRevision();
    final index = shot.kind == 4
        ? 4
        : game.mainPower >= 3
        ? 1
        : 0;
    final size = shot.kind == 4
        ? math.max(14.0, shot.radius * 5.3)
        : (19 + math.max(0, shot.radius - 3) * 2).toDouble();
    final tint = shot.hostile
        ? const Color(0xFFFF9778)
        : CombatVfx.color(shot.weapon);
    final key = (index, size, tint, reducedEffects);
    var picture = _projectilePictures[key];
    if (picture == null) {
      if (_projectilePictures.length >= 128) {
        _projectilePictures.remove(_projectilePictures.keys.first)!.dispose();
      }
      final recorder = ui.PictureRecorder(), local = Canvas(recorder);
      _uncachedShot(
        local,
        Shot(
          Offset.zero,
          const Offset(0, -100),
          0,
          shot.kind,
          weapon: shot.weapon,
          radius: shot.radius,
        ),
      );
      picture = recorder.endRecording();
      _projectilePictures[key] = picture;
    }
    canvas.save();
    canvas.translate(shot.position.dx, shot.position.dy);
    canvas.rotate(math.atan2(shot.velocity.dy, shot.velocity.dx) + math.pi / 2);
    canvas.drawPicture(picture);
    canvas.restore();
    return true;
  }

  void _shot(Canvas canvas, Shot shot) {
    // v12: every ordinary projectile is drawn as light (GlowShots).
    if (_glowShot(canvas, shot)) return;
    if (game.unifiedModules && shot.weapon.startsWith('part:')) {
      if (shot.age < 0 || shot.life <= 0) return;
      final at = game.partShotVisualPosition(shot, reduced: reducedEffects);
      final missile = shot.kind == 1;
      if (missile && shot.closeRange && shot.target != null) {
        canvas.drawCircle(
          shot.target!.position,
          12,
          Paint()
            ..color = const Color(0x883EE8FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(math.atan2(shot.velocity.dx, -shot.velocity.dy));
      final tail = Paint()
        ..color = missile ? const Color(0x99FFBF5A) : const Color(0xAA38DDF2)
        ..strokeWidth = missile ? 3 : 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(0, 3), Offset(0, missile ? 17 : 10), tail);
      if (missile) {
        if (!ShipSpriteArt.paintFx(
          canvas,
          'player_missile',
          Offset.zero,
          shot.weapon.contains(':W2:') ? 20 : 16,
          0,
        )) {
          canvas.scale(shot.weapon.contains(':W2:') ? 9 : 7);
          ModuleAircraftArt.paintPart(canvas, modulePart('missile_hawk'));
        }
      } else {
        canvas.drawLine(
          const Offset(0, -4),
          const Offset(0, 3),
          Paint()
            ..color = const Color(0xFF101C2A)
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          const Offset(0, -4),
          const Offset(0, 3),
          Paint()
            ..color = const Color(0xFFFFE68A)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.restore();
      return;
    }
    // v11 PNG projectiles: pink enemy orbs, yellow bolts, missiles.
    if (_fxShot(canvas, shot)) return;
    if (_cachedShot(canvas, shot)) return;
    _uncachedShot(canvas, shot);
  }

  /// Glow projectiles by family. Returns false for special shots (shells
  /// with fuses, lasers, area cues) that keep their own drawing.
  void _sprite(
    Canvas canvas,
    String name,
    Offset at,
    double size, {
    double angle = 0,
    double opacity = 1,
  }) {
    final image = FlightSceneArt.sprite(name);
    if (image == null || opacity <= 0) return;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (angle != 0) canvas.rotate(angle);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: size, height: size),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
    );
    canvas.restore();
  }

  /// Vulcan ultimate: two free-aiming turrets ride on the wing tips.
  void _wingTurrets(Canvas canvas) {
    if (!game.unifiedModules || !game.ult('part:W1')) return;
    for (final side in [0, 1]) {
      final at = game.moduleWorldAnchor('W1', side);
      Foe? near;
      var best = double.infinity;
      for (final e in game.enemies) {
        if (e.hp <= 0) continue;
        final d = (e.position - at).distanceSquared;
        if (d < best) {
          best = d;
          near = e;
        }
      }
      final to = near == null ? const Offset(0, -1) : near.position - at;
      _sprite(
        canvas,
        'turret',
        at,
        30,
        angle: math.atan2(to.dy, to.dx) + math.pi / 2,
      );
    }
  }

  /// v12 paw weapons: all light, no pictures (see lib/game/paw_weapons.dart).
  void _pawWeapons(Canvas canvas) {
    const laserRed = Color(0xFFFF3B5C), yarnPink = Color(0xFFFF6FB5);
    for (final fx in game.pawFx) {
      final fade = fx.life.isFinite
          ? (1 - fx.age / fx.life).clamp(0.0, 1.0)
          : 1.0;
      switch (fx.kind) {
        case 'orbit':
          // a glowing paw: pad plus three toe beans
          final dir = fx.position - game.position;
          final a = math.atan2(dir.dy, dir.dx) + math.pi / 2;
          GlowShots.paint(
            canvas,
            GlowShape.orb,
            fx.position,
            fx.radius * 2.1,
            GlowShots.gold,
          );
          for (var i = -1; i <= 1; i++) {
            final t = a + i * .62;
            GlowShots.paint(
              canvas,
              GlowShape.orb,
              fx.position +
                  Offset(math.sin(t), -math.cos(t)) * fx.radius * 1.15,
              fx.radius * .95,
              GlowShots.orange,
            );
          }
        case 'yarn':
          GlowShots.disc(canvas, fx.position, fx.radius, yarnPink);
          GlowShots.ring(
            canvas,
            fx.position,
            fx.radius * .62,
            Colors.white,
            width: 2,
            opacity: .7,
          );
          GlowShots.paint(
            canvas,
            GlowShape.star,
            fx.position +
                Offset(math.cos(fx.spin), math.sin(fx.spin)) * fx.radius,
            10,
            GlowShots.gold,
          );
        case 'blast':
          final k = (fx.age / fx.life).clamp(0.0, 1.0);
          GlowShots.disc(
            canvas,
            fx.position,
            fx.radius * (.35 + k * .65),
            yarnPink,
            opacity: (1 - k) * .55,
          );
          GlowShots.ring(
            canvas,
            fx.position,
            fx.radius * (.5 + k * .5),
            GlowShots.orange,
            width: 5,
            opacity: 1 - k,
          );
        case 'laser':
          final pulse = .85 + math.sin(fx.age * 40) * .15;
          GlowShots.beam(
            canvas,
            fx.position,
            fx.origin,
            fx.radius * pulse,
            laserRed,
            opacity: math.min(1, fade * 4),
          );
          GlowShots.disc(canvas, fx.origin, fx.radius * 1.6, laserRed);
        case 'crescent':
          GlowShots.paint(
            canvas,
            GlowShape.crescent,
            fx.position,
            fx.radius * 2.2,
            GlowShots.cyan,
            angle: fx.spin,
          );
        case 'ball':
          GlowShots.disc(
            canvas,
            fx.position,
            fx.radius,
            GlowShots.gold,
            opacity: math.min(1, fade * 3),
          );
          GlowShots.ring(
            canvas,
            fx.position,
            fx.radius * .7,
            GlowShots.cyan,
            width: 3,
            opacity: math.min(1, fade * 3),
          );
        case 'giantpaw':
          // the paw drops from the sky, slams, then lifts away
          final k = (fx.age / .45).clamp(0.0, 1.0);
          GlowShots.ring(
            canvas,
            fx.position,
            fx.radius * (.4 + .6 * k),
            GlowShots.orange,
            width: 4,
            opacity: fx.returning ? fade : .6,
          );
          _sprite(
            canvas,
            'paw',
            fx.position,
            fx.radius * 1.6 * (2 - k),
            opacity: fx.returning ? fade : k,
          );
        case 'yarnstorm':
          GlowShots.disc(canvas, fx.position, fx.radius, yarnPink);
          for (var i = 0; i < 3; i++) {
            final a = fx.spin + i * math.pi * 2 / 3;
            GlowShots.paint(
              canvas,
              GlowShape.star,
              fx.position + Offset(math.cos(a), math.sin(a)) * fx.radius,
              12,
              GlowShots.gold,
            );
          }
        case 'net':
        case 'goo':
          canvas.drawCircle(
            fx.position,
            fx.radius,
            Paint()
              ..color = (fx.kind == 'net' ? yarnPink : GlowShots.green)
                  .withValues(alpha: .16 * fade),
          );
          GlowShots.ring(
            canvas,
            fx.position,
            fx.radius,
            fx.kind == 'net' ? yarnPink : GlowShots.green,
            width: 2,
            opacity: .6 * fade,
          );
        case 'satellite':
          if (fx.target != null) {
            GlowShots.beam(
              canvas,
              fx.position,
              fx.origin,
              14 + math.sin(game.combatTime * 30) * 2,
              laserRed,
            );
            GlowShots.disc(canvas, fx.origin, 20, laserRed);
          }
          _sprite(canvas, 'satellite', fx.position, 58);
        case 'typhoon':
          GlowShots.paint(
            canvas,
            GlowShape.crescent,
            fx.position,
            fx.radius * 2.4,
            GlowShots.cyan,
            angle: game.combatTime * 9,
          );
        case 'pinball':
          GlowShots.disc(canvas, fx.position, fx.radius, GlowShots.gold);
          GlowShots.ring(
            canvas,
            fx.position,
            fx.radius * .72,
            GlowShots.pink,
            width: 4,
          );
        case 'cloud':
          _sprite(canvas, 'cloud', fx.position, 74);
        case 'shell':
          if (fx.age < 0) break;
          GlowShots.ring(
            canvas,
            fx.origin,
            fx.radius * .9,
            GlowShots.orange,
            width: 2,
            opacity: .5,
          );
          GlowShots.paint(
            canvas,
            GlowShape.orb,
            fx.position,
            18,
            GlowShots.orange,
          );
        case 'mothership':
          _sprite(
            canvas,
            'mothership',
            fx.position + Offset(0, math.sin(fx.spin * 2) * 4),
            74,
          );
        case 'para':
          if (fx.age < 0) break;
          _sprite(canvas, 'para', fx.position, 22);
        case 'sunbeam':
          final wobble = 1 + math.sin(game.combatTime * 40) * .08;
          GlowShots.beam(
            canvas,
            fx.position,
            Offset(fx.position.dx, game.viewRect.top),
            fx.radius * 1.4 * wobble,
            GlowShots.gold,
            opacity: math.min(1, fade * 4),
          );
        case 'rail':
          GlowShots.beam(
            canvas,
            fx.position,
            Offset(fx.position.dx, game.viewRect.top),
            fx.radius * fade,
            GlowShots.cyan,
          );
        case 'claw':
          for (var i = -1; i <= 1; i++) {
            GlowShots.paint(
              canvas,
              GlowShape.crescent,
              fx.position + Offset(i * fx.radius * .55, 0),
              fx.radius * 1.6,
              GlowShots.violet,
              angle: fx.spin,
              opacity: math.min(1, fade * 2),
            );
          }
        case 'zap':
          final seed = (fx.spin + fx.age * 30).floor();
          for (var i = 0; i + 1 < fx.chain.length; i++) {
            GlowShots.lightning(
              canvas,
              fx.chain[i],
              fx.chain[i + 1],
              3,
              const Color(0xFFFFF27A),
              seed + i,
              opacity: fade,
            );
          }
      }
    }
  }

  /// A missile is an object, not a beam (user 2026-10-24): the cats fire
  /// mackerel missiles (5), the empire fires spray-can rockets (6), each with
  /// a small flickering exhaust flame.
  bool _missile(
    Canvas canvas,
    Offset at,
    double angle,
    int art,
    double length, {
    String? sprite,
  }) {
    final image = sprite != null
        ? FlightSceneArt.sprite(sprite)
        : FlightSceneArt.partArt(art);
    if (image == null) return false;
    final dir = Offset(math.sin(angle), -math.cos(angle));
    final width = length * image.width / image.height;
    if (!reducedEffects) {
      final flicker = 1 + math.sin(game.atmosphereTime * 40 + at.dx) * .18;
      GlowShots.paint(
        canvas,
        GlowShape.bean,
        at - dir * (length * .5 + 5 * flicker),
        12 * flicker,
        art == 5 ? GlowShots.orange : GlowShots.pink,
        angle: angle,
      );
    }
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: width, height: length),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
    return true;
  }

  /// Floating vacuum mine: a hot core inside a slowly turning danger ring
  /// that marks exactly where it hurts; it blinks fast just before it fades.
  void _mine(Canvas canvas, Shot shot) {
    final at = shot.position;
    final grow = (shot.age / .25).clamp(0.0, 1.0);
    final r = shot.radius * grow;
    final ending = shot.life < 1.2;
    final blink = ending ? (math.sin(shot.age * 26) > 0 ? 1.0 : .35) : 1.0;
    canvas.drawCircle(
      at,
      r,
      Paint()..color = GlowShots.pink.withValues(alpha: .1 * blink),
    );
    final ring = Paint()
      ..color = (ending ? Colors.white : GlowShots.pink).withValues(
        alpha: .75 * blink,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final spin = reducedEffects ? 0.0 : shot.age * 1.6;
    for (var i = 0; i < 8; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: at, radius: r),
        spin + i * math.pi / 4,
        math.pi / 7,
        false,
        ring,
      );
    }
    GlowShots.paint(
      canvas,
      GlowShape.star,
      at,
      22 * grow,
      GlowShots.pink,
      angle: spin * .5,
      opacity: blink,
    );
  }

  bool _glowShot(Canvas canvas, Shot shot) {
    if (shot.kind == 17) {
      _mine(canvas, shot);
      return true;
    }
    if (shot.kind == 21 || shot.kind == 22) {
      // lobbed shell: its landing spot glows on the ground, the shell arcs
      final center = shot.anchor ?? shot.position;
      final arc = shot.kind == 22 && shot.fuse > 0
          ? math.sin((shot.age / shot.fuse).clamp(0, 1) * math.pi) * 24
          : 0.0;
      GlowShots.ring(
        canvas,
        center,
        shot.radius * 1.1,
        GlowShots.orange,
        width: 2,
        opacity: .55,
      );
      GlowShots.paint(
        canvas,
        GlowShape.orb,
        shot.position - Offset(0, arc),
        shot.kind == 22 ? 16 : 20,
        GlowShots.orange,
      );
      return true;
    }
    if (shot.velocity.distance <= 10) return false;
    final angle = math.atan2(shot.velocity.dx, -shot.velocity.dy);
    final part = shot.weapon.startsWith('part:');
    if (part && (shot.age < 0 || shot.life <= 0)) return true;
    final at = part
        ? game.partShotVisualPosition(shot, reduced: reducedEffects)
        : shot.position;
    switch (shot.kind) {
      case 4:
        GlowShots.paint(
          canvas,
          GlowShape.bean,
          at,
          math.max(13, shot.radius * 4.2),
          GlowShots.pink,
          angle: angle,
        );
        return true;
      case 19:
        GlowShots.paint(
          canvas,
          GlowShape.diamond,
          at,
          math.max(16, shot.radius * 4.6),
          GlowShots.violet,
          angle: angle,
        );
        return true;
      case 20:
        if (_missile(canvas, at, angle, 6, 28)) return true;
        if (!reducedEffects) {
          GlowShots.beam(
            canvas,
            at,
            at - shot.velocity / shot.velocity.distance * 22,
            4,
            GlowShots.orange,
            opacity: .55,
          );
        }
        GlowShots.paint(
          canvas,
          GlowShape.oval,
          at,
          18,
          GlowShots.orange,
          angle: angle,
        );
        return true;
    }
    if (shot.hostile) return false;
    if (part) {
      final missile = shot.kind == 1;
      final tuna = shot.weapon.endsWith(':tuna');
      if (missile &&
          _missile(
            canvas,
            at,
            angle,
            5,
            tuna
                ? 58
                : shot.weapon.endsWith(':mini')
                ? 20
                : shot.weapon.contains(':W2:')
                ? 34
                : 30,
            sprite: tuna ? 'tuna' : null,
          )) {
        return true;
      }
      if (missile) {
        if (!reducedEffects) {
          GlowShots.beam(
            canvas,
            at,
            at - shot.velocity / shot.velocity.distance * 20,
            4,
            GlowShots.cyan,
            opacity: .5,
          );
        }
        GlowShots.paint(
          canvas,
          GlowShape.oval,
          at,
          shot.weapon.contains(':W2:') ? 22 : 17,
          GlowShots.cyan,
          angle: angle,
        );
      } else {
        GlowShots.paint(
          canvas,
          shot.weapon.contains('drone') ? GlowShape.diamond : GlowShape.bean,
          at,
          15,
          shot.weapon.contains('drone') ? GlowShots.green : GlowShots.gold,
          angle: angle,
        );
      }
      return true;
    }
    if (shot.weapon == 'module-main') {
      // the airframe's own main gun (user 2026-10-24): a glowing oval with a
      // short light trail, tinted per cat — no bullet pictures
      final tint = switch (game.shipIndex) {
        1 => const Color(0xFF9FE2FF),
        2 => GlowShots.violet,
        _ => GlowShots.cyan,
      };
      final size = math.max(17.0, shot.radius * 3.6);
      if (!reducedEffects) {
        GlowShots.beam(
          canvas,
          at,
          at - shot.velocity / shot.velocity.distance * size * .9,
          size * .2,
          tint,
          opacity: .45,
        );
      }
      GlowShots.paint(canvas, GlowShape.oval, at, size, tint, angle: angle);
      return true;
    }
    if (shot.weapon == 'pet') {
      // the chick's round pellets keep the old orb look, now as light
      GlowShots.paint(canvas, GlowShape.orb, at, 15, GlowShots.orange);
      return true;
    }
    if (shot.kind == 0) {
      // the cat's own nose cannon
      GlowShots.paint(
        canvas,
        GlowShape.bean,
        at,
        16 + math.max(0, shot.radius - 3) * 2.4,
        game.shipIndex == 2 ? GlowShots.orange : GlowShots.gold,
        angle: angle,
      );
      return true;
    }
    return false;
  }

  bool _fxShot(Canvas canvas, Shot shot) {
    if (shot.velocity.distance <= 10) return false;
    final String name;
    final double size;
    if (shot.kind == 4) {
      name = 'enemy_orb';
      size = math.max(15.0, shot.radius * 5.4);
    } else if (shot.kind == 19) {
      // guided bolts read as the bigger spiked orb
      name = 'enemy_big';
      size = math.max(20.0, shot.radius * 4);
    } else if (shot.kind == 0 && !shot.hostile) {
      name = 'player_bolt';
      size = 16 + math.max(0, shot.radius - 3) * 2;
    } else {
      return false;
    }
    final spin = name == 'player_bolt'
        ? math.atan2(shot.velocity.dy, shot.velocity.dx) + math.pi / 2
        : 0.0;
    return ShipSpriteArt.paintFx(canvas, name, shot.position, size, spin);
  }

  void _uncachedShot(Canvas canvas, Shot shot) {
    if (shot.kind == 28) {
      RasterAssets.sprite(
        canvas,
        'projectiles',
        2,
        shot.position,
        18,
        rotation: math.atan2(shot.velocity.dy, shot.velocity.dx) + math.pi / 2,
      );
      return;
    }
    if (shot.kind == 27) {
      canvas.drawCircle(
        shot.position,
        9,
        Paint()..color = const Color(0xFF986BDD),
      );
      canvas.drawCircle(
        shot.position,
        9,
        Paint()
          ..color = const Color(0xFF24202E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      return;
    }
    if (shot.kind == 26) {
      final to = shot.anchor ?? shot.position;
      final progress = (shot.age / .45).clamp(0.0, 1.0);
      final at = Offset.lerp(shot.position, to, progress)!;
      canvas.drawCircle(
        to,
        shot.radius,
        Paint()..color = const Color(0x44FFD45A),
      );
      canvas.drawCircle(
        to,
        shot.radius,
        Paint()
          ..color = const Color(0xFFFFD45A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      RasterAssets.sprite(
        canvas,
        'projectiles',
        2,
        at,
        15 * (1 - progress * .45),
      );
      return;
    }
    CombatVfx.projectile(canvas, shot, reducedEffects);
    if (shot.kind == 23) {
      LaserBeam.paint(
        canvas,
        shot.position,
        shot.position + shot.velocity,
        shot.radius * 2,
        hostile: true,
        age: shot.age,
        duration: shot.age + shot.life,
        reduced: reducedEffects,
      );
      return;
    }
    if (shot.kind == 24) {
      final frame = (shot.age / .1).floor().clamp(0, 3);
      _fx(
        canvas,
        frame,
        shot.position,
        shot.radius * 2.3,
        opacity: (shot.life / .4).clamp(0, 1) * .7,
      );
      return;
    }
    if (shot.kind == 21 || shot.kind == 22) {
      final center = shot.anchor ?? shot.position;
      _fx(canvas, 12, center, shot.radius * 2.2, opacity: .75);
      final arc = shot.kind == 22 && shot.fuse > 0
          ? math.sin((shot.age / shot.fuse).clamp(0, 1) * math.pi) * 24
          : 0.0;
      RasterAssets.sprite(
        canvas,
        'projectiles',
        shot.kind == 22 ? 14 : 20,
        shot.position - Offset(0, arc),
        24,
        rotation: math.atan2(shot.velocity.dy, shot.velocity.dx) + math.pi / 2,
        tint: const Color(0xFFFFAD88),
      );
      return;
    }
    if (shot.kind == 19 || shot.kind == 20) {
      RasterAssets.sprite(
        canvas,
        'projectiles',
        shot.kind == 20 ? 2 : 4,
        shot.position,
        shot.kind == 20 ? 30 : 18,
        rotation: math.atan2(shot.velocity.dy, shot.velocity.dx) + math.pi / 2,
        tint: shot.kind == 20 ? const Color(0xFFFF9B88) : null,
      );
      return;
    }
    if (shot.kind == 18) {
      LaserBeam.paint(
        canvas,
        shot.position,
        shot.position + shot.velocity,
        shot.radius * 2 + 5,
        age: shot.age,
        duration: shot.age + shot.life,
        reduced: reducedEffects,
      );
      return;
    }
    if (shot.kind == 13 || shot.kind == 3 || shot.kind == 5) {
      final effect = shot.weapon == 'void'
          ? 9
          : shot.weapon == 'inferno' || shot.weapon == 'trail'
          ? 10
          : shot.kind == 3
          ? 11
          : 6;
      _fx(
        canvas,
        effect,
        shot.position,
        shot.radius *
            2 *
            (reducedEffects ? 1 : .96 + .04 * math.sin(shot.age * 10)),
        opacity: reducedEffects ? .22 : .4,
        rotation: reducedEffects ? 0 : shot.age * .5,
      );
      return;
    }
    final index = switch (shot.kind) {
      0 => game.mainPower >= 3 ? 1 : 0,
      1 => 2,
      2 => 13,
      4 => 4,
      6 => 7,
      7 => 8,
      8 => 10,
      9 => 7,
      10 => 9,
      11 => 18,
      12 => 11,
      14 => 19,
      15 => 14,
      16 => 15,
      17 => 16,
      _ => 0,
    };
    final moving = shot.velocity.distance > 1;
    final angle = moving
        ? math.atan2(shot.velocity.dy, shot.velocity.dx) + math.pi / 2
        : shot.age;
    final size = shot.kind == 17
        ? shot.radius * 2
        : [7, 8, 10, 11, 12, 14].contains(shot.kind)
        ? math.max(18.0, shot.radius * 2.3)
        : shot.kind == 0
        ? 19 + math.max(0, shot.radius - 3) * 2
        : shot.kind == 4
        ? math.max(14.0, shot.radius * 5.3)
        : shot.kind == 1 || shot.kind == 9
        ? 27.0
        : 21.0;
    RasterAssets.sprite(
      canvas,
      'projectiles',
      index,
      shot.position,
      size.toDouble(),
      rotation: angle,
    );
    if (shot.kind == 17) {
      _fx(canvas, 12, shot.position, shot.radius * 2, opacity: .65);
    }
  }

  /// The house-stage ground, painted across the whole side-scrolling field
  /// and shifted by the camera pan.
  bool _houseGround(Canvas canvas, double viewHeight) {
    canvas.save();
    canvas.translate(-sideReach - game.screenPan, 0);
    final painted = FlightSceneArt.paintHouse(
      canvas,
      Size(420 + sideReach * 2, viewHeight),
      game.stageIndex,
      scroll: game.mapScroll,
      houseMap: game.houseMapShown,
      time: reducedEffects ? 0 : game.atmosphereTime,
    );
    canvas.restore();
    return painted;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 420);
    final viewHeight = game.viewportHeight;
    if (!game.screenMode || !_houseGround(canvas, viewHeight))
      WorldArt.background(
        canvas,
        Size(420, viewHeight),
        game.worldIndex,
        reducedEffects ? 0 : game.atmosphereTime,
        // Center the scenic origin at the initial world position. Both camera
        // axes then move scenery opposite to flight, independently per depth.
        reducedEffects
            ? Offset.zero
            : game.position -
                  const Offset(
                    GameEngine.worldWidth / 2,
                    GameEngine.worldHeight / 2,
                  ),
      );
    if (!reducedEffects && game.hurtFlash > .4) {
      canvas.translate(
        math.sin(game.combatTime * 80) * 1.8,
        math.cos(game.combatTime * 65) * 1.2,
      );
    }
    if (game.hazardVisible) {
      canvas.save();
      canvas.translate(-game.camera.dx, -game.camera.dy);
      final active = game.hazardActive;
      final ink = active ? const Color(0xFFFF746E) : const Color(0xFFFFD56A);
      final fill = Paint()..color = ink.withValues(alpha: active ? .25 : .10);
      final edge = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      for (final f in game.fields) {
        switch (f.shape) {
          case FieldShape.disc:
            canvas.drawCircle(f.a, f.radius, fill);
            canvas.drawCircle(f.a, f.radius, edge);
          case FieldShape.ring:
            canvas.drawCircle(
              f.a,
              f.radius,
              Paint()
                ..color = fill.color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 36,
            );
            canvas.drawCircle(f.a, f.radius - 18, edge);
            canvas.drawCircle(f.a, f.radius + 18, edge);
            if (game.worldIndex == 7 && !active) {
              canvas.drawCircle(f.a, 72, edge..color = const Color(0xFF7DE5CA));
              edge.color = ink;
            }
          case FieldShape.beam:
            canvas.drawLine(
              f.a,
              f.b!,
              Paint()
                ..color = fill.color
                ..strokeWidth = f.radius * 2
                ..strokeCap = StrokeCap.round,
            );
            final delta = f.b! - f.a;
            final normal =
                Offset(-delta.dy, delta.dx) / delta.distance * f.radius;
            canvas.drawLine(f.a + normal, f.b! + normal, edge);
            canvas.drawLine(f.a - normal, f.b! - normal, edge);
          case FieldShape.outside:
            final area = Rect.fromLTWH(
              game.camera.dx,
              game.camera.dy,
              420,
              viewHeight,
            );
            canvas.drawPath(
              Path.combine(
                PathOperation.difference,
                Path()..addRect(area),
                Path()..addOval(Rect.fromCircle(center: f.a, radius: f.radius)),
              ),
              fill,
            );
            canvas.drawCircle(
              f.a,
              f.radius,
              edge..color = const Color(0xFF7DE5CA),
            );
            edge.color = ink;
        }
      }
      canvas.restore();
      // Fixed readable cue remains visible after the player leaves the mark.
      final label = TextPainter(
        text: TextSpan(
          text: message("{0} · {1}", [
            active ? "위험" : "예고 ${(13 - game.hazardPhase).ceil()}초",
            game.worldTactic,
          ]),
          style: const TextStyle(
            color: Color(0xFFFFE7A9),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: 396);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(6, 8, 408, label.height + 12),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0xE6192638),
      );
      label.paint(canvas, const Offset(12, 14));
    }
    canvas.translate(-game.camera.dx, -game.camera.dy);
    final visible = Rect.fromLTWH(
      game.camera.dx,
      game.camera.dy,
      420,
      viewHeight,
    ).inflate(80);
    bool onScreen(Offset at, double radius) =>
        visible.inflate(radius).contains(at);
    for (final e in game.enemies.where(
      (e) => e.plane == AircraftTarget.ground,
    )) {
      if (!onScreen(e.position, 65)) continue;
      final pad = RRect.fromRectAndRadius(
        Rect.fromCenter(center: e.position, width: 84, height: 76),
        const Radius.circular(8),
      );
      canvas.drawRRect(pad, Paint()..color = const Color(0xFF263F4A));
      canvas.drawRRect(
        pad,
        Paint()
          ..color = const Color(0xFF789295)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      if (e.tell > 0)
        _beam(
          canvas,
          e.position,
          e.position + e.aim * 170,
          3,
          hostile: true,
          opacity: .55,
        );
      canvas.save();
      canvas.translate(e.position.dx, e.position.dy);
      canvas.rotate(e.heading + math.pi / 2);
      GroundArt.paint(
        canvas,
        e.groundKind,
        Rect.fromCenter(center: Offset.zero, width: 43, height: 43),
      );
      canvas.restore();
      if (e.hp < e.maxHp)
        _gauge(canvas, e.position + const Offset(0, 27), 40, e.hp / e.maxHp);
    }
    const arena = Rect.fromLTWH(
      0,
      0,
      GameEngine.worldWidth,
      GameEngine.worldHeight,
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(visible),
        Path()..addRect(arena),
      ),
      Paint()..color = const Color(0xCC030812),
    );
    _beam(canvas, arena.topLeft, arena.bottomLeft, 6, opacity: .6);
    _beam(canvas, arena.topRight, arena.bottomRight, 6, opacity: .6);
    _beam(canvas, arena.topLeft, arena.topRight, 6, opacity: .6);
    _beam(canvas, arena.bottomLeft, arena.bottomRight, 6, opacity: .6);
    if (game.bossWarning) {
      final at = game.boss!.position, aim = game.bossAim;
      final safe = game.bossPattern == 0;
      if (game.bossPattern == 3) {
        for (final (from, to) in game.bossLaserLanes) {
          _beam(canvas, from, to, 20, hostile: true, opacity: .35);
        }
        _beam(
          canvas,
          game.bossLaserSafeOrigin,
          game.bossLaserSafeOrigin + aim * 420,
          5,
          opacity: .85,
        );
      } else if (game.bossPattern == 4 || game.bossPattern == 5) {
        final artillery = game.bossPattern == 4;
        for (final target
            in artillery ? game.bossArtilleryTargets : game.bossMineTargets) {
          canvas.drawCircle(
            target,
            artillery ? 30 : 22,
            Paint()..color = const Color(0x55FF674B),
          );
          canvas.drawCircle(
            target,
            artillery ? 30 : 22,
            Paint()
              ..color = const Color(0xFFFFB632)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4,
          );
          canvas.drawLine(
            target - const Offset(8, 0),
            target + const Offset(8, 0),
            Paint()
              ..color = const Color(0xFFFFB632)
              ..strokeWidth = 3,
          );
        }
        if (!artillery) {
          _beam(
            canvas,
            game.bossTarget,
            game.bossTarget + game.bossMineExit * 150,
            5,
            opacity: .85,
          );
        }
      } else if (game.bossPattern == 2) {
        _beam(
          canvas,
          at,
          at + aim * (game.bossChargeSpeed * 1.2),
          68,
          hostile: true,
          opacity: .5,
        );
      } else {
        final direction = safe ? game.bossSafeDirection : aim;
        final angle = math.atan2(direction.dy, direction.dx),
            half = safe ? .42 : .53;
        canvas.save();
        canvas.clipPath(
          Path()
            ..moveTo(at.dx, at.dy)
            ..arcTo(
              Rect.fromCircle(center: at, radius: 400),
              angle - half,
              half * 2,
              false,
            )
            ..close(),
        );
        _fx(canvas, safe ? 6 : 12, at, 800, opacity: .28);
        canvas.restore();
        for (final a in [angle - half, angle + half]) {
          _beam(
            canvas,
            at,
            at + Offset(math.cos(a), math.sin(a)) * 400,
            5,
            hostile: !safe,
            opacity: .85,
          );
        }
      }
    }
    if (!game.resolvingBoss) CombatVfx.under(canvas, game, reducedEffects);
    for (final supply in game.supplies) {
      if (!onScreen(supply.position, 20)) continue;
      if (supply.kind >= 7) {
        // v12.4 field drops: bullet / missile power-ups, mid-boss box
        final art = FlightSceneArt.sprite(
          const ['item_bullet', 'item_missile', 'item_elite'][supply.kind - 7],
        );
        final side = supply.kind == 9 ? 54.0 : 40.0;
        final bob = reducedEffects
            ? 0.0
            : math.sin(game.combatTime * 4 + supply.position.dx) * 3;
        if (!reducedEffects) {
          _fx(
            canvas,
            supply.kind == 9 ? 12 : 6,
            supply.position,
            side * 1.9,
            opacity: .35 + .15 * math.sin(game.combatTime * 6),
          );
        }
        if (art != null) {
          canvas.drawImageRect(
            art,
            Rect.fromLTWH(0, 0, art.width.toDouble(), art.height.toDouble()),
            Rect.fromCenter(
              center: supply.position + Offset(0, bob),
              width: side,
              height: side,
            ),
            Paint()..filterQuality = FilterQuality.medium,
          );
        }
        continue;
      }
      RasterAssets.sprite(
        canvas,
        'icons',
        [10, 11, 12, 13, 14, 15, 16][supply.kind],
        supply.position,
        33,
      );
      if (supply.kind >= 4) {
        final label = TextPainter(
          text: TextSpan(
            text: tr(['R', 'P', 'N'][supply.kind - 4]),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              shadows: [Shadow(color: Colors.black, blurRadius: 3)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, supply.position + Offset(-label.width / 2, 12));
      }
    }
    if (game.magnetPulse > 0 && !reducedEffects) {
      _fx(
        canvas,
        6,
        game.position,
        (1.1 - game.magnetPulse) * 720,
        opacity: game.magnetPulse * .55,
      );
    }
    if (game.pilotShield > 0) _fx(canvas, 8, game.position, 53, opacity: .55);
    final field = game.upgrades['forcefield'] ?? 0;
    if (!game.modular && field > 0) {
      _fx(
        canvas,
        8,
        game.position,
        (55 + field * 8) * game.areaFactor * 2,
        opacity: .15,
      );
    }
    if (!game.modular && (game.upgrades['guardian'] ?? 0) > 0) {
      final radius =
          (game.evolved.contains('guardian') ? 95.0 : 62.0) * game.areaFactor;
      for (int i = 0; i < 4; i++) {
        final a = game.combatTime * 3 + i * math.pi / 2;
        RasterAssets.sprite(
          canvas,
          'enemies',
          11,
          game.position + Offset(math.cos(a), math.sin(a)) * radius,
          25,
          rotation: reducedEffects ? 0 : a,
        );
      }
    }
    if (!game.modular && game.guardianShieldActive) {
      _fx(
        canvas,
        8,
        game.position,
        (game.evolved.contains('guardian') ? 95 : 62) *
            game.areaFactor *
            (game.techSpecial('guardian') ? 1.2 : 1) *
            2,
        opacity: .24,
      );
    }
    if (game.ultimateRemaining > 0 &&
        game.moduleLoadout != null &&
        game.shipIndex != 0) {
      final radius = game.shipIndex == 1 ? 100.0 : 220.0;
      CombatVfx.ring(canvas, game.position, radius, CombatVfx.cyan, .6);
    }
    if (game.ultimateRemaining > 0 &&
        (game.moduleLoadout == null || game.shipIndex == 0)) {
      LaserBeam.paint(
        canvas,
        game.modular ? game.moduleMuzzle(AircraftMount.main) : game.position,
        game.position + const Offset(0, -520),
        140,
        age: 2 - game.ultimateRemaining,
        duration: 2,
        reduced: reducedEffects,
      );
    }
    if (game.laserLife > 0) {
      LaserBeam.paint(
        canvas,
        game.laserOrigin,
        game.laserOrigin + const Offset(0, -520),
        game.mainBranch == MainBranch.pulseSpread ? 40 : 22,
        age: .13 - game.laserLife,
        duration: .13,
        reduced: reducedEffects,
      );
    }
    _crystalField(canvas, onScreen);
    ResolutionVfx.absorption(
      canvas,
      game,
      reducedEffects,
      crystal: cacheProjectiles ? _crystal : null,
    );
    for (final shot in game.shots) {
      if (game.unifiedModules && shot.weapon.startsWith('part:')) continue;
      if (shot.kind == 18 ||
          shot.kind == 23 ||
          onScreen(shot.position, shot.radius)) {
        _shot(canvas, shot);
      }
      if (shot.weapon == 'missile-evo' &&
          shot.target != null &&
          shot.target!.hp > 0) {
        _fx(
          canvas,
          13,
          shot.target!.position,
          (shot.target!.radius + 6) * 2,
          opacity: .7,
        );
      }
    }
    _pawWeapons(canvas);
    for (final e in game.enemies) {
      if (e.plane == AircraftTarget.ground) continue;
      if (!onScreen(e.position, e.radius * 2)) continue;
      if (e.formationPattern == FlightFormation.assault) {
        if (e.phase >= 1.25 && e.phase < 2.25 && e.formationOrder < 1) {
          final from = e.formationDestination!, to = e.targetPoint!;
          final delta = to - from;
          final length = delta.distance;
          final direction = delta / length;
          final ink = Paint()
            ..color = const Color(0xFFFFB632)
            ..strokeWidth = 4;
          for (double d = 0; d < length; d += 24) {
            canvas.drawLine(
              from + direction * d,
              from + direction * math.min(d + 12, length),
              ink,
            );
          }
          final marker = from + direction * math.min(100, length);
          final normal = Offset(-direction.dy, direction.dx);
          canvas.drawLine(marker - direction * 16 + normal * 10, marker, ink);
          canvas.drawLine(marker - direction * 16 - normal * 10, marker, ink);
        } else if (e.phase >= 2.25) {
          _beam(
            canvas,
            e.position - e.aim * 28,
            e.position,
            4,
            hostile: true,
            opacity: .45,
          );
        }
      }
      if (e.formationPattern == FlightFormation.bulwark &&
          e.formationOrder > 0 &&
          e.phase >= 1.25 &&
          e.phase < 5.4) {
        final active = game.formationShieldActive(e);
        final angle = math.atan2(e.formationFacing.dy, e.formationFacing.dx);
        canvas.drawArc(
          Rect.fromCircle(center: e.position, radius: e.radius + 10),
          angle - math.pi / 3,
          math.pi * 2 / 3,
          false,
          Paint()
            ..color = active ? const Color(0xFF52E9FF) : const Color(0xFFFFBA54)
            ..style = PaintingStyle.stroke
            ..strokeWidth = active ? 5 : 2,
        );
        if (active) {
          for (final leader in game.enemies.where(
            (g) =>
                g.formationId == e.formationId &&
                g.formationOrder == 0 &&
                g.hp > 0 &&
                !g.retired &&
                (g.position - e.position).distance <= 110,
          )) {
            canvas.drawLine(
              e.position,
              leader.position,
              Paint()
                ..color = const Color(0x7752E9FF)
                ..strokeWidth = 2,
            );
          }
        }
      }
      // the old bulkhead aura; house bosses show their state by other means
      if (e.kind == 3 && !game.screenMode) {
        _fx(
          canvas,
          game.bossExposed ? 13 : 12,
          e.position,
          e.radius * 3.3,
          opacity: .5,
        );
      }
      // v12 telegraphs: ordinary shooters give no aim line (their glowing
      // bullets are the warning). Only lasers show a thin pre-fire line and
      // shells mark where they land with a soft, filling ring.
      if (e.kind != 3 &&
          e.tell > 0 &&
          e.formationPattern != FlightFormation.assault) {
        final weapon = content.enemyDoctrines[e.role]!.weapon;
        final explosive =
            weapon == content.EnemyArmament.highExplosive ||
            weapon == content.EnemyArmament.grenade;
        if (explosive) {
          final range = (game.position - e.position).distance.clamp(
            90.0,
            360.0,
          );
          final radius = weapon == content.EnemyArmament.grenade ? 38.0 : 46.0;
          final fill = (1 - e.tell.clamp(0, 1)).toDouble();
          final at = e.targetPoint ?? (e.position + e.aim * range);
          GlowShots.ring(
            canvas,
            at,
            radius,
            GlowShots.pink,
            width: 2,
            opacity: .45,
          );
          canvas.drawCircle(
            at,
            radius * fill,
            Paint()..color = GlowShots.pink.withValues(alpha: .14),
          );
        } else if (weapon == content.EnemyArmament.laser) {
          GlowShots.beam(
            canvas,
            e.position,
            e.position + e.aim * 460,
            1.6,
            GlowShots.pink,
            opacity: .35,
          );
        }
      }
      if (e.kind == 3 && game.screenMode && game.houseBossShielded) {
        // the fortress core sits inside a shield fed by its generators
        GlowShots.ring(
          canvas,
          e.position,
          e.radius * 1.12,
          GlowShots.cyan,
          width: 3,
          opacity: .55 + math.sin(game.combatTime * 6) * .2,
        );
        for (final part in game.bossParts.where((p) => p.partKind == 2)) {
          GlowShots.lightning(
            canvas,
            part.position,
            e.position,
            1.6,
            GlowShots.cyan,
            (game.combatTime * 12).floor() + part.mount.dx.round(),
            opacity: .6,
          );
        }
      }
      // house bosses with their own bodies: 3 barrage, 4 duelist
      final houseBody =
          e.kind == 3 &&
              game.screenMode &&
              game.houseBossKind != HouseBossKind.fortress
          ? (game.houseBossKind == HouseBossKind.barrage ? 3 : 4)
          : 0;
      final artKind = e.partKind > 0 ? e.partKind : houseBody;
      final partArt = artKind > 0 ? FlightSceneArt.partArt(artKind) : null;
      if (partArt != null) {
        final side =
            e.radius *
            (houseBody == 3
                ? 3.4
                : houseBody == 4
                ? 3.0
                : 2.7);
        canvas.save();
        canvas.translate(e.position.dx, e.position.dy);
        if (e.partKind == 1) {
          canvas.rotate(math.atan2(e.aim.dy, e.aim.dx) - math.pi / 2);
        } else if (houseBody == 3) {
          // the sprinkler wheel turns with its spiral
          canvas.rotate(game.houseBossSpin);
        } else if (houseBody == 4) {
          final to = game.position - e.position;
          canvas.rotate(math.atan2(to.dy, to.dx) + math.pi / 2);
        }
        canvas.drawImageRect(
          partArt,
          Rect.fromLTWH(
            0,
            0,
            partArt.width.toDouble(),
            partArt.height.toDouble(),
          ),
          Rect.fromCenter(center: Offset.zero, width: side, height: side),
          Paint()..filterQuality = FilterQuality.medium,
        );
        canvas.restore();
        if (houseBody == 0 && e.hp < e.maxHp) {
          canvas.drawRect(
            Rect.fromLTWH(
              e.position.dx - e.radius,
              e.position.dy + e.radius + 4,
              e.radius * 2 * (e.hp / e.maxHp).clamp(0.0, 1.0),
              4,
            ),
            Paint()..color = const Color(0xFFFF6F7D),
          );
        }
        continue;
      }
      canvas.save();
      canvas.translate(e.position.dx, e.position.dy);
      canvas.rotate(
        e.kind == 3 &&
                game.screenMode &&
                game.houseBossKind == HouseBossKind.fortress
            ? math.pi
            : e.kind == 3
            ? math.atan2(
                    game.position.dy - e.position.dy,
                    game.position.dx - e.position.dx,
                  ) +
                  math.pi / 2
            : e.heading + math.pi / 2,
      );
      if (e.kind == 3) {
        WorldArt.boss(canvas, e, game.worldIndex, game.combatTime);
      } else {
        WorldArt.enemy(
          canvas,
          e,
          game.stage.world.color,
          game.worldIndex,
          // house-stage formation planes are drawn well beyond their hitbox
          // so they read clearly (v12.4.2 user: small planes too small);
          // heavies a little less, the mid-boss keeps its own scale
          scale: !game.screenMode || e.elite
              ? 2.7
              : e.kind >= 2
              ? 3.0
              : 3.6,
        );
      }
      canvas.restore();
      if (e.elite) {
        // mid-boss: always-on wide health bar with its title
        _gauge(
          canvas,
          e.position - Offset(0, e.radius + 12),
          e.radius * 2.6,
          e.hp / e.maxHp,
        );
        final title = TextPainter(
          text: TextSpan(
            text: tr('중간 보스'),
            style: const TextStyle(
              color: Color(0xFFFFE08A),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black, blurRadius: 3)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        title.paint(
          canvas,
          e.position - Offset(title.width / 2, e.radius + 30),
        );
      } else if (e.kind >= 2 && e.hp < e.maxHp) {
        _gauge(
          canvas,
          e.position - Offset(0, e.radius + 9),
          e.radius * 2,
          e.hp / e.maxHp,
        );
      }
    }
    ResolutionVfx.boss(canvas, game, reducedEffects);
    if (!game.modular &&
        !game.resolvingBoss &&
        (game.upgrades['drone'] ?? 0) > 0) {
      final at =
          game.position +
          Offset(math.cos(game.elapsed * 2), math.sin(game.elapsed * 2)) * 34;
      if (!reducedEffects) CombatVfx.ring(canvas, at, 16, CombatVfx.cyan, .4);
      RasterAssets.sprite(canvas, 'projectiles', 22, at, 27);
    }
    if (!game.resolvingBoss && game.petKind >= 0 && game.petLevel > 0) {
      ToonAssets.sprite(
        canvas,
        'ships',
        3 + game.petKind.clamp(0, 2),
        game.petPosition,
        46,
        opacity: game.petHp <= 0 ? .4 : 1,
      );
      _gauge(
        canvas,
        game.petPosition + const Offset(0, 23),
        36,
        game.petHp <= 0 ? game.petRevive / 8 : game.petHp / 100,
      );
    }
    if (game.screenMode) {
      // the cloud veil passes over the field but under the cat
      canvas.save();
      canvas.translate(game.camera.dx, game.camera.dy);
      FlightSceneArt.paintCloudVeil(
        canvas,
        Size(420, viewHeight),
        game.cloudCover,
        game.atmosphereTime,
      );
      canvas.restore();
    }
    canvas.save();
    final hero = ResolutionVfx.heroPosition(game);
    canvas.translate(hero.dx, hero.dy);
    canvas.scale(AircraftGeometry.combatScale);
    if (game.resolvingBoss) {
      final thrust = 18 + (game.bossResolution?.departure ?? 0) * 80;
      for (final x in [-17.0, 17.0]) {
        _beam(canvas, Offset(x, 23), Offset(x, 23 + thrust), 7, opacity: .8);
      }
    }
    if (hideHero) {
      // the sortie intro is still flying the craft in
    } else if (game.moduleLoadout != null && ShipSpriteArt.ready) {
      // Authored cat airframe (ship assembly editor). The canvas is already
      // at combat scale, so one ship-canvas unit is shipCombatSide / scale.
      ShipSpriteArt.paint(
        canvas,
        ShipSpriteArt.shipFor(game.shipIndex),
        Offset.zero,
        shipCombatSide / AircraftGeometry.combatScale,
        time: game.combatTime,
        hidden: ShipSpriteArt.hiddenFor(game.moduleLoadout),
        assets: ShipSpriteArt.battleAssets,
        // v12.9.4: the craft rolls into turns; flames stretch going forward
        bank: reducedEffects ? 0 : game.bank,
        flameScale: reducedEffects
            ? 1
            : 1 +
                  .6 * math.max(0, game.thrust) -
                  .3 * math.max(0, -game.thrust),
      );
    } else if (game.moduleLoadout != null) {
      ModuleAircraftArt.paint(
        canvas,
        Offset.zero,
        AircraftGeometry.bodySize,
        game.moduleLoadout!,
        inBattle: true,
        angles: {'W4': game.moduleVisualAngle('W4')},
        recoil: reducedEffects
            ? const {}
            : {
                for (final m in moduleProfiles.where((m) => m.weapon))
                  m.id:
                      game.modulePartVisualOffset(m.id, 0) /
                      AircraftGeometry.combatBodySize,
              },
        sideRecoil: reducedEffects
            ? const {}
            : {
                for (var i = 0; i < 2; i++)
                  'W1:$i':
                      game.modulePartVisualOffset('W1', i) /
                      AircraftGeometry.combatBodySize,
              },
      );
    } else if (game.aircraft != null) {
      AircraftAssemblyArt.paintAssembly(
        canvas,
        Offset.zero,
        AircraftGeometry.bodySize,
        game.aircraft!,
        drift: reducedEffects
            ? const {}
            : {
                for (final mount in AircraftMount.values)
                  mount:
                      game.visuals.followOffset(mount.name) /
                      AircraftGeometry.combatScale,
              },
        gearDrift: reducedEffects
            ? const {}
            : {
                for (final pair in const [
                  (1, 'sensor'),
                  (2, 'core'),
                  (4, 'belt'),
                  (5, 'thruster'),
                ])
                  pair.$1:
                      game.visuals.followOffset(pair.$2) /
                      AircraftGeometry.combatScale,
              },
        angles: {
          AircraftMount.auxiliary: game.moduleAngle(AircraftMount.auxiliary),
          AircraftMount.wings: game.moduleAngle(AircraftMount.wings),
          AircraftMount.rear: 0,
        },
        rightWingAngle: game.moduleAngle(AircraftMount.wings, right: true),
        recoil: reducedEffects
            ? const {}
            : {
                for (final mount in [
                  AircraftMount.main,
                  AircraftMount.auxiliary,
                  AircraftMount.wings,
                  AircraftMount.rear,
                  AircraftMount.ground,
                ])
                  mount: game.visuals.recoil(mount.name),
              },
        rightWingRecoil: reducedEffects
            ? Offset.zero
            : game.visuals.recoil('wings-right'),
      );
    } else {
      ArcadeAircraft.paintShip(canvas, Offset.zero, 76, game.shipIndex);
    }
    if (game.moduleShield > 0) _fx(canvas, 8, Offset.zero, 70, opacity: .3);
    if (game.hurtFlash > 0) {
      _fx(canvas, 15, Offset.zero, 48, opacity: game.hurtFlash * .65);
    }
    canvas.restore();
    _wingTurrets(canvas);
    if (game.moduleLoadout != null) {
      for (final e in game.moduleLoadout!.parts.entries) {
        if (e.value.definition.category != PartCategory.drone) continue;
        final points = game.droneFormation(
          e.key,
          e.value,
          game.partStats(e.key).count,
        );
        for (var i = 0; i < points.length; i++) {
          if (game.droneHealth(e.key, i) <= 0) continue;
          final at =
              points[i] +
              (reducedEffects ? Offset.zero : game.droneVisualOffset(e.key, i));
          canvas.save();
          canvas.translate(at.dx, at.dy);
          canvas.rotate(game.droneVisualAngle(e.key, e.value, i, points[i]));
          // v11: the drone is a PNG sprite (no code-drawn shapes).
          if (!ShipSpriteArt.paintDrone(canvas, 30)) {
            canvas.scale(ModuleGeometry.droneExtent);
            ModuleAircraftArt.paintPart(canvas, e.value.definition);
          }
          canvas.restore();
          _gauge(
            canvas,
            at + const Offset(0, 12),
            20,
            (game.droneHealth(e.key, i) / game.partStats(e.key).droneHealth)
                .clamp(0, 1),
          );
        }
      }
      // Belly/top guns start inside the hull silhouette. Keep their real first
      // flight pixels visible instead of hiding the muzzle under the airframe.
      for (final shot in game.shots) {
        if (shot.weapon.startsWith('part:') &&
            onScreen(shot.position, shot.radius)) {
          _shot(canvas, shot);
        }
      }
    }
    if (!reducedEffects) {
      int drawn = 0;
      for (final p in game.sparks) {
        if (!onScreen(p.position, 16)) continue;
        if (++drawn > 96) break;
        if (p.kind == 2 || (p.kind == 0 && drawn % 6 == 0)) {
          final frame = ((1 - p.life.clamp(0, 1)) * 4).floor().clamp(0, 3);
          _fx(
            canvas,
            frame,
            p.position,
            p.kind == 2 ? 72 : 28,
            opacity: p.life.clamp(0, 1) * .55,
          );
        }
        _fx(
          canvas,
          p.kind == 0 ? 0 : 4,
          p.position,
          7 + p.life * 12,
          opacity: p.life.clamp(0, 1) * .8,
        );
      }
    }
    CombatVfx.over(canvas, game, reducedEffects);
    ResolutionVfx.flash(canvas, game, reducedEffects);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BattlePainter oldDelegate) => true;
}
