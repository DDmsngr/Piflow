import 'package:shared_preferences/shared_preferences.dart';

import 'progress.dart';

/// Static catalogue of achievements. Each carries a display name, description,
/// emoji icon, and a score reward that lands in the player's total on unlock.
///
/// Progress toward achievements is either boolean (unlocked / not) or a
/// counter that ratchets to a target. See [AchievementManager] for storage.
enum Achievement {
  // ── Progress ───────────────────────────────────────────────────────────
  firstSteps('first_steps', 'Первый шаг', 'Пройти L1', '👣', 50),
  clearPiggypark('clear_piggypark', 'Хозяин парка', 'Пройти все уровни PiggyPark', '🌿', 200),
  clearFactory('clear_factory', 'Заводчик', 'Пройти все уровни Factory', '⚡', 300),
  clearGallery('clear_gallery', 'Галерейщик', 'Пройти все уровни Gallery', '🎨', 400),
  clearFrozen('clear_frozen', 'Портальщик', 'Пройти все уровни Frozen', '❄', 500),

  // ── Skill ──────────────────────────────────────────────────────────────
  firstStar('first_star', 'Первая звезда', 'Заработать первую ★', '⭐', 30),
  first3Star('first_3star', 'Идеал', 'Первый 3★ проход', '💫', 100),
  perfectionist5('perfectionist_5', 'Перфекционист', '5 уровней с 3★', '🏆', 250),
  perfectionist15('perfectionist_15', 'Мастер', '15 уровней с 3★', '👑', 500),

  // ── Combo ──────────────────────────────────────────────────────────────
  firstCombo('first_combo', 'Комбо!', 'Первое комбо x5', '💥', 40),
  bigCombo('big_combo', 'Большое комбо', 'Комбо x8', '🔥', 150),
  megaCombo('mega_combo', 'Мега-комбо', 'Комбо x12', '⚡', 400),

  // ── Endless ────────────────────────────────────────────────────────────
  endless5('endless_5', 'Разогрев', 'Endless streak 5', '🎯', 100),
  endless10('endless_10', 'На волне', 'Endless streak 10', '🌊', 250),
  endless25('endless_25', 'Марафонец', 'Endless streak 25', '🏃', 600),
  endless50('endless_50', 'Легенда', 'Endless streak 50', '🌟', 1500),

  // ── Specials ───────────────────────────────────────────────────────────
  useBomb('use_bomb', 'Взрывник', 'Использовать бомбу', '💣', 40),
  useRainbow('use_rainbow', 'Радуга', 'Использовать радужную свинку', '🌈', 40),
  usePortal('use_portal', 'Телепортер', 'Использовать портал-свинку', '🌀', 40),
  useAllSpecials('use_all_specials', 'Коллекционер', 'Использовать все 13 спец-свинок', '🧩', 700);

  const Achievement(this.id, this.title, this.description, this.icon, this.reward);
  final String id;
  final String title;
  final String description;
  final String icon;
  final int reward;
}

/// Persistent state for unlocked achievements + newly unlocked events for UI.
class AchievementManager {
  static const _keyUnlocked = 'piflow_ach_unlocked';
  static const _keyCounter = 'piflow_ach_counter_';
  static const _keySpecialsUsed = 'piflow_ach_specials_used';

  static Future<Set<String>> loadUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyUnlocked)?.toSet() ?? <String>{};
  }

  static Future<bool> isUnlocked(Achievement a) async {
    final s = await loadUnlocked();
    return s.contains(a.id);
  }

  /// Attempt to unlock [a]. On first unlock: persists, awards score into the
  /// achievement-pot, and enqueues a toast for the UI to show. Returns true
  /// only when newly unlocked.
  static Future<bool> unlock(Achievement a) async {
    final prefs = await SharedPreferences.getInstance();
    final owned = prefs.getStringList(_keyUnlocked) ?? <String>[];
    if (owned.contains(a.id)) return false;
    owned.add(a.id);
    await prefs.setStringList(_keyUnlocked, owned);
    await Progress.awardBonusScore(a.reward);
    enqueueToast(a);
    return true;
  }

  /// Read a named counter (e.g. "3star_levels", "combos_over_8").
  static Future<int> getCounter(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyCounter$key') ?? 0;
  }

  /// Increment a named counter by [delta] (default 1) and return the new value.
  static Future<int> incCounter(String key, {int delta = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    final v = (prefs.getInt('$_keyCounter$key') ?? 0) + delta;
    await prefs.setInt('$_keyCounter$key', v);
    return v;
  }

  /// Track which special-piggy types have been used (for the "collect all" cheevo).
  /// Returns true if the set became complete (13 types) this call.
  static Future<bool> markSpecialUsed(String specialTypeName) async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getStringList(_keySpecialsUsed)?.toSet() ?? <String>{};
    if (used.contains(specialTypeName)) return false;
    used.add(specialTypeName);
    await prefs.setStringList(_keySpecialsUsed, used.toList());
    return used.length >= 13;
  }

  static Future<Set<String>> loadSpecialsUsed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keySpecialsUsed)?.toSet() ?? <String>{};
  }

  /// One-shot event queue: unlocked achievements waiting for UI to display
  /// as a snackbar. Producer (AchievementManager.unlock) appends; consumer
  /// (any screen) drains via [takePendingToasts].
  static final List<Achievement> _pendingToasts = [];

  static void enqueueToast(Achievement a) {
    _pendingToasts.add(a);
  }

  static List<Achievement> takePendingToasts() {
    final out = List<Achievement>.from(_pendingToasts);
    _pendingToasts.clear();
    return out;
  }
}
