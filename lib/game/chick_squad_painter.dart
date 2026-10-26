import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/menu_art.dart';
import '../art/raster_assets.dart';
import 'engine.dart';
import 'glow_shots.dart';

/// v12.17 chick tail squad on the field (chick_squad.dart): frost trail and
/// egg bombs under everything, lightning links, the tail chicks with small
/// HP bars, chicks waiting on a cloud parachute with an SOS flag, the rescue
/// donut and tether line, and the cheeping fall-off.
abstract final class ChickSquadPainter {
  static const _size = 40.0;

  static void paint(Canvas canvas, GameEngine game, {bool reduced = false}) {
    final s = game.squad;
    if (s.chicks.isEmpty) return;
    final t = game.combatTime;
    // ice chick: fading frost under the trail
    for (final f in s.frost) {
      canvas.drawCircle(
        f.at,
        14,
        Paint()
          ..color = const Color(0xFFBFF4FF)
              .withValues(alpha: (f.life / 3).clamp(0, 1) * .35),
      );
    }
    // bomb chick: eggs about to burst
    for (final egg in s.eggs) {
      final pulse = 1.0 + (reduced ? 0 : math.sin(t * 30) * .08);
      canvas.drawOval(
        Rect.fromCenter(center: egg.at, width: 13 * pulse, height: 16 * pulse),
        Paint()..color = const Color(0xFFFFF4E0),
      );
      canvas.drawOval(
        Rect.fromCenter(center: egg.at, width: 13 * pulse, height: 16 * pulse),
        Paint()
          ..color = const Color(0xFF3A2410)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    // lightning chick: crackling links ahead and behind
    for (final c in s.tail) {
      if (c.kind != ChickKind.lightning) continue;
      for (final (from, to) in game.chickLinks(c)) {
        GlowShots.lightning(
          canvas,
          from,
          to,
          2.2,
          GlowShots.gold,
          (t * 14).floor() + c.kind,
          opacity: .85,
        );
      }
    }
    // the tail, back to front so the leader sits on top
    for (final c in s.tail.reversed) {
      _chick(canvas, c, 1);
      _hpBar(canvas, c);
    }
    for (final c in s.chicks) {
      if (c.state == ChickState.waiting) _waiting(canvas, game, c, reduced);
      if (c.state == ChickState.falling) _falling(canvas, c, reduced);
    }
  }

  static void _chick(
    Canvas canvas,
    Chick c,
    double opacity, {
    double turn = 0,
    double scale = 1,
  }) {
    canvas.save();
    canvas.translate(c.position.dx, c.position.dy);
    if (turn != 0) canvas.rotate(turn);
    MenuArt.paint(
      canvas,
      'pet-${c.kind.clamp(0, ChickKind.count - 1)}',
      Rect.fromCenter(
        center: Offset.zero,
        width: _size * scale,
        height: _size * scale,
      ),
      opacity: opacity,
    );
    canvas.restore();
  }

  static void _hpBar(Canvas canvas, Chick c) {
    final at = c.position + const Offset(0, _size / 2 + 2);
    const width = 30.0;
    RasterAssets.panel(
      canvas,
      4,
      Rect.fromLTWH(at.dx - width / 2, at.dy, width, 4),
      border: 1,
    );
    RasterAssets.panel(
      canvas,
      2,
      Rect.fromLTWH(
        at.dx - width / 2,
        at.dy,
        width * (c.hp / c.maxHp).clamp(0, 1),
        4,
      ),
      border: 1,
    );
  }

  static void _waiting(Canvas canvas, GameEngine game, Chick c, bool reduced) {
    final t = game.combatTime;
    final bob = reduced ? 0.0 : math.sin(t * 2.4 + c.kind) * 4;
    final at = c.position + Offset(0, bob);
    // the cloud parachute (its strings meet just above the chick)
    MenuArt.paint(
      canvas,
      'chick-chute',
      Rect.fromCenter(center: at + const Offset(0, -36), width: 46, height: 42),
    );
    // the tether line and the donut gauge while the craft is in reach
    if (c.inReach) {
      canvas.drawLine(
        game.position,
        at,
        Paint()
          ..color = const Color(0xCCFFE07A)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.save();
    canvas.translate(at.dx, at.dy);
    // waving gently while it waits
    final wave = reduced ? 0.0 : math.sin(t * 5 + c.kind) * .12;
    canvas.rotate(wave);
    MenuArt.paint(
      canvas,
      'pet-${c.kind.clamp(0, ChickKind.count - 1)}',
      Rect.fromCenter(center: Offset.zero, width: _size, height: _size),
    );
    canvas.restore();
    // SOS flag beside it
    final flag = at + const Offset(20, -8);
    canvas.save();
    canvas.translate(flag.dx, flag.dy);
    canvas.rotate(reduced ? 0 : math.sin(t * 6 + c.kind) * .25);
    MenuArt.paint(
      canvas,
      'chick-sos',
      Rect.fromCenter(center: Offset.zero, width: 22, height: 22),
    );
    canvas.restore();
    if (c.inReach || c.rescue > 0) {
      final ring = Rect.fromCircle(center: at, radius: 27);
      canvas.drawArc(
        ring,
        0,
        math.pi * 2,
        false,
        Paint()
          ..color = const Color(0x660B1830)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );
      canvas.drawArc(
        ring,
        -math.pi / 2,
        math.pi * 2 * c.rescue,
        false,
        Paint()
          ..color = c.inReach
              ? const Color(0xFFFFD447)
              : const Color(0x99FFD447)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 6,
      );
    }
  }

  /// Spins off the chain with a cheep and a puff of feathers.
  static void _falling(Canvas canvas, Chick c, bool reduced) {
    final k = (c.fall / 1.1).clamp(0.0, 1.0);
    _chick(canvas, c, 1, turn: reduced ? 0 : c.spin, scale: 1 - .15 * k);
    if (k < .7) {
      MenuArt.paint(
        canvas,
        'chick-feathers',
        Rect.fromCenter(
          center: c.position + const Offset(0, -6),
          width: 34 + 30 * k,
          height: 34 + 30 * k,
        ),
        opacity: 1 - k / .7,
      );
    }
    if (k < .85) _bubble(canvas, c.position + const Offset(0, -34), 1 - k);
  }

  static final _cheep = TextPainter(
    text: const TextSpan(
      text: '삐약!',
      style: TextStyle(
        fontFamily: 'NotoSansKR',
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: Color(0xFF3A2410),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  static void _bubble(Canvas canvas, Offset at, double opacity) {
    final box = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: at,
        width: _cheep.width + 14,
        height: _cheep.height + 6,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      box,
      Paint()..color = const Color(0xFFFFF3D6).withValues(alpha: opacity),
    );
    canvas.drawRRect(
      box,
      Paint()
        ..color = const Color(0xFF3A2410).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (opacity > .5) {
      _cheep.paint(canvas, at - Offset(_cheep.width / 2, _cheep.height / 2));
    }
  }
}
