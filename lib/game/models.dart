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

/// Puzzle-mode mastery challenge — the "third star" of a level. Each level
/// declares zero or one challenge; the scorer evaluates it against
/// [ActualPlayStats]. Kept in models.dart (not scoring.dart) so LevelConfig
/// can hold it without creating a cyclic import.
enum MasteryKind {
  /// stats.unusedAmmo == 0 — every launched piggy emptied its ammo. Spare
  /// piggies left in the queue (never launched) do NOT count as waste.
  noWastedShots,
}

class MasteryChallenge {
  final MasteryKind kind;
  final String label;
  const MasteryChallenge({required this.kind, required this.label});

  static const noWastedShots = MasteryChallenge(
    kind: MasteryKind.noWastedShots,
    label: 'Без лишних выстрелов',
  );
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
  final PiggyColor? innerColor; // legacy: 2-state dual (outer→inner)
  /// N-state color-shift (2026-08-12). Each hit shifts to the next colour;
  /// the last state kills the block. When set, [hp] MUST equal states.length
  /// and [color] MUST equal states[0]. Ignores [innerColor].
  ///
  /// Example: `colorShiftStates: [yellow, orange, pink], hp: 3, color: yellow`
  ///   hit 1 (Y-piggy): sprite → orange, hp=2
  ///   hit 2 (O-piggy): sprite → pink, hp=1
  ///   hit 3 (P-piggy): dies
  final List<PiggyColor>? colorShiftStates;
  final bool isStone;
  final bool isPortal;
  /// Group id for portals — two BlockSpec.portal(id) instances with the same
  /// [portalPairId] form a two-way teleport pair. -1 for non-portals.
  final int portalPairId;

  const BlockSpec({
    this.color,
    this.hp = 1,
    this.innerColor,
    this.colorShiftStates,
  })  : isStone = false,
        isPortal = false,
        portalPairId = -1;

  const BlockSpec.stone()
      : color = null,
        hp = 1,
        innerColor = null,
        colorShiftStates = null,
        isStone = true,
        isPortal = false,
        portalPairId = -1;

  /// Portal blocks come in pairs: a ball entering one exits at the other.
  /// Non-destructible, transparent to counting/win-condition.
  const BlockSpec.portal(int pairId)
      : color = null,
        hp = 1,
        innerColor = null,
        colorShiftStates = null,
        isStone = false,
        isPortal = true,
        portalPairId = pairId;

  /// True for cells that stop the shot-line search cold (stone). Portal is
  /// intentionally NOT one of these — it's a teleport, not a wall.
  bool get blocksShotLine => isStone;

  /// The colour a piggy needs right now to hit this block.
  /// For color-shift blocks, indexed from states[]. For dual blocks whose
  /// outer layer is broken, this is [innerColor]. For stone/portal — null.
  PiggyColor? currentColor(int currentHp) {
    if (isStone || isPortal) return null;
    if (colorShiftStates != null) {
      // hp counts down from states.length → 1. State index = length - currentHp.
      final idx = colorShiftStates!.length - currentHp;
      if (idx < 0 || idx >= colorShiftStates!.length) return null;
      return colorShiftStates![idx];
    }
    if (innerColor != null && currentHp < hp) return innerColor;
    return color;
  }
}

/// One "bundle" in the puzzle-mode arsenal: N piggies of the same color, each
/// carrying [ammo] shots. The arsenal is a `List<PiggyBundle>` — order matters
/// only for the pre-level card display.
///
/// [type] defaults to normal. Set to a special (bomb/filter/rainbow/…) to
/// pre-load a special piggy into the puzzle inventory — the spawner will
/// hand it to the player at its FIFO turn instead of a plain colored piggy.
/// This is separate from combo-reward specials, which fire opportunistically.
class PiggyBundle {
  final PiggyColor color;
  final int ammo;
  final int count;
  final PiggyType type;
  const PiggyBundle({
    required this.color,
    this.ammo = 1,
    this.count = 1,
    this.type = PiggyType.normal,
  });

  int get shotPotential => ammo * count;
}

class LevelConfig {
  final int levelNumber;
  final List<List<BlockSpec?>> grid;

  // ── Puzzle-mode fields (2026-08-11 redesign) ─────────────────────────────
  // When [inventory] is non-null the level runs in puzzle mode: the arsenal
  // is pre-loaded into the queue/waiting slots and the RNG spawner is off.
  // When null the level falls back to the legacy weighted spawner (Endless
  // pre-migration + any level we haven't converted yet).

  final List<PiggyBundle>? inventory;

  /// Par — designer's target for launches. Perfect = launches ≤ par + perfectLaunchTolerance.
  final int? targetLaunches;

  /// ΣHP of all destructible blocks. Used as the denominator for the unused-
  /// ammo deviation. Auto-derived from [grid] when null.
  final int? targetHits;

  final int expectedCombos;

  /// launches ≤ par + softLaunchTolerance → insidePar checklist tick.
  final int softLaunchTolerance;

  /// launches > par + failLaunchOverflow → rank D. Set very high (e.g. 999)
  /// for tutorial levels where we don't want a hard fail.
  final int failLaunchOverflow;

  /// launches ≤ par + perfectLaunchTolerance → Perfect eligible.
  final int perfectLaunchTolerance;

  /// Puzzle-mode "third star". Null → no mastery challenge on this level.
  /// The scorer evaluates it against actual play stats and reports pass/fail
  /// in [LevelResult.masteryPassed] (nullable string label goes alongside).
  final MasteryChallenge? masteryChallenge;

  // ── Legacy fields (weighted spawner) ─────────────────────────────────────
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
    this.inventory,
    this.targetLaunches,
    this.targetHits,
    this.expectedCombos = 0,
    this.softLaunchTolerance = 2,
    this.failLaunchOverflow = 999,
    this.perfectLaunchTolerance = 0,
    this.masteryChallenge,
    this.ammoMin = 5,
    this.ammoMax = 25,
    this.spawnInterval = 0.9,
    this.queueSlots = 3,
    this.waitingSlots = 5,
    this.piggySpeed = 195,
    this.maxConveyorCapacity = 1,
    this.comboRewards = const [],
  });

  /// True when the level runs in puzzle mode (pre-loaded arsenal, no RNG
  /// spawner). Everything downstream keys off this.
  bool get isPuzzleMode => inventory != null;

  /// Sum of every piggy in the arsenal. Used for pre-level HUD, sizing the
  /// queue/waiting layout, and cost accounting.
  int get arsenalCount => inventory?.fold(0, (a, b) => a! + b.count) ?? 0;

  /// Sum of ammo across every piggy in the arsenal. Upper bound on total
  /// shots the player can fire this level.
  int get arsenalShotPotential =>
      inventory?.fold(0, (a, b) => a! + b.shotPotential) ?? 0;

  /// Unique colors present in the arsenal. NOT used as `allowedColors` in the
  /// scoring pipeline — that's [boardColors]. Kept for tooling / debug.
  Set<PiggyColor> get inventoryColors =>
      inventory?.map((b) => b.color).toSet() ?? const {};

  /// Colors present on the DESTRUCTIBLE board (excludes stone/portal).
  /// Includes dual-block innerColor. This is the puzzle's "required palette":
  ///  • extra colors used  = colorsUsed − boardColors  (dead-color piggies)
  ///  • missing colors     = boardColors − colorsUsed  (color left un-shot)
  /// A dead-color trap piggy is inventory ∖ boardColors: skipping it is
  /// CORRECT (no missing penalty); launching it triggers extraColors penalty.
  Set<PiggyColor> get boardColors {
    final s = <PiggyColor>{};
    for (final row in grid) {
      for (final cell in row) {
        if (cell == null || cell.isStone || cell.isPortal) continue;
        if (cell.color != null) s.add(cell.color!);
        if (cell.innerColor != null) s.add(cell.innerColor!);
        if (cell.colorShiftStates != null) s.addAll(cell.colorShiftStates!);
      }
    }
    return s;
  }

  /// ΣHP of all destructible blocks (stone/portal excluded). Falls back to
  /// grid inspection when [targetHits] is null — puzzle levels can just set
  /// grid + par and get targetHits for free.
  int get effectiveTargetHits {
    if (targetHits != null) return targetHits!;
    var sum = 0;
    for (final row in grid) {
      for (final c in row) {
        if (c != null && !c.isStone && !c.isPortal) sum += c.hp;
      }
    }
    return sum;
  }

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
