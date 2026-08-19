import 'package:shared_preferences/shared_preferences.dart';

/// Player progress persisted across sessions.
///
/// Storage layout:
/// - `piflow_max_completed_level`      int  — highest completed level
/// - `piflow_stars_L{N}`               int  — best stars 0..3 for level N
/// - `piflow_score_L{N}`               int  — best score for level N
class Progress {
  static const _keyMaxCompleted = 'piflow_max_completed_level';
  static String _keyStars(int n) => 'piflow_stars_L$n';
  static String _keyScore(int n) => 'piflow_score_L$n';

  static Future<int> loadMaxCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyMaxCompleted) ?? 0;
  }

  static Future<void> markCompleted(int levelNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyMaxCompleted) ?? 0;
    if (levelNumber > current) {
      await prefs.setInt(_keyMaxCompleted, levelNumber);
    }
  }

  /// Dev-cheat: bump [_keyMaxCompleted] so every level in [levels] is
  /// unlocked. Called from the 6-tap PiFlow-title easter egg on HomeScreen.
  /// Doesn't touch per-level stars/scores — the player still has to actually
  /// play each level to earn them.
  static Future<void> unlockAllLevels(int upToLevelNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_keyMaxCompleted) ?? 0;
    if (upToLevelNumber > current) {
      await prefs.setInt(_keyMaxCompleted, upToLevelNumber);
    }
  }

  /// Best stars stored for [levelNumber], 0..3. 0 = not completed.
  static Future<int> loadStars(int levelNumber) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyStars(levelNumber)) ?? 0;
  }

  /// Best score stored for [levelNumber]. 0 if never completed.
  static Future<int> loadScore(int levelNumber) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyScore(levelNumber)) ?? 0;
  }

  /// Save a result if it beats the stored one.
  /// Stars and score are ratcheted independently — each stays at its own best.
  static Future<void> saveResult({
    required int levelNumber,
    required int stars,
    required int score,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final oldStars = prefs.getInt(_keyStars(levelNumber)) ?? 0;
    if (stars > oldStars) {
      await prefs.setInt(_keyStars(levelNumber), stars);
    }
    final oldScore = prefs.getInt(_keyScore(levelNumber)) ?? 0;
    if (score > oldScore) {
      await prefs.setInt(_keyScore(levelNumber), score);
    }
  }

  /// Sum of best per-level scores + achievement-reward pot.
  static Future<int> totalScore() async {
    final prefs = await SharedPreferences.getInstance();
    var sum = 0;
    for (final k in prefs.getKeys()) {
      if (k.startsWith('piflow_score_L')) {
        sum += prefs.getInt(k) ?? 0;
      }
    }
    sum += prefs.getInt(_keyAchievementPot) ?? 0;
    return sum;
  }

  static const _keyAchievementPot = 'piflow_ach_score_pot';

  /// Add [amount] score won from an achievement unlock. Persists into
  /// [totalScore] via the achievement pot.
  static Future<void> awardBonusScore(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getInt(_keyAchievementPot) ?? 0;
    await prefs.setInt(_keyAchievementPot, old + amount);
  }

  /// Longest endless streak ever achieved (number of consecutive procedural
  /// levels beaten before losing).
  static const _keyEndlessBest = 'piflow_endless_best';

  static Future<int> loadEndlessBest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyEndlessBest) ?? 0;
  }

  static Future<void> saveEndlessStreak(int streak) async {
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getInt(_keyEndlessBest) ?? 0;
    if (streak > old) {
      await prefs.setInt(_keyEndlessBest, streak);
    }
  }

  // Daily challenge — one level per calendar day, seeded by the date so
  // every player sees the same board on the same day (great for gossip).
  static const _keyDailyLastDone = 'piflow_daily_last_done_ymd'; // "20260810"
  static const _keyDailyStreak = 'piflow_daily_streak';
  static const int dailyReward = 200;

  /// Compact date key (YYYYMMDD) for today, used as the seed and dedup key.
  static int todayYmd() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  /// True if the player has already completed today's daily challenge.
  static Future<bool> isDailyDoneToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyDailyLastDone) == todayYmd();
  }

  /// Mark today's daily as done and update the streak. Returns the new streak.
  /// If the last completion was NOT yesterday (gap > 1 day), the streak resets to 1.
  static Future<int> completeDailyToday() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_keyDailyLastDone) ?? 0;
    final today = todayYmd();
    if (last == today) return prefs.getInt(_keyDailyStreak) ?? 1;
    // Compute yesterday's ymd.
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yYmd = yesterday.year * 10000 + yesterday.month * 100 + yesterday.day;
    final newStreak = (last == yYmd) ? (prefs.getInt(_keyDailyStreak) ?? 0) + 1 : 1;
    await prefs.setInt(_keyDailyLastDone, today);
    await prefs.setInt(_keyDailyStreak, newStreak);
    await awardBonusScore(dailyReward);
    return newStreak;
  }

  static Future<int> loadDailyStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyDailyStreak) ?? 0;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    // Nuke everything piflow_* — cleaner than tracking each level individually.
    final keys = prefs.getKeys().where((k) => k.startsWith('piflow_')).toList();
    for (final k in keys) {
      // Keep audio prefs alive — those are user preference, not progress.
      if (k == 'piflow_sound_enabled' || k == 'piflow_music_enabled') continue;
      await prefs.remove(k);
    }
  }
}
