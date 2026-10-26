import '../l10n/app_language.dart';

import 'audio_feedback.dart';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../data/content.dart';
import '../data/profile.dart';
import '../data/shop_ledger.dart';
import 'ad_offer.dart';
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
import '../art/ship_sprite_art.dart';
import '../art/flight_scene_art.dart';
import 'skill_cards.dart';
import '../art/ui_kit.dart';
import 'game_motion.dart';
import 'game_decor.dart';
import 'upgrade_slots.dart';
import 'battle_statistics.dart';
import '../art/game_art.dart';
import '../data/campaign_rewards.dart';
import 'campaign_reward_views.dart';
import 'control_settings_screen.dart';
import '../data/houses.dart';
import '../data/fleet_journal.dart';
import '../art/game_icons.dart';
import 'game_slots.dart';
import 'star_cannon_button.dart';
import '../data/control_preferences.dart';

class BattleScreen extends StatefulWidget {
  /// Battle pictures for [stageIndex]: enemies, the house stage and its
  /// world. The lobby starts this in the background, so launching usually
  /// finds everything decoded; the battle screen awaits the same futures.
  static Future<void> warmArt(int stageIndex) => Future.wait([
    GameArt.loadBattle(),
    FlightSceneArt.ensureHouse(stageIndex),
    FlightSceneArt.ensureWorld(stages[stageIndex].worldIndex),
  ]);

  const BattleScreen({
    super.key,
    required this.profile,
    this.training = false,
    this.challenge = false,
    this.dailyEntry,
    this.engineFactory,
    this.developerConfig,
    this.presentationAutoplay = false,
  });
  final Profile profile;
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

  /// Runs that count: recorded in the flight log and given settings access.
  bool get _recordsRun =>
      p.persistsProgress &&
      !widget.training &&
      widget.engineFactory == null &&
      !widget.presentationAutoplay;
  bool _artLoading = false;
  bool _artError = false;
  String? _adStatus;
  Profile get p => widget.profile;
  bool get controlsLocked => blocked || game.resolvingBoss;

  /// v12.9.3: the sortie intro (roof, clouds, assembly) holds the run.
  bool _intro = false, _liveMotion = false, _motionChecked = false;
  bool get _introAllowed =>
      _liveMotion &&
      !p.reducedEffects &&
      !widget.presentationAutoplay &&
      widget.engineFactory == null &&
      game.moduleLoadout != null;
  bool get blocked =>
      _intro ||
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
    _newGame();
    _artLoading = GameArt.ready && !GameArt.battleReady;
    _loadArt();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_motionChecked) {
      _motionChecked = true;
      _liveMotion = ShipSpriteArt.liveMotion(context);
      _intro = _introAllowed;
    }
  }

  void _newGame() {
    if (p.online != null) p.online!.inBattle = true;
    _adStatus = null;
    _runId = DateTime.now().microsecondsSinceEpoch.toString();
    // a retry flies the intro again (the first run decides after layout)
    _intro =
        _motionChecked &&
        _liveMotion &&
        !p.reducedEffects &&
        !widget.presentationAutoplay &&
        widget.engineFactory == null;
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
          // the cat is the pilot: its fixed trait grows with its level
          pilot: catTraitFor(p.selectedShip).id,
          traitLevel: catTraitLevel(p.pilotLevel),
          hurtGuard: gear.guard,
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
          // v12.17: every deploy card is rescued in turn during the run
          chickRoster: [
            for (final id in p.deployedChicks)
              if (p.chickOwned(id))
                ChickLoadout(
                  id,
                  level: p.petLevels[id],
                  rank: p.petRanks[id],
                  awakePower: p.petBond.powerBonus(id),
                  awakeCooldown: p.petBond.cooldownReduction(id),
                ),
          ],
        );
    // v12.16 real sorties shed their parts in the intro and earn them back
    if (widget.engineFactory == null && !widget.presentationAutoplay) {
      game.startDisassembled();
    }
    game.onEvent = (event) => sound.play(event, armament: game.armament);
    game.visuals.onSound = sound.cue;
    sound.beginFlight(paused: game.paused);
    _rewarded = false;
    _selectedUpgrade = null;
    reward = 0;
    _campaignReceipt = null;
    p.lastLoot = "";
    _clearInput();
  }

  /// The +50% offer fits under the reward of a paying campaign sortie.
  bool get _adOfferShown =>
      _recordsRun &&
      widget.dailyEntry == null &&
      !widget.training &&
      reward > 0 &&
      p.commerce?.offerVisible(AdOffer.runBonus) == true;

  void _commerceChanged() {
    if (mounted && game.finished) {
      setState(() => _adStatus = p.commerce?.status);
    }
  }

  Future<void> _loadArt() async {
    await RasterAssets.load();
    try {
      await Future.wait([
        BattleScreen.warmArt(game.stageIndex),
        // skill cards decode now, not when the first draft is dealt
        if (mounted)
          for (final asset in SkillCardArt.preload)
            precacheImage(AssetImage(asset), context),
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
    final needsReward = game.finished && !_rewarded;
    if (needsReward) {
      sound.pauseMusic();
      _rewarded = true;
      if (p.online != null) p.online!.inBattle = false;
      if (_recordsRun) p.recordFlight(_runId, game);
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
    game.steerGlide = false;
    game.steerTarget = target;
    _stick = local;
  }

  /// Follow-touch steering: the cat flies to just above the finger.
  void _follow(Offset local, double width) {
    final view = local * (420 / width);
    game.steerGlide = true;
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
                                                hideHero: _intro,
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
                                    if (_intro)
                                      SortieIntro(
                                        key: ValueKey('launch-$_runId'),
                                        hull: game.shipIndex,
                                        hidden: ShipSpriteArt.hiddenFor(
                                          game.moduleLoadout,
                                        ),
                                        shed: game.assembleInFlight
                                            ? InFlightAssembly.allLayers
                                            : const {},
                                        assets: ShipSpriteArt.battleAssets,
                                        target: game.position - game.camera,
                                        stage: widget.dailyEntry == null
                                            ? game.stageIndex
                                            : null,
                                        onCue: sound.play,
                                        onDone: () {
                                          if (mounted) {
                                            setState(() => _intro = false);
                                          }
                                        },
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
                                      // v12.16: small, beside the craft;
                                      // faint while charging, vivid when full
                                      Positioned(
                                        left:
                                            ((game.position - game.camera).dx *
                                                        bounds.maxWidth /
                                                        420 +
                                                    (p.controls.leftActions
                                                        ? -90
                                                        : 44))
                                                .clamp(
                                                  4.0,
                                                  bounds.maxWidth - 50,
                                                ),
                                        top:
                                            ((game.position - game.camera).dy *
                                                        bounds.maxWidth /
                                                        420 -
                                                    23)
                                                .clamp(
                                                  4.0,
                                                  bounds.maxHeight - 50,
                                                ),
                                        child: StarCannonButton(
                                          key: const Key('common-ultimate'),
                                          size: 46,
                                          emblem:
                                              CommonUltimate.ultimateAssets[game
                                                  .ultimateKind],
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
              // v12.14: labelled fact tiles and groups, not a stack of
              // "체력 … · Lv … / 주포 연사 … · 출력 …" lines.
              const SizedBox(height: 10),
              GameFactRow([
                GameFact(
                  '시간',
                  '${_clock(game.elapsed)} / ${_clock(game.duration)}',
                ),
                GameFact(
                  '체력',
                  '${game.hp.ceil()}/${game.maxHp.ceil()}',
                  tone: GameTone.danger,
                ),
                GameFact('레벨', 'Lv.${game.level}', tone: GameTone.gold),
              ]),
              const SizedBox(height: 8),
              GameFactRow([
                GameFact('주포 연사', '${game.mainRate}/5', tone: GameTone.gold),
                GameFact('주포 출력', '${game.mainPower}/5', tone: GameTone.gold),
                GameFact(
                  '발사 수',
                  game.evolved.contains('gun')
                      ? '${game.mainProjectiles} EVO'
                      : '${game.mainProjectiles}',
                  tone: GameTone.gold,
                ),
              ]),
              // v12.15: states as small tags, the tactic as one quiet hint;
              // the owned skills are the slot strip above (no text list)
              ...[
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    GameTag(
                      armaments
                          .firstWhere(
                            (a) => a.id == game.armament,
                            orElse: () => armaments.first,
                          )
                          .name,
                    ),
                    for (final s in game.synergyHudText.split('\n'))
                      if (s.trim().isNotEmpty)
                        GameTag(s.trim(), tone: GameTone.good),
                    if (game.pilotStateText.isNotEmpty)
                      GameTag(game.pilotStateText, tone: GameTone.sky),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              GameHint(game.worldTactic),
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
    // UpgradeSlots has already played the card's choice celebration.
    if (game.paused) return;
    setState(() {
      game.chooseUpgrade(id);
      _selectedUpgrade = null;
      _clearInput();
    });
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

  /// v12.15 (user 2026-10-26, mobile-game menus): the pause sign cat, a
  /// ribbon, one big resume button and the rest as round picture buttons.
  Widget _pausePanel() {
    final daily = widget.dailyEntry != null;
    return _scrim(
      PopIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MascotImage(Mascot.pause, size: 112),
            const RibbonTitle('일시정지', width: 320, height: 64, size: 26),
            gap(6),
            UiKitFrame(
              'panel',
              corner: 26,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StaggerIn(
                    index: 1,
                    child: GameActionButton(
                      label: '계속 비행',
                      primary: true,
                      image: 'assets/art/ui_v13/icon_play.webp',
                      onPressed: audible(_resume),
                    ),
                  ),
                  gap(14),
                  StaggerIn(
                    index: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _RoundAction(
                          key: const Key('pause-battle-statistics'),
                          label: '전투 통계',
                          short: '통계',
                          image: 'assets/art/ui_v13/icon_stats.webp',
                          onPressed: _showStatistics,
                        ),
                        if (_recordsRun)
                          _RoundAction(
                            key: const Key('pause-settings'),
                            label: '조작·음향 설정',
                            short: '설정',
                            image: GameIcons.settings,
                            onPressed: () async {
                              _clearInput();
                              await Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      ControlSettingsScreen(profile: p),
                                ),
                              );
                              if (mounted) {
                                _clearInput();
                                setState(() {});
                              }
                            },
                          ),
                        _RoundAction(
                          key: const Key('pause-return'),
                          label: daily ? '도전 중단 · 토큰 보상 없음' : '귀환 · 현재 보상 정산',
                          short: daily ? '도전 중단' : '귀환',
                          image: 'assets/art/ui_v13/icon_home.webp',
                          onPressed: () => setState(() {
                            game.abandon();
                            _clearInput();
                          }),
                        ),
                      ],
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

  bool get _campaignComplete =>
      game.victory &&
      game.stageIndex == 99 &&
      !widget.training &&
      !widget.challenge &&
      widget.dailyEntry == null;

  /// What this run actually paid, as reward pictures: the churu (or the
  /// challenge token) plus every campaign bonus the receipt delivered.
  List<GameReward> get _earned {
    if (widget.dailyEntry != null) {
      return [GameReward(GameIcons.token, reward, '도전 토큰', rarity: 3)];
    }
    var plans = 0, food = 0, gear = 0, tech = 0, eggs = 0, collect = 0;
    for (final (_, r)
        in _campaignReceipt?.entries ?? const <(String, FleetReward)>[]) {
      plans += r.plans;
      food += r.food;
      gear += r.gearKeys;
      tech += r.techKeys;
      eggs += r.eggs;
      collect += r.collectionKeys;
    }
    final items = GameReward.of(
      FleetReward(
        credits: reward,
        plans: plans,
        food: food,
        gearKeys: gear,
        techKeys: tech,
        eggs: eggs,
        collectionKeys: collect,
      ),
    );
    return items.isEmpty ? [GameReward(GameIcons.churu, 0, '츄르')] : items;
  }

  /// v12.15 (user 2026-10-26, mobile shooter results): the cat, big
  /// VICTORY/DEFEAT lettering and ribbon, three picture stat tiles, the
  /// earned rewards popping in as ×N slots, one big next button and round
  /// picture buttons for rewards, statistics and home. One fixed page.
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
                // a short phone with large text drops the portrait and the
                // big lettering; the ribbon still carries the outcome
                final text = MediaQuery.textScalerOf(context).scale(16) / 16;
                final roomy = box.maxHeight >= 620 * text;
                final offer = _adOfferShown;
                final mascot = (box.maxHeight - (offer ? 612 : 548) * text)
                    .clamp(0.0, 140.0);
                final earned = _earned;
                return Semantics(
                  container: true,
                  label: tr(win ? '승리' : '패배'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (roomy && mascot >= 72)
                        SizedBox(
                          height: mascot + 8,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              if (win) ...[
                                GlowRays(size: mascot * 1.8),
                                SparkleBurst(
                                  size: mascot * 1.7,
                                  count: 12,
                                  delay: 250,
                                  color: Color(0xFFFFE27A),
                                ),
                              ],
                              PopIn(
                                child: MascotImage(
                                  win ? Mascot.victory : Mascot.defeat,
                                  key: const Key('result-cat'),
                                  size: mascot,
                                  sway: win ? .12 : .04,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (roomy)
                        PopIn(
                          delay: 80,
                          child: GameLettering(
                            win ? '승리!' : '패배',
                            size: 44,
                            colors: win
                                ? const [Color(0xFFFFF6C2), Color(0xFFFFB627)]
                                : const [Color(0xFFE4ECF7), Color(0xFF8FA3BF)],
                          ),
                        ),
                      PopIn(
                        delay: 150,
                        child: RibbonTitle(
                          _campaignComplete
                              ? '모든 동네 완주!'
                              : win
                              ? '집을 지켜 냈다냥!'
                              : '다음엔 꼭 이긴다냥',
                          width: 320,
                          height: 50,
                          size: 20,
                        ),
                      ),
                      Text(
                        tr(
                          widget.training
                              ? '훈련 비행'
                              : !win && game.lastDamageSource.isNotEmpty
                              ? '마지막 피격 · ${game.lastDamageSource}'
                              : house,
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, color: muted),
                      ),
                      gap(10),
                      StaggerIn(
                        index: 3,
                        child: Row(
                          children: [
                            for (final (i, value, label, image, format) in [
                              (
                                0,
                                game.kills.toDouble(),
                                '격파',
                                GameIcons.crosshair,
                                (double v) => '${v.round()}',
                              ),
                              (
                                1,
                                game.level.toDouble(),
                                '레벨',
                                'assets/art/menu_v13/growth.webp',
                                (double v) => 'Lv.${v.round()}',
                              ),
                              (
                                2,
                                game.combatTime,
                                '시간',
                                GameIcons.hourglass,
                                (double v) => _clock(v),
                              ),
                            ]) ...[
                              if (i > 0) const SizedBox(width: 6),
                              Expanded(
                                child: UiKitFrame(
                                  'slot',
                                  corner: 16,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GameIconImage(image, size: 26),
                                            const SizedBox(width: 4),
                                            CountUp(
                                              value: value,
                                              format: format,
                                              delay: 300 + i * 150,
                                              style: const TextStyle(
                                                fontSize: 21,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        tr(label),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      gap(10),
                      widget.training
                          ? Text(
                              tr('훈련 보상 없음'),
                              key: const Key('result-reward'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: cyan,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : Wrap(
                              key: const Key('result-reward'),
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var i = 0; i < earned.length; i++)
                                  PopIn(
                                    delay: 650 + i * 140,
                                    child: GameRewardSlot(
                                      earned[i],
                                      size: earned.length > 4 ? 46 : 58,
                                    ),
                                  ),
                              ],
                            ),
                      if (offer) ...[
                        gap(8),
                        AdOfferButton(
                          profile: p,
                          offer: AdOffer.runBonus,
                          reward: message('+{0} 츄르', [
                            ShopSystems.runBonus(reward),
                          ]),
                          runId: _runId,
                          runCredits: reward,
                        ),
                      ],
                      gap(12),
                      GameActionButton(
                        primary: true,
                        image: GameIcons.launch,
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
                                  // v12.17: the next house's street and map
                                  // load before it flies (was a blank sky)
                                  setState(() {
                                    _newGame();
                                    _artLoading = true;
                                  });
                                  _loadArt();
                                  _focus.requestFocus();
                                },
                        ),
                        label: widget.dailyEntry != null
                            ? '도전 다시 출격'
                            : _campaignComplete
                            ? '다음 회차 출격'
                            : win
                            ? '다음 집 출격'
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
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (!widget.training)
                            _RoundAction(
                              key: const Key('result-rewards'),
                              label: '보상·기록 보기',
                              short: '보상',
                              image: GameIcons.chest,
                              onPressed: _showResultDetails,
                            ),
                          _RoundAction(
                            key: const Key('result-battle-statistics'),
                            label: '전투 통계',
                            short: '통계',
                            image: 'assets/art/ui_v13/icon_stats.webp',
                            onPressed: _showStatistics,
                          ),
                          _RoundAction(
                            key: const Key('result-return'),
                            label: widget.dailyEntry != null
                                ? '도전 목록으로'
                                : '성장 정비 · 귀환',
                            short: '귀환',
                            image: 'assets/art/ui_v13/icon_home.webp',
                            onPressed: p.commerce?.busy == true
                                ? null
                                : () {
                                    if (_returning) return;
                                    _returning = true;
                                    Navigator.of(context)
                                        .pop(widget.dailyEntry == null);
                                  },
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
    final saveError = p.saveError;
    final loot = saveError ?? p.lastLoot;
    final season = widget.dailyEntry == null && p.lastLoot.isNotEmpty;
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
        ],
        // v12.14: labelled facts and groups instead of one block of lines.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GameFactRow([
              GameFact(
                '보스',
                '${game.bossesDefeated}/${game.requiredBosses}',
                tone: GameTone.danger,
              ),
              GameFact('진행', _clock(game.elapsed)),
              if (season)
                GameFact('시즌 XP', '${p.seasonXp}', tone: GameTone.gold),
            ]),
            if (loot.isNotEmpty) ...[
              const SizedBox(height: 8),
              GameInfoBlock(
                label: saveError != null ? '저장 오류' : '획득',
                tone: saveError != null ? GameTone.danger : GameTone.good,
                children: [
                  for (final part in loot.split(' · '))
                    Text(
                      tr(part),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ],
            if (p.starterTechUnlocked && !p.starterTechClaimed) ...[
              const SizedBox(height: 8),
              const GameInfoBlock(
                label: '해금',
                tone: GameTone.good,
                lead: '희귀 테크 선택',
                detail: '성장 → 테크',
              ),
            ],
            if (!game.victory && game.lastDamageSource.isNotEmpty) ...[
              const SizedBox(height: 8),
              GameInfoBlock(
                label: '공략 팁',
                tone: GameTone.sky,
                detail: game.damageAdvice,
              ),
            ],
            if (loot.isEmpty) ...[
              const SizedBox(height: 6),
              const GameHint('보상과 진행이 자동 저장됩니다.'),
            ],
            if (_adStatus != null) ...[
              const SizedBox(height: 6),
              GameHint(_adStatus!),
            ],
          ],
        ),
      ),
    );
  }
}

/// v12.15: a secondary menu action as a round kit button with its picture
/// and one short word under it; the full label is read out.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    super.key,
    required this.label,
    required this.short,
    required this.image,
    required this.onPressed,
  });
  final String label, short, image;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: tr(label),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: audible(onPressed, cue: buttonCue(label)),
        child: Opacity(
          opacity: onPressed == null ? .5 : 1,
          child: SizedBox(
            width: 76,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                KitRound(size: 56, child: GameIconImage(image, size: 34)),
                const SizedBox(height: 3),
                Text(
                  tr(short),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _clock(double seconds) {
  final v = seconds.floor();
  return '${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toString().padLeft(2, '0')}';
}
