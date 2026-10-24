import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import '../data/profile.dart';
import 'components.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key, required this.profile});
  final Profile profile;
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountState();
}

class _DeleteAccountState extends State<DeleteAccountScreen> {
  final username = TextEditingController(), password = TextEditingController();
  late final String originalUsername, originalId;
  bool deleting = false;
  String? error;
  @override
  void initState() {
    super.initState();
    originalUsername =
        widget.profile.online?.account?['username'] as String? ?? '';
    originalId = widget.profile.online?.accountId ?? '';
    username.addListener(changed);
    password.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  bool get canDelete =>
      !deleting &&
      originalId.isNotEmpty &&
      widget.profile.online?.accountId == originalId &&
      username.text.trim().toLowerCase() == originalUsername &&
      password.text.length >= 12 &&
      password.text.length <= 128;
  Future<void> remove() async {
    if (!canDelete) return;
    FocusScope.of(context).unfocus();
    setState(() {
      deleting = true;
      error = null;
    });
    try {
      await widget.profile.online!.deleteAccount(
        password.text,
        username: originalUsername,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          deleting = false;
          error = e.toString().replaceFirst('Bad state: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return PopScope(
      canPop: !deleting,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('계정 영구 삭제'), textAlign: TextAlign.center),
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: tr('뒤로'),
            onPressed: audible(
              deleting ? null : () => Navigator.of(context).pop(false),
            ),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: GamePages(
            framed: true,
            children: [
              Text(
                message("@{0}", [originalUsername]),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),

                textAlign: TextAlign.center,
              ),
              Text(
                tr(
                  '계정과 클라우드 진행, 저장 이력, 로그인, 길드 가입·기여·보상 기록을 영구 삭제합니다. 복구 코드로도 되돌릴 수 없습니다.',
                ),
                style: TextStyle(fontSize: 16),

                textAlign: TextAlign.center,
              ),
              Text(
                tr(
                  '이 기기의 현재 진행·중단 전투·출격 기록과 임시 진행 백업도 지워집니다. 다른 기기에 남은 로컬 데이터는 해당 기기에서 지워야 합니다.',
                ),
                style: TextStyle(fontSize: 16),

                textAlign: TextAlign.center,
              ),
              Text(
                tr('삭제할 계정의 아이디와 현재 비밀번호를 다시 입력하세요.'),
                style: TextStyle(fontSize: 16),

                textAlign: TextAlign.center,
              ),
              TextField(
                key: const Key('delete-account-user'),
                controller: username,
                enabled: !deleting,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(labelText: tr('아이디 다시 입력')),

                textAlign: TextAlign.center,
              ),
              TextField(
                key: const Key('delete-account-password'),
                controller: password,
                enabled: !deleting,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(labelText: tr('현재 비밀번호')),

                textAlign: TextAlign.center,
              ),
              if (error != null)
                Text(
                  tr(error!),
                  style: const TextStyle(fontSize: 16, color: Colors.orange),

                  textAlign: TextAlign.center,
                ),
              if (deleting)
                Text(
                  tr('삭제를 처리하고 있습니다. 완료 결과가 나올 때까지 기다려 주세요.'),
                  style: TextStyle(fontSize: 16),

                  textAlign: TextAlign.center,
                ),
              GameActionButton(
                label: '계정과 저장 영구 삭제',
                icon: Icons.delete_forever,
                onPressed: audible(canDelete ? remove : null),
              ),
              GameActionButton(
                label: '삭제 취소',
                primary: true,
                onPressed: audible(
                  deleting ? null : () => Navigator.of(context).pop(false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
