import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/arcade_aircraft.dart';
import '../art/aircraft_assembly_art.dart';
import '../art/gear_art.dart';
import '../data/aircraft_assembly.dart';
import '../data/content_catalog.dart';
import '../data/gear_traits.dart';
import '../data/profile.dart';
import '../l10n/app_language.dart';
import 'audio_feedback.dart';
import 'components.dart';
import 'item_slots.dart';
import 'module_workshop.dart';

/// Hit regions remain centered on the art. Paired pieces resolve to one choice,
/// while equipment and a weapon sharing one physical mount remain selectable.
List<AssemblySocket> hitAircraftSockets(
  Iterable<AssemblySocket> sockets,
  AssemblyViewport view,
  Offset point,
) {
  final hits =
      sockets.where((socket) {
        final rect = view.project(socket.rect);
        return Rect.fromCenter(
          center: rect.center,
          width: math.max(48, rect.width),
          height: math.max(48, rect.height),
        ).contains(point);
      }).toList()..sort(
        (a, b) => (point - view.project(a.rect).center).distanceSquared
            .compareTo((point - view.project(b.rect).center).distanceSquared),
      );
  final unique = <String, AssemblySocket>{};
  for (final hit in hits) unique.putIfAbsent(hit.slotId, () => hit);
  return unique.values.toList();
}

/// The eye switches the assembled showcase to owned, editable hardpoint slots.
/// Slots use the painted component geometry; only owned item lists scroll.
class LobbyAircraft extends StatefulWidget {
  const LobbyAircraft({
    super.key,
    required this.profile,
    required this.width,
    required this.height,
    required this.onSelectShip,
  });
  final Profile profile;
  final double width, height;
  final VoidCallback onSelectShip;
  @override
  State<LobbyAircraft> createState() => _LobbyAircraftState();
}

class _LobbyAircraftState extends State<LobbyAircraft> {
  bool slots = false;
  bool openingSlot = false;
  static const mounts = [
    AircraftMount.main,
    AircraftMount.auxiliary,
    AircraftMount.wings,
    AircraftMount.rear,
    AircraftMount.ground,
    AircraftMount.armor,
  ];
  static const names = ['주포', '보조', '날개', '후방', '지상', '장갑'];
  Profile get p => widget.profile;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return ModuleAircraftPreview(
      profile: p,
      width: widget.width,
      height: widget.height,
      onSelectShip: widget.onSelectShip,
    );
  }

  Widget legacyBuild(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: p,
        builder: (context, _) => Stack(
          children: [
            Positioned.fill(
              top: 52,
              child: LayoutBuilder(
                builder: (context, box) {
                  final assembly = p.aircraftAssembly;
                  final view = AssemblyViewport.layout(
                    box.biggest,
                    assembly,
                    targetSize: 48,
                  );
                  final sockets = AircraftAssemblyArt.sockets(assembly);
                  final physical = <Rect, List<AssemblySocket>>{};
                  for (final socket in sockets) {
                    physical.putIfAbsent(socket.rect, () => []).add(socket);
                  }
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: InkWell(
                          key: const Key('lobby-ship-select'),
                          onTap: slots ? null : audible(widget.onSelectShip),
                          child: ArcadeAircraft(
                            shipIndex: p.selectedShip,
                            assembly: assembly,
                            width: box.maxWidth,
                            height: box.maxHeight,
                            targetSize: 48,
                            semanticLabel: '기체 선택',
                          ),
                        ),
                      ),
                      if (slots) ...[
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (event) => audible(
                              () =>
                                  _selectAt(event.localPosition, sockets, view),
                            )!(),
                          ),
                        ),
                        for (final socket in sockets)
                          _socket(
                            socket,
                            view.project(socket.rect),
                            paint: identical(
                              physical[socket.rect]!.first,
                              socket,
                            ),
                            variants: physical[socket.rect]!.length,
                            onTap: () => _selectAt(
                              view.project(socket.rect).center,
                              sockets,
                              view,
                            ),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    toggled: slots,
                    child: IconButton(
                      key: const Key('lobby-slot-eye'),
                      tooltip: tr(slots ? '슬롯 숨기기' : '슬롯 표시'),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: const Color(0xD0192C40),
                      ),
                      onPressed: audible(() => setState(() => slots = !slots)),
                      icon: Icon(
                        slots
                            ? Icons.visibility
                            : Icons.visibility_off_outlined,
                        size: 28,
                        color: slots ? const Color(0xFFFFD43D) : Colors.white,
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

  String _socketName(AssemblySocket socket) {
    if (socket.gearSlot != null) return slotNames[socket.gearSlot!];
    final mount = socket.mount!;
    final index = mounts.indexOf(mount);
    return index >= 0
        ? names[index]
        : const ['좌측 지원', '우측 지원', '후방 지원'][supportMounts.toList().indexOf(
            mount,
          )];
  }

  void _openSocket(AssemblySocket socket) {
    if (socket.gearSlot != null) {
      _gearList(socket.gearSlot!);
    } else {
      _partList(socket.mount!, _socketName(socket));
    }
  }

  Future<void> _selectAt(
    Offset point,
    List<AssemblySocket> sockets,
    AssemblyViewport view,
  ) async {
    if (openingSlot) return;
    final choices = hitAircraftSockets(sockets, view, point);
    if (choices.isEmpty) return;
    if (choices.length == 1) {
      _openSocket(choices.single);
      return;
    }
    openingSlot = true;
    try {
      final selected = await showDialog<AssemblySocket>(
        context: context,
        builder: (dialogContext) => GameDialog(
          title: '슬롯 선택',
          child: SizedBox(
            height: math.min(320, MediaQuery.sizeOf(context).height * .42),
            child: GameSlotList(
              listKey: const Key('slot-overlap-choices'),
              children: [
                for (final socket in choices)
                  GameItemSlot(
                    key: ValueKey('socket-choice-${socket.slotId}'),
                    title: _socketName(socket),
                    semanticLabel: '${_socketName(socket)} 슬롯 선택',
                    status: socket.gearSlot != null
                        ? '장비'
                        : supportMounts.contains(socket.mount)
                        ? '지원'
                        : '무장',
                    image: _socketImage(socket),
                    onTap: () => Navigator.pop(dialogContext, socket),
                  ),
              ],
            ),
          ),
        ),
      );
      if (mounted && selected != null) _openSocket(selected);
    } finally {
      openingSlot = false;
    }
  }

  Widget _socketImage(AssemblySocket socket) {
    if (socket.gearSlot != null)
      return GearIcon(p.gearAt(socket.gearSlot!).spec);
    final part = p.aircraftAssembly.parts[socket.mount];
    return part == null
        ? const Icon(Icons.add, size: 48)
        : AssemblyPartIcon(aircraftPart(part));
  }

  Widget _socket(
    AssemblySocket socket,
    Rect rect, {
    required bool paint,
    required int variants,
    required VoidCallback onTap,
  }) => Positioned.fromRect(
    rect: Rect.fromCenter(
      center: rect.center,
      width: math.max(48, rect.width),
      height: math.max(48, rect.height),
    ),
    child: Semantics(
      key: ValueKey('socket-${socket.id}'),
      button: true,
      label: tr('${_socketName(socket)} 슬롯'),
      excludeSemantics: true,
      onTap: audible(onTap),
      child: IgnorePointer(
        child: Center(
          child: Container(
            key: ValueKey('socket-outline-${socket.id}'),
            width: rect.width,
            height: rect.height,
            decoration: !paint
                ? null
                : BoxDecoration(
                    color: socket.occupied
                        ? const Color(0x1892D5E8)
                        : const Color(0x60192C40),
                    border: Border.all(
                      color: const Color(0xFF92D5E8),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
            child: !paint
                ? null
                : Stack(
                    children: [
                      if (!socket.occupied)
                        const Center(child: Icon(Icons.add, size: 24)),
                      if (variants > 1)
                        Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            color: const Color(0xFF192C40),
                            child: Text(
                              '$variants',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.1,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFFD43D),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );

  Future<void> _gearList(int slot) => showDialog<void>(
    context: context,
    builder: (_) => AnimatedBuilder(
      animation: p,
      builder: (context, _) {
        final items =
            p.inventory.where((g) => g.definition.slot == slot).toList()..sort(
              (a, b) =>
                  gearBaseContribution(b).compareTo(gearBaseContribution(a)),
            );
        return GameDialog(
          title: slotNames[slot],
          child: SizedBox(
            height: math.min(320, MediaQuery.sizeOf(context).height * .4),
            child: GameSlotList(
              listKey: const Key('slot-owned-equipment'),
              children: [
                for (final item in items)
                  GameItemSlot(
                    key: ValueKey('slot-item-${item.id}'),
                    title: item.definition.name,
                    semanticLabel: '${item.definition.name} 장비 특성',
                    selected: p.equippedGear[slot] == item.id,
                    rarity: item.rank,
                    status: '${qualityNames[item.rank]} · Lv.${item.level}',
                    image: Stack(
                      children: [
                        GearIcon(item.spec),
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: GearComparisonMark(
                            delta:
                                gearBaseContribution(item) -
                                gearBaseContribution(p.gearAt(slot)),
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _gearDetail(item.id),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Future<void> _gearDetail(int id) => showDialog<void>(
    context: context,
    builder: (_) => AnimatedBuilder(
      animation: p,
      builder: (context, _) {
        final g = p.item(id);
        if (g == null) return const SizedBox.shrink();
        final worn = p.gearAt(g.definition.slot), selected = worn.id == g.id;
        final value = gearBaseContribution(g),
            delta = value - gearBaseContribution(worn);
        final basis = g.definition.slot < 3 ? '화력' : '선체';
        return GameDialog(
          title: '장비 특성',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GearIcon(g.spec, size: 72),
              Text(
                tr(g.definition.name),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${tr(qualityNames[g.rank])} · Lv.${g.level}',
                textAlign: TextAlign.center,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GearComparisonMark(delta: delta),
                  Flexible(
                    child: Text(
                      '${tr(basis)} +${(value * 100).toStringAsFixed(1)}% (${delta >= 0 ? '+' : ''}${(delta * 100).toStringAsFixed(1)}%p)',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              Text(tr('기본 수치 기준 · 고유 효과는 별도 비교'), textAlign: TextAlign.center),
              Text(tr(g.definition.perk), textAlign: TextAlign.center),
              Text(
                tr(gearTraitDescription(g.spec)),
                textAlign: TextAlign.center,
              ),
              Text(tr('자동 저장 · 다음 출격에 적용'), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              GameActionButton(
                label: selected ? '장착 중' : '장착',
                key: ValueKey('slot-equip-$id'),
                primary: true,
                onPressed: selected
                    ? null
                    : audible(() {
                        p.equipItem(id);
                        Navigator.pop(context);
                      }),
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _partList(AircraftMount mount, String name) => showDialog<void>(
    context: context,
    builder: (_) => AnimatedBuilder(
      animation: p,
      builder: (context, _) {
        final owned = aircraftParts.where(
          (part) =>
              part.mounts.contains(mount) &&
              (AircraftAssembly.petKind(part.id) < 0 ||
                  p.petLevels[AircraftAssembly.petKind(part.id)] > 0),
        );
        return GameDialog(
          title: name,
          child: SizedBox(
            height: math.min(320, MediaQuery.sizeOf(context).height * .4),
            child: GameSlotList(
              listKey: const Key('slot-owned-parts'),
              children: [
                if (owned.isEmpty)
                  Text(tr('보유한 부품이 없습니다.'), textAlign: TextAlign.center),
                for (final part in owned)
                  GameItemSlot(
                    title: part.name,
                    semanticLabel: '${part.name} 부품 특성',
                    image: AssemblyPartIcon(part),
                    selected: p.aircraftAssembly.parts[mount] == part.id,
                    status: p.aircraftAssembly.parts[mount] == part.id
                        ? '장착 중'
                        : '보유',
                    onTap: () => _partDetail(mount, part),
                  ),
                if (mount != AircraftMount.main &&
                    p.aircraftAssembly.parts[mount] != null)
                  GameItemSlot(
                    title: '해제',
                    image: const Icon(Icons.remove_circle_outline, size: 44),
                    onTap: () => p.setAircraftAssembly(
                      p.aircraftAssembly.equip(mount, null),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Future<void> _partDetail(
    AircraftMount mount,
    AircraftPart part,
  ) => showDialog<void>(
    context: context,
    builder: (_) => AnimatedBuilder(
      animation: p,
      builder: (context, _) {
        final selected = p.aircraftAssembly.parts[mount] == part.id;
        final pet = AircraftAssembly.petKind(part.id);
        return GameDialog(
          title: '부품 특성',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AssemblyPartIcon(part, size: 72),
              Text(
                tr(part.name),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (pet >= 0)
                Text('Lv.${p.petLevels[pet]}', textAlign: TextAlign.center),
              Text(tr(part.detail), textAlign: TextAlign.center),
              Text(tr(moduleRoleDetail(part.id)), textAlign: TextAlign.center),
              Text(tr('기능이 다른 부품 · 특성 비교'), textAlign: TextAlign.center),
              Text(tr('자동 저장 · 다음 출격에 적용'), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              GameActionButton(
                label: selected ? '장착 중' : '장착',
                primary: true,
                onPressed: selected
                    ? null
                    : audible(() {
                        final parts = Map<AircraftMount, String>.of(
                          p.aircraftAssembly.parts,
                        );
                        if (supportMounts.contains(mount))
                          parts.removeWhere(
                            (m, id) =>
                                supportMounts.contains(m) && id == part.id,
                          );
                        parts[mount] = part.id;
                        if (p.setAircraftAssembly(
                          AircraftAssembly(hull: p.selectedShip, parts: parts),
                        ))
                          Navigator.pop(context);
                      }),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class GearComparisonMark extends StatelessWidget {
  const GearComparisonMark({super.key, required this.delta});
  final double delta;
  @override
  Widget build(BuildContext context) => Semantics(
    label: tr(
      delta.abs() < .000001
          ? '성능 동일'
          : delta > 0
          ? '기본 성능 상승'
          : '기본 성능 하락',
    ),
    child: Icon(
      delta.abs() < .000001
          ? Icons.remove
          : delta > 0
          ? Icons.arrow_drop_up
          : Icons.arrow_drop_down,
      size: 32,
      color: delta.abs() < .000001
          ? const Color(0xFFB9D0DF)
          : delta > 0
          ? const Color(0xFF68E786)
          : const Color(0xFFFF6B70),
    ),
  );
}

String moduleRoleDetail(String id) => switch (id) {
  'cannon' => '전방 고정 공격 · 주무장과 R/P/N 강화 적용',
  'turret' => '전방위 공중 조준 · 기본 사격 간격 0.95초',
  'wing' => '좌우 공중 표적 공격 · 기본 사격 간격 1.4초',
  'rear' => '후방 공중 표적 공격 · 기본 사격 간격 1.1초',
  'bomb' => '지상 표적 전용 폭격 · 기본 간격 2초',
  'armor' => '기본 피해 감소 6% · 수호자 강화로 추가 방호',
  'reinforce' => '기본 피해 감소 10% · 수호자 강화로 추가 방호',
  'auxShield' => '2초마다 선체 비례 차폐 생성 · 최대 18%',
  'repair' => '12초마다 최대 선체의 1.8% 회복 · 지원 레벨로 증가',
  'capacitor' => '6초마다 에너지 충전 · 파일럿 대기 1.2초 단축',
  'ward' => '4초마다 최대 선체의 2.5% 차폐 · 상한 22%',
  _ => '',
};
