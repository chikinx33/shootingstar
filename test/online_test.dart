import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/profile.dart';
import 'package:shootingstar/data/cloud_sync.dart';
import 'package:shootingstar/data/online_api.dart';

class FakeApi extends OnlineApi {
  FakeApi() : super(base: 'https://example.invalid');
  Future<Map<String, dynamic>> Function(String, Map<String, dynamic>)? handler;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> setToken(String? value) async {}
  @override
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic> data = const {},
  ]) => handler!(path, data);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('account replacement clears previous achievements and tech', () async {
    final p = await Profile.load();
    p.claimedMissions.add(1);
    p.clearedChallenges.add(0);
    p.equippedTech.add(0);
    await p.replaceProgress(Profile.freshProgress());
    expect(p.claimedMissions, isEmpty);
    expect(p.clearedChallenges, isEmpty);
    expect(p.equippedTech, isEmpty);
    expect(p.exportProgress()['version'], 4);
    expect(
      (p.exportProgress()['content'] as Map).containsKey('guildToken'),
      false,
    );
  });
  test(
    'concurrent local edit is retained while remote read finishes',
    () async {
      final p = await Profile.load(), api = FakeApi();
      final c = CloudSync(p, api: api);
      c.account = {'id': 'one', 'nickname': 'One'};
      c.boundId = 'one';
      c.revision = 1;
      final reply = Completer<Map<String, dynamic>>();
      api.handler = (_, _) => reply.future;
      final sync = c.sync();
      p.credits = 777;
      p.contentChanged();
      reply.complete({
        'revision': 2,
        'updatedAt': 1,
        'profile': Profile.freshProgress(),
      });
      await sync;
      expect(p.credits, 777);
      expect(c.conflict, isNotNull);
      expect(c.dirty, true);
      c.dispose();
    },
  );
  test(
    'CAS conflict holds local progress and explicit cloud choice restores it',
    () async {
      final p = await Profile.load(), api = FakeApi();
      final c = CloudSync(p, api: api);
      c.account = {'id': 'one', 'nickname': 'One'};
      c.boundId = 'one';
      c.revision = 1;
      c.dirty = true;
      p.credits = 800;
      final remote = Profile.freshProgress()..['credits'] = 900;
      api.handler = (path, data) async {
        if (path == 'cloud/write') {
          throw OnlineError(409, {'revision': 2, 'profile': remote});
        }
        return {'revision': 2, 'profile': remote};
      };
      await c.sync();
      expect(c.conflict, isNotNull);
      expect(p.credits, 800);
      await c.resolve(useCloud: true);
      expect(p.credits, 900);
      expect(c.revision, 2);
      expect(c.dirty, false);
      c.dispose();
    },
  );
  test('edits during upload stay dirty for the next upload', () async {
    final p = await Profile.load(), api = FakeApi();
    final c = CloudSync(p, api: api);
    c.account = {'id': 'one', 'nickname': 'One'};
    c.boundId = 'one';
    c.dirty = true;
    final reply = Completer<Map<String, dynamic>>();
    api.handler = (_, _) => reply.future;
    final sync = c.sync();
    p.credits = 550;
    p.contentChanged();
    reply.complete({'revision': 1, 'updatedAt': 1});
    await sync;
    expect(c.dirty, true);
    expect(p.credits, 550);
    expect(c.revision, 1);
    c.dispose();
  });
  test(
    'expired session keeps unsent progress and disables guild identity',
    () async {
      final p = await Profile.load(), api = FakeApi();
      final c = CloudSync(p, api: api);
      c.account = {'id': 'one', 'nickname': 'One'};
      c.boundId = 'one';
      c.dirty = true;
      p.credits = 700;
      p.guildToken = 'account:one';
      api.handler = (_, _) async =>
          throw OnlineError(401, {'error': 'Expired'});
      await c.sync();
      expect(c.signedIn, false);
      expect(c.dirty, true);
      expect(p.credits, 700);
      expect(p.guildToken, isEmpty);
      c.dispose();
    },
  );
  test('startup login defers remote progress until battle ends', () async {
    final p = await Profile.load(), api = FakeApi();
    final c = CloudSync(p, api: api)..inBattle = true;
    final remote = Profile.freshProgress()..['credits'] = 950;
    api.handler = (path, data) async => path == 'auth/me'
        ? {
            'account': {'id': 'one', 'nickname': 'One'},
            'revision': 2,
            'updatedAt': 1,
            'profile': remote,
          }
        : {'revision': 2, 'updatedAt': 1, 'profile': remote};
    await c.initialize();
    expect(p.credits, 150);
    expect(c.deferredSession, isNotNull);
    c.inBattle = false;
    await c.sync();
    expect(p.credits, 950);
    expect(c.signedIn, true);
    c.dispose();
  });
}
