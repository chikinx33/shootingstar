import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'game_decor.dart';

import 'package:flutter/services.dart';

import '../data/profile.dart';
import '../data/progress_backup.dart';
import 'components.dart';
import 'info_dialog.dart';

class ProgressBackupScreen extends StatefulWidget {
  const ProgressBackupScreen({
    super.key,
    required this.profile,
    this.pickText,
    this.saveText,
  });
  final Profile profile;
  final Future<String?> Function()? pickText;
  final Future<void> Function(String text)? saveText;
  @override
  State<ProgressBackupScreen> createState() => _ProgressBackupScreenState();
}

class _ProgressBackupScreenState extends State<ProgressBackupScreen> {
  bool busy = false;
  String status = '영구 진행을 파일로 보관하고 게스트 진행에 복원합니다.';
  ProgressBackup? pending;
  int revision = 0;
  Profile get p => widget.profile;
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => status = error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('FormatException: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          revision++;
        });
      }
    }
  }

  Future<void> export() => run(() async {
    final text = await ProgressBackup.encode(p);
    if (widget.saveText != null) {
      await widget.saveText!(text);
    } else if (kIsWeb) {
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
        RegExp(r'[:.]'),
        '-',
      );
      final name = 'shootingstar-progress-$stamp.json';
      await XFile.fromData(
        Uint8List.fromList(utf8.encode(text)),
        mimeType: 'application/json',
        name: name,
      ).saveTo(name);
    } else {
      await Clipboard.setData(ClipboardData(text: text));
    }
    status = kIsWeb
        ? '백업 파일 저장을 요청했습니다. 브라우저 다운로드에서 파일을 확인하세요.'
        : '백업 내용을 복사했습니다. 별도 파일이나 개인 보관 장소에 붙여 넣으세요.';
  });
  Future<void> choose({bool clipboard = false}) => run(() async {
    final block = p.backupRestoreBlock;
    if (block != null) throw StateError(block);
    String? text;
    if (clipboard) {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } else if (widget.pickText != null) {
      text = await widget.pickText!();
    } else {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: '수호묘 특공대 백업',
            extensions: ['json'],
            mimeTypes: ['application/json'],
            uniformTypeIdentifiers: ['public.json'],
          ),
        ],
      );
      if (file != null) {
        if (await file.length() > ProgressBackup.maxBytes) {
          throw const FormatException('백업 파일은 512 KB 이하여야 합니다.');
        }
        text = await file.readAsString();
      }
    }
    if (text == null) {
      status = '선택을 취소했습니다. 현재 진행은 그대로입니다.';
      return;
    }
    pending = await ProgressBackup.decode(text);
    status = '검증한 백업입니다. 현재 진행과 비교한 뒤 복원하세요.';
  });
  Future<void> confirm(Map<String, dynamic> progress) async {
    if (busy) return;
    final block = p.backupRestoreBlock;
    if (block != null) {
      setState(() => status = block);
      return;
    }
    final stamp = jsonEncode(p.exportProgress());
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => GameDialog(
        title: '게스트 진행 복원',
        actions: [
          GameActionButton(
            label: '취소',
            onPressed: audible(() => Navigator.pop(dialog, false)),
          ),
          GameActionButton(
            label: '이 진행으로 복원',
            primary: true,
            onPressed: audible(() => Navigator.pop(dialog, true)),
          ),
        ],
        // v12.14: current vs backup side by side in a small table; what
        // happens is a warning, what stays safe a quiet hint.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CompareTable(
              current: [p.credits, p.runs],
              backup: [progress['credits'], progress['runs']],
            ),
            gap12,
            const GameHint('현재 게스트 진행을 백업 값으로 교체합니다.', tone: GameTone.danger),
            const GameHint('복원 전 진행은 이 기기에 보관해 되돌릴 수 있습니다. 계정 진행은 바뀌지 않습니다.'),
          ],
        ),
      ),
    );
    if (yes != true || !mounted) return;
    await run(() async {
      if (stamp != jsonEncode(p.exportProgress())) {
        throw StateError('현재 진행이 바뀌었습니다. 다시 비교해 주세요.');
      }
      await p.restoreGuestBackup(progress);
      pending = null;
      status = '복원하고 기기에 저장했습니다. 복원 전 진행으로 되돌릴 수도 있습니다.';
    });
  }

  void _details() => showInfoDialog(
    context,
    title: '백업·복원 안내',
    children: const [
      GameSectionTitle('백업 보관'),
      gap8,
      InfoText('백업에는 영구 진행만 담습니다. 계정 인증·후원 소유권·최근 출격 기록은 포함하지 않습니다.'),
      gap8,
      InfoText(
        '백업은 암호화되지 않은 게임 데이터입니다. 공유하면 진행 수치가 노출될 수 있으므로 개인 보관 장소에 저장하세요.',
      ),
      gap16,
      GameSectionTitle('게스트 진행 복원'),
      gap8,
      InfoText('게스트에서만 복원합니다. 선택·내용 검증·현재 진행 비교 후 직접 승인해야 적용됩니다.'),
      gap8,
      InfoText('후원 외형은 계정의 구매 복원으로 확인합니다. 앱 데이터를 지우면 기기에 보관한 복원 전 진행도 지워집니다.'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: GameAppBar(
          title: Text(tr('진행 백업·복원'), textAlign: TextAlign.center),
        ),
        body: SafeArea(
          // v12.4.3: one page. Privacy and scope notes open in the popup.
          child: GamePages(
            key: ValueKey('backup-$revision'),
            framed: true,
            centerContent: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text(tr(status), textAlign: TextAlign.center),
              gap12,
              GameActionButton(
                label: kIsWeb ? '백업 파일 저장' : '백업 내용 복사',
                icon: Icons.save,
                onPressed: audible(busy ? null : export),
              ),
              gap16,
              if (p.backupRestoreBlock != null) ...[
                Text(
                  tr(p.backupRestoreBlock!),
                  style: const TextStyle(color: Colors.orange),
                  textAlign: TextAlign.center,
                ),
                gap8,
              ],
              GameActionButton(
                label: '백업 파일 선택',
                icon: Icons.folder_open,
                onPressed: audible(busy ? null : () => choose()),
              ),
              gap12,
              GameActionButton(
                label: '복사한 백업 읽기',
                icon: Icons.paste,
                onPressed: audible(busy ? null : () => choose(clipboard: true)),
              ),
              if (pending != null) ...[
                gap16,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const GameTag('읽은 백업'),
                    const SizedBox(width: 8),
                    Flexible(
                      child: GameHint(
                        '${pending!.version} · ${pending!.createdAt.toLocal().toString().substring(0, 16)}',
                      ),
                    ),
                  ],
                ),
                gap8,
                // Align keeps the pairs together; the pager would stack
                // each child of a bare Wrap.
                Align(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _Pair('츄르', '${pending!.progress['credits']}'),
                      _Pair('출격', '${pending!.progress['runs']}'),
                      _Pair(
                        '항로',
                        '${(pending!.progress['selectedStage'] as int) + 1}',
                      ),
                    ],
                  ),
                ),
                gap8,
                GameActionButton(
                  label: '백업 내용으로 복원',
                  primary: true,
                  onPressed: audible(
                    busy ? null : () => confirm(pending!.progress),
                  ),
                ),
              ],
              if (p.previousManualBackup() != null) ...[
                gap12,
                GameActionButton(
                  label: '복원 전 진행으로 되돌리기',
                  icon: Icons.undo,
                  onPressed: audible(
                    busy ? null : () => confirm(p.previousManualBackup()!),
                  ),
                ),
              ],
              gap12,
              GameActionButton(
                key: const Key('backup-details'),
                label: '백업·복원 자세히 보기',
                displayLabel: '자세히',
                icon: Icons.question_mark,
                onPressed: audible(_details),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "label value" inline: a coloured tag and its bold value.
class _Pair extends StatelessWidget {
  const _Pair(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameTag(label, tone: GameTone.sky),
        const SizedBox(width: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: GameUi.body,
            height: 1.3,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

/// Current guest progress against the backup: 츄르 and 출격 per row.
class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.current, required this.backup});
  final List<Object?> current, backup;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    Widget cell(String text, {Color? color, bool bold = true}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        tr(text),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color ?? Colors.white,
          fontSize: bold ? 18 : GameUi.caption,
          height: 1.3,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
        ),
      ),
    );
    return GameInset(
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              const SizedBox(),
              cell('츄르', color: GameTone.sky.color, bold: false),
              cell('출격', color: GameTone.sky.color, bold: false),
            ],
          ),
          TableRow(
            children: [
              Center(child: GameTag('현재', tone: GameTone.muted)),
              for (final v in current) cell('$v'),
            ],
          ),
          TableRow(
            children: [
              Center(child: GameTag('백업', tone: GameTone.gold)),
              for (final v in backup) cell('$v', color: GameTone.gold.color),
            ],
          ),
        ],
      ),
    );
  }
}
