import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shootingstar/data/hangar_preset.dart';
import 'package:shootingstar/data/profile.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'six preset slots survive reload, rename, delete and progress replacement',
    () async {
      final p = await Profile.load();
      p.hangarPresets[0] = HangarPreset.capture(p, '첫 저장');
      p.hangarPresets[5] = HangarPreset.capture(p, '마지막 슬롯');
      await p.save();
      final reloaded = await Profile.load();
      expect(reloaded.hangarPresets, hasLength(6));
      expect(reloaded.hangarPresets[0]!.name, '첫 저장');
      expect(reloaded.hangarPresets[1], isNull);
      expect(reloaded.hangarPresets[5]!.name, '마지막 슬롯');
      reloaded.hangarPresets[0] = reloaded.hangarPresets[0]!.renamed('이름 변경');
      reloaded.hangarPresets[5] = null;
      await reloaded.save();
      final renamed = await Profile.load();
      expect(renamed.hangarPresets[0]!.name, '이름 변경');
      expect(renamed.hangarPresets[5], isNull);
      await renamed.replaceProgress(Profile.freshProgress());
      expect(renamed.hangarPresets.every((p) => p == null), isTrue);
    },
  );

  test(
    'capture, rename and serialization deeply isolate saved selections',
    () async {
      final p = await Profile.load();
      p.techStock[0][0] = 1;
      p.equippedTech = {0};
      p.petLevels[1] = 1;
      p.assistingPets = {1};
      final preset = HangarPreset.capture(p, '  보스\n  공략  ');
      expect(preset.name, '보스 공략');
      p.equippedGear[0] = 99;
      p.equippedTech.clear();
      p.assistingPets.clear();
      expect(preset.gearIds.first, 1);
      expect(preset.techIds, [0]);
      expect(preset.assistPets, [1]);
      expect(() => preset.gearIds[0] = 99, throwsUnsupportedError);
      final renamed = preset.renamed('새 이름');
      expect(preset.name, '보스 공략');
      expect(renamed.name, '새 이름');
      final raw = preset.toJson();
      final restored = HangarPreset.restore(jsonDecode(jsonEncode(raw)))!;
      (raw['gearIds'] as List)[0] = 90;
      expect(restored.gearIds.first, 1);
      expect(restored.toJson(), preset.toJson());
      expect(HangarPreset.cleanName('🚀' * 30).runes.length, 24);
    },
  );

  test(
    'applying a valid preset changes selections together without rewards',
    () async {
      final p = await Profile.load();
      p.unlockedShips.add(1);
      p.selectedShip = 1;
      p.selectedPilot = 3;
      p.armamentCollection.unlock('katana');
      p.selectedArmament = 2;
      p.equipment = 1;
      p.techStock[2][0] = 1;
      p.equippedTech = {2};
      final preset = HangarPreset.capture(p, '속공');
      p.selectedShip = 0;
      p.selectedPilot = 0;
      p.selectedArmament = 0;
      p.equipment = 0;
      p.equippedTech = {};
      final credits = p.credits, plans = p.blueprints;
      var notifications = 0;
      p.addListener(() => notifications++);
      expect(preset.apply(p), isTrue);
      expect(
        [p.selectedShip, p.selectedPilot, p.selectedArmament, p.equipment],
        [1, 3, 2, 1],
      );
      expect(p.equippedTech, {2});
      expect(p.credits, credits);
      expect(p.blueprints, plans);
      expect(notifications, 1);
      // A preset carries identities, so it sees the upgraded live item.
      p.item(1)!.level = 7;
      expect(preset.apply(p), isTrue);
      expect(p.gearAt(0).level, 7);
      p.equippedGear[0] = 99;
      expect(preset.gearIds.first, 1);
    },
  );

  test(
    'consumed equipment causes atomic failure and keeps the saved slot',
    () async {
      final p = await Profile.load();
      final preset = HangarPreset.capture(p, '합성 전');
      p.equippedGear[3] = p.grantItem(6)!.id;
      p.inventory.removeWhere((item) => item.id == preset.gearIds[3]);
      p.selectedPilot = 2;
      p.selectedArmament = 3;
      final before = jsonEncode(p.exportProgress());
      var notifications = 0;
      p.addListener(() => notifications++);
      expect(preset.issue(p), contains('장비가 없습니다'));
      expect(preset.apply(p), isFalse);
      expect(jsonEncode(p.exportProgress()), before);
      expect(notifications, 0);
      expect(HangarPreset.restore(preset.toJson()), isNotNull);
    },
  );

  test('unavailable tech and pets reject before all writes', () async {
    final p = await Profile.load();
    p.techStock[0][0] = 1;
    p.equippedTech = {0};
    p.petLevels[1] = 1;
    p.assistingPets = {1};
    final preset = HangarPreset.capture(p, '복합 구성');
    p.equippedTech = {};
    p.techStock[0][0] = 0;
    p.selectedPilot = 4;
    final before = jsonEncode(p.exportProgress());
    expect(preset.issue(p), contains('테크'));
    expect(preset.apply(p), isFalse);
    expect(jsonEncode(p.exportProgress()), before);
    p.techStock[0][0] = 1;
    p.petLevels[1] = 0;
    expect(preset.issue(p), contains('보조 펫'));
    expect(preset.apply(p), isFalse);
    expect(p.selectedPilot, 4);
  });

  test(
    'restore rejects malformed indices, duplicate IDs and overfull tech groups',
    () async {
      final p = await Profile.load();
      final valid = HangarPreset.capture(p, '검증').toJson();
      for (final change in <Map<String, dynamic>>[
        {'ship': -1},
        {'pilot': 9999},
        {'armament': 9999},
        {'equipment': -1},
        {'pet': -2},
        {
          'gearIds': [1, 2, 3, 4, 5],
        },
        {
          'gearIds': [1, 1, 3, 4, 5, 6],
        },
        {
          'techIds': [0, 0],
        },
        {
          'techIds': [0, 1, 2, 3],
        },
        {
          'techIds': [8],
        },
        {
          'assistPets': [0],
        },
        {
          'assistPets': [1, 1],
        },
        {
          'assistPets': [0, 1, 2],
        },
        {'ship': 1.0},
        {'gearIds': 'invalid'},
      ]) {
        expect(
          HangarPreset.restore({...valid, ...change}),
          isNull,
          reason: '$change',
        );
      }
      expect(HangarPreset.restore(null), isNull);
    },
  );

  test('locked ships and equipment in wrong slots cannot be applied', () async {
    final p = await Profile.load();
    final valid = HangarPreset.capture(p, '검증').toJson();
    final ship = HangarPreset.restore({...valid, 'ship': 1})!;
    expect(ship.issue(p), contains('해금'));
    expect(ship.apply(p), isFalse);
    final gear = List<int>.from(valid['gearIds']);
    final first = gear[0];
    gear[0] = gear[1];
    gear[1] = first;
    final invalid = HangarPreset.restore({...valid, 'gearIds': gear})!;
    expect(invalid.issue(p), contains('맞지 않는 장비'));
    expect(invalid.apply(p), isFalse);
    expect(p.selectedShip, 0);
    expect(p.equippedGear, valid['gearIds']);
  });
}
