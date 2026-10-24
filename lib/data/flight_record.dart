import '../game/world_fields.dart';

/// Local learning history, never a reward claim or cloud/analytics event.
class FlightRecord {
  FlightRecord({
    required this.id,
    required this.stage,
    required this.loop,
    required this.armament,
    required this.level,
    required this.kills,
    required this.seconds,
    required this.bosses,
    required this.victory,
    required this.defeated,
    required this.cause,
    required this.savedAt,
    required Map<String, double> damage,
  }) : damage = Map.unmodifiable(damage);
  final String id, armament, cause;
  final int stage, loop, level, kills, seconds, bosses;
  final bool victory, defeated;
  final DateTime savedAt;
  final Map<String, double> damage;
  String get outcome => victory
      ? '완주'
      : defeated
      ? '격추'
      : '귀환';
  String get nextStep {
    if (victory) {
      return '다음 항로에서 새 편대와 위험을 확인하세요. 다른 특화나 파일럿으로 빌드를 바꿔 볼 수 있습니다.';
    }
    if (cause == '환경 위험') {
      return '${worldTactics[stage ~/ 10]}. 예고가 뜨면 이동할 안전 지점을 먼저 정하세요.';
    }
    if (level < 5 && seconds >= 30) {
      return '경험치 회수가 부족했습니다. 가까운 보석을 회수하고 자석을 찾으세요. 회수 연구와 회수 모듈도 도움이 됩니다.';
    }
    if (cause == '적기 접촉' || cause == '보스 접촉') {
      return '적과 간격을 확보하세요. 선체 연구·방호 모듈·수호자로 접근 피해에 대비할 수 있습니다.';
    }
    if (cause == '레이저') return '충전 중 사선 밖으로 이동하고 보스 코어가 열릴 때 집중 공격하세요.';
    if (!defeated) return '현재 편성을 저장하거나 주무기·영구 연구를 확인한 뒤 다음 출격을 준비하세요.';
    return '탄막이 겹치면 손을 떼어 판단하세요. 이동 경로와 방호를 확보하고 항성포로 돌파하세요.';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'stage': stage,
    'loop': loop,
    'armament': armament,
    'level': level,
    'kills': kills,
    'seconds': seconds,
    'bosses': bosses,
    'victory': victory,
    'defeated': defeated,
    'cause': cause,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'damage': damage,
  };
  static FlightRecord? restore(dynamic raw) {
    try {
      if (raw is! Map ||
          raw['id'] is! String ||
          (raw['id'] as String).isEmpty ||
          (raw['id'] as String).length > 200 ||
          raw['armament'] is! String ||
          (raw['armament'] as String).length > 40 ||
          raw['cause'] is! String ||
          (raw['cause'] as String).length > 80 ||
          raw['victory'] is! bool ||
          raw['defeated'] is! bool ||
          raw['damage'] is! Map) {
        return null;
      }
      int n(String key, int max, {int min = 0}) {
        final v = raw[key];
        if (v is! int || v < min || v > max) throw const FormatException();
        return v;
      }

      final damage = <String, double>{};
      final source = raw['damage'] as Map;
      if (source.length > 64) return null;
      for (final e in source.entries) {
        if (e.key is! String ||
            (e.key as String).length > 80 ||
            e.value is! num ||
            !(e.value as num).isFinite ||
            e.value < 0 ||
            e.value > 1e12) {
          return null;
        }
        damage[e.key] = e.value.toDouble();
      }
      return FlightRecord(
        id: raw['id'],
        stage: n('stage', 99),
        loop: n('loop', 9999),
        armament: raw['armament'],
        level: n('level', 10000, min: 1),
        kills: n('kills', 100000),
        seconds: n('seconds', 86400),
        bosses: n('bosses', 3),
        victory: raw['victory'],
        defeated: raw['defeated'],
        cause: raw['cause'],
        savedAt: DateTime.parse(raw['savedAt']),
        damage: damage,
      );
    } catch (_) {
      return null;
    }
  }
}
