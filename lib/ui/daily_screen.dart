import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/level_generator.dart';
import '../game/pixel_flow_game.dart';
import '../game/progress.dart';

/// Daily challenge: one procedural level per calendar day, seed = date.
/// Every player who plays today sees the same layout.
class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

enum _EndKind { none, win, lose }

class _DailyScreenState extends State<DailyScreen> {
  late PixelFlowGame _game;
  _EndKind _end = _EndKind.none;
  int _streakBefore = 0;
  int _streakAfter = 0;
  bool _alreadyDoneToday = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    _streakBefore = await Progress.loadDailyStreak();
    _alreadyDoneToday = await Progress.isDailyDoneToday();
    _spawnLevel();
    if (mounted) setState(() {});
  }

  void _spawnLevel() {
    _end = _EndKind.none;
    // World cycles across weekdays: mon=piggypark, tue=factory, wed=gallery,
    // thu=frozen, fri=piggypark, sat=factory, sun=gallery. Anything memorable.
    const worlds = ['piggypark', 'factory', 'gallery', 'frozen'];
    final today = Progress.todayYmd();
    final weekday = DateTime.now().weekday - 1; // 0..6
    final worldId = worlds[weekday % worlds.length];
    final level = LevelGenerator.generate(
      worldId: worldId,
      seed: today, // fully deterministic per day
      tier: 0.6,   // mid difficulty for everyone
      levelNumber: today,
    );
    _game = PixelFlowGame(
      level: level,
      onWin: _onWin,
      onLose: _onLose,
    );
  }

  Future<void> _onWin() async {
    if (_end != _EndKind.none) return;
    // Only award the streak bump the first time today.
    if (!_alreadyDoneToday) {
      _streakAfter = await Progress.completeDailyToday();
      _alreadyDoneToday = true;
    } else {
      _streakAfter = _streakBefore;
    }
    if (!mounted) return;
    setState(() => _end = _EndKind.win);
  }

  void _onLose() {
    if (_end != _EndKind.none) return;
    if (!mounted) return;
    setState(() => _end = _EndKind.lose);
  }

  void _restart() => setState(_spawnLevel);
  void _exit() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
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
              child: _hud(),
            ),
            if (_end == _EndKind.win) _winOverlay(),
            if (_end == _EndKind.lose) _loseOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _hud() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _exit,
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFB03A3A),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 2),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.close, color: Colors.white, size: 22),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF9B59B6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.3), width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                'Ежедневный',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _restart,
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF3B7CB3),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 2),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.refresh, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _winOverlay() {
    final gained = _streakAfter > _streakBefore;
    return _overlay(
      title: gained ? 'ПРОШЁЛ!' : 'УЖЕ ПРОЙДЕН',
      subtitle: gained
          ? 'Streak: $_streakAfter дня. +${Progress.dailyReward} ★'
          : 'Streak: $_streakBefore дня (сегодняшний уже засчитан)',
      background: const Color(0xFF6ECF3A),
      leftLabel: 'MENU',
      leftAction: _exit,
      rightLabel: 'ЕЩЁ РАЗ',
      rightAction: _restart,
    );
  }

  Widget _loseOverlay() {
    return _overlay(
      title: 'STUCK!',
      subtitle: 'Streak сохранится, если пройдёшь сегодня',
      background: const Color(0xFFB03A3A),
      leftLabel: 'MENU',
      leftAction: _exit,
      rightLabel: 'ЕЩЁ РАЗ',
      rightAction: _restart,
    );
  }

  Widget _overlay({
    required String title,
    required String subtitle,
    required Color background,
    required String leftLabel,
    required VoidCallback leftAction,
    required String rightLabel,
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
              Text(title, textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              const SizedBox(height: 10),
              Text(subtitle, textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 22),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _btn(leftLabel, const Color(0xFF3B7CB3), leftAction),
                  const SizedBox(width: 12),
                  _btn(rightLabel, const Color(0xFFFF9438), rightAction),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap) {
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
