import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/audio.dart';
import '../game/levels.dart';
import '../game/progress.dart';
import 'achievements_screen.dart';
import 'daily_screen.dart';
import 'endless_screen.dart';
import 'game_screen.dart';
import 'info_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _maxCompleted = 0;
  int _totalScore = 0;
  int _endlessBest = 0;
  int _dailyStreak = 0;
  bool _dailyDoneToday = false;
  final Map<int, int> _starsPerLevel = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await Progress.loadMaxCompleted();
    final total = await Progress.totalScore();
    final endlessBest = await Progress.loadEndlessBest();
    final dailyStreak = await Progress.loadDailyStreak();
    final dailyDone = await Progress.isDailyDoneToday();
    final stars = <int, int>{};
    for (final l in levels) {
      stars[l.levelNumber] = await Progress.loadStars(l.levelNumber);
    }
    if (!mounted) return;
    setState(() {
      _maxCompleted = v;
      _totalScore = total;
      _endlessBest = endlessBest;
      _dailyStreak = dailyStreak;
      _dailyDoneToday = dailyDone;
      _starsPerLevel
        ..clear()
        ..addAll(stars);
      _loading = false;
    });
  }

  bool _isUnlocked(int level) => level <= _maxCompleted + 1;
  bool _isCompleted(int level) => level <= _maxCompleted;

  Future<void> _openLevel(int levelIndex) async {
    // First user gesture also unlocks web audio autoplay for bgm.
    AudioService.startBgm();
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(startLevelIndex: levelIndex),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF3B7CB3),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF3B7CB3),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_menu.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF3B7CB3)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _infoButton(),
                      const SizedBox(width: 10),
                      _achievementsButton(),
                      const Spacer(),
                      _shopButton(),
                      const SizedBox(width: 10),
                      _settingsButton(),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                _titleBadge(),
                const SizedBox(height: 8),
                _scoreBadge(),
                const SizedBox(height: 10),
                _endlessBanner(),
                const SizedBox(height: 6),
                _dailyBanner(),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      children: [
                        for (final world in worlds) _worldSection(world),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoButton() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const InfoScreen()),
      ),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF224F73),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 3),
        ),
        alignment: Alignment.center,
        child: const Text(
          'i',
          style: TextStyle(
            fontSize: 28,
            fontFamily: 'serif',
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _settingsButton() {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
        if (mounted) _load();
      },
      child: SizedBox(
        width: 52,
        height: 52,
        child: Image.asset('assets/images/icon_settings.png', fit: BoxFit.contain),
      ),
    );
  }

  Widget _achievementsButton() {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AchievementsScreen()),
        );
        if (mounted) _load(); // refresh total score after bonus awards
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFFFD338),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD338).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _shopButton() {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ShopScreen()),
        );
        if (mounted) _load(); // refresh score after possible purchase
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFFF9438),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF9438).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _endlessBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () async {
          AudioService.startBgm();
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EndlessScreen()),
          );
          if (mounted) _load();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF9438), Color(0xFFB03A3A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.35), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF9438).withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: Colors.white, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ENDLESS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        )),
                    Text('Бесконечная серия',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'BEST $_endlessBest',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dailyBanner() {
    final bgColor = _dailyDoneToday
        ? const Color(0xFF3B7CB3)
        : const Color(0xFF9B59B6);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () async {
          AudioService.startBgm();
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DailyScreen()),
          );
          if (mounted) _load();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.35), width: 2),
          ),
          child: Row(
            children: [
              Icon(
                _dailyDoneToday ? Icons.check_circle_rounded : Icons.calendar_today_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_dailyDoneToday ? 'СЕГОДНЯ ПРОЙДЕН' : 'ЕЖЕДНЕВНЫЙ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        )),
                    Text(
                      _dailyDoneToday
                          ? 'Возвращайся завтра'
                          : '+${Progress.dailyReward} ★ за прохождение',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$_dailyStreak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFD338), size: 20),
          const SizedBox(width: 6),
          Text(
            '$_totalScore',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// One world = header banner + horizontally-flowing hexagons for its levels.
  /// Levels beyond what's implemented (coming-soon world) show a locked
  /// placeholder tile instead of a real hex.
  Widget _worldSection(WorldConfig world) {
    // Which levels from [levels] actually fall into this world (they may not
    // exist yet if the world is marked coming-soon).
    final worldLevels = levels.where((l) => world.contains(l.levelNumber)).toList();
    final levelIndexOf = <int, int>{};
    for (var i = 0; i < levels.length; i++) {
      levelIndexOf[levels[i].levelNumber] = i;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _worldHeader(world),
          const SizedBox(height: 12),
          if (world.comingSoon && worldLevels.isEmpty)
            _comingSoonTile(world)
          else
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final l in worldLevels)
                  _LevelHex(
                    levelNumber: l.levelNumber,
                    unlocked: _isUnlocked(l.levelNumber),
                    completed: _isCompleted(l.levelNumber),
                    stars: _starsPerLevel[l.levelNumber] ?? 0,
                    accentColor: world.color,
                    onTap: _isUnlocked(l.levelNumber)
                        ? () => _openLevel(levelIndexOf[l.levelNumber]!)
                        : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _worldHeader(WorldConfig world) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: world.color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.35), width: 2),
        boxShadow: [
          BoxShadow(
            color: world.color.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            world.emoji,
            style: const TextStyle(fontSize: 26),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  world.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    shadows: [Shadow(color: Colors.black38, offset: Offset(1, 1), blurRadius: 2)],
                  ),
                ),
                if (world.tagline != null)
                  Text(
                    world.tagline!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (world.comingSoon)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'SOON',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _comingSoonTile(WorldConfig world) {
    return Container(
      height: 90,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: world.color.withValues(alpha: 0.4), width: 2, style: BorderStyle.solid),
      ),
      child: Text(
        'Скоро…',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _titleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF224F73),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 3),
      ),
      child: const Text(
        'PiFlow',
        style: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _LevelHex extends StatelessWidget {
  const _LevelHex({
    required this.levelNumber,
    required this.unlocked,
    required this.completed,
    required this.stars,
    required this.onTap,
    this.accentColor,
  });

  final int levelNumber;
  final bool unlocked;
  final bool completed;
  final int stars;
  final VoidCallback? onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    // Locked → grey; completed → world accent (or orange fallback); unlocked
    // but not yet passed → blue "next up".
    final baseColor = !unlocked
        ? const Color(0xFF5A6A7A)
        : completed
            ? (accentColor ?? const Color(0xFFFF9438))
            : const Color(0xFF3B93E6);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: CustomPaint(
              painter: _HexPainter(color: baseColor, outline: Colors.black.withValues(alpha: 0.5)),
              child: Center(
                child: unlocked
                    ? Text(
                        '$levelNumber',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Colors.black45, offset: Offset(2, 2), blurRadius: 4),
                          ],
                        ),
                      )
                    : const Icon(Icons.lock, color: Colors.white, size: 34),
              ),
            ),
          ),
          if (completed) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final on = i < stars;
                return Icon(
                  on ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 18,
                  color: on ? const Color(0xFFFFD338) : Colors.white38,
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  _HexPainter({required this.color, required this.outline});
  final Color color;
  final Color outline;

  Path _hexPath(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angleDeg = -90 + i * 60;
      final angle = angleDeg * math.pi / 180;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _hexPath(size);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = outline
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _HexPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.outline != outline;
}
