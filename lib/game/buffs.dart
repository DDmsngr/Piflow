import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Магазин продаёт **заряды** супер-пигов. Каждая покупка добавляет 1 заряд
/// к соответствующему типу. Купленные заряды копятся в inventory внизу
/// game screen — player сам решает когда пустить супер-пигу в бой (tap на
/// иконку → piggy сразу спавнится на belt в текущем уровне, счётчик −1).
class PiggyBuff {
  final PiggyType type;
  final String displayName;
  final String description;
  final int price;
  final int ammo; // сколько выстрелов у супер-пиги
  final PiggyColor tintColor; // цвет тела (косметически)
  final String spriteAsset; // соответствует piggy_<type>.png

  const PiggyBuff({
    required this.type,
    required this.displayName,
    required this.description,
    required this.price,
    required this.ammo,
    required this.tintColor,
    required this.spriteAsset,
  });
}

/// Каталог доступных супер-пигов. Порядок = вид в магазине и на HUD.
const List<PiggyBuff> allBuffs = [
  PiggyBuff(
    type: PiggyType.bomb,
    displayName: 'Свинка-Бомба',
    description: 'Взрывает область 3×3.',
    price: 500,
    ammo: 1,
    tintColor: PiggyColor.pink,
    spriteAsset: 'piggy_bomb.png',
  ),
  PiggyBuff(
    type: PiggyType.chaos,
    displayName: 'Свинка-Хаос',
    description: 'Полностью перемешивает поле!',
    price: 700,
    ammo: 1,
    tintColor: PiggyColor.purple,
    spriteAsset: 'piggy_chaos.png',
  ),
  PiggyBuff(
    type: PiggyType.freeze,
    displayName: 'Свинка-Заморозка',
    description: 'Блоки не двигаются! Даёт время подумать.',
    price: 900,
    ammo: 3,
    tintColor: PiggyColor.cyan,
    spriteAsset: 'piggy_freeze.png',
  ),
  PiggyBuff(
    type: PiggyType.duplicator,
    displayName: 'Свинка-Дубликатор',
    description: 'Копирует цвет в соседние клетки!',
    price: 1200,
    ammo: 1,
    tintColor: PiggyColor.cyan,
    spriteAsset: 'piggy_duplicator.png',
  ),
  PiggyBuff(
    type: PiggyType.sweeper,
    displayName: 'Свинка-Свайпер',
    description: 'Удаляет весь ряд или колонку!',
    price: 1400,
    ammo: 1,
    tintColor: PiggyColor.pink,
    spriteAsset: 'piggy_sweeper.png',
  ),
  PiggyBuff(
    type: PiggyType.filter,
    displayName: 'Свинка-Фильтр',
    description: 'Ломает камни-стены (stones).',
    price: 1500,
    ammo: 4,
    tintColor: PiggyColor.green,
    spriteAsset: 'piggy_filter.png',
  ),
  PiggyBuff(
    type: PiggyType.painter,
    displayName: 'Свинка-Краска',
    description: 'Перекрашивает область в один цвет!',
    price: 1800,
    ammo: 1,
    tintColor: PiggyColor.yellow,
    spriteAsset: 'piggy_painter.png',
  ),
  PiggyBuff(
    type: PiggyType.converter,
    displayName: 'Свинка-Конвертер',
    description: 'Перекрашивает все блоки поля.',
    price: 2200,
    ammo: 1,
    tintColor: PiggyColor.cyan,
    spriteAsset: 'piggy_converter.png',
  ),
  PiggyBuff(
    type: PiggyType.chain,
    displayName: 'Свинка-Цепная',
    description: 'Цепная реакция по одному цвету!',
    price: 2500,
    ammo: 1,
    tintColor: PiggyColor.yellow,
    spriteAsset: 'piggy_chain.png',
  ),
  PiggyBuff(
    type: PiggyType.rainbow,
    displayName: 'Свинка-Радуга',
    description: 'Уничтожает блоки выбранного цвета!',
    price: 3200,
    ammo: 1,
    tintColor: PiggyColor.pink,
    spriteAsset: 'piggy_rainbow.png',
  ),
  PiggyBuff(
    type: PiggyType.jackpot,
    displayName: 'Свинка-Джекпот',
    description: '50/50 — очистить всё поле или ничего.',
    price: 4000,
    ammo: 1,
    tintColor: PiggyColor.yellow,
    spriteAsset: 'piggy_jackpot.png',
  ),
];

/// Персистент. Каждый buff-тип хранит счётчик зарядов (int в prefs).
/// Ключ: `piflow_buff_charge_<type.name>` → количество доступных зарядов.
class BuffManager {
  static const _keyPrefix = 'piflow_buff_charge_';
  static const _keySpent = 'piflow_buffs_spent';

  static Future<Map<PiggyType, int>> loadCharges() async {
    final prefs = await SharedPreferences.getInstance();
    final out = <PiggyType, int>{};
    for (final buff in allBuffs) {
      final n = prefs.getInt('$_keyPrefix${buff.type.name}') ?? 0;
      if (n > 0) out[buff.type] = n;
    }
    return out;
  }

  static Future<int> chargesOf(PiggyType type) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyPrefix${type.name}') ?? 0;
  }

  /// Купить 1 заряд — deduct цену + charges[type] += 1.
  /// Возвращает true если куплено.
  static Future<bool> buy(PiggyBuff buff, {required int currentScore}) async {
    if (currentScore < buff.price) return false;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix${buff.type.name}';
    final have = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, have + 1);
    final spent = prefs.getInt(_keySpent) ?? 0;
    await prefs.setInt(_keySpent, spent + buff.price);
    return true;
  }

  /// Списать 1 заряд (при tap на HUD-иконку → send piggy to belt).
  /// Возвращает true если заряд был и списан; false если 0.
  static Future<bool> useCharge(PiggyType type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix${type.name}';
    final have = prefs.getInt(key) ?? 0;
    if (have <= 0) return false;
    await prefs.setInt(key, have - 1);
    return true;
  }

  /// Score the player can still spend. Total earned minus buffs spent.
  static Future<int> availableScore(int totalEarned) async {
    final prefs = await SharedPreferences.getInstance();
    final spent = prefs.getInt(_keySpent) ?? 0;
    return (totalEarned - spent).clamp(0, 1 << 30);
  }

  /// Meta for buff by type.
  static PiggyBuff? buffFor(PiggyType? type) {
    if (type == null) return null;
    for (final b in allBuffs) {
      if (b.type == type) return b;
    }
    return null;
  }
}
