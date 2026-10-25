import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../app_version.dart';
import 'profile.dart';

class ProgressBackup {
  const ProgressBackup(this.progress, this.createdAt, this.version);
  static const maxBytes = 512 * 1024;
  final Map<String, dynamic> progress;
  final DateTime createdAt;
  final String version;
  static Future<String> _digest(String value) async =>
      (await Sha256().hash(utf8.encode(value))).bytes
          .map((n) => n.toRadixString(16).padLeft(2, '0'))
          .join();

  static Future<String> encode(Profile profile, {DateTime? at}) async {
    if (!profile.canExportProgressBackup) {
      throw StateError('일반 사용자 진행에서 백업해 주세요.');
    }
    final progress = profile.exportProgress();
    final content = progress['content'] as Map;
    for (final key in ['guildToken', 'guildNickname', 'guildReports']) {
      content.remove(key);
    }
    progress['verifiedAdCredits'] = 0;
    final payload = jsonEncode({
      'version': AppVersion.label,
      'createdAt': (at ?? DateTime.now()).toUtc().toIso8601String(),
      'progress': progress,
    });
    final result = jsonEncode({
      'format': 'shootingstar.progress.backup',
      'schema': 1,
      'payload': payload,
      'sha256': await _digest(payload),
    });
    if (utf8.encode(result).length > maxBytes) {
      throw StateError('백업 크기가 제한을 초과했습니다. 계정 저장을 확인해 주세요.');
    }
    return result;
  }

  static Future<ProgressBackup> decode(String text) async {
    if (text.length > maxBytes || utf8.encode(text).length > maxBytes) {
      throw const FormatException('백업 파일은 512 KB 이하여야 합니다.');
    }
    final dynamic file;
    try {
      file = jsonDecode(text);
    } catch (_) {
      throw const FormatException('백업 파일을 읽지 못했습니다.');
    }
    if (file is! Map ||
        file['format'] != 'shootingstar.progress.backup' ||
        file['schema'] != 1 ||
        file['payload'] is! String ||
        file['sha256'] is! String) {
      throw const FormatException('지원하는 수호묘 특공대 백업 파일이 아닙니다.');
    }
    final payload = file['payload'] as String;
    if (await _digest(payload) != file['sha256']) {
      throw const FormatException('백업 내용이 손상되거나 변경됐습니다.');
    }
    final body = jsonDecode(payload);
    if (body is! Map ||
        body['progress'] is! Map<String, dynamic> ||
        body['version'] is! String ||
        !RegExp(r'^v\d+\.\d+\.\d+$').hasMatch(body['version']) ||
        body['createdAt'] is! String) {
      throw const FormatException('백업 형식이 올바르지 않습니다.');
    }
    final date = DateTime.tryParse(body['createdAt']);
    final value = Map<String, dynamic>.from(body['progress']);
    if (date == null ||
        value['version'] != 4 ||
        value['campaignVersion'] != 1 ||
        value['content'] is! Map ||
        value['content']['inventory'] is! List ||
        value['content']['inventory'].length > 246 ||
        value.containsKey('_battle') ||
        value.containsKey('_flights')) {
      throw const FormatException('지원하지 않는 진행 형식입니다.');
    }
    for (final key in ['credits', 'runs', 'totalKills', 'blueprints']) {
      final number = value[key];
      if (number is! int || number < 0 || number > 9999999) {
        throw const FormatException('진행 수치가 올바르지 않습니다.');
      }
    }
    final normalized = Profile.normalizeBackupProgress(value);
    return ProgressBackup(normalized, date.toUtc(), body['version']);
  }
}
