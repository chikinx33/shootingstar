import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/ship_sprite_art.dart';

import '../art/module_aircraft_art.dart';
import '../data/ship_modules.dart';
import '../data/profile.dart';
import '../data/content.dart';
import '../l10n/app_language.dart';
import 'components.dart';
import 'audio_feedback.dart';
import 'item_slots.dart';
import 'ship_hangar.dart';
import 'hangar_presets.dart';
import 'flight_history_screen.dart';
import 'supporter_screen.dart';

class ModuleAircraftPreview extends StatefulWidget {
  const ModuleAircraftPreview({
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
  State<ModuleAircraftPreview> createState() => _ModuleAircraftPreviewState();
}

class _ModuleAircraftPreviewState extends State<ModuleAircraftPreview> {
  bool sockets = false;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: AnimatedBuilder(
      animation: widget.profile,
      builder: (context, _) => Column(
        children: [
          SizedBox(
            height: 48,
            child: IconButton(
              key: const Key('lobby-slot-eye'),
              tooltip: tr(sockets ? '슬롯 숨기기' : '슬롯 표시'),
              onPressed: audible(() => setState(() => sockets = !sockets)),
              icon: Icon(
                sockets ? Icons.visibility : Icons.visibility_off_outlined,
                color: sockets ? const Color(0xffffd43d) : Colors.white,
                size: 28,
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final extent = math.max(
                  0.0,
                  math.min(box.maxWidth / 1.12, box.maxHeight / 1.12),
                );
                final origin =
                    box.biggest.center(Offset.zero) -
                    Offset(extent / 2, extent / 2);
                final snap = widget.profile.moduleLoadout;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        key: const Key('lobby-ship-select'),
                        excludeFromSemantics: true,
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (event) {
                          if (!sockets) {
                            audible(widget.onSelectShip)!();
                            return;
                          }
                          final local = (event.localPosition - origin) / extent;
                          if (const Rect.fromLTWH(
                            .43,
                            .05,
                            .14,
                            .21,
                          ).contains(local))
                            return;
                          String? nearest;
                          var distance = double.infinity;
                          for (final m in moduleProfiles.where((m) => m.weapon))
                            for (final at in ModuleGeometry.anchors(m.id)) {
                              final center = origin + at * extent,
                                  d = (center - event.localPosition).distance;
                              if (d < math.max(24, extent * .13) &&
                                  d < distance) {
                                nearest = m.id;
                                distance = d;
                              }
                            }
                          if (nearest != null)
                            showModulePicker(context, widget.profile, nearest);
                        },
                        // The authored part sprites; the socket view keeps the
                        // mount geometry used for picking weapon bays.
                        child: sockets
                            ? CustomPaint(
                                painter: _ModulePreviewPainter(snap, extent),
                              )
                            : ShipSprite(
                                hull: snap.hull,
                                loadout: snap,
                                assets: widget.profile.shipLayerAssets,
                                semanticLabel: tr('기체 선택'),
                              ),
                      ),
                    ),
                    if (sockets)
                      for (final m in moduleProfiles.where((m) => m.weapon))
                        for (
                          var side = 0;
                          side < ModuleGeometry.anchors(m.id).length;
                          side++
                        )
                          Positioned.fromRect(
                            rect: Rect.fromCenter(
                              center:
                                  origin +
                                  ModuleGeometry.anchors(m.id)[side] * extent,
                              width: math.max(
                                48,
                                ModuleGeometry.size(m.id).width * extent,
                              ),
                              height: math.max(
                                48,
                                ModuleGeometry.size(m.id).height * extent,
                              ),
                            ),
                            child: Semantics(
                              button: side == 0,
                              excludeSemantics: true,
                              label: side == 0
                                  ? tr('${m.id} ${m.name} 모듈')
                                  : null,
                              onTap: side == 0
                                  ? audible(
                                      () => showModulePicker(
                                        context,
                                        widget.profile,
                                        m.id,
                                      ),
                                    )
                                  : null,
                              child: IgnorePointer(
                                child: Center(
                                  child: Container(
                                    width:
                                        ModuleGeometry.size(m.id).width *
                                        extent,
                                    height:
                                        ModuleGeometry.size(m.id).height *
                                        extent,
                                    key: ValueKey(
                                      'module-socket-${m.id}-$side',
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0xff71e2fb),
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    alignment: Alignment.bottomCenter,
                                    child: Text(
                                      m.id,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        backgroundColor: Color(0xdd172a40),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ],
                );
              },
            ),
          ),
          SizedBox(
            height: 60,
            child: !sockets
                ? const SizedBox()
                : Row(
                    children: [
                      for (final m in moduleProfiles.where((m) => !m.weapon))
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Semantics(
                              button: true,
                              excludeSemantics: true,
                              label: tr('${m.id} 보조 슬롯'),
                              onTap: audible(
                                () => showModulePicker(
                                  context,
                                  widget.profile,
                                  m.id,
                                ),
                              ),
                              child: FilledButton(
                                style: GameUi.compactButton.copyWith(
                                  padding: const WidgetStatePropertyAll(
                                    EdgeInsets.zero,
                                  ),
                                ),
                                onPressed: audible(
                                  () => showModulePicker(
                                    context,
                                    widget.profile,
                                    m.id,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.profile.moduleLoadout.parts[m.id]
                                        case final part?)
                                      ModulePartIcon(part.definition, size: 28)
                                    else
                                      const Icon(Icons.add, size: 24),
                                    Text(
                                      m.id,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ],
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

class _ModulePreviewPainter extends CustomPainter {
  const _ModulePreviewPainter(this.snapshot, this.extent);
  final ModuleSnapshot snapshot;
  final double extent;
  @override
  void paint(Canvas c, Size size) =>
      ModuleAircraftArt.paint(c, size.center(Offset.zero), extent, snapshot);
  @override
  bool shouldRepaint(_ModulePreviewPainter old) =>
      old.snapshot != snapshot || old.extent != extent;
}

Future<void> showModulePicker(
  BuildContext context,
  Profile p,
  String mount,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AnimatedBuilder(
    animation: p,
    builder: (context, _) {
      final profile = mountProfile(mount), snap = p.moduleLoadout;
      final items =
          p.shipModules.owned.values
              .where((i) => i.definition.weapon == profile.weapon)
              .toList()
            ..sort((a, b) => b.level.compareTo(a.level));
      return GameDialog(
        title: '$mount · ${profile.name}',
        child: SizedBox(
          height: math.min(360, MediaQuery.sizeOf(context).height * .48),
          child: GameSlotList(
            listKey: const Key('module-owned-parts'),
            children: [
              if (items.isEmpty)
                GameItemSlot(
                  title: '보유한 부품이 없습니다.',
                  status: '보급에서 파츠를 획득하세요.',
                  image: const Icon(Icons.inventory_2_outlined, size: 48),
                  onTap: null,
                ),
              for (final part in items)
                GameItemSlot(
                  key: ValueKey('module-item-${part.instanceId}'),
                  title: part.definition.name,
                  status: 'Lv.${part.level}',
                  semanticLabel: '${part.instanceId} 파츠 특성',
                  image: ModulePartIcon(part.definition),
                  selected: snap.parts[mount]?.instanceId == part.instanceId,
                  onTap: () =>
                      showModulePartDetail(context, p, mount, part.instanceId),
                ),
              if (snap.parts.containsKey(mount))
                GameItemSlot(
                  title: '해제',
                  image: const Icon(Icons.remove_circle_outline, size: 48),
                  onTap: () {
                    p.equipModule(mount, null);
                    Navigator.pop(dialogContext);
                  },
                ),
            ],
          ),
        ),
      );
    },
  ),
);
Future<void> showModulePartDetail(
  BuildContext context,
  Profile p,
  String mount,
  String id,
) => showDialog<void>(
  context: context,
  builder: (_) => AnimatedBuilder(
    animation: p,
    builder: (context, _) {
      final part = p.shipModules.owned[id],
          m = mountProfile(mount),
          snap = p.moduleLoadout;
      if (part == null)
        return GameDialog(
          title: '분해 완료',
          child: GameActionButton(
            label: '닫기',
            onPressed: () => Navigator.pop(context),
          ),
        );
      final stats = resolvePartStats(part, m), current = snap.parts[mount];
      final before = current == null ? null : resolvePartStats(current, m);
      final same = current?.instanceId == id;
      final from = snap.parts.entries
          .where((e) => e.value.instanceId == id)
          .firstOrNull
          ?.key;
      final duplicate =
          !part.definition.weapon &&
          snap.parts.entries.any(
            (e) =>
                e.key != mount &&
                e.value.partId == part.partId &&
                e.value.instanceId != id,
          );
      final canUpgrade =
          part.level < 40 &&
          p.credits >= p.moduleUpgradeCredits(part.level) &&
          p.blueprints >= p.moduleUpgradePlans(part.level);
      String number(double? v) => v == null ? '—' : v.toStringAsFixed(1);
      return GameDialog(
        title: '파츠 특성',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (part.definition.weapon)
              SizedBox(
                width: 144,
                height: 120,
                child: CustomPaint(
                  painter: _MountDiagram(p.moduleLoadout.hull, mount, part),
                ),
              )
            else
              ModulePartIcon(part.definition, size: 72),
            Text(
              tr('${part.definition.name} · Lv.${part.level}'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            Text(tr(part.definition.effect), textAlign: TextAlign.center),
            Text(tr('$mount · ${m.direction}'), textAlign: TextAlign.center),
            if (part.definition.weapon)
              Text(
                tr(m.roleFor(part.definition.category)),
                textAlign: TextAlign.center,
              ),
            if (!part.definition.weapon)
              Text(
                tr('지원 효율 ${(stats.supportPower * 100).round()}%'),
                textAlign: TextAlign.center,
              ),
            if (part.definition.weapon) ...[
              Text(
                tr('피해 ${number(before?.damage)} → ${number(stats.damage)}'),
                textAlign: TextAlign.center,
              ),
              Text(
                tr(
                  '보스 기본 피해 ${number(before?.bossDamage)} → ${number(stats.bossDamage)}',
                ),
                textAlign: TextAlign.center,
              ),
              if (part.definition.category == PartCategory.drone)
                Text(
                  tr(
                    '드론 체력 ${stats.droneHealth.round()} · 복귀 ${stats.droneRecovery.round()}초',
                  ),
                  textAlign: TextAlign.center,
                ),
              Text(
                tr(
                  '초당 발사 ${number(before?.fireRate)} → ${number(stats.fireRate)}',
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                tr(
                  '발사 수 ${before?.count ?? 0} → ${stats.count} · 관통 +${stats.pierce}',
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                tr(
                  '폭발 범위 ${number(before?.aoe)} → ${number(stats.aoe)} · 사거리 ${stats.range.round()}',
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (from != null && from != mount)
              Text(tr('$from → $mount · 레벨 유지'), textAlign: TextAlign.center),
            if (duplicate)
              Text(tr('같은 보조 부품은 중복 장착할 수 없습니다.'), textAlign: TextAlign.center),
            GameActionButton(
              label: same ? '장착 중' : '장착',
              primary: true,
              icon: Icons.build,
              onPressed: same || duplicate
                  ? null
                  : audible(() {
                      if (p.equipModule(mount, id)) Navigator.pop(context);
                    }),
            ),
            Text(
              tr(
                '${p.moduleUpgradeCredits(part.level)} 츄르 · 별가루 ${p.moduleUpgradePlans(part.level)}',
              ),
              textAlign: TextAlign.center,
            ),
            GameActionButton(
              label: part.level >= 40 ? '최고 레벨' : '파츠 강화',
              icon: Icons.upgrade,
              onPressed: canUpgrade ? audible(() => p.upgradeModule(id)) : null,
            ),
            GameActionButton(
              label: '파츠 분해',
              icon: Icons.recycling,
              onPressed: p.canSalvageModule(id)
                  ? audible(() async {
                      final approved = await showDialog<bool>(
                        context: context,
                        builder: (dialog) => GameDialog(
                          title: '파츠 분해',
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tr(part.definition.name),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                tr(
                                  '${20 + part.level * 5} 츄르 · 별가루 ${1 + part.level ~/ 3}',
                                ),
                                textAlign: TextAlign.center,
                              ),
                              GameActionButton(
                                label: '분해',
                                onPressed: () => Navigator.pop(dialog, true),
                              ),
                              GameActionButton(
                                label: '취소',
                                onPressed: () => Navigator.pop(dialog, false),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (approved == true &&
                          context.mounted &&
                          p.salvageModule(id))
                        Navigator.pop(context);
                    })
                  : null,
            ),
          ],
        ),
      );
    },
  ),
);
Future<void> showAirframeDetails(
  BuildContext context,
  Profile p,
) => showDialog<void>(
  context: context,
  builder: (_) => AnimatedBuilder(
    animation: p,
    builder: (context, _) {
      final snap = p.moduleLoadout, level = snap.airframeLevel;
      return GameDialog(
        title: '기체 정보',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('${ships[p.selectedShip].name} · Lv.$level'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            Text(
              tr('고유 주포 · ${snap.signatureName}'),
              textAlign: TextAlign.center,
            ),
            Text(
              tr('고유 궁극기 · ${snap.ultimateName}'),
              textAlign: TextAlign.center,
            ),
            Text(tr('주포·궁극기는 탈착할 수 없습니다.'), textAlign: TextAlign.center),
            Text(tr('기체 강화는 주포·궁극기·기본 체력을 올립니다.'), textAlign: TextAlign.center),
            Text(
              tr(
                '${p.moduleUpgradeCredits(level)} 츄르 · 별가루 ${p.moduleUpgradePlans(level)}',
              ),
              textAlign: TextAlign.center,
            ),
            GameActionButton(
              label: level >= 40 ? '최고 레벨' : '기체 강화',
              primary: true,
              onPressed:
                  level < 40 &&
                      p.credits >= p.moduleUpgradeCredits(level) &&
                      p.blueprints >= p.moduleUpgradePlans(level)
                  ? audible(p.upgradeAirframe)
                  : null,
            ),
          ],
        ),
      );
    },
  ),
);

class ModuleWorkshop extends StatelessWidget {
  const ModuleWorkshop({
    super.key,
    required this.profile,
    this.embedded = false,
  });
  final Profile profile;
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final body = AnimatedBuilder(
      animation: profile,
      builder: (context, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tr(
                      '${ships[profile.selectedShip].name} · Lv.${profile.moduleLoadout.airframeLevel} · ${profile.credits} 츄르',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: tr('격납고 메뉴'),
                  onOpened: audible(() {}),
                  onCanceled: audible(() {}, cue: 'back'),
                  onSelected: audibleChange((value) {
                    if (value == '파일럿') {
                      showDialog<void>(
                        context: context,
                        builder: (dialog) => GameDialog(
                          title: '파일럿 선택',
                          child: SizedBox(
                            height: 280,
                            child: GameSlotList(
                              children: [
                                for (var i = 0; i < pilots.length; i++)
                                  GameItemSlot(
                                    title: pilots[i].name,
                                    image: const Icon(Icons.person, size: 48),
                                    selected: profile.selectedPilot == i,
                                    onTap: () {
                                      profile.selectPilot(i);
                                      Navigator.pop(dialog);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                      return;
                    }
                    final page = switch (value) {
                      '편성' => HangarPresets(profile: profile),
                      '출격 기록' => FlightHistoryScreen(profile: profile),
                      _ => SupporterScreen(profile: profile),
                    };
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => page),
                    );
                  }),
                  itemBuilder: (_) => [
                    for (final item in ['편성', '파일럿', '출격 기록', '후원 외형'])
                      PopupMenuItem(
                        value: item,
                        child: Text(tr(item), textAlign: TextAlign.center),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: GameUi.compactButton,
                    onPressed: audible(
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ShipHangar(profile: profile),
                        ),
                      ),
                    ),
                    child: Text(tr('기체 선택'), textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: GameUi.compactButton,
                    onPressed: audible(
                      () => showAirframeDetails(context, profile),
                    ),
                    child: Text(tr('기체 정보'), textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GameSlotList(
              listKey: const Key('unified-module-slots'),
              children: [
                for (final mount in moduleProfiles)
                  GameItemSlot(
                    title: '${mount.id} · ${mount.name}',
                    semanticLabel: '${mount.id} 모듈 편집',
                    status: profile.moduleLoadout.parts[mount.id] == null
                        ? '빈 모듈'
                        : 'Lv.${profile.moduleLoadout.parts[mount.id]!.level}',
                    image: profile.moduleLoadout.parts[mount.id] == null
                        ? const Icon(Icons.add, size: 48)
                        : ModulePartIcon(
                            profile.moduleLoadout.parts[mount.id]!.definition,
                          ),
                    onTap: () => showModulePicker(context, profile, mount.id),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              tr('보유 파츠 ${profile.shipModules.owned.length}/240 · 장착 7슬롯'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
    return embedded
        ? body
        : Scaffold(
            appBar: AppBar(
              title: Text(tr('기체 모듈'), textAlign: TextAlign.center),
            ),
            body: body,
          );
  }
}

class _MountDiagram extends CustomPainter {
  const _MountDiagram(this.hull, this.mount, this.part);
  final int hull;
  final String mount;
  final OwnedModulePart part;
  @override
  void paint(Canvas c, Size size) {
    final extent = size.height * .80, center = size.center(Offset.zero);
    ModuleAircraftArt.paint(
      c,
      center,
      extent,
      ModuleSnapshot(hull, 1, {mount: part}),
    );
    final origin = center - Offset(extent / 2, extent / 2);
    final anchors = ModuleGeometry.anchors(mount);
    for (var side = 0; side < anchors.length; side++) {
      final at = origin + anchors[side] * extent;
      final angles = mount == 'W4'
          ? [0.0, math.pi / 2, math.pi, -math.pi / 2]
          : mount == 'W3'
          ? [math.pi - math.pi / 6, math.pi, math.pi + math.pi / 6]
          : [ModuleGeometry.angle(mount, side)];
      for (final angle in angles) {
        final direction = Offset(math.sin(angle), -math.cos(angle)),
            end = at + direction * extent * .22;
        final pen = Paint()
          ..color = const Color(0xff3ce8f2)
          ..strokeWidth = 2.5;
        c.drawLine(at, end, pen);
        final cross = Offset(direction.dy, -direction.dx);
        c.drawLine(end, end - direction * 6 + cross * 4, pen);
        c.drawLine(end, end - direction * 6 - cross * 4, pen);
      }
    }
  }

  @override
  bool shouldRepaint(_MountDiagram old) =>
      old.part != part || old.mount != mount || old.hull != hull;
}
