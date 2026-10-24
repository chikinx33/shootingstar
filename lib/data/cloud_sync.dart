import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';
import 'online_api.dart';

class CloudSync extends ChangeNotifier {
  CloudSync(this.profile, {OnlineApi? api}) : api = api ?? OnlineApi() {
    profile.online = this;
  }
  final Profile profile;
  final OnlineApi api;
  SharedPreferences? prefs;
  Map<String, dynamic>? account, conflict, deferredSession;
  int revision = 0, updatedAt = 0;
  bool dirty = false, busy = false, inBattle = false, ready = false;
  String status = '연결 확인 중', boundId = '', recoveryCode = '';
  Timer? debounce, poll;
  bool get signedIn => account != null;
  String get accountId => account?['id'] as String? ?? '';
  String get nickname => account?['nickname'] as String? ?? '';
  Future<void> initialize() async {
    prefs = await SharedPreferences.getInstance();
    boundId = prefs!.getString('online.bound') ?? '';
    revision = prefs!.getInt('online.revision') ?? 0;
    dirty = prefs!.getBool('online.dirty') ?? false;
    profile.guildToken = '';
    try {
      await api.initialize();
      await _accept(await api.post('auth/me'));
    } catch (e) {
      status = e is OnlineError && e.status == 401
          ? '게스트 · 기기에 저장'
          : '오프라인 · 기기에 저장';
    }
    ready = true;
    notifyListeners();
    poll = Timer.periodic(const Duration(seconds: 30), (_) => sync());
  }

  Future<void> _meta() async {
    await prefs?.setString('online.bound', boundId);
    await prefs?.setInt('online.revision', revision);
    await prefs?.setBool('online.dirty', dirty);
  }

  void changed() {
    // Preserve an expired account's unsent progress until it signs in again.
    if (boundId.isNotEmpty || signedIn) {
      dirty = true;
      _meta();
    }
    if (signedIn) {
      status = '기기에 저장 · 동기화 대기';
      notifyListeners();
      debounce?.cancel();
      debounce = Timer(const Duration(seconds: 2), () => sync());
    }
  }

  Future<void> _backup(String key) async {
    await prefs?.setString(
      'online.backup.$key',
      jsonEncode(profile.exportProgress()),
    );
  }

  Future<bool> _apply(
    Map<String, dynamic> value, {
    bool onlyIfClean = false,
  }) async {
    await _backup(boundId.isEmpty ? 'guest' : boundId);
    if (onlyIfClean && (dirty || inBattle || profile.hasSuspendedBattle)) {
      return false;
    }
    await profile.replaceProgress(
      value,
      preserveFlightHistory: boundId.isNotEmpty && boundId == accountId,
    );
    profile.guildToken = signedIn ? 'account:$accountId' : '';
    return true;
  }

  Future<void> _accept(Map<String, dynamic> result) async {
    if (inBattle) {
      deferredSession = result;
      status = '귀환 후 계정 동기화';
      return;
    }
    busy = true;
    try {
      final next = Map<String, dynamic>.from(result['account']);
      final same = boundId == next['id'];
      if (!same) await _backup(boundId.isEmpty ? 'guest' : boundId);
      if (!same && profile.hasSuspendedBattle) await profile.discardBattle();
      account = next;
      if (result['token'] is String) await api.setToken(result['token']);
      recoveryCode = result['recoveryCode'] as String? ?? '';
      final remote = result['profile'];
      if (same && (dirty || profile.hasSuspendedBattle)) {
        if (result['revision'] != revision) {
          conflict = result;
          status = '저장 충돌 · 진행 선택 필요';
        }
      } else {
        if (remote is Map) await _apply(Map<String, dynamic>.from(remote));
        if (!same && remote == null) profile.rebindVerifiedAdCredits();
        revision = result['revision'] as int;
        dirty = remote == null;
      }
      boundId = accountId;
      profile.guildToken = 'account:$accountId';
      profile.guildNickname = nickname;
      updatedAt = result['updatedAt'] as int? ?? 0;
      await _meta();
      notifyListeners();
    } finally {
      busy = false;
      notifyListeners();
    }
    if (conflict == null) await sync();
  }

  Future<void> login(
    String user,
    String password, {
    String? nickname,
    String? recovery,
  }) async {
    if (busy || inBattle) return;
    if (!ready) throw StateError('연결 확인이 끝난 뒤 다시 시도하세요.');
    if (profile.hasSuspendedBattle) {
      throw StateError('중단한 출격을 먼저 이어서 정산하거나 포기한 뒤 계정을 바꿔 주세요.');
    }
    busy = true;
    notifyListeners();
    try {
      final recovering = recovery != null;
      final challenge = recovering
          ? {'salt': OnlineApi.salt()}
          : await api.post('auth/challenge', {'username': user});
      final salt = challenge['salt'] as String;
      final result = await api.post(
        recovering
            ? 'auth/recover'
            : nickname != null
            ? 'auth/register'
            : 'auth/login',
        {
          'username': user,
          'key': await OnlineApi.passwordKey(password, salt),
          'salt': salt,
          'nickname': ?nickname,
          if (recovery != null) 'recoveryCode': recovery.trim(),
        },
      );
      // _accept may upload; release the request lock first.
      busy = false;
      await _accept(result);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> sync() async {
    if (profile.hasSuspendedBattle && !inBattle && !busy) {
      const message = '중단 출격 보관 · 이어하기/정산 후 동기화';
      if (status != message) {
        status = message;
        notifyListeners();
      }
      return;
    }
    if (!inBattle && !busy && deferredSession != null) {
      final value = deferredSession!;
      deferredSession = null;
      await _accept(value);
      return;
    }
    if (!signedIn ||
        busy ||
        inBattle ||
        conflict != null ||
        profile.hasSuspendedBattle) {
      return;
    }
    busy = true;
    status = '동기화 중';
    notifyListeners();
    try {
      if (dirty) {
        final sent = profile.exportProgress(),
            encoded = jsonEncode(profile.exportProgress());
        final result = await api.post('cloud/write', {
          'revision': revision,
          'profile': sent,
        });
        revision = result['revision'] as int;
        updatedAt = result['updatedAt'] as int;
        dirty = encoded != jsonEncode(profile.exportProgress());
        if (result['verifiedAdCredits'] is int) {
          profile.acceptVerifiedAdCredits(result['verifiedAdCredits'] as int);
        }
      } else {
        final result = await api.post('cloud/read');
        if (result['revision'] != revision) {
          // A local edit during this read must never be replaced.
          if (dirty || inBattle) {
            conflict = result;
          } else {
            if (result['profile'] is Map) {
              final applied = await _apply(
                Map<String, dynamic>.from(result['profile']),
                onlyIfClean: true,
              );
              if (!applied) {
                conflict = result;
                return;
              }
            }
            revision = result['revision'] as int;
            updatedAt = result['updatedAt'] as int;
          }
        }
      }
      await profile.save();
      await _meta();
      status = conflict != null
          ? '저장 충돌 · 진행 선택 필요'
          : dirty
          ? '기기에 저장 · 동기화 대기'
          : '클라우드 저장 완료';
    } on OnlineError catch (e) {
      if (e.status == 409) {
        conflict = e.data;
        status = '저장 충돌 · 진행 선택 필요';
      } else if (e.status == 401) {
        account = null;
        profile.guildToken = '';
        status = '로그인 만료 · 기기 진행 보관';
      } else {
        status = e.toString();
      }
    } catch (_) {
      status = '오프라인 · 기기에 저장';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> resolve({required bool useCloud}) async {
    final remote = conflict;
    if (remote == null || busy) return;
    busy = true;
    notifyListeners();
    try {
      await _backup('conflict-device');
      await prefs?.setString(
        'online.backup.conflict-cloud',
        jsonEncode(remote['profile']),
      );
      if (useCloud && remote['profile'] is Map) {
        await _apply(Map<String, dynamic>.from(remote['profile']));
      }
      revision = remote['revision'] as int;
      dirty = !useCloud;
      conflict = null;
      await _meta();
    } finally {
      busy = false;
      notifyListeners();
    }
    await sync();
  }

  Future<void> logout({bool all = false}) async {
    if (profile.hasSuspendedBattle) {
      throw StateError('중단한 출격을 먼저 이어서 정산하거나 포기한 뒤 로그아웃해 주세요.');
    }
    await sync();
    if (dirty || conflict != null || busy) {
      throw StateError('진행 저장 또는 충돌 해결 후 로그아웃해 주세요.');
    }
    busy = true;
    notifyListeners();
    try {
      await api.post(all ? 'auth/logout-all' : 'auth/logout');
      await api.setToken(null);
      await _backup(boundId);
      account = null;
      boundId = '';
      revision = 0;
      dirty = false;
      recoveryCode = '';
      final guest = prefs?.getString('online.backup.guest');
      await profile.replaceProgress(
        guest == null
            ? Profile.freshProgress()
            : Map<String, dynamic>.from(jsonDecode(guest)),
      );
      profile.guildToken = '';
      await _meta();
      status = '게스트 · 기기에 저장';
      notifyListeners();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Destructive account deletion requires the current password and the exact
  /// account name shown in the confirmation screen. Never uploads dirty data.
  Future<void> deleteAccount(
    String password, {
    required String username,
  }) async {
    if (busy || inBattle) throw StateError('진행 중인 작업이 끝난 뒤 다시 시도하세요.');
    if (!ready ||
        !signedIn ||
        username != account?['username'] ||
        password.length < 12 ||
        password.length > 128) {
      throw StateError('현재 계정의 아이디와 비밀번호를 다시 입력하세요.');
    }
    final deletingId = accountId;
    busy = true;
    debounce?.cancel();
    notifyListeners();
    try {
      final challenge = await api.post('auth/challenge', {
        'username': username,
      });
      final key = await OnlineApi.passwordKey(
        password,
        challenge['salt'] as String,
      );
      if (accountId != deletingId) throw StateError('계정이 바뀌었습니다. 다시 확인하세요.');
      final result = await api.post('auth/delete', {
        'username': username,
        'key': key,
      });
      if (result['ok'] != true) throw StateError('계정 삭제 결과를 확인하지 못했습니다.');
      var cleanupFailed = false;
      try {
        await api.setToken(null);
      } catch (_) {
        cleanupFailed = true;
      }
      api.token = null;
      account = null;
      boundId = '';
      revision = 0;
      updatedAt = 0;
      dirty = false;
      conflict = null;
      deferredSession = null;
      recoveryCode = '';
      await profile.replaceProgress(Profile.freshProgress());
      for (final key
          in prefs
                  ?.getKeys()
                  .where(
                    (key) =>
                        key.startsWith('online.backup.') ||
                        key == 'commerce.cosmetic.$deletingId' ||
                        key.startsWith('${Profile.storageKey}.before'),
                  )
                  .toList() ??
              <String>[]) {
        if (!await prefs!.remove(key)) cleanupFailed = true;
      }
      await _meta();
      status = '계정 삭제 완료 · 게스트로 시작';
      if (cleanupFailed || profile.saveError != null) {
        throw StateError(
          '서버 계정은 삭제됐지만 기기 데이터 정리를 마치지 못했습니다. 저장·복구 도움말을 확인하고 앱 데이터를 지워 주세요.',
        );
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    poll?.cancel();
    api.client.close();
    super.dispose();
  }
}
