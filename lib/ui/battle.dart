import '../l10n/app_language.dart';

import 'audio_feedback.dart';


import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../data/content.dart';
import '../data/profile.dart';
import '../data/daily_challenge.dart';
import '../game/engine.dart';
import '../game/developer_battle.dart';
import '../game/survival_skills.dart';
import '../game/battle_painter.dart';
import '../services/sound.dart';
import '../main.dart';
import 'components.dart';
import 'battle_hud.dart';
import 'boss_intro_card.dart';
import 'launch_assembly.dart';
import 'ultimate_banner.dart';
import 'lobby_cat_hero.dart';
import '../art/ship_sprite_art.dart';
import '../art/flight_scene_art.dart';
import 'upgrade_slots.dart';
import 'battle_statistics.dart';
import '../art/game_art.dart';
import '../data/campaign_rewards.dart';
import 'campaign_reward_views.dart';
import 'control_settings_screen.dart';
import '../data/houses.dart';
import 'star_cannon_button.dart';
import '../data/control_preferences.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen({
    super.key,
    required this.profile,
    this.training = false,
    this.challenge = false,
    this.dailyEntry,
    this.engineFactory,
    this.developerConfig,
    this.presentationAutoplay = false,
    this.resume,
  });
  final Profile profile;
  final SuspendedSortie? resume;
  final DeveloperBattleConfig? developerConfig;
  final bool training;
  final bool challenge;
  final DailyChallengeEntry? dailyEntry;

  /// Only standalone effect replays bypass the input-release slow motion.
  final bool presentationAutoplay;

  /// Allows isolated QA/replay entrypoints to exercise the real battle UI.
  /// The production app does not supply a factory or read QA URL parameters.
  final GameEngine Function()? engineFactory;
  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late GameEngine game;
  late final Ticker _ticker;
  late final GameSound sound;
  Duration _previous = Duration.zero;
  double _fpsTime = 0, _fps = 0;
  int _fpsFrames = 0;
  final FocusNode _focus = FocusNode();
  final Set<LogicalKeyboardKey> _keys = {};
  Offset? _anchor, _stick;
  int? _pointer;
  bool _rewarded = false;
  bool _returning = false;
  bool _statisticsOpen = false, _hudDetailsOpen = false;
  String? _selectedUpgrade;
  int reward = 0;
  CampaignRewardReceipt? _campaignReceipt;
  String _runId = '';
  double _saveElapsed = 0;
  bool _savingBattle = false, _restored = false;
  String _decisionStamp = '';
  bool get _canCheckpoint =>
      p.supportsBattleSave &&
      !widget.training &&
      widget.engineFactory == null &&
      !widget.presentationAutoplay;
  bool _artLoading = false;
  bool _artError = false;
  String? _adStatus;
  Profile get p => widget.profile;
  bool get controlsLocked => blocked || game.resolvingBoss;
  bool get blocked =>
      _artLoading ||
      _artError ||
      game.paused ||
      game.choices.isNotEmpty ||
      game.finished;
  bool get slowMotion =>
      !widget.presentationAutoplay &&
      !controlsLocked &&
      _pointer == null &&
      _keys.isEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    p.commerce?.addListener(_commerceChanged);
    sound = GameSound(p);
    _newGame(restore: true);
    _artLoading = GameArt.ready && !GameArt.battleReady;
    _loadArt();
    _ticker = createTicker(_tick)..start();
  }

  void _newGame({bool restore = false}) {
    if (p.online != null) p.online!.inBattle = true;
    _adStatus = null;
    _restored = false;
    _runId = DateTime.now().microsecondsSinceEpoch.toString();
    // Equipped cat gear: stats for this run and its sprites on the ship.
    final gear = p.catGear.bonuses;
    ShipSpriteArt.battleAssets = p.shipLayerAssets;
    game =
        widget.engineFactory?.call() ??
        GameEngine(
          stageIndex: widget.dailyEntry?.stageIndex ?? p.selectedStage,
          shipIndex: p.selectedShip,
          aircraft: p.aircraftAssembly,
          supportLevels: p.aircraftSupportLevels,
          attackLevel: 0,
          hullLevel: 0,
          magnetLevel: p.magnetLevel,
          equipmentIndex: -1,
          training: widget.training,
          challenge: widget.challenge,
          gearDamage: p.pilotDamage + gear.damage,
          gearHull: p.pilotHull + gear.hull,
          startingWeapon: 'gun',
          campaignLoop: widget.dailyEntry == null ? p.campaignLoop : 0,
          dailyEntry: widget.dailyEntry,
          armament: p.moduleLoadout.signature,
          armamentLevel: p.moduleLoadout.airframeLevel - 1,
          mainPrecisionLink: false,
          mainCycleLink: false,
          bossSetWorld: -1,
          pilot: pilots[p.selectedPilot].id,
          bonusSpeed: gear.speed,
          bonusPickup: gear.pickup,
          bonusCooldown: 0,
          damageReduction: gear.reduction,
          regeneration: false,
          techRanks: p.battleTech,
          petKind: p.activePet,
          petLevel: p.equippedPetLevel,
          petRank: p.equippedPetRank,
          petAwakePower: p.petBond.powerBonus(p.activePet),
          petAwakeCooldown: p.petBond.cooldownReduction(p.activePet),
        );
    if (restore && widget.resume != null) {
      game = widget.resume!.game;
      _runId = widget.resume!.runId;
      _restored = true;
    }
    game.onEvent = (event) => sound.play(event, armament: game.armament);
    game.visuals.onSound = sound.cue;
    sound.beginFlight(paused: game.paused);
    _saveElapsed = 2;
    _decisionStamp = '';
    _rewarded = false;
    _selectedUpgrade = null;
    reward = 0;
    _campaignReceipt = null;
    p.lastLoot = "";
    _clearInput();
  }

  void _commerceChanged() {
    if (mounted && game.finished) {
      setState(() => _adStatus = p.commerce?.status);
    }
  }

  Future<void> _loadArt() async {
    await RasterAssets.load();
    try {
      await Future.wait([
        GameArt.loadBattle(),
        FlightSceneArt.ensureWorld(game.worldIndex),
        FlightSceneArt.ensureHouse(game.stageIndex),
      ]);
    } catch (_) {
      if (mounted) setState(() => _artError = true);
    } finally {
      if (mounted) setState(() => _artLoading = false);
    }
  }

  void _tick(Duration time) {
    final dt = (time - _previous).inMicroseconds / 1000000;
    _previous = time;
    if (!mounted) return;
    final wasActive = !blocked;
    if (!blocked) {
      sound.startMusic(boss: game.boss != null && !game.finished);
      final dev = p.developerMode ? widget.developerConfig : null;
      if (dev == null) {
        final realStep = dt.clamp(0.0, .05);
        game.update(
          realStep * (slowMotion ? .05 : 1),
          presentationDelta: realStep,
        );
      } else {
        final scaled = dt.clamp(0, .04) * dev.speed;
        final steps = dev.speed.ceil().clamp(1, 4);
        for (var i = 0; i < steps && !blocked; i++) {
          game.update(
            scaled / steps * (slowMotion ? .05 : 1),
            presentationDelta: dt.clamp(0.0, .04) / steps,
          );
          if (dev.autoChoose && game.choices.isNotEmpty) {
            game.chooseUpgrade(game.choices.first.id);
          }
        }
        _fpsTime += dt;
        _fpsFrames++;
        if (_fpsTime >= .5) {
          _fps = _fpsFrames / _fpsTime;
          _fpsTime = 0;
          _fpsFrames = 0;
        }
      }
      if (game.choices.isNotEmpty || game.finished || game.resolvingBoss) {
        _clearInput();
      }
    }
    if (_canCheckpoint &&
        !game.finished &&
        !game.paused &&
        !_artLoading &&
        !_artError) {
      if (wasActive) _saveElapsed += dt.clamp(0.0, .5);
      final stamp =
          '${game.choices.map((c) => c.id).join(',')}/${game.rerolls}/${game.passiveReplacements}';
      if (stamp != _decisionStamp || _saveElapsed >= 2) {
        _decisionStamp = stamp;
        _checkpoint();
      }
    }
    final needsReward = game.finished && !_rewarded;
    if (needsReward) {
      sound.pauseMusic();
      _rewarded = true;
      if (p.online != null) p.online!.inBattle = false;
      if (_canCheckpoint) p.recordFlight(_runId, game);
      reward = widget.dailyEntry != null
          ? p.completeDailyChallenge(
              runId: _runId,
              entry: widget.dailyEntry!,
              victory: game.victory,
              kills: game.kills,
              seconds: game.elapsed.floor(),
              bosses: game.bossesDefeated,
              deployedPet: game.petKind,
            )
          : p.completeRun(
              runId: _runId,
              victory: game.victory,
              stageIndex: game.stageIndex,
              kills: game.kills,
              level: game.level,
              seconds: game.elapsed.floor(),
              bossesDefeated: game.bossesDefeated,
              creditBonus: (game.passives['gold'] ?? 0) * .08,
              training: widget.training,
              challenge: widget.challenge,
              deployedPet: game.petKind,
            );
      if (widget.dailyEntry == null && !widget.training) {
        _campaignReceipt = p.lastCampaignReward;
      }
    }
    if (wasActive || needsReward) setState(() {});
  }

  Future<bool> _checkpoint({bool force = false}) async {
    if (!_canCheckpoint || game.finished) return false;
    if (_savingBattle) {
      if (!force) return false;
      await p.save();
    }
    _saveElapsed = 0;
    _savingBattle = true;
    try {
      final saved = await p.checkpointBattle(_runId, game);
      if (mounted) setState(() {});
      return saved;
    } finally {
      _savingBattle = false;
    }
  }

  Future<void> _saveAndReturn() async {
    if (_returning) return;
    _returning = true;
    _pause();
    final saved = await _checkpoint(force: true);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(false);
    } else {
      setState(() => _returning = false);
    }
  }

  void _clearInput() {
    _keys.clear();
    _anchor = null;
    _stick = null;
    _pointer = null;
    game.input = Offset.zero;
    game.steerTarget = null;
    _dragFinger = null;
    _dragCat = null;
  }

  bool get _followTouch => p.controls.followTouch && game.screenMode;
  bool get _dragSteer => !p.controls.followTouch && game.screenMode;
  Offset? _dragFinger, _dragCat;

  /// Drag steering: the cat moves by the finger slide (scaled), with no
  /// joystick hold-and-drift, so it stops the moment the finger stops.
  void _drag(Offset local, double width) {
    final from = _dragFinger, cat = _dragCat;
    if (from == null || cat == null) return;
    final slide = (local - from) * (420 / width * p.controls.dragScale);
    final wanted = cat + slide;
    final target = game.clampToField(wanted);
    // Pinned at an edge: re-base so reversing responds immediately.
    if (target != wanted) _dragCat = target - slide;
    game.steerTarget = target;
    _stick = local;
  }

  /// Follow-touch steering: the cat flies to just above the finger.
  void _follow(Offset local, double width) {
    final view = local * (420 / width);
    game.steerTarget = game.screenToField(
      view - const Offset(0, ControlPreferences.followLift),
    );
    _stick = local;
  }

  void _pause() {
    if (game.finished) return;
    setState(() {
      game.setPaused(true);
      _clearInput();
      sound.stop();
      sound.play('pause');
    });
    _checkpoint(force: true);
  }

  void _resume() {
    if (_statisticsOpen || _hudDetailsOpen || game.finished) return;
    setState(() {
      game.setPaused(false);
      _clearInput();
      sound.startMusic(boss: game.boss != null);
      sound.play('resume');
    });
    _focus.requestFocus();
  }

  Future<void> _showStatistics() async {
    if (_statisticsOpen || (!game.paused && !game.finished)) return;
    setState(() {
      _statisticsOpen = true;
      _clearInput();
    });
    try {
      final snapshot = BattleStatisticsSnapshot.fromGame(game);
      await showDialog<void>(
        context: context,
        builder: (_) => BattleStatisticsDialog(snapshot: snapshot),
      );
    } finally {
      if (mounted) {
        setState(() {
          _statisticsOpen = false;
          _clearInput();
        });
        _focus.requestFocus();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (_statisticsOpen || _hudDetailsOpen) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space && game.hasCommonUltimate) {
      if (event is KeyDownEvent && !controlsLocked) {
        setState(() {
          game.activateCommonUltimate();
        });
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP) {
      if (event is KeyDownEvent) {
        game.paused ? _resume() : _pause();
      }
      return KeyEventResult.handled;
    }
    final controls = {
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
    };
    if (!controls.contains(key)) return KeyEventResult.ignored;
    if (controlsLocked) {
      _clearInput();
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      _keys.remove(key);
    } else {
      _keys.add(key);
    }
    final x =
        (_keys.contains(LogicalKeyboardKey.keyD) ||
                _keys.contains(LogicalKeyboardKey.arrowRight)
            ? 1.0
            : 0.0) -
        (_keys.contains(LogicalKeyboardKey.keyA) ||
                _keys.contains(LogicalKeyboardKey.arrowLeft)
            ? 1.0
            : 0.0);
    final y =
        (_keys.contains(LogicalKeyboardKey.keyS) ||
                _keys.contains(LogicalKeyboardKey.arrowDown)
            ? 1.0
            : 0.0) -
        (_keys.contains(LogicalKeyboardKey.keyW) ||
                _keys.contains(LogicalKeyboardKey.arrowUp)
            ? 1.0
            : 0.0);
    game.input = Offset(x, y);
    return KeyEventResult.handled;
  }

  @override
  void didChangeMetrics() {
    if (mounted && !blocked) _pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    p.commerce?.removeListener(_commerceChanged);
    _ticker.dispose();
    sound.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return _artLoading || _artError
        ? Scaffold(
            body: Center(
              child: _artError
                  ? GamePages(
                      centerContent: true,
                      children: [
                        Text(
                          tr('출격 그림을 불러오지 못했습니다. 연결을 확인한 뒤 다시 시도해 주세요.'),
                          textAlign: TextAlign.center,
                        ),
                        GameActionButton(
                          label: '다시 불러오기',
                          onPressed: audible(() {
                            setState(() {
                              _artError = false;
                              _artLoading = true;
                            });
                            _loadArt();
                          }),
                        ),
                      ],
                    )
                  : Text(tr('출격 준비 중'), textAlign: TextAlign.center),
            ),
          )
        : PopScope(
            canPop: game.finished && p.commerce?.busy != true,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) _pause();
            },
            child: Scaffold(
              body: Focus(
                autofocus: true,
                focusNode: _focus,
                onKeyEvent: _key,
                onFocusChange: (focused) {
                  if (!focused &&
                      !game.finished &&
                      !game.paused &&
                      game.choices.isEmpty) {
                    _pause();
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Column(
                      children: [
                        ColoredBox(
                          color: const Color(0xFF253447),
                          child: SafeArea(
                            bottom: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _hud(),
                                if (p.developerMode &&
                                    widget.developerConfig?.showPerformance ==
                                        true)
                                  Text(
                                    message(
                                      "TEST · {0} FPS · 적 {1} · 탄 {2} · 효과 {3}",
                                      [
                                        _fps.toStringAsFixed(0),
                                        game.enemies.length,
                                        game.shots.length,
                                        game.sparks.length,
                                      ],
                                    ),
                                    key: const Key('developer-performance'),
                                    style: const TextStyle(fontSize: 14),

                                    textAlign: TextAlign.center,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, bounds) {
                              game.viewportHeight =
                                  bounds.maxHeight * 420 / bounds.maxWidth;
                              return ClipRect(
                                key: const Key('battle-playing-viewport'),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Listener(
                                      key: const Key('battle-touch-field'),
                                      onPointerDown: (e) {
                                        if (controlsLocked ||
                                            _pointer != null) {
                                          return;
                                        }
                                        _focus.requestFocus();
                                        _pointer = e.pointer;
                                        if (_followTouch) {
                                          _follow(
                                            e.localPosition,
                                            bounds.maxWidth,
                                          );
                                          return;
                                        }
                                        if (_dragSteer) {
                                          _dragFinger = e.localPosition;
                                          _dragCat = game.position;
                                          game.steerTarget = game.position;
                                          _stick = e.localPosition;
                                          return;
                                        }
                                        _anchor = e.localPosition;
                                        _stick = _anchor;
                                      },
                                      onPointerMove: (e) {
                                        if (controlsLocked ||
                                            e.pointer != _pointer) {
                                          return;
                                        }
                                        if (_followTouch) {
                                          _follow(
                                            e.localPosition,
                                            bounds.maxWidth,
                                          );
                                          return;
                                        }
                                        if (_dragSteer) {
                                          _drag(
                                            e.localPosition,
                                            bounds.maxWidth,
                                          );
                                          return;
                                        }
                                        if (_anchor == null) return;
                                        // Keep the captured drag alive at the edge.
                                        // Clearing it here abruptly switched flight to 5% time.
                                        final local = Offset(
                                          e.localPosition.dx.clamp(
                                            0.0,
                                            bounds.maxWidth,
                                          ),
                                          e.localPosition.dy.clamp(
                                            0.0,
                                            bounds.maxHeight,
                                          ),
                                        );
                                        final steering = p.controls.steer(
                                          _anchor!,
                                          local,
                                        );
                                        _anchor = steering.anchor;
                                        _stick = local;
                                        game.input = steering.input;
                                      },
                                      onPointerUp: (e) {
                                        if (e.pointer == _pointer) {
                                          _clearInput();
                                        }
                                      },
                                      onPointerCancel: (e) {
                                        if (e.pointer == _pointer) {
                                          _clearInput();
                                        }
                                      },
                                      child: MouseRegion(
                                        onExit: (_) {
                                          if (_pointer != null) _clearInput();
                                        },
                                        child: Semantics(
                                          label: tr('전투 영역'),
                                          container: true,
                                          child: RepaintBoundary(
                                            child: CustomPaint(
                                              painter: BattlePainter(
                                                game,
                                                reducedEffects:
                                                    p.reducedEffects,
                                              ),
                                              size: Size.infinite,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      left: 8,
                                      right: 8,
                                      child: IgnorePointer(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            BattleHudStatus(game: game),
                                            if (game.boss == null &&
                                                (game.waveNoticeTime > 0 ||
                                                    game.bossIncoming) &&
                                                !widget.presentationAutoplay &&
                                                !controlsLocked)
                                              _waveBanner(),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (!widget.presentationAutoplay)
                                      BossIntroCard(
                                        world: game.worldIndex,
                                        arrival: game.bossArrivals,
                                      ),
                                    if (!widget.presentationAutoplay)
                                      VacuumKingTransmission(
                                        defeat: game.bossDefeats,
                                      ),
                                    if (game.ultimateShow > 0)
                                      UltimateBanner(
                                        name: game.ultimateBanner,
                                        t: game.ultimateShow / 1.6,
                                      ),
                                    if (!widget.presentationAutoplay &&
                                        !_restored &&
                                        game.moduleLoadout != null)
                                      LaunchAssembly(
                                        key: ValueKey('launch-$_runId'),
                                        hull: game.shipIndex,
                                        hidden: ShipSpriteArt.hiddenFor(
                                          game.moduleLoadout,
                                        ),
                                        assets: ShipSpriteArt.battleAssets,
                                        stage: widget.dailyEntry == null
                                            ? game.stageIndex
                                            : null,
                                      ),
                                    if (game.resolvingBoss)
                                      IgnorePointer(
                                        child: Center(
                                          child: Opacity(
                                            opacity:
                                                game.bossResolution!.time <
                                                    BossResolution.clearAt
                                                ? 0
                                                : ((game.bossResolution!.time -
                                                              BossResolution
                                                                  .clearAt) *
                                                          4)
                                                      .clamp(0.0, 1.0),
                                            child: Semantics(
                                              liveRegion: true,
                                              child: Container(
                                                key: const Key(
                                                  'boss-clear-banner',
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 18,
                                                      vertical: 14,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xE80B2134,
                                                  ),
                                                  border: Border.symmetric(
                                                    horizontal: BorderSide(
                                                      color: cyan,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),
                                                child: Text(
                                                  tr(
                                                    game
                                                        .bossResolution!
                                                        .message,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 26,
                                                    fontWeight: FontWeight.w900,
                                                    color: cyan,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_anchor != null && !controlsLocked)
                                      Positioned(
                                        left: _anchor!.dx - 44,
                                        top: _anchor!.dy - 44,
                                        child: IgnorePointer(
                                          child: Container(
                                            width: 88,
                                            height: 88,
                                            decoration: RasterDecoration(
                                              shape: BoxShape.circle,
                                              color: cyan.withValues(
                                                alpha: .05,
                                              ),
                                              border: Border.all(
                                                color: cyan.withValues(
                                                  alpha: .3,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_stick != null && !controlsLocked)
                                      Positioned(
                                        left: _stick!.dx - 15,
                                        top: _stick!.dy - 15,
                                        child: IgnorePointer(
                                          child: Container(
                                            width: 30,
                                            height: 30,
                                            decoration: RasterDecoration(
                                              shape: BoxShape.circle,
                                              color: cyan.withValues(alpha: .4),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (!widget.presentationAutoplay &&
                                        !controlsLocked &&
                                        game.hasCommonUltimate)
                                      Positioned(
                                        right: p.controls.leftActions
                                            ? null
                                            : 10,
                                        left: p.controls.leftActions
                                            ? 10
                                            : null,
                                        // side edge, just below the middle
                                        top: bounds.maxHeight * .58 - 32,
                                        child: StarCannonButton(
                                          key: const Key('common-ultimate'),
                                          charge: game.ultimateCharge,
                                          ready: game.ultimateReady,
                                          firing: game.ultimateRemaining > 0,
                                          onPressed: !game.ultimateReady
                                              ? null
                                              : () {
                                                  setState(() {
                                                    game.activateCommonUltimate();
                                                    _clearInput();
                                                  });
                                                  _focus.requestFocus();
                                                },
                                        ),
                                      ),
                                    if (!controlsLocked && game.pilotHasActive)
                                      Positioned(
                                        right: p.controls.leftActions
                                            ? null
                                            : 12,
                                        left: p.controls.leftActions
                                            ? 12
                                            : null,
                                        bottom: 64,
                                        child: FilledButton.tonal(
                                          style: GameUi.compactButton,
                                          onPressed: audible(
                                            game.pilotAbilityCooldown > 0
                                                ? null
                                                : () {
                                                    setState(() {
                                                      game.activatePilotAbility();
                                                      _clearInput();
                                                    });
                                                    _focus.requestFocus();
                                                  },
                                          ),
                                          child: Text(
                                            tr(
                                              game.pilotAbilityCooldown > 0
                                                  ? '고유 ${game.pilotAbilityCooldown.ceil()}초'
                                                  : game.pilotAbilityLabel,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 15,
                                            ),

                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    if (game.choices.isNotEmpty &&
                        !game.finished &&
                        !game.paused)
                      SafeArea(child: _upgrades()),
                    if (game.paused && !game.finished && !_hudDetailsOpen)
                      SafeArea(child: _pausePanel()),
                    if (game.finished) SafeArea(child: _result()),
                  ],
                ),
              ),
            ),
          );
  }

  Widget _waveBanner() => IgnorePointer(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: Container(
          key: const Key('battle-wave-banner'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: RasterDecoration(
            color: ink.withValues(alpha: .8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            tr(game.waveLabel),
            style: TextStyle(
              color: game.bossIncoming ? const Color(0xFFFFBD7A) : cyan,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),

            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
  Widget _hud() => BattleHud(
    game: game,
    saveWarning: p.battleSaveNotice != null,
    title: widget.training
        ? '45초 훈련'
        : widget.dailyEntry?.name ?? stages[game.stageIndex].name,
    timer: '${_clock(game.elapsed)} / ${_clock(game.duration)}',
    onPause: game.finished ? null : _pause,
    onDetails: controlsLocked ? null : _showHudDetails,
  );

  Future<void> _showHudDetails() async {
    if (controlsLocked || _hudDetailsOpen) return;
    _hudDetailsOpen = true;
    _pause();
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => GameDialog(
          title: '전투 정보',
          closeLabel: '전투 정보 닫기',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GameSectionTitle(
                widget.training
                    ? '45초 훈련'
                    : widget.dailyEntry?.name ?? stages[game.stageIndex].name,
              ),
              BattleLoadoutDetails(game: game),
              const SizedBox(height: 12),
              if (p.battleSaveNotice != null)
                Text(
                  tr(p.battleSaveNotice!),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.orange),
                ),
              Text(tr(game.worldTactic), textAlign: TextAlign.center),
              Text(
                '${_clock(game.elapsed)} / ${_clock(game.duration)}',
                textAlign: TextAlign.center,
              ),
              Text(
                message("체력 {0}/{1} · Lv.{2}\n경험치 {3}/{4}", [
                  game.hp.ceil(),
                  game.maxHp.ceil(),
                  game.level,
                  game.xp.toStringAsFixed(1),
                  game.xpNeeded.toStringAsFixed(1),
                ]),

                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message("주포 연사 {0}/5 · 출력 {1}/5 · 발사 {2}{3}", [
                  game.mainRate,
                  game.mainPower,
                  game.mainProjectiles,
                  game.evolved.contains('gun') ? ' · EVO' : '',
                ]),

                textAlign: TextAlign.center,
              ),
              if (game.mainBranchSpec != null)
                Text(
                  message("주포 특화 · {0}", [game.mainBranchSpec!.name]),
                  textAlign: TextAlign.center,
                ),
              if (game.synergyHudText.isNotEmpty)
                Text(tr(game.synergyHudText), textAlign: TextAlign.center),
              if (game.pilotStateText.isNotEmpty)
                Text(tr(game.pilotStateText), textAlign: TextAlign.center),
              for (final passive in [false, true]) ...[
                const SizedBox(height: 12),
                GameSectionTitle(passive ? '보조 스킬' : '무기'),
                for (final e
                    in (passive ? game.passives : game.upgrades).entries) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      RasterSkillIcon(e.key, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message("{0} · {1}단계{2}\n{3}", [
                            e.key == 'gun'
                                ? armaments
                                      .firstWhere((a) => a.id == game.armament)
                                      .name
                                : game.combatSkill(e.key).name,
                            e.value,
                            game.evolved.contains(e.key) ? ' · EVO' : '',
                            game.weaponRoleLabel(e.key),
                          ]),

                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      );
    } finally {
      if (mounted) {
        _hudDetailsOpen = false;
        final state = WidgetsBinding.instance.lifecycleState;
        if (state == null || state == AppLifecycleState.resumed) {
          _resume();
        } else {
          setState(() {});
        }
      }
    }
  }

  Future<void> _replacePassive() async {
    final newId = await showDialog<String>(
      context: context,
      builder: (c) => RasterSimpleDialog(
        title: Text(tr('얻을 진화 재료'), textAlign: TextAlign.center),
        children: [
          for (final id in game.missingPartners)
            SimpleDialogOption(
              onPressed: audible(() => Navigator.pop(c, id)),
              child: Text(tr(skillFor(id).name), textAlign: TextAlign.center),
            ),
        ],
      ),
    );
    if (newId == null || !mounted) return;
    final oldId = await showDialog<String>(
      context: context,
      builder: (c) => RasterSimpleDialog(
        title: Text(
          message("{0} 1단계로 교체", [skillFor(newId).name]),
          textAlign: TextAlign.center,
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              tr('이번 성장 선택과 교체 1회를 사용합니다. 고른 보조의 모든 단계가 사라집니다.'),
              textAlign: TextAlign.center,
            ),
          ),
          for (final entry in game.passives.entries)
            SimpleDialogOption(
              onPressed: audible(() => Navigator.pop(c, entry.key)),
              child: Text(
                message("{0} Lv.{1} 교체", [
                  skillFor(entry.key).name,
                  entry.value,
                ]),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
    if (oldId != null && mounted) {
      setState(() {
        game.replacePassive(oldId, newId);
        _clearInput();
      });
    }
  }

  /// Dim overlay with one fixed, centered page (no paging, no scrolling).
  Widget _scrim(Widget child) => Container(
    color: ink.withValues(alpha: .94),
    alignment: Alignment.center,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 344),
        child: child,
      ),
    ),
  );
  Future<void> _chooseUpgrade(String id) async {
    if (_selectedUpgrade != null || !game.choices.any((c) => c.id == id)) {
      return;
    }
    setState(() => _selectedUpgrade = id);
    final selectedRun = game;
    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted || game.paused || game != selectedRun) {
      if (mounted) setState(() => _selectedUpgrade = null);
      return;
    }
    setState(() {
      game.chooseUpgrade(id);
      _selectedUpgrade = null;
      _clearInput();
    });
    _checkpoint(force: true);
    _focus.requestFocus();
  }

  Widget _upgrades() => UpgradeSlots(
    game: game,
    selected: _selectedUpgrade,
    onChoose: _chooseUpgrade,
    onReroll: () => setState(game.rerollChoices),
    onReplace:
        game.passives.length == 6 &&
            game.missingPartners.isNotEmpty &&
            game.passiveReplacements > 0
        ? _replacePassive
        : null,
  );

  /// v12.4.3 (user 2026-10-25): one fixed page, short labels, no paging.
  Widget _pausePanel() {
    final notice = p.battleSaveNotice ?? (_restored ? '이전 전투를 복원했습니다.' : null);
    return _scrim(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RasterIcon(Icons.pause_circle_outline, color: cyan, size: 48),
          gap(6),
          Text(
            tr('일시정지'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          if (notice != null) ...[
            gap(6),
            Text(
              tr(notice),
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: GameUi.body),
            ),
          ],
          gap(16),
          GameActionButton(
            label: '계속 비행',
            primary: true,
            icon: Icons.play_arrow,
            onPressed: audible(_resume),
          ),
          gap(10),
          Row(
            children: [
              Expanded(
                child: GameActionButton(
                  key: const Key('pause-battle-statistics'),
                  label: '전투 통계',
                  displayLabel: '통계',
                  onPressed: audible(_showStatistics),
                ),
              ),
              if (_canCheckpoint) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: GameActionButton(
                    label: '조작·음향 설정',
                    displayLabel: '설정',
                    onPressed: audible(() async {
                      _clearInput();
                      await Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ControlSettingsScreen(profile: p),
                        ),
                      );
                      if (mounted) {
                        _clearInput();
                        await _checkpoint(force: true);
                        setState(() {});
                      }
                    }),
                  ),
                ),
              ],
            ],
          ),
          gap(10),
          Row(
            children: [
              if (_canCheckpoint) ...[
                Expanded(
                  child: GameActionButton(
                    key: const Key('save-battle-return'),
                    label: '저장 후 로비',
                    displayLabel: '저장·로비',
                    onPressed: audible(_returning ? null : _saveAndReturn),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: GameActionButton(
                  label: widget.dailyEntry != null
                      ? '도전 중단 · 토큰 보상 없음'
                      : '귀환 · 현재 보상 정산',
                  displayLabel: widget.dailyEntry != null ? '도전 중단' : '귀환',
                  onPressed: audible(() {
                    setState(() {
                      game.abandon();
                      _clearInput();
                    });
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _campaignComplete =>
      game.victory &&
      game.stageIndex == 99 &&
      !widget.training &&
      !widget.challenge &&
      widget.dailyEntry == null;

  /// v12.4.3 (user 2026-10-25): one fixed page with only what matters —
  /// the outcome, three numbers, the reward and the next step. Everything
  /// else (loot text, progress, defeat advice, receipts) is in the reward
  /// popup. No paging and no scrolling.
  Widget _result() {
    final win = game.victory;
    final house = houseOf(game.stageIndex).place;
    return ColoredBox(
      color: ink.withValues(alpha: .94),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, box) {
                // a short phone with large text drops only the portrait
                final text = MediaQuery.textScalerOf(context).scale(16) / 16;
                final roomy = box.maxHeight >= 520 * text;
                return Semantics(
                  container: true,
                  label: tr(win ? '승리' : '패배'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (roomy)
                        SizedBox(
                          height: 76,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (win)
                                Image.asset(
                                  'assets/art/fx_v11/level_burst.webp',
                                  width: 96,
                                  height: 96,
                                ),
                              Opacity(
                                opacity: win ? 1 : .8,
                                child: Image.asset(
                                  LobbyCatHero.portraits[game.shipIndex.clamp(
                                    0,
                                    2,
                                  )],
                                  key: const Key('result-cat'),
                                  width: 72,
                                  height: 72,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (roomy) gap(6),
                      Text(
                        tr(
                          _campaignComplete
                              ? '모든 동네 완주!'
                              : win
                              ? '집을 지켜 냈다냥!'
                              : '다음엔 꼭 이긴다냥',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: win ? Colors.white : const Color(0xFFFFD2A8),
                        ),
                      ),
                      gap(4),
                      Text(
                        tr(
                          widget.training
                              ? '훈련 비행'
                              : !win && game.lastDamageSource.isNotEmpty
                              ? '마지막 피격 · ${game.lastDamageSource}'
                              : house,
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: muted),
                      ),
                      gap(14),
                      Surface(
                        child: Row(
                          children: [
                            Expanded(child: Stat('${game.kills}', '격파')),
                            Expanded(child: Stat('Lv.${game.level}', '레벨')),
                            Expanded(
                              child: Stat(_clock(game.combatTime), '시간'),
                            ),
                          ],
                        ),
                      ),
                      gap(12),
                      Text(
                        tr(
                          widget.training
                              ? '훈련 보상 없음'
                              : widget.dailyEntry != null
                              ? '+ $reward 도전 토큰'
                              : '+ $reward 츄르',
                        ),
                        key: const Key('result-reward'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cyan,
                          fontSize: widget.training ? 18 : 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      gap(14),
                      GameActionButton(
                        primary: true,
                        icon: Icons.rocket_launch,
                        onPressed: audible(
                          p.commerce?.busy == true
                              ? null
                              : () {
                                  sound.play('click');
                                  if (widget.dailyEntry != null) {
                                    p.refreshContentClock(DateTime.now());
                                    if (p.dailyChallenge.day !=
                                        widget.dailyEntry!.day) {
                                      Navigator.of(context).pop(false);
                                      return;
                                    }
                                  }
                                  setState(() => _newGame());
                                  _focus.requestFocus();
                                },
                        ),
                        label: widget.dailyEntry != null
                            ? '도전 다시 출격'
                            : _campaignComplete
                            ? '다음 회차 출격'
                            : win
                            ? '다음 항로 출격'
                            : '다시 출격',
                        displayLabel: widget.dailyEntry != null
                            ? '다시 도전'
                            : _campaignComplete
                            ? '다음 회차'
                            : win
                            ? '다음 집으로'
                            : '다시 출격',
                      ),
                      gap(10),
                      Row(
                        children: [
                          if (!widget.training) ...[
                            Expanded(
                              child: GameActionButton(
                                key: const Key('result-rewards'),
                                label: '보상·기록 보기',
                                displayLabel: '보상',
                                onPressed: audible(_showResultDetails),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: GameActionButton(
                              key: const Key('result-battle-statistics'),
                              label: '전투 통계',
                              displayLabel: '통계',
                              onPressed: audible(_showStatistics),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GameActionButton(
                              onPressed: audible(
                                p.commerce?.busy == true
                                    ? null
                                    : () {
                                        if (_returning) return;
                                        _returning = true;
                                        Navigator.of(context)
                                            .pop(widget.dailyEntry == null);
                                      },
                              ),
                              label: widget.dailyEntry != null
                                  ? '도전 목록으로'
                                  : '성장 정비 · 귀환',
                              displayLabel: '귀환',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// The run's secondary facts, on demand.
  Future<void> _showResultDetails() async {
    final loot = p.saveError ?? p.lastLoot;
    final lines = <String>[
      message("보스 {0}/{1} · 진행 {2}", [
        game.bossesDefeated,
        game.requiredBosses,
        _clock(game.elapsed),
      ]),
      if (loot.isNotEmpty) loot,
      if (widget.dailyEntry == null && p.lastLoot.isNotEmpty)
        message("시즌 {0} XP", [p.seasonXp]),
      if (p.starterTechUnlocked && !p.starterTechClaimed)
        '희귀 테크 선택 해금 · 성장 → 테크',
      if (!game.victory && game.lastDamageSource.isNotEmpty) game.damageAdvice,
      if (loot.isEmpty) '보상과 진행이 자동 저장됩니다.',
      ?_adStatus,
    ];
    await showDialog<void>(
      context: context,
      builder: (dialog) => GameDialog(
        title: '보상·기록',
        actions: [
          if (_campaignReceipt != null)
            GameActionButton(
              label: '보상 내역',
              icon: Icons.card_giftcard,
              onPressed: audible(
                () => showCampaignRewardReceipt(context, _campaignReceipt!),
              ),
            ),
          if (_canCheckpoint &&
              widget.dailyEntry == null &&
              game.elapsed >= 30 &&
              game.kills >= 10 &&
              p.commerce?.configuredAds == true)
            GameActionButton(
              label: p.commerce!.rewardedRun(_runId)
                  ? '추가 보상 지급 완료'
                  : '광고 선택 · 추가 20 츄르',
              icon: Icons.play_circle,
              onPressed: audible(
                p.commerce!.canAdvertise && !p.commerce!.rewardedRun(_runId)
                    ? () async {
                        final store = p.commerce!;
                        setState(() => _adStatus = '추가 보상 확인 중');
                        await store.watchReward(
                          runId: _runId,
                          seconds: game.elapsed.floor(),
                          kills: game.kills,
                        );
                        if (mounted) setState(() => _adStatus = store.status);
                      }
                    : null,
              ),
            ),
        ],
        child: Text(
          lines.map(tr).join('\n'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, height: 1.45),
        ),
      ),
    );
  }
}

String _clock(double seconds) {
  final v = seconds.floor();
  return '${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toString().padLeft(2, '0')}';
}
