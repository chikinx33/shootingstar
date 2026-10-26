import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/ui_kit.dart';
import 'skill_cards.dart';
import 'game_motion.dart';
import 'game_decor.dart';

import '../art/ship_sprite_art.dart';

import '../data/ship_modules.dart';
import '../data/profile.dart';
import '../data/content.dart';
import '../l10n/app_language.dart';
import '../art/game_icons.dart';
import 'game_slots.dart';
import 'item_info_card.dart';
import 'components.dart';
import 'audio_feedback.dart';
import 'item_slots.dart';
import 'ship_hangar.dart';
import 'hangar_presets.dart';
import 'flight_history_screen.dart';
import 'supporter_screen.dart';

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
                  image: ShipSpriteArt.partSprite(part.definition, 56),
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
      final before = current == null || current.instanceId == id
          ? null
          : resolvePartStats(current, m);
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
      String n(double v) => v.toStringAsFixed(1);
      // v12.15 mobile-RPG item popup: the part in its frame with its level,
      // keyword pills, one icon line per stat ("now → this" in green when
      // it would replace another part), the price over the actions.
      StatLine line(String label, double now, double? was, Color color) =>
          StatLine(
            label: label,
            value: n(now),
            was: was == null ? null : n(was),
            color: color,
          );
      return GameDialog(
        title: '파츠 특성',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ItemHero(
              image: ShipSpriteArt.partSprite(
                part.definition,
                56,
                mount: mount,
              ),
              name: part.definition.name,
              rarity: 2,
              chips: [
                ('Lv.${part.level}/40', const Color(0xFFFFD43D)),
                (mount, const Color(0xFF8FD3FF)),
                if (same) ('장착 중', const Color(0xFF7CE08A)),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 5,
              runSpacing: 4,
              children: [
                for (final t in tr(part.definition.effect).split(' · '))
                  ItemPill(t, const Color(0xFF8FD3FF)),
                ItemPill(m.direction, const Color(0xFF8FD3FF)),
                if (part.definition.weapon)
                  ItemPill(
                    m.roleFor(part.definition.category),
                    const Color(0xFF7CE08A),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (!part.definition.weapon)
              StatGrid([
                StatLine(
                  label: '지원 효율',
                  value: '${(stats.supportPower * 100).round()}%',
                  color: const Color(0xFF7CE08A),
                ),
              ])
            else
              StatGrid([
                line(
                  '피해',
                  stats.damage,
                  before?.damage,
                  const Color(0xFFFF8A5C),
                ),
                line(
                  '보스 피해',
                  stats.bossDamage,
                  before?.bossDamage,
                  const Color(0xFFFF8A5C),
                ),
                line(
                  '초당 발사',
                  stats.fireRate,
                  before?.fireRate,
                  const Color(0xFFFFD43D),
                ),
                StatLine(
                  label: '발사 수',
                  value: '${stats.count}',
                  was: before == null ? null : '${before.count}',
                  color: const Color(0xFF7CC8FF),
                ),
                if (stats.pierce > 0)
                  StatLine(
                    label: '관통',
                    value: '+${stats.pierce}',
                    color: const Color(0xFFD9A8FF),
                  ),
                if (stats.aoe > 0)
                  line(
                    '폭발 범위',
                    stats.aoe,
                    before?.aoe,
                    const Color(0xFFFFD43D),
                  ),
                if (part.definition.category == PartCategory.drone) ...[
                  StatLine(
                    label: '드론 체력',
                    value: '${stats.droneHealth.round()}',
                    color: const Color(0xFF7CE08A),
                  ),
                  StatLine(
                    label: '드론 복귀',
                    value: message('{0}초', [stats.droneRecovery.round()]),
                    color: const Color(0xFF7CE08A),
                  ),
                ],
              ]),
            if (from != null && from != mount) ...[
              const SizedBox(height: 4),
              GameHint('$from → $mount', tone: GameTone.sky),
            ],
            if (duplicate) ...[
              const SizedBox(height: 4),
              const GameHint('보조 부품 중복', tone: GameTone.danger),
            ],
            const SizedBox(height: 8),
            Center(
              child: part.level >= 40
                  ? const ItemPill('최대 레벨', Color(0xFFFFD43D))
                  : CostLabel(
                      churu: p.moduleUpgradeCredits(part.level),
                      stardust: p.moduleUpgradePlans(part.level),
                      affordable: canUpgrade,
                    ),
            ),
            const SizedBox(height: 8),
            GameActionStrip(
              children: [
                GameActionTile(
                  key: const Key('part-detail-equip'),
                  label: same ? '장착 중' : '장착',
                  icon: Icons.check,
                  image: 'assets/art/ui_v13/act_check.webp',
                  primary: !same,
                  onPressed: same || duplicate
                      ? null
                      : () {
                          if (p.equipModule(mount, id)) Navigator.pop(context);
                        },
                ),
                GameActionTile(
                  key: const Key('part-detail-upgrade'),
                  label: part.level >= 40 ? '최고 레벨' : '파츠 강화',
                  displayLabel: '강화',
                  icon: Icons.upgrade,
                  image: 'assets/art/ui_v13/act_upgrade.webp',
                  onPressed: canUpgrade ? () => p.upgradeModule(id) : null,
                ),
                GameActionTile(
                  key: const Key('part-detail-salvage'),
                  label: '파츠 분해',
                  displayLabel: '분해',
                  icon: Icons.recycling,
                  image: 'assets/art/ui_v13/act_dismantle.webp',
                  onPressed: p.canSalvageModule(id)
                      ? () async {
                          final approved = await _confirmPartSalvage(
                            context,
                            part,
                          );
                          if (approved == true &&
                              context.mounted &&
                              p.salvageModule(id))
                            Navigator.pop(context);
                        }
                      : null,
                ),
              ],
            ),
          ],
        ),
      );
    },
  ),
);

/// The salvage confirmation: the part, then its returns as picture slots.
Future<bool?> _confirmPartSalvage(BuildContext context, OwnedModulePart part) =>
    showDialog<bool>(
      context: context,
      builder: (dialog) => GameDialog(
        title: '파츠 분해',
        actions: [
          GameActionButton(
            label: '분해',
            primary: true,
            image: 'assets/art/ui_v13/act_dismantle.webp',
            onPressed: () => Navigator.pop(dialog, true),
          ),
          GameActionButton(
            label: '취소',
            onPressed: () => Navigator.pop(dialog, false),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ItemHero(
              image: ShipSpriteArt.partSprite(part.definition, 48),
              name: part.definition.name,
              chips: [('Lv.${part.level}', const Color(0xFFFFD43D))],
              size: 64,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GameRewardSlot(
                  GameReward(GameIcons.churu, 20 + part.level * 5, '츄르'),
                ),
                const SizedBox(width: 10),
                GameRewardSlot(
                  GameReward(GameIcons.stardust, 1 + part.level ~/ 3, '별가루'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

Future<void> showAirframeDetails(BuildContext context, Profile p) =>
    showDialog<void>(
      context: context,
      builder: (_) => AnimatedBuilder(
        animation: p,
        builder: (context, _) {
          final snap = p.moduleLoadout, level = snap.airframeLevel;
          final canUpgrade =
              level < 40 &&
              p.credits >= p.moduleUpgradeCredits(level) &&
              p.blueprints >= p.moduleUpgradePlans(level);
          // v12.15: the airframe in its frame, its fixed main gun and
          // ultimate as icon lines, the price over the upgrade button
          return GameDialog(
            title: '기체 정보',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ItemHero(
                  image: ShipSprite(hull: p.selectedShip, loadout: snap),
                  name: ships[p.selectedShip].name,
                  rarity: 4,
                  size: 84,
                  chips: [('Lv.$level/40', const Color(0xFFFFD43D))],
                ),
                const SizedBox(height: 8),
                StatGrid([
                  StatLine(
                    label: '고유 주포',
                    value: snap.signatureName,
                    color: const Color(0xFFFF8A5C),
                  ),
                  StatLine(
                    label: '고유 궁극기',
                    value: snap.ultimateName,
                    color: const Color(0xFFD9A8FF),
                  ),
                ]),
                const SizedBox(height: 10),
                Center(
                  child: level >= 40
                      ? const ItemPill('최대 레벨', Color(0xFFFFD43D))
                      : CostLabel(
                          churu: p.moduleUpgradeCredits(level),
                          stardust: p.moduleUpgradePlans(level),
                          affordable: canUpgrade,
                        ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: GameActionButton(
                    label: level >= 40 ? '최고 레벨' : '기체 강화',
                    primary: true,
                    image: 'assets/art/ui_v13/act_upgrade.webp',
                    onPressed: canUpgrade ? audible(p.upgradeAirframe) : null,
                  ),
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
