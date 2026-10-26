import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'game_decor.dart';

import 'prologue_screen.dart';

import '../art/refit_art.dart';
import '../art/flight_scene_art.dart';
import '../art/raster_assets.dart';
import '../data/profile.dart';
import 'components.dart';
import 'arcade_home_widgets.dart';
import 'fixed_lobby.dart';
import 'lobby_cat_hero.dart';
import 'hangar_board.dart';
import 'reward_popup.dart';
import 'battle.dart';
import 'daily_challenge_screen.dart';
import '../data/daily_challenge.dart';
import 'account_screen.dart';
import 'settings_screen.dart';
import 'guild_screen.dart';
import 'survival_meta.dart';
import 'talent_screen.dart';
import 'fleet_activity_screen.dart';
import 'content_hub.dart';
import 'campaign_selector.dart';
import '../data/guild_client.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.profile});
  final Profile profile;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  bool _launching = false;
  Profile get p => widget.profile;
  @override
  void initState() {
    super.initState();
    p.addListener(_refresh);
    p.online?.addListener(_refresh);
    p.commerce?.addListener(_refresh);
    _warmBattleArt();
    // First launch: the guardian cats' story (never inside widget tests,
    // which drive the lobby directly).
    final testing = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _showUpdateNotices());
    if (!p.prologueSeen && !p.developerMode && !testing) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        p.markPrologueSeen();
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const PrologueScreen()));
      });
    }
  }

  /// v12.11: what a save change gave back (retired shield devices, drones),
  /// shown once.
  Future<void> _showUpdateNotices() async {
    p.shipModules; // runs the fleet's one-time slot changes
    if (!mounted || p.updateNotices.isEmpty) return;
    final lines = [...p.updateNotices];
    p.updateNotices.clear();
    await showDialog<void>(
      context: context,
      builder: (dialog) => GameDialog(
        title: '슬롯 정리 안내',
        actions: [
          GameActionButton(
            label: '확인',
            primary: true,
            icon: Icons.check,
            onPressed: () => Navigator.pop(dialog),
          ),
        ],
        // v12.14: one tagged block per change instead of one run-on text.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < lines.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              GameInfoBlock(
                label: '환급 완료',
                tone: GameTone.good,
                children: [
                  const SizedBox(height: 4),
                  Text(tr(lines[i]), textAlign: TextAlign.center),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Decodes the next sortie's pictures while the player is in the lobby,
  /// then the other worlds' grounds; launching then rarely waits.
  Future<void> _warmBattleArt() async {
    try {
      // The lobby's own pictures first: battle art decoding in the
      // background must never leave the first lobby screen blank.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final hull = p.selectedShip.clamp(0, 2);
      await Future.wait([
        for (final asset in [
          LobbyCatHero.portraits[hull],
          LobbyCatHero.faces[hull],
          CurrencyArt.churu,
          CurrencyArt.stardust,
          CurrencyArt.gearTicket,
          for (final name in MenuArtIcon.lobby)
            'assets/art/menu_v13/$name.webp',
        ])
          precacheImage(AssetImage(asset), context),
      ]);
      await RasterAssets.load();
      await BattleScreen.warmArt(p.selectedStage);
      await FlightSceneArt.preloadWorlds();
    } catch (_) {
      // The battle screen loads (and reports) whatever is still missing.
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    p.removeListener(_refresh);
    p.online?.removeListener(_refresh);
    p.commerce?.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _launch({
    bool training = false,
    bool challenge = false,
    DailyChallengeEntry? dailyEntry,
  }) async {
    if (_launching) return;
    if (p.online?.busy == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('계정 동기화가 끝난 뒤 출격해 주세요.'),
            textAlign: TextAlign.center,
          ),
        ),
      );
      return;
    }
    _launching = true;
    if (p.online != null) p.online!.inBattle = true;
    try {
      if (!p.onboarded) {
        await showGuide(context, p.finishOnboarding);
        if (!mounted) return;
      }
      if (dailyEntry != null) {
        p.refreshContentClock(DateTime.now());
        final expected = p.dailyChallenge.begin(dailyEntry.tier);
        if (expected == null ||
            expected.day != dailyEntry.day ||
            expected.seed != dailyEntry.seed ||
            expected.variant != dailyEntry.variant) {
          return;
        }
      }
      final beforeFlight = RewardSnapshot(p);
      final toHangar = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => BattleScreen(
            profile: p,
            training: training,
            challenge: challenge,
            dailyEntry: dailyEntry,
          ),
        ),
      );
      if (mounted && toHangar == true) setState(() => tab = 2);
      if (mounted) {
        final earned = beforeFlight.earned(p);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) RewardFlights.show(context, earned);
      }
      if (p.guildToken.isNotEmpty && p.guildReports.isNotEmpty) {
        try {
          await GuildClient(p).syncReports();
        } catch (_) {
          /* Retained for retry in guild screen. */
        }
      }
    } finally {
      _launching = false;
      if (p.online != null) {
        p.online!.inBattle = false;
        p.online!.sync();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _header(),
                if (p.online?.conflict != null)
                  MaterialBanner(
                    content: Text(
                      tr('다른 기기의 진행과 충돌했습니다. 저장할 진행을 선택하세요.'),
                      textAlign: TextAlign.center,
                    ),
                    actions: [
                      TextButton(
                        onPressed: audible(
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AccountScreen(profile: p),
                            ),
                          ),
                        ),
                        child: Text(tr('진행 선택'), textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                Expanded(
                  child: RefitBackdrop(
                    launch: tab == 0,
                    child: switch (tab) {
                      0 => _bridge(),
                      1 => _hangar(),
                      2 => ContentHub(
                        key: const ValueKey('growth'),
                        profile: p,
                      ),
                      4 => TalentScreen(profile: p),
                      5 => ContentHub(
                        key: const ValueKey('supply'),
                        profile: p,
                        initialPage: 3,
                        showNavigation: false,
                      ),
                      _ => SurvivalMeta(
                        profile: p,
                        section: tab,
                        onDailyChallenge: _openDailyChallenge,
                        onChallenge: (i) {
                          p.selectStage(i);
                          _launch(challenge: true);
                        },
                      ),
                    },
                  ),
                ),
                if (p.saveError != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      tr(p.saveError!),
                      style: const TextStyle(color: Colors.orange),

                      textAlign: TextAlign.center,
                    ),
                  ),
                FlightNavigation(
                  selected: tab,
                  onSelect: (i) => setState(() => tab = i),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One row (user 2026-10-25): the selected cat's face opens the account,
  /// the three currencies as picture + amount, then settings. No title; the
  /// pilot level sits before the cat's name in the lobby.
  Widget _header() => ColoredBox(
    color: const Color(0xCC15263B),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      child: Row(
        children: [
          Tooltip(
            message: message("계정 · {0}", [p.online?.status ?? "게스트"]),
            child: Semantics(
              button: true,
              label: tr('계정'),
              child: InkWell(
                key: const Key('account-avatar'),
                borderRadius: BorderRadius.circular(12),
                onTap: audible(
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountScreen(profile: p),
                    ),
                  ),
                ),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC56B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFE3A8),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      LobbyCatHero.faces[p.selectedShip.clamp(0, 2)],
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ResourceCounter(
              image: CurrencyArt.churu,
              label: '츄르',
              value: p.credits,
              onTap: audible(() => setState(() => tab = 5))!,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ResourceCounter(
              image: CurrencyArt.stardust,
              label: '별가루',
              value: p.blueprints,
              onTap: audible(() => setState(() => tab = 2))!,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ResourceCounter(
              image: CurrencyArt.gearTicket,
              label: '장비 보급권',
              value: p.gearKeys,
              onTap: audible(() => setState(() => tab = 5))!,
            ),
          ),
          IconButton(
            tooltip: tr('설정'),
            onPressed: audible(() => _settings(context)),
            icon: const Icon(Icons.settings, color: Colors.white, size: 30),
          ),
        ],
      ),
    ),
  );

  Future<void> _chooseChapter() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => CampaignSelector(profile: p),
  );
  void _openActivity(int page) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => FleetActivityScreen(profile: p, initialPage: page),
    ),
  );

  void _openDailyChallenge() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => DailyChallengeScreen(
        profile: p,
        onLaunch: (entry) => _launch(dailyEntry: entry),
        onExchange: p.exchangeDailyChallenge,
      ),
    ),
  );

  void _openSeason() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: GameAppBar(
          title: Text(tr('시즌 원정'), textAlign: TextAlign.center),
        ),
        body: ContentHub(profile: p, initialPage: 4, showNavigation: false),
      ),
    ),
  );

  Widget _bridge() => FixedLobby(
    profile: p,
    onChapter: _chooseChapter,
    onLaunch: _launch,
    onTraining: () => _launch(training: true),
    onGuide: () => showGuide(context, () {}),
    onActivity: _openActivity,
    onSeason: _openSeason,
    onHangar: () => setState(() => tab = 1),
    onGuild: () => Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => GuildScreen(profile: p)),
    ),
  );
  Widget _hangar() => HangarBoard(profile: p);

  Future<void> _settings(BuildContext context) =>
      showFlightSettings(context, p);
}
