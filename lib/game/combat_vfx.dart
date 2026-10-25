import '../l10n/app_language.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'combat_cues.dart';
import 'engine.dart';

/// Layered motion over the shared raster art. All positions are world positions.
/// No blur/saveLayer or random sampling in the per-frame path.
abstract final class CombatVfx {
  static const cyan = Color(0xFF65E7FF), gold = Color(0xFFFFCA61);
  static Color color(String source) {
    if (source.contains('fire') ||
        source.contains('inferno') ||
        source.contains('trail'))
      return const Color(0xFFFF9855);
    if (source.contains('frost') ||
        source.contains('ice') ||
        source.contains('laser'))
      return cyan;
    if (source.contains('poison') ||
        source.contains('heal') ||
        source.contains('repair'))
      return const Color(0xFF95F7AB);
    if (source.contains('void') ||
        source.contains('soul') ||
        source.contains('disorder'))
      return const Color(0xFFD3A6FF);
    if (source.contains('missile') ||
        source.contains('mine') ||
        source.contains('shotgun') ||
        source.contains('bomb'))
      return gold;
    return cyan;
  }

  static Paint ink(Color color, double alpha, [double width = 2]) => Paint()
    ..color = color.withValues(alpha: alpha.clamp(0, 1))
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;
  static void ring(
    Canvas c,
    Offset at,
    double r,
    Color color,
    double alpha, {
    double width = 2,
  }) {
    if (r > 0) c.drawCircle(at, r, ink(color, alpha, width));
  }

  static void _jet(Canvas c, Offset at, double time, {double scale = 1}) {
    final length = (16 + 6 * math.sin(time * 38)) * scale;
    final p = Path()
      ..moveTo(at.dx - 4 * scale, at.dy)
      ..quadraticBezierTo(
        at.dx - 7 * scale,
        at.dy + length * .6,
        at.dx,
        at.dy + length,
      )
      ..quadraticBezierTo(
        at.dx + 7 * scale,
        at.dy + length * .6,
        at.dx + 4 * scale,
        at.dy,
      )
      ..close();
    c.drawPath(p, Paint()..color = const Color(0xCC38CBE8));
    c.drawLine(
      at,
      at + Offset(0, length * .7),
      ink(const Color(0xFFFFF7DD), .95, 3 * scale),
    );
  }

  static void under(Canvas c, GameEngine g, bool reduced) {
    final t = reduced ? 0.0 : g.combatTime;
    if (!reduced) {
      // v12.9.5 (user 2026-10-25): the cat's craft shows only its painted
      // flame art; the old code-drawn jets under it are gone.
      for (final e in g.enemies) {
        if ((e.position - g.position).distance > 650 || e.kind == 3) continue;
        c.save();
        c.translate(e.position.dx, e.position.dy);
        c.rotate(e.heading - math.pi / 2);
        _jet(c, const Offset(0, -14), t + e.phase, scale: .5);
        c.restore();
      }
    }
    final shield = g.guardianShieldActive || g.pilotShield > 0;
    if (shield) {
      final r = g.guardianShieldActive
          ? (g.evolved.contains('guardian') ? 95.0 : 62.0) * g.areaFactor
          : 42.0;
      for (var i = 0; i < 3; i++) {
        c.drawArc(
          Rect.fromCircle(center: g.position, radius: r),
          t + i * math.pi * 2 / 3,
          math.pi * .42,
          false,
          ink(cyan, .7, 3),
        );
      }
    }
    if (g.ultimateRemaining > 0) {
      final origin = g.position + const Offset(0, -25);
      ring(c, origin, 30 + 5 * math.sin(t * 22), gold, .9, width: 4);
      if (!reduced)
        for (var i = 0; i < 8; i++) {
          final y = (t * 390 + i * 65) % 520;
          c.drawLine(
            origin + Offset(-55, -y),
            origin + Offset(55, -y - 18),
            ink(cyan, .4, 2),
          );
        }
    }
    if (g.shieldCounterPending)
      ring(c, g.position, 40 + 4 * math.sin(t * 12), gold, .95, width: 3);
    if (g.pilotBuff > 0) ring(c, g.position, 34, color(g.pilot), .5);
    // Item silhouettes remain still enough to identify; beacon rings breathe.
    for (final s in g.supplies) {
      final r = 19.0 + (reduced ? 0.0 : 3 * math.sin(t * 4 + s.kind));
      ring(c, s.position, r, s.kind == 0 ? const Color(0xFF95F7AB) : gold, .6);
      if (!reduced)
        c.drawLine(
          s.position + Offset(0, -r - 6),
          s.position + Offset(0, -r - 13),
          ink(gold, .7, 3),
        );
    }
    if (!reduced) {
      var i = 0;
      for (final x in g.crystals) {
        if (++i > 120) break;
        final delta = g.position - x;
        if (delta.distance < g.collectionRadius && delta.distance > 18) {
          c.drawLine(x, x - delta / delta.distance * 8, ink(cyan, .3, 2));
        }
      }
    }
  }

  static void projectile(Canvas c, Shot s, bool reduced) {
    if (reduced || s.velocity.distance < 10 || s.kind == 18 || s.kind == 23)
      return;
    final direction = s.velocity / s.velocity.distance;
    final explosive = s.kind == 1 || s.kind == 9 || s.kind == 20;
    final tint = s.hostile ? const Color(0xFFFF9778) : color(s.weapon);
    final length = explosive ? 30.0 : 14.0;
    c.drawLine(
      s.position - direction * 4,
      s.position - direction * length,
      ink(tint, .22, explosive ? 7 : 4),
    );
    c.drawLine(
      s.position - direction * 4,
      s.position - direction * (length * .7),
      ink(tint, .7, 2),
    );
    if (explosive)
      c.drawCircle(
        s.position - direction * 10,
        3 + math.sin(s.age * 45),
        Paint()..color = gold.withValues(alpha: .7),
      );
  }

  static void over(Canvas c, GameEngine g, bool reduced) {
    var numbers = 0;
    for (final v in g.visuals.active) {
      final t = v.progress, fade = 1 - t, at = v.at, col = color(v.source);
      switch (v.kind) {
        case CombatCueKind.muzzle:
          if (reduced) continue;
          if (g.unifiedModules &&
              (v.source.startsWith('part:') || v.source == 'module-main')) {
            final delta = at - (v.from ?? at + const Offset(0, 1));
            final direction = delta.distance > .001
                ? delta / delta.distance
                : const Offset(0, -1);
            final normal = Offset(-direction.dy, direction.dx);
            final size = v.source.contains('missile') ? 9.0 : 6.0;
            final tip = at + direction * (size * (1 - t * .6));
            c.drawPath(
              Path()
                ..moveTo(at.dx, at.dy)
                ..lineTo(
                  (at + normal * size * .35).dx,
                  (at + normal * size * .35).dy,
                )
                ..lineTo(tip.dx, tip.dy)
                ..lineTo(
                  (at - normal * size * .35).dx,
                  (at - normal * size * .35).dy,
                )
                ..close(),
              Paint()..color = const Color(0xFFFFE69C).withValues(alpha: fade),
            );
            c.drawLine(at, tip, ink(Colors.white, fade, 2));
            continue;
          }
          final r = 7 + 12 * t;
          final p = at + const Offset(0, -30);
          c.drawOval(
            Rect.fromCenter(center: p, width: r * 1.5, height: r * 2.2),
            Paint()..color = col.withValues(alpha: fade * .75),
          );
          c.drawLine(
            p + Offset(0, 4),
            p - Offset(0, r),
            ink(Colors.white, fade, 3),
          );
        case CombatCueKind.impact:
          if (v.source == 'hit') {
            ring(c, at, 22 + 24 * t, const Color(0xFFFF8D77), fade, width: 3);
          } else {
            final r = 5 + 13 * t;
            if (!reduced)
              for (var i = 0; i < 4; i++) {
                final a = i * math.pi / 2 + .4;
                final d = Offset(math.cos(a), math.sin(a));
                c.drawLine(at + d * r * .35, at + d * r, ink(col, fade, 2));
              }
            if (v.amount >= 1 && numbers++ < (reduced ? 3 : 14)) {
              _label(
                c,
                v.amount >= 1000
                    ? '${(v.amount / 1000).toStringAsFixed(1)}K'
                    : '${v.amount.round()}',
                at - Offset(0, 16 + t * 25),
                fade,
                col,
                size: 14,
              );
            }
          }
        case CombatCueKind.lightning:
          final start = v.from ?? at, delta = at - start;
          final normal = delta.distance > 0
              ? Offset(-delta.dy, delta.dx) / delta.distance
              : Offset.zero;
          final p = Path()..moveTo(start.dx, start.dy);
          for (var i = 1; i <= 7; i++) {
            final q =
                start +
                delta * (i / 7) +
                normal * (i == 7 ? 0 : math.sin(i * 7 + v.age * 70) * 11);
            p.lineTo(q.dx, q.dy);
          }
          c.drawPath(p, ink(cyan, fade * .4, 8));
          c.drawPath(p, ink(Colors.white, fade, 2));
          ring(c, at, 10 + 18 * t, cyan, fade);
        case CombatCueKind.explosion:
        case CombatCueKind.bossExplosion:
          final big = v.kind == CombatCueKind.bossExplosion;
          final r = v.radius * (.15 + .85 * math.sin(t * math.pi / 2));
          c.drawCircle(
            at,
            r * .55,
            Paint()..color = gold.withValues(alpha: fade * fade * .35),
          );
          ring(c, at, r, gold, fade, width: big ? 5 : 2);
          if (!reduced)
            for (var i = 0; i < (big ? 14 : 6); i++) {
              final a = i * math.pi * 2 / (big ? 14 : 6);
              final d = Offset(math.cos(a), math.sin(a));
              c.drawLine(
                at + d * r * .65,
                at + d * (r + 8 * fade),
                ink(i.isEven ? gold : const Color(0xFFFF9855), fade, 3),
              );
            }
        case CombatCueKind.area:
          ring(c, at, v.radius * (.7 + .3 * t), col, fade * .45, width: 3);
        case CombatCueKind.shield:
          ring(c, at, v.radius * (.9 + .3 * t), cyan, fade, width: 3);
          if (!reduced) _hex(c, at, v.radius, cyan, fade * .5);
        case CombatCueKind.pickup:
          ring(c, at, 8 + v.radius * .45 * t, cyan, fade * .65);
        case CombatCueKind.heal:
          final green = color('heal');
          ring(c, at, 24 + v.radius * t, green, fade);
          for (var i = 0; i < 3; i++) {
            final p = at + Offset((i - 1) * 22.0, -15 - t * 35 - i * 9);
            c.drawLine(
              p - const Offset(4, 0),
              p + const Offset(4, 0),
              ink(green, fade, 3),
            );
            c.drawLine(
              p - const Offset(0, 4),
              p + const Offset(0, 4),
              ink(green, fade, 3),
            );
          }
        case CombatCueKind.magnet:
          ring(c, at, 20 + 250 * fade, cyan, t * .5, width: 3);
        case CombatCueKind.bomb:
          ring(c, at, 20 + v.radius * t, gold, fade, width: 5);
        case CombatCueKind.level:
        case CombatCueKind.evolution:
        case CombatCueKind.synergy:
        case CombatCueKind.ultimate:
        case CombatCueKind.pilot:
        case CombatCueKind.bossPhase:
        case CombatCueKind.victory:
        case CombatCueKind.defeat:
          final boss = v.kind == CombatCueKind.bossPhase;
          final tone = boss && v.source != 'open'
              ? const Color(0xFFFF9D7B)
              : v.kind == CombatCueKind.evolution
              ? const Color(0xFFE1BBFF)
              : gold;
          ring(c, at, 18 + v.radius * t, tone, fade * .8, width: 3);
          if (!reduced) _hex(c, at, 15 + v.radius * t * .7, tone, fade * .4);
          final text = switch (v.kind) {
            CombatCueKind.evolution => 'EVOLUTION',
            CombatCueKind.level => 'LEVEL UP',
            CombatCueKind.synergy => 'SYNERGY',
            CombatCueKind.ultimate => '항성포',
            CombatCueKind.victory => '항로 확보',
            CombatCueKind.defeat => '비행 종료',
            CombatCueKind.pilot => '능력 발동',
            _ => v.source == 'open' ? 'CORE OPEN' : 'PHASE',
          };
          _label(c, text, at - Offset(0, 55 + t * 12), fade, tone);
      }
    }
  }

  static void _hex(Canvas c, Offset at, double r, Color color, double alpha) {
    final p = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3, v = at + Offset(math.cos(a), math.sin(a)) * r;
      if (i == 0) {
        p.moveTo(v.dx, v.dy);
      } else {
        p.lineTo(v.dx, v.dy);
      }
    }
    p.close();
    c.drawPath(p, ink(color, alpha));
  }

  static void _label(
    Canvas c,
    String text,
    Offset at,
    double alpha,
    Color color, {
    double size = 18,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: tr(text),
        style: TextStyle(
          fontFamily: 'NotoSansKR',
          fontSize: size,
          fontWeight: FontWeight.w900,
          color: color.withValues(alpha: alpha),
          shadows: const [
            Shadow(color: Color(0xFF091421), offset: Offset(0, 2)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(c, at - Offset(painter.width / 2, painter.height / 2));
  }
}
