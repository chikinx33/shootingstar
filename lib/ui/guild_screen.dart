import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'game_motion.dart';
import 'lobby_cat_hero.dart';

import 'game_decor.dart';

import '../data/profile.dart';
import '../data/guild_client.dart';
import 'components.dart';
import 'account_screen.dart';
import 'catalog_screens.dart';
import 'game_slots.dart';
import 'info_dialog.dart';
import '../art/game_icons.dart';

class GuildScreen extends StatefulWidget {
  const GuildScreen({super.key, required this.profile});
  final Profile profile;
  @override
  State<GuildScreen> createState() => _GuildScreenState();
}

class _GuildScreenState extends State<GuildScreen> {
  Map<String, dynamic>? state;
  bool busy = false;
  int tab = 0;
  String? error;
  final name = TextEditingController(), code = TextEditingController();
  late final client = GuildClient(widget.profile);
  @override
  void initState() {
    super.initState();
    if (widget.profile.online?.signedIn == true) run('state');
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> run(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      var result = await client.call(action, data);
      if (result['guild'] != null && widget.profile.guildReports.isNotEmpty) {
        await client.syncReports();
        result = await client.call('state');
      }
      if (mounted) {
        setState(() {
          if ((state?['guild'] == null) != (result['guild'] == null)) tab = 0;
          state = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e.toString().startsWith('Exception:')
              ? e.toString().substring(11)
              : '길드 서버에 연결할 수 없습니다. 인터넷 연결을 확인하고 다시 시도하세요.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final p = widget.profile, g = state?['guild'], user = state?['user'];
    final signed = p.online?.signedIn == true;
    final labels = g != null
        ? const ['현황', '토벌', '보급', '길드원']
        : const ['합류', '모집'];
    final selected = tab.clamp(0, labels.length - 1);
    final listing = signed && state != null && selected == labels.length - 1;
    final items = listing
        ? (state![g == null ? 'directory' : 'members'] as List? ?? [])
        : const [];
    return Scaffold(
      appBar: GameAppBar(
        title: Text(tr('성간 길드'), textAlign: TextAlign.center),
        actions: [
          InfoAction(
            key: const Key('guild-info'),
            label: '길드 안내',
            onPressed: _rules,
          ),
          IconButton(
            onPressed: audible(busy || !signed ? null : () => run('state')),
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const RasterIcon(Icons.refresh, size: 32),
            tooltip: tr('길드 새로고침'),
          ),
        ],
      ),
      body: Column(
        children: [
          // v12.15: the guild's emblem card (name, level, members, coins)
          // instead of a ribbon and a "a · b" status line
          if (MediaQuery.viewInsetsOf(context).bottom == 0)
            Padding(
              key: const Key('guild-banner'),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: _GuildBanner(
                name: g == null ? '함께하는 함대' : '${g['name']}',
                facts: g == null
                    ? const []
                    : [
                        GameTag('Lv.${1 + (g['xp'] as int) ~/ 200}'),
                        GameTag(
                          message('{0}/20명', [
                            (state!['members'] as List).length,
                          ]),
                          tone: GameTone.sky,
                        ),
                        GameTag(
                          message('코인 {0}', [user['coins']]),
                          tone: GameTone.good,
                        ),
                      ],
              ),
            ),
          SizedBox(height: 6, child: busy ? const RasterGauge() : null),
          if (signed &&
              state != null &&
              MediaQuery.viewInsetsOf(context).bottom == 0)
            LayoutBuilder(
              builder: (context, constraints) {
                // Four chips need space for three Korean glyphs and chip insets.
                // Split categories before the framework's chip label can fade.
                final split =
                    labels.length == 4 &&
                    constraints.maxWidth <
                        4 *
                            (MediaQuery.textScalerOf(context).scale(18) * 3 +
                                46);
                if (!split) return _tabs(labels, selected, 0);
                return Column(
                  children: [
                    _tabs(
                      labels.sublist(0, 2),
                      selected < 2 ? selected : -1,
                      0,
                    ),
                    _tabs(
                      labels.sublist(2),
                      selected >= 2 ? selected - 2 : -1,
                      2,
                    ),
                  ],
                );
              },
            ),
          Expanded(
            child: error != null
                ? GamePages(
                    centerContent: true,
                    child: Column(
                      children: [
                        const Center(
                          child: GameIconImage(Mascot.defeat, size: 96),
                        ),
                        Text(
                          tr(error!),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.orange,
                          ),

                          textAlign: TextAlign.center,
                        ),
                        gap(24),
                        GameActionButton(
                          label: '서버 다시 연결',
                          onPressed: audible(busy ? null : () => run('state')),
                        ),
                      ],
                    ),
                  )
                : listing
                ? ListView(
                    key: ValueKey(
                      'guild-list-${g == null ? 'directory' : 'members'}',
                    ),
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (items.isEmpty)
                        CatalogCard(
                          children: [
                            Text(
                              tr('모집 중인 길드가 없습니다.'),
                              style: TextStyle(fontSize: 18),

                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      for (final item in items)
                        CatalogCard(
                          children: [
                            Row(
                              children: [
                                const GameIconImage(_emblem, size: 56),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item['name'],
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),

                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            if (g == null) ...[
                              GameFactRow([
                                GameFact('인원', '${item['members']}/20'),
                                GameFact(
                                  '초대 코드',
                                  '${item['id']}',
                                  tone: GameTone.gold,
                                ),
                              ]),
                              gap(24),
                              Center(
                                child: GameActionButton(
                                  label: AppLanguage.instance.english
                                      ? 'Join ${item['name']}'
                                      : '${item['name']} 가입',
                                  displayLabel: '가입',
                                  primary: true,
                                  onPressed: audible(
                                    busy
                                        ? null
                                        : () =>
                                              run('join', {'code': item['id']}),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  )
                : GamePages(
                    centerContent: !signed || state == null,
                    framed: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!signed) ...[
                          // v12.9: the guild flag over a squad of guardians
                          Row(
                            key: const Key('guild-intro-cats'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final (k, face)
                                  in LobbyCatHero.faces.indexed)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Bob(
                                    height: 4,
                                    period: 2200 + k * 300,
                                    child: Image.asset(
                                      face,
                                      width: 72,
                                      height: 72,
                                      filterQuality: FilterQuality.medium,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          gap(8),
                          const GameSectionTitle('동료와 함께 성장하세요'),
                          gap(6),
                          const _PerkRow(),
                          gap(20),
                          GameActionButton(
                            label: '계정 로그인 · 가입',
                            primary: true,
                            image: LobbyCatHero.faces.first,
                            onPressed: audible(() async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AccountScreen(profile: p),
                                ),
                              );
                              if (mounted) {
                                setState(() {});
                                if (p.online?.signedIn == true) run('state');
                              }
                            }),
                          ),
                        ] else if (state == null) ...[
                          const Center(
                            child: GameIconImage(_emblem, size: 120),
                          ),
                          Text(
                            tr('길드 서버에 연결해 가입 상태와 기록을 불러오세요.'),
                            style: TextStyle(fontSize: 16),

                            textAlign: TextAlign.center,
                          ),
                          GameActionButton(
                            label: '서버 다시 연결',
                            primary: true,
                            onPressed: audible(
                              busy ? null : () => run('state'),
                            ),
                          ),
                        ] else if (g == null) ...[
                          const GameSectionTitle('길드 창설'),
                          TextField(
                            controller: name,
                            maxLength: 24,
                            style: const TextStyle(fontSize: 20),
                            decoration: InputDecoration(
                              labelText: tr('새 길드 이름'),
                            ),

                            textAlign: TextAlign.center,
                          ),
                          GameActionButton(
                            label: '길드 창설',
                            primary: true,
                            onPressed: audible(
                              busy
                                  ? null
                                  : () => run('create', {'name': name.text}),
                            ),
                          ),
                          gap(24),
                          const GameSectionTitle('초대 코드로 합류'),
                          TextField(
                            controller: code,
                            maxLength: 6,
                            style: const TextStyle(fontSize: 20),
                            decoration: InputDecoration(
                              labelText: tr('6자리 초대 코드'),
                            ),

                            textAlign: TextAlign.center,
                          ),
                          GameActionButton(
                            label: '초대 코드로 가입',
                            onPressed: audible(
                              busy
                                  ? null
                                  : () => run('join', {'code': code.text}),
                            ),
                          ),
                        ] else if (selected == 0) ...[
                          // v12.14: the code keeps its copyable text beside a
                          // tag; guild numbers sit in labelled tiles.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const GameTag('초대 코드'),
                              const SizedBox(width: 8),
                              Flexible(
                                child: SelectableText(
                                  '${g['id']}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          gap(8),
                          GameFactRow([
                            GameFact(
                              '길드 Lv',
                              '${1 + (g['xp'] as int) ~/ 200}',
                              tone: GameTone.gold,
                            ),
                            GameFact('기여 경험치', '${g['xp']}'),
                            GameFact(
                              '내 코인',
                              '${user['coins']}',
                              tone: GameTone.good,
                            ),
                          ]),
                          gap(24),
                          GameActionButton(
                            label: user['checkday'] == state!['day']
                                ? '오늘 출석 완료'
                                : '출석 · 코인 +10',
                            primary: true,
                            image: GameIcons.calendar,
                            onPressed: audible(
                              busy || user['checkday'] == state!['day']
                                  ? null
                                  : () => run('checkin'),
                            ),
                          ),
                          gap(12),
                          GameActionButton(
                            label: '기여 · 코인 10',
                            image: GameIcons.coin,
                            onPressed: audible(
                              busy || (user['coins'] as int) < 10
                                  ? null
                                  : () => run('donate'),
                            ),
                          ),
                          gap(24),
                          GameActionButton(
                            label: '길드 탈퇴',
                            onPressed: audible(busy ? null : _leave),
                          ),
                        ] else if (selected == 1) ...[
                          // the weekly target: the Vacuum King's flagship
                          const Center(
                            child: GameIconImage(_flagship, size: 132),
                          ),
                          GameSectionTitle('주간 토벌 · ${state!['week']}'),
                          RasterGauge(
                            value: ((state!['damage'] as int) / 100000).clamp(
                              0,
                              1,
                            ),
                          ),
                          gap(8),
                          GameFactRow([
                            GameFact(
                              '누적 피해',
                              '${state!['damage']} / 100,000',
                              tone: GameTone.danger,
                            ),
                            GameFact('오늘 기여', '${state!['attempts']}/3'),
                          ]),
                          gap(24),
                          GameActionButton(
                            label: '토벌 보상 우편 수령',
                            displayLabel: '보상 우편 수령',
                            primary: true,
                            onPressed: audible(
                              busy || (state!['damage'] as int) < 100000
                                  ? null
                                  : () => run('raid'),
                            ),
                          ),
                        ] else ...[
                          const Center(
                            child: GameIconImage(GameIcons.chest, size: 112),
                          ),
                          const GameSectionTitle('길드 보급소'),
                          gap(10),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GameRewardSlot(
                                GameReward(GameIcons.food, 30, '먹이'),
                                size: 72,
                              ),
                              SizedBox(width: 12),
                              GameRewardSlot(
                                GameReward(GameIcons.stardust, 2, '별가루'),
                                size: 72,
                              ),
                            ],
                          ),
                          gap(8),
                          const GameHint('하루 1회 · 우편으로 지급'),
                          gap(20),
                          GameActionButton(
                            label: '길드 코인 10 · 우편 지급',
                            displayLabel: '10 · 받기',
                            image: GameIcons.coin,
                            primary: true,
                            onPressed: audible(
                              busy || (user['coins'] as int) < 10
                                  ? null
                                  : () => run('shop'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabs(List<String> labels, int selected, int offset) => CatalogTabs(
    labels: labels,
    selected: selected,
    onSelected: audibleChange((value) => setState(() => tab = value + offset)),
  );

  Future<void> _leave() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => GameDialog(
        title: '길드 탈퇴',
        actions: [
          GameActionButton(
            label: '취소',
            onPressed: audible(() => Navigator.pop(c, false)),
          ),
          GameActionButton(
            label: '탈퇴',
            primary: true,
            onPressed: audible(() => Navigator.pop(c, true)),
          ),
        ],
        child: Text(tr('공동 토벌 참여를 종료합니다. 탈퇴할까요?'), textAlign: TextAlign.center),
      ),
    );
    if (yes == true && mounted) {
      tab = 0;
      await run('leave');
    }
  }

  /// The rules live behind the app bar's '?': short lines with pictures.
  void _rules() => showInfoDialog(
    context,
    title: '길드 안내',
    children: const [
      RuleLine(GameIcons.calendar, '매일 출석하면 코인 10'),
      RuleLine(GameIcons.coin, '코인 10으로 길드 경험치 기여'),
      RuleLine(_flagship, '30초·10격파 이상 출격이 주간 토벌에 자동 기여'),
      RuleLine(GameIcons.bomb, '1격파 = 피해 3 · 1회 최대 3,000'),
      RuleLine(GameIcons.hourglass, '토벌은 매주 월요일 초기화'),
      RuleLine(GameIcons.chest, '보급소는 하루 1회 · 우편으로 지급'),
    ],
  );
}

const _emblem = 'assets/art/menu_v13/guild.webp';
const _flagship = 'assets/art/enemies_v14/boss_9.webp';

/// The guild's emblem with its name and tags in one card.
class _GuildBanner extends StatelessWidget {
  const _GuildBanner({required this.name, required this.facts});
  final String name;
  final List<Widget> facts;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return GameInset(
      tone: GameTone.gold,
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      child: Row(
        children: [
          const GameIconImage(_emblem, size: 56),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: GameLettering(name, size: 22),
                ),
                if (facts.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: facts,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What a guild gives, as four pictures with one word each.
class _PerkRow extends StatelessWidget {
  const _PerkRow();
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    Widget perk(String asset, String label) => Expanded(
      child: Column(
        children: [
          GameIconImage(asset, size: 44),
          Text(
            tr(label),
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: GameUi.caption,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    return Row(
      children: [
        perk(GameIcons.calendar, '출석'),
        perk(GameIcons.coin, '기여'),
        perk(_flagship, '토벌'),
        perk(GameIcons.chest, '보급'),
      ],
    );
  }
}
