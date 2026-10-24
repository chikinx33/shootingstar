import 'profile.dart';

class GuildClient {
  GuildClient(this.profile);
  final Profile profile;
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    final online = profile.online;
    if (online == null || !online.signedIn) throw Exception('계정에 먼저 로그인하세요.');
    final value = await online.api.post('guild/$action', data);
    for (final reward in (value['rewards'] as List? ?? [])) {
      profile.acceptServerReward(Map<String, dynamic>.from(reward));
    }
    return value;
  }

  Future<void> syncReports() async {
    for (final report in List<Map<String, dynamic>>.from(
      profile.guildReports,
    )) {
      await call('report', report);
      profile.guildReports.remove(report);
      profile.contentChanged();
    }
  }
}
