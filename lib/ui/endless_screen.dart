import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/achievements.dart';
import '../game/level_generator.dart';
import '../game/levels.dart';
import '../game/models.dart';
import '../game/pixel_flow_game.dart';
import '../game/progress.dart';
import 'achievements_screen.dart' show showAchievementToasts;

/// Endless mode: procedural levels of ever-increasing difficulty. The player
/// picks up a streak — each cleared level adds to it, a STUCK ends the run.
///
/// The world rotates every 4 levels so the run feels varied. Difficulty tier
/// grows linearly and pushes past the hand-crafted worlds' peak past streak 10.
class EndlessScreen extends StatefulWidget {
  const EndlessScreen({super.key});

  @override
  State<EndlessScreen> createState() => _EndlessScreenState();
}

enum _EndKind { none, win, lose }

class _EndlessScreenState extends State<EndlessScreen> {
  int _streak = 0; // levels cleared so far
  int _bestBefore = 0;
  late PixelFlowGame _game;
  late String _currentWorld;
  _EndKind _end = _EndKind.none;
  /// Signatures of every grid the player has seen this run — the generator
  /// never returns a repeat while this set survives.
  final Set<int> _seenGrids = <int>{};

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    _bestBefore = await Progress.loadEndlessBest();
    if (!mounted) return;
    setState(() => _spawnNextLevel());
  }

  /// Spawn a fresh procedural level scaled to the current streak.
  void _spawnNextLevel() {
    _end = _EndKind.none;
    // Endless starts hard on purpose — skip the tutorial world entirely and
    // rotate every 2 levels for constant variety.
    const rotation = ['factory', 'gallery', 'frozen'];
    _currentWorld = rotation[(_streak ~/ 2) % rotation.length];

    // Base tier 0.4 (already past the easiest levels), ramps to 1.0 by
    // streak 5 and keeps climbing past 2.0 for high-streak hardcore.
    final tier = 0.4 + _streak / 8.0;
    final level = LevelGenerator.generate(
      worldId: _currentWorld,
      seed: DateTime.now().microsecondsSinceEpoch ^ _streak,
      tier: tier,
      levelNumber: _streak + 1,
      seenHashes: _seenGrids,
    );
    _game = PixelFlowGame(
      level: level,
      onWin: _onWin,
      onLose: _onLose,
    );
  }

  Future<void> _onWin() async {
    if (_end != _EndKind.none) return;
    setState(() {
      _streak++;
      _end = _EndKind.win;
    });
    // Milestone achievements.
    if (_streak >= 5) await AchievementManager.unlock(Achievement.endless5);
    if (_streak >= 10) await AchievementManager.unlock(Achievement.endless10);
    if (_streak >= 25) await AchievementManager.unlock(Achievement.endless25);
    if (_streak >= 50) await AchievementManager.unlock(Achievement.endless50);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showAchievementToasts(context);
    });
  }

  Future<void> _onLose() async {
    if (_end != _EndKind.none) return;
    // Persist the streak as a best if it beats the previous.
    await Progress.saveEndlessStreak(_streak);
    if (!mounted) return;
    setState(() => _end = _EndKind.lose);
  }

  void _nextLevel() {
    setState(_spawnNextLevel);
  }

  void _giveUpAndExit() {
    Navigator.of(context).pop();
  }

  Future<void> _restart() async {
    // Reset streak and clear the "seen grids" memory — a brand new run
    // deserves the full template pool again.
    setState(() {
      _streak = 0;
      _seenGrids.clear();
      _spawnNextLevel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final world = worlds.firstWhere(
      (w) => w.id == _currentWorld,
      orElse: () => worlds.first,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF2A2140),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: GameWidget(game: _game)),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _hud(world),
            ),
            if (_end == _EndKind.win) _winOverlay(),
            if (_end == _EndKind.lose) _loseOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _hud(WorldConfig world) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _closeButton(),
            _streakBadge(),
            _restartButton(),
          ],
        ),
        const SizedBox(height: 6),
        Align(alignment: Alignment.centerRight, child: _worldChip(world)),
        const SizedBox(height: 6),
        // Missing-colour warning — mirrors game_screen's FxTimersRow bit.
        ValueListenableBuilder<GameFxState>(
          valueListenable: _game.fx,
          builder: (_, fx, __) {
            if (fx.missingColors.isEmpty) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
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
                    for (final c in fx.missingColors)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            color: c.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.black.withValues(alpha: 0.4),
                                width: 1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _closeButton() {
    return GestureDetector(
      onTap: _confirmExit,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFB03A3A),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 2),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.close, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _restartButton() {
    return GestureDetector(
      onTap: _restartCurrentLevel,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF3B7CB3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 2),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.refresh, color: Colors.white, size: 22),
      ),
    );
  }

  /// Re-generates the CURRENT streak's level with a fresh seed. Streak is
  /// preserved (you don't lose progress) but the layout & piggy sequence are
  /// different so a retry actually gives you a new chance.
  void _restartCurrentLevel() {
    setState(_spawnNextLevel);
  }

  Widget _streakBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9438),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            'Уровень ${_streak + 1}',
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

  Widget _worldChip(WorldConfig world) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: world.color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(world.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            world.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF3B7CB3),
        title: const Text('Выйти из Endless?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text('Текущий streak ($_streak) сохранится.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Продолжить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Progress.saveEndlessStreak(_streak);
      if (!mounted) return;
      _giveUpAndExit();
    }
  }

  Widget _winOverlay() {
    return _overlay(
      title: 'ПРОШЁЛ!',
      subtitle: 'Streak: $_streak',
      background: const Color(0xFF6ECF3A),
      leftLabel: 'MENU',
      leftColor: const Color(0xFF3B7CB3),
      leftAction: _giveUpAndExit,
      rightLabel: 'ДАЛЬШЕ',
      rightColor: const Color(0xFFFF9438),
      rightAction: _nextLevel,
    );
  }

  Widget _loseOverlay() {
    final beatBest = _streak > _bestBefore;
    return _overlay(
      title: beatBest ? 'НОВЫЙ РЕКОРД!' : 'GAME OVER',
      subtitle: beatBest
          ? 'Streak: $_streak (было $_bestBefore)'
          : 'Streak: $_streak (лучший $_bestBefore)',
      background: const Color(0xFFB03A3A),
      leftLabel: 'MENU',
      leftColor: const Color(0xFF3B7CB3),
      leftAction: _giveUpAndExit,
      rightLabel: 'НАЧАТЬ ЗАНОВО',
      rightColor: const Color(0xFFFF9438),
      rightAction: _restart,
    );
  }

  Widget _overlay({
    required String title,
    required String subtitle,
    required Color background,
    required String leftLabel,
    required Color leftColor,
    required VoidCallback leftAction,
    required String rightLabel,
    required Color rightColor,
    required VoidCallback rightAction,
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
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  )),
              const SizedBox(height: 10),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 22),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _bigButton(leftLabel, leftColor, leftAction),
                  const SizedBox(width: 12),
                  _bigButton(rightLabel, rightColor, rightAction),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bigButton(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          )),
    );
  }
}
