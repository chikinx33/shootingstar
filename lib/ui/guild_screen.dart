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
          if (MediaQuery.viewInsetsOf(context).bottom == 0)
            CatalogHeader(
              title: '함께하는 함대',
              localizeStatus: g == null,
              icon: Icons.groups,
              status: g == null
                  ? '출석 · 기여 · 주간 토벌 · 보급'
                  : '${g['name']} · ${tr('코인')} ${user['coins']}',
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
                        const RasterIcon(Icons.wifi_off, size: 72),
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
                                const RasterIcon(
                                  Icons.person_outline,
                                  size: 64,
                                ),
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
                              Text(
                                message("{0} / 20명 · 초대 코드 {1}", [
                                  item['members'],
                                  item['id'],
                                ]),
                                style: const TextStyle(fontSize: 16),

                                textAlign: TextAlign.center,
                              ),
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
                          const Center(
                            child: RasterIcon(Icons.groups, size: 120),
                          ),
                          Row(
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
                          Text(
                            tr(
                              '같은 서버의 동료와 초대 코드로 합류하세요. 출석·기여·주간 토벌 기록은 온라인 계정에 저장됩니다.',
                            ),
                            style: TextStyle(fontSize: 16),

                            textAlign: TextAlign.center,
                          ),
                          gap(24),
                          GameActionButton(
                            label: '계정 로그인 · 가입',
                            primary: true,
                            icon: Icons.person,
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
                            child: RasterIcon(Icons.groups, size: 144),
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
                          const Center(
                            child: RasterIcon(Icons.groups, size: 112),
                          ),
                          Text(
                            g['name'],
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),

                            textAlign: TextAlign.center,
                          ),
                          SelectableText(
                            '초대 코드 ${g['id']}',
                            style: const TextStyle(fontSize: 18),

                            textAlign: TextAlign.center,
                          ),
                          Text(
                            message("Lv.{0} · 기여 경험치 {1} · {2}/20명", [
                              1 + (g['xp'] as int) ~/ 200,
                              g['xp'],
                              (state!['members'] as List).length,
                            ]),
                            style: const TextStyle(fontSize: 16),

                            textAlign: TextAlign.center,
                          ),
                          GameCostLine('내 길드 코인 ${user['coins']}'),
                          gap(24),
                          GameActionButton(
                            label: user['checkday'] == state!['day']
                                ? '오늘 출석 완료'
                                : '출석 · 코인 +10',
                            primary: true,
                            icon: Icons.calendar_month,
                            onPressed: audible(
                              busy || user['checkday'] == state!['day']
                                  ? null
                                  : () => run('checkin'),
                            ),
                          ),
                          gap(12),
                          GameActionButton(
                            label: '기여 · 코인 10',
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
                          const Center(
                            child: RasterIcon(Icons.shield, size: 144),
                          ),
                          GameSectionTitle('주간 토벌 · ${state!['week']}'),
                          RasterGauge(
                            value: ((state!['damage'] as int) / 100000).clamp(
                              0,
                              1,
                            ),
                          ),
                          Text(
                            message("{0} / 100,000 피해 · 오늘 {1}/3회", [
                              state!['damage'],
                              state!['attempts'],
                            ]),
                            style: const TextStyle(fontSize: 18),

                            textAlign: TextAlign.center,
                          ),
                          Text(
                            tr(
                              '30초·10격파 이상 일반 출격이 자동 기여됩니다. 1격파 = 피해 3, 1회 최대 3,000. 월요일 초기화.',
                            ),
                            style: TextStyle(fontSize: 16),

                            textAlign: TextAlign.center,
                          ),
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
                            child: RasterIcon(Icons.storefront, size: 144),
                          ),
                          const GameSectionTitle('길드 보급소'),
                          Text(
                            tr('먹이 30 + 별가루 2 · 하루 1회\n보상은 우편으로 지급됩니다.'),
                            style: TextStyle(fontSize: 18),

                            textAlign: TextAlign.center,
                          ),
                          const GameCostLine('길드 코인 10'),
                          gap(24),
                          GameActionButton(
                            label: '길드 코인 10 · 우편 지급',
                            displayLabel: '보급 우편 받기',
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
}
