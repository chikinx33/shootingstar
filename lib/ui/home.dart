import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'prologue_screen.dart';

import '../art/refit_art.dart';
import '../art/lobby_art.dart';
import '../data/profile.dart';
import '../data/content.dart';
import '../main.dart';
import 'components.dart';
import 'arcade_home_widgets.dart';
import 'fixed_lobby.dart';
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
    // First launch: the guardian cats' story (never inside widget tests,
    // which drive the lobby directly).
    final testing = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (!p.prologueSeen && !p.developerMode && !testing) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        p.markPrologueSeen();
        await Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const PrologueScreen()));
      });
    }
    if (p.battleSaveNotice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || p.battleSaveNotice == null) return;
        final notice = p.battleSaveNotice!;
        p.battleSaveNotice = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(notice), textAlign: TextAlign.center)),
        );
      });
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
      SuspendedSortie? resume;
      if (p.hasSuspendedBattle && !p.developerMode) {
        final pending = p.restoreBattle();
        if (pending != null) {
          final decision = await showDialog<String>(
            context: context,
            builder: (c) => GameDialog(
              title: '진행 중인 출격',
              child: GamePages(
                children: [
                  Text(
                    message("{0} · Lv.{1} · {2}초", [
                      stages[pending.game.stageIndex].name,
                      pending.game.level,
                      pending.game.elapsed.floor(),
                    ]),

                    textAlign: TextAlign.center,
                  ),
                  Text(
                    tr('기체·무장·적탄과 성장 선택을 저장했습니다. 종료 중에는 전투 시간이 흐르지 않습니다.'),

                    textAlign: TextAlign.center,
                  ),
                  GameActionButton(
                    label: '이전 전투 이어하기',
                    primary: true,
                    icon: Icons.play_arrow,
                    onPressed: audible(() => Navigator.pop(c, 'resume')),
                  ),
                  GameActionButton(
                    label: '이전 전투 포기',
                    onPressed: audible(() => Navigator.pop(c, 'discard')),
                  ),
                ],
              ),
            ),
          );
          if (!mounted || decision == null) return;
          if (decision == 'resume') {
            resume = pending;
            training = false;
            challenge = pending.game.challenge;
            dailyEntry = pending.game.dailyEntry;
          } else {
            final discard = await showDialog<bool>(
              context: context,
              builder: (c) => GameDialog(
                title: '출격을 포기할까요?',
                child: GamePages(
                  children: [
                    Text(
                      tr('저장된 전투와 미정산 보상이 사라집니다. 영구 성장과 재화는 유지됩니다.'),
                      textAlign: TextAlign.center,
                    ),
                    GameActionButton(
                      label: '포기하고 새로 출격',
                      onPressed: audible(() => Navigator.pop(c, true)),
                    ),
                    GameActionButton(
                      label: '이전 전투 유지',
                      primary: true,
                      onPressed: audible(() => Navigator.pop(c, false)),
                    ),
                  ],
                ),
              ),
            );
            if (!mounted || discard != true) return;
            await p.discardBattle();
          }
        } else if (mounted && p.battleSaveNotice != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr(p.battleSaveNotice!),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
      }
      if (!mounted) return;
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
            resume: resume,
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

  Widget _header() => ColoredBox(
    color: const Color(0xFF15263B),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: message("계정 · {0}", [p.online?.status ?? "게스트"]),
                  onPressed: audible(
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AccountScreen(profile: p),
                      ),
                    ),
                  ),
                  icon: const LobbyIcon(Icons.person, size: 36),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      tr('슈팅스타'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),

                      textAlign: TextAlign.center,
                    ),
                    Text(
                      message("Lv.{0}", [p.pilotLevel + 1]),
                      style: const TextStyle(color: muted, fontSize: 14),

                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr('설정'),
                onPressed: audible(() => _settings(context)),
                icon: const Icon(Icons.settings, color: Colors.white, size: 32),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: ResourceCounter(
                  icon: Icons.hexagon,
                  label: '츄르',
                  value: p.credits,
                  color: cyan,
                  onTap: audible(() => setState(() => tab = 5))!,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ResourceCounter(
                  icon: Icons.description,
                  label: '별가루',
                  value: p.blueprints,
                  color: const Color(0xFF9EC8FF),
                  onTap: audible(() => setState(() => tab = 2))!,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ResourceCounter(
                  icon: Icons.vpn_key,
                  label: '장비 보급권',
                  value: p.gearKeys,
                  color: const Color(0xFFA7E6B3),
                  onTap: audible(() => setState(() => tab = 5))!,
                ),
              ),
            ],
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
        appBar: AppBar(title: Text(tr('시즌 원정'), textAlign: TextAlign.center)),
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
