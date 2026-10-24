import '../l10n/app_language.dart';

import 'audio_feedback.dart';
import 'components.dart';
import 'catalog_screens.dart';
import 'storage_help_screen.dart';
import 'delete_account_screen.dart';
import 'info_dialog.dart';
import 'supporter_screen.dart';

import 'package:flutter/material.dart';

import 'game_decor.dart';

import '../data/profile.dart';
import '../data/cloud_sync.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.profile});
  final Profile profile;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final user = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController(),
      recovery = TextEditingController();
  int mode = 0, actionRevision = 0;
  String? error;
  CloudSync get online => widget.profile.online!;
  @override
  void dispose() {
    user.dispose();
    password.dispose();
    name.dispose();
    recovery.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      error = null;
      actionRevision++;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
      }
    }
  }

  Future<void> submit() async {
    if (!RegExp(r'^[a-z0-9_]{4,24}$')
        .hasMatch(user.text.trim().toLowerCase())) {
      setState(() => error = '아이디는 영문·숫자·밑줄 4~24자로 입력하세요.');
      return;
    }
    if (password.text.length < 12 || password.text.length > 128) {
      setState(() => error = '비밀번호는 12~128자로 입력하세요.');
      return;
    }
    if (mode == 1 &&
        (name.text.trim().isEmpty || name.text.trim().length > 16)) {
      setState(() => error = '닉네임은 1~16자로 입력하세요.');
      return;
    }
    await run(
      () => online.login(
        user.text.trim().toLowerCase(),
        password.text,
        nickname: mode == 1 ? name.text.trim() : null,
        recovery: mode == 2 ? recovery.text : null,
      ),
    );
    if (!mounted) return;
    password.clear();
    recovery.clear();
  }

  Future<void> resolve(bool cloud) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => GameDialog(
        title: '진행 선택',
        actions: [
          GameActionButton(
            onPressed: audible(() => Navigator.pop(c, false)),
            label: '취소',
          ),
          GameActionButton(
            primary: true,
            onPressed: audible(() => Navigator.pop(c, true)),
            label: '선택한 진행 사용',
            displayLabel: '이 진행 사용',
          ),
        ],
        child: Text(
          message("{0}\n선택한 진행으로 동기화합니다. 선택 전 두 진행은 이 기기에 백업됩니다.", [
            cloud ? '서버 진행을 불러옵니다.' : '이 기기 진행을 저장합니다.',
          ]),

          textAlign: TextAlign.center,
        ),
      ),
    );
    if (yes == true && mounted) {
      await run(() => online.resolve(useCloud: cloud));
    }
  }

  Future<void> requestDelete() async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DeleteAccountScreen(profile: widget.profile),
      ),
    );
    if (deleted == true && mounted) {
      user.clear();
      password.clear();
      name.clear();
      recovery.clear();
      setState(() {
        mode = 0;
        error = null;
      });
    }
  }

  String summary(dynamic value) => value is Map
      ? '출격 ${value['runs'] ?? 0}회 · ${value['credits'] ?? 0} 츄르 · 장비 ${(value['content']?['inventory'] as List?)?.length ?? 0}개'
      : '저장 없음';
  InputDecoration fieldLabel(String label, {String? hint, String? help}) =>
      InputDecoration(
        labelText: tr(label),
        hintText: tr(hint),
        helperText: tr(help),
        labelStyle: const TextStyle(fontSize: 18),
        hintStyle: const TextStyle(fontSize: 16),
        helperStyle: const TextStyle(fontSize: 16),
        counterStyle: const TextStyle(fontSize: 14),
      );
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    if (widget.profile.online == null) {
      return Scaffold(
        appBar: GameAppBar(title: Text(tr('계정'), textAlign: TextAlign.center)),
        body: GamePages(
          centerContent: true,
          framed: true,
          children: [
            Center(child: RasterIcon(Icons.person, size: 112)),
            Text(
              tr('온라인 서비스를 준비하고 있습니다.'),
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListenableBuilder(
      listenable: online,
      builder: (context, _) {
        final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
        return Scaffold(
          appBar: GameAppBar(
            title: Text(tr('계정'), textAlign: TextAlign.center),
            actions: [
              if (keyboard)
                IconButton(
                  tooltip: tr('키보드 닫기'),
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: const RasterIcon(Icons.keyboard_hide, size: 32),
                  onPressed: audible(() => FocusScope.of(context).unfocus()),
                )
              else
                InfoAction(
                  key: const Key('account-info'),
                  label: '계정 안내',
                  onPressed: details,
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                if (!keyboard)
                  CatalogHeader(
                    title: '계정 저장',
                    status: online.status,
                    icon: Icons.person,
                  ),
                if (!online.signedIn && !keyboard)
                  CatalogTabs(
                    tight: true,
                    labels: const ['로그인', '가입', '복구'],
                    selected: mode,
                    onSelected: audibleChange(
                      online.busy
                          ? null
                          : (value) => setState(() {
                              mode = value;
                              error = null;
                            }),
                    ),
                  ),
                Expanded(
                  // v12.4.3: one page per state. Explanations open from the
                  // AppBar info control; rare account actions from 계정 관리.
                  child: GamePages(
                    key: ValueKey(
                      'account-$mode-${online.signedIn}-$actionRevision-$error',
                    ),
                    framed: true,
                    centerContent: true,
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (online.busy) const RasterGauge(),
                      if (error != null) ...[
                        Text(
                          tr(error!),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.orange,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        gap8,
                      ],
                      if (online.signedIn) ...signedIn() else ...guest(),
                      // A one-time recovery code or a save conflict needs the
                      // whole page; both links stay in the info popup.
                      if (!online.signedIn ||
                          (online.recoveryCode.isEmpty &&
                              online.conflict == null)) ...[
                        gap12,
                        pair(
                          widget.profile.developerMode
                              ? null
                              : supporterLink(context),
                          helpLink(context),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  GameActionButton supporterLink(BuildContext context) => GameActionButton(
    label: '후원 외형·선택형 보상 안내',
    displayLabel: '후원 외형',
    onPressed: audible(
      () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SupporterScreen(profile: widget.profile),
        ),
      ),
    ),
  );

  GameActionButton helpLink(BuildContext context) => GameActionButton(
    label: '저장·복구 도움말',
    displayLabel: '저장 도움말',
    onPressed: audible(
      () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StorageHelpScreen(profile: widget.profile),
        ),
      ),
    ),
  );

  /// Two secondary actions side by side; a lone action keeps its own width.
  Widget pair(Widget? a, Widget b) => a == null
      ? b
      : Row(
          children: [
            Expanded(child: a),
            const SizedBox(width: 8),
            Expanded(child: b),
          ],
        );

  List<Widget> signedIn() => [
    Text(
      online.nickname,
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
      textAlign: TextAlign.center,
    ),
    Text(
      message("@{0} · 저장 버전 {1}", [
        online.account?['username'],
        online.revision,
      ]),
      style: const TextStyle(fontSize: 16),
      textAlign: TextAlign.center,
    ),
    if (online.updatedAt > 0)
      Text(
        message("서버 저장: {0}", [
          DateTime.fromMillisecondsSinceEpoch(online.updatedAt * 1000)
              .toLocal()
              .toString()
              .substring(5, 16),
        ]),
        style: const TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
      ),
    if (online.recoveryCode.isNotEmpty) ...[
      gap12,
      const GameSectionTitle('복구 코드 보관'),
      Text(
        tr('비밀번호 분실 시 필요합니다. 한 번만 표시되니 남에게 알리지 마세요.'),
        style: const TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
      ),
      gap8,
      SelectableText(
        online.recoveryCode,
        style: const TextStyle(fontSize: 20),
        textAlign: TextAlign.center,
      ),
      gap8,
      GameActionButton(
        label: '별도로 보관했습니다',
        displayLabel: '보관 완료',
        onPressed: audible(() => setState(() => online.recoveryCode = '')),
      ),
    ],
    if (online.conflict != null) ...[
      gap12,
      Text(
        tr('사용할 진행을 고르세요.'),
        style: const TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
      ),
      gap8,
      GameChoiceTile(
        title: '서버 진행 사용',
        description: summary(online.conflict!['profile']),
        icon: Icons.cloud_download,
        selected: false,
        onPressed: audible(online.busy ? null : () => resolve(true)),
      ),
      gap8,
      GameChoiceTile(
        title: '이 기기 진행 저장',
        description: summary(widget.profile.exportProgress()),
        icon: Icons.save,
        selected: false,
        onPressed: audible(online.busy ? null : () => resolve(false)),
      ),
    ],
    gap16,
    GameActionButton(
      label: '지금 동기화',
      primary: true,
      icon: Icons.refresh,
      onPressed: audible(online.busy ? null : () => run(online.sync)),
    ),
    gap12,
    pair(
      GameActionButton(
        label: '로그아웃 · 게스트로 돌아가기',
        displayLabel: '로그아웃',
        onPressed: audible(
          online.busy ? null : () => run(() => online.logout()),
        ),
      ),
      GameActionButton(
        key: const Key('account-manage'),
        label: '계정 관리',
        onPressed: audible(online.busy ? null : manage),
      ),
    ),
  ];

  List<Widget> guest() => [
    // A validation/online error takes the place of the short mode line.
    if (error == null)
      Text(
        tr(
          mode == 1
              ? '지금 기기의 진행으로 계정을 만듭니다.'
              : mode == 2
              ? '복구 코드로 새 비밀번호를 정합니다. 기존 로그인은 모두 해제됩니다.'
              : '계정 진행을 불러오고 지금 진행은 기기에 백업합니다.',
        ),
        style: const TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
      ),
    TextField(
      key: const Key('account-user'),
      controller: user,
      enabled: !online.busy,
      style: const TextStyle(fontSize: 20),
      autocorrect: false,
      decoration: fieldLabel('아이디', hint: '영문·숫자·밑줄 4~24자'),
      textAlign: TextAlign.center,
    ),
    if (mode == 1)
      TextField(
        key: const Key('account-name'),
        controller: name,
        enabled: !online.busy,
        style: const TextStyle(fontSize: 20),
        maxLength: 16,
        decoration: fieldLabel('닉네임'),
        textAlign: TextAlign.center,
      ),
    if (mode == 2)
      TextField(
        key: const Key('account-recovery'),
        controller: recovery,
        enabled: !online.busy,
        style: const TextStyle(fontSize: 20),
        autocorrect: false,
        decoration: fieldLabel('48자리 복구 코드'),
        textAlign: TextAlign.center,
      ),
    TextField(
      key: const Key('account-password'),
      controller: password,
      enabled: !online.busy,
      style: const TextStyle(fontSize: 20),
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: fieldLabel(mode == 2 ? '새 비밀번호' : '비밀번호', help: '12~128자'),
      onSubmitted: audibleChange((_) {
        if (!online.busy) submit();
      }),
      textAlign: TextAlign.center,
    ),
    gap16,
    GameActionButton(
      primary: true,
      label: mode == 1
          ? '현재 진행으로 계정 만들기'
          : mode == 2
          ? '계정 복구'
          : '로그인',
      displayLabel: mode == 1
          ? '계정 만들기'
          : mode == 2
          ? '계정 복구'
          : '로그인',
      onPressed: audible(online.busy || !online.ready ? null : submit),
    ),
  ];

  /// Explanations that do not need to stay on the form or account page.
  void details() => showInfoDialog(
    context,
    title: '계정 안내',
    actions: (dialog) => [
      if (!widget.profile.developerMode) supporterLink(dialog),
      helpLink(dialog),
    ],
    children: online.signedIn
        ? const [
            InfoText(
              '장비·펫·테크·시즌·우편의 영구 진행을 동기화합니다. 중단한 전투는 같은 기기에서만 이어갑니다. 미완료 출격을 정산하거나 포기한 뒤 다른 기기를 사용하세요.',
            ),
          ]
        : [
            InfoText(
              mode == 1
                  ? '현재 기기의 진행으로 계정을 만듭니다.'
                  : mode == 2
                  ? '복구 코드로 새 비밀번호를 설정합니다. 기존 로그인은 모두 해제됩니다.'
                  : '로그인하면 계정의 진행을 불러옵니다. 현재 진행은 이 기기에 백업됩니다.',
            ),
            gap8,
            const InfoText(
              '가입하지 않아도 기기 저장으로 플레이할 수 있습니다. 온라인 길드와 기기 간 저장은 계정이 필요합니다.',
            ),
          ],
  );

  /// Rare, account-wide actions stay one tap away in a popup.
  void manage() => showInfoDialog(
    context,
    title: '계정 관리',
    children: const [
      InfoText('모든 기기 로그아웃은 다른 기기의 로그인도 해제합니다. 계정 삭제는 되돌릴 수 없습니다.'),
    ],
    actions: (dialog) => [
      GameActionButton(
        label: '모든 기기 로그아웃',
        displayLabel: '전체 로그아웃',
        onPressed: audible(
          online.busy
              ? null
              : () {
                  Navigator.pop(dialog);
                  run(() => online.logout(all: true));
                },
        ),
      ),
      GameActionButton(
        label: '계정 영구 삭제',
        icon: Icons.delete_forever,
        onPressed: audible(
          online.busy
              ? null
              : () {
                  Navigator.pop(dialog);
                  requestDelete();
                },
        ),
      ),
    ],
  );
}
