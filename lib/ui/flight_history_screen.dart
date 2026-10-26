import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import 'game_decor.dart';

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
      appBar: GameAppBar(title: Text(tr('출격 기록'), textAlign: TextAlign.center)),
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
              status: message('{0}순환', [record.loop + 1]),
            ),
            // v12.14: the run's numbers in labelled tiles, the last hit and
            // the next goal as tagged blocks, damage as name | amount rows.
            const SizedBox(height: 8),
            GameFactRow([
              GameFact('격파', '${record.kills}'),
              GameFact('보스', '${record.bosses}', tone: GameTone.danger),
              GameFact('시간', message('{0}초', [record.seconds])),
              GameFact('Lv', '${record.level}', tone: GameTone.gold),
            ]),
            const SizedBox(height: 8),
            GameInfoBlock(
              label: '마지막 피격',
              tone: GameTone.danger,
              lead: record.cause.isEmpty ? '없음' : record.cause,
            ),
            const SizedBox(height: 8),
            GameInfoBlock(
              label: '다음 출격 목표',
              tone: GameTone.good,
              lead: record.nextStep,
            ),
            if (ranked.isNotEmpty) ...[
              const SizedBox(height: 8),
              GameInset(
                tone: GameTone.sky,
                child: Column(
                  children: [
                    const GameTag('주요 피해 기여', tone: GameTone.sky),
                    const SizedBox(height: 4),
                    for (final e in ranked.take(3))
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tr(
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
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: GameUi.body,
                                height: 1.35,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${e.value.floor()}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: GameTone.gold.color,
                              fontSize: GameUi.body,
                              height: 1.35,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            GameActionButton(
              label: '영구 연구 보기',
              onPressed: audible(
                () => Navigator.of(dialog).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: GameAppBar(
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
