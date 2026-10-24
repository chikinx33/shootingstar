import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/profile.dart';
import '../game/engine.dart';
import '../game/presentation_replay.dart';
import 'battle.dart';
import 'components.dart';
import 'arcade_home_widgets.dart';
import 'reward_popup.dart';

/// A fresh, unsaved copy for every rehearsal, including real purchase actions.
class PresentationReplayScreen extends StatefulWidget {
  const PresentationReplayScreen({
    super.key,
    required this.source,
    required this.kind,
  });
  final Profile source;
  final PresentationReplay kind;
  @override
  State<PresentationReplayScreen> createState() =>
      _PresentationReplayScreenState();
}

class _PresentationReplayScreenState extends State<PresentationReplayScreen> {
  late final Profile rehearsal;
  Timer? launchTimer;
  bool busy = false;
  bool get battle => widget.kind.battle;
  @override
  void initState() {
    super.initState();
    rehearsal = Profile.presentationCopy(widget.source);
    rehearsal.credits = 1500;
    rehearsal.gearKeys = 2;
    rehearsal.inventory.removeWhere(
      (g) => !rehearsal.equippedGear.contains(g.id),
    );
    rehearsal.addListener(refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!battle) {
        playReceipt();
      }
    });
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  GameEngine newBattle() {
    final game = buildPresentationReplay(rehearsal, widget.kind);
    launchTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.kind.autoplay) {
        triggerPresentationReplay(game, widget.kind);
        return;
      }
      // Let the route transition finish before short effects begin. Pausing or
      // backgrounding also defers the trigger, so the effect cannot be missed.
      var activeTicks = 0;
      launchTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (!game.paused && ++activeTicks >= 13) {
          timer.cancel();
          triggerPresentationReplay(game, widget.kind);
        }
      });
    });
    return game;
  }

  @override
  void dispose() {
    launchTimer?.cancel();
    rehearsal.removeListener(refresh);
    rehearsal.dispose();
    super.dispose();
  }

  Future<void> playReceipt() async {
    if (busy) return;
    setState(() => busy = true);
    await claimWithRewardPopup(context, rehearsal, () {
      if (widget.kind == PresentationReplay.purchase) {
        return rehearsal.openGearSupply();
      }
      rehearsal.credits += 120;
      rehearsal.gearKeys += 2;
      rehearsal.contentChanged();
      return true;
    }, title: widget.kind == PresentationReplay.purchase ? '구매 완료' : '보상 획득');
    if (mounted) setState(() => busy = false);
  }

  void restart() => Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) =>
          PresentationReplayScreen(source: widget.source, kind: widget.kind),
    ),
  );
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(widget.kind.label), textAlign: TextAlign.center),
        leading: IconButton(
          tooltip: tr('테스트로 돌아가기'),
          icon: const RasterIcon(Icons.arrow_back, size: 28),
          onPressed: audible(() => Navigator.of(context).pop()),
        ),
        actions: [
          IconButton(
            tooltip: tr('다시 재현'),
            key: const Key('replay-again'),
            onPressed: audible(busy ? null : restart),
            icon: const RasterIcon(Icons.replay, size: 28),
          ),
        ],
      ),
      body: battle
          ? BattleScreen(
              profile: rehearsal,
              engineFactory: newBattle,
              presentationAutoplay: widget.kind.autoplay,
            )
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ResourceCounter(
                          image: CurrencyArt.churu,
                          label: '츄르',
                          value: rehearsal.credits,
                          onTap: audible(() {})!,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ResourceCounter(
                          image: CurrencyArt.gearTicket,
                          label: '장비 보급권',
                          value: rehearsal.gearKeys,
                          onTap: audible(() {})!,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr('연출 재현 · 기존 저장에 반영되지 않습니다.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  if (widget.kind == PresentationReplay.purchase &&
                      rehearsal.inventory.isNotEmpty) ...[
                    RewardTarget(
                      name: rehearsal.inventory.last.definition.name,
                      child: RewardIcon(
                        entry: RewardEntry(
                          rehearsal.inventory.last.definition.name,
                          1,
                          Icons.inventory_2,
                          atlas: 'equipment',
                          index: rehearsal.inventory.last.spec,
                        ),
                        size: 64,
                      ),
                    ),
                    Text(
                      tr(rehearsal.inventory.last.definition.name),
                      style: const TextStyle(fontSize: 16),

                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Center(
                    child: GameActionButton(
                      label: '다시 재현',
                      primary: true,
                      icon: Icons.replay,
                      onPressed: audible(busy ? null : restart),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
