import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import '../data/content.dart';
import '../data/profile.dart';
import 'components.dart';
import 'armament_hangar.dart';

class CombatLoadoutPicker extends StatelessWidget {
  const CombatLoadoutPicker({super.key, required this.profile});
  final Profile profile;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                message("조종사 Lv.{0} · {1}순환", [
                  profile.pilotLevel + 1,
                  profile.campaignLoop + 1,
                ]),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),

                textAlign: TextAlign.center,
              ),
              Text(
                message("영구 화력 +{0}% · 선체 +{1}%", [
                  (profile.pilotDamage * 100).round(),
                  (profile.pilotHull * 100).round(),
                ]),

                textAlign: TextAlign.center,
              ),
              Text(
                message("다음 성장 {0} / {1} XP", [
                  profile.pilotXp,
                  profile.pilotXpNeeded,
                ]),
                style: const TextStyle(fontSize: 14),

                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          tr('독립 주포'),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),

          textAlign: TextAlign.center,
        ),
        Text(
          tr(
            '출격 중 R 연사 · P 출력·굵기 · N 발사 수 획득\n주포는 성장 선택의 6개 무기 슬롯을 사용하지 않습니다.',
          ),
          style: TextStyle(fontSize: 14),

          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          onTap: audible(() {}),
          icon: const RotatedBox(
            quarterTurns: 2,
            child: RasterTile('icons', 60, width: 20, height: 20),
          ),
          key: ValueKey(
            'owned-armament-${profile.activeArmamentIndex}-${profile.armamentCollection.ownedCount}',
          ),
          initialValue: profile.activeArmamentIndex,
          isExpanded: true,
          decoration: InputDecoration(labelText: tr('주포 계열')),
          items: [
            for (int i = 0; i < armaments.length; i++)
              if (profile.armamentCollection.owns(armaments[i].id))
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    tr(armaments[i].name),
                    textAlign: TextAlign.center,
                  ),
                ),
          ],
          onChanged: audibleChange((id) {
            if (id != null) profile.selectArmament(id);
          }),
        ),
        Text(
          tr(armaments[profile.activeArmamentIndex].detail),
          style: const TextStyle(fontSize: 14),

          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        GameActionButton(
          label: '주무기 소유·성장',
          icon: Icons.rocket_launch,
          onPressed: audible(
            () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ArmamentHangar(profile: profile),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<int>(
          onTap: audible(() {}),
          icon: const RotatedBox(
            quarterTurns: 2,
            child: RasterTile('icons', 60, width: 20, height: 20),
          ),
          initialValue: profile.selectedPilot,
          isExpanded: true,
          decoration: InputDecoration(labelText: tr('조종사 고유 모듈')),
          items: [
            for (int i = 0; i < pilots.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(tr(pilots[i].name), textAlign: TextAlign.center),
              ),
          ],
          onChanged: audibleChange((id) {
            if (id != null) profile.selectPilot(id);
          }),
        ),
        Text(
          tr(pilots[profile.selectedPilot].detail),
          style: const TextStyle(fontSize: 14),

          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
