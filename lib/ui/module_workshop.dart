import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/ui_kit.dart';
import 'skill_cards.dart';
import 'game_motion.dart';
import 'game_decor.dart';

import '../art/ship_sprite_art.dart';

import '../art/module_aircraft_art.dart';
import '../data/ship_modules.dart';
import '../data/profile.dart';
import '../data/content.dart';
import '../l10n/app_language.dart';
import 'arcade_home_widgets.dart' show CurrencyArt;
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
      String change(double? was, double now) =>
          was == null || same ? number(now) : '${number(was)} → ${number(now)}';
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
            _NameLevel(part.definition.name, part.level),
            Text(
              tr(part.definition.effect),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.3),
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                GameTag(mount, tone: GameTone.sky),
                GameTag(m.direction, tone: GameTone.sky),
                if (part.definition.weapon)
                  GameTag(
                    m.roleFor(part.definition.category),
                    tone: GameTone.good,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // v12.14: each stat is its own labelled tile; when another part
            // sits here the tile shows "now -> this part".
            if (!part.definition.weapon)
              GameFactRow([
                GameFact(
                  '지원 효율',
                  '${(stats.supportPower * 100).round()}%',
                  tone: GameTone.good,
                ),
              ])
            else ...[
              if (before != null && !same)
                const GameHint('지금 장착 → 이 파츠', tone: GameTone.sky),
              GameFactRow([
                GameFact(
                  '피해',
                  change(before?.damage, stats.damage),
                  tone: GameTone.danger,
                ),
                GameFact(
                  '보스 피해',
                  change(before?.bossDamage, stats.bossDamage),
                  tone: GameTone.danger,
                ),
                GameFact('초당 발사', change(before?.fireRate, stats.fireRate)),
              ]),
              const SizedBox(height: 6),
              GameFactRow([
                GameFact(
                  '발사 수',
                  before == null || same
                      ? '${stats.count}'
                      : '${before.count} → ${stats.count}',
                ),
                GameFact('관통', '+${stats.pierce}'),
                GameFact(
                  '폭발 범위',
                  change(before?.aoe, stats.aoe),
                  tone: GameTone.gold,
                ),
                GameFact('사거리', '${stats.range.round()}'),
              ]),
              if (part.definition.category == PartCategory.drone) ...[
                const SizedBox(height: 6),
                GameFactRow([
                  GameFact(
                    '드론 체력',
                    '${stats.droneHealth.round()}',
                    tone: GameTone.good,
                  ),
                  GameFact(
                    '드론 복귀',
                    message('{0}초', [stats.droneRecovery.round()]),
                    tone: GameTone.good,
                  ),
                ]),
              ],
            ],
            const SizedBox(height: 6),
            if (from != null && from != mount)
              GameHint('$from → $mount · 레벨 유지', tone: GameTone.sky),
            if (duplicate)
              const GameHint('같은 보조 부품은 중복 장착할 수 없습니다.', tone: GameTone.danger),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            _CostRow(
              '강화 비용',
              p.moduleUpgradeCredits(part.level),
              p.moduleUpgradePlans(part.level),
            ),
            const SizedBox(height: 6),
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
                              _NameLevel(part.definition.name, part.level),
                              const SizedBox(height: 8),
                              _CostRow(
                                '분해 시 획득',
                                20 + part.level * 5,
                                1 + part.level ~/ 3,
                                tone: GameTone.good,
                              ),
                              const SizedBox(height: 12),
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
Future<void> showAirframeDetails(BuildContext context, Profile p) =>
    showDialog<void>(
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
                _NameLevel(ships[p.selectedShip].name, level, size: 22),
                const SizedBox(height: 8),
                GameFactRow([
                  GameFact('고유 주포', snap.signatureName, tone: GameTone.danger),
                  GameFact('고유 궁극기', snap.ultimateName, tone: GameTone.gold),
                ]),
                const SizedBox(height: 6),
                const GameHint('주포·궁극기는 탈착할 수 없습니다.'),
                const GameHint(
                  '기체 강화는 주포·궁극기·기본 체력을 올립니다.',
                  tone: GameTone.sky,
                ),
                const SizedBox(height: 8),
                _CostRow(
                  '강화 비용',
                  p.moduleUpgradeCredits(level),
                  p.moduleUpgradePlans(level),
                ),
                const SizedBox(height: 8),
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
                // v12.8: the mechanic cat beside the craft on its pedestal
                const MascotImage(Mascot.hangar, size: 76),
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 96,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              bottom: 0,
                              child: Image.asset(
                                '${UiKit.root}pedestal.webp',
                                width: 112,
                              ),
                            ),
                            Positioned.fill(
                              bottom: 16,
                              child: Bob(
                                height: 4,
                                child: ShipSprite(
                                  hull: profile.selectedShip,
                                  loadout: profile.moduleLoadout,
                                  assets: profile.shipLayerAssets,
                                  semanticLabel: tr('장착한 기체'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // churu already sits in the screen's currency header
                      // (v12.10: one currency, one place)
                      _NameLevel(
                        ships[profile.selectedShip].name,
                        profile.moduleLoadout.airframeLevel,
                        size: 17,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: tr('격납고 메뉴'),
                  onOpened: audible(() {}),
                  onCanceled: audible(() {}, cue: 'back'),
                  onSelected: audibleChange((value) {
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
                    for (final item in ['편성', '출격 기록', '후원 외형'])
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
                        : partIllustration(
                            profile.moduleLoadout.parts[mount.id]!.definition,
                          ),
                    onTap: () => showModulePicker(context, profile, mount.id),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            // the mounts are the slots above; only the owned count is new
            child: Center(
              child: _Count('보유 파츠', '${profile.shipModules.owned.length}/240'),
            ),
          ),
        ],
      ),
    );
    return embedded
        ? body
        : Scaffold(
            appBar: GameAppBar(
              title: Text(tr('기체 모듈'), textAlign: TextAlign.center),
            ),
            body: body,
          );
  }
}

/// A sky tag and its count, kept together on one line.
class _Count extends StatelessWidget {
  const _Count(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      GameTag(label, tone: GameTone.sky),
      const SizedBox(width: 6),
      Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
    ],
  );
}

/// Name with its level as a gold tag beside it.
class _NameLevel extends StatelessWidget {
  const _NameLevel(this.name, this.level, {this.size = 20});
  final String name;
  final int level;
  final double size;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Flexible(
        child: Text(
          tr(name),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w900),
        ),
      ),
      const SizedBox(width: 6),
      GameTag('Lv.$level'),
    ],
  );
}

/// A labelled cost (or gain): tag, then churu and stardust chips.
class _CostRow extends StatelessWidget {
  const _CostRow(
    this.label,
    this.credits,
    this.plans, {
    this.tone = GameTone.gold,
  });
  final String label;
  final int credits, plans;
  final GameTone tone;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 6,
    runSpacing: 4,
    children: [
      GameTag(label, tone: tone),
      GameRewardChip('츄르', credits, image: CurrencyArt.churu),
      GameRewardChip('별가루', plans, image: CurrencyArt.stardust),
    ],
  );
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
