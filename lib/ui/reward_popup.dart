import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';

import '../art/toon_assets.dart';
import '../art/menu_art.dart';
import '../art/arcade_aircraft.dart';
import '../data/profile.dart';
import '../data/ship_modules.dart';
import '../art/module_aircraft_art.dart';
import '../data/collection_book.dart';
import '../data/content_catalog.dart';
import 'components.dart';
import 'reward_flight.dart';
import '../services/audio_director.dart';
export 'reward_flight.dart';

class RewardEntry {
  const RewardEntry(
    this.name,
    this.amount,
    this.icon, {
    this.modulePartId,
    this.atlas,
    this.index,
    this.rarity = 3,
  });
  final String? modulePartId;
  final String name;
  final int amount, rarity;
  final IconData icon;
  final String? atlas;
  final int? index;
}

/// View-only receipt: actual positive changes after a successful model action.
/// Closing or rebuilding this widget never calls a claim or writes progress.
class RewardSnapshot {
  RewardSnapshot(Profile p)
    : balances = [
        p.credits,
        p.blueprints,
        p.petFood,
        p.gearKeys,
        p.techKeys,
        p.petEggs,
        p.collections.keys,
        p.seasonXp,
      ],
      gearIds = p.inventory.map((g) => g.id).toSet(),
      tech = [
        for (final ranks in p.techStock) [...ranks],
      ],
      pets = [...p.petLevels],
      shards = [...p.petShards],
      relicShards = [...p.collections.shards],
      relicLevels = [...p.collections.levels],
      gearLevels = {for (final g in p.inventory) g.id: (g.level, g.rank)},
      research = [p.attackLevel, p.hullLevel, p.magnetLevel],
      moduleIds = p.shipModules.owned.keys.toSet();
  final List<int> balances;
  final Set<int> gearIds;
  final Set<String> moduleIds;
  final List<List<int>> tech;
  final List<int> pets, shards, relicShards;
  final List<int> relicLevels;
  final Map<int, (int, int)> gearLevels;
  final List<int> research;

  List<RewardEntry> spent(Profile p) {
    final after = RewardSnapshot(p);
    const names = [
      '츄르',
      '별가루',
      '펫 먹이',
      '장비 보급권',
      '테크 보급권',
      '펫 구조권',
      '수집품 보급권',
      '시즌 XP',
    ];
    const icons = [
      Icons.hexagon,
      Icons.description,
      Icons.pets,
      Icons.vpn_key,
      Icons.precision_manufacturing,
      Icons.favorite,
      Icons.auto_awesome,
      Icons.school,
    ];
    return [
      for (var i = 0; i < balances.length; i++)
        if (balances[i] > after.balances[i])
          RewardEntry(names[i], balances[i] - after.balances[i], icons[i]),
    ];
  }

  List<RewardEntry> improvements(Profile p) => [
    for (var i = 0; i < relicLevels.length; i++)
      if (p.collections.levels[i] > relicLevels[i])
        RewardEntry(
          relicCatalog[i].name,
          1,
          Icons.auto_awesome,
          atlas: 'icons',
          index: [60, 42, 29, 54, 37, 30, 48, 0, 4, 33, 5, 22][i],
        ),
    for (final g in p.inventory)
      if (gearLevels.containsKey(g.id) &&
          (g.level > gearLevels[g.id]!.$1 || g.rank > gearLevels[g.id]!.$2))
        RewardEntry(
          g.definition.name,
          1,
          Icons.inventory_2,
          atlas: 'equipment',
          index: g.spec,
          rarity: g.rank,
        ),
    for (var i = 0; i < 3; i++)
      if ([p.attackLevel, p.hullLevel, p.magnetLevel][i] > research[i])
        RewardEntry(
          ['화력 연구', '선체 연구', '회수 연구'][i],
          1,
          [Icons.bolt, Icons.shield, Icons.radar][i],
        ),
    for (var i = 0; i < pets.length; i++)
      if (p.petLevels[i] > pets[i] && pets[i] > 0)
        RewardEntry(petNames[i], 1, Icons.pets, atlas: 'ships', index: i + 3),
  ];

  List<RewardEntry> earned(Profile p) {
    final after = RewardSnapshot(p);
    const names = [
      '츄르',
      '별가루',
      '펫 먹이',
      '장비 보급권',
      '테크 보급권',
      '펫 구조권',
      '수집품 보급권',
      '시즌 XP',
    ];
    const icons = [
      Icons.hexagon,
      Icons.description,
      Icons.pets,
      Icons.vpn_key,
      Icons.precision_manufacturing,
      Icons.favorite,
      Icons.auto_awesome,
      Icons.school,
    ];
    return [
      for (final part in p.shipModules.owned.values)
        if (!moduleIds.contains(part.instanceId) &&
            !part.instanceId.startsWith('legacy-'))
          RewardEntry(
            part.definition.name,
            1,
            Icons.build,
            modulePartId: part.partId,
          ),
      for (var i = 0; i < balances.length; i++)
        if (after.balances[i] > balances[i])
          RewardEntry(names[i], after.balances[i] - balances[i], icons[i]),
      for (var id = 0; id < relicShards.length; id++)
        if (p.collections.shards[id] > relicShards[id])
          RewardEntry(
            '${relicCatalog[id].name} 조각',
            p.collections.shards[id] - relicShards[id],
            Icons.auto_awesome,
            atlas: 'icons',
            index: [60, 42, 29, 54, 37, 30, 48, 0, 4, 33, 5, 22][id],
          ),
      for (final gear in p.inventory)
        if (!gearIds.contains(gear.id))
          RewardEntry(
            gear.spec < 12
                ? modulePart(legacyModulePartIds[gear.spec]).name
                : '${gear.definition.name} · 보류 보관',
            1,
            Icons.inventory_2,
            modulePartId: gear.spec < 12
                ? legacyModulePartIds[gear.spec]
                : null,
            atlas: 'equipment',
            index: gear.spec,
            rarity: gear.rank,
          ),
      for (var id = 0; id < p.techStock.length; id++)
        for (var rank = 0; rank < p.techStock[id].length; rank++)
          if (p.techStock[id][rank] > tech[id][rank])
            RewardEntry(
              '${techNames[id]} · ${qualityNames[rank]}',
              p.techStock[id][rank] - tech[id][rank],
              Icons.precision_manufacturing,
              atlas: 'icons',
              index: [18, 25, 15, 22, 28, 32, 30, 31][id],
              rarity: rank,
            ),
      for (var id = 0; id < pets.length; id++) ...[
        if (pets[id] == 0 && p.petLevels[id] > 0)
          RewardEntry(
            petNames[id],
            1,
            Icons.pets,
            atlas: 'ships',
            index: 3 + id,
          ),
        if (p.petShards[id] > shards[id])
          RewardEntry(
            '${petNames[id]} 유전자',
            p.petShards[id] - shards[id],
            Icons.pets,
            atlas: 'ships',
            index: 3 + id,
          ),
      ],
    ];
  }
}

Future<void> claimWithRewardPopup(
  BuildContext context,
  Profile profile,
  bool Function() action, {
  String title = '보상 획득',
}) async {
  final before = RewardSnapshot(profile);
  final ok = action();
  if (!context.mounted) return;
  if (!ok) {
    AudioDirector.current?.play('error');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            tr('보상 조건과 수령 상태를 확인하세요.'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    return;
  }
  final entries = before.earned(profile);
  AudioDirector.current?.play('reward');
  final message = profile.lastLoot;
  final origin = context.findRenderObject();
  var from = origin is RenderBox && origin.hasSize
      ? origin.localToGlobal(origin.size.center(Offset.zero))
      : null;
  final receiptKey = GlobalKey();
  await showDialog<void>(
    context: context,
    builder: (dialog) => RewardPopup(
      key: receiptKey,
      entries: entries,
      title: title,
      message: entries.isEmpty ? message : '보상이 저장되었습니다.',
    ),
  );
  if (context.mounted) {
    final receipt = receiptKey.currentContext?.findRenderObject();
    if (receipt is RenderBox && receipt.hasSize) {
      from = receipt.localToGlobal(receipt.size.center(Offset.zero));
    }
    await WidgetsBinding.instance.endOfFrame;
    if (context.mounted) RewardFlights.show(context, entries, from: from);
  }
}

/// Feedback reads the successful change; it never invokes the model action.
void showTransactionFeedback(
  BuildContext context,
  Profile p,
  RewardSnapshot before, {
  RewardEntry? item,
}) {
  final gains = before.earned(p);
  final upgrades = before.improvements(p);
  final costs = before.spent(p);
  if (upgrades.isNotEmpty) {
    AudioDirector.current?.play('upgrade');
  } else if (costs.isNotEmpty) {
    AudioDirector.current?.play('purchase');
  } else if (gains.isNotEmpty || item != null) {
    AudioDirector.current?.play('reward');
  }
  if (gains.isNotEmpty || upgrades.isNotEmpty || item != null) {
    RewardFlights.show(context, [
      ...gains,
      ...upgrades,
      if (item != null &&
          ![...gains, ...upgrades].any((e) => e.name == item.name))
        item,
    ]);
  } else if (costs.isNotEmpty) {
    RewardFlights.show(context, costs, spending: true);
  }
}

class RewardPopup extends StatelessWidget {
  const RewardPopup({
    super.key,
    required this.entries,
    this.title = '보상 획득',
    this.message = '보상이 저장되었습니다.',
  });
  final List<RewardEntry> entries;
  final String title, message;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return GameDialog(
      title: title,
      closeLabel: '보상 닫기',
      actions: [
        GameActionButton(
          label: '확인',
          primary: true,
          icon: Icons.check_circle,
          onPressed: audible(() => Navigator.of(context).pop()),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entries.isNotEmpty) RewardGrid(entries: entries),
          gap(16),
          Text(
            tr(message),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: GameUi.body),
          ),
        ],
      ),
    );
  }
}

class RewardGrid extends StatelessWidget implements GamePageContent {
  const RewardGrid({super.key, required this.entries});
  final List<RewardEntry> entries;
  @override
  List<Widget> pageParts(BuildContext context, double width) {
    final columns =
        MediaQuery.textScalerOf(context).scale(1) > 1.15 || width < 300 ? 2 : 3;
    return [
      for (var start = 0; start < entries.length; start += columns)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: 12),
                Expanded(
                  child: start + c < entries.length
                      ? _card(entries[start + c])
                      : const SizedBox(),
                ),
              ],
            ],
          ),
        ),
    ];
  }

  Widget _card(RewardEntry entry) => RewardReveal(
    child: ToonRarityFrame(
      rank: entry.rarity,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RewardIcon(entry: entry, size: 64),
            gap(8),
            Text(
              message("×{0}", [entry.amount]),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            Text(
              tr(entry.name),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return LayoutBuilder(
      builder: (context, box) => Column(
        mainAxisSize: MainAxisSize.min,
        children: pageParts(context, box.maxWidth),
      ),
    );
  }
}

class RewardIcon extends StatelessWidget {
  const RewardIcon({super.key, required this.entry, this.size = 36});
  final RewardEntry entry;
  final double size;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (entry.modulePartId != null)
            ModulePartIcon(modulePart(entry.modulePartId!), size: size)
          else if (entry.atlas == 'hero')
            ArcadeAircraft(shipIndex: entry.index ?? 0, size: size)
          else if (entry.atlas == 'equipment' && MenuArt.images.isNotEmpty)
            MenuImage(
              entry.index == 1
                  ? 'game/missile'
                  : const [
                      'module-gun',
                      'module-sensor',
                      'module-core',
                      'module-hull',
                      'module-belt',
                      'module-engine',
                    ][gearCatalog[entry.index!.clamp(0, gearCatalog.length - 1)]
                        .slot],
              size: size,
            )
          else if (entry.atlas == 'ships' &&
              (entry.index ?? 0) >= 3 &&
              MenuArt.images.isNotEmpty)
            ToonTile('ships', entry.index!, size: size)
          else if (entry.atlas == 'equipment' && (entry.index ?? 0) >= 12)
            ToonTile(
              'equipment',
              gearCatalog[entry.index!.clamp(0, gearCatalog.length - 1)].slot *
                  2,
              size: size,
            )
          else if (entry.atlas != null)
            ToonTile(entry.atlas!, entry.index!, size: size)
          else
            RasterIcon(entry.icon, size: size),
        ],
      ),
    );
  }
}
