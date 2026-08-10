import 'package:shared_preferences/shared_preferences.dart';

/// A cosmetic skin — rendered as an overlay accessory (hat / helmet / hoodie)
/// on top of the normal piggy sprite. Cheap on art: one PNG per skin covers
/// every colour. Zero gameplay impact.
enum SkinId {
  /// Sentinel — no skin applied, plain piggy.
  none('none', 'Обычная', '🐷', 0, 'Без аксессуара', hasArt: true),
  astronaut('astronaut', 'Космонавт', '🚀', 500,
      'Шлем астронавта — покорителя блоков.'),
  pirate('pirate', 'Пират', '🏴‍☠', 800,
      'Треуголка и повязка на глаз.'),
  hoodie('hoodie', 'Худи', '🧥', 1200,
      'Уличный капюшон.'),
  robot('robot', 'Робот', '🤖', 1800,
      'Антенна и красные линзы.'),
  donut('donut', 'Пончик', '🍩', 2500,
      'Сладкая корона.');

  final String id;
  final String displayName;
  final String emoji; // placeholder while dedicated art is pending
  final int price;
  final String description;
  /// True once real PNG art lives at assets/images/skin_<id>.png. Until then
  /// UI falls back to the emoji placeholder and the game skips the overlay.
  final bool hasArt;

  const SkinId(this.id, this.displayName, this.emoji, this.price, this.description,
      {this.hasArt = false});
}

/// Persistent skin state: what's owned, what's currently active.
class SkinManager {
  static const _keyOwned = 'piflow_skins_owned';
  static const _keyActive = 'piflow_skin_active';

  static Future<Set<SkinId>> loadOwned() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_keyOwned) ?? const [];
    final owned = <SkinId>{SkinId.none}; // "none" is always owned
    for (final id in ids) {
      final skin = _byId(id);
      if (skin != null) owned.add(skin);
    }
    return owned;
  }

  static Future<SkinId> loadActive() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_keyActive);
    return _byId(id ?? 'none') ?? SkinId.none;
  }

  static Future<void> setActive(SkinId skin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActive, skin.id);
  }

  /// Attempt to buy [skin]. Returns true on success (score deducted + saved).
  /// Deducts by writing a persistent "spent" counter used by [availableScore].
  static Future<bool> buy(SkinId skin, {required int currentScore}) async {
    if (skin == SkinId.none) return false;
    if (currentScore < skin.price) return false;
    final prefs = await SharedPreferences.getInstance();
    final owned = prefs.getStringList(_keyOwned) ?? <String>[];
    if (owned.contains(skin.id)) return false; // already owned
    owned.add(skin.id);
    await prefs.setStringList(_keyOwned, owned);
    final spent = prefs.getInt(_keySpent) ?? 0;
    await prefs.setInt(_keySpent, spent + skin.price);
    return true;
  }

  /// Score the player can still spend. Total earned minus total spent on skins.
  static Future<int> availableScore(int totalEarned) async {
    final prefs = await SharedPreferences.getInstance();
    final spent = prefs.getInt(_keySpent) ?? 0;
    return (totalEarned - spent).clamp(0, 1 << 30);
  }

  static const _keySpent = 'piflow_skins_spent';

  static SkinId? _byId(String id) {
    for (final s in SkinId.values) {
      if (s.id == id) return s;
    }
    return null;
  }
}
