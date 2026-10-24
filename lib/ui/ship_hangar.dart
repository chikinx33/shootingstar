import '../l10n/app_language.dart';

import 'audio_feedback.dart';
import 'aircraft_design_screen.dart';

import 'package:flutter/material.dart';

import 'reward_popup.dart';

import '../art/arcade_aircraft.dart';
import '../data/content.dart';
import '../data/profile.dart';
import '../data/aircraft_assembly.dart';
import 'components.dart';
import 'detail_widgets.dart';
import 'item_slots.dart';

class ShipHangar extends StatelessWidget {
  const ShipHangar({super.key, required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('기체 선택'), textAlign: TextAlign.center),
        actions: [
          IconButton(
            tooltip: tr('조합형 기체 설계'),
            icon: const Icon(Icons.design_services),
            onPressed: audible(
              () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AircraftDesignScreen(profile: profile),
                ),
              ),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: profile,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                message("장착: {0} · {1} 츄르", [
                  ships[profile.selectedShip].name,
                  profile.credits,
                ]),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),

                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: GameSlotList(
                listKey: const Key('ship-items'),
                children: [
                  for (var i = 0; i < ships.length; i++)
                    GameItemSlot(
                      title: ships[i].name,
                      image: ArcadeAircraft(
                        shipIndex: i,
                        assembly: AircraftAssembly(
                          hull: i,
                          modules: profile.shipModules.preview(i),
                        ),
                        size: 56,
                        semanticLabel: ships[i].name,
                      ),
                      status: profile.unlockedShips.contains(i)
                          ? (profile.selectedShip == i ? '장착 중' : '보유')
                          : '${ships[i].unlockCost} 츄르',
                      selected: profile.selectedShip == i,
                      onTap: audible(
                        () => showDialog<void>(
                          context: context,
                          builder: (_) => AnimatedBuilder(
                            animation: profile,
                            builder: (_, _) => GameDialog(
                              title: ships[i].name,
                              child: _entry(context, i),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entry(BuildContext context, int i) {
    final ship = ships[i];
    final owned = profile.unlockedShips.contains(i);
    final selected = profile.selectedShip == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Surface(
        active: selected,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GameDetailHeader(
              image: ArcadeAircraft(
                shipIndex: i,
                assembly: AircraftAssembly(
                  hull: i,
                  modules: profile.shipModules.preview(i),
                ),
                size: 72,
                semanticLabel: ship.name,
              ),
              title: ship.name,
              status: selected ? '장착 중' : ship.tagline,
            ),
            Text(
              tr(ship.detail),
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message("기본 선체 {0} · 기동 {1} · 화력 {2}%", [
                ship.health.toInt(),
                ship.speed.toInt(),
                (ship.damage * 100).round(),
              ]),
              style: const TextStyle(fontSize: 16),

              textAlign: TextAlign.center,
            ),
            if (!owned) ...[
              const SizedBox(height: 8),
              Text(
                message("영구 해금 {0} 츄르", [ship.unlockCost]),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),

                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            if (!selected)
              Center(
                child: GameActionButton(
                  key: ValueKey('ship-select-$i'),
                  primary: true,
                  label: owned
                      ? '${ship.name} ${selected ? '장착 중' : '선택'}'
                      : '${ship.name} ${ship.unlockCost} 츄르 해금·선택',
                  displayLabel: owned ? (selected ? '장착 중' : '기체 선택') : '해금·선택',
                  icon: owned ? Icons.check_circle : Icons.lock_open,
                  onPressed: audible(
                    selected || (!owned && profile.credits < ship.unlockCost)
                        ? null
                        : () {
                            if (owned || profile.unlockShip(i)) {
                              profile.selectShip(i);
                              RewardFlights.show(context, [
                                RewardEntry(
                                  ship.name,
                                  1,
                                  Icons.rocket_launch,
                                  atlas: 'hero',
                                  index: i,
                                ),
                              ]);
                            }
                          },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
