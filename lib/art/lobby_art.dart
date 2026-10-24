import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'menu_art.dart';

/// v9 menu icons that refit_v16 does not replace (mission, radar, guild,
/// coin, blueprint, key). Entries already decoded by [RefitArt] are skipped.
abstract final class LobbyArt {
  static const root = 'assets/art/lobby_v9/';
  static Future<void>? _loading;
  static Future<void> load() => _loading ??= _load();
  static Future<void> _load() async {
    final map =
        jsonDecode(await rootBundle.loadString('${root}manifest.json')) as Map;
    await Future.wait(
      map.entries.map((entry) async {
        // Replacement art is already decoded; do not fetch both generations.
        if (MenuArt.images.containsKey('lobby/${entry.key}')) return;
        final meta = entry.value as Map;
        final bytes = await rootBundle.load('$root${entry.key}.webp');
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
          targetWidth: meta['background'] == true ? 768 : 512,
        );
        final key = 'lobby/${entry.key}';
        MenuArt.images[key] = (await codec.getNextFrame()).image;
        codec.dispose();
        final b = (meta['bounds'] as List).cast<num>();
        MenuArt.bounds[key] = Rect.fromLTRB(
          b[0].toDouble(),
          b[1].toDouble(),
          b[2].toDouble(),
          b[3].toDouble(),
        );
      }),
    );
  }

  static String ship(int index) =>
      const ['hero', 'vector', 'monolith'][index.clamp(0, 2)];
}

/// All lobby illustrations use the same independent PNGs and alpha-safe renderer.
class LobbyIcon extends StatelessWidget {
  const LobbyIcon(this.icon, {super.key, this.size = 40});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) {
    final name = <IconData, String>{
      Icons.assignment_turned_in: 'mission',
      Icons.card_giftcard: 'chest',
      Icons.explore: 'radar',
      Icons.groups: 'guild',
      Icons.storefront: 'chest',
      Icons.build: 'growth',
      Icons.rocket_launch: 'hero',
      Icons.emoji_events: 'challenge',
      Icons.account_tree: 'research',
      Icons.hexagon: 'coin',
      Icons.description: 'blueprint',
      Icons.vpn_key: 'key',
      Icons.person: 'hero',
    }[icon];
    return name == null
        ? Icon(icon, size: size)
        : MenuImage('lobby/$name', size: size);
  }
}
