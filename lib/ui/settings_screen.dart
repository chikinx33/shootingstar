import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'game_decor.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../data/profile.dart';
import 'components.dart';
import 'catalog_screens.dart';
import 'account_screen.dart';
import '../app_version.dart';
import 'developer_screen.dart';
import 'control_settings_screen.dart';
import 'item_slots.dart';
import 'lobby_cat_hero.dart';
import '../art/game_icons.dart';

Future<void> showFlightSettings(BuildContext context, Profile profile) =>
    showDialog<void>(
      context: context,
      builder: (_) => FlightSettings(profile: profile),
    );

class FlightSettings extends StatefulWidget {
  const FlightSettings({super.key, required this.profile});
  final Profile profile;
  @override
  State<FlightSettings> createState() => _FlightSettingsState();
}

class _FlightSettingsState extends State<FlightSettings> {
  Profile get p => widget.profile;
  void volume(double value) {
    p.updateSettings(volume: value.clamp(0.0, 1.0).toDouble());
    setState(() {});
  }

  Future<void> unlockDeveloper() async {
    if (p.developerMode) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => const DeveloperPasswordDialog(),
    );
    if (!mounted || accepted != true) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final source = p;
    navigator.pop();
    await source.startDeveloperSession();
  }

  Widget _settingsHeader(Widget leading, Widget title, Widget trailing) =>
      AppLanguage.instance.english
      ? Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [leading, const Spacer(), trailing]),
            title,
            const SizedBox(height: 0),
          ],
        )
      : Row(
          children: [
            leading,
            Expanded(child: title),
            trailing,
          ],
        );

  /// v12.15: the three sub-menus are picture tiles (cat face, rocket,
  /// codex) in one strip, like a game's option shortcuts.
  Widget link(
    String label,
    String english,
    String image,
    VoidCallback? action,
  ) => GameActionTile(
    label: label,
    displayLabel: AppLanguage.instance.english ? english : label,
    icon: Icons.settings,
    image: image,
    onPressed: action,
  );

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      constraints: const BoxConstraints(maxWidth: 440),
      child: RasterPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RasterPanel(
              skin: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: _settingsHeader(
                  SizedBox(
                    width: 96,
                    child: Semantics(
                      label: message("{0} · 3초 눌러 개발자 인증", [AppVersion.label]),
                      button: true,
                      onLongPress: audible(unlockDeveloper),
                      child: RawGestureDetector(
                        key: const Key('settings-version'),
                        gestures: {
                          LongPressGestureRecognizer:
                              GestureRecognizerFactoryWithHandlers<
                                LongPressGestureRecognizer
                              >(
                                () => LongPressGestureRecognizer(
                                  duration: const Duration(seconds: 3),
                                ),
                                (instance) =>
                                    instance..onLongPress = unlockDeveloper,
                              ),
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            tr(AppVersion.label),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    header: true,
                    label: tr('옵션'),
                    excludeSemantics: true,
                    child: Text(
                      tr('옵션'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (p.developerMode)
                          IconButton(
                            key: const Key('exit-developer'),
                            tooltip: tr('개발자 모드 종료 · 일반 사용자로 전환'),
                            onPressed: audible(
                              () => exitDeveloperMode(context, p),
                            ),
                            icon: Image.asset(
                              'assets/art/ui_v13/act_unlock.webp',
                              width: 30,
                              height: 30,
                            ),
                          ),
                        KitCloseButton(
                          onPressed: audible(() => Navigator.pop(context)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyMedium!
                    .copyWith(fontSize: 16, decoration: TextDecoration.none),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      key: const Key('language-setting'),
                      children: [
                        for (final option in const [
                          ('ko', '한국어'),
                          ('en', 'English'),
                        ])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: ChoiceChip(
                                key: ValueKey('language-${option.$1}'),
                                showCheckmark: false,
                                selected:
                                    AppLanguage.instance.code == option.$1,
                                onSelected: audibleChange((_) {
                                  AppLanguage.instance.select(option.$1);
                                }),
                                label: SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    tr(option.$2),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    AudioChannelRow(
                      id: 'music',
                      label: '배경음',
                      enabled: p.musicEnabled,
                      volume: p.musicVolume,
                      onEnabled: (v) {
                        p.updateSettings(musicEnabled: v);
                        setState(() {});
                      },
                      onVolume: (v) {
                        p.updateSettings(musicVolume: v);
                        setState(() {});
                      },
                    ),
                    AudioChannelRow(
                      id: 'sfx',
                      label: '효과음',
                      enabled: p.soundEnabled,
                      volume: p.volume,
                      onEnabled: (v) {
                        p.updateSettings(soundEnabled: v);
                        setState(() {});
                      },
                      onVolume: volume,
                    ),
                    RasterSwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      semanticLabel: '시각 효과 줄이기',
                      title: Text(
                        tr('시각 효과 줄이기'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),

                        textAlign: TextAlign.center,
                      ),
                      value: p.reducedEffects,
                      onChanged: audibleChange((value) {
                        p.updateSettings(reducedEffects: value);
                        setState(() {});
                      }),
                    ),
                    const SizedBox(height: 8),
                    GameActionStrip(
                      children: [
                        // a developer session has no account; its test lab
                        // takes the account tile's place
                        if (p.developerMode)
                          link(
                            '테스트',
                            'Test',
                            'assets/art/ui_v13/icon_stats.webp',
                            () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => DeveloperTestScreen(profile: p),
                              ),
                            ),
                          )
                        else
                          link(
                            '계정',
                            'Profile',
                            LobbyCatHero.faces[p.selectedShip.clamp(0, 2)],
                            () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => AccountScreen(profile: p),
                              ),
                            ),
                          ),
                        link(
                          '조작',
                          'Input',
                          GameIcons.launch,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ControlSettingsScreen(profile: p),
                            ),
                          ),
                        ),
                        link(
                          '라이선스',
                          'Legal',
                          GameIcons.codex,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const GameLicensesScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GameHint(p.developerMode ? '개발자 모드 · 별도 저장 중' : '자동 저장'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DeveloperPasswordDialog extends StatefulWidget {
  const DeveloperPasswordDialog({super.key});
  @override
  State<DeveloperPasswordDialog> createState() =>
      _DeveloperPasswordDialogState();
}

class _DeveloperPasswordDialogState extends State<DeveloperPasswordDialog> {
  final password = TextEditingController();
  String? error;
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  void submit() {
    if (password.text == '0623') {
      Navigator.pop(context, true);
    } else {
      setState(() => error = '비밀번호가 올바르지 않습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return GameDialog(
      title: '개발자 인증',
      actions: [
        GameActionButton(
          label: '개발자 모드 시작',
          icon: Icons.lock_open,
          primary: true,
          onPressed: audible(submit),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('개발자 모드 비밀번호'),
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('developer-password'),
            controller: password,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(
              labelText: tr('비밀번호'),
              border: const OutlineInputBorder(),
              errorText: tr(error),
            ),
            onSubmitted: audibleChange((_) => submit()),

            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            tr('일반 진행과 분리해 개발자 설정을 저장합니다.'),
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Package entries are a list; a complete license opens in one popup whose
/// paragraphs scroll inside a bounded list (no page arrows).
class GameLicensesScreen extends StatefulWidget {
  const GameLicensesScreen({super.key});
  @override
  State<GameLicensesScreen> createState() => _GameLicensesScreenState();
}

class _GameLicensesScreenState extends State<GameLicensesScreen> {
  late Future<List<LicenseEntry>> entries = LicenseRegistry.licenses.toList();
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      appBar: GameAppBar(title: Text(tr('라이선스'), textAlign: TextAlign.center)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const CatalogHeader(
              title: '오픈소스',
              status: '항목별 라이선스 전문',
              icon: Icons.auto_stories,
            ),
            Expanded(
              child: FutureBuilder<List<LicenseEntry>>(
                future: entries,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return GamePages(
                      centerContent: true,
                      framed: true,
                      children: [
                        Text(
                          tr('라이선스를 불러오지 못했습니다.'),
                          style: TextStyle(fontSize: 16),

                          textAlign: TextAlign.center,
                        ),
                        GameActionButton(
                          label: '다시 불러오기',
                          onPressed: audible(
                            () => setState(
                              () => entries = LicenseRegistry.licenses.toList(),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  if (!snapshot.hasData) {
                    return Center(
                      child: Text(
                        tr('라이선스를 불러오는 중입니다.'),
                        style: TextStyle(fontSize: 16),

                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  final list = snapshot.data!;
                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (list.isEmpty)
                        CatalogCard(
                          children: [
                            Text(
                              tr('등록된 라이선스가 없습니다.'),
                              style: TextStyle(fontSize: 16),

                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      for (final entry in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GameItemSlot(
                            title: entry.packages.join(' · '),
                            status: '전문 보기',
                            semanticLabel:
                                '${entry.packages.join(' · ')} 라이선스 열기',
                            image: const GameIconImage(
                              GameIcons.codex,
                              size: 56,
                            ),
                            onTap: () => showDialog<void>(
                              context: context,
                              builder: (_) => _LicenseTextDialog(entry: entry),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One popup per license. Its paragraphs are the repeated items, so only that
/// bounded list moves; the header, title and close control stay fixed.
class _LicenseTextDialog extends StatelessWidget {
  const _LicenseTextDialog({required this.entry});
  final LicenseEntry entry;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final media = MediaQuery.of(context);
    final paragraphs = entry.paragraphs.toList();
    // Screen minus the dialog inset (32), its header and the page padding (32).
    final header = media.textScaler.scale(28) * 1.25 + 24;
    final height =
        media.size.height -
        media.padding.vertical -
        media.viewInsets.bottom -
        32 -
        (header < 72 ? 72 : header) -
        32 -
        8;
    return GameDialog(
      title: '라이선스',
      child: SizedBox(
        height: height < 160 ? 160 : height,
        child: ListView.builder(
          key: const Key('license-paragraphs'),
          itemCount: paragraphs.length + 1,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: i == 0
                ? GameSectionTitle(entry.packages.join(' · '))
                : Text(
                    tr(paragraphs[i - 1].text),
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
          ),
        ),
      ),
    );
  }
}

/// One audio channel on one row (v12.8): name and level, a volume slider
/// and an on/off switch. Background music and sound effects each get one.
class AudioChannelRow extends StatelessWidget {
  const AudioChannelRow({
    super.key,
    required this.id,
    required this.label,
    required this.enabled,
    required this.volume,
    required this.onEnabled,
    required this.onVolume,
  });
  final String id, label;
  final bool enabled;
  final double volume;
  final ValueChanged<bool> onEnabled;
  final ValueChanged<double> onVolume;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final percent = (volume * 100).round();
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            '${tr(label)}\n$percent%',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.2,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: Opacity(
            opacity: enabled ? 1 : .45,
            child: Slider(
              key: Key('$id-volume'),
              value: volume,
              label: '$percent%',
              semanticFormatterCallback: (v) =>
                  '${tr(label)} ${(v * 100).round()}%',
              onChanged: audibleChange(
                (v) => onVolume(v.clamp(0.0, 1.0).toDouble()),
              ),
            ),
          ),
        ),
        Semantics(
          label: tr(label),
          toggled: enabled,
          child: Switch(
            key: Key('$id-switch'),
            value: enabled,
            onChanged: audibleChange(onEnabled),
          ),
        ),
      ],
    );
  }
}
