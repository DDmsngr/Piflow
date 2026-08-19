import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'achievements.dart';
import 'audio.dart';
import 'models.dart';
import 'scoring.dart';
import 'skins.dart';

/// Snapshot of transient in-game FX for the HUD overlay to render.
/// Rebuilt only when something actually changes (not per-frame) so
/// [ValueListenableBuilder] doesn't churn.
@immutable
class GameFxState {
  final PiggyType? pendingReward;
  final double freezeRemaining;
  final double freezeMax;
  final double universalRemaining;
  final double universalMax;
  final PiggyColor? universalColor;
  final int comboFlashSize;      // 0 == no flash active
  final double comboFlashAt;     // wall time of the flash (for cross-fade)
  /// Colours that are on the board right now but have zero corresponding
  /// piggies anywhere (queue + waiting + belt). If non-empty the HUD shows
  /// a warning banner "нужен цвет: X".
  final List<PiggyColor> missingColors;

  const GameFxState({
    this.pendingReward,
    this.freezeRemaining = 0,
    this.freezeMax = 0,
    this.universalRemaining = 0,
    this.universalMax = 0,
    this.universalColor,
    this.comboFlashSize = 0,
    this.comboFlashAt = 0,
    this.missingColors = const [],
  });

  static const idle = GameFxState();

  GameFxState copy({
    Object? pendingReward = _sentinel,
    double? freezeRemaining,
    double? freezeMax,
    double? universalRemaining,
    double? universalMax,
    Object? universalColor = _sentinel,
    int? comboFlashSize,
    double? comboFlashAt,
    List<PiggyColor>? missingColors,
  }) {
    return GameFxState(
      pendingReward: identical(pendingReward, _sentinel)
          ? this.pendingReward
          : pendingReward as PiggyType?,
      freezeRemaining: freezeRemaining ?? this.freezeRemaining,
      freezeMax: freezeMax ?? this.freezeMax,
      universalRemaining: universalRemaining ?? this.universalRemaining,
      universalMax: universalMax ?? this.universalMax,
      universalColor: identical(universalColor, _sentinel)
          ? this.universalColor
          : universalColor as PiggyColor?,
      comboFlashSize: comboFlashSize ?? this.comboFlashSize,
      comboFlashAt: comboFlashAt ?? this.comboFlashAt,
      missingColors: missingColors ?? this.missingColors,
    );
  }

  static const Object _sentinel = Object();
}

class PixelFlowGame extends FlameGame with HasCollisionDetection {
  PixelFlowGame({required this.level, this.onWin, this.onLose});

  final LevelConfig level;
  final VoidCallback? onWin;
  final VoidCallback? onLose;

  late BoardComponent board;
  late ConveyorComponent conveyor;
  late QueueComponent piggyQueue;
  late WaitingSlotsComponent slots;
  SpriteComponent? _bgSprite;

  // Reactive counter for the HUD.
  final ValueNotifier<int> remainingBlocks = ValueNotifier<int>(0);

  // Reactive FX snapshot (pending reward, freeze/universal timers, combo flash).
  // Updated only when values actually change → cheap on the widget tree.
  final ValueNotifier<GameFxState> fx = ValueNotifier<GameFxState>(GameFxState.idle);

  /// Throttle for pushing timer-only ticks into [fx] (once every 100ms is
  /// plenty for a countdown indicator, per-frame would over-rebuild).
  double _fxTickAccum = 0;

  // Scoring bookkeeping.
  int shotsFired = 0;
  int combosTriggered = 0;

  // Puzzle-mode play stats (2026-08-11 redesign).
  int launchesMade = 0;
  int launchedAmmoPool = 0;
  final Set<PiggyColor> launchedColors = <PiggyColor>{};
  final List<PiggyColor> launchedSequence = <PiggyColor>[];

  /// Called by [PiggyComponent.onTapDown] whenever a piggy leaves the queue
  /// (whether to belt or via direct queue→waiting transfer). Both count as a
  /// "launch" per the design contract — dead-color transfers must be punished
  /// too (see L3 tutorial).
  void recordLaunch(PiggyComponent p) {
    launchesMade++;
    launchedAmmoPool += p.ammo;
    launchedColors.add(p.piggyColor);
    launchedSequence.add(p.piggyColor);
  }

  /// Legacy result — kept for the current [game_screen.dart] star overlay
  /// during transition. New puzzle-mode UI uses [computeLevelResult].
  ({int stars, int score}) computeResult() {
    final total = level.totalBlocks;
    final ratio = total == 0 ? 1.0 : shotsFired / total;
    final int stars = ratio <= 1.2 ? 3 : (ratio <= 1.7 ? 2 : 1);
    const perStar = [0, 50, 100, 150];
    final base = 100 + perStar[stars] + combosTriggered * 10;
    final score = stars >= 3 ? base * 2 : base;
    return (stars: stars, score: score);
  }

  /// Full puzzle-mode evaluation. Called by the result-overlay UI after WIN
  /// or arsenal-exhaustion. Returns a [LevelResult] with rank, deviation
  /// bars, checklist, and motivational hint.
  ///
  /// [cleared] must reflect the actual board state at end-of-level — true if
  /// every destructible block is gone, false if arsenal ran out first.
  LevelResult computeLevelResult({required bool cleared}) {
    // unused ammo across LAUNCHED piggies still alive (leaving + waiting +
    // belt). Un-launched piggies (still in queue) do NOT count — spare, not
    // waste. See scoring.dart docstring.
    var unused = 0;
    for (final p in world.children.whereType<PiggyComponent>()) {
      if (p.state == PiggyState.inQueue) continue;
      if (p.ammo > 0) unused += p.ammo;
    }
    // For consistency with launchedAmmoPool - shotsFired: the game engine's
    // per-piggy ammo counter is decremented only on real shots, so the sum
    // above == launchedAmmoPool - shotsFired for still-alive piggies. But
    // some piggies may have been GC'd (removed after leaving). We fall back
    // to the pool-minus-shots formula which is invariant.
    final poolFormula = (launchedAmmoPool - shotsFired).clamp(0, 1 << 30);
    final unusedAmmo = poolFormula > unused ? poolFormula : unused;

    final cfg = LevelTargetConfig(
      targetLaunches: level.targetLaunches ?? level.arsenalCount,
      targetHits: level.effectiveTargetHits,
      allowedColors: level.boardColors,
      expectedCombos: level.expectedCombos,
      softLaunchTolerance: level.softLaunchTolerance,
      failLaunchOverflow: level.failLaunchOverflow,
      perfectLaunchTolerance: level.perfectLaunchTolerance,
      masteryChallenge: level.masteryChallenge,
    );
    final stats = ActualPlayStats(
      launchesMade: launchesMade,
      shotsFired: shotsFired,
      unusedAmmo: unusedAmmo,
      colorsUsed: launchedColors,
      combosTriggered: combosTriggered,
      actualSequence:
          level.inventory == null ? null : List<PiggyColor>.from(launchedSequence),
      cleared: cleared,
    );
    return const LevelScorer().evaluate(cfg, stats);
  }

  static const double worldWidth = 400;
  static const double worldHeight = 900;

  // Measured from board_frame.png — belt chevron centres far from corners.
  static const double _trackRelL = 0.1095;
  static const double _trackRelR = 0.8889;
  static const double _trackRelT = 0.0867;
  static const double _trackRelB = 0.8110;
  // dark inner grid area
  static const double _boardRelL = 0.250;
  static const double _boardRelR = 0.748;
  static const double _boardRelT = 0.250;
  static const double _boardRelB = 0.749;
  // frame image aspect (941 x 1672)
  static const double _frameAspect = 941.0 / 1672.0;

  final Map<String, Sprite> _sprites = {};
  Sprite sprite(String name) {
    final s = _sprites[name];
    if (s == null) throw StateError('Sprite $name not preloaded');
    return s;
  }

  @override
  Color backgroundColor() => const Color(0xFF2A2140);

  /// Cached active skin. Loaded once at game start; changing skin in the shop
  /// takes effect on the next played level (no live-swap mid-game).
  SkinId activeSkin = SkinId.none;

  Future<void> _preloadImages() async {
    activeSkin = await SkinManager.loadActive();
    final names = <String>[
      'bg_game.png',
      'board_frame.png',
      for (final c in PiggyColor.values) 'piggy_${c.name}.png',
      for (final c in PiggyColor.values) 'piggy_${c.name}_shoot.png',
      for (final c in PiggyColor.values) 'block_${c.name}.png',
      for (final c in PiggyColor.values) 'ball_${c.name}.png',
      for (final t in PiggyType.values)
        if (t.spriteAsset != null) t.spriteAsset!,
      // Only preload skin art if it actually exists on disk — hasArt gate
      // avoids crashes while placeholders (hasArt=false) are in play.
      if (activeSkin != SkinId.none && activeSkin.hasArt)
        'skin_${activeSkin.id}.png',
    ];
    for (final n in names) {
      _sprites[n] = await Sprite.load(n);
    }
  }

  @override
  Future<void> onLoad() async {
    await _preloadImages();
    await AudioService.preload();

    camera.viewfinder.visibleGameSize = Vector2(worldWidth, worldHeight);
    camera.viewfinder.position = Vector2(worldWidth / 2, worldHeight / 2);

    // Background
    _bgSprite = SpriteComponent(
      sprite: sprite('bg_game.png'),
      size: Vector2(worldWidth, worldHeight),
      position: Vector2.zero(),
      priority: -20,
    );
    world.add(_bgSprite!);

    // Frame: keep true aspect ratio, fit into top region.
    final frameW = worldWidth - 20;
    final frameH = frameW / _frameAspect;
    final frameSize = Vector2(frameW, frameH);
    final framePos = Vector2(10, 20);

    // Frame sprite (below everything except bg)
    world.add(SpriteComponent(
      sprite: sprite('board_frame.png'),
      size: frameSize,
      position: framePos,
      priority: -10,
    ));

    // Board area from measured relative coords
    final boardRect = Rect.fromLTRB(
      framePos.x + frameW * _boardRelL,
      framePos.y + frameH * _boardRelT,
      framePos.x + frameW * _boardRelR,
      framePos.y + frameH * _boardRelB,
    );
    board = BoardComponent(level: level, area: boardRect);
    world.add(board);

    // Conveyor: track along measured belt centre line
    final trackRect = Rect.fromLTRB(
      framePos.x + frameW * _trackRelL,
      framePos.y + frameH * _trackRelT,
      framePos.x + frameW * _trackRelR,
      framePos.y + frameH * _trackRelB,
    );
    conveyor = ConveyorComponent(trackRect: trackRect);
    world.add(conveyor);

    // Waiting slots row
    final slotsRect = Rect.fromLTWH(20, worldHeight - 250, worldWidth - 40, 60);
    slots = WaitingSlotsComponent(area: slotsRect, count: level.waitingSlots);
    world.add(slots);

    // Queue at bottom — puzzle mode pulls from the pre-loaded arsenal FIFO;
    // legacy mode still uses the weighted RNG spawner.
    final queueRect = Rect.fromLTWH(20, worldHeight - 170, worldWidth - 40, 70);
    piggyQueue = QueueComponent(
      area: queueRect,
      game: this,
      slotCount: level.queueSlots,
      spawnInterval: level.spawnInterval,
      palette: level.spawnPalette,
      ammoMin: level.ammoMin,
      ammoMax: level.ammoMax,
      arsenal: level.inventory,
    );
    world.add(piggyQueue);
  }

  bool _finished = false;
  double _loseCheckTimer = 0;

  // Combo bookkeeping: count pops within the last _comboWindow seconds.
  final List<double> _recentPopTimes = [];
  static const double _comboWindow = 0.6;
  static const int _comboThreshold = 5;
  double _shakeTime = 0;
  double _shakeIntensity = 0;
  double _gameTime = 0;

  /// Queued reward — the very next piggy the spawner produces will be of this
  /// type (instead of a normal one). Cleared when the reward spawns.
  PiggyType? pendingRewardType;

  // Seeded from microseconds so restarts of the same level get a different
  // spawn/reward sequence — otherwise players see the same colour order after
  // each retry within the same second.
  final math.Random _rewardRng =
      math.Random(DateTime.now().microsecondsSinceEpoch);

  /// Wall time when the last reward was granted. Enforces [_rewardCooldown]
  /// between combos so a single well-placed shot doesn't rain 4 specials.
  double _lastRewardAt = -100;
  static const double _rewardCooldown = 8.0;

  // Special-piggy transient state ---------------------------------------
  /// Multiplier on piggy travel speed. Freeze-piggy sets it low temporarily.
  double beltSpeedMultiplier = 1.0;
  double _freezeTimer = 0;

  /// Ramps 1.0 → 1.5 across the level: as more blocks fall, the belt
  /// accelerates. Multiplies with [beltSpeedMultiplier] so freeze still works
  /// (freeze × ramp × base).
  double dynamicSpeedFactor = 1.0;
  static const double _dynamicSpeedPeak = 1.5;
  /// If non-null, normal piggies may shoot any block of this colour regardless
  /// of their own colour. Universal-piggy sets it after firing.
  PiggyColor? universalColor;
  double _universalTimer = 0;

  /// Called by BlockComponent when a block actually pops (not just planned).
  void notePop() {
    // Light haptic per pop — subtle, feels "clicky". Silent on web.
    HapticFeedback.selectionClick();
    _recentPopTimes.add(_gameTime);
    _recentPopTimes.removeWhere((t) => _gameTime - t > _comboWindow);
    if (_recentPopTimes.length >= _comboThreshold && _shakeTime <= 0) {
      _shakeTime = 0.35;
      _shakeIntensity = 6 + math.min(6, _recentPopTimes.length - _comboThreshold).toDouble();
      combosTriggered++;
      HapticFeedback.mediumImpact();
      // Publish combo flash for the HUD.
      final comboSize = _recentPopTimes.length;
      fx.value = fx.value.copy(
        comboFlashSize: comboSize,
        comboFlashAt: _gameTime,
      );
      _maybeAwardSpecialPiggy();
      // Achievement hooks — fire-and-forget, don't block combo flow.
      AchievementManager.unlock(Achievement.firstCombo);
      if (comboSize >= 8) AchievementManager.unlock(Achievement.bigCombo);
      if (comboSize >= 12) AchievementManager.unlock(Achievement.megaCombo);
    }
  }

  /// Combo of 5+ blocks pops in a short window → queue up a special piggy.
  /// Multiple guards keep specials from becoming free wins:
  ///  - level must actually offer rewards
  ///  - no other reward pending or already sitting unspent in queue/waiting
  ///  - cooldown of [_rewardCooldown] seconds since the last granted reward
  void _maybeAwardSpecialPiggy() {
    if (pendingRewardType != null) return;
    final rewards = level.comboRewards;
    if (rewards.isEmpty) return;
    if (_gameTime - _lastRewardAt < _rewardCooldown) return;
    if (_hasUnspentSpecial()) return;
    pendingRewardType = rewards[_rewardRng.nextInt(rewards.length)];
    _lastRewardAt = _gameTime;
    fx.value = fx.value.copy(pendingReward: pendingRewardType);
  }

  /// True if there's already a special piggy sitting in queue or waiting-slots
  /// that the player hasn't used. Prevents stockpiling.
  bool _hasUnspentSpecial() {
    for (final p in world.children.whereType<PiggyComponent>()) {
      if (!p.type.isSpecial) continue;
      if (p.state == PiggyState.inQueue || p.state == PiggyState.inSlot) {
        return true;
      }
    }
    return false;
  }

  /// Called by the spawner right after it consumed [pendingRewardType].
  void notePendingRewardConsumed() {
    if (fx.value.pendingReward != null) {
      fx.value = fx.value.copy(pendingReward: null);
    }
  }

  /// Triggered by freeze-piggy on impact: slow down the belt for [seconds].
  void applyFreeze(double seconds) {
    _freezeTimer = math.max(_freezeTimer, seconds);
    beltSpeedMultiplier = 0.25;
    fx.value = fx.value.copy(
      freezeRemaining: _freezeTimer,
      freezeMax: math.max(fx.value.freezeMax, seconds),
    );
  }

  /// Universal-piggy on impact: for a few seconds, any normal piggy can pop
  /// any block of [color] (in addition to their own colour).
  void applyUniversal(PiggyColor color, double seconds) {
    universalColor = color;
    _universalTimer = math.max(_universalTimer, seconds);
    fx.value = fx.value.copy(
      universalColor: color,
      universalRemaining: _universalTimer,
      universalMax: math.max(fx.value.universalMax, seconds),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _gameTime += dt;

    // Decay freeze / universal timers.
    if (_freezeTimer > 0) {
      _freezeTimer -= dt;
      if (_freezeTimer <= 0) {
        _freezeTimer = 0;
        beltSpeedMultiplier = 1.0;
        fx.value = fx.value.copy(freezeRemaining: 0, freezeMax: 0);
      }
    }
    if (_universalTimer > 0) {
      _universalTimer -= dt;
      if (_universalTimer <= 0) {
        _universalTimer = 0;
        universalColor = null;
        fx.value = fx.value.copy(
          universalRemaining: 0,
          universalMax: 0,
          universalColor: null,
        );
      }
    }

    // Throttle FX ticks (timers, combo flash decay) to ~10 Hz.
    _fxTickAccum += dt;
    if (_fxTickAccum >= 0.1) {
      _fxTickAccum = 0;
      final current = fx.value;
      var next = current;
      if (_freezeTimer > 0 && (current.freezeRemaining - _freezeTimer).abs() > 0.05) {
        next = next.copy(freezeRemaining: _freezeTimer);
      }
      if (_universalTimer > 0 && (current.universalRemaining - _universalTimer).abs() > 0.05) {
        next = next.copy(universalRemaining: _universalTimer);
      }
      // Combo flash lasts ~0.9s then clears itself.
      if (current.comboFlashSize > 0 && _gameTime - current.comboFlashAt > 0.9) {
        next = next.copy(comboFlashSize: 0);
      }
      // Warning: which colours on board have zero piggies matching them?
      final missing = _computeMissingColors();
      if (!_sameList(missing, current.missingColors)) {
        next = next.copy(missingColors: missing);
      }
      if (!identical(next, current)) fx.value = next;
    }

    // Apply / decay screen-shake by nudging the camera off-centre.
    if (_shakeTime > 0) {
      _shakeTime -= dt;
      final k = (_shakeTime / 0.35).clamp(0.0, 1.0);
      final dx = (math.Random().nextDouble() * 2 - 1) * _shakeIntensity * k;
      final dy = (math.Random().nextDouble() * 2 - 1) * _shakeIntensity * k;
      camera.viewfinder.position = Vector2(
        worldWidth / 2 + dx,
        worldHeight / 2 + dy,
      );
      if (_shakeTime <= 0) {
        camera.viewfinder.position = Vector2(worldWidth / 2, worldHeight / 2);
      }
    }

    if (_finished) return;

    final n = board.remainingBlocks;
    if (remainingBlocks.value != n) remainingBlocks.value = n;

    // Ramp belt speed with level progress. progress=0 at start, 1 near win.
    final total = level.totalBlocks;
    if (total > 0) {
      final progress = (1.0 - n / total).clamp(0.0, 1.0);
      dynamicSpeedFactor = 1.0 + progress * (_dynamicSpeedPeak - 1.0);
    }

    if (n == 0) {
      _finished = true;
      AudioService.win();
      // Give the last pop-effect a moment to breathe before the overlay.
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!_finished || onWin == null) return;
        onWin!();
      });
      return;
    }

    // End-detect: throttle to twice a second.
    _loseCheckTimer -= dt;
    if (_loseCheckTimer <= 0) {
      _loseCheckTimer = 0.5;
      // Puzzle mode: soft end when arsenal drained AND no more piggies alive
      // AND board still has blocks. No STUCK screen — result overlay carries
      // the drama via rank D + retry (per Aleksey 2026-08-11).
      if (level.isPuzzleMode) {
        if (_isArsenalOut() || _isPuzzleStuck()) {
          _finished = true;
          AudioService.lose();
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!_finished || onLose == null) return;
            onLose!();
          });
        }
        return;
      }
      // Legacy mode keeps the old hard STUCK detection.
      if (_isStuck()) {
        _finished = true;
        AudioService.lose();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_finished || onLose == null) return;
          onLose!();
        });
      }
    }
  }

  /// Puzzle-mode end: FIFO pool empty AND no piggy left in queue/waiting/belt
  /// that could still shoot something. Blocks remain (otherwise we'd have
  /// won earlier in this same tick).
  bool _isArsenalOut() {
    if (!piggyQueue.isArsenalExhausted) return false;
    for (final p in world.children.whereType<PiggyComponent>()) {
      if (p.state == PiggyState.leaving) continue;
      // Any live piggy anywhere = play continues.
      return false;
    }
    return true;
  }

  /// Puzzle-mode early game-over: FIFO pool empty AND every live piggy is
  /// useless against the remaining board (colour mismatch, ammo=0, no
  /// specials). Waiting-slot has no rescue value here — the spawner is
  /// permanently silent so a free slot doesn't refill. Trigger the lose
  /// overlay immediately instead of making the player wait through empty
  /// belt-laps until the last piggy times out.
  bool _isPuzzleStuck() {
    if (!piggyQueue.isArsenalExhausted) return false;

    final aliveColors = <PiggyColor>{};
    var hasAnyBlock = false;
    for (final row in board.cells) {
      for (final b in row) {
        if (b == null || b.spec.isStone || b.spec.isPortal || b.isBeingRemoved) continue;
        hasAnyBlock = true;
        final c = b.currentColor;
        if (c != null) aliveColors.add(c);
      }
    }
    if (!hasAnyBlock) return false; // caught by win-check upstream

    for (final p in world.children.whereType<PiggyComponent>()) {
      if (p.state == PiggyState.leaving) continue;
      if (p.ammo <= 0) continue;
      if (p.type.isSpecial) return false;
      if (aliveColors.contains(p.piggyColor)) return false;
      if (universalColor != null && p.piggyColor == universalColor) return false;
    }
    return true;
  }

  /// Stuck rule (per Alexey 2026-08-10): "count only the piggies in the
  /// waiting-SLOTS, ignore the spawn queue". Queue is a spawn buffer, waiting
  /// is the player's actual inventory. If the inventory + belt has nothing
  /// useful AND the player has no way to swap it, it's game over.
  ///
  /// Precisely we return true when ALL of these hold:
  ///   1. No belt-piggy with useful ammo (she'd shoot something).
  ///   2. No useful waiting-slot piggy (specials count; normals if colour is
  ///      on board OR matches universalColor).
  ///   3. Waiting-slots are full — otherwise the player can direct-transfer a
  ///      queue-piggy into a free waiting-slot and the spawner refills queue.
  /// Colours currently on the board that have zero corresponding piggy in
  /// queue+waiting+belt. Empty means the player has at least one of each
  /// needed colour somewhere in her inventory.
  List<PiggyColor> _computeMissingColors() {
    final aliveColors = <PiggyColor>{};
    for (final row in board.cells) {
      for (final b in row) {
        if (b == null || b.spec.isStone || b.spec.isPortal || b.isBeingRemoved) continue;
        final c = b.currentColor;
        if (c != null) aliveColors.add(c);
      }
    }
    if (aliveColors.isEmpty) return const [];

    final coveredColors = <PiggyColor>{};
    var hasSpecial = false;
    for (final p in world.children.whereType<PiggyComponent>()) {
      if (p.state == PiggyState.leaving) continue;
      if (p.type.isSpecial) { hasSpecial = true; continue; }
      coveredColors.add(p.piggyColor);
    }
    if (hasSpecial) return const []; // specials cover anything
    if (universalColor != null) coveredColors.add(universalColor!);

    return aliveColors.difference(coveredColors).toList();
  }

  static bool _sameList(List<PiggyColor> a, List<PiggyColor> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _isStuck() {
    final aliveColors = <PiggyColor>{};
    var hasAnyBlock = false;
    for (final row in board.cells) {
      for (final b in row) {
        if (b == null || b.spec.isStone || b.spec.isPortal || b.isBeingRemoved) continue;
        hasAnyBlock = true;
        final c = b.currentColor;
        if (c != null) aliveColors.add(c);
      }
    }
    if (!hasAnyBlock) return false; // win

    // A belt-piggy with matching ammo is going to shoot; not stuck.
    for (final p in _piggiesOnBelt) {
      if (p.ammo <= 0) continue;
      if (p.type.isSpecial) return false;
      if (aliveColors.contains(p.piggyColor)) return false;
      if (universalColor != null && p.piggyColor == universalColor) return false;
    }

    // Check waiting-slot piggies ONLY (queue-piggies don't count as inventory
    // per the user's rule — they're a spawn buffer).
    for (final p in world.children.whereType<PiggyComponent>()) {
      if (p.state != PiggyState.inSlot) continue;
      if (p.type.isSpecial) return false;
      if (aliveColors.contains(p.piggyColor)) return false;
      if (universalColor != null && p.piggyColor == universalColor) return false;
    }

    // Waiting has a free spot → the player can park a queue-piggy there and
    // keep the spawner rolling; not stuck yet.
    if (slots.hasFreeSlot) return false;

    return true;
  }

  Iterable<PiggyComponent> get _piggiesOnBelt => world.children
      .whereType<PiggyComponent>()
      .where((p) => p.state == PiggyState.onConveyor || p.state == PiggyState.shooting);

  int get conveyorLoad => _piggiesOnBelt.length;

  /// Reason a piggy currently sitting in the QUEUE (bottom row) cannot be
  /// launched. Queue-launches need TWO things:
  ///   - a free belt slot (`belt-busy` if not),
  ///   - a free waiting-slot to come back to after the lap (`slots-full`
  ///     otherwise — a queue-piggy that has nowhere to land after her lap
  ///     will just walk off with unspent ammo, which is a bad trade the
  ///     player never wants).
  /// This is asymmetric on purpose: waiting-slot piggies DO release their own
  /// slot at launch time, so they only need the belt to be free.
  String? queueLaunchBlockReason() {
    if (conveyorLoad >= level.maxConveyorCapacity) return 'belt-busy';
    if (!slots.hasFreeSlot) return 'slots-full';
    return null;
  }

  /// Reason a piggy currently in a WAITING slot cannot be launched. Only the
  /// belt matters — waiting-piggy releases her own slot as she leaves it.
  String? waitingLaunchBlockReason() {
    if (conveyorLoad >= level.maxConveyorCapacity) return 'belt-busy';
    return null;
  }

  /// Legacy name — kept because a few callers still ask "can I launch anyone
  /// at all right now?" and only care about the belt. Prefer the two specific
  /// methods above in new code.
  String? launchBlockReason() => waitingLaunchBlockReason();

  bool tryLaunchPiggy(PiggyComponent p) {
    // Queue-launch — belt free, waiting has room, AND the piggy's colour is
    // still needed (a useless-colour piggy would ride an empty lap and waste
    // her ammo). For useless-colour piggies, players use the direct
    // queue→waiting transfer (see PiggyComponent.onTapDown) — this method is
    // only for going to the belt.
    if (queueLaunchBlockReason() != null) return false;
    if (!p.type.isSpecial && !board.hasBlockOfColor(p.piggyColor)) return false;
    // Space new piggies evenly around the loop so they don't stack on top
    // of already-riding ones. Start = current furthest piggy's distance +
    // (perimeter / capacity) — feels like the belt naturally accepts them.
    final riding = _piggiesOnBelt.toList();
    double startDistance = 0;
    if (riding.isNotEmpty) {
      final farthest = riding
          .map((p) => p.trackDistance)
          .reduce((a, b) => a > b ? a : b);
      startDistance = farthest - conveyor.perimeter / level.maxConveyorCapacity;
      if (startDistance < 0) startDistance += conveyor.perimeter;
    }
    p.startOnConveyor(conveyor, startDistance: startDistance);
    AudioService.launch();
    return true;
  }
}

// ------------------------------------------------------------
// Board / Blocks
// ------------------------------------------------------------

class BoardComponent extends PositionComponent {
  BoardComponent({required this.level, required this.area}) {
    position = Vector2(area.left, area.top);
    size = Vector2(area.width, area.height);
  }

  final LevelConfig level;
  final Rect area;
  late final List<List<BlockComponent?>> cells;
  late final double cellSize;
  late final double gridOffsetX;
  late final double gridOffsetY;

  /// Blocks that still need to be shot (planned-but-not-arrived-yet hits count
  /// as gone). Stone and portal don't count towards winning.
  int get remainingBlocks {
    var n = 0;
    for (final row in cells) {
      for (final c in row) {
        if (c == null || c.spec.isStone || c.spec.isPortal) continue;
        if (!c.isBeingRemoved) n++;
      }
    }
    return n;
  }

  @override
  Future<void> onLoad() async {
    final cols = level.cols;
    final rows = level.rows;

    final gridW = size.x;
    final gridH = size.y;
    cellSize = math.min(gridW / cols, gridH / rows);

    final totalW = cellSize * cols;
    final totalH = cellSize * rows;
    gridOffsetX = (size.x - totalW) / 2;
    gridOffsetY = (size.y - totalH) / 2;

    cells = List.generate(rows, (_) => List.filled(cols, null));

    final game = findGame()! as PixelFlowGame;
    Sprite spriteFor(PiggyColor color) => game.sprite('block_${color.name}.png');

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final spec = level.grid[r][c];
        if (spec == null) continue;
        final block = BlockComponent(
          spec: spec,
          gridRow: r,
          gridCol: c,
          spriteFor: spriteFor,
          position: Vector2(
            gridOffsetX + c * cellSize + cellSize / 2,
            gridOffsetY + r * cellSize + cellSize / 2,
          ),
          size: Vector2.all(cellSize * 0.92),
        );
        cells[r][c] = block;
        add(block);
      }
    }
  }

  Vector2 worldCenterOf(int row, int col) {
    return Vector2(
      position.x + gridOffsetX + col * cellSize + cellSize / 2,
      position.y + gridOffsetY + row * cellSize + cellSize / 2,
    );
  }

  /// Is there at least one living block whose currentColor matches [color]?
  /// Used to grey-out useless piggies and to reject their launches.
  bool hasBlockOfColor(PiggyColor color) {
    for (final row in cells) {
      for (final b in row) {
        if (b == null || b.spec.isStone || b.spec.isPortal || b.isBeingRemoved) continue;
        if (b.currentColor == color) return true;
      }
    }
    return false;
  }

  /// Find the paired portal for [source]. Returns null if the source is not a
  /// portal or if its pair is missing / has been removed.
  BlockComponent? findPortalPair(BlockComponent source) {
    if (!source.spec.isPortal) return null;
    final id = source.spec.portalPairId;
    for (final row in cells) {
      for (final b in row) {
        if (b == null || b == source) continue;
        if (b.spec.isPortal && b.spec.portalPairId == id) return b;
      }
    }
    return null;
  }

  double get worldLeft => position.x + gridOffsetX;
  double get worldRight => position.x + gridOffsetX + cellSize * level.cols;
  double get worldTop => position.y + gridOffsetY;
  double get worldBottom => position.y + gridOffsetY + cellSize * level.rows;

  int? columnAtWorldX(double x) {
    if (x < worldLeft || x > worldRight) return null;
    final c = ((x - worldLeft) / cellSize).floor();
    return c.clamp(0, level.cols - 1);
  }

  int? rowAtWorldY(double y) {
    if (y < worldTop || y > worldBottom) return null;
    final r = ((y - worldTop) / cellSize).floor();
    return r.clamp(0, level.rows - 1);
  }

  BlockComponent? firstBlockInColumnFromTop(int col) => _raycast(0, col, 1, 0).target;
  BlockComponent? firstBlockInColumnFromBottom(int col) => _raycast(level.rows - 1, col, -1, 0).target;
  BlockComponent? firstBlockInRowFromLeft(int row) => _raycast(row, 0, 0, 1).target;
  BlockComponent? firstBlockInRowFromRight(int row) => _raycast(row, level.cols - 1, 0, -1).target;

  /// Same as the four one-liners above, but returns the full teleport chain
  /// so BallComponent can visibly hop through portals rather than teleporting
  /// "off-screen".
  RaycastResult raycastFromColumnTop(int col) => _raycast(0, col, 1, 0);
  RaycastResult raycastFromColumnBottom(int col) => _raycast(level.rows - 1, col, -1, 0);
  RaycastResult raycastFromRowLeft(int row) => _raycast(row, 0, 0, 1);
  RaycastResult raycastFromRowRight(int row) => _raycast(row, level.cols - 1, 0, -1);

  /// Walk cells from (r0,c0) stepping by (dr,dc). Return the first destroyable
  /// block encountered. If the walk hits a portal, jump to its pair and keep
  /// walking in the same direction — record each portal in [portalsTraversed]
  /// so the caller can render the ball hopping through.
  ///
  /// Stops on: stone (nothing hit), out-of-bounds (nothing hit), or a normal
  /// living block (hit). Portal-cycles are broken by [maxPortalHops].
  RaycastResult _raycast(int r0, int c0, int dr, int dc, {int maxPortalHops = 3}) {
    final portals = <BlockComponent>[];
    var r = r0;
    var c = c0;
    var hops = 0;
    while (true) {
      while (r >= 0 && r < level.rows && c >= 0 && c < level.cols) {
        final b = cells[r][c];
        if (b != null && !b.isBeingRemoved) {
          if (b.spec.isPortal) {
            // Teleport: find pair, restart the walk from the pair's cell in
            // the SAME direction. Fail-safes: hop cap, missing pair.
            if (hops >= maxPortalHops) return RaycastResult(null, portals);
            final pair = findPortalPair(b);
            if (pair == null) {
              // Malformed level: portal without pair. Treat as stone.
              return RaycastResult(null, portals);
            }
            portals.add(b);
            portals.add(pair);
            hops++;
            r = pair.gridRow + dr;
            c = pair.gridCol + dc;
            break; // exit inner while, restart outer walk from new (r,c)
          }
          // First real block on the line — hit.
          return RaycastResult(b, portals);
        }
        r += dr;
        c += dc;
      }
      // If we exited by going out of bounds (not by portal teleport), nothing.
      if (r < 0 || r >= level.rows || c < 0 || c >= level.cols) {
        return RaycastResult(null, portals);
      }
    }
  }
}

/// Result of a raycast for shot targeting.
/// - [target]: the first destroyable block on the line (or null if line
///   dead-ends into a wall, portal-cycle, or off-board).
/// - [portalsTraversed]: even-length list of portals the shot passed through
///   as pairs — [enter0, exit0, enter1, exit1, ...]. BallComponent uses this
///   to build a multi-segment flight path.
class RaycastResult {
  const RaycastResult(this.target, this.portalsTraversed);
  final BlockComponent? target;
  final List<BlockComponent> portalsTraversed;
}

/// A block on the board. Supports:
///   normal   — 1 colour, 1 hp
///   armored  — 1 colour, hp > 1 (crack overlay grows per hit)
///   dual     — hp = 2, second colour exposed after first hit
///   stone    — no colour, cannot be shot, blocks the shot line
class BlockComponent extends PositionComponent {
  BlockComponent({
    required this.spec,
    required this.gridRow,
    required this.gridCol,
    required Vector2 position,
    required Vector2 size,
    required this.spriteFor,
  })  : hp = spec.hp,
        maxHp = spec.hp,
        super(position: position, size: size, anchor: Anchor.center);

  final BlockSpec spec;
  final int gridRow;
  final int gridCol;
  final Sprite Function(PiggyColor) spriteFor;

  int hp;
  final int maxHp;

  /// Painter/duplicator/converter may repaint a block after it spawns.
  /// When set, [currentColor] returns this override and the sprite reflects it.
  /// Repainting also resets armor/dual state (hp back to 1, override colour
  /// used everywhere the outer/inner colour was consulted).
  PiggyColor? _paintOverride;

  /// How many balls are already in flight aimed at this block. A block is
  /// off-limits for further shots once [hp] − [_plannedHits] == 0.
  int _plannedHits = 0;

  /// True once [_plannedHits] >= [hp]: the block is effectively dead for
  /// targeting purposes even before the balls arrive. Used by shot logic
  /// and by [BoardComponent.remainingBlocks] / STUCK-detection.
  bool get isBeingRemoved => _plannedHits >= hp;

  bool _animatingOut = false;

  SpriteComponent? _bodySprite;

  /// Colour a piggy needs to shoot this block right now (null for stone).
  /// Accounts for [_plannedHits] — in-flight balls that will land in the
  /// future. Otherwise a Y-piggy shoots into a dual _yg, reserves 1 hit
  /// (hp still = 2 until the ball arrives), sees currentColor == Y again
  /// on the next cooldown and fires a wasted Y-shot into what's already
  /// virtually inner=G. Same story for color-shift YOP.
  PiggyColor? get currentColor =>
      _paintOverride ?? spec.currentColor(math.max(0, hp - _plannedHits));

  /// Painter/duplicator/converter: change this block's colour on the fly.
  /// Skips stone/portal (unchanged) and blocks already popping. Resets
  /// armor/dual so a repainted block always dies in one hit of the new colour.
  void repaintTo(PiggyColor color) {
    if (spec.isStone || spec.isPortal || _animatingOut) return;
    _paintOverride = color;
    hp = 1;
    _plannedHits = 0;
    _bodySprite?.sprite = spriteFor(color);
    _applyDarkening();
    add(SequenceEffect([
      ScaleEffect.to(Vector2.all(1.15), EffectController(duration: 0.08)),
      ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.12)),
    ]));
  }

  @override
  Future<void> onLoad() async {
    if (spec.isStone || spec.isPortal) return; // drawn manually in render()
    _bodySprite = SpriteComponent(
      sprite: spriteFor(spec.color!),
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    _applyDarkening();
    add(_bodySprite!);
  }

  /// Armored blocks look progressively darker so the player sees "this one
  /// costs more shots" without reading the crack overlay.
  ///  hp==1 → normal
  ///  hp==2 → ~15% darker
  ///  hp==3 → ~28% darker
  void _applyDarkening() {
    final s = _bodySprite;
    if (s == null) return;
    final effectiveHp = hp; // current, not max — so it lightens as it's hit
    if (effectiveHp <= 1) {
      s.paint = Paint(); // reset
      return;
    }
    final darken = math.min(0.35, 0.15 * (effectiveHp - 1)); // cap at 35%
    s.paint = Paint()
      ..colorFilter = ColorFilter.mode(
        Colors.black.withValues(alpha: darken),
        BlendMode.srcATop,
      );
  }

  /// A shot is being sent this way — mark it so the next shot picks something
  /// else. Called by the piggy at the moment of firing.
  void reserveHit() {
    _plannedHits++;
  }

  /// Breaker-piggy hit: works only on stone, destroys it in one go.
  void applyStoneBreak() {
    if (!spec.isStone || _animatingOut) return;
    _plannedHits = math.max(0, _plannedHits - 1);
    hp = 0;
    _pop();
  }

  /// Bomb explosion: destroy no matter what (stone, armored, dual).
  /// Portals are the ONE exception — they're structural and outlast explosions.
  /// Used by BallComponent._bombExplosion for each cell in the 3x3.
  void forceDestroy() {
    if (_animatingOut || spec.isPortal) return;
    // Don't leave planned-hits dangling — reset first.
    _plannedHits = 0;
    hp = 0;
    _pop();
  }

  /// A ball arrived. Applies damage; pops if the last hp is gone.
  void applyHit() {
    if (spec.isStone || spec.isPortal || _animatingOut) return;
    _plannedHits = math.max(0, _plannedHits - 1);
    hp--;

    if (hp <= 0) {
      _pop();
      return;
    }

    // Swap sprite to reflect the new current colour after damage.
    //   - Dual (innerColor set): hp = maxHp-1 exposes innerColor.
    //   - Color-shift (colorShiftStates set): every hit shifts to next state.
    //   - Repainted (_paintOverride set): sprite stays as override.
    if (_paintOverride == null) {
      final nextColor = spec.currentColor(hp);
      if (nextColor != null) {
        _bodySprite?.sprite = spriteFor(nextColor);
      }
    }

    // Lighten the tint as damage is taken (armored blocks visibly weaken).
    _applyDarkening();

    // Little squish + repaint (crack overlay grows automatically).
    add(SequenceEffect([
      ScaleEffect.to(Vector2.all(0.88), EffectController(duration: 0.05)),
      ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.10)),
    ]));
  }

  void _pop() {
    if (_animatingOut) return;
    _animatingOut = true;
    AudioService.pop();
    _spawnBurst();
    // Detach from the board grid so remainingBlocks stops counting it.
    final board = parent;
    if (board is BoardComponent) {
      board.cells[gridRow][gridCol] = null;
      final game = board.findGame();
      if (game is PixelFlowGame) game.notePop();
    }
    add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.16, curve: Curves.easeInBack),
        onComplete: removeFromParent,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    if (spec.isStone) {
      _renderStone(canvas);
    } else if (spec.isPortal) {
      _renderPortal(canvas);
    }
    super.render(canvas);
    if (!spec.isStone && !spec.isPortal && hp < maxHp && _paintOverride == null) {
      _renderCracks(canvas);
    }
  }

  static const List<List<Color>> _portalPalettes = [
    // Cyan / white
    [Color(0xFF5AC8FA), Color(0xFFB0F0FF), Color(0xFFFFFFFF)],
    // Magenta / pink
    [Color(0xFFFF6BAA), Color(0xFFFFC1E0), Color(0xFFFFFFFF)],
    // Green / lime
    [Color(0xFF6ECF3A), Color(0xFFC8FFA0), Color(0xFFFFFFFF)],
    // Yellow / orange
    [Color(0xFFFFD338), Color(0xFFFFB84D), Color(0xFFFFFFFF)],
  ];

  void _renderPortal(Canvas canvas) {
    final id = spec.portalPairId.clamp(0, _portalPalettes.length - 1);
    final palette = _portalPalettes[id];
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.x * 0.5));
    // Outer ring — dark base with pair-colour halo.
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * 0.08, size.y * 0.08, size.x * 0.84, size.y * 0.84),
        Radius.circular(size.x * 0.5),
      ),
      Paint()
        ..shader = RadialGradient(
          colors: palette,
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromLTWH(size.x * 0.15, size.y * 0.15, size.x * 0.7, size.y * 0.7)),
    );
    // Pair label — small tag so the player pairs A and B at a glance.
    final label = String.fromCharCode(0x41 + id); // 'A', 'B', 'C', ...
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: size.x * 0.4,
          color: Colors.black.withValues(alpha: 0.75),
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.x - tp.width) / 2, (size.y - tp.height) / 2));
  }

  void _renderStone(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.x * 0.15));
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9AA1B0), Color(0xFF5D6270)],
      ).createShader(rect);
    canvas.drawRRect(rrect, base);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.x * 0.06,
    );
    // Highlight glare
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * 0.12, size.x * 0.12, size.x * 0.35, size.x * 0.22),
        Radius.circular(size.x * 0.08),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    // Etched cross to signal "unbreakable"
    final xPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = size.x * 0.08
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.x * 0.28, size.y * 0.28),
      Offset(size.x * 0.72, size.y * 0.72),
      xPaint,
    );
    canvas.drawLine(
      Offset(size.x * 0.72, size.y * 0.28),
      Offset(size.x * 0.28, size.y * 0.72),
      xPaint,
    );
  }

  void _renderCracks(Canvas canvas) {
    // Deterministic per-block so the crack pattern is stable across frames.
    final rng = math.Random(gridRow * 131 + gridCol * 17 + maxHp);
    final damage = maxHp - hp;
    final lines = 2 + damage * 2;
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, size.x * 0.045)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < lines; i++) {
      final x1 = size.x * (0.15 + rng.nextDouble() * 0.7);
      final y1 = size.y * (0.15 + rng.nextDouble() * 0.7);
      final dx = (rng.nextDouble() - 0.5) * size.x * 0.55;
      final dy = (rng.nextDouble() - 0.5) * size.y * 0.55;
      canvas.drawLine(Offset(x1, y1), Offset(x1 + dx, y1 + dy), paint);
    }
  }

  void _spawnBurst() {
    final game = findGame();
    if (game == null) return;
    final rng = math.Random();
    final worldPos = absoluteCenter;
    // For dual blocks whose inner has been exposed, use the inner colour for
    // debris; otherwise use the current colour.
    final debrisColor = (currentColor ?? spec.color ?? PiggyColor.pink).color;
    final component = ParticleSystemComponent(
      position: worldPos,
      particle: Particle.generate(
        count: 12,
        lifespan: 0.5,
        generator: (i) {
          final angle = rng.nextDouble() * math.pi * 2;
          final speed = 90 + rng.nextDouble() * 90;
          final velocity = Vector2(math.cos(angle) * speed, math.sin(angle) * speed);
          final chipSize = 3.0 + rng.nextDouble() * 3.5;
          return AcceleratedParticle(
            acceleration: Vector2(0, 260),
            speed: velocity,
            child: ComputedParticle(
              renderer: (canvas, particle) {
                final progress = particle.progress;
                final alpha = (1.0 - progress).clamp(0.0, 1.0);
                final paint = Paint()..color = debrisColor.withValues(alpha: alpha);
                final s = chipSize * (1.0 - 0.3 * progress);
                canvas.drawRRect(
                  RRect.fromRectAndRadius(
                    Rect.fromCenter(center: Offset.zero, width: s, height: s),
                    const Radius.circular(1),
                  ),
                  paint,
                );
              },
            ),
          );
        },
      ),
    );
    (game as FlameGame).world.add(component);
  }
}

// ------------------------------------------------------------
// Conveyor
// ------------------------------------------------------------

enum ConveyorSide { left, top, right, bottom }

class ConveyorComponent extends PositionComponent {
  ConveyorComponent({required this.trackRect});

  final Rect trackRect;
  static const double cornerRadius = 28;
  late final double perimeter;

  @override
  Future<void> onLoad() async {
    perimeter = _perimeter();
  }

  double _perimeter() {
    final w = trackRect.width - 2 * cornerRadius;
    final h = trackRect.height - 2 * cornerRadius;
    return 2 * w + 2 * h + 2 * math.pi * cornerRadius;
  }

  // Drawing handled by the frame sprite; no debug draw needed.

  /// Point on track at [distance] (clockwise from bottom-left going UP the left side).
  Vector2 positionAt(double distance) {
    final d = distance % perimeter;
    final w = trackRect.width - 2 * cornerRadius;
    final h = trackRect.height - 2 * cornerRadius;
    final arc = math.pi / 2 * cornerRadius;

    final segments = <double>[h, arc, w, arc, h, arc, w, arc];
    var acc = 0.0;
    for (var i = 0; i < segments.length; i++) {
      if (d < acc + segments[i]) {
        return _pointOnSegment(i, d - acc);
      }
      acc += segments[i];
    }
    return _pointOnSegment(0, 0);
  }

  Vector2 _pointOnSegment(int seg, double local) {
    final r = cornerRadius;
    switch (seg) {
      case 0:
        return Vector2(trackRect.left, trackRect.bottom - r - local);
      case 1:
        {
          final t = local / r;
          final cx = trackRect.left + r;
          final cy = trackRect.top + r;
          final a = math.pi + t;
          return Vector2(cx + r * math.cos(a), cy + r * math.sin(a));
        }
      case 2:
        return Vector2(trackRect.left + r + local, trackRect.top);
      case 3:
        {
          final t = local / r;
          final cx = trackRect.right - r;
          final cy = trackRect.top + r;
          final a = -math.pi / 2 + t;
          return Vector2(cx + r * math.cos(a), cy + r * math.sin(a));
        }
      case 4:
        return Vector2(trackRect.right, trackRect.top + r + local);
      case 5:
        {
          final t = local / r;
          final cx = trackRect.right - r;
          final cy = trackRect.bottom - r;
          final a = t;
          return Vector2(cx + r * math.cos(a), cy + r * math.sin(a));
        }
      case 6:
        return Vector2(trackRect.right - r - local, trackRect.bottom);
      case 7:
        {
          final t = local / r;
          final cx = trackRect.left + r;
          final cy = trackRect.bottom - r;
          final a = math.pi / 2 + t;
          return Vector2(cx + r * math.cos(a), cy + r * math.sin(a));
        }
    }
    return Vector2.zero();
  }

  /// Which side is the piggy currently on (based on its world position).
  ConveyorSide sideAt(Vector2 pos) {
    final r = cornerRadius;
    // Prioritise straight segments; corners fold to the nearest side.
    final onLeft = pos.x <= trackRect.left + r + 1;
    final onRight = pos.x >= trackRect.right - r - 1;
    final onTop = pos.y <= trackRect.top + r + 1;
    final onBottom = pos.y >= trackRect.bottom - r - 1;

    // Choose the dominant one based on distance to that edge
    final dLeft = (pos.x - trackRect.left).abs();
    final dRight = (trackRect.right - pos.x).abs();
    final dTop = (pos.y - trackRect.top).abs();
    final dBottom = (trackRect.bottom - pos.y).abs();

    var side = ConveyorSide.left;
    var best = dLeft;
    if (dRight < best) { best = dRight; side = ConveyorSide.right; }
    if (dTop < best) { best = dTop; side = ConveyorSide.top; }
    if (dBottom < best) { best = dBottom; side = ConveyorSide.bottom; }

    // Suppress unused-var warnings for readability booleans
    _ignore(onLeft); _ignore(onRight); _ignore(onTop); _ignore(onBottom);
    return side;
  }

  void _ignore(Object _) {}
}

// ------------------------------------------------------------
// Piggy
// ------------------------------------------------------------

enum PiggyState { inQueue, inSlot, onConveyor, shooting, leaving }

class PiggyComponent extends PositionComponent with TapCallbacks {
  PiggyComponent({
    required this.piggyColor,
    required this.ammo,
    required Vector2 position,
    this.type = PiggyType.normal,
  }) : super(position: position, anchor: Anchor.center, size: Vector2.all(46));

  final PiggyColor piggyColor;
  final PiggyType type;
  int ammo;
  PiggyState state = PiggyState.inQueue;
  ConveyorComponent? _conveyor;
  double _trackDistance = 0;
  double _startDistance = 0;
  double _shotCooldown = 0.15;
  double _shootAnimationTimer = 0;
  double _idleTime = 0; // for the "ready to launch" pulse

  double get trackDistance => _trackDistance;
  double get _speed =>
      game.level.piggySpeed * game.beltSpeedMultiplier * game.dynamicSpeedFactor;

  late final SpriteComponent _bodyNormal;
  late final SpriteComponent _bodyShoot;
  late final TextComponent _ammoLabel;

  PixelFlowGame get game => findGame()! as PixelFlowGame;

  @override
  Future<void> onLoad() async {
    // Special piggies have their own artwork — use it as both the idle and
    // shoot sprite (no separate "mouth-open" variant available).
    final normalSprite = type.spriteAsset != null
        ? game.sprite(type.spriteAsset!)
        : game.sprite('piggy_${piggyColor.name}.png');
    final shootSprite = type.spriteAsset != null
        ? game.sprite(type.spriteAsset!)
        : game.sprite('piggy_${piggyColor.name}_shoot.png');

    _bodyNormal = SpriteComponent(
      sprite: normalSprite,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    _bodyShoot = SpriteComponent(
      sprite: shootSprite,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    _bodyShoot.opacity = 0;
    add(_bodyNormal);
    add(_bodyShoot);

    _ammoLabel = TextComponent(
      text: '$ammo',
      anchor: Anchor.center,
      position: Vector2(size.x / 2, -8),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          shadows: [
            Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 2),
            Shadow(color: Colors.black, offset: Offset(-1, -1), blurRadius: 2),
          ],
        ),
      ),
    );
    add(_ammoLabel);

    // Active skin overlay — applies to normal piggies only. Specials keep
    // their unique art untouched. Skipped when hasArt=false (art pending).
    final skin = game.activeSkin;
    if (type == PiggyType.normal && skin != SkinId.none && skin.hasArt) {
      add(SpriteComponent(
        sprite: game.sprite('skin_${skin.id}.png'),
        size: size,
        anchor: Anchor.center,
        position: size / 2,
        priority: 1, // above the body sprites
      ));
    }
  }

  void _updateAmmoLabel() => _ammoLabel.text = '$ammo';

  void startOnConveyor(ConveyorComponent conveyor, {double startDistance = 0}) {
    _conveyor = conveyor;
    _trackDistance = startDistance;
    _startDistance = startDistance;
    _shotCooldown = 0.15;
    // Reset any queue-idle scale.
    scale.setValues(1.0, 1.0);
    _idleTime = 0;

    // Enter through the exit pipe (bottom-left corner): appear slightly
    // outside the track and hop up onto the belt over ~0.28s.
    final onTrack = conveyor.positionAt(startDistance);
    final pipeStart = Vector2(onTrack.x - 6, onTrack.y + 60);
    position.setFrom(pipeStart);

    // While the little hop plays, keep the piggy in a "not-yet-riding" state
    // so update() doesn't push it along the belt from the pipe origin.
    state = PiggyState.inSlot;
    add(SequenceEffect(
      [
        MoveToEffect(onTrack, EffectController(duration: 0.28, curve: Curves.easeOut)),
      ],
      onComplete: () {
        if (isMounted) state = PiggyState.onConveyor;
      },
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_shootAnimationTimer > 0) {
      _shootAnimationTimer -= dt;
      if (_shootAnimationTimer <= 0) {
        _bodyNormal.opacity = 1;
        _bodyShoot.opacity = 0;
      }
    }

    switch (state) {
      case PiggyState.onConveyor:
      case PiggyState.shooting:
        _updateOnConveyor(dt);
        break;
      case PiggyState.leaving:
        position.y += 220 * dt;
        opacity = (opacity - dt * 3).clamp(0.0, 1.0);
        if (opacity <= 0 || position.y > PixelFlowGame.worldHeight + 80) {
          removeFromParent();
        }
        break;
      case PiggyState.inQueue:
      case PiggyState.inSlot:
        // Both queue AND waiting-slot piggies dim when belt is busy — they're
        // both "clickable to launch" pools and both share the same block.
        _updateIdlePulse(dt);
        break;
    }
  }

  /// Pulse only when the conveyor is free AND our colour is still needed —
  /// signals "you can launch me now". Otherwise sit still and heavily dim so
  /// the player sees at a glance why a tap won't do anything:
  ///   - opacity 0.28 → useless (colour gone from board)
  ///   - opacity 0.28 → belt busy (wait for the current piggy to finish)
  ///   - opacity 1.0  → clickable; also gentle pulse if in queue
  ///
  /// Called for both PiggyState.inQueue and PiggyState.inSlot — waiting-slot
  /// piggies dim too. Pulse is only shown for queue (inSlot has no "come at me"
  /// signal since it already lives at fixed spots).
  void _updateIdlePulse(double dt) {
    // Different launch rules for queue vs. waiting-slot.
    final blocked = state == PiggyState.inQueue
        ? game.queueLaunchBlockReason() != null
        : game.waitingLaunchBlockReason() != null;
    // "Useful" == can actually pop a block right now. Specials always can.
    final useful = type.isSpecial || game.board.hasBlockOfColor(piggyColor);

    if (blocked) {
      // Hard block (belt busy / no waiting room) → strong dim, tap only wiggles.
      _setIdleOpacity(0.28, ammoAlpha: 0.45);
      if (scale.x != 1.0) scale.setValues(1.0, 1.0);
      _idleTime = 0;
      return;
    }
    if (!useful) {
      // Soft dim — the colour is gone from board, but the player CAN launch
      // her anyway to free the queue slot for a fresh spawn.
      _setIdleOpacity(0.55, ammoAlpha: 0.7);
      if (scale.x != 1.0) scale.setValues(1.0, 1.0);
      _idleTime = 0;
      return;
    }
    // Fully clickable + useful.
    if (_bodyNormal.opacity < 1.0) {
      _bodyNormal.opacity = 1.0;
      _updateAmmoLabel();
    }
    // Only inQueue gets the "ready" pulse — inSlot piggies sit at fixed
    // waiting positions so there's nothing to signal.
    if (state == PiggyState.inQueue) {
      _idleTime += dt;
      final s = 1.0 + 0.05 * math.sin(_idleTime * 6.5);
      scale.setValues(s, s);
    } else if (scale.x != 1.0) {
      scale.setValues(1.0, 1.0);
    }
  }

  void _setIdleOpacity(double bodyAlpha, {required double ammoAlpha}) {
    _bodyNormal.opacity = bodyAlpha;
    _ammoLabel.textRenderer = TextPaint(
      style: TextStyle(
        color: Colors.white.withValues(alpha: ammoAlpha),
        fontSize: 16,
        fontWeight: FontWeight.w800,
        shadows: const [Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 2)],
      ),
    );
  }

  double get opacity => _bodyNormal.opacity;
  set opacity(double v) {
    _bodyNormal.opacity = v;
    _bodyShoot.opacity = 0;
    _ammoLabel.textRenderer = TextPaint(
      style: TextStyle(
        color: Colors.white.withValues(alpha: v),
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  void _updateOnConveyor(double dt) {
    if (_conveyor == null) return;
    _trackDistance += _speed * dt;
    position.setFrom(_conveyor!.positionAt(_trackDistance));

    _shotCooldown -= dt;
    if (_shotCooldown <= 0 && ammo > 0) {
      _tryShoot();
    }

    if (ammo <= 0) {
      state = PiggyState.leaving;
      return;
    }

    // Completed a full loop?
    if (_trackDistance - _startDistance >= _conveyor!.perimeter) {
      // If there are still targets somewhere and we have ammo, go to slot to wait.
      if (game.board.remainingBlocks == 0) {
        state = PiggyState.leaving;
        return;
      }
      _goToSlot();
    }
  }

  /// Cell-period for cooldown pacing. Excludes freeze (so slowdown doesn't
  /// stop firing) but INCLUDES the level ramp so cooldown shrinks alongside
  /// the accelerating belt — otherwise the piggy would skip cells at 1.5x.
  double get _baseSpeed => game.level.piggySpeed * game.dynamicSpeedFactor;

  void _tryShoot() {
    final board = game.board;
    final side = _conveyor!.sideAt(position);
    final result = _firstBlockOnLine(board, side);

    // Cooldown is tuned so the piggy gets AT LEAST one shot attempt per grid
    // cell it flies over — otherwise fast levels (speed=500) would skip
    // blocks entirely between fires.
    final cellPeriod = board.cellSize / _baseSpeed;

    if (result.target == null) {
      _shotCooldown = cellPeriod * 0.35; // retry fast, we're mid-air over nothing
      return;
    }

    if (!_canShoot(result.target!)) {
      _shotCooldown = cellPeriod * 0.35;
      return;
    }

    _fireBallAt(result.target!, portals: result.portalsTraversed);
    game.shotsFired++;
    ammo--;
    _updateAmmoLabel();
    // 85% of a cell-period so we never miss the next cell but leave a small
    // recovery gap for the muzzle animation.
    _shotCooldown = cellPeriod * 0.85;
    _triggerShootAnimation();
    AudioService.shoot();
  }

  RaycastResult _firstBlockOnLine(BoardComponent board, ConveyorSide side) {
    switch (side) {
      case ConveyorSide.top:
        final col = board.columnAtWorldX(position.x);
        return col == null ? const RaycastResult(null, []) : board.raycastFromColumnTop(col);
      case ConveyorSide.bottom:
        final col = board.columnAtWorldX(position.x);
        return col == null ? const RaycastResult(null, []) : board.raycastFromColumnBottom(col);
      case ConveyorSide.left:
        final row = board.rowAtWorldY(position.y);
        return row == null ? const RaycastResult(null, []) : board.raycastFromRowLeft(row);
      case ConveyorSide.right:
        final row = board.rowAtWorldY(position.y);
        return row == null ? const RaycastResult(null, []) : board.raycastFromRowRight(row);
    }
  }

  bool _canShoot(BlockComponent target) {
    switch (type) {
      case PiggyType.bomb:
        // Bombs treat the first block as ignition. Stone can be ignited too
        // (bomb blows it up).
        return true;
      case PiggyType.rainbow:
        // Rainbow ignores colour — any coloured block on the line.
        return !target.spec.isStone;
      case PiggyType.filter:
      case PiggyType.breaker: // legacy alias
        // Filter/breaker only works on stone.
        return target.spec.isStone;
      case PiggyType.painter:
      case PiggyType.converter:
      case PiggyType.freeze:
      case PiggyType.chaos:
      case PiggyType.jackpot:
      case PiggyType.portal:
        // Field-manipulators: any non-stone target ignites them.
        return !target.spec.isStone;
      case PiggyType.duplicator:
      case PiggyType.universal:
      case PiggyType.chain:
      case PiggyType.sweeper:
        // Need a coloured target to know what to spread / clear.
        return !target.spec.isStone && target.currentColor != null;
      case PiggyType.normal:
        final wanted = target.currentColor;
        if (wanted == null) return false;
        if (wanted == piggyColor) return true;
        // Universal-piggy effect: any normal piggy can also pop [universalColor].
        return game.universalColor != null && wanted == game.universalColor;
    }
  }

  void _triggerShootAnimation() {
    _bodyNormal.opacity = 0;
    _bodyShoot.opacity = 1;
    _shootAnimationTimer = 0.12;
  }

  void _fireBallAt(BlockComponent target, {List<BlockComponent> portals = const []}) {
    // Reserve one hp slot on the target so the very next shot sees "one less
    // hp available" and either takes the next slot (armored) or moves on.
    // Bomb/breaker reserve too so the same block isn't shot again mid-flight.
    target.reserveHit();

    // Ball colour: rainbow paints the ball with the target's colour so the
    // trail matches what actually gets destroyed. Everything else uses the
    // piggy's own colour.
    final PiggyColor ballColor = type == PiggyType.rainbow
        ? (target.currentColor ?? piggyColor)
        : piggyColor;

    final ball = BallComponent(
      startPos: position.clone(),
      target: target,
      piggyColor: ballColor,
      sprite: game.sprite('ball_${ballColor.name}.png'),
      shooterType: type,
      portalsTraversed: portals,
    );
    game.world.add(ball);
  }

  void _goToSlot() {
    final slot = game.slots.findFreeSlot();
    if (slot == null) {
      state = PiggyState.leaving;
      return;
    }
    slot.piggy = this;
    state = PiggyState.inSlot;
    _conveyor = null;
    add(MoveToEffect(slot.worldCenter, EffectController(duration: 0.4, curve: Curves.easeOut)));
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (state == PiggyState.inQueue) {
      // Path A: useful colour (or special) → launch to belt.
      if (game.tryLaunchPiggy(this)) {
        AudioService.click();
        game.recordLaunch(this);
        game.piggyQueue.removePiggy(this);
        return;
      }
      // Path B: useless colour but waiting has room → park her directly there.
      // Frees the queue slot for a fresh spawn without wasting a belt lap.
      // Still counts as a launch (piggy exited the arsenal — dead-color
      // transfers are supposed to hurt the L3 rank).
      final iCouldBeUseful = type.isSpecial || game.board.hasBlockOfColor(piggyColor);
      if (!iCouldBeUseful && game.slots.hasFreeSlot &&
          game.queueLaunchBlockReason() != 'slots-full') {
        _parkInWaitingSlot();
        return;
      }
      _bumpDenied();
    } else if (state == PiggyState.inSlot) {
      if (game.waitingLaunchBlockReason() != null) {
        _bumpDenied();
        return;
      }
      AudioService.click();
      game.slots.release(this);
      startOnConveyor(game.conveyor);
    }
  }

  /// Move directly from the bottom queue to a free waiting-slot, no belt lap.
  /// The queue slot opens for a fresh spawn on the next tick.
  /// Guards against tap-spam causing overlapping MoveToEffects — the second
  /// tap would capture the transitioning position and leave the piggy stranded
  /// between queue and waiting.
  bool _transferring = false;
  void _parkInWaitingSlot() {
    if (_transferring) return;
    final slot = game.slots.findFreeSlot();
    if (slot == null) {
      _bumpDenied();
      return;
    }
    _transferring = true;
    AudioService.click();
    game.recordLaunch(this);
    game.piggyQueue.removePiggy(this);
    slot.piggy = this;
    state = PiggyState.inSlot;
    // Snap position so the transition starts from the queue slot, not from a
    // half-way point of a previous animation.
    add(MoveToEffect(
      slot.worldCenter,
      EffectController(duration: 0.35, curve: Curves.easeOut),
      onComplete: () {
        _transferring = false;
        // Snap-lock final position so any lingering effect can't drift it.
        position.setFrom(slot.worldCenter);
      },
    ));
  }

  /// "Nope" wiggle when the tap can't do anything. No click sound — click is
  /// reserved for successful launch so it doesn't feel like the action
  /// registered when it didn't.
  ///
  /// Reset [angle] to 0 as start and end, and gate on [_bumping] — otherwise
  /// spamming taps mid-wiggle captures the intermediate rotation as the new
  /// base and the piggy drifts.
  bool _bumping = false;
  void _bumpDenied() {
    if (_bumping) return;
    _bumping = true;
    angle = 0; // snap-reset in case a prior effect was still in flight
    add(
      SequenceEffect(
        [
          RotateEffect.to(-0.25, EffectController(duration: 0.05)),
          RotateEffect.to(0.25, EffectController(duration: 0.07)),
          RotateEffect.to(-0.15, EffectController(duration: 0.06)),
          RotateEffect.to(0.0, EffectController(duration: 0.06)),
        ],
        onComplete: () {
          _bumping = false;
          angle = 0;
        },
      ),
    );
  }
}

// ------------------------------------------------------------
// Ball
// ------------------------------------------------------------

class BallComponent extends SpriteComponent {
  BallComponent({
    required Vector2 startPos,
    required this.target,
    required this.piggyColor,
    required Sprite sprite,
    this.shooterType = PiggyType.normal,
    List<BlockComponent> portalsTraversed = const [],
  }) : _portalsAtSpawn = portalsTraversed,
       super(
          sprite: sprite,
          position: startPos,
          anchor: Anchor.center,
          size: Vector2.all(14),
        );

  final BlockComponent target;
  final PiggyColor piggyColor;
  final PiggyType shooterType;
  /// Even-length list [enter0, exit0, enter1, exit1, ...] captured at fire
  /// time so we can pin visual waypoints even if a portal disappears mid-flight.
  final List<BlockComponent> _portalsAtSpawn;
  double _t = 0;
  static const double _perSegmentTime = 0.14;
  late final Vector2 _startPos = position.clone();
  bool _hit = false;
  double _trailTimer = 0;

  /// Precomputed flight path: startPos, portal-exit1, portal-exit2, ..., target.
  /// Between each consecutive pair the ball lerps for [_perSegmentTime] seconds,
  /// flashing at the portal exits.
  late final List<Vector2> _waypoints = _buildWaypoints();

  List<Vector2> _buildWaypoints() {
    final points = <Vector2>[_startPos.clone()];
    // Each portal pair adds a waypoint AT the enter portal (ball vanishes) then
    // teleports to the exit portal (ball reappears). We collapse this to two
    // waypoints so segment timing is uniform.
    for (var i = 0; i + 1 < _portalsAtSpawn.length; i += 2) {
      final enter = _portalsAtSpawn[i];
      final exit = _portalsAtSpawn[i + 1];
      points.add(enter.absoluteCenter);
      points.add(exit.absoluteCenter);
    }
    // Target position resolved lazily in update so armored-crack shakes track.
    points.add(target.absoluteCenter);
    return points;
  }

  int get _segmentCount => _waypoints.length - 1;

  @override
  void update(double dt) {
    super.update(dt);
    if (_hit) return;
    _t += dt;
    if (!target.isMounted) {
      removeFromParent();
      return;
    }
    // Advance across segments.
    final totalTime = _perSegmentTime * _segmentCount;
    final k = (_t / totalTime).clamp(0.0, 1.0);
    final scaled = k * _segmentCount;
    final segIdx = math.min(_segmentCount - 1, scaled.floor());
    final segT = scaled - segIdx;
    final start = _waypoints[segIdx];
    final end = segIdx == _segmentCount - 1
        ? target.absoluteCenter // keep tracking target on final leg
        : _waypoints[segIdx + 1];
    position
      ..setFrom(start)
      ..lerp(end, segT);

    _trailTimer -= dt;
    if (_trailTimer <= 0) {
      _trailTimer = 0.015; // one wisp every 15ms
      _spawnTrailWisp();
    }

    // When a segment ends mid-flight (not the final one), flash the portal.
    if (segIdx < _segmentCount - 1 && segT >= 0.98 && !_portalFlashedFor.contains(segIdx)) {
      _portalFlashedFor.add(segIdx);
      _spawnPortalBurst(end);
    }

    if (k >= 1) {
      _hit = true;
      _onImpact();
      removeFromParent();
    }
  }

  final Set<int> _portalFlashedFor = <int>{};

  /// Small ring of coloured chips at the portal-exit for the "pop" of appearance.
  void _spawnPortalBurst(Vector2 worldPos) {
    final game = findGame();
    if (game is! FlameGame) return;
    final tint = piggyColor.color;
    game.world.add(
      ParticleSystemComponent(
        position: worldPos.clone(),
        particle: Particle.generate(
          count: 8,
          lifespan: 0.35,
          generator: (i) {
            final angle = (i / 8) * math.pi * 2;
            const speed = 110.0;
            return AcceleratedParticle(
              speed: Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
              acceleration: Vector2.zero(),
              child: ComputedParticle(
                renderer: (canvas, p) {
                  final a = (1.0 - p.progress).clamp(0.0, 1.0);
                  canvas.drawCircle(
                    Offset.zero,
                    2.5 * (1.0 - p.progress * 0.6),
                    Paint()..color = tint.withValues(alpha: a),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _onImpact() {
    // Achievement tracking: mark this special as "used", unlock per-type
    // achievements + the "collect them all" cheevo when the set is full.
    if (shooterType.isSpecial) {
      AchievementManager.markSpecialUsed(shooterType.name).then((allUsed) {
        if (allUsed) AchievementManager.unlock(Achievement.useAllSpecials);
      });
      switch (shooterType) {
        case PiggyType.bomb:
          AchievementManager.unlock(Achievement.useBomb);
          break;
        case PiggyType.rainbow:
          AchievementManager.unlock(Achievement.useRainbow);
          break;
        case PiggyType.portal:
          AchievementManager.unlock(Achievement.usePortal);
          break;
        default:
          break;
      }
    }
    switch (shooterType) {
      case PiggyType.bomb:
        _bombExplosion();
        break;
      case PiggyType.filter:
      case PiggyType.breaker:
        target.applyStoneBreak();
        break;
      case PiggyType.painter:
        _painterRepaint(area: 1, color: piggyColor);
        break;
      case PiggyType.converter:
        _converterShuffle();
        break;
      case PiggyType.chain:
        _chainReaction();
        break;
      case PiggyType.duplicator:
        _duplicatorSpread();
        break;
      case PiggyType.freeze:
        _freezeBelt();
        break;
      case PiggyType.sweeper:
        _sweeperClear();
        break;
      case PiggyType.chaos:
        _chaosShuffle();
        break;
      case PiggyType.jackpot:
        _jackpotRoll();
        break;
      case PiggyType.universal:
        _universalMark();
        break;
      case PiggyType.portal:
        _portalTeleport();
        break;
      case PiggyType.normal:
      case PiggyType.rainbow:
        target.applyHit();
        break;
    }
  }

  /// Portal-piggy: on impact, open a brief portal flash at the target cell,
  /// pick a random alive coloured block anywhere on the board (preferring the
  /// piggy's own colour), teleport a fresh damage-shot to it. If the picked
  /// block matches the piggy's colour it dies; otherwise the shot is wasted
  /// but the ripple/particle FX still triggers.
  void _portalTeleport() {
    final board = _board;
    if (board == null) {
      target.applyHit();
      return;
    }
    // Portal flash at the entry (target) cell.
    _spawnPortalBurst(target.absoluteCenter);

    // Collect candidates: alive, non-stone, non-portal, not the target itself.
    final ownColor = <BlockComponent>[];
    final anyColor = <BlockComponent>[];
    for (final row in board.cells) {
      for (final b in row) {
        if (b == null || identical(b, target)) continue;
        if (b.spec.isStone || b.spec.isPortal || b.isBeingRemoved) continue;
        anyColor.add(b);
        if (b.currentColor == piggyColor) ownColor.add(b);
      }
    }
    final pool = ownColor.isNotEmpty ? ownColor : anyColor;
    if (pool.isEmpty) {
      target.applyHit();
      return;
    }
    final dest = pool[math.Random().nextInt(pool.length)];
    _spawnPortalBurst(dest.absoluteCenter);
    if (dest.currentColor == piggyColor) {
      dest.reserveHit();
      dest.applyHit();
    }
  }

  /// Pop a 3x3 area centred on [target]. Everything (stone, armored) dies.
  void _bombExplosion() {
    final board = target.parent;
    if (board is! BoardComponent) return;
    final gr = target.gridRow;
    final gc = target.gridCol;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final r = gr + dr;
        final c = gc + dc;
        if (r < 0 || r >= board.cells.length) continue;
        if (c < 0 || c >= board.cells[r].length) continue;
        final b = board.cells[r][c];
        if (b == null) continue;
        b.forceDestroy();
      }
    }
  }

  BoardComponent? get _board {
    final b = target.parent;
    return b is BoardComponent ? b : null;
  }

  PixelFlowGame? get _game {
    final g = target.findGame();
    return g is PixelFlowGame ? g : null;
  }

  /// Painter: repaint every non-stone block in a (2*area+1) square around
  /// [target] to [color]. Target itself included.
  void _painterRepaint({required int area, required PiggyColor color}) {
    final board = _board;
    if (board == null) return;
    final gr = target.gridRow;
    final gc = target.gridCol;
    for (var dr = -area; dr <= area; dr++) {
      for (var dc = -area; dc <= area; dc++) {
        final r = gr + dr;
        final c = gc + dc;
        if (r < 0 || r >= board.cells.length) continue;
        if (c < 0 || c >= board.cells[r].length) continue;
        board.cells[r][c]?.repaintTo(color);
      }
    }
  }

  /// Converter: pick 2-3 random colours from those alive on the board
  /// (fallback to piggy palette) and repaint every non-stone block to a
  /// random one from that set.
  void _converterShuffle() {
    final board = _board;
    if (board == null) return;
    final rng = math.Random();
    final present = <PiggyColor>{};
    for (final row in board.cells) {
      for (final b in row) {
        if (b == null || b.spec.isStone) continue;
        final c = b.currentColor;
        if (c != null) present.add(c);
      }
    }
    var pool = present.toList();
    if (pool.length < 2) pool = List<PiggyColor>.from(PiggyColor.values);
    pool.shuffle(rng);
    final take = pool.length < 3 ? pool.length : (2 + rng.nextInt(2));
    final chosen = pool.take(take).toList();
    for (final row in board.cells) {
      for (final b in row) {
        if (b == null || b.spec.isStone) continue;
        b.repaintTo(chosen[rng.nextInt(chosen.length)]);
      }
    }
  }

  /// Chain: destroy [target] and BFS along 4-connected neighbours of the
  /// same colour, staggered so the pops cascade visibly.
  void _chainReaction() {
    final board = _board;
    if (board == null) return;
    final chainColor = target.currentColor;
    if (chainColor == null) {
      target.applyHit();
      return;
    }
    final visited = <String>{};
    final queue = <(int, int, int)>[(target.gridRow, target.gridCol, 0)];
    visited.add('${target.gridRow}_${target.gridCol}');
    while (queue.isNotEmpty) {
      final (r, c, step) = queue.removeAt(0);
      final b = board.cells[r][c];
      if (b == null || b.spec.isStone) continue;
      if (b.currentColor != chainColor) continue;
      Future.delayed(Duration(milliseconds: 60 * step), () {
        if (b.isMounted) b.forceDestroy();
      });
      const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
      for (final (dr, dc) in dirs) {
        final nr = r + dr;
        final nc = c + dc;
        if (nr < 0 || nr >= board.cells.length) continue;
        if (nc < 0 || nc >= board.cells[nr].length) continue;
        final k = '${nr}_$nc';
        if (visited.contains(k)) continue;
        visited.add(k);
        queue.add((nr, nc, step + 1));
      }
    }
  }

  /// Duplicator: copy [target]'s colour into its 4 orthogonal neighbours,
  /// then normally hit the target.
  void _duplicatorSpread() {
    final board = _board;
    if (board == null) return;
    final color = target.currentColor;
    if (color == null) {
      target.applyHit();
      return;
    }
    const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    final gr = target.gridRow;
    final gc = target.gridCol;
    for (final (dr, dc) in dirs) {
      final r = gr + dr;
      final c = gc + dc;
      if (r < 0 || r >= board.cells.length) continue;
      if (c < 0 || c >= board.cells[r].length) continue;
      board.cells[r][c]?.repaintTo(color);
    }
    target.applyHit();
  }

  /// Freeze: slow belt for 3 seconds so the player can plan.
  void _freezeBelt() {
    _game?.applyFreeze(3.0);
    target.applyHit();
  }

  /// Sweeper: clear the whole row or column of [target] (row if the shot
  /// came in from the left/right, column if from top/bottom). Stone stays.
  void _sweeperClear() {
    final board = _board;
    if (board == null) return;
    final dx = (target.absoluteCenter - _startPos).x.abs();
    final dy = (target.absoluteCenter - _startPos).y.abs();
    final horizontalShot = dx >= dy;
    if (horizontalShot) {
      final r = target.gridRow;
      for (var c = 0; c < board.cells[r].length; c++) {
        final b = board.cells[r][c];
        if (b == null || b.spec.isStone) continue;
        Future.delayed(Duration(milliseconds: 40 * c), () {
          if (b.isMounted) b.forceDestroy();
        });
      }
    } else {
      final c = target.gridCol;
      for (var r = 0; r < board.cells.length; r++) {
        final b = board.cells[r][c];
        if (b == null || b.spec.isStone) continue;
        Future.delayed(Duration(milliseconds: 40 * r), () {
          if (b.isMounted) b.forceDestroy();
        });
      }
    }
  }

  /// Chaos: shuffle the colours of all living non-stone blocks in place.
  /// Positions stay, colours are permuted. Armor/dual resets to 1hp.
  void _chaosShuffle() {
    final board = _board;
    if (board == null) return;
    final rng = math.Random();
    final blocks = <BlockComponent>[];
    final colors = <PiggyColor>[];
    for (final row in board.cells) {
      for (final b in row) {
        if (b == null || b.spec.isStone) continue;
        final c = b.currentColor;
        if (c == null) continue;
        blocks.add(b);
        colors.add(c);
      }
    }
    colors.shuffle(rng);
    for (var i = 0; i < blocks.length; i++) {
      blocks[i].repaintTo(colors[i]);
    }
  }

  /// Jackpot: 50% clear the whole board (stone excluded), 50% just pop target.
  void _jackpotRoll() {
    final board = _board;
    if (board == null) return;
    final lucky = math.Random().nextBool();
    if (!lucky) {
      target.applyHit();
      return;
    }
    var step = 0;
    for (final row in board.cells) {
      for (final b in row) {
        if (b == null || b.spec.isStone) continue;
        final s = step++;
        Future.delayed(Duration(milliseconds: 25 * s), () {
          if (b.isMounted) b.forceDestroy();
        });
      }
    }
  }

  /// Universal: mark [target]'s colour as universal for 4 seconds so any
  /// normal piggy can pop blocks of that colour. Also hit the target itself.
  void _universalMark() {
    final color = target.currentColor;
    if (color != null) {
      _game?.applyUniversal(color, 4.0);
    }
    target.applyHit();
  }

  void _spawnTrailWisp() {
    final game = findGame();
    if (game is! FlameGame) return;
    final baseColor = piggyColor.color;
    game.world.add(
      ParticleSystemComponent(
        position: position.clone(),
        particle: ComputedParticle(
          lifespan: 0.28,
          renderer: (canvas, p) {
            final alpha = (1.0 - p.progress) * 0.6;
            final r = 4.0 * (1.0 - p.progress * 0.7);
            canvas.drawCircle(
              Offset.zero,
              r,
              Paint()..color = baseColor.withValues(alpha: alpha),
            );
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Queue
// ------------------------------------------------------------

/// Auto-spawner + queue: spawns random piggies at fixed slots along the bottom.
/// Piggies stay in slot until the player taps them (and the conveyor is free).
class QueueComponent extends PositionComponent {
  QueueComponent({
    required this.area,
    required this.game,
    required this.slotCount,
    required this.spawnInterval,
    required this.palette,
    required this.ammoMin,
    required this.ammoMax,
    this.arsenal,
  }) {
    position = Vector2(area.left, area.top);
    size = Vector2(area.width, area.height);
  }

  final Rect area;
  final PixelFlowGame game;
  final int slotCount;
  final double spawnInterval;
  final List<PiggyColor> palette;
  final int ammoMin;
  final int ammoMax;

  /// Non-null → puzzle mode. Spawner pulls piggies from this pre-loaded
  /// FIFO pool in bundle-declaration order. When the pool empties, the
  /// spawner stops (no more piggies will appear).
  final List<PiggyBundle>? arsenal;

  late final List<PiggyComponent?> _slots;
  late final List<_ArsenalPick> _pool;
  double _spawnTimer = 0;
  // Microsecond seed: every restart of the same level rolls a different
  // colour sequence, so retries don't feel like the same puzzle twice.
  final math.Random _rng =
      math.Random(DateTime.now().microsecondsSinceEpoch);
  PiggyColor? _lastColor;
  int _sameColorStreak = 0;

  bool get isPuzzleMode => arsenal != null;

  /// Puzzle-only: true when the FIFO pool is fully drained. Used by the game
  /// end-of-level detector to decide when to fire the result overlay.
  bool get isArsenalExhausted => isPuzzleMode && _pool.isEmpty;

  @override
  Future<void> onLoad() async {
    _slots = List.filled(slotCount, null);
    _pool = <_ArsenalPick>[];
    if (arsenal != null) {
      for (final b in arsenal!) {
        for (var i = 0; i < b.count; i++) {
          _pool.add(_ArsenalPick(color: b.color, ammo: b.ammo, type: b.type));
        }
      }
    }
    // Prefill so the player has a piggy to tap immediately.
    _spawnInto(0, animated: false);
  }

  @override
  void render(Canvas canvas) {
    final slotW = size.x / slotCount;
    // Queue turns red when EITHER belt is busy OR waiting-slots are full.
    // Either way tapping a queue-piggy does nothing right now.
    final busy = game.queueLaunchBlockReason() != null;
    final paint = Paint()
      ..color = busy
          ? const Color(0xFF4A1E1E).withValues(alpha: 0.6)
          : Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = busy
          ? const Color(0xFFE64A4A).withValues(alpha: 0.55)
          : Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = busy ? 2.5 : 1.5;
    for (var i = 0; i < slotCount; i++) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * slotW + 4, 4, slotW - 8, size.y - 8),
        const Radius.circular(8),
      );
      canvas.drawRRect(r, paint);
      canvas.drawRRect(r, outline);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _spawnTimer += dt;
    if (_spawnTimer >= spawnInterval) {
      _spawnTimer = 0;
      _spawnNext();
    }
    // No stale-replace: once a piggy is in the queue, she stays. It's the
    // player's job to choose what to keep. Filtering the spawner by "colours
    // present on board" also made end-game trivial (only useful colours came)
    // so we roll uniformly over the whole palette below.
  }

  void _spawnNext() {
    final freeIdx = _slots.indexWhere((p) => p == null);
    if (freeIdx == -1) return; // queue is full — blocked
    if (isPuzzleMode && _pool.isEmpty && game.pendingRewardType == null) {
      return; // arsenal drained, no reward pending — nothing to spawn
    }
    _spawnInto(freeIdx, animated: true);
  }

  /// Weighted pick: colours currently on the board are 2× more likely than
  /// those that aren't. Non-board colours still have a real chance so the
  /// player isn't guaranteed a useful spawn — luck matters.
  ///
  /// Then anti-monotony guard: never 3 of the same colour in a row.
  PiggyColor _pickColor() {
    final weights = <int>[];
    var totalWeight = 0;
    for (final c in palette) {
      final w = game.board.hasBlockOfColor(c) ? 2 : 1;
      weights.add(w);
      totalWeight += w;
    }
    var roll = _rng.nextInt(totalWeight);
    PiggyColor chosen = palette.last;
    for (var i = 0; i < palette.length; i++) {
      roll -= weights[i];
      if (roll < 0) {
        chosen = palette[i];
        break;
      }
    }

    if (chosen == _lastColor && _sameColorStreak >= 2 && palette.length > 1) {
      final others = palette.where((c) => c != chosen).toList();
      chosen = others[_rng.nextInt(others.length)];
    }
    if (chosen == _lastColor) {
      _sameColorStreak++;
    } else {
      _sameColorStreak = 1;
      _lastColor = chosen;
    }
    return chosen;
  }

  void _spawnInto(int idx, {required bool animated}) {
    // Never overwrite an occupied slot — the caller (usually _spawnNext) should
    // have found a free index first. If we ever hit this the previous pig would
    // be orphaned in the world at the same target position, which is the "two
    // pigs in one slot" bug the user reported for L2.
    if (_slots[idx] != null) return;

    // Consume a pending combo reward if we have one.
    PiggyType type = PiggyType.normal;
    if (game.pendingRewardType != null) {
      type = game.pendingRewardType!;
      game.pendingRewardType = null;
      game.notePendingRewardConsumed();
    }

    final PiggyColor color;
    final int ammo;
    if (isPuzzleMode && type == PiggyType.normal) {
      if (_pool.isEmpty) return; // guard — shouldn't reach here, _spawnNext checks
      final pick = _pool.removeAt(0);
      color = pick.color;
      ammo = pick.ammo;
      // A bundle can pre-load a special (filter/bomb/rainbow/…) into the
      // puzzle inventory; when we pull one, its type wins over the default
      // PiggyType.normal set above.
      type = pick.type;
    } else {
      color = _pickColor();
      // Special piggies get a bit less ammo so they don't trivialise the level.
      final maxAmmo = type.isSpecial ? math.min(8, ammoMax) : ammoMax;
      final minAmmo = type.isSpecial ? math.min(3, ammoMin) : ammoMin;
      ammo = minAmmo + _rng.nextInt(math.max(1, maxAmmo - minAmmo + 1));
    }

    final target = _slotPosition(idx);
    final start = animated
        ? Vector2(target.x, target.y + 80)
        : target.clone();
    final p = PiggyComponent(
      piggyColor: color,
      ammo: ammo,
      position: start,
      type: type,
    );
    p.state = PiggyState.inQueue;
    _slots[idx] = p;
    game.world.add(p);
    if (animated) {
      p.add(MoveToEffect(
        target,
        EffectController(duration: 0.35, curve: Curves.easeOut),
        // Snap-lock to the CURRENT logical slot position, not the closed-over
        // `target`. If _compact moved this piggy to a different slot while the
        // spawn animation was still running, the closure would otherwise snap
        // her back to the original slot on top of a freshly spawned piggy —
        // that's the "two pigs in one slot" bug.
        onComplete: () {
          final curIdx = _slots.indexOf(p);
          if (curIdx >= 0) p.position.setFrom(_slotPosition(curIdx));
        },
      ));
    }
  }

  Vector2 _slotPosition(int index) {
    final slotW = size.x / slotCount;
    return Vector2(
      area.left + index * slotW + slotW / 2,
      area.top + size.y / 2,
    );
  }

  bool get hasFreeSlot => _slots.contains(null);

  /// Called by piggy when it's launched onto the conveyor.
  /// Compacts remaining piggies to the left.
  void removePiggy(PiggyComponent p) {
    final idx = _slots.indexOf(p);
    if (idx == -1) return;
    _slots[idx] = null;
    _compact();
  }

  void _compact() {
    // Shift piggies to the leftmost free slots.
    var writeIdx = 0;
    for (var i = 0; i < slotCount; i++) {
      final p = _slots[i];
      if (p != null) {
        if (writeIdx != i) {
          _slots[writeIdx] = p;
          _slots[i] = null;
          // Kill any in-flight MoveToEffect (from a still-running spawn or
          // an earlier compact) — otherwise their onComplete snap-lock
          // yanks the piggy back to a stale target and stacks two piggies
          // at the same visual point.
          for (final e in p.children.whereType<MoveToEffect>().toList()) {
            e.removeFromParent();
          }
          p.add(MoveToEffect(
            _slotPosition(writeIdx),
            EffectController(duration: 0.22, curve: Curves.easeOut),
            onComplete: () {
              final curIdx = _slots.indexOf(p);
              if (curIdx >= 0) p.position.setFrom(_slotPosition(curIdx));
            },
          ));
        }
        writeIdx++;
      }
    }
  }

  /// Index of a piggy in the queue, or -1 if not present.
  int indexOf(PiggyComponent p) => _slots.indexOf(p);
}

/// One entry in the puzzle-mode arsenal pool. Bundles are unrolled into
/// picks at level start so FIFO order matches inventory declaration order.
class _ArsenalPick {
  final PiggyColor color;
  final int ammo;
  final PiggyType type;
  const _ArsenalPick({
    required this.color,
    required this.ammo,
    this.type = PiggyType.normal,
  });
}

// ------------------------------------------------------------
// Waiting Slots
// ------------------------------------------------------------

class WaitingSlotsComponent extends PositionComponent {
  WaitingSlotsComponent({required this.area, required this.count}) {
    position = Vector2(area.left, area.top);
    size = Vector2(area.width, area.height);
  }

  final Rect area;
  final int count;
  late final List<Slot> _slots;

  @override
  Future<void> onLoad() async {
    _slots = List.generate(count, (i) => Slot(index: i, parent: this));
  }

  @override
  void render(Canvas canvas) {
    final slotW = size.x / count;
    // Waiting-slot tint reacts ONLY to the belt — a waiting-piggy releases her
    // own slot when launched, so waiting-slot fullness doesn't block her.
    final game = findGame();
    final busy = game is PixelFlowGame && game.waitingLaunchBlockReason() != null;
    final paint = Paint()
      ..color = busy
          ? const Color(0xFF4A1E1E).withValues(alpha: 0.6)
          : Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = busy
          ? const Color(0xFFE64A4A).withValues(alpha: 0.55)
          : Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = busy ? 2.5 : 1.5;
    for (var i = 0; i < count; i++) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * slotW + 4, 4, slotW - 8, size.y - 8),
        const Radius.circular(8),
      );
      canvas.drawRRect(r, paint);
      canvas.drawRRect(r, outline);
    }
  }

  // Waiting piggies stay put once parked — losing a colour doesn't evict
  // them. The player decides what to keep in a slot; the system only reports
  // STUCK if there's no path forward.

  Slot? findFreeSlot() {
    for (final s in _slots) {
      if (s.piggy == null) return s;
    }
    return null;
  }

  bool get hasFreeSlot => findFreeSlot() != null;

  void release(PiggyComponent p) {
    for (final s in _slots) {
      if (s.piggy == p) s.piggy = null;
    }
  }
}

class Slot {
  Slot({required this.index, required this.parent});
  final int index;
  final WaitingSlotsComponent parent;
  PiggyComponent? piggy;

  Vector2 get worldCenter {
    final slotW = parent.size.x / parent.count;
    return Vector2(
      parent.position.x + index * slotW + slotW / 2,
      parent.position.y + parent.size.y / 2,
    );
  }
}
