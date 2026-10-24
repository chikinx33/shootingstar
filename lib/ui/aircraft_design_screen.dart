import 'package:flutter/material.dart';

import 'game_decor.dart';

import '../art/aircraft_assembly_art.dart';
import '../data/aircraft_assembly.dart';
import '../data/content.dart';
import '../data/profile.dart';
import '../l10n/app_language.dart';
import 'audio_feedback.dart';
import 'module_workshop.dart';
import 'components.dart';
import 'item_slots.dart';

/// One saved assembly drives the lobby, hangar and every new sortie.
class AircraftDesignScreen extends StatefulWidget {
  const AircraftDesignScreen({super.key, this.initialHull = 0, this.profile});
  final Profile? profile;
  final int initialHull;
  @override
  State<AircraftDesignScreen> createState() => _AircraftDesignScreenState();
}

class _AircraftDesignScreenState extends State<AircraftDesignScreen> {
  late AircraftAssembly assembly =
      widget.profile?.aircraftAssembly ??
      AircraftAssembly.demo(widget.initialHull);
  bool get live => widget.profile != null;
  bool owns(AircraftPart part) {
    final pet = AircraftAssembly.petKind(part.id);
    return !live || pet < 0 || widget.profile!.petLevels[pet] > 0;
  }

  void change(AircraftAssembly next) {
    if (live && !widget.profile!.setAircraftAssembly(next)) return;
    setState(() => assembly = widget.profile?.aircraftAssembly ?? next);
  }

  late Future<void> ready = AircraftAssemblyArt.load();
  int category = 0, weapon = 0, support = 0;
  static const weaponMounts = [
    AircraftMount.main,
    AircraftMount.auxiliary,
    AircraftMount.wings,
    AircraftMount.rear,
    AircraftMount.ground,
  ];
  static const petMounts = [
    AircraftMount.supportLeft,
    AircraftMount.supportRight,
    AircraftMount.supportRear,
  ];
  AircraftMount get mount => category == 2
      ? AircraftMount.armor
      : category == 3
      ? petMounts[support]
      : weaponMounts[weapon];
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    if (widget.profile != null) return ModuleWorkshop(profile: widget.profile!);
    return Scaffold(
      appBar: GameAppBar(
        title: Text(tr(live ? '기체 조립' : '기체 설계'), textAlign: TextAlign.center),
        actions: [
          IconButton(
            tooltip: tr(live ? '기본 조립 복원' : '부품 모두 해제'),
            onPressed: audible(
              () => change(
                live
                    ? AircraftAssembly.initial(
                        assembly.hull,
                        pets: assembly.parts.values
                            .map(AircraftAssembly.petKind)
                            .where((id) => id >= 0),
                      )
                    : AircraftAssembly(hull: assembly.hull),
              ),
            ),
            icon: const Icon(Icons.layers_clear),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: ready,
        builder: (context, state) {
          if (state.hasError)
            return Center(
              child: GameActionButton(
                label: '그림 다시 불러오기',
                icon: Icons.refresh,
                onPressed: audible(
                  () => setState(() => ready = AircraftAssemblyArt.load()),
                ),
              ),
            );
          if (state.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Text(
                  tr(live ? '자동 저장 · 다음 출격에 적용' : '조립 미리보기 · 실전 미적용'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFFFD461),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Semantics(
                  image: true,
                  label: tr('부품 조합 미리보기'),
                  child: AircraftAssemblyView(
                    key: const Key('assembly-preview'),
                    assembly: assembly,
                  ),
                ),
              ),
              Text(
                tr(ships[assembly.hull].name),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (category != 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Text(
                    tr(
                      assembly.parts[mount] == null
                          ? '빈 장착부'
                          : aircraftPart(assembly.parts[mount]!).detail,
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              _DesignTabs(
                labels: const ['본체', '무장', '방어', '지원'],
                selected: category,
                onSelected: (i) => setState(() => category = i),
                id: 'assembly-category',
              ),
              if (category == 1)
                _DesignTabs(
                  labels: const ['주포', '보조', '날개', '후방', '지상'],
                  selected: weapon,
                  onSelected: (i) => setState(() => weapon = i),
                  id: 'assembly-weapon',
                ),
              if (category == 3)
                _DesignTabs(
                  labels: const ['좌측', '우측', '후방'],
                  selected: support,
                  onSelected: (i) => setState(() => support = i),
                  id: 'assembly-support',
                ),
              Expanded(
                flex: 3,
                child: GameSlotList(
                  listKey: ValueKey(
                    'assembly-list-$category-${category == 1 ? weapon : support}',
                  ),
                  children: [
                    if (category == 0)
                      for (var i = 0; i < 3; i++)
                        GameItemSlot(
                          key: ValueKey('assembly-hull-$i'),
                          title: ships[i].name,
                          status: assembly.hull == i
                              ? '선택됨'
                              : live &&
                                    !widget.profile!.unlockedShips.contains(i)
                              ? '미해금'
                              : '선택 가능',
                          image: SizedBox.square(
                            dimension: 56,
                            child: AircraftAssemblyView(
                              assembly: AircraftAssembly(hull: i),
                            ),
                          ),
                          selected: assembly.hull == i,
                          onTap:
                              !live || widget.profile!.unlockedShips.contains(i)
                              ? () => change(assembly.withHull(i))
                              : null,
                        ),
                    if (category != 0) ...[
                      for (final part in aircraftParts.where(
                        (part) => part.mounts.contains(mount),
                      ))
                        GameItemSlot(
                          key: ValueKey('assembly-part-${part.id}'),
                          title: part.name,
                          semanticLabel:
                              '${tr(part.name)} · ${tr(part.detail)}',
                          status: !owns(part)
                              ? '미보유'
                              : assembly.parts[mount] == part.id
                              ? '장착 중'
                              : assembly.canEquip(mount, part)
                              ? '장착'
                              : '다른 위치 장착',
                          selected: assembly.parts[mount] == part.id,
                          image: AssemblyPartIcon(part),
                          onTap: owns(part) && assembly.canEquip(mount, part)
                              ? () => change(assembly.equip(mount, part.id))
                              : null,
                        ),
                      GameItemSlot(
                        key: const Key('assembly-part-empty'),
                        title: '해제',
                        status: live && mount == AircraftMount.main
                            ? '필수 장착'
                            : '빈 장착부',
                        image: const Icon(
                          Icons.remove_circle_outline,
                          size: 44,
                        ),
                        selected: assembly.parts[mount] == null,
                        onTap: live && mount == AircraftMount.main
                            ? null
                            : () => change(assembly.equip(mount, null)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DesignTabs extends StatelessWidget {
  const _DesignTabs({
    required this.labels,
    required this.selected,
    required this.onSelected,
    required this.id,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final String id;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              key: ValueKey('$id-$i'),
              button: true,
              selected: selected == i,
              label: tr(labels[i]),
              excludeSemantics: true,
              onTap: audible(() => onSelected(i)),
              child: InkWell(
                onTap: audible(() => onSelected(i)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr(labels[i]),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: GameUi.navigationLabel,
                            fontWeight: FontWeight.w900,
                            color: selected == i
                                ? const Color(0xFFFFD461)
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          width: 28,
                          height: 3,
                          child: ColoredBox(
                            color: selected == i
                                ? const Color(0xFFFFD461)
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
