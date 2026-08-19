import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/achievements.dart';
import '../game/levels.dart';
import '../game/models.dart';
import '../game/pixel_flow_game.dart';
import '../game/progress.dart';
import '../game/scoring.dart';
import 'achievements_screen.dart' show showAchievementToasts;

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.startLevelIndex = 0});
  final int startLevelIndex;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum _EndKind { none, win, lose }

class _GameScreenState extends State<GameScreen> {
  late int levelIndex;
  late PixelFlowGame game;
  _EndKind _end = _EndKind.none;
  int _lastStars = 0;
  int _lastScore = 0;

  /// Puzzle-mode result (stars, moves/shots/colors/mastery). Null for
  /// legacy-mode levels — those still use the old star overlay.
  LevelResult? _lastResult;

  @override
  void initState() {
    super.initState();
    levelIndex = widget.startLevelIndex;
    _createGame();
  }

  void _createGame() {
    _end = _EndKind.none;
    _lastStars = 0;
    _lastScore = 0;
    _lastResult = null;
    game = PixelFlowGame(
      level: levels[levelIndex],
      onWin: _onWin,
      onLose: _onLose,
    );
  }

  Future<void> _onWin() async {
    if (_end != _EndKind.none) return;
    final level = levels[levelIndex];
    await Progress.markCompleted(level.levelNumber);

    if (level.isPuzzleMode) {
      final r = game.computeLevelResult(cleared: true);
      final stars = r.stars;
      final score = r.finalScore.round();
      await Progress.saveResult(
        levelNumber: level.levelNumber,
        stars: stars,
        score: score,
      );
      await _checkLevelAchievements(level, (stars: stars, score: score));
      if (!mounted) return;
      setState(() {
        _lastResult = r;
        _lastStars = stars;
        _lastScore = score;
        _end = _EndKind.win;
      });
    } else {
      final result = game.computeResult();
      await Progress.saveResult(
        levelNumber: level.levelNumber,
        stars: result.stars,
        score: result.score,
      );
      await _checkLevelAchievements(level, result);
      if (!mounted) return;
      setState(() {
        _lastStars = result.stars;
        _lastScore = result.score;
        _end = _EndKind.win;
      });
    }
    // Drain any newly-unlocked achievements into snackbars over the overlay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showAchievementToasts(context);
    });
  }

  /// Fires level-related achievements (first steps, first-star, 3★ counters,
  /// world clears). All idempotent — repeat plays don't unlock twice.
  Future<void> _checkLevelAchievements(
      LevelConfig level, ({int stars, int score}) result) async {
    if (level.levelNumber == 1) {
      await AchievementManager.unlock(Achievement.firstSteps);
    }
    if (result.stars >= 1) {
      await AchievementManager.unlock(Achievement.firstStar);
    }
    if (result.stars >= 3) {
      await AchievementManager.unlock(Achievement.first3Star);
      final count = await AchievementManager.incCounter('3star_levels');
      if (count >= 5) await AchievementManager.unlock(Achievement.perfectionist5);
      if (count >= 15) await AchievementManager.unlock(Achievement.perfectionist15);
    }
    // World-clear cheevos: fire when this level was the boss of its world AND
    // every level in the world is completed.
    final world = worldOf(level.levelNumber);
    if (world != null && level.levelNumber == world.lastLevel) {
      final maxDone = await Progress.loadMaxCompleted();
      if (maxDone >= world.lastLevel) {
        final ach = switch (world.id) {
          'piggypark' => Achievement.clearPiggypark,
          'factory' => Achievement.clearFactory,
          'gallery' => Achievement.clearGallery,
          'frozen' => Achievement.clearFrozen,
          _ => null,
        };
        if (ach != null) await AchievementManager.unlock(ach);
      }
    }
  }

  void _onLose() {
    if (_end != _EndKind.none) return;
    final level = levels[levelIndex];
    if (level.isPuzzleMode) {
      final r = game.computeLevelResult(cleared: false);
      if (!mounted) return;
      setState(() {
        _lastResult = r;
        _lastStars = 0;
        _lastScore = 0;
        _end = _EndKind.lose;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _end = _EndKind.lose);
  }

  void _nextLevel() {
    if (levelIndex + 1 >= levels.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      levelIndex++;
      _createGame();
    });
  }

  void _restart() {
    setState(_createGame);
  }

  void _backToMenu() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final level = levels[levelIndex];
    final isLast = levelIndex + 1 >= levels.length;
    return Scaffold(
      backgroundColor: const Color(0xFF2A2140),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: GameWidget(game: game)),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _pngButton('assets/images/icon_close.png', _backToMenu),
                      _hudLabel('Level ${level.levelNumber}'),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<GameFxState>(
                            valueListenable: game.fx,
                            builder: (_, fx, __) => _RewardPill(type: fx.pendingReward),
                          ),
                          const SizedBox(width: 8),
                          _hudButton(Icons.refresh, _restart),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<int>(
                    valueListenable: game.remainingBlocks,
                    builder: (_, remaining, __) => _progressStrip(
                      remaining: remaining,
                      total: level.totalBlocks,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ValueListenableBuilder<GameFxState>(
                    valueListenable: game.fx,
                    builder: (_, fx, __) => _FxTimersRow(fx: fx),
                  ),
                ],
              ),
            ),
            // Combo flash sits in the middle of the screen — brief attention
            // grabber synced with screen-shake.
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<GameFxState>(
                  valueListenable: game.fx,
                  builder: (_, fx, __) => _ComboFlash(size: fx.comboFlashSize),
                ),
              ),
            ),
            if (_end == _EndKind.win)
              _lastResult != null
                  ? _puzzleResultOverlay(_lastResult!, cleared: true, isLast: isLast)
                  : _winOverlay(isLast),
            if (_end == _EndKind.lose)
              _lastResult != null
                  ? _puzzleResultOverlay(_lastResult!, cleared: false, isLast: isLast)
                  : _loseOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _progressStrip({required int remaining, required int total}) {
    final safeTotal = total == 0 ? 1 : total;
    final done = (total - remaining).clamp(0, total);
    final ratio = done / safeTotal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.grid_view_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(height: 10, color: Colors.white.withValues(alpha: 0.15)),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 200),
                    widthFactor: ratio,
                    child: Container(
                      height: 10,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6ECF3A), Color(0xFFFFD338)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$remaining',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0xFF5AC8FA),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _pngButton(String asset, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 46,
        height: 46,
        child: Image.asset(asset, fit: BoxFit.contain),
      ),
    );
  }

  Widget _hudLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF3B7CB3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.3), width: 2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _winOverlay(bool isLast) {
    return _endOverlay(
      title: isLast ? 'ALL DONE!' : 'LEVEL COMPLETE!',
      titleColor: Colors.white,
      background: const Color(0xFF5AC8FA),
      leftLabel: 'MENU',
      leftColor: const Color(0xFF3B7CB3),
      leftAction: _backToMenu,
      rightLabel: isLast ? 'DONE' : 'NEXT',
      rightColor: const Color(0xFFFF9438),
      rightAction: _nextLevel,
      extra: _resultBadge(),
    );
  }

  Widget _resultBadge() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final earned = i < _lastStars;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                earned ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 40,
                color: earned ? const Color(0xFFFFD338) : Colors.white54,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF224F73),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '+$_lastScore',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _loseOverlay() {
    return _endOverlay(
      title: 'STUCK!',
      subtitle: 'Ни одна свинка не подходит\nк оставшимся блокам',
      titleColor: Colors.white,
      background: const Color(0xFFB03A3A),
      leftLabel: 'MENU',
      leftColor: const Color(0xFF3B7CB3),
      leftAction: _backToMenu,
      rightLabel: 'RETRY',
      rightColor: const Color(0xFFFF9438),
      rightAction: _restart,
    );
  }

  // ── Puzzle-mode result overlay (2026-08-12 rewrite) ─────────────────────
  //  Aleksey's spec: 3 звезды + Ходы/Выстрелы/Цвета/Мастерство + Цели уровня
  //  + Итог. Никаких Par/S/SS/equality/Ammo.
  //  UI reads LevelResult exclusively — все данные уже в r.
  Widget _puzzleResultOverlay(
    LevelResult r, {
    required bool cleared,
    required bool isLast,
  }) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.62),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              color: cleared ? const Color(0xFF224F73) : const Color(0xFF4A3A55),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  cleared ? 'УРОВЕНЬ ПРОЙДЕН!' : 'Уровень не пройден',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: cleared ? 22 : 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: cleared ? 1.0 : 0.85),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 14),
                _StarsRow(earned: r.stars),
                const SizedBox(height: 18),
                _StatsBlock(result: r),
                const SizedBox(height: 16),
                _GoalsBlock(result: r),
                const SizedBox(height: 14),
                _VerdictBlock(text: r.motivationalHint),
                if (cleared && r.finalScore > 0) ...[
                  const SizedBox(height: 14),
                  Text(
                    '+${r.finalScore.round()} ОЧКОВ',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFD338),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _bigButton(
                      label: 'MENU',
                      color: const Color(0xFF3B7CB3),
                      onTap: _backToMenu,
                    ),
                    const SizedBox(width: 10),
                    _bigButton(
                      label: 'RETRY',
                      color: const Color(0xFFFF9438),
                      onTap: _restart,
                    ),
                    if (cleared) ...[
                      const SizedBox(width: 10),
                      _bigButton(
                        label: isLast ? 'DONE' : 'NEXT',
                        color: const Color(0xFF6ECF3A),
                        onTap: _nextLevel,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _endOverlay({
    required String title,
    String? subtitle,
    required Color titleColor,
    required Color background,
    required String leftLabel,
    required Color leftColor,
    required VoidCallback leftAction,
    required String rightLabel,
    required Color rightColor,
    required VoidCallback rightAction,
    Widget? extra,
  }) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(28),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: titleColor.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (extra != null) ...[
                const SizedBox(height: 16),
                extra,
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _bigButton(label: leftLabel, color: leftColor, onTap: leftAction),
                  const SizedBox(width: 12),
                  _bigButton(label: rightLabel, color: rightColor, onTap: rightAction),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bigButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FX HUD widgets: pending reward pill, active-effect timers, combo flash.
// ---------------------------------------------------------------------------

/// Small round chip next to the refresh button that shows which special
/// piggy the next spawn will produce. Empty (invisible slot) when nothing
/// is queued — kept in-tree with fixed size so the row doesn't jump.
class _RewardPill extends StatelessWidget {
  const _RewardPill({required this.type});
  final PiggyType? type;

  @override
  Widget build(BuildContext context) {
    if (type == null || type!.spriteAsset == null) {
      return const SizedBox(width: 46, height: 46);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(type!.name),
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.elasticOut,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFFFD338),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.45), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD338).withValues(alpha: 0.6),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Image.asset(
          'assets/images/${type!.spriteAsset}',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// Two side-by-side chips (freeze snowflake, universal star) that appear
/// only while their respective effect is active. Countdown ring shows
/// remaining fraction.
class _FxTimersRow extends StatelessWidget {
  const _FxTimersRow({required this.fx});
  final GameFxState fx;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (fx.freezeRemaining > 0 && fx.freezeMax > 0) {
      chips.add(_FxChip(
        icon: Icons.ac_unit_rounded,
        label: fx.freezeRemaining.toStringAsFixed(1),
        color: const Color(0xFF5AC8FA),
        progress: (fx.freezeRemaining / fx.freezeMax).clamp(0.0, 1.0),
      ));
    }
    if (fx.universalRemaining > 0 && fx.universalMax > 0 && fx.universalColor != null) {
      chips.add(_FxChip(
        icon: Icons.auto_awesome,
        label: fx.universalRemaining.toStringAsFixed(1),
        color: fx.universalColor!.color,
        progress: (fx.universalRemaining / fx.universalMax).clamp(0.0, 1.0),
      ));
    }
    if (fx.missingColors.isNotEmpty) {
      chips.add(_MissingColorsWarning(colors: fx.missingColors));
    }
    if (chips.isEmpty) return const SizedBox(height: 0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (final c in chips) Padding(
          padding: const EdgeInsets.only(right: 6),
          child: c,
        ),
      ],
    );
  }
}

/// "Нужен цвет: [dot][dot]" chip that appears when a board colour has no
/// piggy anywhere. Nudges the player to keep the queue rolling.
class _MissingColorsWarning extends StatelessWidget {
  const _MissingColorsWarning({required this.colors});
  final List<PiggyColor> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF9438), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFFF9438), size: 14),
          const SizedBox(width: 6),
          const Text('нужен',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(width: 6),
          for (final c in colors)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: c.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.black.withValues(alpha: 0.4), width: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FxChip extends StatelessWidget {
  const _FxChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.progress,
  });
  final IconData icon;
  final String label;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.8), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(color),
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                Icon(icon, color: color, size: 12),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${label}s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Combo x7!" that fades in/out over ~0.9s. Sits above the board so the
/// player's eyes catch it while the shake plays.
class _ComboFlash extends StatelessWidget {
  const _ComboFlash({required this.size});
  final int size;

  @override
  Widget build(BuildContext context) {
    if (size <= 0) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      key: ValueKey(size), // restart animation on each new combo
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, t, __) {
        final scale = 0.7 + t * 0.6;
        final opacity = (t < 0.15
                ? t / 0.15
                : (t < 0.7 ? 1.0 : (1.0 - (t - 0.7) / 0.3)))
            .clamp(0.0, 1.0);
        return Align(
          alignment: const Alignment(0, -0.35),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9438),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.5), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9438).withValues(alpha: 0.55),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Text(
                  'COMBO ×$size!',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                    shadows: [Shadow(color: Colors.black38, offset: Offset(1, 2), blurRadius: 3)],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Puzzle-mode result overlay support widgets (2026-08-12 rewrite) ────────

/// Three stars, filled/hollow based on earned count (0-3).
class _StarsRow extends StatelessWidget {
  const _StarsRow({required this.earned});
  final int earned;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final on = i < earned;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            on ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 52,
            color: on ? const Color(0xFFFFD338) : Colors.white38,
          ),
        );
      }),
    );
  }
}

/// Stats block: Ходы / Выстрелы / Цвета / Мастерство (each = label + main + status).
class _StatsBlock extends StatelessWidget {
  const _StatsBlock({required this.result});
  final LevelResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final movesOverflow = r.launchOverflow;
    final String movesStatus;
    if (movesOverflow == 0) {
      movesStatus = 'Цель выполнена';
    } else if (movesOverflow > 0) {
      movesStatus = '+$movesOverflow ходов к цели';
    } else {
      movesStatus = 'На ${-movesOverflow} лучше цели';
    }

    final colorsRequired = r.colorsRequired.length;
    final colorsUsed = r.colorsUsed.intersection(r.colorsRequired).length;
    final colorsExtra = r.extraColors.length;
    final String colorsStatus;
    if (colorsExtra > 0) {
      colorsStatus = 'Лишний цвет: $colorsExtra';
    } else if (colorsUsed >= colorsRequired) {
      colorsStatus = 'Выполнено';
    } else {
      colorsStatus = 'Не хватает: ${colorsRequired - colorsUsed}';
    }

    final String masteryLabel;
    final String masteryStatus;
    if (r.masteryLabel != null && r.masteryPassed != null) {
      masteryLabel = r.masteryLabel!;
      masteryStatus = r.masteryPassed! ? 'Выполнено' : 'Не выполнено';
    } else {
      masteryLabel = 'Без лишних выстрелов';
      masteryStatus = r.unusedAmmo == 0 ? 'Выполнено' : 'Не выполнено';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatRow(
          label: 'Ходы',
          main: '${r.movesUsed} / ${r.movesTarget}',
          status: movesStatus,
          ok: movesOverflow <= 0,
        ),
        _StatRow(
          label: 'Выстрелы',
          main: 'Использовано: ${r.shotsUsed}',
          status: 'Осталось: ${r.unusedAmmo}',
          ok: r.unusedAmmo == 0,
        ),
        _StatRow(
          label: 'Цвета',
          main: '$colorsUsed / $colorsRequired',
          status: colorsStatus,
          ok: colorsExtra == 0 && colorsUsed >= colorsRequired,
        ),
        _StatRow(
          label: 'Мастерство',
          main: masteryLabel,
          status: masteryStatus,
          ok: masteryStatus == 'Выполнено',
        ),
      ],
    );
  }
}

/// One row of the stats block. Label left, main value mid, status right.
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.main,
    required this.status,
    required this.ok,
  });
  final String label;
  final String main;
  final String status;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  main,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: ok ? const Color(0xFF6ECF3A) : const Color(0xFFFFA07A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "ЦЕЛИ УРОВНЯ" — 3 goals (main / target / mastery) with tick/circle.
class _GoalsBlock extends StatelessWidget {
  const _GoalsBlock({required this.result});
  final LevelResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final masteryLabel = r.masteryLabel ?? 'Без лишних выстрелов';
    final masteryDone = r.masteryPassed ?? (r.unusedAmmo == 0);
    final items = <(String, bool)>[
      ('Уничтожить все кубики', r.checklist.cleared),
      ('Уложиться в ${r.movesTarget} ходов', r.launchOverflow <= 0),
      (masteryLabel, masteryDone),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ЦЕЛИ УРОВНЯ',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          ...items.map((it) {
            final (label, ticked) = it;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    ticked ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 16,
                    color: ticked ? const Color(0xFF6ECF3A) : Colors.white38,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: ticked ? Colors.white : Colors.white60,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// "ИТОГ" — motivational hint from scorer.
class _VerdictBlock extends StatelessWidget {
  const _VerdictBlock({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ИТОГ',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
