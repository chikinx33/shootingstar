import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../art/module_aircraft_art.dart';
import '../game/engine.dart';
import '../l10n/app_language.dart';
import '../services/audio_director.dart';
import 'audio_feedback.dart';
import 'components.dart';
import 'skill_cards.dart';

/// The level-up draft (user 2026-10-25): illustrated skill cards dealt over
/// the frozen battlefield. Frames grow richer with the skill's stage, and
/// choosing a card plays a celebration that scales with its tier — the
/// purple 궁극 card gets the full show. [onChoose] fires once it ends.
class UpgradeSlots extends StatefulWidget {
  const UpgradeSlots({
    super.key,
    required this.game,
    required this.onChoose,
    required this.onReroll,
    this.selected,
    this.onReplace,
  });
  final GameEngine game;
  final ValueChanged<String> onChoose;
  final VoidCallback onReroll;
  final VoidCallback? onReplace;
  final String? selected;

  @override
  State<UpgradeSlots> createState() => _UpgradeSlotsState();
}

class _UpgradeSlotsState extends State<UpgradeSlots>
    with TickerProviderStateMixin {
  static const _introMs = 1150;

  /// How long each tier's choice celebration runs (index = tier).
  static const _pickMs = [0, 650, 700, 800, 1000, 1300, 2000];

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _introMs),
  );
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  late final AnimationController _pick = AnimationController(vsync: this);

  String _deal = '';
  String? _picked;
  int _pickedIndex = 0, _pickedTier = 1;

  GameEngine get game => widget.game;
  String get _stamp => game.choices.map((c) => c.id).join(',');

  bool get _motion =>
      TickerMode.valuesOf(context).enabled &&
      !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _redeal();
    if (_motion) {
      // Two minutes of shimmer is plenty for one draft (and lets tests and
      // screens settle).
      if (!_idle.isAnimating) _idle.repeat(count: 30);
    } else {
      _idle.stop();
    }
  }

  @override
  void didUpdateWidget(UpgradeSlots old) {
    super.didUpdateWidget(old);
    _redeal();
  }

  /// A new or re-rolled hand is dealt again from the bottom.
  void _redeal() {
    final stamp = _stamp;
    if (stamp == _deal) return;
    _deal = stamp;
    _picked = null;
    _pick.value = 0;
    if (_motion) {
      _intro.forward(from: 0);
      AudioDirector.current?.play('level');
    } else {
      _intro.value = 1;
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _idle.dispose();
    _pick.dispose();
    super.dispose();
  }

  void _choose(UpgradeChoice choice, int index, int tier) {
    if (_picked != null || widget.selected != null) return;
    setState(() {
      _picked = choice.id;
      _pickedIndex = index;
      _pickedTier = tier;
    });
    final audio = AudioDirector.current;
    audio?.unlock();
    audio?.play(
      tier >= 6
          ? 'transform'
          : tier >= 4
          ? 'evolution'
          : 'pick',
    );
    final ms = _motion ? _pickMs[tier] : 120;
    if (tier >= 5 && _motion) {
      Future<void>.delayed(Duration(milliseconds: (ms * .42).round()), () {
        if (mounted && _picked == choice.id) audio?.play('ultimate');
      });
    }
    _pick
      ..duration = Duration(milliseconds: ms)
      ..forward(from: 0).whenComplete(() {
        if (mounted && _picked == choice.id) widget.onChoose(choice.id);
      });
  }

  static double _span(double t, double start, double length) =>
      ((t - start) / length).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final choices = game.choices;
    final tiers = [for (final c in choices) skillCardTier(game, c)];
    final top = tiers.isEmpty ? 1 : tiers.reduce(math.max);
    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _idle, _pick]),
      builder: (context, _) {
        final intro = _intro.value, idle = _idle.value, pick = _pick.value;
        final picking = _picked != null;
        // Grand choices shake the whole draft at their peak.
        final shakeAmp = !picking || _pickedTier < 5
            ? 0.0
            : (_pickedTier >= 6 ? 9.0 : 4.0) *
                  (1 - _span(pick, .3, .45)) *
                  (pick > .3 ? 1 : 0);
        final shake = Offset(
          math.sin(pick * 90) * shakeAmp,
          math.cos(pick * 77) * shakeAmp * .6,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              key: const Key('upgrade-dark-backdrop'),
              color: Color.lerp(
                Colors.transparent,
                const Color(0xE6060F1C),
                _span(intro, 0, .3),
              )!,
            ),
            // The best card's colour glows behind the whole hand.
            Center(
              child: Opacity(
                opacity: .45 * _span(intro, .1, .4),
                child: _tinted(
                  SkillCardArt.fx('glow'),
                  SkillTier.of(top).color,
                  560,
                ),
              ),
            ),
            Transform.translate(
              offset: shake,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _banner(intro, pick),
                        const SizedBox(height: 22),
                        Semantics(
                          label: tr(
                            game.chestSelection
                                ? '보스 보급 진화 선택'
                                : '레벨 ${game.level} 스킬 선택. 전투 일시정지',
                          ),
                          child: LayoutBuilder(
                            builder: (context, box) => _hand(
                              box.maxWidth,
                              choices,
                              tiers,
                              intro,
                              idle,
                              pick,
                            ),
                          ),
                        ),
                        _actions(intro, picking),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (picking) ..._screenFlash(pick),
          ],
        );
      },
    );
  }

  Widget _banner(double intro, double pick) {
    final t = Curves.easeOutBack.transform(_span(intro, 0, .35));
    final chest = game.chestSelection;
    final fade = _picked == null ? 1.0 : 1 - _span(pick, 0, .25);
    return Opacity(
      opacity: (_span(intro, 0, .2) * fade).clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 1.8 - .8 * t,
        child: Column(
          children: [
            _outlined(chest ? '보스 보급!' : 'LEVEL UP!', 34, const [
              Color(0xFFFFF4A8),
              Color(0xFFFFB627),
            ]),
            Text(
              tr(chest ? '진화할 무기를 고르세요' : '새로운 힘을 고르세요'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFFDCE8F5),
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hand(
    double width,
    List<UpgradeChoice> choices,
    List<int> tiers,
    double intro,
    double idle,
    double pick,
  ) {
    const gap = 4.0;
    final count = math.max(1, choices.length);
    final cardW = math.min(140.0, (width - gap * (count - 1)) / count);
    final rowW = cardW * count + gap * (count - 1);
    return SizedBox(
      width: rowW,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The picked card's burst sits under it, the hand above.
          if (_picked != null)
            Positioned.fill(child: _burst(rowW, cardW, pick, behind: true)),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < choices.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  SizedBox(
                    width: cardW,
                    child: _dealt(
                      i,
                      choices[i],
                      tiers[i],
                      cardW,
                      rowW,
                      gap,
                      intro,
                      idle,
                      pick,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_picked != null)
            Positioned.fill(child: _burst(rowW, cardW, pick, behind: false)),
        ],
      ),
    );
  }

  /// Deal-in, idle and choice motion around one card.
  Widget _dealt(
    int i,
    UpgradeChoice choice,
    int tier,
    double cardW,
    double rowW,
    double gap,
    double intro,
    double idle,
    double pick,
  ) {
    final local = _span(intro * _introMs, 180 + i * 140.0, 620);
    final land = Curves.easeOutBack.transform(local);
    final flip = (1 - Curves.easeOutCubic.transform(local)) * math.pi;
    var dx = 0.0, dy = (1 - land) * 280, scale = .75 + .25 * land;
    var turn = 0.0, opacity = _span(local, 0, .25);
    if (_picked != null) {
      if (_picked == choice.id) {
        final move = Curves.easeOutBack.transform(_span(pick, 0, .32));
        final centre = i * (cardW + gap) + cardW / 2;
        dx = (rowW / 2 - centre) * move;
        dy = -18 * move;
        final peak = tier >= 6
            ? .5
            : tier >= 5
            ? .38
            : .26;
        scale = 1 + peak * move + .06 * math.sin(_span(pick, .3, .3) * math.pi);
        opacity = 1 - _span(pick, .86, .14);
      } else {
        final away = Curves.easeInCubic.transform(_span(pick, 0, .3));
        dy = 160 * away;
        turn = (i < _pickedIndex ? -.35 : .35) * away;
        opacity = 1 - away;
      }
    }
    final card = _card(choice, tier, cardW, idle, pick);
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translateByDouble(dx, dy, 0, 1)
          ..rotateZ(turn)
          ..scaleByDouble(scale, scale, 1, 1)
          ..setEntry(3, 2, .0016)
          ..rotateY(flip),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Face-down half of the flip: a dark silhouette of the frame.
            if (flip > math.pi / 2)
              ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Color(0xFF14243A),
                  BlendMode.srcATop,
                ),
                child: card,
              )
            else
              card,
            if (local > .55 && local < 1)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Opacity(
                      opacity: 1 - _span(local, .55, .45),
                      child: _tinted(
                        SkillCardArt.fx('sparkle'),
                        SkillTier.of(tier).color,
                        cardW * (.6 + 1.4 * _span(local, .55, .45)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(
    UpgradeChoice choice,
    int tier,
    double cardW,
    double idle,
    double pick,
  ) {
    final style = SkillTier.of(tier);
    final (frameSize, window) = SkillCardArt.frames[tier - 1];
    // Windows line up across tiers, but an ornate frame never grows wider
    // than its slot: richer tiers trade a little art size for their crown.
    final s = math.min(
      cardW * .8 / (window.width * frameSize.width),
      cardW / frameSize.width,
    );
    final windowW = window.width * frameSize.width * s;
    final frameW = frameSize.width * s, frameH = frameSize.height * s;
    final winTop = window.top * frameSize.height * s;
    final winH = window.height * frameSize.height * s;
    final boxH = cardW * 1.02;
    final left = cardW / 2 - (window.left * frameSize.width * s + windowW / 2);
    final topY = boxH / 2 - (winTop + winH / 2);
    final windowRect = Rect.fromLTWH(
      left + window.left * frameSize.width * s,
      topY + winTop,
      windowW,
      winH,
    );
    final art = SkillCardArt.art(choice);
    final spin = idle * 2 * math.pi;
    final chosen = _picked == choice.id;
    return Semantics(
      button: true,
      label: tr(choice.title),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('upgrade-${choice.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: _picked == null && widget.selected == null
              ? () => _choose(choice, game.choices.indexOf(choice), tier)
              : null,
          onLongPress: audible(
            () => showDialog<void>(
              context: context,
              builder: (_) => GameDialog(
                title: choice.title,
                child: _ChoiceDetail(game, choice),
              ),
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: boxH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (style.mythic)
                      Positioned(
                        left: cardW / 2 - cardW * .85,
                        top: boxH / 2 - cardW * .85,
                        child: Transform.rotate(
                          angle: -spin,
                          child: Opacity(
                            opacity: .75,
                            child: Image.asset(
                              SkillCardArt.fx('vortex'),
                              width: cardW * 1.7,
                              height: cardW * 1.7,
                            ),
                          ),
                        ),
                      ),
                    if (style.radiant)
                      Positioned(
                        left: cardW / 2 - cardW * .8,
                        top: boxH / 2 - cardW * .8,
                        child: Transform.rotate(
                          angle: spin * .5,
                          child: Opacity(
                            opacity: .45 + .25 * math.sin(spin * 2),
                            child: _tinted(
                              SkillCardArt.fx('rays'),
                              style.color,
                              cardW * 1.6,
                            ),
                          ),
                        ),
                      ),
                    // window: tier-tinted backdrop, illustration, shine
                    Positioned.fromRect(
                      rect: windowRect,
                      child: ClipRect(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    style.color.withValues(alpha: .55),
                                    style.deep,
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(windowW * .06),
                              child: art != null
                                  ? Image.asset(
                                      art,
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.medium,
                                    )
                                  : FittedBox(child: _fallbackIcon(choice)),
                            ),
                            _shine(idle, tier),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: left,
                      top: topY,
                      width: frameW,
                      height: frameH,
                      child: Image.asset(
                        SkillCardArt.frame(tier),
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    if (style.mythic)
                      for (var k = 0; k < 3; k++)
                        Positioned(
                          left:
                              cardW / 2 +
                              math.cos(spin + k * 2.1) * cardW * .55 -
                              12,
                          top:
                              boxH / 2 +
                              math.sin(spin + k * 2.1) * cardW * .62 -
                              12,
                          child: Opacity(
                            opacity: .6 + .4 * math.sin(spin * 3 + k),
                            child: Image.asset(
                              SkillCardArt.fx('sparkle'),
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: windowRect.bottom - 13,
                      child: Center(child: _badge(choice, style)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(choice.title),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  color: chosen ? style.color : Colors.white,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
                ),
              ),
              const SizedBox(height: 4),
              _progress(choice, style),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  tr(choice.description),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: Color(0xFFD5E1EE),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A light band that sweeps across the art once per idle cycle.
  Widget _shine(double idle, int tier) {
    final t = _span(idle, .1 + tier * .05, .3);
    if (t <= 0 || t >= 1) return const SizedBox.shrink();
    return IgnorePointer(
      child: FractionalTranslation(
        translation: Offset(-1.2 + 2.4 * t, 0),
        child: Transform.rotate(
          angle: .5,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x00FFFFFF),
                  Color(0x66FFFFFF),
                  Color(0x00FFFFFF),
                ],
                stops: [.35, .5, .65],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(UpgradeChoice choice, SkillTier style) {
    final id = choice.id.contains('|')
        ? choice.id.substring(choice.id.indexOf('|') + 1)
        : choice.id;
    final rank = skillRank(game, choice);
    final label = switch (choice.growth) {
      'new' => 'NEW',
      'enh' => '${tr('강화')} ${game.enh(id) + 1}',
      'evo' => '${tr('진화')} ${game.evo(id) + 1}',
      'ult' => tr('궁극'),
      _ =>
        choice.id == 'repair'
            ? tr('회복')
            : choice.specialization
            ? tr('특화')
            : choice.evolution
            ? 'EVO'
            : 'Lv.${rank + 1}',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [style.color, Color.lerp(style.color, style.deep, .45)!],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0D1626), width: 2),
        boxShadow: [
          BoxShadow(color: style.color.withValues(alpha: .6), blurRadius: 8),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w900,
          color: Color(0xFF0D1626),
        ),
      ),
    );
  }

  /// Stage pips for weapons (강화 ●●○ · 진화 ○○○), level for support skills.
  Widget _progress(UpgradeChoice choice, SkillTier style) {
    final id = choice.id.contains('|')
        ? choice.id.substring(choice.id.indexOf('|') + 1)
        : null;
    if (id == null || choice.growth == 'new' || choice.growth == 'ult') {
      return Text(
        tr(
          choice.growth == 'ult'
              ? '변신!'
              : choice.growth == 'new'
              ? '새 무기'
              : style.name,
        ),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: style.color,
        ),
      );
    }
    final next = choice.growth == 'enh'
        ? (enh: game.enh(id) + 1, evo: game.evo(id))
        : (enh: game.enh(id), evo: game.evo(id) + 1);
    Widget pips(int filled, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var k = 0; k < 3; k++)
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: k < filled ? color : const Color(0xFF26364A),
              border: Border.all(color: const Color(0xFF0D1626)),
            ),
          ),
      ],
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        pips(next.enh, const Color(0xFF6CC4FF)),
        const SizedBox(width: 6),
        pips(next.evo, const Color(0xFFFF8A4C)),
      ],
    );
  }

  Widget _fallbackIcon(UpgradeChoice choice) =>
      choice.iconKey.startsWith('part:') && game.unifiedModules
      ? ModulePartIcon(
          game.moduleLoadout!.parts[choice.iconKey.substring(5)]!.definition,
          size: 44,
        )
      : RasterSkillIcon(choice.iconKey, size: 44);

  /// Light burst around the picked card once it reaches the centre.
  Widget _burst(
    double rowW,
    double cardW,
    double pick, {
    required bool behind,
  }) {
    final style = SkillTier.of(_pickedTier);
    final tier = _pickedTier;
    final centre = Offset(rowW / 2, cardW * .98 / 2 - 18);
    Widget at(double size, Widget child) => Positioned(
      left: centre.dx - size / 2,
      top: centre.dy - size / 2,
      width: size,
      height: size,
      child: child,
    );
    final layers = <Widget>[];
    if (behind) {
      if (tier >= 6) {
        final v = _span(pick, .12, .55);
        layers.add(
          at(
            cardW * 4.2 * Curves.easeOutCubic.transform(v),
            Transform.rotate(
              angle: pick * 7,
              child: Opacity(
                opacity: math.sin(math.pi * _span(pick, .1, .9)),
                child: Image.asset(SkillCardArt.fx('vortex')),
              ),
            ),
          ),
        );
      }
      if (tier >= 3) {
        final r = _span(pick, .24, .62);
        layers.add(
          at(
            cardW * (1.2 + 2.4 * Curves.easeOut.transform(r)),
            Transform.rotate(
              angle: r * 1.6,
              child: Opacity(
                opacity: math.sin(math.pi * r) * (tier >= 5 ? 1 : .7),
                child: _tinted(
                  SkillCardArt.fx('rays'),
                  style.color,
                  double.infinity,
                ),
              ),
            ),
          ),
        );
      }
      final g = _span(pick, .22, .5);
      layers.add(
        at(
          cardW * (1.4 + (tier >= 5 ? 1.6 : .8) * g),
          Opacity(
            opacity: math.sin(math.pi * g),
            child: _tinted(
              SkillCardArt.fx('glow'),
              style.color,
              double.infinity,
            ),
          ),
        ),
      );
    } else {
      final rings = tier >= 6
          ? 3
          : tier >= 5
          ? 2
          : 1;
      for (var k = 0; k < rings; k++) {
        final r = _span(pick, .3 + k * .13, .45);
        if (r <= 0 || r >= 1) continue;
        layers.add(
          at(
            cardW * (.6 + 3.4 * Curves.easeOutCubic.transform(r)),
            Opacity(
              opacity: 1 - r,
              child: _tinted(
                SkillCardArt.fx('ring'),
                k.isEven ? style.color : Colors.white,
                double.infinity,
              ),
            ),
          ),
        );
      }
      final count = tier >= 6
          ? 16
          : tier >= 4
          ? 11
          : 8;
      final f = _span(pick, .3, .6);
      if (f > 0 && f < 1) {
        final ease = Curves.easeOutCubic.transform(f);
        for (var k = 0; k < count; k++) {
          final a = k * 2 * math.pi / count + tier;
          final d = cardW * (.35 + (1.3 + (k % 3) * .35) * ease);
          final size = (tier >= 5 ? 30.0 : 24.0) * (1 - f * .5);
          layers.add(
            Positioned(
              left: centre.dx + math.cos(a) * d - size / 2,
              top: centre.dy + math.sin(a) * d - size / 2,
              width: size,
              height: size,
              child: Opacity(
                opacity: 1 - f,
                child: Image.asset(SkillCardArt.fx('sparkle')),
              ),
            ),
          );
        }
      }
      if (tier >= 4) {
        final p = _span(pick, .32, .55);
        layers.add(
          at(
            cardW * (1 + 2.2 * p),
            Opacity(
              opacity: (1 - p) * .95,
              child: Image.asset(SkillCardArt.fx('particles')),
            ),
          ),
        );
      }
      if (tier >= 6) {
        for (final (start, angle, side) in [
          (.34, -.5, -1.0),
          (.48, .6, 1.0),
          (.6, -.2, .2),
        ]) {
          final l = _span(pick, start, .12);
          if (l <= 0 || l >= 1) continue;
          layers.add(
            Positioned(
              left: centre.dx + side * cardW * .7 - cardW * .7,
              top: centre.dy - cardW * .9,
              width: cardW * 1.4,
              height: cardW * 1.4,
              child: Transform.rotate(
                angle: angle,
                child: Opacity(
                  opacity: math.sin(math.pi * l),
                  child: Image.asset(SkillCardArt.fx('lightning')),
                ),
              ),
            ),
          );
        }
        final fl = _span(pick, .36, .3);
        layers.add(
          at(
            cardW * (1 + 2 * fl),
            Opacity(
              opacity: math.sin(math.pi * fl),
              child: Image.asset(SkillCardArt.fx('flare')),
            ),
          ),
        );
      }
      if (tier >= 4) {
        final t = _span(pick, .3, .25);
        final hold = 1 - _span(pick, .85, .15);
        layers.add(
          Positioned(
            left: -60,
            right: -60,
            top: centre.dy - (tier >= 6 ? 24 : 20),
            child: Opacity(
              opacity: (t * hold).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 2.6 - 1.6 * Curves.easeOutBack.transform(t),
                child: Center(
                  child: _outlined(
                    tier >= 6
                        ? '궁극 변신!'
                        : tier >= 5
                        ? '진화 완성!'
                        : '진화!',
                    tier >= 6 ? 36 : 30,
                    [Colors.white, style.color],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return IgnorePointer(
      child: Stack(clipBehavior: Clip.none, children: layers),
    );
  }

  /// Gold and purple choices strike a sharp flash at their peak: a fast
  /// white rise, then a quick fade through the tier colour.
  List<Widget> _screenFlash(double pick) {
    if (_pickedTier < 5) return const [];
    final rise = _span(pick, .3, .05), fall = _span(pick, .35, .16);
    final strength = rise * (1 - fall);
    if (strength <= 0) return const [];
    final peak = _pickedTier >= 6 ? .9 : .5;
    return [
      IgnorePointer(
        child: ColoredBox(
          color: Color.lerp(
            Colors.white,
            SkillTier.of(_pickedTier).color,
            fall,
          )!.withValues(alpha: peak * strength),
        ),
      ),
    ];
  }

  Widget _actions(double intro, bool picking) {
    final show = _span(intro, .7, .3) * (picking ? 0 : 1);
    return Opacity(
      opacity: show,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!game.chestSelection && game.rerolls > 0) ...[
            const SizedBox(height: 14),
            Center(
              child: SizedBox(
                width: 264,
                child: GameActionButton(
                  label: '다시 뽑기 ${game.rerolls}회',
                  displayLabel: '재추첨 ${game.rerolls}회',
                  icon: Icons.refresh,
                  onPressed: picking || widget.selected != null
                      ? null
                      : widget.onReroll,
                ),
              ),
            ),
          ],
          if (widget.onReplace != null) ...[
            const SizedBox(height: 12),
            Center(
              child: GameActionButton(
                label: '보조 교체',
                icon: Icons.swap_horiz,
                onPressed: picking || widget.selected != null
                    ? null
                    : widget.onReplace,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// A light sprite recoloured to [color] (white keeps its highlights).
  static Widget _tinted(String asset, Color color, double size) => Image.asset(
    asset,
    width: size.isFinite ? size : null,
    height: size.isFinite ? size : null,
    color: color,
    colorBlendMode: BlendMode.modulate,
    filterQuality: FilterQuality.medium,
  );

  /// Big outlined game lettering with a vertical colour gradient.
  static Widget _outlined(String text, double size, List<Color> colors) {
    final label = tr(text);
    return Stack(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            height: 1.1,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * .16
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF1A0F2E),
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ).createShader(bounds),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w900,
              height: 1.1,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// v12.14: a card's long-press detail as labelled groups — the effect, then
/// its role (or growth effect) and any synergy, instead of one text block.
class _ChoiceDetail extends StatelessWidget {
  const _ChoiceDetail(this.game, this.choice);
  final GameEngine game;
  final UpgradeChoice choice;
  static const _synergy = '연계: ';
  @override
  Widget build(BuildContext context) {
    AppLanguage.watch(context);
    final lines = game
        .choiceDetail(choice)
        .split('\n')
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return const SizedBox.shrink();
    final rest = [
      for (final l in lines.skip(1))
        if (!l.startsWith(_synergy)) l,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(lines.first),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            height: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 10),
          GameInfoBlock(
            label: game.modular ? '효과' : '역할',
            tone: GameTone.sky,
            detail: rest.join('\n'),
          ),
        ],
        for (final l in lines.skip(1))
          if (l.startsWith(_synergy)) ...[
            const SizedBox(height: 8),
            GameInfoBlock(
              label: '연계',
              tone: GameTone.good,
              lead: l.substring(_synergy.length),
            ),
          ],
      ],
    );
  }
}
