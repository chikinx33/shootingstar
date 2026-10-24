/// Chapter progress is accumulated across failed runs; boss time cannot be farmed.
class RunRewards {
  const RunRewards({
    required this.seconds,
    required this.kills,
    required this.bosses,
    required this.victory,
  });
  final int seconds, kills, bosses;
  final bool victory;
  bool get eligible => seconds >= 30 && kills >= 10;
  int get credits => !eligible
      ? 0
      : seconds ~/ 3 +
            kills.clamp(0, seconds * 2) ~/ 8 +
            bosses * 40 +
            (victory ? 100 : 0);
  int get bonusCaches => bosses + (victory ? 1 : 0);
}
