import 'package:flutter/material.dart';

import 'difficulty.dart';

enum PiggyColor {
  pink(Color(0xFFFF6BAA), 'pink'),
  cyan(Color(0xFF5AC8FA), 'cyan'),
  yellow(Color(0xFFFFD338), 'yellow'),
  green(Color(0xFF6ECF3A), 'green'),
  purple(Color(0xFFB76BFF), 'purple'),
  orange(Color(0xFFFF9438), 'orange');

  final Color color;
  final String name;
  const PiggyColor(this.color, this.name);
}

/// Type governs the piggy's shot behaviour.
enum PiggyType {
  normal(null, 'Обычная', 'Стреляет по кубикам своего цвета.'),
  rainbow('piggy_rainbow.png', 'Радуга',
      'Уничтожает все блоки выбранного цвета!'),
  bomb('piggy_bomb.png', 'Бомба', 'Взрывает область 3×3.'),
  painter('piggy_painter.png', 'Краска',
      'Перекрашивает область в один цвет.'),
  converter('piggy_converter.png', 'Конвертер',
      'Превращает все блоки в 2–3 случайных цвета.'),
  chain('piggy_chain.png', 'Цепная',
      'Запускает цепную реакцию по цветам!'),
  duplicator('piggy_duplicator.png', 'Дубликатор',
      'Копирует цвет в соседние клетки.'),
  freeze('piggy_freeze.png', 'Заморозка',
      'Блоки не двигаются. Даёт время подумать.'),
  sweeper('piggy_sweeper.png', 'Свайпер',
      'Удаляет весь ряд или колонку.'),
  filter('piggy_filter.png', 'Фильтр',
      'Удаляет только серые блоки-мусор.'),
  chaos('piggy_chaos.png', 'Хаос', 'Полностью перемешивает поле!'),
  jackpot('piggy_jackpot.png', 'Джекпот',
      'Шанс: очистить всё поле… или ничего не сделать!'),
  universal('piggy_universal.png', 'Универсал',
      'Делает выбранный цвет универсальным!'),
  portal('piggy_portal.png', 'Портал',
      'Открывает временный портал и телепортирует шар в случайный блок.'),

  /// Legacy alias kept for old comboRewards; behaves like [filter].
  breaker('piggy_filter.png', 'Разрушитель',
      'Разрушает каменные блоки.');

  final String? spriteAsset;
  final String displayName;
  final String description;
  const PiggyType(this.spriteAsset, this.displayName, this.description);

  bool get isSpecial => this != PiggyType.normal;
}

/// A single cell on the board.
///
/// - normal:  `BlockSpec(color: X)` — 1 hit of colour X kills it.
/// - armored: `BlockSpec(color: X, hp: N)` — N hits of colour X kill it,
///            crack overlay grows with each hit.
/// - dual:    `BlockSpec(color: outer, hp: 2, innerColor: inner)` — first hit
///            (of outer colour) exposes an inner colour; the block then reads
///            as `innerColor` for shot-targeting/spawn-weighting.
/// - stone:   `BlockSpec.stone()` — non-destructible; blocks the shot line
///            for every colour. Never counted as a "remaining" objective.
/// - portal:  `BlockSpec.portal(pairId)` — non-destructible teleport. Balls
///            entering the block exit at the paired block (same pairId).
///            Doesn't block the shot line, doesn't count towards winning.
class BlockSpec {
  final PiggyColor? color;      // null iff stone/portal
  final int hp;
  final PiggyColor? innerColor; // exposed after hp drops below max
  final bool isStone;
  final bool isPortal;
  /// Group id for portals — two BlockSpec.portal(id) instances with the same
  /// [portalPairId] form a two-way teleport pair. -1 for non-portals.
  final int portalPairId;

  const BlockSpec({
    this.color,
    this.hp = 1,
    this.innerColor,
  })  : isStone = false,
        isPortal = false,
        portalPairId = -1;

  const BlockSpec.stone()
      : color = null,
        hp = 1,
        innerColor = null,
        isStone = true,
        isPortal = false,
        portalPairId = -1;

  /// Portal blocks come in pairs: a ball entering one exits at the other.
  /// Non-destructible, transparent to counting/win-condition.
  const BlockSpec.portal(int pairId)
      : color = null,
        hp = 1,
        innerColor = null,
        isStone = false,
        isPortal = true,
        portalPairId = pairId;

  /// True for cells that stop the shot-line search cold (stone). Portal is
  /// intentionally NOT one of these — it's a teleport, not a wall.
  bool get blocksShotLine => isStone;

  /// The colour a piggy needs right now to hit this block.
  /// For dual blocks whose outer layer is broken, this is [innerColor].
  /// For stone/portal — null (cannot be shot).
  PiggyColor? currentColor(int currentHp) {
    if (isStone || isPortal) return null;
    if (innerColor != null && currentHp < hp) return innerColor;
    return color;
  }
}

class LevelConfig {
  final int levelNumber;
  final List<List<BlockSpec?>> grid;
  final List<PiggyColor> spawnPalette;
  final int ammoMin;
  final int ammoMax;
  final double spawnInterval;
  final int queueSlots;
  final int waitingSlots;
  final double piggySpeed;
  final int maxConveyorCapacity;
  /// Special piggy types that may be awarded on a 5+ combo. Empty = no
  /// rewards (level plays with normal piggies only).
  final List<PiggyType> comboRewards;

  const LevelConfig({
    required this.levelNumber,
    required this.grid,
    required this.spawnPalette,
    this.ammoMin = 5,
    this.ammoMax = 25,
    this.spawnInterval = 0.9,
    this.queueSlots = 3,
    this.waitingSlots = 5,
    this.piggySpeed = 195,
    this.maxConveyorCapacity = 1,
    this.comboRewards = const [],
  });

  /// Preferred constructor for new levels: pulls speed/ammo/interval/rewards
  /// from [LevelDifficulty] using the level's position inside its world.
  /// Any override supplied here wins over the computed default.
  ///
  /// Note: this is a factory, not a const constructor — level lists get
  /// evaluated once at startup so runtime interpolation is fine.
  factory LevelConfig.forSlot({
    required int levelNumber,
    required String worldId,
    required int indexInWorld,
    required int worldLength,
    required List<List<BlockSpec?>> grid,
    required List<PiggyColor> spawnPalette,
    List<PiggyType>? comboRewards,
    // Optional overrides — leave null to accept the difficulty curve.
    double? piggySpeed,
    int? ammoMin,
    int? ammoMax,
    double? spawnInterval,
    int? queueSlots,
    int? waitingSlots,
    int? maxConveyorCapacity,
  }) {
    final params = LevelDifficulty.paramsFor(
      worldId: worldId,
      indexInWorld: indexInWorld,
      worldLength: worldLength,
    );
    return LevelConfig(
      levelNumber: levelNumber,
      grid: grid,
      spawnPalette: spawnPalette,
      piggySpeed: piggySpeed ?? params.piggySpeed,
      ammoMin: ammoMin ?? params.ammoMin,
      ammoMax: ammoMax ?? params.ammoMax,
      spawnInterval: spawnInterval ?? params.spawnInterval,
      queueSlots: queueSlots ?? 3,
      waitingSlots: waitingSlots ?? 5,
      maxConveyorCapacity: maxConveyorCapacity ?? 1,
      comboRewards: comboRewards ??
          LevelDifficulty.rewardsFor(
            worldId: worldId,
            indexInWorld: indexInWorld,
            worldLength: worldLength,
          ),
    );
  }

  int get rows => grid.length;
  int get cols => grid.isEmpty ? 0 : grid[0].length;

  /// Only blocks that must be destroyed to win — stone AND portal are
  /// excluded (they can't be shot).
  int get totalBlocks {
    var count = 0;
    for (final row in grid) {
      for (final c in row) {
        if (c != null && !c.isStone && !c.isPortal) count++;
      }
    }
    return count;
  }
}
