import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import '../data/profile.dart';
import '../data/flight_record.dart';
import '../data/content.dart';
import '../art/armament_art.dart';
import 'battle_statistics.dart' show damageSourceLabel;
import 'components.dart';
import 'detail_widgets.dart';
import 'item_slots.dart';
import 'talent_screen.dart';
import 'armament_hangar.dart';

class FlightHistoryScreen extends StatelessWidget {
  const FlightHistoryScreen({super.key, required this.profile});
  final Profile profile;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('출격 기록'), textAlign: TextAlign.center)),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              tr('최근 8회 · 이 기기에 보관\n재현·훈련 기록은 저장하지 않습니다.'),
              style: TextStyle(fontSize: 16),

              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: profile.flightHistory.isEmpty
                ? Center(
                    child: Text(
                      tr('출격을 마치면 기록과 다음 목표를 확인할 수 있습니다.'),
                      textAlign: TextAlign.center,
                    ),
                  )
                : GameSlotList(
                    children: [
                      for (final record in profile.flightHistory)
                        GameItemSlot(
                          title:
                              '${record.stage ~/ 10 + 1}-${record.stage % 10 + 1} ${record.outcome}',
                          image: ArmamentArt(record.armament, size: 56),
                          status: 'Lv.${record.level}\n${record.seconds}초',
                          semanticLabel:
                              '${record.stage ~/ 10 + 1}-${record.stage % 10 + 1} ${record.outcome} 출격 기록 상세',
                          onTap: audible(() => _detail(context, record)),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _detail(
    BuildContext context,
    FlightRecord record,
  ) => showDialog<void>(
    context: context,
    builder: (dialog) {
      final ranked = record.damage.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return GameDialog(
        title:
            '${record.stage ~/ 10 + 1}-${record.stage % 10 + 1} ${record.outcome}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GameDetailHeader(
              image: ArmamentArt(record.armament, size: 72),
              title: armaments
                  .firstWhere(
                    (a) => a.id == record.armament,
                    orElse: () => armaments.first,
                  )
                  .name,
              status:
                  '${record.loop + 1}순환 · Lv.${record.level} · ${record.seconds}초',
            ),
            Text(
              message("{0}격파 · 보스 {1}기\n마지막 피격: {2}", [
                record.kills,
                record.bosses,
                record.cause.isEmpty ? "없음" : record.cause,
              ]),
              style: const TextStyle(fontSize: 16),

              textAlign: TextAlign.center,
            ),
            const GameSectionTitle('다음 출격의 목표'),
            Text(
              tr(record.nextStep),
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (ranked.isNotEmpty) ...[
              const GameSectionTitle('주요 피해 기여'),
              for (final e in ranked.take(3))
                Text(
                  message("{0} · {1}", [
                    damageSourceLabel(
                      e.key,
                      pilot: '파일럿',
                      armament: armaments
                          .firstWhere(
                            (a) => a.id == record.armament,
                            orElse: () => armaments.first,
                          )
                          .name,
                    ),
                    e.value.floor(),
                  ]),
                  style: const TextStyle(fontSize: 16),

                  textAlign: TextAlign.center,
                ),
            ],
            GameActionButton(
              label: '영구 연구 보기',
              onPressed: audible(
                () => Navigator.of(dialog).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: Text(tr('영구 연구'), textAlign: TextAlign.center),
                      ),
                      body: TalentScreen(profile: profile),
                    ),
                  ),
                ),
              ),
            ),
            GameActionButton(
              label: '주무기 강화 보기',
              onPressed: audible(
                () => Navigator.of(dialog).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ArmamentHangar(profile: profile),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
