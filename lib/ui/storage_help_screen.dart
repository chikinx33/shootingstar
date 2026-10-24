import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'game_decor.dart';
import 'package:flutter/services.dart';

import '../app_version.dart';
import '../data/profile.dart';
import 'components.dart';
import 'info_dialog.dart';
import 'progress_backup_screen.dart';

Map<String, dynamic> storageDiagnostics(Profile p) => {
  'version': AppVersion.label,
  'surface': kIsWeb ? 'web' : 'native',
  'createdAt': DateTime.now().toUtc().toIso8601String(),
  'storageAvailable': p.persistsProgress,
  'saveError': p.saveError,
  'signedIn': p.online?.signedIn ?? false,
  'syncReady': p.online?.ready ?? false,
  'recentFlights': p.flightHistory.length,
  'campaignLoop': p.campaignLoop,
  'stage': p.selectedStage + 1,
  'runs': p.runs,
};

class StorageHelpScreen extends StatelessWidget {
  const StorageHelpScreen({super.key, required this.profile});
  final Profile profile;

  void _details(BuildContext context) => showInfoDialog(
    context,
    title: '저장·복구 안내',
    children: const [
      GameSectionTitle('출격과 저장'),
      gap8,
      InfoText('출격은 한 판으로 끝납니다. 전투를 마치거나 귀환하면 보상이 정산되고 진행이 자동 저장됩니다.'),
      gap16,
      GameSectionTitle('저장 충돌과 데이터 삭제'),
      gap8,
      InfoText(
        '두 기기에서 진행했다면 비교해 사용할 쪽을 고르세요. 복구 코드는 따로 보관하세요. 앱·브라우저 데이터를 지우면 기기 백업과 중단 전투도 사라집니다.',
      ),
    ],
  );

  Future<void> _copyDiagnostics(BuildContext context) async {
    try {
      await Clipboard.setData(
        ClipboardData(
          text: const JsonEncoder.withIndent('  ')
              .convert(storageDiagnostics(profile)),
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('진단 정보를 복사했습니다.'), textAlign: TextAlign.center),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('복사하지 못했습니다. 브라우저의 클립보드 권한을 확인하세요.'),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final error = profile.saveError;
    return Scaffold(
      appBar: GameAppBar(title: Text(tr('저장·복구 도움말'), textAlign: TextAlign.center)),
      body: SafeArea(
        // v12.4.3: one page. Step-by-step rules open in the details popup.
        child: GamePages(
          centerContent: true,
          framed: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              tr('게스트 진행은 이 앱·브라우저에 저장됩니다. 기기를 바꾸기 전에 계정으로 동기화하세요.'),
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            gap8,
            Text(
              error == null
                  ? tr('현재 저장 오류가 없습니다.')
                  : message('{0}\n앱을 닫기 전에 저장 공간을 확인하고 저장 후 로비를 다시 시도하세요.', [
                      error,
                    ]),
              style: TextStyle(
                fontSize: 16,
                color: error == null ? null : Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),
            gap16,
            GameActionButton(
              label: '진행 백업·복원',
              icon: Icons.save,
              onPressed: audible(
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ProgressBackupScreen(profile: profile),
                  ),
                ),
              ),
            ),
            gap12,
            GameActionButton(
              label: '진단 정보 복사',
              icon: Icons.copy,
              onPressed: audible(() => _copyDiagnostics(context)),
            ),
            gap8,
            Text(
              tr('버전·저장 상태·항로·출격 횟수만 복사합니다. 닉네임·비밀번호·장비는 넣지 않고 자동 전송하지 않습니다.'),
              style: const TextStyle(fontSize: GameUi.caption),
              textAlign: TextAlign.center,
            ),
            gap12,
            GameActionButton(
              key: const Key('storage-help-details'),
              label: '저장·복구 자세히 보기',
              displayLabel: '자세히',
              icon: Icons.question_mark,
              onPressed: audible(() => _details(context)),
            ),
          ],
        ),
      ),
    );
  }
}
