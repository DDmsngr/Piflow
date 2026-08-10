import 'package:flutter/material.dart';

import '../game/achievements.dart';

/// Displays all achievements as a grid. Unlocked ones are highlighted;
/// locked ones show the emoji dimmed and no title (mystery).
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  Set<String> _unlocked = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await AchievementManager.loadUnlocked();
    if (!mounted) return;
    setState(() {
      _unlocked = u;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF224F73),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    final all = Achievement.values;
    final unlockedCount = all.where((a) => _unlocked.contains(a.id)).length;
    return Scaffold(
      backgroundColor: const Color(0xFF224F73),
      body: SafeArea(
        child: Column(
          children: [
            _header(context, unlockedCount, all.length),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.9,
                ),
                itemCount: all.length,
                itemBuilder: (_, i) => _AchievementCard(
                  a: all[i],
                  unlocked: _unlocked.contains(all[i].id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, int unlocked, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Material(
            color: const Color(0xFF3B7CB3),
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Достижения',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$unlocked / $total',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.a, required this.unlocked});
  final Achievement a;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: unlocked ? const Color(0xFF3B7CB3) : const Color(0xFF1F3B52),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unlocked
              ? const Color(0xFFFFD338)
              : Colors.black.withValues(alpha: 0.3),
          width: unlocked ? 3 : 2,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              a.icon,
              style: TextStyle(
                fontSize: 40,
                color: unlocked ? null : Colors.white.withValues(alpha: 0.25),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unlocked ? a.title : '???',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: unlocked ? Colors.white : Colors.white54,
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Text(
              unlocked ? a.description : 'заблокировано',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: unlocked ? 0.85 : 0.4),
                height: 1.2,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: unlocked
                  ? const Color(0xFFFFD338)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '+${a.reward} ★',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: unlocked ? Colors.black87 : Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Show a snackbar-style toast when achievements unlock. Call from any
/// screen's `didChangeDependencies` or after user actions to drain the queue.
void showAchievementToasts(BuildContext context) {
  final pending = AchievementManager.takePendingToasts();
  if (pending.isEmpty) return;
  for (final a in pending) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF224F73),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFFFD338), width: 2),
        ),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(a.icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Достижение!',
                      style: TextStyle(
                        color: Color(0xFFFFD338),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      )),
                  Text(a.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      )),
                  Text('+${a.reward} ★',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
