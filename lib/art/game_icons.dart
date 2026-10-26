import 'package:flutter/material.dart';

/// v12.15 (user 2026-10-26): every item, currency and symbol picture in one
/// place, current cat-kit art only. Screens ask for a picture by meaning
/// (`GameIcons.coin`) or by the Material symbol they used to draw
/// ([forIcon]); nothing here points at the removed v9/v10/v16/v52 folders.
abstract final class GameIcons {
  static const _v14 = 'assets/art/icons_v14/';
  static const _kit = 'assets/art/ui_v13/';
  static const _menu = 'assets/art/menu_v13/';

  // currencies and tickets
  static const churu = 'assets/art/icons_v11/churu.webp';
  static const stardust = 'assets/art/icons_v11/stardust.webp';
  static const gearTicket = '${_menu}gear_ticket.webp';
  static const techTicket = 'assets/art/icons_v11/blueprint.webp';
  static const petTicket = 'assets/art/icons_v11/egg.webp';
  static const collectTicket = '${_v14}collect_crate.webp';
  static const food = '${_kit}act_feed.webp';
  static const coin = '${_v14}coin.webp';
  static const key = '${_v14}key.webp';
  static const token = '${_v14}token.webp';
  static const gene = '${_v14}gene.webp';
  static const relicDust = '${_v14}relic_dust.webp';
  static const exploreTicket = '${_v14}explore_ticket.webp';
  static const season = '${_v14}season.webp';

  // boxes and rewards
  static const chest = '${_menu}supply.webp';
  static const bossChest = 'assets/art/icons_v12/item_elite.webp';
  static const calendar = '${_v14}calendar.webp';

  // battle drops and stats
  static const heal = '${_v14}heal.webp';
  static const magnet = '${_v14}magnet.webp';

  /// The field magnet drop: a classic horseshoe (v12.17).
  static const magnetDrop = '${_v14}magnet_drop.webp';
  static const bomb = '${_v14}bomb.webp';
  static const heart = '${_kit}act_heart.webp';
  static const shield = '${_v14}shield.webp';
  static const bolt = '${_v14}bolt.webp';
  static const gem = '${_v14}gem.webp';
  static const speed = '${_v14}speed.webp';
  static const hourglass = '${_v14}hourglass.webp';
  static const crosshair = '${_v14}crosshair.webp';
  static const missile = 'assets/art/houses_v12/missile_fish.webp';
  static const chick = '${_v14}chick.webp';
  static const launch = '${_menu}launch.webp';

  // controls and symbols
  static const codex = '${_v14}codex.webp';
  static const fastForward = '${_v14}fast_forward.webp';
  static const pause = '${_v14}pause.webp';
  static const refresh = '${_v14}refresh.webp';
  static const rotate = '${_v14}rotate.webp';
  static const settings = '${_kit}icon_settings.webp';
  static const lock = '${_kit}act_lock.webp';
  static const check = '${_kit}act_check.webp';

  static const all = [
    churu,
    stardust,
    gearTicket,
    techTicket,
    petTicket,
    collectTicket,
    food,
    coin,
    key,
    token,
    gene,
    relicDust,
    exploreTicket,
    season,
    chest,
    bossChest,
    calendar,
    heal,
    magnet,
    magnetDrop,
    bomb,
    heart,
    shield,
    bolt,
    gem,
    speed,
    hourglass,
    crosshair,
    missile,
    chick,
    launch,
    codex,
    fastForward,
    pause,
    refresh,
    rotate,
    settings,
    lock,
    check,
  ];

  /// The picture for a Material symbol a screen asks for, or null for plain
  /// controls (close, back, plus, minus) that stay outlined glyphs.
  static String? forIcon(IconData? icon) => _symbols[icon];

  static final _symbols = <IconData, String>{
    // menu sheet
    Icons.rocket_launch: launch,
    Icons.rocket_launch_outlined: launch,
    Icons.flight: launch,
    Icons.airplanemode_active: launch,
    Icons.emoji_events: '${_menu}challenge.webp',
    Icons.emoji_events_outlined: '${_menu}challenge.webp',
    Icons.storefront: chest,
    Icons.inventory_2: chest,
    Icons.inventory_2_outlined: chest,
    Icons.card_giftcard: chest,
    Icons.build: '${_menu}growth.webp',
    Icons.auto_fix_high: '${_menu}growth.webp',
    Icons.account_tree: '${_menu}research.webp',
    Icons.school: '${_menu}research.webp',
    Icons.precision_manufacturing: '${_menu}hangar.webp',
    Icons.radar: '${_menu}patrol.webp',
    Icons.explore: '${_menu}patrol.webp',
    Icons.travel_explore: '${_menu}patrol.webp',
    Icons.event_repeat: '${_menu}season.webp',
    Icons.workspace_premium: '${_menu}achievement.webp',
    Icons.groups: '${_menu}guild.webp',
    Icons.assignment_turned_in: '${_menu}mission.webp',
    // items
    Icons.hexagon: coin,
    Icons.description: techTicket,
    Icons.vpn_key: key,
    Icons.calendar_month: calendar,
    Icons.pets: chick,
    Icons.favorite: heart,
    Icons.favorite_border: heart,
    Icons.healing: heal,
    Icons.auto_awesome: gem,
    Icons.diamond: gem,
    Icons.bolt: bolt,
    Icons.flash_on: bolt,
    Icons.electric_bolt: bolt,
    Icons.battery_full: bolt,
    Icons.battery_charging_full: bolt,
    Icons.shield: shield,
    Icons.shield_outlined: shield,
    Icons.security: shield,
    Icons.view_agenda: shield,
    Icons.navigation: missile,
    Icons.track_changes: crosshair,
    Icons.gps_fixed: crosshair,
    Icons.speed: speed,
    Icons.hourglass_bottom: hourglass,
    Icons.auto_stories: codex,
    Icons.auto_stories_outlined: codex,
    Icons.fast_forward: fastForward,
    Icons.compare_arrows: fastForward,
    // controls
    Icons.settings: settings,
    Icons.tune: settings,
    Icons.pause: pause,
    Icons.pause_circle_outline: pause,
    Icons.refresh: refresh,
    Icons.screen_rotation: rotate,
    Icons.lock: lock,
    Icons.lock_outline: lock,
    Icons.check_circle: check,
  };
}

/// A current-art picture at a square size (contain-fit).
class GameIconImage extends StatelessWidget {
  const GameIconImage(this.asset, {super.key, this.size = 40});
  final String asset;
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
  );
}

/// Menu shortcuts' pictures by symbol (kept name for the lobby callers).
class LobbyIcon extends StatelessWidget {
  const LobbyIcon(this.icon, {super.key, this.size = 40});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) {
    final asset = icon == Icons.card_giftcard
        ? 'assets/art/menu_v13/season.webp'
        : GameIcons.forIcon(icon);
    return asset == null
        ? Icon(icon, size: size)
        : GameIconImage(asset, size: size);
  }
}
