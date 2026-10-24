import '../l10n/app_language.dart';

import 'audio_feedback.dart';
import 'module_workshop.dart';

import 'package:flutter/material.dart';

import 'game_decor.dart';

import '../art/arcade_aircraft.dart';
import '../data/content.dart';
import '../data/profile.dart';
import 'armament_hangar.dart';
import 'catalog_screens.dart';
import 'components.dart';
import 'hangar_presets.dart';
import 'item_slots.dart';
import 'ship_hangar.dart';
import 'aircraft_design_screen.dart';
import 'talent_screen.dart';
import 'flight_history_screen.dart';
import 'supporter_screen.dart';

/// One fixed preparation board. Only selectable pilot/module entries scroll.
class HangarBoard extends StatefulWidget {
  const HangarBoard({super.key, required this.profile});
  final Profile profile;
  @override
  State<HangarBoard> createState() => _HangarBoardState();
}

class _HangarBoardState extends State<HangarBoard> {
  int section = 0;
  Profile get p => widget.profile;

  void open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return ModuleWorkshop(profile: p, embedded: true);
  }

  Widget legacyBuild(BuildContext context) {
    return AnimatedBuilder(
      animation: p,
      builder: (_, _) => Column(
        children: [
          CatalogHeader(
            title: '출격 편성',
            status: section == 1
                ? pilots[p.selectedPilot].name
                : section == 2
                ? equipmentOptions[p.equipment].name
                : '${ships[p.selectedShip].name} · ${armaments[p.activeArmamentIndex].name}',
            icon: Icons.rocket_launch,
            action: IconButton(
              tooltip: tr('성장 길잡이'),
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const RasterIcon(Icons.help_outline, size: 32),
              onPressed: audible(_growthGuide),
            ),
          ),
          CatalogTabs(
            labels: const ['편성', '파일럿', '모듈'],
            selected: section,
            onSelected: audibleChange(
              (value) => setState(() => section = value),
            ),
          ),
          Expanded(
            child: section == 0
                ? GamePages(
                    key: const ValueKey('hangar-preparation'),
                    children: [
                      GameActionButton(
                        label: '기체 조립',
                        icon: Icons.flight,
                        onPressed: audible(
                          () => open(AircraftDesignScreen(profile: p)),
                        ),
                      ),
                      if (!p.developerMode)
                        GameActionButton(
                          label: '후원 외형 미리보기',
                          icon: Icons.auto_awesome,
                          onPressed: audible(
                            () => open(SupporterScreen(profile: p)),
                          ),
                        ),
                      GameActionButton(
                        label: '기체 해금',
                        icon: Icons.lock_open,
                        onPressed: audible(() => open(ShipHangar(profile: p))),
                      ),
                      GameActionButton(
                        label: '주무기 선택·강화',
                        icon: Icons.rocket_launch,
                        onPressed: audible(
                          () => open(ArmamentHangar(profile: p)),
                        ),
                      ),
                      GameActionButton(
                        label: '편성 저장·불러오기',
                        displayLabel: '편성 관리',
                        icon: Icons.save,
                        onPressed: audible(
                          () => open(HangarPresets(profile: p)),
                        ),
                      ),
                      GameActionButton(
                        label: '영구 연구',
                        icon: Icons.school,
                        onPressed: audible(
                          () => open(
                            Scaffold(
                              appBar: GameAppBar(
                                title: Text(
                                  tr('영구 연구'),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              body: TalentScreen(profile: p),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : GameSlotList(
                    listKey: ValueKey('hangar-selection-$section'),
                    children: section == 1
                        ? [
                            for (var i = 0; i < pilots.length; i++)
                              GameItemSlot(
                                title: pilots[i].name,
                                image: ArcadeAircraft(
                                  shipIndex: i % ships.length,
                                  size: 56,
                                ),
                                status: p.selectedPilot == i ? '출격 중' : '고유 모듈',
                                selected: p.selectedPilot == i,
                                semanticLabel: '${pilots[i].name} 파일럿 상세',
                                onTap: audible(() => _pilot(i)),
                              ),
                          ]
                        : [
                            for (var i = 0; i < equipmentOptions.length; i++)
                              GameItemSlot(
                                title: equipmentOptions[i].name,
                                image: RasterIcon(
                                  const [
                                    Icons.shield,
                                    Icons.bolt,
                                    Icons.radar,
                                  ][i],
                                  size: 52,
                                ),
                                status: p.equipment == i ? '장착 중' : '선택 가능',
                                selected: p.equipment == i,
                                semanticLabel:
                                    '${equipmentOptions[i].name} 모듈 상세',
                                onTap: audible(() => _module(i)),
                              ),
                          ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _growthGuide() => showDialog<void>(
    context: context,
    builder: (dialog) => GameDialog(
      title: '성장 길잡이',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.flightHistory.isNotEmpty) ...[
            GameSectionTitle('최근 출격 · ${p.flightHistory.first.outcome}'),
            Text(
              tr(p.flightHistory.first.nextStep),
              textAlign: TextAlign.center,
            ),
            GameActionButton(
              label: '출격 기록과 다음 목표',
              icon: Icons.history,
              onPressed: audible(
                () => Navigator.of(dialog).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FlightHistoryScreen(profile: p),
                  ),
                ),
              ),
            ),
          ],
          const GameSectionTitle('먼저 막힌 이유를 확인하세요'),
          Text(
            tr(
              '피격이 잦다면 선체 연구와 방호 장비, 적이 쌓인다면 화력 연구와 주무기 강화, 회수가 어렵다면 회수 연구를 확인하세요.',
            ),

            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          GameSectionTitle('이번 출격과 영구 성장은 다릅니다'),
          Text(
            tr(
              'R/P/N·특화·스킬 선택은 출격이 끝나면 초기화됩니다. 연구·주무기 강화·장비·펫·테크·유물은 다음 출격에도 적용됩니다.',
            ),

            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          GameSectionTitle('투자를 바꿔 볼 수 있습니다'),
          Text(
            tr(
              '주무기와 장비 강화는 사용 재료를 반환할 수 있습니다. 강화 전에 비용과 효과를 읽고, 다른 구성을 시험할 때 편성 저장을 이용하세요.',
            ),

            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Future<void> _pilot(int id) => showDialog<void>(
    context: context,
    builder: (dialog) => GameDialog(
      title: pilots[id].name,
      actions: [
        GameActionButton(
          label: '파일럿 선택',
          primary: true,
          icon: Icons.check,
          onPressed: audible(() {
            p.selectPilot(id);
            Navigator.pop(dialog);
          }),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr(pilots[id].detail), textAlign: TextAlign.center),
          gap(12),
          Text(
            tr(
              '고유 모듈은 출격 중 강화합니다. 일부 파일럿은 전용 능력 버튼을 사용하며, 공격/보조 슬롯 사용 여부도 다릅니다.',
            ),

            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Future<void> _module(int id) => showDialog<void>(
    context: context,
    builder: (dialog) => GameDialog(
      title: equipmentOptions[id].name,
      actions: [
        GameActionButton(
          label: '모듈 장착',
          primary: true,
          icon: Icons.check,
          onPressed: audible(() {
            p.selectEquipment(id);
            Navigator.pop(dialog);
          }),
        ),
      ],
      child: Text(tr(equipmentOptions[id].detail), textAlign: TextAlign.center),
    ),
  );
}
