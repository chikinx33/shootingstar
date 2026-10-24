part of 'profile.dart';

class SuspendedSortie {
  const SuspendedSortie(this.runId, this.game, this.savedAt);
  final String runId;
  final GameEngine game;
  final DateTime savedAt;
}

// Corruption detection only. This local record is not a trusted paid ledger.
int _battleChecksum(String text) {
  var value = 5381;
  for (final unit in text.codeUnits) {
    value = ((value << 5) + value + unit) & 0x7fffffff;
  }
  return value;
}

extension BattleSave on Profile {
  bool get supportsBattleSave =>
      !developerMode && !_presentationOnly && _prefs != null;
  bool get hasSuspendedBattle => _suspendedBattle != null;
  String get _battleOwner => online?.ready == true
      ? online!.boundId
      : _prefs?.getString('online.bound') ?? '';

  /// Stored only in the same local write as permanent progress. exportProgress
  /// and cloud backups exclude it, so a checkpoint cannot cross accounts/devices.
  Future<bool> checkpointBattle(String runId, GameEngine game) async {
    if (!supportsBattleSave ||
        game.training ||
        game.finished ||
        _processedRunIds.contains(runId)) {
      return false;
    }
    try {
      final payload = jsonEncode(game.checkpoint());
      if (utf8.encode(payload).length > 2 * 1024 * 1024) {
        throw const FormatException('Checkpoint too large');
      }
      _suspendedBattle = {
        'version': 1,
        'runId': runId,
        'owner': _battleOwner,
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'payload': payload,
        'checksum': _battleChecksum(payload),
      };
      await save();
      battleSaveNotice = saveError == null
          ? null
          : '전투 저장 실패 · 앱을 닫기 전에 다시 저장해 주세요.';
      return saveError == null;
    } catch (_) {
      battleSaveNotice = '전투 상태를 저장하지 못했습니다. 앱을 닫기 전에 다시 시도해 주세요.';
      return false;
    }
  }

  SuspendedSortie? restoreBattle() {
    final value = _suspendedBattle;
    if (value == null) return null;
    try {
      if (value['version'] != 1 || value['owner'] != _battleOwner) {
        throw const FormatException('Account changed');
      }
      final id = value['runId'];
      final payload = value['payload'];
      if (id is! String ||
          id.isEmpty ||
          id.length > 200 ||
          _processedRunIds.contains(id) ||
          payload is! String ||
          utf8.encode(payload).length > 2 * 1024 * 1024 ||
          value['checksum'] != _battleChecksum(payload)) {
        throw const FormatException('Invalid checkpoint');
      }
      final game = BattleCheckpoint.restore(jsonDecode(payload));
      if (game.finished ||
          game.training ||
          !canStage(game.stageIndex) ||
          game.campaignLoop != (game.dailyEntry == null ? campaignLoop : 0)) {
        throw const FormatException('Progress changed');
      }
      if (game.dailyEntry != null) {
        refreshContentClock(DateTime.now());
        final expected = dailyChallenge.begin(game.dailyEntry!.tier);
        if (expected == null ||
            expected.day != game.dailyEntry!.day ||
            expected.seed != game.dailyEntry!.seed ||
            expected.variant != game.dailyEntry!.variant) {
          throw const FormatException('Daily challenge expired');
        }
      }
      final savedAt = DateTime.parse(value['savedAt'] as String);
      game.setPaused(true);
      return SuspendedSortie(id, game, savedAt);
    } catch (_) {
      _suspendedBattle = null;
      battleSaveNotice =
          '이전 전투는 계정·항로·도전 날짜가 바뀌었거나 저장이 손상되어 이어갈 수 없습니다. 영구 진행은 유지됩니다.';
      return null;
    }
  }

  Future<void> discardBattle() async {
    _suspendedBattle = null;
    await save();
  }
}
