import 'package:flutter/material.dart';

import 'models.dart';
import 'shape_levels.dart';

/// A themed group of levels shown as a "world" section on HomeScreen.
/// Each world has its own visual identity (name, emoji, colour) and covers
/// a contiguous range of level numbers.
@immutable
class WorldConfig {
  const WorldConfig({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.firstLevel,
    required this.lastLevel,
    this.comingSoon = false,
    this.tagline,
  });

  final String id;
  final String name;
  final String emoji;
  final Color color;
  final int firstLevel;
  final int lastLevel;
  final bool comingSoon;
  final String? tagline;

  bool contains(int levelNumber) =>
      levelNumber >= firstLevel && levelNumber <= lastLevel;
}

/// Ordered list of worlds. Add new worlds by appending here — HomeScreen
/// renders them in this order.
const List<WorldConfig> worlds = [
  WorldConfig(
    id: 'piggypark',
    name: 'PiggyPark',
    emoji: '🌿',
    color: Color(0xFF6ECF3A),
    firstLevel: 1,
    lastLevel: 5,
    tagline: 'Основы',
  ),
  WorldConfig(
    id: 'factory',
    name: 'Factory',
    emoji: '⚡',
    color: Color(0xFFFF9438),
    firstLevel: 6,
    lastLevel: 10,
    tagline: 'Броня, камень, двухцветные',
  ),
  WorldConfig(
    id: 'gallery',
    name: 'Gallery',
    emoji: '🎨',
    color: Color(0xFFB76BFF),
    firstLevel: 11,
    lastLevel: 15,
    tagline: 'Фигуры и картинки',
  ),
  WorldConfig(
    id: 'frozen',
    name: 'Frozen',
    emoji: '❄',
    color: Color(0xFF5AC8FA),
    firstLevel: 16,
    lastLevel: 20,
    tagline: 'Порталы',
  ),
  WorldConfig(
    id: 'neon',
    name: 'Neon Lab',
    emoji: '🧪',
    color: Color(0xFFFF3B93),
    firstLevel: 21,
    lastLevel: 30,
    tagline: 'Спец-пиги: бомбы и реакции',
  ),
  WorldConfig(
    id: 'gridlab',
    name: 'Grid Lab',
    emoji: '🌌',
    color: Color(0xFF6C4CFF),
    firstLevel: 31,
    lastLevel: 45,
    tagline: 'Огромные поля, всё сразу',
  ),
];

/// Look up which world a level belongs to. Returns the first matching world
/// or null (shouldn't happen for any level in [levels]).
WorldConfig? worldOf(int levelNumber) {
  for (final w in worlds) {
    if (w.contains(levelNumber)) return w;
  }
  return null;
}

// Normal 1-hp blocks (short single-letter aliases for readability).
const _p = BlockSpec(color: PiggyColor.pink);
const _c = BlockSpec(color: PiggyColor.cyan);
const _y = BlockSpec(color: PiggyColor.yellow);
const _g = BlockSpec(color: PiggyColor.green);
const _v = BlockSpec(color: PiggyColor.purple);
const _o = BlockSpec(color: PiggyColor.orange);

// Armored 2-hp blocks (need two hits of the same colour).
const _p2 = BlockSpec(color: PiggyColor.pink, hp: 2);
const _c2 = BlockSpec(color: PiggyColor.cyan, hp: 2);
const _y2 = BlockSpec(color: PiggyColor.yellow, hp: 2);
const _g2 = BlockSpec(color: PiggyColor.green, hp: 2);
const _v2 = BlockSpec(color: PiggyColor.purple, hp: 2);

// Dual-colour blocks: outer → inner (2 hp, second hit needs innerColor piggy).
const _pc = BlockSpec(color: PiggyColor.pink,   hp: 2, innerColor: PiggyColor.cyan);
const _cp = BlockSpec(color: PiggyColor.cyan,   hp: 2, innerColor: PiggyColor.pink);
const _yg = BlockSpec(color: PiggyColor.yellow, hp: 2, innerColor: PiggyColor.green);
const _gy = BlockSpec(color: PiggyColor.green,  hp: 2, innerColor: PiggyColor.yellow);
const _vo = BlockSpec(color: PiggyColor.purple, hp: 2, innerColor: PiggyColor.orange);
const _ov = BlockSpec(color: PiggyColor.orange, hp: 2, innerColor: PiggyColor.purple);

// Stone — unbreakable, blocks any shot line.
// ignore: constant_identifier_names
const _S = BlockSpec.stone();

// Portal pairs. Two cells with the same pairId form a teleport.
// ignore: constant_identifier_names
const _PA = BlockSpec.portal(0); // pair A
// ignore: constant_identifier_names
const _PB = BlockSpec.portal(1); // pair B
// ignore: constant_identifier_names
const _PC = BlockSpec.portal(2); // pair C

// Color-shift blocks (3-state, hp=3). Each hit shifts to next state.
//   _shiftYOP: yellow → orange → pink (gradient «раскалённая»)
// ignore: constant_identifier_names
const _shiftYOP = BlockSpec(
  color: PiggyColor.yellow,
  hp: 3,
  colorShiftStates: [PiggyColor.yellow, PiggyColor.orange, PiggyColor.pink],
);

// Empty cell (shot flies through, no block).
const BlockSpec? _e = null;

// World sizes drive the difficulty interpolation. Keep in sync with the
// number of LevelConfig.forSlot calls per world below. PiggyPark (L1-L5)
// no longer uses forSlot — they're handcrafted puzzles.
const _factoryLen = 5;
const _galleryLen = 5;
const _frozenLen = 5;

final List<LevelConfig> levels = [
  // =========================================================================
  // 🌿 PIGGYPARK  L1-L5 — handcrafted PUZZLE tutorials (2026-08-11 redesign)
  //
  // Design contract (agreed with Aleksey):
  //   • Pre-loaded arsenal, no RNG spawner.
  //   • ammo per piggy = blocks that piggy is meant to break by design.
  //   • Slack = spare PIGGIES in inventory, not spare ammo on a piggy.
  //     (Auto-fire wastes leftover ammo → tighter design.)
  //   • Campaign has no hard fail: failLaunchOverflow = 999 for all 5.
  //     Drama comes from rank / Perfect / SS, not death screens.
  //   • Progressive disclosure: L1 shows only launches bar; L2 adds Ammo;
  //     L3 adds Colors; L4 highlights over-par; L5 shows full checklist +
  //     Perfect badge. (Enforced in the result overlay UI, not here.)
  // =========================================================================

  // L1 — «Запуск и par». Три Y в вертикальной колонке. 3 launches × ammo=1.
  //       Никаких промахов, никакой возможности проигрыша. Онбординг.
  LevelConfig(
    levelNumber: 1,
    grid: [
      [_e, _e, _e, _e, _e],
      [_e, _e, _y, _e, _e],
      [_e, _e, _y, _e, _e],
      [_e, _e, _y, _e, _e],
      [_e, _e, _e, _e, _e],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.yellow, ammo: 1, count: 3),
    ],
    targetLaunches: 3,
    // targetHits auto-derived from grid → 3.
    spawnPalette: const [PiggyColor.yellow],
    piggySpeed: 240,
    spawnInterval: 0.9,
  ),

  // L2 — «Выстрелы оцениваются». Квадрат 2×2, арсенал 6 (маржа +2 свинки).
  //       Игрок жгущий все 6 → 2 unused ammo → полоска Ammo впервые в дело.
  LevelConfig(
    levelNumber: 2,
    grid: [
      [_e, _e, _e, _e, _e],
      [_e, _e, _y, _y, _e],
      [_e, _e, _y, _y, _e],
      [_e, _e, _e, _e, _e],
      [_e, _e, _e, _e, _e],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.yellow, ammo: 1, count: 6),
    ],
    targetLaunches: 4,
    spawnPalette: const [PiggyColor.yellow],
    piggySpeed: 260,
    spawnInterval: 0.85,
  ),

  // L3 — «Читай набор». Ряд синих + ряд оранжевых. В арсенале — мёртвый
  //       зелёный (2 шт). Запустил зелёного → +1 wasted ammo + потраченный
  //       launch. Perfect = вообще не запускать зелёных.
  LevelConfig(
    levelNumber: 3,
    grid: [
      [_e, _e, _e, _e, _e],
      [_e, _c, _c, _c, _e],
      [_e, _e, _e, _e, _e],
      [_e, _o, _o, _o, _e],
      [_e, _e, _e, _e, _e],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 1, count: 3),
      PiggyBundle(color: PiggyColor.orange, ammo: 1, count: 3),
      PiggyBundle(color: PiggyColor.green,  ammo: 1, count: 2), // мёртвый цвет
    ],
    targetLaunches: 6,
    spawnPalette: const [PiggyColor.cyan, PiggyColor.orange, PiggyColor.green],
    piggySpeed: 280,
    spawnInterval: 0.8,
  ),

  // L4 — «Эффективность». 4 пары (одна колонка, 2 блока) + 2 armored.
  //       6 свинок × ammo=2 = 12 shots = ΣHP exact. Perfect чист.
  //       Каждая свинка бьёт 2 блока за 2 круга belt-а.
  LevelConfig(
    levelNumber: 4,
    grid: [
      [_y,  _e,  _e,  _g,  _e],
      [_y,  _e,  _e,  _g,  _e],
      [_c,  _e,  _e,  _v,  _e],
      [_c,  _e,  _e,  _v,  _e],
      [_e,  _y2, _v2, _e,  _e],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.yellow, ammo: 2, count: 2), // одна на пару, одна на armored
      PiggyBundle(color: PiggyColor.cyan,   ammo: 2, count: 1),
      PiggyBundle(color: PiggyColor.green,  ammo: 2, count: 1),
      PiggyBundle(color: PiggyColor.purple, ammo: 2, count: 2), // одна на пару, одна на armored
    ],
    targetLaunches: 6,
    expectedCombos: 1,
    spawnPalette: const [
      PiggyColor.yellow, PiggyColor.cyan, PiggyColor.green, PiggyColor.purple,
    ],
    piggySpeed: 300,
    spawnInterval: 0.75,
  ),

  // L5 — «Первый Perfect». Пять изолированных блоков, каждый уникального
  //       цвета и доступен с одной стороны (кроме центра O — виден со всех
  //       сторон, но заслонён другими блоками; должен идти последним).
  //       Арсенал: 5 цветных ammo=1 + 1 spare Y. Perfect = не тронуть spare.
  LevelConfig(
    levelNumber: 5,
    grid: [
      [_e, _e, _y, _e, _e],
      [_e, _e, _e, _e, _e],
      [_g, _e, _o, _e, _v],
      [_e, _e, _e, _e, _e],
      [_e, _e, _c, _e, _e],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.yellow, ammo: 1, count: 2), // 1 боевая + 1 spare
      PiggyBundle(color: PiggyColor.cyan,   ammo: 1, count: 1),
      PiggyBundle(color: PiggyColor.green,  ammo: 1, count: 1),
      PiggyBundle(color: PiggyColor.purple, ammo: 1, count: 1),
      PiggyBundle(color: PiggyColor.orange, ammo: 1, count: 1),
    ],
    targetLaunches: 5,
    perfectLaunchTolerance: 0, // exact par для SS
    spawnPalette: const [
      PiggyColor.yellow, PiggyColor.cyan, PiggyColor.green,
      PiggyColor.purple, PiggyColor.orange,
    ],
    piggySpeed: 320,
    spawnInterval: 0.7,
  ),

  // =========================================================================
  // ⚡ FACTORY  L6-L10 — armored, stone, dual
  // =========================================================================

  // L6 — ⚙ ШЕСТЕРЁНКА (Factory-1 icon). Pixel-art pilot v3 — 4 цвета, слои.
  //
  //   Grid 12×12: 88 блоков, четыре цветовых слоя (снаружи внутрь):
  //     Y = 52  внешние зубцы + верх/низ обода     («латунь»)
  //     O = 16  внутренний боковой обод            («раскалённый металл»)
  //     C = 16  плазма-ядро                        (энерго-core)
  //     V =  4  центральная ось 2×2                (axle)
  //
  //   Depth-механика (4 слоя!):
  //     Y снаружи закрывает O → C → V. Каждый слой стреляем только когда
  //     предыдущий убран. Purple ammo=4 запущенный первым = 4 unused ammo,
  //     mastery fail. Игрок УЧИТСЯ порядку: Y → O → C → V.
  //
  //   Inventory (10 свинок):
  //     Y × 4 ammo=13 → 52 exact  (внешний корпус)
  //     O × 2 ammo=8  → 16 exact  (второй слой)
  //     C × 2 ammo=8  → 16 exact  (ядро)
  //     V × 1 ammo=4  →  4 exact  (axle, последней)
  //     Y × 1 ammo=3  →  3 spare  (маленькое ammo = глаз ловит «лишняя»)
  //     ─────────────────────────
  //     ShotBudget = 91, S = 88, ShotMargin = 3
  //
  //   Par: 9 launches (skip spare Y).
  //   Perfect / Mastery (noWastedShots): 9 launches, unusedAmmo=0.
  //   FIFO ставит Y первыми (4 подряд), затем O/C чередуются, V перед spare.
  LevelConfig(
    levelNumber: 6,
    grid: [
      [_e, _e, _e, _e, _y, _y, _y, _y, _e, _e, _e, _e],
      [_e, _e, _e, _y, _y, _y, _y, _y, _y, _e, _e, _e],
      [_e, _y, _e, _y, _y, _y, _y, _y, _y, _e, _y, _e],
      [_y, _y, _y, _y, _e, _e, _e, _e, _y, _y, _y, _y],
      [_o, _o, _e, _e, _c, _c, _c, _c, _e, _e, _o, _o],
      [_o, _o, _e, _c, _c, _v, _v, _c, _c, _e, _o, _o],
      [_o, _o, _e, _c, _c, _v, _v, _c, _c, _e, _o, _o],
      [_o, _o, _e, _e, _c, _c, _c, _c, _e, _e, _o, _o],
      [_y, _y, _y, _y, _e, _e, _e, _e, _y, _y, _y, _y],
      [_e, _y, _e, _y, _y, _y, _y, _y, _y, _e, _y, _e],
      [_e, _e, _e, _y, _y, _y, _y, _y, _y, _e, _e, _e],
      [_e, _e, _e, _e, _y, _y, _y, _y, _e, _e, _e, _e],
    ],
    inventory: const [
      // 4 Y-heavy first — снять внешний корпус (52 shots exact).
      PiggyBundle(color: PiggyColor.yellow, ammo: 13), // 1
      PiggyBundle(color: PiggyColor.yellow, ammo: 13), // 2
      PiggyBundle(color: PiggyColor.yellow, ammo: 13), // 3
      PiggyBundle(color: PiggyColor.yellow, ammo: 13), // 4
      // Второй слой + ядро чередуются — O/C доступны когда Y снят.
      PiggyBundle(color: PiggyColor.orange, ammo:  8), // 5 — O layer
      PiggyBundle(color: PiggyColor.cyan,   ammo:  8), // 6 — C core
      PiggyBundle(color: PiggyColor.orange, ammo:  8), // 7 — O layer
      PiggyBundle(color: PiggyColor.cyan,   ammo:  8), // 8 — C core
      // Axle — последняя, доступна когда C убран.
      PiggyBundle(color: PiggyColor.purple, ammo:  4), // 9 — V axle
      // Spare — не запускать, mastery ловит.
      PiggyBundle(color: PiggyColor.yellow, ammo:  3), // 10 — SPARE
    ],
    targetLaunches: 9,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.yellow, PiggyColor.orange,
      PiggyColor.cyan, PiggyColor.purple,
    ],
    piggySpeed: 380,
    spawnInterval: 0.9,
  ),

  // L7 — ⚒ МОЛОТ v2 (Factory-2). Pixel-art, 5 цветов, слоистая depth.
  //   НОВОЕ: ARMOR (HP=2 через C2), DEAD-COLOR TRAP (Purple не на поле).
  //
  //   Grid 12×12: 80 blocks + 4 armored = 80 destructible.
  //     Голова = 4 концентрических слоя:
  //       G  = 30  outer shell (green metal)
  //       O  = 20  second layer (orange heat glow)
  //       P  =  8  third layer (pink hot core)
  //       C2 =  4  armored plasma центр (2 shots каждый)
  //     Ручка:
  //       Y  = 14  handle grip
  //     Colors on board: G, O, P, C, Y (5 ✓)
  //
  //   Shot hits: 30 + 20 + 8 + 8 + 14 = 80.
  //
  //   Inventory (9 piggies, LIVE-margin = 0):
  //     G × 3 ammo=10 → 30 exact
  //     O × 2 ammo=10 → 20 exact
  //     P × 1 ammo=8  →  8 exact
  //     C × 1 ammo=8  →  8 exact (кроет C2 = 4×2)
  //     Y × 1 ammo=14 → 14 exact
  //     V × 1 ammo=6  →  6 DEAD-COLOR TRAP (Purple не на поле)
  //     ─────────────────────────
  //     Live budget = 80 = S exact. Trap adds 6 = 86 total.
  //
  //   Par: 8 launches (skip V trap).
  //   Depth: G→O→P→C2 (глубина 4 слоя в голове) + Y handle сразу с боков/низа.
  //   Traps: 1 dead-color V. Launched → +6 unusedAmmo + extraColors={V} penalty.
  LevelConfig(
    levelNumber: 7,
    grid: [
      [_e, _e, _g, _g, _g, _g, _g, _g, _g, _g, _e, _e],
      [_e, _e, _g, _g, _o, _o, _o, _o, _g, _g, _e, _e],
      [_e, _e, _g, _o, _o, _p, _p, _o, _o, _g, _e, _e],
      [_e, _e, _g, _o, _p, _c2,_c2,_p, _o, _g, _e, _e],
      [_e, _e, _g, _o, _p, _c2,_c2,_p, _o, _g, _e, _e],
      [_e, _e, _g, _o, _o, _p, _p, _o, _o, _g, _e, _e],
      [_e, _e, _g, _g, _o, _o, _o, _o, _g, _g, _e, _e],
      [_e, _e, _e, _g, _g, _g, _g, _g, _g, _e, _e, _e],
      [_e, _e, _e, _e, _e, _y, _y, _e, _e, _e, _e, _e],
      [_e, _e, _e, _e, _e, _y, _y, _e, _e, _e, _e, _e],
      [_e, _e, _e, _e, _y, _y, _y, _y, _e, _e, _e, _e],
      [_e, _e, _e, _y, _y, _y, _y, _y, _y, _e, _e, _e],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.green,  ammo: 10), // 1 — outer shell
      PiggyBundle(color: PiggyColor.green,  ammo: 10), // 2 — outer shell
      PiggyBundle(color: PiggyColor.green,  ammo: 10), // 3 — outer shell (30 exact)
      PiggyBundle(color: PiggyColor.orange, ammo: 10), // 4 — 2nd layer
      PiggyBundle(color: PiggyColor.orange, ammo: 10), // 5 — 2nd layer (20 exact)
      PiggyBundle(color: PiggyColor.pink,   ammo:  8), // 6 — 3rd layer (8 exact)
      PiggyBundle(color: PiggyColor.cyan,   ammo:  8), // 7 — plasma core armor (8 exact)
      PiggyBundle(color: PiggyColor.yellow, ammo: 14), // 8 — handle (14 exact)
      PiggyBundle(color: PiggyColor.purple, ammo:  6), // 9 — TRAP: Purple не на поле
    ],
    targetLaunches: 8,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.green, PiggyColor.orange, PiggyColor.pink,
      PiggyColor.cyan, PiggyColor.yellow, PiggyColor.purple,
    ],
    piggySpeed: 400,
    spawnInterval: 0.87,
  ),

  // L8 — 🔋 БАТАРЕЯ v2 (Factory-3). 5 цветов, armored axle, 2 trap-свинки.
  //
  //   Grid 12×12: 84 destructible + 4 armored inside.
  //     Y  = 20  оба терминала (top cap 10 + bottom cap 10)
  //     G  = 28  battery case (обод)
  //     O  = 20  insulation ring (между case и core)
  //     C  = 12  outer charge cells
  //     V2 =  4  armored central axle (2 shots each = 8 V-shots)
  //     Colors on board: Y, G, O, C, V (5 ✓)
  //
  //   Shot hits: 20 + 28 + 20 + 12 + 8 = 88.
  //
  //   Inventory (11 piggies, LIVE-margin = 0, ДВА traps):
  //     Y × 2 ammo=10       → 20 exact
  //     G × 2 ammo=10 + 1×8 → 28 exact
  //     O × 2 ammo=10       → 20 exact
  //     C × 1 ammo=12       → 12 exact
  //     V × 1 ammo=8        →  8 exact (armor axle)
  //     P × 1 ammo=6        →  TRAP 1: Pink не на поле (dead-color)
  //     Y × 1 ammo=3        →  TRAP 2: excess Y spare (мелкое ammo)
  //     ─────────────────────────
  //     Live = 88 = S. Traps = 9. Total budget 97.
  //
  //   Par: 9 launches (skip both traps).
  //   Depth: 5 слоёв — Y cap (top+bottom) → G case → O insulation → C core → V axle.
  //   Traps: P dead-color (identifiable by цвет) + Y-spare (identifiable by
  //     маленькое ammo=3 vs Y-heavy=10). Пропустить оба → SS + mastery.
  LevelConfig(
    levelNumber: 8,
    grid: [
      [_e, _e, _e, _e, _y, _y, _y, _y, _e, _e, _e, _e],
      [_e, _e, _e, _y, _y, _y, _y, _y, _y, _e, _e, _e],
      [_e, _e, _g, _g, _g, _g, _g, _g, _g, _g, _e, _e],
      [_e, _e, _g, _o, _o, _o, _o, _o, _o, _g, _e, _e],
      [_e, _e, _g, _o, _c, _c, _c, _c, _o, _g, _e, _e],
      [_e, _e, _g, _o, _c, _v2,_v2,_c, _o, _g, _e, _e],
      [_e, _e, _g, _o, _c, _v2,_v2,_c, _o, _g, _e, _e],
      [_e, _e, _g, _o, _c, _c, _c, _c, _o, _g, _e, _e],
      [_e, _e, _g, _o, _o, _o, _o, _o, _o, _g, _e, _e],
      [_e, _e, _g, _g, _g, _g, _g, _g, _g, _g, _e, _e],
      [_e, _e, _e, _y, _y, _y, _y, _y, _y, _e, _e, _e],
      [_e, _e, _e, _e, _y, _y, _y, _y, _e, _e, _e, _e],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.yellow, ammo: 10), // 1 — top cap
      PiggyBundle(color: PiggyColor.yellow, ammo: 10), // 2 — bottom cap (20 exact)
      PiggyBundle(color: PiggyColor.green,  ammo: 10), // 3 — case
      PiggyBundle(color: PiggyColor.green,  ammo: 10), // 4 — case
      PiggyBundle(color: PiggyColor.green,  ammo:  8), // 5 — case (28 exact)
      PiggyBundle(color: PiggyColor.orange, ammo: 10), // 6 — insulation
      PiggyBundle(color: PiggyColor.orange, ammo: 10), // 7 — insulation (20 exact)
      PiggyBundle(color: PiggyColor.cyan,   ammo: 12), // 8 — outer core (12 exact)
      PiggyBundle(color: PiggyColor.purple, ammo:  8), // 9 — armor axle (8 exact)
      PiggyBundle(color: PiggyColor.pink,   ammo:  6), // 10 — TRAP: Pink not on board
      PiggyBundle(color: PiggyColor.yellow, ammo:  3), // 11 — TRAP: excess Y spare
    ],
    targetLaunches: 9,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.yellow, PiggyColor.green, PiggyColor.orange,
      PiggyColor.cyan, PiggyColor.purple, PiggyColor.pink,
    ],
    piggySpeed: 420,
    spawnInterval: 0.85,
  ),

  // L9 — 🔧 ГАЕЧНЫЙ КЛЮЧ v2 (Factory-4). 5 цветов + STONE + armor + 2 traps.
  //
  //   Grid 12×12: 74 destructible + 8 stones (не counted).
  //     G  = 32  outer head + shoulders
  //     O  = 16  neck & shoulder accent (orange grip transition)
  //     P2 =  4  armored jaw tips (2 shots each = 8 P-shots) — стиснуты болтом
  //     Y  = 16  handle body
  //     C  =  6  grip texture in handle (rubber highlights)
  //     S  =  8  stone «болт» in opening — блокирует line-shots
  //     Colors on board: G, O, P, Y, C (5 ✓)
  //
  //   Shot hits: 32 + 16 + 8 + 16 + 6 = 78.
  //
  //   Inventory (11 piggies, LIVE-margin = 0, ДВА traps):
  //     G × 2 ammo=10 + 1×12 → 32 exact
  //     O × 2 ammo=8         → 16 exact
  //     P × 1 ammo=8         →  8 exact (crack + kill armored jaws)
  //     Y × 2 ammo=8         → 16 exact
  //     C × 1 ammo=6         →  6 exact
  //     V × 1 ammo=6         →  TRAP 1: Purple не на поле
  //     G × 1 ammo=3         →  TRAP 2: excess G spare
  //     ─────────────────────────
  //     Live budget = 78 = S exact. Traps = 9.
  //
  //   Par: 9 launches (skip both traps).
  //   Depth: stone «болт» в opening → P2 armored jaws доступны только с
  //     ТОРЦОВ head (не через opening). Игрок УЧИТ обходить stone-линии,
  //     стрелять P только с левой/правой стороны конвейера.
  //   Traps: V dead-color + G-spare (маленькое ammo = визуальный сигнал).
  LevelConfig(
    levelNumber: 9,
    grid: [
      [_e, _e, _e, _g, _g, _g, _g, _g, _g, _e, _e, _e],
      [_e, _e, _g, _g, _o, _o, _o, _o, _g, _g, _e, _e],
      [_e, _g, _g, _o, _e, _e, _e, _e, _o, _g, _g, _e],
      [_e, _g, _o, _p2,_S, _S, _S, _S, _p2,_o, _g, _e],
      [_e, _g, _o, _p2,_S, _S, _S, _S, _p2,_o, _g, _e],
      [_e, _g, _g, _o, _e, _e, _e, _e, _o, _g, _g, _e],
      [_e, _e, _g, _g, _o, _o, _o, _o, _g, _g, _e, _e],
      [_e, _e, _e, _g, _g, _g, _g, _g, _g, _e, _e, _e],
      [_e, _e, _e, _e, _y, _y, _y, _y, _e, _e, _e, _e],
      [_e, _e, _e, _y, _y, _c, _c, _y, _y, _e, _e, _e],
      [_e, _e, _e, _y, _c, _c, _c, _c, _y, _e, _e, _e],
      [_e, _e, _e, _y, _y, _y, _y, _y, _y, _e, _e, _e],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.green,  ammo: 10), // 1 — head
      PiggyBundle(color: PiggyColor.green,  ammo: 10), // 2 — head
      PiggyBundle(color: PiggyColor.green,  ammo: 12), // 3 — head (32 exact)
      PiggyBundle(color: PiggyColor.orange, ammo:  8), // 4 — neck accent
      PiggyBundle(color: PiggyColor.orange, ammo:  8), // 5 — neck (16 exact)
      PiggyBundle(color: PiggyColor.pink,   ammo:  8), // 6 — armored jaws (8 exact)
      PiggyBundle(color: PiggyColor.yellow, ammo:  8), // 7 — handle
      PiggyBundle(color: PiggyColor.yellow, ammo:  8), // 8 — handle (16 exact)
      PiggyBundle(color: PiggyColor.cyan,   ammo:  6), // 9 — grip (6 exact)
      PiggyBundle(color: PiggyColor.purple, ammo:  6), // 10 — TRAP: Purple not on board
      PiggyBundle(color: PiggyColor.green,  ammo:  3), // 11 — TRAP: excess G spare
    ],
    targetLaunches: 9,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.green, PiggyColor.orange, PiggyColor.pink,
      PiggyColor.yellow, PiggyColor.cyan, PiggyColor.purple,
    ],
    piggySpeed: 440,
    spawnInterval: 0.82,
  ),

  // L10 — 🤖 РОБОТ BOSS (Factory-5). ВВОДИТ COMBO-REWARD-PUZZLE.
  //
  //   Двухфазная головоломка:
  //     ФАЗА 1 (combo setup): игрок клинит overhead-цвета (P/Y/C/O) на cols
  //       2-9, чтобы обнажить row 4 = 8 G подряд.
  //     ФАЗА 2 (combo trigger): G-piggy на top belt пролетает над 8 exposed
  //       green блоками → 8 pops за ~0.4с → combo ≥5 → filter reward spawns.
  //     ФАЗА 3 (chamber open): filter piggy ломает stones вокруг chamber.
  //     ФАЗА 4 (finish): Y-piggies (с сохранённой ammo) добивают 3 yellow
  //       cores внутри chamber + все остальные G.
  //
  //   Grid 12×12: 45 destructible + 8 stones (chamber trap).
  //     Y  = 11  head 4 + eyes 4 + chamber cores 3
  //     P  =  4  temples r1-r2 (cols 2, 9)
  //     C  =  2  brow eyes r2 (cols 5, 6)
  //     O  =  8  brow band r3 (6) + waist r8 (2 — breaks chest pillar!)
  //     G  = 20  combo strip row 4 (8) + chest pillars (8) + legs/arms/feet (4)
  //     S  =  8  chamber trap (3 top-cap + 2 sides + 3 bottom-cap)
  //     Colors on board: Y, P, C, O, G (5 ✓)
  //
  //   ⚠ IMPORTANT: waist O на r8 нужен чтобы прервать G-пилары cols 2, 9.
  //     Без него cols 2, 9 имели бы 6 G подряд вертикально → второй
  //     combo-путь через left/right belt. С waist O на r8: max vertical G
  //     contig = 4 (r4-r7). Combo возможно ТОЛЬКО через row 4 top belt.
  //
  //   Inventory (11 piggies + 1 dynamic filter reward):
  //     P × 1 ammo=4     →  4 exact  (temples)
  //     Y × 2 ammo=6+5   → 11 exact  (outside + wait for chamber)
  //     C × 1 ammo=2     →  2 exact  (eyes)
  //     O × 2 ammo=4     →  8 exact  (brow + waist)
  //     G × 3 ammo=7+7+6 → 20 exact  (7 обеспечивает combo на row 4)
  //     V × 1 ammo=6     →  TRAP 1: Purple dead-color
  //     Y × 1 ammo=3     →  TRAP 2: excess Y spare
  //     + Filter reward (dynamic RNG 3-8 shots on stones). Chamber 8 stones
  //       total = max filter ammo → всегда 0 unusedAmmo для filter.
  //     ─────────────────────────
  //     Live S = 45. Par = 10 launches (9 live + 1 filter reward).
  //
  //   comboRewards: [filter] only. Единственный тип награды — stone-breaker.
  //   Mastery: noWastedShots — если trap запущен ИЛИ combo не сработало
  //     (тогда filter не спавнится, chamber остаётся закрытым, level не clear).
  //   L10 v3 — 🤖 РОБОТ BOSS (2026-08-19 clean pixel-art + varied ammo 2-25).
  //   Голова G с C-глазами и O-ртом + P-руки + V-worm в chest chamber + Y-ноги.
  //
  //   Grid 12×12: 86 destructible + 10 stones (chest chamber).
  //     G  = 58  голова + шея + плечи + тело + нижняя часть
  //     C  =  8  глаза (2×2 клетки)
  //     O  =  4  рот
  //     P  = 10  руки (torch cols 0-1, 10-11)
  //     V  =  2  worm в chest chamber
  //     Y  =  4  ноги (2 пары)
  //     S  = 10  chamber walls (4 top-cap + 2 sides + 4 bottom-cap)
  //     Colors on board: G, C, O, P, V, Y = 6 ✓
  //
  //   Inventory (12 pigs + 1 filter reward) — varied ammo 2..25:
  //     G × 4: 25+18+10+5 = 58
  //     C × 2: 5+3 = 8
  //     O × 1: 4
  //     P × 2: 7+3 = 10
  //     V × 1: 2
  //     Y × 1: 4
  //     G × 1 ammo=6 — TRAP: excess G spare
  //   Live S=86. Par: 11 launches (10 live + 1 filter reward, skip 1 trap).
  //   Combo triggers naturally on rows 1/4/6/10 (8G contig each). Cooldown
  //   8s blocks extra filter rewards.
  LevelConfig(
    levelNumber: 10,
    grid: [
      [_e, _e, _g, _g, _g, _g, _g, _g, _g, _g, _e, _e], // head top (8G)
      [_e, _e, _g, _c, _c, _g, _g, _c, _c, _g, _e, _e], // eyes (4G+4C)
      [_e, _e, _g, _c, _c, _g, _g, _c, _c, _g, _e, _e], // eyes (4G+4C)
      [_e, _e, _g, _g, _g, _g, _g, _g, _g, _g, _e, _e], // head (8G)
      [_e, _e, _g, _g, _o, _o, _o, _o, _g, _g, _e, _e], // mouth (4G+4O)
      [_e, _e, _g, _g, _g, _g, _g, _g, _g, _g, _e, _e], // head bottom (8G)
      [_p, _p, _g, _g, _g, _g, _g, _g, _g, _g, _p, _p], // shoulders (4P+8G)
      [_p, _p, _g, _e, _S, _S, _S, _S, _e, _g, _p, _p], // top-cap chamber (4P+2G+4S)
      [_p, _e, _g, _e, _S, _v, _v, _S, _e, _g, _e, _p], // chamber middle (2P+2G+2V+2S)
      [_e, _e, _g, _e, _S, _S, _S, _S, _e, _g, _e, _e], // bottom-cap (2G+4S)
      [_e, _e, _g, _g, _g, _g, _g, _g, _g, _g, _e, _e], // body bottom (8G)
      [_e, _e, _y, _y, _e, _e, _e, _e, _y, _y, _e, _e], // feet (4Y)
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.green,  ammo: 25), // 1 — HUGE G (combo trigger)
      PiggyBundle(color: PiggyColor.green,  ammo: 18), // 2 — G heavy
      PiggyBundle(color: PiggyColor.green,  ammo: 10), // 3 — G medium
      PiggyBundle(color: PiggyColor.green,  ammo:  5), // 4 — G small (58 exact)
      PiggyBundle(color: PiggyColor.cyan,   ammo:  5), // 5 — eyes big
      PiggyBundle(color: PiggyColor.cyan,   ammo:  3), // 6 — eyes small (8 exact)
      PiggyBundle(color: PiggyColor.orange, ammo:  4), // 7 — mouth (4 exact)
      PiggyBundle(color: PiggyColor.pink,   ammo:  7), // 8 — arms big
      PiggyBundle(color: PiggyColor.pink,   ammo:  3), // 9 — arms small (10 exact)
      PiggyBundle(color: PiggyColor.purple, ammo:  2), // 10 — worm (after filter)
      PiggyBundle(color: PiggyColor.yellow, ammo:  4), // 11 — feet (4 exact)
      PiggyBundle(color: PiggyColor.green,  ammo:  6), // 12 — TRAP: excess G spare
    ],
    comboRewards: const [PiggyType.filter],
    targetLaunches: 11,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    expectedCombos: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.green, PiggyColor.cyan, PiggyColor.orange,
      PiggyColor.pink, PiggyColor.purple, PiggyColor.yellow,
    ],
    piggySpeed: 450,
    spawnInterval: 0.8,
  ),

  // =========================================================================
  // 🎨 GALLERY  L11-L15 — pixel-art shapes с накопительными механиками
  // =========================================================================

  // L11 — 🏠 ДОМИК v2. ВВОДИТ DUAL-COLOR (окна pink→cyan через _pc).
  //
  //   Grid 12×12: 89 destructible + 12 stones (foundation, декор).
  //     Y  =  5   солнце над крышей (5 pixel-art)
  //     O  = 36   крыша (пирамида)
  //     P  = 38   стены (walls)
  //     Dual =  8 окна _pc (pink→cyan, hp=2, требуют 1 P + 1 C)
  //     G  =  2   дверь
  //     S  = 12   фундамент (нижняя строка stones — декор, не блокирует)
  //     Colors on board: Y (солнце), O, P (walls+dual outer), C (dual inner), G = 5 ✓
  //
  //   Shot hits: Y=5, O=36, P=38+8(dual outer)=46, C=8(dual inner), G=2. Σ=97
  //
  //   Inventory (12 piggies, LIVE-margin = 0, ДВА traps):
  //     Y × 1 ammo=5       →  5 exact (солнце)
  //     O × 3 ammo=12      → 36 exact (крыша)
  //     P × 4 ammo=11+11+12+12 → 46 exact (walls + dual outer crack)
  //     C × 1 ammo=8       →  8 exact (dual inner)
  //     G × 1 ammo=2       →  2 exact (дверь)
  //     V × 1 ammo=6       →  TRAP 1: Purple не на поле
  //     Y × 1 ammo=3       →  TRAP 2: excess Y spare
  //
  //   Par: 10 launches (skip 2 traps).
  //   Depth: sun → roof (top) → walls → duals (after P крак) → doors.
  //     Duals hp=2: P-piggy кракает outer, C-piggy добивает inner.
  //     Если C запущена ДО P → 8 ammo впустую → mastery fail.
  LevelConfig(
    levelNumber: 11,
    grid: [
      [_e, _e, _e, _e, _e, _y, _e, _e, _e, _e, _e, _e],
      [_e, _e, _e, _e, _y, _y, _y, _e, _e, _e, _e, _e],
      [_e, _e, _e, _e, _e, _y, _e, _e, _e, _e, _e, _e],
      [_e, _e, _e, _o, _o, _o, _o, _o, _o, _e, _e, _e],
      [_e, _e, _o, _o, _o, _o, _o, _o, _o, _o, _e, _e],
      [_e, _o, _o, _o, _o, _o, _o, _o, _o, _o, _o, _e],
      [_o, _o, _o, _o, _o, _o, _o, _o, _o, _o, _o, _o],
      [_p, _p, _p, _p, _p, _p, _p, _p, _p, _p, _p, _p],
      [_p, _pc, _pc, _p, _p, _p, _p, _p, _p, _pc, _pc, _p],
      [_p, _pc, _pc, _p, _p, _p, _p, _p, _p, _pc, _pc, _p],
      [_p, _p, _p, _p, _p, _g, _g, _p, _p, _p, _p, _p],
      [_S, _S, _S, _S, _S, _S, _S, _S, _S, _S, _S, _S],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.yellow, ammo:  5), // 1 — sun (5 exact)
      PiggyBundle(color: PiggyColor.orange, ammo: 22), // 2 — roof heavy
      PiggyBundle(color: PiggyColor.orange, ammo:  8), // 3 — roof mid
      PiggyBundle(color: PiggyColor.orange, ammo:  6), // 4 — roof small (36 exact)
      PiggyBundle(color: PiggyColor.pink,   ammo: 22), // 5 — walls heavy
      PiggyBundle(color: PiggyColor.pink,   ammo: 13), // 6 — walls
      PiggyBundle(color: PiggyColor.pink,   ammo:  8), // 7 — walls
      PiggyBundle(color: PiggyColor.pink,   ammo:  3), // 8 — walls small (46 exact, кракает dual outer)
      PiggyBundle(color: PiggyColor.cyan,   ammo:  8), // 9 — dual inner (8 exact)
      PiggyBundle(color: PiggyColor.green,  ammo:  2), // 10 — door (2 exact)
      PiggyBundle(color: PiggyColor.purple, ammo:  4), // 11 — TRAP: Purple dead-color
      PiggyBundle(color: PiggyColor.yellow, ammo:  3), // 12 — TRAP: excess Y spare
    ],
    targetLaunches: 10,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.yellow, PiggyColor.orange, PiggyColor.pink,
      PiggyColor.cyan, PiggyColor.green, PiggyColor.purple,
    ],
    piggySpeed: 450,
    spawnInterval: 0.85,
  ),

  // L12 — 🍄 МУХОМОР v2. Combo-puzzle со HIDDEN WORM (V) в шапке.
  //
  //   Grid 12×12: 83 destructible + 8 stones (chamber trap для worm).
  //     P  = 48  шапка гриба (mushroom cap)
  //     C  = 12  spot-accents на шапке (белые точки как в мухоморе)
  //     S  =  8  chamber walls (worm skрытая внутри cap)
  //     V  =  3  worm (purple, скрыта в chamber)
  //     Y  =  8  ножка (stem)
  //     G  = 12  трава (grass)
  //     Colors on board: P, C, V, Y, G = 5 ✓
  //
  //   Shot hits: P=48, C=12, V=3, Y=8, G=12. Σ=83
  //
  //   Combo triggering: row 1 (8 P contig c2-c9) + row 7 (mirror). Первая
  //     P-piggy на top belt → 5+ pops на row 0-1 → combo → filter reward.
  //     Cooldown 8с блокирует лишние combos от последующих P-piggies.
  //
  //   Inventory (12 piggies, LIVE-margin = 0):
  //     P × 4 ammo=12       → 48 exact (шапка + trigger combo)
  //     C × 2 ammo=6        → 12 exact (spot-accents)
  //     V × 1 ammo=3        →  3 exact (worm — только после filter)
  //     Y × 1 ammo=8        →  8 exact (ножка)
  //     G × 2 ammo=6        → 12 exact (трава)
  //     O × 1 ammo=6        →  TRAP 1: Orange не на поле
  //     P × 1 ammo=3        →  TRAP 2: excess P spare
  //     + Filter reward (RNG 3-8): всегда exhausts (chamber ≥ 8 stones).
  //
  //   Par: 11 launches (10 live + 1 filter, skip 2 traps).
  //   Depth: overhead (P+C) → combo → filter → chamber → worm V.
  LevelConfig(
    levelNumber: 12,
    grid: [
      [_e, _e, _e, _e, _p, _p, _p, _p, _e, _e, _e, _e],
      [_e, _e, _p, _p, _p, _p, _p, _p, _p, _p, _e, _e],
      [_e, _p, _p, _p, _c, _c, _c, _c, _p, _p, _p, _e],
      [_e, _p, _p, _c, _S, _S, _S, _c, _p, _p, _e, _e],
      [_e, _p, _p, _S, _v, _v, _v, _S, _p, _p, _e, _e],
      [_e, _p, _p, _c, _S, _S, _S, _c, _p, _p, _e, _e],
      [_e, _p, _p, _p, _c, _c, _c, _c, _p, _p, _p, _e],
      [_e, _e, _p, _p, _p, _p, _p, _p, _p, _p, _e, _e],
      [_e, _e, _e, _e, _p, _p, _p, _p, _e, _e, _e, _e],
      [_e, _e, _e, _e, _y, _y, _y, _y, _e, _e, _e, _e],
      [_e, _e, _e, _e, _y, _y, _y, _y, _e, _e, _e, _e],
      [_g, _g, _g, _g, _g, _g, _g, _g, _g, _g, _g, _g],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.pink,   ammo: 22), // 1 — cap + COMBO trigger (heavy)
      PiggyBundle(color: PiggyColor.pink,   ammo: 13), // 2 — cap
      PiggyBundle(color: PiggyColor.pink,   ammo:  8), // 3 — cap
      PiggyBundle(color: PiggyColor.pink,   ammo:  5), // 4 — cap small (48 exact)
      PiggyBundle(color: PiggyColor.cyan,   ammo:  9), // 5 — spot accents heavy
      PiggyBundle(color: PiggyColor.cyan,   ammo:  3), // 6 — spot accents small (12 exact)
      PiggyBundle(color: PiggyColor.purple, ammo:  3), // 7 — WORM (after filter)
      PiggyBundle(color: PiggyColor.yellow, ammo:  8), // 8 — stem (8 exact)
      PiggyBundle(color: PiggyColor.green,  ammo:  8), // 9 — grass heavy
      PiggyBundle(color: PiggyColor.green,  ammo:  4), // 10 — grass small (12 exact)
      PiggyBundle(color: PiggyColor.orange, ammo:  5), // 11 — TRAP: Orange dead-color
      PiggyBundle(color: PiggyColor.pink,   ammo:  3), // 12 — TRAP: excess P spare
    ],
    comboRewards: const [PiggyType.filter],
    targetLaunches: 11, // 10 live + 1 filter reward, skip 2 traps
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    expectedCombos: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.pink, PiggyColor.cyan, PiggyColor.purple,
      PiggyColor.yellow, PiggyColor.green, PiggyColor.orange,
    ],
    piggySpeed: 470,
    spawnInterval: 0.82,
  ),

  // L13 v5 — ❤ СЕРДЦЕ / ЧЕРЕП (13×13 pattern A, dual + 1 shift, safety-margin).
  //
  //   Grid 13×13: пирамидальная верхушка → solid → две hollow-впадины
  //   («глазницы») → tapered низ → 2×2 зелёная ножка. Aleksey заметил
  //   что читается как череп — оставляем как есть.
  //
  //   Cells: 124 P + 2 dual (_yg) + 1 shift (_shiftYOP) + 4 G = 131 blocks.
  //     Dual в row 3 col 4, col 8 (симметрично).
  //     Shift в row 4 col 6 (центр, не одна колонка с dual — иначе shift
  //     блокирует line-of-sight к dual, и уровень становится order-lock'ом
  //     с высокими требованиями по waiting-slot микроменеджменту).
  //
  //   Shot hits per color:
  //     P = 124 + 1 (shift state 2 = P) = 125
  //     Y = 2 (dual outer) + 1 (shift state 0 = Y) = 3
  //     G = 4 (ножка) + 2 (dual inner) = 6
  //     O = 1 (shift state 1 = O)
  //   Total S = 135.
  //
  //   ORDER: 5 P (early clean-up вокруг shift/dual) → Y → O → P
  //   (shift state 2 закрывается + чистые P) → G (dual inner когда outer
  //   уже кракнут) → P (остаток). Player паркует Y в waiting, ждёт пока
  //   P расчистит line-of-sight к dual.
  //
  //   SAFETY: Y и G с +1 ammo (4 и 7 вместо 3 и 6 exact). Даёт запас на
  //   1 miss каждого цвета, mastery `noWastedShots` тогда 2★ вместо 3★.
  //   С fix currentColor-бага (учитывает _plannedHits) player теоретически
  //   может 3★, но UX-safety защищает от малейшего mis-tap.
  //
  //   Inventory (12 pigs, live-margin = 2):
  //     P × 5 (early): 25+22+20+18+16 = 101
  //     Y × 1 ammo=4  (safety +1)
  //     O × 1 ammo=1  (exact)
  //     P × 1 ammo=12 (shift state 2 + чистые)
  //     G × 1 ammo=7  (safety +1)
  //     P × 1 ammo=12 (остальные чистые P; P sum = 125 exact)
  //     C × 1 ammo=6  — TRAP: Cyan dead-color
  //     P × 1 ammo=5  — TRAP: excess P spare
  //   Par: 10 launches (skip 2 traps), 1 combo ожидается.
  LevelConfig(
    levelNumber: 13,
    grid: [
      // Row 0: 9 P
      [_e, _e, _p, _p, _p, _p, _p, _p, _p, _p, _p, _e, _e],
      // Row 1: 11 P
      [_e, _p, _p, _p, _p, _p, _p, _p, _p, _p, _p, _p, _e],
      // Row 2: 13 P (solid)
      [_p, _p, _p, _p, _p, _p, _p, _p, _p, _p, _p, _p, _p],
      // Row 3: 11 P + 2 dual (col 4, col 8)
      [_p, _p, _p, _p, _yg, _p, _p, _p, _yg, _p, _p, _p, _p],
      // Row 4: 12 P + 1 shift (col 6 — центр, отдельно от dual columns)
      [_p, _p, _p, _p, _p, _p, _shiftYOP, _p, _p, _p, _p, _p, _p],
      // Row 5: 9 P (hollows start)
      [_p, _p, _p, _e, _e, _p, _p, _p, _e, _e, _p, _p, _p],
      // Row 6: 7 P (hollows wide)
      [_p, _p, _e, _e, _e, _p, _p, _p, _e, _e, _e, _p, _p],
      // Row 7: 7 P
      [_p, _p, _e, _e, _e, _p, _p, _p, _e, _e, _e, _p, _p],
      // Row 8: 9 P (hollows close)
      [_p, _p, _p, _e, _e, _p, _p, _p, _e, _e, _p, _p, _p],
      // Row 9: 13 P (solid)
      [_p, _p, _p, _p, _p, _p, _p, _p, _p, _p, _p, _p, _p],
      // Row 10: 11 P (taper)
      [_e, _p, _p, _p, _p, _p, _p, _p, _p, _p, _p, _p, _e],
      // Row 11: 6 P + 2 G (ножка старт)
      [_e, _e, _p, _p, _p, _g, _g, _p, _p, _p, _e, _e, _e],
      // Row 12: 6 P + 2 G (ножка конец)
      [_e, _e, _p, _p, _p, _g, _g, _p, _p, _p, _e, _e, _e],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.pink,   ammo: 25), // 1 — HUGE P (combo trigger)
      PiggyBundle(color: PiggyColor.pink,   ammo: 22), // 2 — P heavy
      PiggyBundle(color: PiggyColor.pink,   ammo: 20), // 3 — P heavy
      PiggyBundle(color: PiggyColor.pink,   ammo: 18), // 4 — P medium
      PiggyBundle(color: PiggyColor.pink,   ammo: 16), // 5 — P medium (early P = 101)
      PiggyBundle(color: PiggyColor.yellow, ammo:  4), // 6 — dual outer + shift Y (safety +1)
      PiggyBundle(color: PiggyColor.orange, ammo:  1), // 7 — shift state 1 (exact)
      PiggyBundle(color: PiggyColor.pink,   ammo: 12), // 8 — shift state 2 + чистые P
      PiggyBundle(color: PiggyColor.green,  ammo:  7), // 9 — G-ножка + dual inner (safety +1)
      PiggyBundle(color: PiggyColor.pink,   ammo: 12), // 10 — остаток P (sum = 125 exact)
      PiggyBundle(color: PiggyColor.cyan,   ammo:  6), // 11 — TRAP: Cyan dead-color
      PiggyBundle(color: PiggyColor.pink,   ammo:  5), // 12 — TRAP: excess P spare
    ],
    targetLaunches: 10, // 10 live, skip 2 traps
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    expectedCombos: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.pink, PiggyColor.yellow, PiggyColor.green,
      PiggyColor.orange, PiggyColor.cyan,
    ],
    piggySpeed: 480,
    spawnInterval: 0.8,
  ),

  // L14 v3 — ⭐ ЗВЕЗДА (2026-08-19 чистый 5-конечник + varied ammo + shift).
  //   Классическая пятиконечная звезда: острие вверх, крылья по бокам,
  //   2 ноги вниз. Shift-точки на кончиках лучей.
  //
  //   Grid 12×12: 58 destructible + 5 shift blocks.
  //     Y  = 50  тело звезды (non-shift)
  //     G  =  4  green core (центр)
  //     V  =  2  purple accents (shoulders)
  //     C  =  2  cyan spot (nose)
  //     ColorShift(Y→O→P) × 5 (top tip + 2 arm-corners + 2 leg-tips)
  //     Shot hits:
  //       Y: 50 + 5 (shift state 1) = 55
  //       O: 5 (shift state 2)
  //       P: 5 (shift state 3)
  //       G: 4, V: 2, C: 2
  //     Colors on board: Y, O, P, G, V, C = 6 ✓
  //   Total S = 73.
  //
  //   Inventory (9 pigs) — varied ammo 2..25:
  //     Y × 3: 25+18+12 = 55
  //     O × 1: 5, P × 1: 5, G × 1: 4, V × 1: 2, C × 1: 2
  //     Y × 1 ammo=3 — TRAP: excess Y spare
  //   Par: 8 launches (skip 1 trap).
  LevelConfig(
    levelNumber: 14,
    grid: [
      [_e, _e, _e, _e, _e, _shiftYOP, _e, _e, _e, _e, _e, _e], // top tip (1 shift)
      [_e, _e, _e, _e, _y, _y, _y, _y, _e, _e, _e, _e], // 4Y
      [_e, _e, _e, _e, _y, _y, _y, _y, _e, _e, _e, _e], // 4Y
      [_shiftYOP, _y, _y, _y, _y, _y, _y, _y, _y, _y, _y, _shiftYOP], // arm-corners + 10Y
      [_e, _y, _y, _y, _y, _g, _g, _y, _y, _y, _y, _e], // arms + green core (8Y+2G)
      [_e, _e, _y, _y, _v, _g, _g, _v, _y, _y, _e, _e], // shoulders + core (4Y+2V+2G)
      [_e, _e, _e, _y, _y, _c, _c, _y, _y, _e, _e, _e], // nose + C (4Y+2C)
      [_e, _e, _y, _y, _y, _e, _e, _y, _y, _y, _e, _e], // legs split (6Y)
      [_e, _y, _y, _y, _e, _e, _e, _e, _y, _y, _y, _e], // legs spread (6Y)
      [_e, _y, _y, _e, _e, _e, _e, _e, _e, _y, _y, _e], // legs (4Y)
      [_shiftYOP, _e, _e, _e, _e, _e, _e, _e, _e, _e, _e, _shiftYOP], // leg-tips (2 shift)
      [_e, _e, _e, _e, _e, _e, _e, _e, _e, _e, _e, _e],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.yellow, ammo: 25), // 1 — HUGE Y (combo trigger)
      PiggyBundle(color: PiggyColor.yellow, ammo: 18), // 2 — Y heavy
      PiggyBundle(color: PiggyColor.yellow, ammo: 12), // 3 — Y medium (55 exact)
      PiggyBundle(color: PiggyColor.orange, ammo:  5), // 4 — shift O (5 exact)
      PiggyBundle(color: PiggyColor.pink,   ammo:  5), // 5 — shift P (5 exact)
      PiggyBundle(color: PiggyColor.green,  ammo:  4), // 6 — core (4 exact)
      PiggyBundle(color: PiggyColor.purple, ammo:  2), // 7 — shoulders (2 exact)
      PiggyBundle(color: PiggyColor.cyan,   ammo:  2), // 8 — nose (2 exact)
      PiggyBundle(color: PiggyColor.yellow, ammo:  3), // 9 — TRAP: excess Y
    ],
    targetLaunches: 8,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.yellow, PiggyColor.orange, PiggyColor.pink,
      PiggyColor.green, PiggyColor.purple, PiggyColor.cyan,
    ],
    piggySpeed: 490,
    spawnInterval: 0.8,
  ),

  // L15 — 🐟 РЫБА BOSS (Gallery-5). ВСЁ СРАЗУ:
  //   dual (L11) + combo+chamber (L12) + color-shift (L14) + 6 colors + trap.
  //
  //   Grid 12×12: 96 destructible + 8 stones (chamber с V-жемчужиной).
  //     C  = 70  тело рыбы (dominant)
  //     O  = 13  хвост
  //     Y  =  1  глаз (eye)
  //     G  =  2  bubbles внизу
  //     V  =  2  жемчужина внутри chamber
  //     Dual (_yg) × 2 = 2 blocks (highlights на теле — 2 Y-shots + 2 G-shots)
  //     ColorShift (Y→O→P) × 2 = 2 blocks (радужные чешуйки — 2×3 shots)
  //     S  =  8  chamber walls (2 top-cap + 2 sides + 4 bottom-cap)
  //     Colors on board: C, O, Y (eye+dual+shift), G (bubbles+dual), V, P (shift) = 6 ✓
  //
  //   Shot hits per color:
  //     C=70, O=13+2(shift state 2)=15, Y=1+2(dual outer)+2(shift state 1)=5,
  //     G=2+2(dual inner)=4, V=2, P=2(shift state 3). Σ=98
  //
  //   Combo: row 6 = 12 C contig → первая C-piggy → filter reward.
  //   Chamber (8 stones ≥ max filter ammo) → filter всегда exhausts.
  //
  //   Inventory (15 piggies + 1 filter reward):
  //     C × 7 ammo=10        → 70 exact (тело + combo trigger)
  //     O × 3 ammo=5         → 15 exact (хвост + shift state 2)
  //     Y × 1 ammo=5         →  5 exact (eye + dual outer + shift state 1)
  //     G × 1 ammo=4         →  4 exact (bubbles + dual inner)
  //     V × 1 ammo=2         →  2 exact (жемчужина после filter)
  //     P × 1 ammo=2         →  2 exact (shift state 3)
  //     C × 1 ammo=3         →  TRAP: excess C spare
  //
  //   Par: 15 launches (14 live + 1 filter, skip 1 trap).
  //   Order matters: на shift-блоках Y first → O next → P last. Ранняя O/P
  //     на shift без Y-фазы = ammo впустую. Player УЧИТ последовательность
  //     на предыдущих уровнях, теперь применяет.
  //   L15 v3 — 🐟 РЫБА BOSS (2026-08-19 чистая рыба + varied ammo + all mech).
  //   Тело С овалом, хвост O слева, глаз Y справа. Dual + shift на теле.
  //   Chamber с V-жемчужиной ниже. 6 цветов + trap.
  //
  //   Grid 12×12: 80 destructible + 8 stones (pearl chamber).
  //     C  = 65  тело рыбы
  //     O  =  9  хвост (левая часть)
  //     Y  =  1  глаз (правый край тела)
  //     G  =  3  bubbles внизу
  //     V  =  2  жемчужина в chamber
  //     Dual _yg × 2 = 2 highlights
  //     Shift YOP × 2 = 2 радужные чешуйки
  //     S  =  8  chamber (3 top + 2 sides + 3 bottom)
  //   Shot hits:
  //     C = 65
  //     O = 9 + 2 (shift O) = 11
  //     Y = 1 + 2 (dual outer) + 2 (shift Y) = 5
  //     G = 3 + 2 (dual inner) = 5
  //     V = 2
  //     P = 2 (shift P)
  //   Total S = 90
  //
  //   Inventory (12 pigs + 1 filter) — varied ammo 2..25:
  //     C × 4: 25+15+15+10 = 65
  //     O × 2: 6+5 = 11
  //     Y × 1: 5, G × 1: 5, V × 1: 2, P × 1: 2
  //     C × 1 ammo=4 — TRAP: excess C spare
  //     P × 1 ammo=3 — TRAP: excess P spare
  //   Par: 11 launches (10 live + 1 filter, skip 2 traps).
  LevelConfig(
    levelNumber: 15,
    grid: [
      [_e, _e, _e, _e, _c, _c, _c, _c, _e, _e, _e, _e], // body top (4C)
      [_e, _e, _e, _c, _c, _c, _c, _c, _c, _e, _e, _e], // body (6C)
      [_e, _e, _c, _c, _c, _c, _c, _c, _c, _c, _e, _e], // body wider (8C)
      [_e, _o, _c, _c, _yg,_c, _c, _c, _c, _c, _y, _e], // tail-start+body+dual+eye (1O+9C+1D+1Y)
      [_o, _o, _c, _c, _c, _c, _shiftYOP, _c, _c, _c, _c, _c], // 2O + 9C + 1shift
      [_o, _o, _o, _c, _c, _c, _c, _c, _c, _c, _c, _c], // 3O + 9C (body middle)
      [_o, _o, _c, _c, _c, _shiftYOP, _c, _c, _c, _c, _c, _e], // 2O + 9C + 1shift
      [_e, _o, _c, _c, _c, _c, _yg,_c, _c, _c, _e, _e], // 1O + 8C + 1D
      [_e, _e, _c, _c, _c, _c, _c, _c, _c, _e, _e, _e], // body bottom (7C)
      [_e, _e, _e, _e, _S, _S, _S, _e, _e, _e, _e, _e], // chamber top-cap (3S)
      [_e, _g, _e, _S, _v, _v, _S, _e, _e, _g, _e, _g], // chamber (3G+2V+2S)
      [_e, _e, _e, _e, _S, _S, _S, _e, _e, _e, _e, _e], // chamber bot-cap (3S)
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 25), // 1 — HUGE C (combo trigger)
      PiggyBundle(color: PiggyColor.cyan,   ammo: 15), // 2 — C heavy
      PiggyBundle(color: PiggyColor.cyan,   ammo: 15), // 3 — C heavy
      PiggyBundle(color: PiggyColor.cyan,   ammo: 10), // 4 — C medium (65 exact)
      PiggyBundle(color: PiggyColor.orange, ammo:  6), // 5 — tail
      PiggyBundle(color: PiggyColor.orange, ammo:  5), // 6 — tail (11 exact)
      PiggyBundle(color: PiggyColor.yellow, ammo:  5), // 7 — eye + dual + shift Y
      PiggyBundle(color: PiggyColor.green,  ammo:  5), // 8 — bubbles + dual inner
      PiggyBundle(color: PiggyColor.purple, ammo:  2), // 9 — pearl (after filter)
      PiggyBundle(color: PiggyColor.pink,   ammo:  2), // 10 — shift P (2 exact)
      PiggyBundle(color: PiggyColor.cyan,   ammo:  4), // 11 — TRAP: excess C
      PiggyBundle(color: PiggyColor.pink,   ammo:  3), // 12 — TRAP: excess P
    ],
    comboRewards: const [PiggyType.filter],
    targetLaunches: 11, // 10 live + 1 filter, skip 2 traps
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    expectedCombos: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.orange, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.purple, PiggyColor.pink,
    ],
    piggySpeed: 500,
    spawnInterval: 0.75,
  ),

  // =========================================================================
  // ❄ FROZEN  L16-L20 — portals
  // =========================================================================

  // L16 — 🌀 ПОРТАЛ INTRO. Одна пара _PA. 3 цвета. Обучение механике:
  //   выстрел, вошедший в _PA, выходит из парного _PA в том же направлении.
  //
  //   Grid 8×8: 52 destructible + 2 portals (_PA пара (0,3) ↔ (6,6),
  //   разные строки и столбцы — иначе baldirection после teleport ушёл бы
  //   в клетку-близнеца и получилась бы петля).
  //
  //   Portal-showcase: shot из TOP belt col 3 → (0,3) _PA → выход (6,6)
  //   продолжает down → (7,6) = C hit. Player видит shortcut в bottom row.
  //
  //   Counts:
  //     C = 21 (периметр + акценты снизу)
  //     P = 15 (внутренняя рамка)
  //     Y = 16 (центр + accents)
  //
  //   Inventory (8 pigs, live-margin = 0, 1 trap):
  //     C × 3: 15+4+2 = 21
  //     P × 2: 10+5 = 15
  //     Y × 2: 12+4 = 16
  //     V × 1 ammo=3 — TRAP: Purple dead-color
  //   Par: 7 launches (skip 1 trap).
  LevelConfig(
    levelNumber: 16,
    grid: [
      [_c, _c, _c, _PA, _e, _e, _e, _c],
      [_c, _p, _p, _p,  _y, _y, _p, _c],
      [_c, _p, _y, _y,  _y, _y, _p, _c],
      [_c, _p, _y, _e,  _e, _y, _p, _c],
      [_c, _p, _y, _e,  _e, _y, _p, _c],
      [_c, _p, _y, _y,  _y, _y, _p, _c],
      [_c, _p, _p, _y,  _y, _p, _PA, _c],
      [_c, _c, _c, _e,  _e, _e, _c, _c],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 15), // 1 — C combo trigger
      PiggyBundle(color: PiggyColor.cyan,   ammo:  4),
      PiggyBundle(color: PiggyColor.cyan,   ammo:  2), // sum C = 21
      PiggyBundle(color: PiggyColor.pink,   ammo: 10),
      PiggyBundle(color: PiggyColor.pink,   ammo:  5), // sum P = 15
      PiggyBundle(color: PiggyColor.yellow, ammo: 12),
      PiggyBundle(color: PiggyColor.yellow, ammo:  4), // sum Y = 16
      PiggyBundle(color: PiggyColor.purple, ammo:  3), // TRAP: Purple dead-color
    ],
    targetLaunches: 7,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow, PiggyColor.purple,
    ],
    piggySpeed: 460,
    spawnInterval: 0.9,
  ),

  // L17 — 🌀 ПОРТАЛ + БРОНЯ. Одна пара _PA внутри поля (не на границе,
  //   чтобы direction после teleport вёл в живые блоки). 4 цвета + armor P2.
  //
  //   Grid 8×8: destructible + 4 stones (центральный chamber) + portal pair.
  //   _PA (2,3) ↔ (5,4) — shot из top col 3 через chamber-wall уходит в
  //   portal, выходит на (5,4) direction down → бьёт row 6 col 4.
  //
  //   Counts:
  //     C = 28 (row 0 + row 7 + вертикальные края)
  //     P clean = 18 (внутренняя рамка + acc)
  //     P2 = 4 (2 hits each = 8 P shots) — углы внутренней рамки
  //     Y = 6 (accents вокруг portal)
  //     G = 4 (вокруг chamber)
  //     S = 4 (chamber walls)
  //
  //   Shot totals: C=28, P=18+8=26, Y=6, G=4. Σ=64.
  //
  //   Inventory (9 pigs, 1 trap):
  //     C × 3: 15+8+5 = 28 (первая — combo trigger)
  //     P × 3: 15+7+4 = 26
  //     Y × 1 ammo=6
  //     G × 1 ammo=4
  //     V × 1 ammo=3 — TRAP: Purple dead-color
  //   Par: 8 launches (skip 1 trap).
  LevelConfig(
    levelNumber: 17,
    grid: [
      [_c, _c,  _c, _c,  _c,  _c, _c,  _c],
      [_c, _p2, _p, _p,  _p,  _p, _p2, _c],
      [_c, _p,  _y, _PA, _y,  _y, _p,  _c],
      [_c, _p,  _g, _S,  _S,  _g, _p,  _c],
      [_c, _p,  _g, _S,  _S,  _g, _p,  _c],
      [_c, _p,  _y, _y,  _PA, _y, _p,  _c],
      [_c, _p2, _p, _p,  _p,  _p, _p2, _c],
      [_c, _c,  _c, _c,  _c,  _c, _c,  _c],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 15), // 1 — C combo trigger
      PiggyBundle(color: PiggyColor.cyan,   ammo:  8),
      PiggyBundle(color: PiggyColor.cyan,   ammo:  5), // sum C = 28
      PiggyBundle(color: PiggyColor.pink,   ammo: 15),
      PiggyBundle(color: PiggyColor.pink,   ammo:  7),
      PiggyBundle(color: PiggyColor.pink,   ammo:  4), // sum P = 26 (18 clean + 8 armor)
      PiggyBundle(color: PiggyColor.yellow, ammo:  6), // 6 exact
      PiggyBundle(color: PiggyColor.green,  ammo:  4), // 4 exact
      PiggyBundle(color: PiggyColor.purple, ammo:  3), // TRAP: Purple dead-color
    ],
    targetLaunches: 8,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    expectedCombos: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.purple,
    ],
    piggySpeed: 470,
    spawnInterval: 0.85,
  ),

  // L18 — 🌀 ПОРТАЛ + DUAL + КОМБО. Две пары порталов (_PA, _PB) внутри
  //   поля. Симметричные dual _pc/_cp по 4 штуки. 4 цвета + trap.
  //
  //   Grid 8×8. Порталы во второй/предпоследней строках — exit-direction
  //   попадает в живой блок:
  //     _PA (1,2) ↔ (6,5)
  //     _PB (1,5) ↔ (6,2)
  //
  //   Counts:
  //     C = 28 (row 0 + row 7 + вертикальные края)
  //     P clean = 12 (внутренняя рамка)
  //     Y = 8 (accents вокруг dual)
  //     G = 4 (центральное ядро)
  //     Dual _pc × 2 (row 2 col 3, row 5 col 4) + _cp × 2 (row 2 col 4, row 5 col 3)
  //       Dual shots: 4 P (outer _pc + inner _cp) + 4 C (outer _cp + inner _pc)
  //
  //   Shot totals: C=28+4=32, P=12+4=16, Y=8, G=4. Σ=60.
  //
  //   Inventory (8 pigs, 1 trap):
  //     C × 3: 20+8+4 = 32 (combo trigger)
  //     P × 2: 12+4 = 16
  //     Y × 1 ammo=8
  //     G × 1 ammo=4
  //     V × 1 ammo=3 — TRAP: Purple dead-color
  //   Par: 7 launches (skip 1 trap).
  LevelConfig(
    levelNumber: 18,
    grid: [
      [_c, _c, _c,  _c,  _c,  _c,  _c, _c],
      [_c, _p, _PA, _e,  _e,  _PB, _p, _c],
      [_c, _p, _y,  _pc, _cp, _y,  _p, _c],
      [_c, _p, _y,  _g,  _g,  _y,  _p, _c],
      [_c, _p, _y,  _g,  _g,  _y,  _p, _c],
      [_c, _p, _y,  _cp, _pc, _y,  _p, _c],
      [_c, _p, _PB, _e,  _e,  _PA, _p, _c],
      [_c, _c, _c,  _c,  _c,  _c,  _c, _c],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 20), // 1 — C combo trigger (row 7 8-contig)
      PiggyBundle(color: PiggyColor.cyan,   ammo:  8),
      PiggyBundle(color: PiggyColor.cyan,   ammo:  4), // sum C = 32
      PiggyBundle(color: PiggyColor.pink,   ammo: 12),
      PiggyBundle(color: PiggyColor.pink,   ammo:  4), // sum P = 16
      PiggyBundle(color: PiggyColor.yellow, ammo:  8), // 8 exact
      PiggyBundle(color: PiggyColor.green,  ammo:  4), // 4 exact
      PiggyBundle(color: PiggyColor.purple, ammo:  3), // TRAP: Purple dead-color
    ],
    targetLaunches: 7,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    expectedCombos: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.purple,
    ],
    piggySpeed: 490,
    spawnInterval: 0.82,
  ),

  // L19 — 🌀 ПОРТАЛ + SHIFT + CHAMBER С WORM. FILTER-piggy ОБЯЗАТЕЛЕН.
  //
  //   Grid 10×10. 2 портальные пары (внутри поля), 2 shift YOP на верхней
  //   и нижней рамках, 8 stones-chamber в центре с 4 V-worm внутри.
  //   Только FILTER-piggy (в inventory) может пробить stone chamber —
  //   без неё V-worm остаётся заперт и уровень непроходим.
  //
  //   _PA (2,3) ↔ (7,6), _PB (2,6) ↔ (7,3).
  //
  //   Shot totals:
  //     C = 36 (периметр)
  //     P = 26 clean + 2 shift state 2 = 28
  //     Y = 16 clean + 2 shift state 0 = 18
  //     O = 2 (shift state 1)
  //     V = 4 (worm)
  //     + 8 filter shots on stones
  //
  //   Inventory (12 pigs, 1 special, 1 trap, live-margin = 0):
  //     C × 3: 20+10+6 = 36
  //     P × 3: 15+8+5 = 28
  //     Y × 3: 10+6+2 = 18
  //     O × 1 ammo=2
  //     FILTER × 1 ammo=8 (spec: PiggyType.filter, кракает ВСЕ 8 stones)
  //     V × 1 ammo=4 (worm, после filter)
  //     G × 1 ammo=3 — TRAP: Green dead-color
  //
  //   ORDER: shift YOP требует Y→O→P. Filter должен пойти ПОСЛЕ P (иначе
  //   filter fires в chamber до того как соседние P блоки очистят line-of-sight
  //   к chamber-stones). V идёт последней (после filter открывает chamber).
  //
  //   Par: 11 launches (skip 1 trap).
  LevelConfig(
    levelNumber: 19,
    grid: [
      [_c, _c,        _c, _c,  _e, _e, _c,  _c, _c,        _c],
      [_c, _shiftYOP, _p, _p,  _p, _p, _p,  _p, _shiftYOP, _c],
      [_c, _p,        _y, _PA, _e, _e, _PB, _y, _p,        _c],
      [_c, _p,        _y, _y,  _S, _S, _y,  _y, _p,        _c],
      [_c, _p,        _y, _S,  _v, _v, _S,  _y, _p,        _c],
      [_c, _p,        _y, _S,  _v, _v, _S,  _y, _p,        _c],
      [_c, _p,        _y, _y,  _S, _S, _y,  _y, _p,        _c],
      [_c, _p,        _y, _PB, _e, _e, _PA, _y, _p,        _c],
      [_c, _p,        _p, _p,  _p, _p, _p,  _p, _p,        _c],
      [_c, _c,        _c, _c,  _c, _c, _c,  _c, _c,        _c],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 20),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 10),
      PiggyBundle(color: PiggyColor.cyan,   ammo:  6), // sum C = 36
      PiggyBundle(color: PiggyColor.pink,   ammo: 15),
      PiggyBundle(color: PiggyColor.pink,   ammo:  8),
      PiggyBundle(color: PiggyColor.yellow, ammo: 10),
      PiggyBundle(color: PiggyColor.yellow, ammo:  6),
      PiggyBundle(color: PiggyColor.yellow, ammo:  2), // sum Y = 18
      PiggyBundle(color: PiggyColor.orange, ammo:  2), // shift state 1
      PiggyBundle(color: PiggyColor.pink,   ammo:  5), // late P (shift state 2) — sum P = 28
      PiggyBundle(color: PiggyColor.cyan,   ammo:  8, type: PiggyType.filter), // ⚡ SPECIAL: chamber
      PiggyBundle(color: PiggyColor.purple, ammo:  4), // worm V
      PiggyBundle(color: PiggyColor.green,  ammo:  3), // TRAP: Green dead-color
    ],
    targetLaunches: 12,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.orange, PiggyColor.purple, PiggyColor.green,
    ],
    piggySpeed: 490,
    spawnInterval: 0.8,
  ),

  // L20 — 🌀 FROZEN BOSS. Все механики Frozen: 2 portal-пары, 4 shift, 4 dual,
  //   4 armored Y2, chamber с worm V, + FILTER + BOMB spec-piggies.
  //
  //   Grid 10×10. Плотный уровень. Bomb — вспомогательная (расчищает clusters
  //   быстрее), filter — обязательна для chamber.
  //
  //   _PA (1,3) ↔ (8,6), _PB (1,6) ↔ (8,3).
  //
  //   Shot totals:
  //     C = 36 + 4 (dual C) = 40
  //     P = 16 clean + 4 (dual P) + 4 (shift state 2) = 24
  //     Y = 12 clean + 8 (Y2 armor) + 4 (shift state 0) = 24
  //     O = 4 (shift state 1)
  //     V = 4 (worm)
  //     + 8 filter (chamber) + 1 bomb (helper)
  //
  //   Inventory (16 pigs, 2 specials, 2 traps):
  //     C × 4: 20+10+6+4 = 40
  //     P × 3: 12+8+4 = 24
  //     Y × 4: 12+6+4+2 = 24
  //     O × 2: 3+1 = 4
  //     V × 1 ammo=4
  //     FILTER × 1 ammo=8 (chamber-mandatory)
  //     BOMB × 1 ammo=1 (helper — площадное поражение 3×3)
  //     G × 1 ammo=3 — TRAP dead-color
  //     P × 1 ammo=3 — TRAP excess spare
  //
  //   Par: 14 launches (skip 2 traps).
  LevelConfig(
    levelNumber: 20,
    grid: [
      [_c, _c,        _c, _c,  _c, _c, _c,  _c, _c,        _c],
      [_c, _shiftYOP, _p, _PA, _e, _e, _PB, _p, _shiftYOP, _c],
      [_c, _p,        _y, _pc, _y, _y, _cp, _y, _p,        _c],
      [_c, _p,        _y, _y,  _S, _S, _y,  _y, _p,        _c],
      [_c, _p,        _y2, _S, _v, _v, _S,  _y2, _p,       _c],
      [_c, _p,        _y2, _S, _v, _v, _S,  _y2, _p,       _c],
      [_c, _p,        _y, _y,  _S, _S, _y,  _y, _p,        _c],
      [_c, _p,        _y, _cp, _y, _y, _pc, _y, _p,        _c],
      [_c, _shiftYOP, _p, _PB, _e, _e, _PA, _p, _shiftYOP, _c],
      [_c, _c,        _c, _c,  _c, _c, _c,  _c, _c,        _c],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 20),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 10),
      PiggyBundle(color: PiggyColor.cyan,   ammo:  6),
      PiggyBundle(color: PiggyColor.cyan,   ammo:  4), // sum C = 40
      PiggyBundle(color: PiggyColor.pink,   ammo: 12),
      PiggyBundle(color: PiggyColor.pink,   ammo:  8),
      PiggyBundle(color: PiggyColor.yellow, ammo: 12),
      PiggyBundle(color: PiggyColor.yellow, ammo:  8),
      PiggyBundle(color: PiggyColor.yellow, ammo:  6),
      PiggyBundle(color: PiggyColor.yellow, ammo:  2), // sum Y = 28 (16 clean + 8 Y2 armor + 4 shift)
      PiggyBundle(color: PiggyColor.orange, ammo:  3),
      PiggyBundle(color: PiggyColor.orange, ammo:  1), // sum O = 4
      PiggyBundle(color: PiggyColor.pink,   ammo:  4), // late P (shift state 2) — sum P = 24
      PiggyBundle(color: PiggyColor.cyan,   ammo:  8, type: PiggyType.filter), // ⚡ SPECIAL: chamber
      PiggyBundle(color: PiggyColor.pink,   ammo:  8, type: PiggyType.bomb),   // 💣 SPECIAL: 8 bombs — расчищай кластеры и добивай что забыл
      PiggyBundle(color: PiggyColor.purple, ammo:  4), // worm V
      PiggyBundle(color: PiggyColor.green,  ammo:  3), // TRAP: Green dead-color
      PiggyBundle(color: PiggyColor.pink,   ammo:  3), // TRAP: excess P spare
    ],
    targetLaunches: 14,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    expectedCombos: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.orange, PiggyColor.purple, PiggyColor.green,
    ],
    piggySpeed: 510,
    spawnInterval: 0.78,
  ),

  // ═════════════════════════════════════════════════════════════════════════
  // 🧪 NEON LAB (L21-L25) — фокус на спец-пигах (bomb, chain, rainbow, ...)
  // ═════════════════════════════════════════════════════════════════════════

  // L21 — 💣 BOMB LAB. Усложнённый интро в спец-пиги: 5 цветов, 2 shift,
  //   4 dual (_pc/_cp), 2×2 G-кластер в центре. G-piggy НЕТ в inventory —
  //   только BOMB может убить кластер. Bomb с ammo=8 — расчищай что хочешь,
  //   но G-кластер обязателен.
  //
  //   Grid 10×10.
  //
  //   Точный подсчёт (правило: считать ДО написания):
  //     C periphery = 10 (row 0) + 10 (row 9) + 8 (col 0 rows 1-8) + 8 (col 9 rows 1-8) = 36
  //     P clean    = 8 (row 1) + 8 (row 8) + 6 (col 1 rows 2-7) + 6 (col 8 rows 2-7) = 28
  //     Y clean    = 4 (row 2 cols 3-6) + 2 (row 3 cols 2,7) + 2 (row 4)
  //                  + 2 (row 5) + 2 (row 6 cols 2,7) + 4 (row 7 cols 3-6) = 16
  //     G          = 4 (rows 4-5 cols 4-5, 2×2 кластер)
  //     Shift × 4  (row 2 cols 2,7; row 7 cols 2,7) → 4Y + 4O + 4P shots
  //     Dual × 4   (_pc × 2 + _cp × 2) → 4P + 4C shots
  //
  //   Итоги по цветам:
  //     C = 36 + 4 (dual) = 40
  //     P = 28 + 4 (dual) + 4 (shift) = 36
  //     Y = 16 + 4 (shift) = 20
  //     O = 4 (shift)
  //     G = 4 (bomb only!)
  //
  //   Inventory (15 pigs, 2 specials, 1 trap):
  //     C × 4: 20+10+6+4 = 40 ✓
  //     P × 4: 15+10+7+4 = 36 ✓
  //     Y × 3: 12+6+2 = 20 ✓
  //     O × 2: 3+1 = 4 ✓
  //     BOMB × 1 ammo=8 (mandatory для G-кластера + запас для маневра)
  //     V × 1 ammo=3 — TRAP: Purple dead-color
  //
  //   Par: 14 launches (skip 1 trap).
  //   Mastery: bomb с ammo=8 скорее всего оставит лишние → 2★ приемлемо.
  LevelConfig(
    levelNumber: 21,
    grid: [
      [_c, _c,        _c, _c,  _c, _c, _c,  _c,        _c, _c],
      [_c, _p,        _p, _p,  _p, _p, _p,  _p,        _p, _c],
      [_c, _p,        _shiftYOP, _y, _y, _y, _y, _shiftYOP, _p, _c],
      [_c, _p,        _y, _pc, _e, _e, _cp, _y,        _p, _c],
      [_c, _p,        _y, _e,  _g, _g, _e,  _y,        _p, _c],
      [_c, _p,        _y, _e,  _g, _g, _e,  _y,        _p, _c],
      [_c, _p,        _y, _cp, _e, _e, _pc, _y,        _p, _c],
      [_c, _p,        _shiftYOP, _y, _y, _y, _y, _shiftYOP, _p, _c],
      [_c, _p,        _p, _p,  _p, _p, _p,  _p,        _p, _c],
      [_c, _c,        _c, _c,  _c, _c, _c,  _c,        _c, _c],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 20),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 10),
      PiggyBundle(color: PiggyColor.cyan,   ammo:  6),
      PiggyBundle(color: PiggyColor.cyan,   ammo:  4), // sum C = 40
      PiggyBundle(color: PiggyColor.pink,   ammo: 15),
      PiggyBundle(color: PiggyColor.pink,   ammo: 10),
      PiggyBundle(color: PiggyColor.pink,   ammo:  7),
      PiggyBundle(color: PiggyColor.yellow, ammo: 12),
      PiggyBundle(color: PiggyColor.yellow, ammo:  6),
      PiggyBundle(color: PiggyColor.yellow, ammo:  2), // sum Y = 20
      PiggyBundle(color: PiggyColor.orange, ammo:  3),
      PiggyBundle(color: PiggyColor.orange, ammo:  1), // sum O = 4
      PiggyBundle(color: PiggyColor.pink,   ammo:  4), // late P (shift state 2) — sum P = 36
      PiggyBundle(color: PiggyColor.green,  ammo:  8, type: PiggyType.bomb), // 💣 MANDATORY
      PiggyBundle(color: PiggyColor.purple, ammo:  3), // TRAP: Purple dead
    ],
    targetLaunches: 14,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    expectedCombos: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.orange, PiggyColor.green, PiggyColor.purple,
    ],
    piggySpeed: 490,
    spawnInterval: 0.8,
  ),

  // L22 — ⛓ CHAIN INTRO. Огромная стена Y-блоков (6×6=36) в центре поля.
  //   Y-piggy в inventory ОТСУТСТВУЕТ — только CHAIN может пройти всю
  //   стену за один выстрел (chain propagates по 4-connected same-color).
  //
  //   Player стратегия: очистить C+P на верхней строке в колонке X, затем
  //   пустить CHAIN сверху col X — первый блок на линии = Y (row 2), chain
  //   уходит по всей связанной Y-стене → 36 Y убиты за 1 shot.
  //
  //   Grid 10×10.
  //
  //   Точный подсчёт:
  //     C periphery = 10 + 10 + 8 + 8 = 36
  //     P = 8 (row 1) + 8 (row 8) + 6 (col 1 rows 2-7) + 6 (col 8 rows 2-7) = 28
  //     Y = 6 × 6 = 36 (все связаны)
  //
  //   Shot totals:
  //     C = 36
  //     P = 28
  //     Y = 36 (chain × 1)
  //
  //   Inventory (9 pigs, 1 special, 2 traps):
  //     C × 3: 20+10+6 = 36
  //     P × 3: 15+8+5 = 28
  //     CHAIN × 1 ammo=1 (⛓ MANDATORY — Y-стена не пробивается normal-ammo)
  //     V × 1 ammo=3, G × 1 ammo=3 — TRAPS (dead-colors)
  //
  //   Par: 7 launches (skip 2 traps).
  //
  //   Chain shots at first colored block on line — player должен направить
  //   на Y (не на C/P). Прикинуть belt-side и колонку. Промах = стек.
  LevelConfig(
    levelNumber: 22,
    grid: [
      [_c, _c, _c, _c, _c, _c, _c, _c, _c, _c],
      [_c, _p, _p, _p, _p, _p, _p, _p, _p, _c],
      [_c, _p, _y, _y, _y, _y, _y, _y, _p, _c],
      [_c, _p, _y, _y, _y, _y, _y, _y, _p, _c],
      [_c, _p, _y, _y, _y, _y, _y, _y, _p, _c],
      [_c, _p, _y, _y, _y, _y, _y, _y, _p, _c],
      [_c, _p, _y, _y, _y, _y, _y, _y, _p, _c],
      [_c, _p, _y, _y, _y, _y, _y, _y, _p, _c],
      [_c, _p, _p, _p, _p, _p, _p, _p, _p, _c],
      [_c, _c, _c, _c, _c, _c, _c, _c, _c, _c],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 20),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 10),
      PiggyBundle(color: PiggyColor.cyan,   ammo:  6), // sum C = 36
      PiggyBundle(color: PiggyColor.pink,   ammo: 15),
      PiggyBundle(color: PiggyColor.pink,   ammo:  8),
      PiggyBundle(color: PiggyColor.pink,   ammo:  5), // sum P = 28
      PiggyBundle(color: PiggyColor.yellow, ammo:  1, type: PiggyType.chain), // ⛓ MANDATORY
      PiggyBundle(color: PiggyColor.purple, ammo:  3), // TRAP: Purple dead
      PiggyBundle(color: PiggyColor.green,  ammo:  3), // TRAP: Green dead
    ],
    targetLaunches: 7,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.purple, PiggyColor.green,
    ],
    piggySpeed: 500,
    spawnInterval: 0.8,
  ),

  // L23 — 🌈 RAINBOW INTRO. Изолированная 2×2 V-комната, V-piggy отсутствует.
  //   Только RAINBOW (стреляет по любому цвету) может добить V.
  //
  //   Grid 10×10. V-cluster в центре окружён empty-cells, чтобы rainbow
  //   через пустоту от края поля дошёл до V первым (иначе rainbow бьёт
  //   в Y-стену или P-рамку).
  //
  //   Точный подсчёт:
  //     C = 10 (row 0) + 10 (row 9) + 8 (col 0) + 8 (col 9) = 36
  //     P = 8 (row 1) + 2×6 (col 1, col 8 rows 2-7) + 8 (row 8) = 28
  //     Y = 6 (row 2) + 2 (row 3) + 2 (row 4) + 2 (row 5) + 2 (row 6) + 6 (row 7) = 20
  //     V = 4 (rows 4-5 cols 4-5, 2×2)
  //
  //   Shots: C=36, P=28, Y=20, V=4 (rainbow only).
  //
  //   Inventory (10 pigs, 1 special, 1 trap):
  //     C × 3: 20+10+6 = 36 ✓
  //     P × 3: 15+8+5 = 28 ✓
  //     Y × 3: 10+7+3 = 20 ✓
  //     RAINBOW × 1 ammo=4 (🌈 MANDATORY для V-cluster)
  //     G × 1 ammo=3 — TRAP dead-color
  //
  //   Par: 9 launches (skip 1 trap).
  //
  //   Player план: очистить путь к V через одну из сторон (top col 4 после
  //   killing C+P+Y в этой колонке), пустить rainbow — она сделает 4 shots
  //   в 4 V. Промах в non-V цвет = wasted ammo → mastery fail.
  LevelConfig(
    levelNumber: 23,
    grid: [
      [_c, _c, _c, _c, _c, _c, _c, _c, _c, _c],
      [_c, _p, _p, _p, _p, _p, _p, _p, _p, _c],
      [_c, _p, _y, _y, _y, _y, _y, _y, _p, _c],
      [_c, _p, _y, _e, _e, _e, _e, _y, _p, _c],
      [_c, _p, _y, _e, _v, _v, _e, _y, _p, _c],
      [_c, _p, _y, _e, _v, _v, _e, _y, _p, _c],
      [_c, _p, _y, _e, _e, _e, _e, _y, _p, _c],
      [_c, _p, _y, _y, _y, _y, _y, _y, _p, _c],
      [_c, _p, _p, _p, _p, _p, _p, _p, _p, _c],
      [_c, _c, _c, _c, _c, _c, _c, _c, _c, _c],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 20),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 10),
      PiggyBundle(color: PiggyColor.cyan,   ammo:  6), // sum C = 36
      PiggyBundle(color: PiggyColor.pink,   ammo: 15),
      PiggyBundle(color: PiggyColor.pink,   ammo:  8),
      PiggyBundle(color: PiggyColor.pink,   ammo:  5), // sum P = 28
      PiggyBundle(color: PiggyColor.yellow, ammo: 10),
      PiggyBundle(color: PiggyColor.yellow, ammo:  7),
      PiggyBundle(color: PiggyColor.yellow, ammo:  3), // sum Y = 20
      PiggyBundle(color: PiggyColor.purple, ammo:  4, type: PiggyType.rainbow), // 🌈 MANDATORY (4 V)
      PiggyBundle(color: PiggyColor.green,  ammo:  3), // TRAP: Green dead-color
    ],
    targetLaunches: 10,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.purple, PiggyColor.green,
    ],
    piggySpeed: 500,
    spawnInterval: 0.8,
  ),

  // L24 — 🎨 PAINTER INTRO. 2×2 V-cluster без V-piggy. PAINTER (piggyColor=Y)
  //   бьёт V и перекрашивает 3×3 area в Y. 4 V → 4 Y, потом Y-piggy добивает.
  //
  //   Grid 10×10. V-cluster впритык к Y-wall (rows 2-7 cols 2-7 mostly Y),
  //   чтобы painter не переоткрашивал ничего постороннего (только V) —
  //   зона repaint 3×3 центрируется на V и содержит только V + Y (Y уже Y).
  //
  //   Точный подсчёт:
  //     C = 36
  //     P = 28 (внутренняя рамка)
  //     Y clean = 6 (row 2) + 6 (row 3) + 2 (row 4 cols 2,7) + 2 (row 5)
  //             + 6 (row 6) + 6 (row 7) = 28
  //     V = 4 (rows 4-5 cols 4-5)
  //
  //   После painter: 4 V перекрашены в Y (paintOverride=Y). Общее Y-shots
  //   для игрока = 28 clean + 4 painted = 32.
  //
  //   Inventory (11 pigs, 1 special, 1 trap):
  //     C × 3: 20+10+6 = 36
  //     P × 3: 15+8+5 = 28
  //     Y × 3: 20+8+4 = 32 (28 clean + 4 painted V)
  //     PAINTER × 1 piggyColor=Y, ammo=1 (🎨 MANDATORY — красит V→Y)
  //     G × 1 ammo=3 — TRAP dead-color
  //
  //   Par: 10 launches (skip 1 trap).
  //
  //   Painter должен ударить в V-блок (не в Y). Player пре-очищает путь
  //   от края до V, потом launches painter. Target = V, 3×3 area repaints
  //   все 4 V разом. Промах = painter репэйнтит Y-блоки (сброс hp=1,
  //   визуально ничего не меняется) = 0 конверсии V → уровень stuck.
  LevelConfig(
    levelNumber: 24,
    grid: [
      [_c, _c, _c, _c, _c, _c, _c, _c, _c, _c],
      [_c, _p, _p, _p, _p, _p, _p, _p, _p, _c],
      [_c, _p, _y, _y, _y, _y, _y, _y, _p, _c],
      [_c, _p, _y, _y, _y, _y, _y, _y, _p, _c],
      [_c, _p, _y, _e, _v, _v, _e, _y, _p, _c],
      [_c, _p, _y, _e, _v, _v, _e, _y, _p, _c],
      [_c, _p, _y, _y, _y, _y, _y, _y, _p, _c],
      [_c, _p, _y, _y, _y, _y, _y, _y, _p, _c],
      [_c, _p, _p, _p, _p, _p, _p, _p, _p, _c],
      [_c, _c, _c, _c, _c, _c, _c, _c, _c, _c],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 20),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 10),
      PiggyBundle(color: PiggyColor.cyan,   ammo:  6), // sum C = 36
      PiggyBundle(color: PiggyColor.pink,   ammo: 15),
      PiggyBundle(color: PiggyColor.pink,   ammo:  8),
      PiggyBundle(color: PiggyColor.pink,   ammo:  5), // sum P = 28
      PiggyBundle(color: PiggyColor.yellow, ammo: 20),
      PiggyBundle(color: PiggyColor.yellow, ammo:  8),
      PiggyBundle(color: PiggyColor.yellow, ammo:  4), // sum Y = 32 (28 clean + 4 painted)
      PiggyBundle(color: PiggyColor.yellow, ammo:  1, type: PiggyType.painter), // 🎨 MANDATORY
      PiggyBundle(color: PiggyColor.green,  ammo:  3), // TRAP: Green dead-color
    ],
    targetLaunches: 10,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow, PiggyColor.green,
    ],
    piggySpeed: 500,
    spawnInterval: 0.8,
  ),

  // L25 — 🧪 NEON BOSS «Лаборатория». Три спец-пиги обязательны разом:
  //   CHAIN (Y-стена 3×4), BOMB (G 2×2), FILTER (chamber с V-worm).
  //
  //   Grid 10×10. Три "квадранта" с задачами:
  //     - Rows 2-4 cols 2-5: Y-wall 3×4 = 12 Y (all connected, no Y-piggy → CHAIN)
  //     - Rows 3-4 cols 7-8: G 2×2 = 4 G (no G-piggy → BOMB)
  //     - Rows 6-8 cols 2-4: chamber 8 stones + 1 V в центре (FILTER + V-piggy)
  //
  //   Точный подсчёт:
  //     C periphery = 36
  //     P = 8 (row 1) + 2 (row 2 cols 1,8) + 1 (row 3 col 1) + 1 (row 4 col 1)
  //         + 1 (row 5) + 1 (row 6) + 1 (row 7) + 5 (row 8 cols 1,5-8) = 20
  //     Y = 12 (rows 2-4 cols 2-5, all connected)
  //     G = 4 (rows 3-4 cols 7-8, 2×2 cluster)
  //     V = 1 (row 7 col 3)
  //     S = 8 (chamber walls вокруг V)
  //
  //   Стратегия BOSS'а:
  //     1. CHAIN fires at Y wall → 12 Y wiped за 1 shot
  //     2. BOMB at (4,7) → 4 G killed (без C-waste — bomb на угловом блоке)
  //     3. FILTER × 8 shots ломает chamber → V-piggy добивает worm
  //     4. C/P piggy закрывают C-периметр и P-inner ring
  //
  //   Inventory (10 pigs, 3 specials, 1 trap):
  //     C × 3: 20+10+6 = 36
  //     P × 3: 12+5+3 = 20
  //     CHAIN × 1 ammo=1 (⛓ MANDATORY — Y wall)
  //     BOMB × 1 ammo=1 (💣 MANDATORY — G cluster)
  //     FILTER × 1 ammo=8 (⚡ MANDATORY — chamber)
  //     V × 1 ammo=1 (worm)
  //     O × 1 ammo=3 — TRAP dead-color
  //
  //   Par: 9 launches (skip 1 trap).
  //
  //   Первый уровень с ТРЕМЯ одновременно обязательными специалками.
  //   Order-agnostic: любой порядок работает если path для каждого расчищен.
  LevelConfig(
    levelNumber: 25,
    grid: [
      [_c, _c, _c, _c, _c, _c, _c, _c, _c, _c],
      [_c, _p, _p, _p, _p, _p, _p, _p, _p, _c],
      [_c, _p, _y, _y, _y, _y, _e, _e, _p, _c],
      [_c, _p, _y, _y, _y, _y, _e, _g, _g, _c],
      [_c, _p, _y, _y, _y, _y, _e, _g, _g, _c],
      [_c, _p, _e, _e, _e, _e, _e, _e, _e, _c],
      [_c, _p, _S, _S, _S, _e, _e, _e, _e, _c],
      [_c, _p, _S, _v, _S, _e, _e, _e, _e, _c],
      [_c, _p, _S, _S, _S, _p, _p, _p, _p, _c],
      [_c, _c, _c, _c, _c, _c, _c, _c, _c, _c],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 20),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 10),
      PiggyBundle(color: PiggyColor.cyan,   ammo:  6), // sum C = 36
      PiggyBundle(color: PiggyColor.pink,   ammo: 12),
      PiggyBundle(color: PiggyColor.pink,   ammo:  5),
      PiggyBundle(color: PiggyColor.pink,   ammo:  3), // sum P = 20
      PiggyBundle(color: PiggyColor.yellow, ammo:  1, type: PiggyType.chain),  // ⛓ Y wall
      PiggyBundle(color: PiggyColor.green,  ammo:  1, type: PiggyType.bomb),   // 💣 G cluster
      PiggyBundle(color: PiggyColor.cyan,   ammo:  8, type: PiggyType.filter), // ⚡ chamber
      PiggyBundle(color: PiggyColor.purple, ammo:  1), // worm V
      PiggyBundle(color: PiggyColor.orange, ammo:  3), // TRAP: Orange dead-color
    ],
    targetLaunches: 10,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 1,
    expectedCombos: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.purple, PiggyColor.orange,
    ],
    piggySpeed: 520,
    spawnInterval: 0.77,
  ),

  // L26 — 🧪 «Полигон» (тестовый уровень, спроектирован в Grid Lab Aleksey'ем).
  //   Все механики Neon Lab в одной сетке: armor (G2/Y2/V2/P2), 5 типов dual
  //   (_cp / _yg / _ov / _pc / _vo), chamber из 16 stones, 2 filter piggies.
  //   Одинокий _PA заменён на _e (portal без пары = мертвая клетка,
  //   raycast трактует как stone). Portals в следующих итерациях.
  //
  //   Grid 10×10 · destructible: 82 (+ 16 stones)
  //   Shots per color (посчитаны из редактора + verified вручную):
  //     C = 6 clean + 4 (_cp outer) + 4 (_pc inner) = 14
  //     P = 2 clean + 16 (_p2 armor) + 4 (_cp inner) + 4 (_pc outer) = 26
  //     Y = 48 (_y2 armor) + 2 (_yg outer) = 50
  //     G = 20 (_g2 armor) + 2 (_yg inner) = 22
  //     V = 16 (_v2 armor) + 10 (_ov inner) + 5 (_vo outer) = 31
  //     O = 10 (_ov outer) + 5 (_vo inner) = 15
  //   Total normal = 158 + filter 16.
  //
  //   Order-critical duals:
  //     _cp: C→P    (C-piggy до P)
  //     _pc: P→C    (P до C — конфликт с _cp! Play accepts flexibility)
  //     _yg: Y→G
  //     _ov: O→V    (O piggy до V)
  //     _vo: V→O    (V до O)
  //   Player использует piggies-in-waiting для отложенной стрельбы —
  //   inner-color piggies дожидаются пока outer убит.
  //
  //   Inventory (23 pigs, 2 specials, no traps — тест):
  //     C × 3: 8+4+2   = 14
  //     P × 4: 12+8+4+2 = 26
  //     Y × 5: 20+15+10+3+2 = 50
  //     G × 3: 12+7+3  = 22
  //     O × 2: 10+5    = 15
  //     V × 4: 15+10+4+2 = 31
  //     FILTER × 2 ammo=8+8 (⚡ 16 stones chamber)
  //
  //   Par: 23. Boss-scale (>150 shots) — тест на выносливость и планирование.
  LevelConfig(
    levelNumber: 26,
    grid: [
      [_g2, _g2, _c , _c , _c , _c , _c , _c , _g2, _g2],
      [_g2, _y2, _y2, _cp, _cp, _cp, _cp, _y2, _y2, _g2],
      [_g2, _y2, _S , _S , _S , _S , _S , _S , _y2, _g2],
      [_g2, _y2, _S , _yg, _S , _S , _yg, _S , _y2, _g2],
      [_ov, _y2, _S , _S , _S , _S , _S , _S , _y2, _ov],
      [_ov, _ov, _ov, _ov, _pc, _pc, _ov, _ov, _ov, _ov],
      [_v2, _y2, _y2, _p , _vo, _vo, _p , _y2, _y2, _v2],
      [_v2, _y2, _pc, _y2, _vo, _vo, _y2, _pc, _y2, _v2],
      [_v2, _y2, _y2, _y2, _vo, _e , _y2, _y2, _y2, _v2], // _PA→_e (portal без пары)
      [_v2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _v2],
    ],
    inventory: const [
      // C first — _cp outer + clean C
      PiggyBundle(color: PiggyColor.cyan,   ammo:  8),
      PiggyBundle(color: PiggyColor.cyan,   ammo:  4),
      PiggyBundle(color: PiggyColor.cyan,   ammo:  2), // sum C = 14
      // P — _p2 armor + _pc outer + _cp inner + clean
      PiggyBundle(color: PiggyColor.pink,   ammo: 12),
      PiggyBundle(color: PiggyColor.pink,   ammo:  8),
      PiggyBundle(color: PiggyColor.pink,   ammo:  4),
      PiggyBundle(color: PiggyColor.pink,   ammo:  2), // sum P = 26
      // Y — _y2 armor + _yg outer (много Y — bulk)
      PiggyBundle(color: PiggyColor.yellow, ammo: 20),
      PiggyBundle(color: PiggyColor.yellow, ammo: 15),
      PiggyBundle(color: PiggyColor.yellow, ammo: 10),
      PiggyBundle(color: PiggyColor.yellow, ammo:  3),
      PiggyBundle(color: PiggyColor.yellow, ammo:  2), // sum Y = 50
      // G — _g2 armor + _yg inner
      PiggyBundle(color: PiggyColor.green,  ammo: 12),
      PiggyBundle(color: PiggyColor.green,  ammo:  7),
      PiggyBundle(color: PiggyColor.green,  ammo:  3), // sum G = 22
      // O — _ov outer + _vo inner (O до V)
      PiggyBundle(color: PiggyColor.orange, ammo: 10),
      PiggyBundle(color: PiggyColor.orange, ammo:  5), // sum O = 15
      // V — _v2 armor + _ov inner + _vo outer (V перекликается с O через оба dual)
      PiggyBundle(color: PiggyColor.purple, ammo: 15),
      PiggyBundle(color: PiggyColor.purple, ammo: 10),
      PiggyBundle(color: PiggyColor.purple, ammo:  4),
      PiggyBundle(color: PiggyColor.purple, ammo:  2), // sum V = 31
      // FILTER × 2 — 16 stones chamber
      PiggyBundle(color: PiggyColor.cyan,   ammo:  8, type: PiggyType.filter),
      PiggyBundle(color: PiggyColor.cyan,   ammo:  8, type: PiggyType.filter),
    ],
    targetLaunches: 23,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 2,
    expectedCombos: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.orange, PiggyColor.purple,
    ],
    piggySpeed: 520,
    spawnInterval: 0.75,
  ),

  // L27 — 🌀 «Троепортал» (тестовый уровень из Grid Lab, три портал-пары).
  //   Внешнее кольцо из 12 stones (столбцы 0 и 9 rows 2-7) блокирует shot
  //   line с left/right belt — вся сложность внутренняя достигается через
  //   top/bottom belt И через 3 портала:
  //     _PA (3,7) ↔ (6,2)
  //     _PB (2,2) ↔ (7,7)
  //     _PC (1,9) ↔ (8,0)
  //   Плюс shift YOP × 2 в углах верхней и нижней строки — order-critical.
  //
  //   Grid 10×10. Destructible: 62. Shots per color (пересчёт вручную):
  //     C = 3 clean (_c) + 8 (_cp outer) = 11
  //     P = 3 clean (_p) + 16 (_p2 armor) + 8 (_cp inner) + 2 (shift state 2) = 29
  //     Y = 16 (_y2 armor) + 10 (_yg outer) + 2 (shift state 0) = 28
  //     G = 24 (_g2 armor) + 10 (_yg inner) = 34
  //     V = 16 (_v2 armor) = 16
  //     O = 2 (shift state 1) = 2
  //   Total normal = 120 + filter 12 chamber-stones.
  //
  //   Inventory (21 pigs, 2 specials, без trap — тест):
  //     C × 3: 6+3+2 = 11
  //     P × 4: 12+8+5+4 = 29
  //     Y × 4: 12+8+5+3 = 28
  //     G × 4: 15+10+6+3 = 34
  //     V × 3: 8+5+3 = 16
  //     O × 1 ammo=2
  //     FILTER × 2 ammo=6+6 = 12 (⚡ 12 stones внешнего кольца)
  //
  //   Order: shift YOP требует Y→O→P. FIFO: C→Y→O→P→G→V→FILTER.
  //   Piggies с inner-color (P для _cp, G для _yg) ждут в waiting-slots
  //   пока outer убит. Portal shots — player экспериментирует.
  //
  //   Par: 21 launches.
  LevelConfig(
    levelNumber: 27,
    grid: [
      [_e       , _e , _e , _e , _e , _e , _e , _e , _e , _e       ],
      [_shiftYOP, _v2, _v2, _v2, _yg, _yg, _yg, _yg, _yg, _PC      ],
      [_S       , _v2, _PB, _p2, _p2, _p2, _p2, _g2, _g2, _S       ],
      [_S       , _cp, _cp, _y2, _y2, _y2, _y2, _PA, _g2, _S       ],
      [_S       , _cp, _cp, _c , _c , _c , _g2, _g2, _g2, _S       ],
      [_S       , _g2, _g2, _g2, _p , _p , _p , _cp, _cp, _S       ],
      [_S       , _g2, _PA, _y2, _y2, _y2, _y2, _cp, _cp, _S       ],
      [_S       , _g2, _g2, _p2, _p2, _p2, _p2, _PB, _v2, _S       ],
      [_PC      , _yg, _yg, _yg, _yg, _yg, _v2, _v2, _v2, _shiftYOP],
      [_e       , _e , _e , _e , _e , _e , _e , _e , _e , _e       ],
    ],
    // v3 (2026-08-21): revert увеличение слотов (правило Aleksey: 3+5 fixed).
    // Ammo EXACT (без safety). Разбивка Y/G на early/late — они нужны в
    // разные моменты игры. Меньше bundles (12 pigs) чтобы не переполнять
    // waiting → belt-crash game-over (новая механика).
    inventory: const [
      // C — clean + _cp outer
      PiggyBundle(color: PiggyColor.cyan,   ammo:  8),
      PiggyBundle(color: PiggyColor.cyan,   ammo:  3), // sum C = 11
      // Y × early — _yg outer × 10 + shift state 0 × 2 = 12 shots
      PiggyBundle(color: PiggyColor.yellow, ammo: 12),
      // O — shift state 1
      PiggyBundle(color: PiggyColor.orange, ammo:  2),
      // P — clean + _p2 armor + _cp inner + shift state 2 = 29
      PiggyBundle(color: PiggyColor.pink,   ammo: 15),
      PiggyBundle(color: PiggyColor.pink,   ammo: 14), // sum P = 29
      // Y × late — _y2 armor (8×2=16) после того как P открыл _p2 линию
      PiggyBundle(color: PiggyColor.yellow, ammo: 16), // Y sum = 28 exact
      // G — _g2 armor (12×2=24) + _yg inner (10) = 34
      PiggyBundle(color: PiggyColor.green,  ammo: 18),
      PiggyBundle(color: PiggyColor.green,  ammo: 16), // sum G = 34 exact
      // V — _v2 armor (8 × 2 = 16)
      PiggyBundle(color: PiggyColor.purple, ammo: 10),
      PiggyBundle(color: PiggyColor.purple, ammo:  6), // sum V = 16 exact
      // FILTER × 2 — 12 stones outer chamber
      PiggyBundle(color: PiggyColor.cyan,   ammo:  6, type: PiggyType.filter),
      PiggyBundle(color: PiggyColor.cyan,   ammo:  6, type: PiggyType.filter),
    ],
    targetLaunches: 13,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 2,
    expectedCombos: 1,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.orange, PiggyColor.purple,
    ],
    piggySpeed: 530,
    spawnInterval: 0.73,
  ),

  // L28 — 🌸 «Мандала» (Aleksey Grid Lab, 20×20, ~40 ammo per pig).
  //
  //   324 destructible + 8 stones (2 chamber-колонны col 7 и col 12).
  //   2 portal-пары. Симметрия по обеим осям. Плотный узор из dual-блоков
  //   (_cp/_pc/_yg/_gy/_ov) + armor (_y2/_g2/_p2). Один из первых уровней
  //   L82-стиля: piggies с большим ammo, мелкие клетки, много механик разом.
  //
  //   Точный подсчёт shots per color:
  //     C = 18 (_c) + 36 (_cp outer) + 18 (_pc inner) = 72
  //     P = 36 (_cp inner) + 8 (_p2 armor) + 18 (_pc outer) = 62
  //     Y = 32 (_y) + 72 (_yg outer) + 72 (_y2 armor 36×2) + 20 (_gy inner) = 196
  //     G = 72 (_yg inner) + 56 (_g2 armor 28×2) + 20 (_gy outer) = 148
  //     V = 28 (_ov inner)
  //     O = 32 (_o) + 28 (_ov outer) = 60
  //     Filter: 8 stones
  //   Total normal = 566 + 8 filter.
  //
  //   Inventory (12 pigs, exact ammo, interleaved order для order-dependency):
  //     C × 1 ammo=40 (early — _cp outer + clean C открывают путь для P inner)
  //     Y × 1 ammo=40 (early — _yg outer + _y clean + _gy inner)
  //     P × 1 ammo=40 (mid — _p2 armor + _cp inner + _pc outer)
  //     G × 1 ammo=40 (mid — _g2 partial + _gy outer opens _gy inner)
  //     O × 1 ammo=40 (mid — _o clean + _ov outer)
  //     V × 1 ammo=28 (mid-late — _ov inner после O killed outer, exact)
  //     Y × 4 ammo=40+40+40+36 = 156 (late — finish Y, sum Y = 196)
  //     G × 3 ammo=40+40+28 = 108 (late — finish G, sum G = 148)
  //     C × 1 ammo=32 (late — sum C = 72)
  //     P × 1 ammo=22 (late — sum P = 62)
  //     O × 1 ammo=20 (late — sum O = 60)
  //     FILTER × 1 ammo=8 (⚡ chamber-колонны col 7, col 12)
  //
  //   Piggies с большим ammo делают много кругов по belt → супер-пиги
  //   с HUD в помощь для расчистки path к внутренним слоям.
  //
  //   Par: 12 launches (все pigs used).
  LevelConfig(
    levelNumber: 28,
    grid: [
      [_c , _e , _e , _e , _y , _yg, _o , _o , _o , _o , _o , _o , _o , _o , _yg, _y , _e , _e , _e , _c ],
      [_cp, _c , _e , _e , _y , _yg, _o , _o , _o , _o , _o , _o , _o , _o , _yg, _y , _e , _e , _c , _cp],
      [_y2, _cp, _c , _e , _y , _yg, _y , _y , _y , _y , _y , _y , _y , _y , _yg, _y , _e , _c , _cp, _y2],
      [_ov, _y2, _cp, _c , _y , _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _y , _c , _cp, _y2, _ov],
      [_yg, _ov, _y2, _cp, _c , _g2, _g2, _g2, _g2, _gy, _gy, _g2, _g2, _g2, _g2, _c , _cp, _y2, _ov, _yg],
      [_yg, _yg, _ov, _y2, _cp, _c , _g2, _g2, _g2, _gy, _gy, _g2, _g2, _g2, _c , _cp, _y2, _ov, _yg, _yg],
      [_e , _yg, _e , _ov, _PA, _cp, _c , _y2, _y2, _gy, _gy, _y2, _y2, _c , _cp, _e , _ov, _PB, _yg, _e ],
      [_e , _e , _e , _yg, _e , _e , _cp, _c , _y2, _gy, _gy, _y2, _c , _cp, _e , _e , _yg, _e , _e , _e ],
      [_e , _e , _e , _yg, _y2, _ov, _cp, _S , _c , _gy, _gy, _c , _S , _cp, _ov, _y2, _yg, _e , _e , _e ],
      [_yg, _yg, _yg, _yg, _p2, _y2, _ov, _S , _ov, _cp, _cp, _ov, _S , _ov, _y2, _p2, _yg, _yg, _yg, _yg],
      [_yg, _yg, _yg, _yg, _p2, _y2, _ov, _S , _ov, _cp, _cp, _ov, _S , _ov, _y2, _p2, _yg, _yg, _yg, _yg],
      [_e , _e , _e , _yg, _y2, _ov, _cp, _S , _pc, _gy, _gy, _pc, _S , _cp, _ov, _y2, _yg, _e , _e , _e ],
      [_e , _e , _e , _yg, _e , _e , _cp, _pc, _y2, _gy, _gy, _y2, _pc, _cp, _PA, _e , _yg, _e , _e , _e ],
      [_e , _yg, _PB, _ov, _e , _cp, _pc, _y2, _y2, _gy, _gy, _y2, _y2, _pc, _cp, _e , _ov, _e , _yg, _e ],
      [_yg, _yg, _ov, _y2, _cp, _pc, _g2, _g2, _g2, _gy, _gy, _g2, _g2, _g2, _pc, _cp, _y2, _ov, _yg, _yg],
      [_yg, _ov, _y2, _cp, _pc, _g2, _g2, _g2, _g2, _gy, _gy, _g2, _g2, _g2, _g2, _pc, _cp, _y2, _ov, _yg],
      [_ov, _y2, _cp, _pc, _y , _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _y , _pc, _cp, _y2, _ov],
      [_y2, _cp, _pc, _e , _y , _yg, _y , _y , _y , _y , _y , _y , _y , _y , _yg, _y , _e , _pc, _cp, _y2],
      [_cp, _pc, _e , _e , _y , _yg, _o , _o , _o , _o , _o , _o , _o , _o , _yg, _y , _e , _e , _pc, _cp],
      [_pc, _e , _e , _e , _y , _yg, _o , _o , _o , _o , _o , _o , _o , _o , _yg, _y , _e , _e , _e , _pc],
    ],
    inventory: const [
      // Interleaved order: каждый цвет получает ~40-ammo раннего запуска
      // чтобы прогрызть внешние слои и открыть путь для inner colors.
      PiggyBundle(color: PiggyColor.cyan,   ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.pink,   ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo: 40),
      PiggyBundle(color: PiggyColor.orange, ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 28), // V exact (только _ov inner)
      // Поздние bundles — «доспинывать» большие цвета
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 36), // Y sum = 196
      PiggyBundle(color: PiggyColor.green,  ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo: 28), // G sum = 148
      PiggyBundle(color: PiggyColor.cyan,   ammo: 32), // C sum = 72
      PiggyBundle(color: PiggyColor.pink,   ammo: 22), // P sum = 62
      PiggyBundle(color: PiggyColor.orange, ammo: 20), // O sum = 60
      // FILTER × 1 — 8 stones (2 chamber-колонны)
      PiggyBundle(color: PiggyColor.cyan,   ammo:  8, type: PiggyType.filter),
    ],
    targetLaunches: 17,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 3,
    expectedCombos: 2,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.orange, PiggyColor.purple,
    ],
    piggySpeed: 540,
    spawnInterval: 0.7,
  ),

  // L29 — 🌀 «Спираль» (Aleksey Grid Lab, 25×25, 24 pigs).
  //
  //   620 destructible + 0 stones. 2 portal-пары (B ↔ B, C ↔ C).
  //   Симметрия по обеим диагоналям — спираль из витков _ov/_c от углов
  //   к центру. Ядро (rows 10-14, cols 10-15) — плотный _v (purple 1hp)
  //   внутри _y/_g/_c обмоток для order-dependency: сначала внешние
  //   витки, потом центр.
  //
  //   Точный подсчёт shots per color:
  //     C = 236 (_c) + 6 (_c2 armor 3×2) = 242
  //     Y = 45 (_y) + 8 (_y2 armor 4×2) = 53
  //     G = 43 (_g) + 14 (_g2 armor 7×2) = 57
  //     P = 271 (_ov inner) + 11 (_v) = 282
  //     O = 271 (_ov outer) = 271
  //   Total = 905 shots.
  //
  //   Inventory (24 pigs, exact ammo). Порядок: C/O/P интерлив в основе,
  //   Y/G — точечные finish pigs, всё сходится ровно в сумму per color.
  //     C ×  6 : 40×5 + 42 = 242
  //     O ×  7 : 40×6 + 31 = 271
  //     P ×  7 : 40×6 + 42 = 282
  //     Y ×  2 : 30 + 23 = 53
  //     G ×  2 : 30 + 27 = 57
  //
  //   Portals:
  //     _PB : (r=1,c=2) ↔ (r=22,c=21) — сокращают путь из левого верха
  //           в правый низ по контр-диагонали.
  //     _PC : (r=3,c=20) ↔ (r=19,c=3) — правый верх ↔ левый низ.
  //
  //   Par: 24 launches (все pigs used).
  LevelConfig(
    levelNumber: 29,
    grid: [
      [_y , _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _y ],
      [_ov, _y , _PB, _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _g , _y , _ov],
      [_ov, _g , _y , _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _y , _g , _ov],
      [_ov, _c , _ov, _y2, _g , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _PC, _y2, _ov, _c , _ov],
      [_ov, _c , _ov, _g , _y , _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _y , _g , _g , _ov, _c ],
      [_ov, _c , _ov, _c , _ov, _y , _g , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _g , _y , _ov, _c , _g , _ov, _c ],
      [_ov, _c , _ov, _c , _ov, _g , _y , _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _y , _g , _g , _ov, _c , _ov, _c ],
      [_ov, _c , _ov, _c , _ov, _c , _ov, _y , _g , _c , _c , _c , _c , _c , _c , _c , _g , _y , _ov, _c , _g , _ov, _c , _ov, _c ],
      [_ov, _c , _ov, _c , _ov, _c , _ov, _g , _y , _ov, _ov, _ov, _ov, _ov, _ov, _ov, _y , _g , _g , _ov, _c , _ov, _c , _ov, _c ],
      [_ov, _c , _ov, _c , _ov, _c , _ov, _c , _ov, _y , _g , _c , _c , _c , _g , _y , _ov, _c , _g , _ov, _c , _ov, _c , _ov, _c ],
      [_ov, _c , _ov, _c , _ov, _c , _ov, _c , _ov, _g , _y , _v , _v , _v , _y , _g , _g , _ov, _c , _ov, _c , _ov, _c , _ov, _c2],
      [_ov, _c , _ov, _c , _ov, _c , _ov, _c , _ov, _c , _v , _y , _v , _y , _v , _c , _g , _ov, _c , _ov, _c , _ov, _c , _ov, _c2],
      [_ov, _c , _ov, _c , _ov, _c , _ov, _c , _ov, _c , _v , _v , _y , _c , _v , _e , _c , _ov, _c , _ov, _c , _ov, _c , _ov, _c2],
      [_ov, _c , _ov, _c , _ov, _c , _ov, _c , _ov, _c , _v , _y , _v , _y , _c , _ov, _c , _ov, _c , _ov, _c , _ov, _c , _ov, _c ],
      [_ov, _c , _ov, _c , _ov, _c , _ov, _g , _c , _ov, _y , _c , _c , _c , _y , _ov, _c , _ov, _c , _ov, _c , _ov, _c , _ov, _c ],
      [_ov, _c , _ov, _c , _ov, _c , _ov, _g , _g , _y , _ov, _ov, _ov, _ov, _ov, _y , _g2, _ov, _c , _ov, _c , _ov, _c , _ov, _c ],
      [_ov, _c , _ov, _c , _ov, _g , _c , _ov, _y , _g , _c , _c , _c , _c , _c , _g2, _y , _ov, _c , _ov, _c , _ov, _c , _ov, _c ],
      [_ov, _c , _ov, _c , _ov, _g , _g , _y , _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _y , _g2, _ov, _c , _ov, _c , _ov, _c ],
      [_ov, _c , _ov, _g , _c , _ov, _y , _g , _c , _c , _c , _c , _c , _c , _c , _c , _c , _g2, _y , _ov, _c , _ov, _c , _ov, _c ],
      [_ov, _c , _ov, _PC, _g , _y , _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _y , _g2, _ov, _c , _ov, _c ],
      [_ov, _g , _c , _ov, _y , _g , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _g2, _y , _ov, _c , _ov, _c ],
      [_ov, _g , _g , _y2, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _y2, _g2, _ov, _c ],
      [_g , _ov, _y , _g , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _PB, _y , _ov, _c ],
      [_g , _y , _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _y , _c ],
      [_y , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _y ],
    ],
    inventory: const [
      // C — 6 pigs → sum 242 exact
      PiggyBundle(color: PiggyColor.cyan,   ammo: 40),
      PiggyBundle(color: PiggyColor.orange, ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 30),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 40),
      PiggyBundle(color: PiggyColor.orange, ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo: 30),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 40),
      PiggyBundle(color: PiggyColor.orange, ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 40),
      PiggyBundle(color: PiggyColor.orange, ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 40), // C 5×40=200
      PiggyBundle(color: PiggyColor.orange, ammo: 40), // O 5×40=200
      PiggyBundle(color: PiggyColor.purple, ammo: 40), // P 5×40=200
      PiggyBundle(color: PiggyColor.cyan,   ammo: 42), // C sum = 242 ✓
      PiggyBundle(color: PiggyColor.yellow, ammo: 23), // Y sum = 53 ✓
      PiggyBundle(color: PiggyColor.green,  ammo: 27), // G sum = 57 ✓
      PiggyBundle(color: PiggyColor.orange, ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.orange, ammo: 31), // O sum = 271 ✓
      PiggyBundle(color: PiggyColor.purple, ammo: 42), // P sum = 282 ✓
    ],
    targetLaunches: 24,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 3,
    expectedCombos: 2,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.orange, PiggyColor.purple,
    ],
    piggySpeed: 480,
    spawnInterval: 0.7,
  ),

  // L30 — 🏛 «Крепость» (Aleksey Grid Lab, 25×25, 31 pigs).
  //
  //   605 destructible + 16 stones. 2 portal-пары (B/C).
  //   Многослойная симметрия: верхняя половина — концентрическая крепость
  //   из _p2 (pink armor) с вставками _g2/_y2/_v2 armor + _o/_v одиночек +
  //   _pc и мини-камерами. Нижняя — сплошной _gy/_ov/_vo/_pc weave вокруг
  //   каменной перемычки (16 _S по центру).
  //
  //   Точный подсчёт shots per color:
  //     C = 8 (_c) + 33 (_pc inner) = 41
  //     P = 132×2 (_p2 armor) + 33 (_pc outer) = 297
  //     Y = 69 (_y) + 60×2 (_y2 armor) + 2 (_yg outer) + 72 (_gy inner) = 263
  //     G = 27×2 (_g2 armor) + 2 (_yg inner) + 72 (_gy outer) = 128
  //     V = 26 (_v) + 46×2 (_v2 armor) + 39 (_ov inner) + 35 (_vo outer) = 192
  //     O = 56 (_o) + 39 (_ov outer) + 35 (_vo inner) = 130
  //     Filter: 16 stones (каменная перемычка row 15-16)
  //   Total normal = 1051 shots.
  //
  //   Inventory (31 pigs, exact ammo). Filter в позиции 7 — открывает
  //   каменный проход к нижней половине. Мелкие «finish»-pigs (G 8, O 10,
  //   V 32, Y 23, P 17, C 21) стоят в конце — жёсткое no-waste в
  //   финальной чистке.
  //     C ×  2 : 20 + 21 = 41
  //     P ×  8 : 40×7 + 17 = 297
  //     Y ×  7 : 40×6 + 23 = 263
  //     G ×  4 : 40×3 + 8 = 128
  //     V ×  5 : 40×4 + 32 = 192
  //     O ×  4 : 40×3 + 10 = 130
  //     FILTER × 1 : 16
  //
  //   Portals:
  //     _PB : (r=1,c=12) ↔ (r=16,c=8) — вертикальный shortcut через
  //           каменную перемычку.
  //     _PC : (r=0,c=24) ↔ (r=24,c=0) — по главной диагонали, corner-to-corner.
  //
  //   Par: 31 launches (все pigs used).
  LevelConfig(
    levelNumber: 30,
    grid: [
      [_v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _PC],
      [_p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _v , _PB, _v , _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2],
      [_p2, _p2, _p2, _p2, _p2, _p2, _g2, _g2, _p2, _p2, _p2, _y2, _y2, _y2, _p2, _p2, _p2, _g2, _g2, _p2, _p2, _p2, _p2, _p2, _p2],
      [_p2, _p2, _g2, _g2, _g2, _g2, _g2, _o , _o , _o , _p2, _y2, _y2, _y2, _p2, _o , _o , _o , _g2, _g2, _g2, _g2, _g2, _p2, _p2],
      [_p2, _p2, _g2, _g2, _g2, _g2, _v2, _v2, _v2, _o , _p2, _y2, _y2, _y2, _p2, _o , _v2, _v2, _v2, _g2, _g2, _g2, _g2, _p2, _p2],
      [_p2, _g2, _g2, _pc, _y , _y , _y , _pc, _v2, _o , _p2, _y2, _y2, _y2, _p2, _o , _v2, _pc, _y , _y , _y , _pc, _g2, _g2, _p2],
      [_p2, _o , _v2, _pc, _y , _c , _y , _pc, _v2, _o , _p2, _y2, _y2, _y2, _p2, _o , _v2, _pc, _y , _c , _y , _pc, _v2, _o , _p2],
      [_p2, _o , _v2, _pc, _y , _c , _y , _pc, _v2, _o , _p2, _y2, _y2, _y2, _p2, _o , _v2, _pc, _y , _c , _y , _pc, _v2, _o , _p2],
      [_p2, _o , _v2, _p2, _y , _c , _y , _p2, _v2, _o , _p2, _y2, _y2, _y2, _p2, _o , _v2, _p2, _y , _c , _y , _p2, _v2, _o , _p2],
      [_p2, _o , _v2, _p2, _y , _c , _y , _p2, _v2, _o , _p2, _y2, _y2, _y2, _p2, _o , _v2, _p2, _y , _c , _y , _p2, _v2, _o , _p2],
      [_p2, _o , _v2, _p2, _y , _y , _y , _p2, _v2, _o , _p2, _y2, _y2, _y2, _p2, _o , _v2, _p2, _y , _y , _y , _p2, _v2, _o , _p2],
      [_p2, _o , _v2, _p2, _p2, _p2, _p2, _p2, _v2, _o , _p2, _y2, _y2, _y2, _p2, _o , _v2, _p2, _p2, _p2, _p2, _p2, _v2, _o , _p2],
      [_p2, _o , _v2, _v2, _v2, _v2, _v2, _v2, _v2, _o , _p2, _ov, _vo, _ov, _p2, _o , _v2, _v2, _v2, _v2, _v2, _v2, _v2, _o , _p2],
      [_p2, _o , _o , _o , _o , _o , _o , _o , _o , _o , _p2, _ov, _vo, _ov, _p2, _o , _o , _o , _o , _o , _o , _o , _o , _o , _p2],
      [_p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _ov, _vo, _ov, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2],
      [_y2, _y2, _y2, _y2, _y2, _y2, _y2, _S , _S , _S , _S , _ov, _vo, _ov, _S , _S , _S , _S , _y2, _y2, _y2, _y2, _y2, _y2, _y2],
      [_y2, _y , _y , _ov, _ov, _ov, _ov, _ov, _PB, _S , _S , _S , _S , _S , _S , _S , _S , _ov, _ov, _ov, _ov, _ov, _y , _y , _y2],
      [_y2, _y , _ov, _ov, _gy, _gy, _gy, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _gy, _gy, _gy, _ov, _ov, _y , _y2],
      [_y2, _y , _ov, _gy, _gy, _pc, _gy, _gy, _ov, _ov, _gy, _gy, _gy, _gy, _gy, _ov, _ov, _gy, _gy, _pc, _gy, _gy, _ov, _y , _y2],
      [_y2, _y , _gy, _gy, _pc, _yg, _pc, _gy, _gy, _gy, _gy, _pc, _gy, _pc, _gy, _gy, _gy, _gy, _pc, _yg, _pc, _gy, _gy, _y , _y2],
      [_y2, _y , _gy, _pc, _gy, _gy, _gy, _pc, _gy, _gy, _pc, _gy, _pc, _gy, _pc, _gy, _gy, _pc, _gy, _gy, _gy, _pc, _gy, _y , _y2],
      [_y2, _y , _gy, _pc, _gy, _vo, _gy, _gy, _pc, _pc, _gy, _gy, _vo, _gy, _gy, _pc, _pc, _gy, _gy, _vo, _gy, _pc, _gy, _y , _y2],
      [_y2, _y , _gy, _gy, _gy, _vo, _vo, _gy, _gy, _gy, _gy, _vo, _vo, _vo, _gy, _gy, _gy, _gy, _vo, _vo, _gy, _gy, _gy, _y , _y2],
      [_y2, _y , _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _y , _y2],
      [_PC, _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _g2],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 20),
      PiggyBundle(color: PiggyColor.pink,   ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.orange, ammo: 40),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 16, type: PiggyType.filter),
      PiggyBundle(color: PiggyColor.pink,   ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.orange, ammo: 40),
      PiggyBundle(color: PiggyColor.pink,   ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.orange, ammo: 40),
      PiggyBundle(color: PiggyColor.pink,   ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo:  8), // G sum = 128 ✓
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.orange, ammo: 10), // O sum = 130 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 32), // V sum = 192 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.pink,   ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 23), // Y sum = 263 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 17), // P sum = 297 ✓
      PiggyBundle(color: PiggyColor.cyan,   ammo: 21), // C sum = 41 ✓
    ],
    targetLaunches: 31,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 4,
    expectedCombos: 3,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.orange, PiggyColor.purple,
    ],
    piggySpeed: 480,
    spawnInterval: 0.65,
  ),

  // L31 — 🌌 «Сингулярность» (Aleksey Grid Lab, 40×25, 38 pigs).
  //
  //   836 destructible + 0 stones. 3 portal-пары (_PA/_PB/_PC).
  //   40 rows × 25 cols — самый вытянутый уровень в игре. Три композиционные
  //   зоны: верх (спираль _o/_v/_c2 + ядро armor из _p2/_g2/_v2), середина
  //   (сплошная _g2 стена row 12), низ (пиксель-арт "лица" из _p/_y/_v2/_y2
  //   + мандала-цепь _pc/_yg/_ov в самом низу).
  //
  //   Точный подсчёт shots per color:
  //     C = 98 (_c) + 57×2 (_c2) + 80 (_pc inner) + 9 (_cp outer) = 301
  //     P = 24 (_p) + 38×2 (_p2) + 80 (_pc outer) + 9 (_cp inner) + 4 (_shiftYOP) = 193
  //     Y = 14 (_y) + 90×2 (_y2) + 31 (_yg outer) + 24 (_gy inner) + 4 (_shiftYOP) = 253
  //     G = 93×2 (_g2) + 31 (_yg inner) + 24 (_gy outer) = 241
  //     V = 38 (_v) + 83×2 (_v2) + 55 (_ov inner) = 259
  //     O = 98 (_o) + 55 (_ov outer) + 4 (_shiftYOP) = 157
  //   Total = 1404 shots.
  //
  //   Inventory (38 pigs, exact ammo). Порядок — round-robin C/O/V/Y/G/P
  //   с постепенной убылью O (только 4 pigs) и P (5 pigs).
  //     C ×  8 : 40×7 + 21 = 301
  //     P ×  5 : 40×4 + 33 = 193
  //     Y ×  7 : 40×6 + 13 = 253
  //     G ×  7 : 40×6 + 1  = 241
  //     V ×  7 : 40×6 + 19 = 259
  //     O ×  4 : 40×3 + 37 = 157
  //
  //   Portals:
  //     _PA : (r=8,c=8)  ↔ (r=17,c=16) — вертикальный shortcut через ядро.
  //     _PB : (r=8,c=16) ↔ (r=30,c=9)  — из верхнего ядра в нижнюю мандалу.
  //     _PC : (r=4,c=7)  ↔ (r=34,c=1)  — по диагонали через всё поле.
  //
  //   Par: 38 launches (все pigs used). Скорость снижена (piggySpeed=440)
  //   т.к. поле сильно вытянуто — cellSize ~28px, каденс сохранён.
  LevelConfig(
    levelNumber: 31,
    grid: [
      [_c2, _o , _v , _v , _o , _e , _e , _e , _e , _e , _e , _o , _g2, _o , _e , _e , _e , _e , _e , _e , _o , _v , _v , _o , _c2],
      [_o , _c2, _o , _v , _v , _o , _c , _c , _c , _c , _o , _g2, _g2, _g2, _o , _c , _c , _c , _c , _o , _v , _v , _o , _c2, _o ],
      [_v , _o , _c2, _o , _v , _v , _o , _c , _c , _o , _g2, _p2, _g2, _p2, _g2, _o , _c , _c , _o , _v , _v , _o , _c2, _o , _v ],
      [_v , _v , _o , _c2, _o , _v , _v , _o , _o , _g2, _p2, _p2, _g2, _p2, _p2, _g2, _o , _o , _v , _v , _o , _c2, _o , _v , _v ],
      [_e , _v , _v , _o , _c2, _o , _v , _PC, _g2, _p2, _p2, _v2, _g2, _v2, _p2, _p2, _g2, _shiftYOP, _v , _o , _c2, _o , _v , _v , _e ],
      [_e , _c , _v , _v , _o , _c2, _o , _g2, _p2, _p2, _v2, _v2, _g2, _v2, _v2, _p2, _p2, _g2, _o , _c2, _o , _v , _v , _c , _e ],
      [_e , _o , _c , _v , _v , _o , _g2, _p2, _p2, _v2, _c , _v2, _g2, _v2, _c , _v2, _p2, _p2, _g2, _o , _v , _v , _c , _o , _e ],
      [_e , _y , _o , _c , _v , _g2, _p2, _p2, _v2, _c , _c , _v2, _g2, _v2, _c , _c , _v2, _p2, _p2, _g2, _v , _c , _o , _y , _e ],
      [_e , _y , _o , _c , _g2, _p2, _p2, _v2, _PA, _c , _c , _v2, _g2, _v2, _c , _c , _PB, _v2, _p2, _p2, _g2, _c , _o , _y , _e ],
      [_e , _o , _c , _g2, _p2, _p2, _v2, _c , _c , _c , _c , _v2, _g2, _v2, _c , _c , _c , _c , _v2, _p2, _p2, _g2, _c , _o , _e ],
      [_e , _c , _g2, _p2, _p2, _v2, _c , _c , _c , _c , _c , _v2, _g2, _v2, _c , _c , _c , _c , _c , _v2, _p2, _p2, _g2, _c , _e ],
      [_e , _g2, _p2, _p2, _v2, _c , _c , _c , _c , _c , _c , _v2, _g2, _v2, _c , _c , _c , _c , _c , _c , _v2, _p2, _p2, _g2, _e ],
      [_g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2],
      [_p , _g2, _o , _c2, _gy, _o , _o , _o , _o , _o , _o , _c2, _g2, _c2, _o , _o , _o , _o , _o , _o , _gy, _c2, _o , _g2, _p ],
      [_e , _p , _g2, _o , _c2, _gy, _o , _o , _o , _o , _o , _c2, _g2, _c2, _o , _o , _o , _o , _o , _gy, _c2, _o , _g2, _p , _e ],
      [_e , _y , _p , _g2, _o , _c2, _gy, _o , _o , _o , _o , _c2, _g2, _c2, _o , _o , _o , _o , _gy, _c2, _o , _g2, _p , _y , _e ],
      [_e , _cp, _y , _p , _g2, _o , _c2, _gy, _gy, _gy, _gy, _c2, _g2, _c2, _gy, _gy, _gy, _gy, _c2, _o , _g2, _p , _y , _cp, _e ],
      [_e , _cp, _cp, _y , _p , _g2, _o , _c2, _c2, _gy, _gy, _c2, _g2, _c2, _gy, _gy, _PA, _c2, _o , _g2, _p , _y , _cp, _cp, _e ],
      [_e , _cp, _y , _v2, _y2, _p , _g2, _o , _c2, _gy, _gy, _c2, _g2, _c2, _gy, _gy, _c2, _o , _g2, _p , _y2, _v2, _y , _cp, _e ],
      [_e , _y , _v2, _y2, _y2, _c2, _p , _g2, _o , _c2, _gy, _c2, _g2, _c2, _gy, _c2, _o , _g2, _p , _c2, _y2, _y2, _v2, _y , _e ],
      [_e , _v2, _y2, _y2, _c2, _y2, _y2, _p , _g2, _o , _c2, _c2, _g2, _c2, _c2, _o , _g2, _p , _y2, _y2, _c2, _y2, _y2, _v2, _e ],
      [_v2, _y2, _y2, _c2, _y2, _y2, _v2, _c , _p , _g2, _o , _c2, _g2, _c2, _o , _g2, _p , _c , _v2, _y2, _y2, _c2, _y2, _y2, _v2],
      [_y2, _y2, _c2, _y2, _y2, _v2, _e , _c , _e , _p , _g2, _o , _g2, _o , _g2, _p , _e , _c , _e , _v2, _y2, _y2, _c2, _y2, _y2],
      [_y2, _c2, _y2, _y2, _v2, _e , _e , _c , _e , _e , _p , _g2, _g2, _g2, _p , _e , _e , _c , _e , _e , _v2, _y2, _y2, _c2, _y2],
      [_y2, _y2, _y2, _v2, _e , _e , _e , _c , _shiftYOP, _e , _e , _p , _g2, _p , _e , _e , _shiftYOP, _c , _e , _e , _e , _v2, _y2, _y2, _y2],
      [_y2, _y2, _y2, _v2, _e , _e , _e , _c , _e , _e , _e , _y2, _y2, _y2, _e , _e , _e , _c , _e , _e , _e , _v2, _y2, _y2, _y2],
      [_v2, _v2, _v2, _v2, _e , _e , _c , _c , _c , _y2, _y2, _pc, _yg, _pc, _y2, _y2, _c , _c , _c , _e , _e , _v2, _v2, _v2, _v2],
      [_e , _e , _e , _e , _c , _c , _c , _y2, _y2, _pc, _pc, _pc, _yg, _pc, _pc, _pc, _y2, _y2, _c , _c , _c , _e , _e , _e , _e ],
      [_e , _e , _c , _c , _c , _y2, _y2, _pc, _pc, _pc, _pc, _pc, _yg, _pc, _pc, _pc, _pc, _pc, _y2, _y2, _c , _c , _c , _e , _e ],
      [_c , _c , _c , _y2, _y2, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _yg, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _y2, _y2, _c , _c , _c ],
      [_y2, _y2, _y2, _pc, _pc, _pc, _pc, _pc, _pc, _PB, _pc, _pc, _yg, _pc, _pc, _cp, _pc, _pc, _pc, _pc, _pc, _pc, _y2, _y2, _y2],
      [_e , _e , _e , _y2, _y2, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _yg, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _y2, _y2, _e , _e , _e ],
      [_e , _e , _e , _e , _e , _y2, _y2, _pc, _pc, _pc, _pc, _pc, _yg, _pc, _pc, _pc, _pc, _pc, _y2, _y2, _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _y2, _y2, _pc, _pc, _pc, _yg, _pc, _pc, _pc, _y2, _y2, _e , _e , _e , _e , _e , _e , _e ],
      [_e , _PC, _e , _e , _e , _e , _e , _e , _e , _y2, _y2, _pc, _yg, _pc, _y2, _y2, _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_shiftYOP, _ov, _yg, _ov, _yg, _ov, _yg, _ov, _yg, _ov, _yg, _ov, _y2, _ov, _yg, _ov, _yg, _ov, _yg, _ov, _yg, _ov, _yg, _ov, _e ],
      [_ov, _yg, _ov, _yg, _ov, _yg, _ov, _yg, _ov, _yg, _ov, _yg, _ov, _yg, _ov, _yg, _ov, _yg, _ov, _yg, _ov, _yg, _ov, _yg, _ov],
      [_v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2],
      [_ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _v2, _ov, _ov, _ov, _v2, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov],
      [_e , _e , _e , _e , _e , _e , _e , _e , _e , _ov, _ov, _ov, _ov, _ov, _ov, _ov, _e , _e , _e , _e , _e , _e , _e , _e , _e ],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 40),
      PiggyBundle(color: PiggyColor.orange, ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo: 40),
      PiggyBundle(color: PiggyColor.pink,   ammo: 40),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 40),
      PiggyBundle(color: PiggyColor.orange, ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo: 40),
      PiggyBundle(color: PiggyColor.pink,   ammo: 40),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 40),
      PiggyBundle(color: PiggyColor.orange, ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo: 40),
      PiggyBundle(color: PiggyColor.pink,   ammo: 40),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 40),
      PiggyBundle(color: PiggyColor.orange, ammo: 37), // O sum = 157 ✓
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo: 40),
      PiggyBundle(color: PiggyColor.pink,   ammo: 40),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo: 40),
      PiggyBundle(color: PiggyColor.pink,   ammo: 33), // P sum = 193 ✓
      PiggyBundle(color: PiggyColor.cyan,   ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo: 40),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 19), // V sum = 259 ✓
      PiggyBundle(color: PiggyColor.yellow, ammo: 13), // Y sum = 253 ✓
      PiggyBundle(color: PiggyColor.green,  ammo:  1), // G sum = 241 ✓
      PiggyBundle(color: PiggyColor.cyan,   ammo: 21), // C sum = 301 ✓
    ],
    targetLaunches: 38,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 5,
    expectedCombos: 4,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.orange, PiggyColor.purple,
    ],
    piggySpeed: 440,
    spawnInterval: 0.65,
  ),

  // L32 — 🔮 «Радужный тор» (Aleksey Grid Lab, 30×30, 39 pigs).
  //
  //   900 destructible + 0 stones. Портал-пар нет. Радиально-симметричный
  //   тор из концентрических колец: наружная рама _g2/_p2/_y (3 слоя),
  //   середина — восьмилучевая звезда из _cp/_yg/_gy/_ov/_vo с ядром
  //   _shiftYOP (92 блока, каждый = 1 Y + 1 O + 1 P). Центр держат два
  //   квадрата _v2 и «перекрёстные» ленты _p2/_o.
  //
  //   Точный подсчёт shots per color:
  //     C = 64 (_cp inner) = 64
  //     P = 320 (_p2×2) + 64 (_cp outer) + 92 (_shiftYOP state 2) = 476
  //     Y = 112 (_y) + 56 (_yg outer) + 48 (_gy inner) + 92 (_shiftYOP state 0) = 308
  //     G = 112 (_g2×2) + 56 (_yg inner) + 48 (_gy outer) = 216
  //     V = 80 (_v2×2) + 184 (_ov inner) + 48 (_vo outer) = 312
  //     O = 40 (_o) + 184 (_ov outer) + 48 (_vo inner) + 92 (_shiftYOP state 1) = 364
  //   Total = 1740 shots.
  //
  //   Inventory (39 pigs, exact ammo, ~50 avg). Round-robin C/O/V/Y/G/P
  //   с finish-пигами в конце.
  //     C ×  2 : 32 + 32 = 64
  //     O ×  8 : 50×7 + 14 = 364
  //     V ×  7 : 50×6 + 12 = 312
  //     Y ×  7 : 50×6 + 8  = 308
  //     G ×  5 : 50×4 + 16 = 216
  //     P × 10 : 50×9 + 26 = 476
  //
  //   Par: 39 launches (все pigs used). piggySpeed=440 (клетка ~50px на
  //   30-cell гриде — тот же каденс что L30-31).
  LevelConfig(
    levelNumber: 32,
    grid: [
      [_g2, _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _g2],
      [_y , _g2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _g2, _y ],
      [_y , _p2, _g2, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _g2, _p2, _y ],
      [_y , _p2, _ov, _g2, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _g2, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _g2, _cp, _cp, _cp, _cp, _cp, _o , _o , _o , _o , _o , _o , _o , _o , _o , _o , _cp, _cp, _cp, _cp, _cp, _g2, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _yg, _g2, _cp, _cp, _cp, _cp, _vo, _vo, _vo, _vo, _o , _o , _vo, _vo, _vo, _vo, _cp, _cp, _cp, _cp, _g2, _yg, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _yg, _yg, _g2, _cp, _cp, _cp, _vo, _vo, _vo, _vo, _o , _o , _vo, _vo, _vo, _vo, _cp, _cp, _cp, _g2, _yg, _yg, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _yg, _yg, _yg, _g2, _cp, _cp, _vo, _vo, _vo, _vo, _o , _o , _vo, _vo, _vo, _vo, _cp, _cp, _g2, _yg, _yg, _yg, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _yg, _yg, _yg, _yg, _g2, _cp, _shiftYOP, _p2, _p2, _p2, _o , _o , _p2, _p2, _p2, _shiftYOP, _cp, _g2, _yg, _yg, _yg, _yg, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _yg, _yg, _yg, _yg, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _p2, _p2, _o , _o , _p2, _p2, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _yg, _yg, _yg, _yg, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _v2, _gy, _gy, _gy, _shiftYOP, _shiftYOP, _g2, _shiftYOP, _shiftYOP, _p2, _p2, _p2, _p2, _shiftYOP, _shiftYOP, _g2, _shiftYOP, _shiftYOP, _gy, _gy, _gy, _v2, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _v2, _gy, _gy, _gy, _p2, _shiftYOP, _shiftYOP, _g2, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _g2, _shiftYOP, _shiftYOP, _p2, _gy, _gy, _gy, _v2, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _v2, _gy, _gy, _gy, _p2, _p2, _shiftYOP, _shiftYOP, _g2, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _g2, _shiftYOP, _shiftYOP, _p2, _p2, _gy, _gy, _gy, _v2, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _v2, _gy, _gy, _gy, _p2, _p2, _p2, _shiftYOP, _cp, _g2, _shiftYOP, _shiftYOP, _g2, _cp, _shiftYOP, _p2, _p2, _p2, _gy, _gy, _gy, _v2, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _v2, _v2, _v2, _v2, _v2, _v2, _p2, _shiftYOP, _shiftYOP, _shiftYOP, _g2, _g2, _shiftYOP, _shiftYOP, _shiftYOP, _p2, _v2, _v2, _v2, _v2, _v2, _v2, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _v2, _v2, _v2, _v2, _v2, _v2, _p2, _shiftYOP, _shiftYOP, _shiftYOP, _g2, _g2, _shiftYOP, _shiftYOP, _shiftYOP, _p2, _v2, _v2, _v2, _v2, _v2, _v2, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _v2, _gy, _gy, _gy, _p2, _p2, _p2, _shiftYOP, _cp, _g2, _shiftYOP, _shiftYOP, _g2, _cp, _shiftYOP, _p2, _p2, _p2, _gy, _gy, _gy, _v2, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _v2, _gy, _gy, _gy, _p2, _p2, _shiftYOP, _shiftYOP, _g2, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _g2, _shiftYOP, _shiftYOP, _p2, _p2, _gy, _gy, _gy, _v2, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _v2, _gy, _gy, _gy, _p2, _shiftYOP, _shiftYOP, _g2, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _g2, _shiftYOP, _shiftYOP, _p2, _gy, _gy, _gy, _v2, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _v2, _gy, _gy, _gy, _shiftYOP, _shiftYOP, _g2, _shiftYOP, _shiftYOP, _p2, _p2, _p2, _p2, _shiftYOP, _shiftYOP, _g2, _shiftYOP, _shiftYOP, _gy, _gy, _gy, _v2, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _yg, _yg, _yg, _yg, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _p2, _p2, _o , _o , _p2, _p2, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _yg, _yg, _yg, _yg, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _yg, _yg, _yg, _yg, _g2, _cp, _shiftYOP, _p2, _p2, _p2, _o , _o , _p2, _p2, _p2, _shiftYOP, _cp, _g2, _yg, _yg, _yg, _yg, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _yg, _yg, _yg, _g2, _cp, _cp, _vo, _vo, _vo, _vo, _o , _o , _vo, _vo, _vo, _vo, _cp, _cp, _g2, _yg, _yg, _yg, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _yg, _yg, _g2, _cp, _cp, _cp, _vo, _vo, _vo, _vo, _o , _o , _vo, _vo, _vo, _vo, _cp, _cp, _cp, _g2, _yg, _yg, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _yg, _g2, _cp, _cp, _cp, _cp, _vo, _vo, _vo, _vo, _o , _o , _vo, _vo, _vo, _vo, _cp, _cp, _cp, _cp, _g2, _yg, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _ov, _g2, _cp, _cp, _cp, _cp, _cp, _o , _o , _o , _o , _o , _o , _o , _o , _o , _o , _cp, _cp, _cp, _cp, _cp, _g2, _ov, _ov, _p2, _y ],
      [_y , _p2, _ov, _g2, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _g2, _ov, _p2, _y ],
      [_y , _p2, _g2, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _g2, _p2, _y ],
      [_y , _g2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _g2, _y ],
      [_g2, _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _g2],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 32),
      PiggyBundle(color: PiggyColor.orange, ammo: 50),
      PiggyBundle(color: PiggyColor.purple, ammo: 50),
      PiggyBundle(color: PiggyColor.yellow, ammo: 50),
      PiggyBundle(color: PiggyColor.green,  ammo: 50),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 32), // C sum = 64 ✓
      PiggyBundle(color: PiggyColor.orange, ammo: 50),
      PiggyBundle(color: PiggyColor.purple, ammo: 50),
      PiggyBundle(color: PiggyColor.yellow, ammo: 50),
      PiggyBundle(color: PiggyColor.green,  ammo: 50),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.orange, ammo: 50),
      PiggyBundle(color: PiggyColor.purple, ammo: 50),
      PiggyBundle(color: PiggyColor.yellow, ammo: 50),
      PiggyBundle(color: PiggyColor.green,  ammo: 50),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.orange, ammo: 50),
      PiggyBundle(color: PiggyColor.purple, ammo: 50),
      PiggyBundle(color: PiggyColor.yellow, ammo: 50),
      PiggyBundle(color: PiggyColor.green,  ammo: 50),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.orange, ammo: 50),
      PiggyBundle(color: PiggyColor.purple, ammo: 50),
      PiggyBundle(color: PiggyColor.yellow, ammo: 50),
      PiggyBundle(color: PiggyColor.green,  ammo: 16), // G sum = 216 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.orange, ammo: 50),
      PiggyBundle(color: PiggyColor.purple, ammo: 50),
      PiggyBundle(color: PiggyColor.yellow, ammo: 50),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.orange, ammo: 50),
      PiggyBundle(color: PiggyColor.purple, ammo: 12), // V sum = 312 ✓
      PiggyBundle(color: PiggyColor.yellow, ammo:  8), // Y sum = 308 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.orange, ammo: 14), // O sum = 364 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.pink,   ammo: 26), // P sum = 476 ✓
    ],
    targetLaunches: 39,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 6,
    expectedCombos: 4,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.orange, PiggyColor.purple,
    ],
    piggySpeed: 440,
    spawnInterval: 0.65,
  ),

  // L33 — 🌀 «Триспираль» (Aleksey Grid Lab, 30×30, 29 pigs).
  //
  //   870 destructible + 24 stones. **3 portal-пары** _PA/_PB/_PC.
  //   Асимметричная композиция: правый край — сплошной _p слой (189),
  //   центральный тор — _ov/_vo концентрика, две chamber-камеры _S+_v
  //   в углах, _shiftYOP полосы, _pc лента row 14-15.
  //
  //   Точный подсчёт shots per color:
  //     C = 84 (_c) + 60 (_pc inner) = 144
  //     P = 189 (_p) + 60 (_pc outer) + 42 (_shiftYOP state 2) = 291
  //     Y = 187 (_y) + 78 (_gy inner) + 42 (_shiftYOP state 0) = 307
  //     G = 78 (_gy outer) = 78
  //     V = 27 (_v) + 8×2 (_v2) + 117 (_ov inner) + 78 (_vo outer) = 238
  //     O = 117 (_ov outer) + 78 (_vo inner) + 42 (_shiftYOP state 1) = 237
  //     Filter: 24 stones (2 chamber-корпуса)
  //   Total = 1295 + 24 filter.
  //
  //   Portals:
  //     _PA : (r=7,c=9)  ↔ (r=29,c=7)
  //     _PB : (r=26,c=3) ↔ (r=29,c=29)
  //     _PC : (r=0,c=29) ↔ (r=12,c=1)
  //
  //   Par: 29 launches (все pigs used).
  LevelConfig(
    levelNumber: 33,
    grid: [
      [_p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _PC],
      [_c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p ],
      [_y , _y , _shiftYOP, _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _c , _c , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p ],
      [_y , _ov, _shiftYOP, _v , _v , _v , _v , _v , _v , _v , _v , _v , _S , _S , _S , _S , _S , _S , _y , _c , _c , _p , _p , _p , _p , _p , _p , _p , _p , _p ],
      [_y , _ov, _shiftYOP, _v , _v , _v , _v , _v , _v , _v , _v , _v , _S , _S , _S , _S , _S , _S , _y , _y , _c , _c , _p , _p , _p , _p , _p , _p , _p , _p ],
      [_y , _ov, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _y , _y , _c , _c , _p , _p , _p , _p , _p , _p , _p ],
      [_y , _gy, _shiftYOP, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _y , _y , _c , _c , _p , _p , _p , _p , _p , _p ],
      [_y , _y , _y , _y , _y , _y , _y , _y , _y , _PA, _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _c , _c , _p , _p , _p , _p , _p ],
      [_y , _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _y , _y , _c , _c , _p , _p , _p , _p ],
      [_y , _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _y , _y , _c , _c , _p , _p , _p ],
      [_y , _ov, _ov, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _ov, _ov, _y , _y , _c , _c , _p , _p ],
      [_y , _ov, _ov, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _ov, _ov, _ov, _y , _c , _c , _p ],
      [_y , _PC, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _y , _y , _c , _c ],
      [_y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _c ],
      [_pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc],
      [_pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc],
      [_y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _c ],
      [_y , _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _y , _y , _c , _c ],
      [_y , _ov, _ov, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _ov, _ov, _ov, _y , _c , _c , _p ],
      [_y , _ov, _ov, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _ov, _ov, _y , _y , _c , _c , _p , _p ],
      [_y , _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _y , _y , _c , _c , _p , _p , _p ],
      [_y , _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _y , _y , _c , _c , _p , _p , _p , _p ],
      [_y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _c , _c , _p , _p , _p , _p , _p ],
      [_y , _gy, _shiftYOP, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _y , _y , _c , _c , _p , _p , _p , _p , _p , _p ],
      [_y , _ov, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _y , _y , _c , _c , _p , _p , _p , _p , _p , _p , _p ],
      [_y , _ov, _shiftYOP, _v , _v , _v , _v , _v , _v , _v , _v , _v , _S , _S , _S , _S , _S , _S , _y , _y , _c , _c , _p , _p , _p , _p , _p , _p , _p , _p ],
      [_y , _ov, _shiftYOP, _PB, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _S , _S , _S , _S , _S , _S , _y , _c , _c , _p , _p , _p , _p , _p , _p , _p , _p , _p ],
      [_y , _y , _shiftYOP, _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _c , _c , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p ],
      [_c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p ],
      [_p , _p , _p , _p , _p , _p , _p , _PA, _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _PB],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 48),
      PiggyBundle(color: PiggyColor.orange, ammo: 48),
      PiggyBundle(color: PiggyColor.purple, ammo: 48),
      PiggyBundle(color: PiggyColor.yellow, ammo: 44),
      PiggyBundle(color: PiggyColor.green,  ammo: 39),
      PiggyBundle(color: PiggyColor.pink,   ammo: 48),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 48),
      PiggyBundle(color: PiggyColor.orange, ammo: 48),
      PiggyBundle(color: PiggyColor.purple, ammo: 48),
      PiggyBundle(color: PiggyColor.yellow, ammo: 44),
      PiggyBundle(color: PiggyColor.green,  ammo: 39), // G sum = 78 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 48),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 48), // C sum = 144 ✓
      PiggyBundle(color: PiggyColor.orange, ammo: 48),
      PiggyBundle(color: PiggyColor.purple, ammo: 48),
      PiggyBundle(color: PiggyColor.yellow, ammo: 44),
      PiggyBundle(color: PiggyColor.pink,   ammo: 48),
      PiggyBundle(color: PiggyColor.orange, ammo: 48),
      PiggyBundle(color: PiggyColor.purple, ammo: 48),
      PiggyBundle(color: PiggyColor.yellow, ammo: 44),
      PiggyBundle(color: PiggyColor.pink,   ammo: 48),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 24, type: PiggyType.filter), // 24 stones ✓
      PiggyBundle(color: PiggyColor.orange, ammo: 45), // O sum = 237 ✓
      PiggyBundle(color: PiggyColor.purple, ammo: 46), // V sum = 238 ✓
      PiggyBundle(color: PiggyColor.yellow, ammo: 44),
      PiggyBundle(color: PiggyColor.pink,   ammo: 48),
      PiggyBundle(color: PiggyColor.yellow, ammo: 44),
      PiggyBundle(color: PiggyColor.pink,   ammo: 51), // P sum = 291 ✓
      PiggyBundle(color: PiggyColor.yellow, ammo: 43), // Y sum = 307 ✓
    ],
    targetLaunches: 29,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 5,
    expectedCombos: 4,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.orange, PiggyColor.purple,
    ],
    piggySpeed: 440,
    spawnInterval: 0.65,
  ),

  // L34 — 🗺 «Архипелаг» (Aleksey Grid Lab, 30×40, 28 pigs).
  //
  //   568 destructible + 50 stones. Portal-пар нет. Разбросанные острова
  //   разной формы + 4 больших stone-щита требующих filter.
  //
  //   Точный подсчёт shots per color:
  //     C =  14 (_cp inner) + 104 (_pc inner) = 118
  //     P = 118×2 (_p2) + 104 (_pc outer) + 14 (_cp outer) = 354
  //     Y = 87×2 (_y2) + 18 (_yg outer) = 192
  //     G = 93×2 (_g2) + 18 (_yg inner) = 204
  //     V =  52 (_v) + 19×2 (_v2) + 63 (_ov inner) = 153
  //     O =  63 (_ov outer) = 63
  //     Filter: 50 stones
  //   Total = 1084 + 50 filter.
  //
  //   Portals: нет.
  //   Par: 28 launches (все pigs used).
  LevelConfig(
    levelNumber: 34,
    grid: [
      [_e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _p2, _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _g2, _g2, _e , _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _e , _e , _e , _p2, _e , _p2, _p2, _p2, _p2, _p2, _p2, _p2, _g2, _g2, _g2, _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _p2, _e , _e , _g2, _g2, _e , _e , _e , _e , _e , _e , _p2, _e , _e , _e , _e , _e , _e , _e , _e , _e , _p2, _p2, _p2, _p2, _g2, _p2, _g2, _p2, _e , _p2, _e , _e , _e , _e , _e ],
      [_e , _g2, _g2, _p2, _g2, _g2, _e , _g2, _e , _p2, _e , _p2, _S , _e , _p2, _e , _e , _y2, _e , _e , _e , _g2, _g2, _e , _e , _e , _S , _S , _S , _e , _e , _e , _p2, _g2, _e , _e , _p2, _e , _e , _e ],
      [_e , _e , _p2, _e , _p2, _g2, _g2, _S , _S , _S , _S , _S , _S , _S , _e , _e , _y2, _e , _e , _e , _g2, _e , _e , _e , _S , _S , _S , _e , _e , _S , _S , _e , _e , _e , _p2, _e , _g2, _e , _e , _e ],
      [_e , _p2, _e , _e , _g2, _p2, _S , _S , _e , _v , _v , _v , _v , _e , _S , _e , _y2, _y2, _e , _g2, _g2, _e , _S , _S , _e , _e , _v , _v , _e , _e , _S , _e , _e , _y2, _y2, _y2, _e , _g2, _e , _e ],
      [_e , _e , _e , _e , _p2, _p2, _S , _e , _v , _v , _v , _v , _v , _v , _S , _S , _e , _y2, _e , _e , _e , _S , _S , _e , _e , _v , _v , _v , _v , _v , _S , _S , _p2, _e , _y2, _y2, _p2, _g2, _e , _e ],
      [_e , _p2, _p2, _p2, _e , _S , _S , _e , _v , _e , _e , _e , _e , _v , _e , _S , _e , _y2, _g2, _e , _S , _e , _e , _e , _v , _e , _e , _e , _e , _v , _e , _S , _S , _e , _e , _y2, _p2, _g2, _e , _e ],
      [_e , _e , _e , _g2, _e , _S , _e , _v , _e , _yg, _yg, _yg, _e , _v , _e , _e , _y2, _g2, _g2, _e , _e , _e , _e , _v , _v , _e , _e , _yg, _e , _v , _e , _e , _S , _S , _e , _y2, _p2, _p2, _e , _e ],
      [_e , _e , _g2, _e , _e , _e , _e , _v , _e , _yg, _yg, _e , _v , _v , _e , _y2, _y2, _g2, _e , _e , _y2, _e , _v , _v , _yg, _yg, _yg, _yg, _e , _v , _e , _p2, _e , _S , _e , _y2, _e , _p2, _p2, _e ],
      [_e , _e , _g2, _g2, _pc, _e , _e , _v , _e , _yg, _yg, _v , _v , _y2, _y2, _y2, _e , _g2, _g2, _e , _y2, _y2, _v , _e , _yg, _yg, _yg, _e , _e , _v , _y2, _y2, _y2, _y2, _y2, _y2, _e , _p2, _e , _e ],
      [_e , _e , _e , _e , _pc, _pc, _pc, _e , _v , _e , _e , _v , _y2, _y2, _e , _g2, _e , _g2, _e , _e , _e , _y2, _v , _e , _yg, _yg, _yg, _e , _v , _y2, _y2, _e , _p2, _e , _e , _g2, _e , _p2, _e , _e ],
      [_e , _e , _e , _e , _e , _e , _pc, _e , _e , _v , _v , _e , _y2, _g2, _g2, _e , _e , _pc, _pc, _e , _y2, _e , _v , _v , _e , _e , _v , _v , _v , _y2, _e , _g2, _p2, _g2, _g2, _p2, _p2, _e , _e , _p2],
      [_e , _e , _g2, _e , _e , _e , _pc, _e , _pc, _pc, _e , _g2, _g2, _e , _pc, _pc, _pc, _e , _pc, _pc, _e , _pc, _e , _v , _v , _v , _v , _e , _y2, _e , _g2, _e , _e , _p2, _p2, _p2, _e , _e , _e , _e ],
      [_g2, _g2, _e , _g2, _e , _pc, _pc, _e , _e , _pc, _pc, _pc, _pc, _pc, _cp, _cp, _cp, _cp, _e , _pc, _pc, _pc, _ov, _ov, _e , _e , _ov, _e , _e , _e , _g2, _e , _e , _e , _e , _e , _e , _e , _e , _p2],
      [_e , _e , _e , _e , _ov, _ov, _e , _pc, _pc, _pc, _pc, _e , _e , _v2, _v2, _v2, _v2, _e , _cp, _cp, _e , _pc, _ov, _e , _e , _e , _e , _e , _ov, _e , _g2, _ov, _ov, _e , _ov, _ov, _e , _e , _p2, _e ],
      [_e , _e , _ov, _ov, _e , _ov, _e , _e , _g2, _g2, _g2, _pc, _e , _v2, _v2, _v2, _v2, _v2, _v2, _cp, _e , _pc, _e , _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _e , _e , _ov, _e , _ov, _e , _e , _e , _e ],
      [_y2, _y2, _y2, _e , _ov, _ov, _e , _e , _g2, _e , _e , _pc, _pc, _cp, _v2, _v2, _v2, _v2, _v2, _cp, _pc, _e , _ov, _ov, _ov, _ov, _ov, _ov, _e , _e , _g2, _e , _e , _ov, _e , _ov, _e , _e , _e , _e ],
      [_e , _e , _y2, _y2, _p2, _ov, _e , _e , _e , _g2, _g2, _e , _pc, _pc, _v2, _v2, _v2, _e , _cp, _cp, _pc, _e , _e , _e , _ov, _ov, _e , _e , _e , _g2, _g2, _e , _e , _e , _ov, _ov, _e , _p2, _e , _p2],
      [_e , _e , _p2, _y2, _p2, _ov, _ov, _e , _g2, _g2, _g2, _g2, _e , _pc, _pc, _v2, _cp, _cp, _cp, _pc, _pc, _e , _g2, _g2, _g2, _e , _g2, _g2, _e , _e , _e , _ov, _ov, _ov, _pc, _e , _e , _y2, _p2, _e ],
      [_e , _p2, _y2, _e , _pc, _e , _ov, _ov, _ov, _e , _e , _e , _g2, _e , _e , _pc, _e , _e , _pc, _pc, _e , _g2, _e , _e , _y2, _y2, _e , _e , _e , _y2, _y2, _ov, _e , _p2, _pc, _e , _y2, _e , _p2, _e ],
      [_e , _p2, _y2, _e , _pc, _p2, _e , _e , _e , _ov, _ov, _e , _g2, _e , _e , _pc, _pc, _pc, _pc, _e , _e , _g2, _y2, _y2, _e , _e , _y2, _e , _y2, _e , _ov, _e , _p2, _p2, _pc, _y2, _e , _e , _p2, _e ],
      [_e , _e , _y2, _e , _pc, _p2, _p2, _p2, _p2, _e , _e , _ov, _ov, _g2, _e , _e , _pc, _pc, _e , _e , _g2, _e , _e , _e , _ov, _ov, _ov, _ov, _ov, _ov, _ov, _e , _p2, _pc, _e , _y2, _e , _e , _p2, _e ],
      [_p2, _e , _y2, _e , _pc, _e , _e , _e , _S , _S , _p2, _e , _ov, _ov, _g2, _g2, _e , _e , _g2, _g2, _e , _e , _e , _e , _y2, _y2, _e , _y2, _y2, _y2, _e , _p2, _p2, _pc, _e , _y2, _e , _e , _p2, _e ],
      [_p2, _p2, _y2, _y2, _e , _pc, _pc, _e , _S , _e , _S , _S , _p2, _e , _ov, _e , _g2, _g2, _e , _e , _p2, _p2, _p2, _p2, _e , _e , _e , _p2, _p2, _p2, _p2, _e , _e , _e , _y2, _e , _p2, _e , _e , _p2],
      [_e , _p2, _p2, _y2, _e , _e , _pc, _pc, _e , _e , _S , _S , _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _e , _pc, _pc, _e , _pc, _pc, _p2, _p2, _e , _e , _e , _e , _pc, _pc, _y2, _e , _p2, _e , _e , _e ],
      [_e , _e , _p2, _e , _y2, _y2, _e , _pc, _pc, _pc, _e , _S , _e , _e , _e , _e , _pc, _e , _e , _e , _pc, _pc, _e , _e , _pc, _e , _e , _e , _e , _e , _e , _e , _pc, _e , _y2, _e , _p2, _p2, _e , _e ],
      [_e , _e , _p2, _e , _e , _y2, _y2, _e , _e , _pc, _pc, _S , _S , _S , _e , _pc, _e , _e , _e , _e , _pc, _e , _e , _pc, _pc, _e , _e , _e , _e , _e , _pc, _pc, _e , _e , _y2, _e , _p2, _p2, _p2, _e ],
      [_e , _e , _p2, _p2, _p2, _e , _e , _y2, _y2, _e , _pc, _pc, _e , _e , _e , _e , _pc, _e , _e , _e , _e , _pc, _pc, _e , _e , _e , _e , _e , _pc, _pc, _pc, _e , _e , _e , _y2, _y2, _y2, _y2, _y2, _y2],
      [_e , _e , _e , _e , _p2, _p2, _p2, _e , _e , _y2, _y2, _pc, _pc, _e , _e , _e , _pc, _pc, _pc, _pc, _pc, _e , _e , _e , _e , _e , _e , _pc, _pc, _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 40),
      PiggyBundle(color: PiggyColor.pink,   ammo: 44),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.orange, ammo: 32),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 40),
      PiggyBundle(color: PiggyColor.pink,   ammo: 44),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.pink,   ammo: 44),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 40),
      PiggyBundle(color: PiggyColor.orange, ammo: 31), // O sum = 63 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 44),
      PiggyBundle(color: PiggyColor.yellow, ammo: 40),
      PiggyBundle(color: PiggyColor.green,  ammo: 40),
      PiggyBundle(color: PiggyColor.purple, ammo: 33), // V sum = 153 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 44),
      PiggyBundle(color: PiggyColor.green,  ammo: 44), // G sum = 204 ✓
      PiggyBundle(color: PiggyColor.cyan,   ammo: 50, type: PiggyType.filter), // 50 stones ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 44),
      PiggyBundle(color: PiggyColor.yellow, ammo: 32), // Y sum = 192 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 44),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 38), // C sum = 118 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 46), // P sum = 354 ✓
    ],
    targetLaunches: 28,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 5,
    expectedCombos: 3,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.orange, PiggyColor.purple,
    ],
    piggySpeed: 400,
    spawnInterval: 0.65,
  ),

  // L35 — 🔺 «Триптих» (Aleksey Grid Lab, 40×30, 33 pigs).
  //
  //   895 destructible + 46 stones. 1 portal-пара _PC. Три архитектурные
  //   зоны: верх (Y2 крепость с V2 воротами), центр (три звёздных _yg
  //   камеры вокруг _pc фона), низ (_ov концентрика с _cp core + _gy
  //   основание).
  //
  //   Точный подсчёт shots per color:
  //     C =  68 (_c) + 191 (_pc inner) + 16 (_cp outer) = 275
  //     P =  88 (_p) + 191 (_pc outer) + 16 (_cp inner) = 295
  //     Y =  26 (_y) + 68×2 (_y2) + 54 (_yg outer) + 114 (_gy inner) = 330
  //     G =  36×2 (_g2) + 54 (_yg inner) + 114 (_gy outer) = 240
  //     V =  56 (_v) + 80×2 (_v2) + 72 (_ov inner) = 288
  //     O =  26 (_o) + 72 (_ov outer) = 98
  //     Filter: 46 stones
  //   Total = 1526 + 46 filter.
  //
  //   Portals:
  //     _PC : (r=15,c=6) ↔ (r=38,c=4) — вертикальный shortcut через
  //           три зоны.
  //   Par: 33 launches (все pigs used).
  LevelConfig(
    levelNumber: 35,
    grid: [
      [_v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v ],
      [_o , _o , _o , _o , _o , _o , _o , _o , _o , _o , _o , _o , _o , _g2, _g2, _g2, _g2, _o , _o , _o , _o , _o , _o , _o , _o , _o , _o , _o , _o , _o ],
      [_v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _g2, _y2, _y2, _g2, _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v , _v ],
      [_y , _y , _y , _e , _e , _y , _y , _y , _y , _y , _y , _y , _g2, _g2, _y2, _y2, _g2, _g2, _y , _y , _y , _y , _y , _y , _y , _e , _e , _y , _y , _y ],
      [_e , _e , _e , _y , _y , _y , _e , _e , _g2, _g2, _g2, _g2, _g2, _y2, _y2, _y2, _y2, _g2, _g2, _g2, _g2, _g2, _e , _e , _y , _y , _y , _e , _e , _e ],
      [_g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _e , _e , _y2, _y2, _y2, _y2, _e , _e , _y2, _y2, _y2, _y2, _e , _e , _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2],
      [_y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _S , _S , _S , _S , _S , _S , _S , _S , _S , _S , _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2],
      [_y2, _y2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _e , _e , _S , _S , _e , _e , _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _y2, _y2],
      [_v2, _v2, _v2, _c , _c , _c , _c , _c , _c , _c , _c , _c , _v2, _v2, _v2, _v2, _v2, _v2, _c , _c , _c , _c , _c , _c , _c , _c , _c , _v2, _v2, _v2],
      [_v2, _p , _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _p , _v2],
      [_p , _pc, _pc, _pc, _pc, _pc, _S , _S , _S , _S , _S , _S , _pc, _p , _y2, _y2, _p , _pc, _S , _S , _S , _S , _S , _S , _pc, _pc, _pc, _pc, _pc, _p ],
      [_p , _pc, _pc, _pc, _pc, _S , _yg, _yg, _yg, _yg, _S , _pc, _pc, _p , _p , _p , _p , _pc, _pc, _S , _yg, _yg, _yg, _yg, _S , _pc, _pc, _pc, _pc, _p ],
      [_p , _pc, _e , _pc, _S , _yg, _yg, _yg, _yg, _yg, _S , _pc, _pc, _pc, _p , _p , _pc, _pc, _pc, _S , _yg, _yg, _yg, _yg, _yg, _S , _pc, _e , _pc, _p ],
      [_p , _pc, _e , _pc, _S , _yg, _yg, _yg, _yg, _yg, _S , _S , _pc, _pc, _p , _p , _pc, _pc, _S , _S , _yg, _yg, _yg, _yg, _yg, _S , _pc, _e , _pc, _p ],
      [_p , _pc, _e , _pc, _pc, _yg, _yg, _yg, _yg, _yg, _yg, _S , _pc, _pc, _p , _p , _pc, _pc, _S , _yg, _yg, _yg, _yg, _yg, _yg, _pc, _pc, _e , _pc, _p ],
      [_p , _pc, _pc, _pc, _pc, _pc, _PC, _yg, _yg, _yg, _yg, _S , _S , _pc, _p , _p , _pc, _S , _S , _yg, _yg, _yg, _yg, _e , _pc, _pc, _pc, _pc, _pc, _p ],
      [_c , _p , _p , _pc, _pc, _pc, _pc, _pc, _yg, _yg, _yg, _S , _pc, _pc, _p , _p , _pc, _pc, _S , _yg, _yg, _yg, _pc, _e , _pc, _pc, _pc, _p , _p , _c ],
      [_c , _c , _p , _p , _p , _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _p , _p , _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _p , _p , _p , _c , _c ],
      [_e , _c , _c , _c , _p , _p , _p , _p , _pc, _pc, _pc, _pc, _pc, _p , _p , _p , _p , _pc, _pc, _pc, _pc, _pc, _p , _p , _p , _p , _c , _c , _c , _e ],
      [_gy, _e , _e , _c , _c , _c , _c , _c , _p , _p , _p , _p , _p , _p , _gy, _gy, _p , _p , _p , _p , _p , _p , _c , _c , _c , _c , _c , _e , _e , _gy],
      [_e , _gy, _e , _e , _e , _e , _e , _c , _c , _p , _p , _c , _c , _c , _gy, _gy, _c , _c , _c , _p , _p , _c , _c , _e , _e , _e , _e , _e , _gy, _e ],
      [_e , _e , _gy, _gy, _gy, _gy, _gy, _e , _c , _p , _p , _c , _e , _c , _gy, _gy, _c , _e , _c , _p , _p , _c , _e , _gy, _gy, _gy, _gy, _gy, _e , _e ],
      [_e , _e , _e , _e , _e , _e , _gy, _gy, _c , _c , _c , _c , _c , _c , _gy, _gy, _c , _c , _c , _c , _c , _c , _gy, _gy, _e , _e , _e , _e , _e , _e ],
      [_e , _e , _ov, _ov, _e , _e , _e , _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _e , _e , _e , _ov, _ov, _e , _e ],
      [_e , _e , _e , _e , _e , _ov, _ov, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _ov, _ov, _e , _e , _e , _e , _e ],
      [_pc, _pc, _pc, _pc, _e , _pc, _pc, _ov, _e , _e , _e , _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _e , _e , _e , _ov, _pc, _pc, _e , _pc, _pc, _pc, _pc],
      [_pc, _pc, _pc, _pc, _pc, _pc, _pc, _ov, _e , _e , _ov, _e , _ov, _ov, _ov, _ov, _ov, _ov, _e , _ov, _e , _e , _ov, _pc, _pc, _pc, _pc, _pc, _pc, _pc],
      [_pc, _pc, _pc, _pc, _pc, _pc, _pc, _ov, _ov, _ov, _ov, _ov, _e , _e , _e , _e , _e , _e , _ov, _ov, _ov, _ov, _ov, _pc, _pc, _pc, _pc, _pc, _pc, _pc],
      [_pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc, _pc],
      [_pc, _pc, _pc, _pc, _pc, _pc, _pc, _ov, _ov, _ov, _ov, _e , _e , _e , _e , _e , _e , _e , _e , _ov, _ov, _ov, _ov, _pc, _pc, _pc, _pc, _pc, _pc, _pc],
      [_pc, _pc, _pc, _pc, _ov, _ov, _ov, _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _ov, _ov, _ov, _pc, _pc, _pc, _pc],
      [_pc, _pc, _pc, _ov, _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _ov, _pc, _pc, _pc],
      [_ov, _ov, _ov, _e , _e , _e , _e , _e , _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _e , _e , _e , _e , _e , _ov, _ov, _ov],
      [_e , _e , _e , _e , _gy, _gy, _gy, _gy, _gy, _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _gy, _gy, _gy, _gy, _gy, _e , _e , _e , _e ],
      [_e , _e , _e , _e , _gy, _gy, _e , _e , _e , _v2, _v2, _v2, _v2, _v2, _e , _e , _v2, _v2, _v2, _v2, _v2, _e , _e , _e , _gy, _gy, _e , _e , _e , _e ],
      [_e , _e , _gy, _gy, _gy, _e , _e , _e , _v2, _v2, _p , _e , _e , _v2, _v2, _v2, _v2, _e , _e , _p , _v2, _v2, _e , _e , _e , _gy, _gy, _gy, _e , _e ],
      [_e , _gy, _gy, _gy, _e , _e , _e , _e , _v2, _e , _p , _p , _e , _e , _v2, _v2, _e , _e , _p , _p , _e , _v2, _e , _e , _e , _e , _gy, _gy, _gy, _e ],
      [_gy, _gy, _e , _e , _e , _e , _e , _e , _v2, _v2, _e , _e , _p , _e , _v2, _v2, _e , _p , _e , _e , _v2, _v2, _e , _e , _e , _e , _e , _e , _gy, _gy],
      [_gy, _gy, _v2, _v2, _PC, _v2, _v2, _v2, _v2, _v2, _v2, _v2, _e , _p , _p , _p , _p , _e , _v2, _v2, _v2, _v2, _v2, _v2, _v2, _e , _v2, _v2, _gy, _gy],
      [_gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _e , _e , _p , _p , _e , _e , _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 45),
      PiggyBundle(color: PiggyColor.orange, ammo: 49),
      PiggyBundle(color: PiggyColor.purple, ammo: 48),
      PiggyBundle(color: PiggyColor.yellow, ammo: 48),
      PiggyBundle(color: PiggyColor.green,  ammo: 48),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 45),
      PiggyBundle(color: PiggyColor.orange, ammo: 49), // O sum = 98 ✓
      PiggyBundle(color: PiggyColor.purple, ammo: 48),
      PiggyBundle(color: PiggyColor.yellow, ammo: 48),
      PiggyBundle(color: PiggyColor.green,  ammo: 48),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 45),
      PiggyBundle(color: PiggyColor.purple, ammo: 48),
      PiggyBundle(color: PiggyColor.yellow, ammo: 48),
      PiggyBundle(color: PiggyColor.green,  ammo: 48),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 45),
      PiggyBundle(color: PiggyColor.purple, ammo: 48),
      PiggyBundle(color: PiggyColor.yellow, ammo: 48),
      PiggyBundle(color: PiggyColor.green,  ammo: 48),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 45),
      PiggyBundle(color: PiggyColor.purple, ammo: 48),
      PiggyBundle(color: PiggyColor.yellow, ammo: 48),
      PiggyBundle(color: PiggyColor.green,  ammo: 48), // G sum = 240 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 46, type: PiggyType.filter), // 46 stones ✓
      PiggyBundle(color: PiggyColor.cyan,   ammo: 50), // C sum = 275 ✓
      PiggyBundle(color: PiggyColor.purple, ammo: 48), // V sum = 288 ✓
      PiggyBundle(color: PiggyColor.yellow, ammo: 48),
      PiggyBundle(color: PiggyColor.yellow, ammo: 42), // Y sum = 330 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 45), // P sum = 295 ✓
    ],
    targetLaunches: 33,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 5,
    expectedCombos: 4,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.orange, PiggyColor.purple,
    ],
    piggySpeed: 400,
    spawnInterval: 0.65,
  ),

  // L36 — 🕸 «Витражная мозаика» (Aleksey Grid Lab, 40×30, 29 pigs).
  //
  //   923 destructible + 0 stones. Portal-пар нет. Тройная симметрия:
  //   рамка _g/_gy/_vo, ажурная орнаментация из _vo/_o, центральное
  //   яйцо (top: _y+_g+_v+_c ядро, bottom: _v/_v2/_o лабиринт с _yg
  //   вставками). Малые вкрапления _c/_pc/_p как «жемчуг».
  //
  //   Точный подсчёт shots per color:
  //     C =   4 (_c) + 12×2 (_c2) + 2 (_pc) = 30
  //     P =  28 (_p) + 4×2 (_p2) + 2 (_pc) = 38
  //     Y = 183 (_y) + 55 (_yg outer) + 116 (_gy inner) = 354
  //     G =  78 (_g) + 55 (_yg inner) + 116 (_gy outer) = 249
  //     V =  50 (_v) + 50×2 (_v2) + 240 (_vo outer) = 390
  //     O = 101 (_o) + 240 (_vo inner) = 341
  //   Total = 1402 shots.
  //
  //   Portals: нет.
  //   Par: 29 launches.
  LevelConfig(
    levelNumber: 36,
    grid: [
      [_g , _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _g ],
      [_g , _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _g ],
      [_g , _e , _e , _e , _vo, _vo, _e , _e , _e , _vo, _vo, _e , _e , _e , _vo, _vo, _e , _e , _e , _vo, _vo, _e , _e , _e , _vo, _vo, _e , _e , _e , _g ],
      [_g , _e , _e , _vo, _vo, _e , _e , _o , _o , _e , _vo, _vo, _e , _e , _vo, _vo, _e , _e , _vo, _vo, _e , _o , _o , _e , _e , _vo, _vo, _e , _e , _g ],
      [_g , _e , _e , _vo, _e , _e , _o , _p , _p , _o , _e , _vo, _e , _e , _vo, _vo, _e , _e , _vo, _e , _o , _p , _p , _o , _e , _e , _vo, _e , _e , _g ],
      [_g , _g , _e , _vo, _e , _o , _p , _p , _p , _o , _e , _vo, _e , _e , _vo, _vo, _e , _e , _vo, _e , _o , _p , _p , _p , _o , _e , _vo, _e , _g , _g ],
      [_gy, _g , _vo, _vo, _e , _o , _p , _pc, _p , _o , _e , _e , _vo, _vo, _vo, _vo, _vo, _vo, _e , _e , _o , _p , _pc, _p , _o , _e , _vo, _vo, _g , _gy],
      [_gy, _g , _vo, _e , _e , _e , _o , _p , _p , _o , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _o , _p , _p , _o , _e , _e , _e , _vo, _g , _gy],
      [_gy, _g , _vo, _vo, _e , _e , _e , _o , _o , _o , _o , _o , _o , _o , _o , _o , _o , _o , _o , _o , _o , _o , _o , _e , _e , _e , _vo, _vo, _g , _gy],
      [_gy, _g , _e , _vo, _e , _e , _e , _e , _o , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _o , _e , _e , _e , _e , _vo, _e , _g , _gy],
      [_gy, _g , _e , _vo, _e , _e , _e , _o , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _o , _e , _e , _e , _vo, _e , _g , _gy],
      [_gy, _g , _e , _vo, _e , _e , _o , _y , _y , _g , _g , _g , _y , _y , _y , _y , _y , _y , _g , _g , _g , _y , _y , _o , _e , _e , _vo, _e , _g , _gy],
      [_gy, _g , _vo, _vo, _e , _e , _o , _y , _y , _g , _c , _v , _y , _y , _y , _y , _y , _y , _v , _c , _g , _y , _y , _o , _e , _e , _vo, _vo, _g , _gy],
      [_gy, _g , _vo, _e , _e , _e , _o , _y , _y , _g , _g , _g , _y , _y , _y , _y , _y , _y , _g , _g , _g , _y , _y , _o , _e , _e , _e , _vo, _g , _gy],
      [_gy, _g , _vo, _c2, _c2, _c2, _o , _y , _y , _y , _y , _y , _y , _y , _p , _p , _y , _y , _y , _y , _y , _y , _y , _o , _c2, _c2, _c2, _vo, _g , _gy],
      [_gy, _vo, _vo, _vo, _e , _e , _o , _y , _y , _y , _y , _y , _y , _y , _p , _p , _y , _y , _y , _y , _y , _y , _y , _o , _e , _e , _vo, _vo, _vo, _gy],
      [_gy, _vo, _e , _c2, _c2, _c2, _e , _o , _y , _y , _y , _y , _y , _p , _y , _y , _p , _y , _y , _y , _y , _y , _o , _e , _c2, _c2, _c2, _e , _vo, _gy],
      [_gy, _vo, _e , _e , _e , _e , _e , _o , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _o , _e , _e , _e , _e , _e , _vo, _gy],
      [_gy, _vo, _vo, _e , _e , _e , _e , _vo, _vo, _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _vo, _vo, _e , _e , _e , _e , _vo, _vo, _gy],
      [_gy, _gy, _vo, _vo, _vo, _vo, _vo, _vo, _e , _o , _y , _y , _y , _y , _y , _y , _y , _y , _y , _y , _o , _e , _vo, _vo, _vo, _vo, _vo, _vo, _gy, _gy],
      [_gy, _gy, _vo, _vo, _vo, _vo, _vo, _vo, _e , _e , _e , _p , _p , _p2, _p2, _p2, _p2, _p , _p , _e , _e , _e , _vo, _vo, _vo, _vo, _vo, _vo, _gy, _gy],
      [_gy, _vo, _vo, _e , _e , _e , _e , _vo, _vo, _e , _o , _v2, _v , _y , _y , _y , _y , _y , _v , _o , _e , _vo, _vo, _e , _e , _e , _e , _vo, _vo, _gy],
      [_gy, _vo, _e , _e , _e , _e , _e , _e , _e , _o , _v2, _v , _v2, _yg, _yg, _yg, _yg, _yg, _v2, _v , _o , _e , _e , _e , _e , _e , _e , _e , _vo, _gy],
      [_gy, _vo, _e , _e , _e , _e , _e , _e , _o , _v2, _v , _v2, _y , _y , _y , _y , _y , _y , _y , _v2, _v , _o , _e , _e , _e , _e , _e , _e , _vo, _gy],
      [_gy, _vo, _vo, _vo, _e , _e , _e , _o , _v2, _v , _v2, _v , _yg, _yg, _yg, _yg, _yg, _yg, _yg, _v , _v2, _v , _o , _e , _e , _e , _vo, _vo, _vo, _gy],
      [_gy, _g , _vo, _e , _e , _e , _e , _o , _v , _v2, _v , _v2, _y , _y , _y , _y , _y , _y , _y , _v2, _v , _v2, _o , _e , _e , _e , _e , _vo, _g , _gy],
      [_gy, _g , _vo, _e , _e , _e , _o , _v , _v2, _v , _v2, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _v2, _v , _v2, _o , _e , _e , _e , _vo, _g , _gy],
      [_gy, _g , _vo, _vo, _e , _e , _o , _v2, _v , _v2, _v , _y , _y , _y , _y , _y , _y , _y , _y , _y , _v , _v2, _v , _o , _e , _e , _vo, _vo, _g , _gy],
      [_gy, _g , _e , _vo, _e , _o , _v2, _v , _v2, _v , _v2, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _v2, _v , _v2, _v , _o , _o , _vo, _e , _g , _gy],
      [_gy, _g , _e , _vo, _e , _o , _v , _v2, _v , _v2, _v , _y , _y , _y , _y , _y , _y , _y , _y , _y , _v , _v2, _v , _v2, _o , _o , _vo, _e , _g , _gy],
      [_gy, _g , _e , _vo, _e , _o , _v2, _v , _v2, _v , _v2, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _v2, _v , _v2, _v , _o , _e , _vo, _o , _g , _gy],
      [_gy, _g , _vo, _vo, _e , _o , _v , _v2, _v , _v2, _v , _y , _y , _y , _y , _y , _y , _y , _y , _y , _v , _v2, _v , _v2, _o , _e , _vo, _vo, _g , _gy],
      [_gy, _g , _vo, _e , _e , _e , _o , _v , _v2, _v , _v2, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _v2, _v , _v2, _o , _e , _o , _o , _vo, _g , _gy],
      [_gy, _g , _vo, _vo, _e , _e , _o , _v2, _v , _v2, _v , _y , _vo, _vo, _vo, _vo, _vo, _vo, _y , _y , _v , _v2, _v , _o , _o , _o , _vo, _vo, _g , _gy],
      [_g , _g , _e , _vo, _e , _e , _e , _o , _v2, _v , _v2, _vo, _yg, _yg, _vo, _vo, _yg, _yg, _vo, _v , _v2, _v , _o , _o , _o , _e , _vo, _e , _g , _g ],
      [_g , _e , _e , _vo, _e , _e , _e , _e , _o , _o , _c , _vo, _o , _y , _vo, _vo, _y , _o , _vo, _c , _o , _o , _e , _e , _e , _e , _vo, _e , _e , _g ],
      [_g , _e , _e , _vo, _vo, _e , _e , _e , _e , _o , _vo, _vo, _v2, _yg, _vo, _vo, _yg, _yg, _vo, _vo, _o , _e , _e , _e , _e , _vo, _vo, _e , _e , _g ],
      [_g , _e , _e , _e , _vo, _vo, _e , _e , _e , _vo, _vo, _e , _e , _e , _vo, _vo, _e , _e , _e , _vo, _vo, _e , _e , _e , _vo, _vo, _e , _e , _e , _g ],
      [_g , _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _g ],
      [_g , _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _g ],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 30), // C sum = 30 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 38), // P sum = 38 ✓
      PiggyBundle(color: PiggyColor.orange, ammo: 50),
      PiggyBundle(color: PiggyColor.purple, ammo: 50),
      PiggyBundle(color: PiggyColor.yellow, ammo: 55),
      PiggyBundle(color: PiggyColor.green,  ammo: 50),
      PiggyBundle(color: PiggyColor.orange, ammo: 50),
      PiggyBundle(color: PiggyColor.purple, ammo: 50),
      PiggyBundle(color: PiggyColor.yellow, ammo: 55),
      PiggyBundle(color: PiggyColor.green,  ammo: 50),
      PiggyBundle(color: PiggyColor.orange, ammo: 50),
      PiggyBundle(color: PiggyColor.purple, ammo: 50),
      PiggyBundle(color: PiggyColor.yellow, ammo: 55),
      PiggyBundle(color: PiggyColor.green,  ammo: 50),
      PiggyBundle(color: PiggyColor.orange, ammo: 50),
      PiggyBundle(color: PiggyColor.purple, ammo: 50),
      PiggyBundle(color: PiggyColor.yellow, ammo: 55),
      PiggyBundle(color: PiggyColor.green,  ammo: 50),
      PiggyBundle(color: PiggyColor.orange, ammo: 50),
      PiggyBundle(color: PiggyColor.purple, ammo: 50),
      PiggyBundle(color: PiggyColor.yellow, ammo: 55),
      PiggyBundle(color: PiggyColor.green,  ammo: 49), // G sum = 249 ✓
      PiggyBundle(color: PiggyColor.orange, ammo: 50),
      PiggyBundle(color: PiggyColor.purple, ammo: 50),
      PiggyBundle(color: PiggyColor.yellow, ammo: 55),
      PiggyBundle(color: PiggyColor.orange, ammo: 41), // O sum = 341 ✓
      PiggyBundle(color: PiggyColor.purple, ammo: 50),
      PiggyBundle(color: PiggyColor.yellow, ammo: 24), // Y sum = 354 ✓
      PiggyBundle(color: PiggyColor.purple, ammo: 40), // V sum = 390 ✓
    ],
    targetLaunches: 29,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 5,
    expectedCombos: 4,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.orange, PiggyColor.purple,
    ],
    piggySpeed: 400,
    spawnInterval: 0.65,
  ),

  // L37 — 🎈 «Гирлянда» (Aleksey Grid Lab, 40×30, 12 pigs).
  //
  //   511 destructible, только 3 цвета (G/V/P). Portal-пар нет.
  //   Компактный узор в центре: верхний ромб с двумя _v/_p цветочными
  //   вставками и нижняя каплевидная фигура. Простая палитра — уровень
  //   на скорость.
  //
  //   Точный подсчёт shots per color:
  //     G = 431 (_g), P = 8 (_p), V = 72 (_v). Total = 511.
  //   Par: 12 launches.
  LevelConfig(
    levelNumber: 37,
    grid: [
      [_e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e ],
      [_e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e ],
      [_e , _e , _g , _g , _g , _v , _v , _v , _v , _g , _g , _g , _g , _g , _g , _g , _g , _g , _v , _v , _v , _v , _g , _g , _g , _g , _e , _e , _e , _e ],
      [_e , _e , _g , _g , _v , _v , _p , _p , _v , _v , _g , _g , _g , _g , _g , _g , _v , _v , _p , _p , _v , _v , _g , _g , _g , _g , _e , _e , _e , _e ],
      [_e , _e , _g , _g , _v , _v , _p , _p , _v , _v , _v , _g , _g , _g , _g , _v , _v , _p , _p , _v , _v , _v , _g , _g , _g , _g , _e , _e , _e , _e ],
      [_e , _e , _g , _g , _v , _v , _v , _v , _v , _v , _v , _g , _g , _g , _g , _v , _v , _v , _v , _v , _v , _v , _g , _g , _g , _g , _e , _e , _e , _e ],
      [_e , _e , _e , _g , _g , _v , _v , _v , _v , _v , _v , _g , _g , _g , _g , _v , _v , _v , _v , _v , _v , _g , _g , _g , _g , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _g , _g , _g , _v , _v , _v , _v , _g , _g , _g , _g , _g , _g , _v , _v , _v , _v , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _g , _g , _g , _v , _v , _g , _g , _g , _g , _g , _g , _g , _g , _v , _v , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _g , _g , _g , _g , _g , _v , _g , _g , _v , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _e , _g , _g , _v , _v , _v , _v , _v , _v , _g , _g , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
      [_e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e , _e ],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.green,  ammo: 48),
      PiggyBundle(color: PiggyColor.purple, ammo: 36),
      PiggyBundle(color: PiggyColor.green,  ammo: 48),
      PiggyBundle(color: PiggyColor.purple, ammo: 36), // V sum = 72 ✓
      PiggyBundle(color: PiggyColor.green,  ammo: 48),
      PiggyBundle(color: PiggyColor.pink,   ammo:  8), // P sum = 8 ✓
      PiggyBundle(color: PiggyColor.green,  ammo: 48),
      PiggyBundle(color: PiggyColor.green,  ammo: 48),
      PiggyBundle(color: PiggyColor.green,  ammo: 48),
      PiggyBundle(color: PiggyColor.green,  ammo: 48),
      PiggyBundle(color: PiggyColor.green,  ammo: 48),
      PiggyBundle(color: PiggyColor.green,  ammo: 47), // G sum = 431 ✓
    ],
    targetLaunches: 12,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 2,
    expectedCombos: 2,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.green, PiggyColor.purple, PiggyColor.pink,
    ],
    piggySpeed: 400,
    spawnInterval: 0.65,
  ),

  // L38 — 🕯 «Свеча ремесла» (Aleksey Grid Lab, 40×30, 39 pigs).
  //
  //   1194 destructible + 0 stones. **3 portal-пары** A/B/C.
  //   Верхняя рамка _c2/_yg (крепкая), центр — большой _g/_cp монолит
  //   с _v/_p/_v2 инкрустацией (два «цветка»), нижняя капля _cp+_ov
  //   с _p2 контурами. Один из самых объёмных уровней.
  //
  //   Точный подсчёт shots per color:
  //     C = 137×2 (_c2) + 277 (_cp outer) = 551
  //     P =   5 (_p) + 138×2 (_p2) + 277 (_cp inner) = 558
  //     Y =  83 (_yg outer) = 83
  //     G = 418 (_g) + 83 (_yg inner) = 501
  //     V =  77 (_v) + 3×2 (_v2) + 56 (_ov inner) = 139
  //     O =  56 (_ov outer) = 56
  //   Total = 1888 shots.
  //
  //   Portals:
  //     _PA : (r=20,c=18) ↔ (r=39,c=7)
  //     _PB : (r=12,c=7)  ↔ (r=39,c=24)
  //     _PC : (r=11,c=19) ↔ (r=39,c=9)
  //   Par: 39 launches. piggySpeed=380 (много pigs + большой grid).
  LevelConfig(
    levelNumber: 38,
    grid: [
      [_c2, _c2, _c2, _c2, _c2, _c2, _c2, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _c2, _c2, _c2, _c2, _c2, _c2, _c2],
      [_c2, _c2, _c2, _c2, _c2, _c2, _v , _v , _v , _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _c2, _c2, _c2, _c2, _c2, _c2, _c2],
      [_c2, _c2, _c2, _c2, _c2, _v , _v , _yg, _yg, _yg, _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _yg, _yg, _yg, _yg, _yg, _c2, _c2, _c2, _c2, _c2],
      [_c2, _c2, _c2, _c2, _v , _v , _yg, _yg, _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _yg, _yg, _yg, _yg, _yg, _yg, _c2, _c2, _c2, _c2],
      [_c2, _c2, _c2, _c2, _v , _yg, _yg, _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _yg, _yg, _yg, _yg, _c2, _c2, _c2, _c2],
      [_c2, _c2, _c2, _c2, _yg, _yg, _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _yg, _yg, _yg, _c2, _c2, _c2, _c2],
      [_c2, _c2, _c2, _c2, _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _yg, _yg, _c2, _c2, _c2, _c2],
      [_cp, _cp, _cp, _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _yg, _yg, _yg, _cp, _cp, _cp],
      [_cp, _cp, _cp, _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _yg, _yg, _cp, _cp, _cp],
      [_cp, _cp, _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _yg, _yg, _cp, _cp],
      [_cp, _cp, _g , _g , _g , _v , _v2, _v , _v , _g , _g , _g , _g , _g , _g , _g , _g , _g , _v , _v2, _v , _v , _g , _g , _g , _g , _yg, _yg, _cp, _cp],
      [_cp, _cp, _g , _g , _v , _v , _p , _p2, _v , _v , _g , _g , _g , _g , _g , _g , _v , _v , _p , _PC, _v , _v , _g , _g , _g , _g , _yg, _yg, _cp, _cp],
      [_cp, _cp, _g , _g , _v , _v , _p , _PB, _v , _v , _v , _g , _g , _g , _g , _v , _v , _p , _p , _v , _v , _v , _g , _g , _g , _g , _yg, _yg, _cp, _cp],
      [_cp, _cp, _g , _g , _v , _v , _v2, _v , _v , _v , _v , _g , _g , _g , _g , _v , _v , _v , _v , _v , _v , _v , _g , _g , _g , _g , _yg, _yg, _cp, _cp],
      [_cp, _cp, _cp, _g , _g , _v , _v , _v , _v , _v , _v , _g , _g , _g , _g , _v , _v , _v , _v , _v , _v , _g , _g , _g , _g , _yg, _yg, _cp, _cp, _cp],
      [_cp, _cp, _cp, _g , _g , _g , _v , _v , _v , _v , _g , _g , _g , _g , _g , _g , _v , _v , _v , _v , _g , _g , _g , _g , _g , _yg, _yg, _cp, _cp, _cp],
      [_cp, _cp, _cp, _cp, _g , _g , _g , _v , _v , _g , _g , _g , _g , _g , _g , _g , _g , _v , _v , _g , _g , _g , _g , _g , _yg, _yg, _cp, _cp, _cp, _cp],
      [_cp, _cp, _cp, _cp, _cp, _g , _g , _g , _cp, _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _cp, _g , _yg, _yg, _cp, _cp, _cp, _cp, _cp],
      [_cp, _cp, _cp, _cp, _cp, _cp, _g , _cp, _cp, _g , _g , _v , _g , _g , _v , _g , _g , _g , _g , _g , _g , _cp, _cp, _yg, _cp, _cp, _cp, _cp, _cp, _cp],
      [_cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _p2, _p2, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp],
      [_cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _g , _g , _v , _v , _v , _v , _v , _v , _g , _g , _PA, _p2, _p2, _p2, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp],
      [_cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _g , _g , _g , _g , _g , _g , _g , _g , _p2, _p2, _p2, _p2, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp],
      [_cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _g , _g , _g , _g , _g , _g , _p2, _p2, _p2, _p2, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp],
      [_cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _g , _g , _g , _g , _p2, _p2, _p2, _p2, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp],
      [_cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _g , _g , _g , _g , _p2, _p2, _p2, _p2, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp],
      [_cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _g , _g , _g , _g , _g , _g , _p2, _p2, _p2, _p2, _p2, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp],
      [_cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _p2, _p2, _p2, _p2, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp],
      [_cp, _cp, _cp, _cp, _cp, _cp, _cp, _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _p2, _p2, _p2, _p2, _cp, _cp, _cp, _cp, _cp, _cp, _cp],
      [_cp, _cp, _cp, _cp, _cp, _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _p2, _p2, _p2, _p2, _cp, _cp, _cp, _cp, _cp],
      [_cp, _cp, _cp, _cp, _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _p2, _p2, _p2, _p2, _cp, _cp, _cp, _cp],
      [_cp, _cp, _cp, _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _p2, _p2, _p2, _p2, _cp, _cp, _cp],
      [_cp, _cp, _cp, _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _p2, _p2, _p2, _p2, _cp, _cp],
      [_cp, _cp, _cp, _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _g , _p2, _p2, _p2, _p2, _cp, _cp],
      [_c2, _c2, _c2, _c2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _c2, _c2, _c2, _c2],
      [_c2, _c2, _c2, _c2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _c2, _c2, _c2, _c2],
      [_c2, _c2, _c2, _c2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _c2, _c2, _c2, _c2],
      [_c2, _c2, _c2, _c2, _ov, _ov, _p2, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _p2, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _c2, _c2, _c2, _c2],
      [_c2, _c2, _c2, _c2, _c2, _ov, _ov, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _p2, _ov, _ov, _ov, _ov, _ov, _ov, _p2, _p2, _c2, _c2, _c2, _c2, _c2],
      [_c2, _c2, _c2, _c2, _c2, _c2, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _p2, _p2, _p2, _ov, _ov, _ov, _ov, _ov, _c2, _c2, _c2, _c2, _c2, _c2, _c2],
      [_c2, _c2, _c2, _c2, _c2, _c2, _c2, _PA, _ov, _PC, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _ov, _c2, _PB, _c2, _c2, _c2, _c2, _c2],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 50),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.green,  ammo: 50),
      PiggyBundle(color: PiggyColor.purple, ammo: 46),
      PiggyBundle(color: PiggyColor.yellow, ammo: 42),
      PiggyBundle(color: PiggyColor.orange, ammo: 28),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 50),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.green,  ammo: 50),
      PiggyBundle(color: PiggyColor.purple, ammo: 46),
      PiggyBundle(color: PiggyColor.yellow, ammo: 41), // Y sum = 83 ✓
      PiggyBundle(color: PiggyColor.orange, ammo: 28), // O sum = 56 ✓
      PiggyBundle(color: PiggyColor.cyan,   ammo: 50),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.green,  ammo: 50),
      PiggyBundle(color: PiggyColor.purple, ammo: 47), // V sum = 139 ✓
      PiggyBundle(color: PiggyColor.cyan,   ammo: 50),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.green,  ammo: 50),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 50),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.green,  ammo: 50),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 50),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.green,  ammo: 50),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 50),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.green,  ammo: 50),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 50),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.green,  ammo: 50),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 50),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.green,  ammo: 50),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 50),
      PiggyBundle(color: PiggyColor.pink,   ammo: 50),
      PiggyBundle(color: PiggyColor.green,  ammo: 51), // G sum = 501 ✓
      PiggyBundle(color: PiggyColor.cyan,   ammo: 51), // C sum = 551 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 58), // P sum = 558 ✓
    ],
    targetLaunches: 39,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 6,
    expectedCombos: 5,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.orange, PiggyColor.purple,
    ],
    piggySpeed: 380,
    spawnInterval: 0.6,
  ),

  // L39 — 🌀 «Вложенная спираль» (Aleksey Grid Lab, 40×40, 49 pigs).
  //
  //   1594 destructible + 0 stones. **3 portal-пары** A/B/C. Один из
  //   самых сложных: вложенные "коридоры" из 7 цветовых слоёв
  //   (_c2/_p/_y2/_vo/_g2/_yg/_shiftYOP), витыми лабиринтом от углов
  //   к центру. Двойная симметрия по диагонали.
  //
  //   Точный подсчёт shots per color:
  //     C = 295×2 (_c2) + 4 (_c) = 594
  //     P = 277 (_p) + 146 (_shiftYOP state 2) = 423
  //     Y = 253×2 (_y2) + 185 (_yg outer) + 146 (_shiftYOP state 0) = 837
  //     G = 205×2 (_g2) + 185 (_yg inner) = 595
  //     V = 229 (_vo outer) = 229
  //     O = 229 (_vo inner) + 146 (_shiftYOP state 1) = 375
  //   Total = 3053 shots — рекордный уровень.
  //
  //   Portals:
  //     _PA : (r=18,c=26) ↔ (r=39,c=0)
  //     _PB : (r=0,c=2)   ↔ (r=25,c=14)
  //     _PC : (r=2,c=19)  ↔ (r=31,c=31)
  //   Par: 49 launches. piggySpeed=360 (сетка 40×40, клетка ~26px).
  LevelConfig(
    levelNumber: 39,
    grid: [
      [_c2, _c2, _PB, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2],
      [_p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _c2],
      [_y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _PC, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _p , _c2],
      [_vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _y2, _p , _c2],
      [_g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _vo, _y2, _p , _c2],
      [_yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _g2, _vo, _y2, _p , _c2],
      [_shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _vo, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _vo, _g2, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _g2, _vo, _y2, _p , _c2, _PA, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _c2, _c2, _c2, _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _p , _p , _p , _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _shiftYOP, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _y2, _y2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _shiftYOP, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _vo, _vo, _vo, _vo, _vo, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _PB, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _vo, _g2, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _g2, _vo, _y2, _p , _c , _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _vo, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _vo, _y2, _p , _c , _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _p , _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _PC, _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _yg, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _vo, _y2, _p , _c2],
      [_c2, _p , _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _p , _c2],
      [_c2, _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _p , _c2],
      [_PA, _c2, _c2, _c2, _c2, _c , _c , _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.yellow, ammo: 70),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 66),
      PiggyBundle(color: PiggyColor.pink,   ammo: 47),
      PiggyBundle(color: PiggyColor.green,  ammo: 60),
      PiggyBundle(color: PiggyColor.orange, ammo: 75),
      PiggyBundle(color: PiggyColor.yellow, ammo: 70),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 66),
      PiggyBundle(color: PiggyColor.pink,   ammo: 47),
      PiggyBundle(color: PiggyColor.green,  ammo: 60),
      PiggyBundle(color: PiggyColor.purple, ammo: 57),
      PiggyBundle(color: PiggyColor.yellow, ammo: 70),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 66),
      PiggyBundle(color: PiggyColor.pink,   ammo: 47),
      PiggyBundle(color: PiggyColor.green,  ammo: 60),
      PiggyBundle(color: PiggyColor.yellow, ammo: 70),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 66),
      PiggyBundle(color: PiggyColor.orange, ammo: 75),
      PiggyBundle(color: PiggyColor.pink,   ammo: 47),
      PiggyBundle(color: PiggyColor.yellow, ammo: 70),
      PiggyBundle(color: PiggyColor.green,  ammo: 60),
      PiggyBundle(color: PiggyColor.purple, ammo: 57),
      PiggyBundle(color: PiggyColor.yellow, ammo: 70),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 66),
      PiggyBundle(color: PiggyColor.pink,   ammo: 47),
      PiggyBundle(color: PiggyColor.green,  ammo: 60),
      PiggyBundle(color: PiggyColor.yellow, ammo: 70),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 66),
      PiggyBundle(color: PiggyColor.pink,   ammo: 47),
      PiggyBundle(color: PiggyColor.orange, ammo: 75),
      PiggyBundle(color: PiggyColor.yellow, ammo: 70),
      PiggyBundle(color: PiggyColor.purple, ammo: 57),
      PiggyBundle(color: PiggyColor.green,  ammo: 60),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 66),
      PiggyBundle(color: PiggyColor.yellow, ammo: 70),
      PiggyBundle(color: PiggyColor.pink,   ammo: 47),
      PiggyBundle(color: PiggyColor.green,  ammo: 60),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 66),
      PiggyBundle(color: PiggyColor.yellow, ammo: 70),
      PiggyBundle(color: PiggyColor.orange, ammo: 75),
      PiggyBundle(color: PiggyColor.pink,   ammo: 47),
      PiggyBundle(color: PiggyColor.green,  ammo: 60),
      PiggyBundle(color: PiggyColor.yellow, ammo: 70),
      PiggyBundle(color: PiggyColor.purple, ammo: 58), // V sum = 229 ✓
      PiggyBundle(color: PiggyColor.cyan,   ammo: 66), // C sum = 594 ✓
      PiggyBundle(color: PiggyColor.green,  ammo: 60),
      PiggyBundle(color: PiggyColor.yellow, ammo: 67), // Y sum = 837 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 47), // P sum = 423 ✓
      PiggyBundle(color: PiggyColor.green,  ammo: 55), // G sum = 595 ✓
      PiggyBundle(color: PiggyColor.orange, ammo: 75), // O sum = 375 ✓
    ],
    targetLaunches: 49,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 8,
    expectedCombos: 6,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.orange, PiggyColor.purple,
    ],
    piggySpeed: 360,
    spawnInterval: 0.6,
  ),

  // L40 — 🕸 «Кружево» (Aleksey Grid Lab, 40×40, 36 pigs).
  //
  //   952 destructible + 76 stones. **3 portal-пары** A/B/C.
  //   Плотный ажурный симметричный узор: восьмиугольная звезда из
  //   _y2 + _gy + _p + _cp + _g2 + _yg + _shiftYOP + _o. Без purple.
  //
  //   Точный подсчёт shots per color:
  //     C = 128 (_cp inner) = 128
  //     P = 148 (_p) + 128 (_cp outer) + 44 (_shiftYOP state 2) = 320
  //     Y = 208×2 (_y2) + 72 (_yg outer) + 140 (_gy inner) + 44 (_shiftYOP state 0) = 672
  //     G = 100×2 (_g2) + 72 (_yg inner) + 140 (_gy outer) = 412
  //     O = 112 (_o) + 44 (_shiftYOP state 1) = 156
  //     Filter: 76 stones
  //   Total = 1688 + 76 filter.
  //
  //   Portals:
  //     _PA : (r=17,c=20) ↔ (r=36,c=2)
  //     _PB : (r=2,c=29)  ↔ (r=22,c=19)
  //     _PC : (r=6,c=4)   ↔ (r=21,c=22)
  //   Par: 36 launches.
  LevelConfig(
    levelNumber: 40,
    grid: [
      [_p , _p , _e , _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _gy, _gy, _gy, _y2, _y2, _y2, _o , _o , _y2, _y2, _y2, _gy, _gy, _gy, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _e , _p , _p ],
      [_e , _p , _p , _e , _e , _e , _e , _y2, _e , _gy, _gy, _e , _y2, _o , _o , _e , _gy, _e , _e , _o , _o , _e , _e , _gy, _e , _o , _o , _y2, _e , _gy, _gy, _e , _y2, _e , _e , _e , _e , _p , _p , _e ],
      [_y2, _e , _p , _p , _e , _o , _o , _e , _y2, _e , _e , _o , _o , _e , _o , _o , _o , _gy, _e , _o , _o , _e , _gy, _o , _o , _o , _e , _o , _o , _PB, _e , _y2, _e , _o , _o , _e , _p , _p , _e , _y2],
      [_y2, _e , _e , _p , _p , _e , _o , _e , _y2, _y2, _e , _e , _e , _e , _y2, _y2, _o , _e , _gy, _o , _o , _gy, _e , _o , _y2, _y2, _e , _e , _e , _e , _y2, _y2, _e , _o , _e , _p , _p , _e , _e , _y2],
      [_y2, _e , _e , _e , _p , _p , _e , _o , _o , _e , _e , _y2, _y2, _y2, _e , _y2, _o , _e , _gy, _o , _o , _gy, _e , _o , _y2, _e , _y2, _y2, _y2, _e , _e , _o , _o , _e , _p , _p , _e , _e , _e , _y2],
      [_y2, _cp, _cp, _e , _e , _p , _p , _e , _o , _o , _e , _e , _e , _y2, _y2, _y2, _o , _o , _o , _o , _o , _o , _o , _o , _y2, _y2, _y2, _e , _e , _e , _o , _o , _e , _p , _p , _e , _e , _cp, _cp, _y2],
      [_y2, _e , _e , _cp, _PC, _e , _p , _e , _e , _o , _e , _gy, _S , _S , _e , _y2, _e , _e , _gy, _e , _e , _gy, _e , _e , _y2, _e , _S , _S , _gy, _e , _o , _e , _e , _p , _e , _e , _cp, _e , _e , _y2],
      [_y2, _e , _e , _cp, _e , _e , _p , _p , _p , _o , _o , _gy, _e , _S , _S , _y2, _y2, _y2, _gy, _e , _e , _gy, _y2, _y2, _y2, _S , _S , _e , _gy, _o , _o , _p , _p , _p , _e , _e , _cp, _e , _e , _y2],
      [_y2, _e , _e , _cp, _cp, _e , _e , _e , _p , _e , _e , _e , _gy, _e , _S , _e , _e , _y2, _gy, _gy, _gy, _gy, _y2, _e , _e , _S , _e , _gy, _e , _e , _e , _p , _e , _e , _e , _cp, _cp, _e , _e , _y2],
      [_y2, _g2, _g2, _g2, _cp, _cp, _cp, _e , _p , _p , _p , _e , _gy, _gy, _S , _e , _y2, _y2, _e , _gy, _gy, _e , _y2, _y2, _e , _S , _gy, _gy, _e , _p , _p , _p , _e , _cp, _cp, _cp, _g2, _g2, _g2, _y2],
      [_y2, _g2, _e , _g2, _e , _e , _cp, _yg, _e , _e , _p , _p , _e , _gy, _S , _S , _y2, _y2, _e , _gy, _gy, _e , _y2, _y2, _S , _S , _gy, _e , _p , _p , _e , _e , _yg, _cp, _e , _e , _g2, _e , _g2, _y2],
      [_y2, _e , _e , _g2, _e , _e , _cp, _e , _yg, _e , _e , _p , _p , _gy, _e , _S , _S , _y2, _e , _gy, _gy, _e , _y2, _S , _S , _e , _gy, _p , _p , _e , _e , _yg, _e , _cp, _e , _e , _g2, _e , _e , _y2],
      [_y2, _e , _g2, _e , _cp, _cp, _cp, _e , _yg, _yg, _e , _p , _p , _e , _gy, _gy, _e , _y2, _e , _gy, _gy, _e , _y2, _e , _gy, _gy, _e , _p , _p , _e , _yg, _yg, _e , _cp, _cp, _cp, _e , _g2, _e , _y2],
      [_y2, _e , _e , _cp, _cp, _e , _e , _e , _e , _yg, _yg, _e , _p , _e , _e , _gy, _gy, _e , _y2, _y2, _y2, _y2, _e , _gy, _gy, _e , _e , _p , _e , _yg, _yg, _e , _e , _e , _e , _cp, _cp, _e , _e , _y2],
      [_g2, _g2, _e , _cp, _cp, _cp, _cp, _cp, _cp, _e , _yg, _e , _p , _p , _p , _e , _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _e , _p , _p , _p , _e , _yg, _e , _cp, _cp, _cp, _cp, _cp, _cp, _e , _g2, _g2],
      [_g2, _g2, _g2, _e , _S , _S , _S , _S , _e , _cp, _yg, _yg, _yg, _yg, _e , _p , _e , _e , _gy, _gy, _gy, _gy, _e , _e , _p , _e , _yg, _yg, _yg, _yg, _cp, _e , _S , _S , _S , _S , _e , _g2, _g2, _g2],
      [_shiftYOP, _e , _g2, _e , _S , _S , _S , _e , _e , _cp, _e , _e , _e , _yg, _e , _p , _p , _e , _e , _gy, _gy, _e , _e , _p , _p , _e , _yg, _e , _e , _e , _cp, _e , _e , _S , _S , _S , _e , _g2, _e , _shiftYOP],
      [_shiftYOP, _e , _g2, _g2, _g2, _e , _S , _g2, _e , _e , _cp, _cp, _cp, _cp, _yg, _yg, _yg, _p , _p , _e , _PA, _p , _p , _yg, _yg, _yg, _cp, _cp, _cp, _cp, _e , _e , _g2, _S , _e , _g2, _g2, _g2, _e , _shiftYOP],
      [_shiftYOP, _e , _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _S , _g2, _e , _e , _e , _e , _e , _cp, _cp, _e , _yg, _e , _p , _e , _e , _p , _e , _yg, _e , _cp, _cp, _e , _e , _e , _e , _e , _g2, _S , _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _e , _shiftYOP],
      [_shiftYOP, _shiftYOP, _e , _e , _e , _shiftYOP, _shiftYOP, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _cp, _cp, _yg, _e , _p , _yg, _yg, _p , _e , _yg, _cp, _cp, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _shiftYOP, _shiftYOP, _e , _e , _e , _shiftYOP, _shiftYOP],
      [_shiftYOP, _shiftYOP, _e , _e , _e , _shiftYOP, _shiftYOP, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _cp, _cp, _yg, _e , _p , _yg, _yg, _p , _e , _yg, _cp, _cp, _g2, _g2, _g2, _g2, _g2, _g2, _g2, _shiftYOP, _shiftYOP, _e , _e , _e , _shiftYOP, _shiftYOP],
      [_shiftYOP, _e , _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _S , _g2, _e , _e , _e , _e , _e , _cp, _cp, _e , _yg, _e , _p , _e , _e , _p , _PC, _yg, _e , _cp, _cp, _e , _e , _e , _e , _e , _g2, _S , _shiftYOP, _shiftYOP, _shiftYOP, _shiftYOP, _e , _shiftYOP],
      [_shiftYOP, _e , _g2, _g2, _g2, _e , _S , _g2, _e , _e , _cp, _cp, _cp, _cp, _yg, _yg, _yg, _p , _p , _PB, _e , _p , _p , _yg, _yg, _yg, _cp, _cp, _cp, _cp, _e , _e , _g2, _S , _e , _g2, _g2, _g2, _e , _shiftYOP],
      [_shiftYOP, _e , _g2, _e , _S , _S , _S , _e , _e , _cp, _e , _e , _e , _yg, _e , _p , _p , _e , _e , _gy, _gy, _e , _e , _p , _p , _e , _yg, _e , _e , _e , _cp, _e , _e , _S , _S , _S , _e , _g2, _e , _shiftYOP],
      [_g2, _g2, _g2, _e , _S , _S , _S , _S , _e , _cp, _yg, _yg, _yg, _yg, _e , _p , _e , _e , _gy, _gy, _gy, _gy, _e , _e , _p , _e , _yg, _yg, _yg, _yg, _cp, _e , _S , _S , _S , _S , _e , _g2, _g2, _g2],
      [_g2, _g2, _e , _cp, _cp, _cp, _cp, _cp, _cp, _e , _yg, _e , _p , _p , _p , _e , _gy, _gy, _gy, _gy, _gy, _gy, _gy, _gy, _e , _p , _p , _p , _e , _yg, _e , _cp, _cp, _cp, _cp, _cp, _cp, _e , _g2, _g2],
      [_y2, _e , _e , _cp, _cp, _e , _e , _e , _e , _yg, _yg, _e , _p , _e , _e , _gy, _gy, _e , _y2, _y2, _y2, _y2, _e , _gy, _gy, _e , _e , _p , _e , _yg, _yg, _e , _e , _e , _e , _cp, _cp, _e , _e , _y2],
      [_y2, _e , _g2, _e , _cp, _cp, _cp, _e , _yg, _yg, _e , _p , _p , _e , _gy, _gy, _e , _y2, _e , _gy, _gy, _e , _y2, _e , _gy, _gy, _e , _p , _p , _e , _yg, _yg, _e , _cp, _cp, _cp, _e , _g2, _e , _y2],
      [_y2, _e , _e , _g2, _e , _e , _cp, _e , _yg, _e , _e , _p , _p , _gy, _e , _S , _S , _y2, _e , _gy, _gy, _e , _y2, _S , _S , _e , _gy, _p , _p , _e , _e , _yg, _e , _cp, _e , _e , _g2, _e , _e , _y2],
      [_y2, _g2, _e , _g2, _e , _e , _cp, _yg, _e , _e , _p , _p , _e , _gy, _S , _S , _y2, _y2, _e , _gy, _gy, _e , _y2, _y2, _S , _S , _gy, _e , _p , _p , _e , _e , _yg, _cp, _e , _e , _g2, _e , _g2, _y2],
      [_y2, _g2, _g2, _g2, _cp, _cp, _cp, _e , _p , _p , _p , _e , _gy, _gy, _S , _e , _y2, _y2, _e , _gy, _gy, _e , _y2, _y2, _e , _S , _gy, _gy, _e , _p , _p , _p , _e , _cp, _cp, _cp, _g2, _g2, _g2, _y2],
      [_y2, _e , _e , _cp, _cp, _e , _e , _e , _p , _e , _e , _e , _gy, _e , _S , _e , _e , _y2, _gy, _gy, _gy, _gy, _y2, _e , _e , _S , _e , _gy, _e , _e , _e , _p , _e , _e , _e , _cp, _cp, _e , _e , _y2],
      [_y2, _e , _e , _cp, _e , _e , _p , _p , _p , _o , _o , _gy, _e , _S , _S , _y2, _y2, _y2, _gy, _e , _e , _gy, _y2, _y2, _y2, _S , _S , _e , _gy, _o , _o , _p , _p , _p , _e , _e , _cp, _e , _e , _y2],
      [_y2, _e , _e , _cp, _e , _e , _p , _e , _e , _o , _e , _gy, _S , _S , _e , _y2, _e , _e , _gy, _e , _e , _gy, _e , _e , _y2, _e , _S , _S , _gy, _e , _o , _e , _e , _p , _e , _e , _cp, _e , _e , _y2],
      [_y2, _cp, _cp, _e , _e , _p , _p , _e , _o , _o , _e , _e , _e , _y2, _y2, _y2, _o , _o , _o , _o , _o , _o , _o , _o , _y2, _y2, _y2, _e , _e , _e , _o , _o , _e , _p , _p , _e , _e , _cp, _cp, _y2],
      [_y2, _e , _e , _e , _p , _p , _e , _o , _o , _e , _e , _y2, _y2, _y2, _e , _y2, _o , _e , _gy, _o , _o , _gy, _e , _o , _y2, _e , _y2, _y2, _y2, _e , _e , _o , _o , _e , _p , _p , _e , _e , _e , _y2],
      [_y2, _e , _PA, _p , _p , _e , _o , _e , _y2, _y2, _e , _e , _e , _e , _y2, _y2, _o , _e , _gy, _o , _o , _gy, _e , _o , _y2, _y2, _e , _e , _e , _e , _y2, _y2, _e , _o , _e , _p , _p , _e , _e , _y2],
      [_y2, _e , _p , _p , _e , _o , _o , _e , _y2, _e , _e , _o , _o , _e , _o , _o , _o , _gy, _e , _o , _o , _e , _gy, _o , _o , _o , _e , _o , _o , _e , _e , _y2, _e , _o , _o , _e , _p , _p , _e , _y2],
      [_e , _p , _p , _e , _e , _e , _e , _y2, _e , _gy, _gy, _e , _y2, _o , _o , _e , _gy, _e , _e , _o , _o , _e , _e , _gy, _e , _o , _o , _y2, _e , _gy, _gy, _e , _y2, _e , _e , _e , _e , _p , _p , _e ],
      [_p , _p , _e , _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _gy, _gy, _gy, _y2, _y2, _y2, _o , _o , _y2, _y2, _y2, _gy, _gy, _gy, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _y2, _e , _p , _p ],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.yellow, ammo: 56),
      PiggyBundle(color: PiggyColor.green,  ammo: 46),
      PiggyBundle(color: PiggyColor.pink,   ammo: 46),
      PiggyBundle(color: PiggyColor.yellow, ammo: 56),
      PiggyBundle(color: PiggyColor.green,  ammo: 46),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 43),
      PiggyBundle(color: PiggyColor.yellow, ammo: 56),
      PiggyBundle(color: PiggyColor.green,  ammo: 46),
      PiggyBundle(color: PiggyColor.pink,   ammo: 46),
      PiggyBundle(color: PiggyColor.yellow, ammo: 56),
      PiggyBundle(color: PiggyColor.orange, ammo: 39),
      PiggyBundle(color: PiggyColor.green,  ammo: 46),
      PiggyBundle(color: PiggyColor.yellow, ammo: 56),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 43),
      PiggyBundle(color: PiggyColor.green,  ammo: 46),
      PiggyBundle(color: PiggyColor.pink,   ammo: 46),
      PiggyBundle(color: PiggyColor.yellow, ammo: 56),
      PiggyBundle(color: PiggyColor.orange, ammo: 39),
      PiggyBundle(color: PiggyColor.green,  ammo: 46),
      PiggyBundle(color: PiggyColor.yellow, ammo: 56),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 76, type: PiggyType.filter), // 76 stones ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 46),
      PiggyBundle(color: PiggyColor.yellow, ammo: 56),
      PiggyBundle(color: PiggyColor.green,  ammo: 46),
      PiggyBundle(color: PiggyColor.orange, ammo: 39),
      PiggyBundle(color: PiggyColor.pink,   ammo: 46),
      PiggyBundle(color: PiggyColor.yellow, ammo: 56),
      PiggyBundle(color: PiggyColor.green,  ammo: 46),
      PiggyBundle(color: PiggyColor.yellow, ammo: 56),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 42), // C sum = 128 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 46),
      PiggyBundle(color: PiggyColor.green,  ammo: 44), // G sum = 412 ✓
      PiggyBundle(color: PiggyColor.orange, ammo: 39), // O sum = 156 ✓
      PiggyBundle(color: PiggyColor.pink,   ammo: 44), // P sum = 320 ✓
      PiggyBundle(color: PiggyColor.yellow, ammo: 56),
      PiggyBundle(color: PiggyColor.yellow, ammo: 56), // Y sum = 672 ✓
    ],
    targetLaunches: 36,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 6,
    expectedCombos: 5,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.orange, PiggyColor.purple,
    ],
    piggySpeed: 360,
    spawnInterval: 0.6,
  ),

  // L41 — 🔮 «Око бури» (Aleksey Grid Lab, 40×30, 32 pigs).
  //
  //   1167 destructible + 29 stones. **2 portal-пары** _PB / _PC.
  //   Массивный cyan массив (368 _c + 105 _c2 armor + 39 _cp) образует
  //   рамку, внутри — «глаз» из _v (272) + _v2 (56 armor) + _shiftYOP
  //   (106 tri-color) + _o/_y/_p узоры. Без green — оптимально для
  //   комбо-охоты cyan/purple.
  //
  //   Точный подсчёт shots per color:
  //     C = 368 (_c) + 105×2 (_c2) + 39 (_cp inner) = 617
  //     P =  30 (_p) + 39 (_cp outer) + 106 (_shiftYOP state 2) = 175
  //     Y =  63 (_y) + 106 (_shiftYOP state 0) = 169
  //     V = 272 (_v) + 56×2 (_v2) = 384
  //     O = 128 (_o) + 106 (_shiftYOP state 1) = 234
  //     Filter: 29 stones
  //   Total = 1579 + 29 filter.
  //
  //   Portals:
  //     _PB : (r=8,c=3)  ↔ (r=27,c=29)
  //     _PC : (r=7,c=16) ↔ (r=38,c=14)
  //   Par: 32 launches.
  LevelConfig(
    levelNumber: 41,
    grid: [
      [_c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2],
      [_c , _c , _c , _S , _S , _S , _S , _S , _S , _S , _S , _S , _S , _S , _S , _S , _S , _S , _S , _S , _S , _S , _S , _S , _S , _c , _c , _c , _c , _c ],
      [_c , _c , _c , _c , _v , _v , _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _v , _v , _c , _c , _c , _c , _c , _c ],
      [_c , _c , _c , _c , _c , _v , _v , _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _cp, _c , _v , _v , _c , _c , _c , _c , _c , _c , _c ],
      [_c , _c , _c , _c , _c , _c , _v , _v , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _v , _v , _c , _c , _c , _c , _c , _c , _c , _c ],
      [_c , _c , _c , _c , _c , _c , _c , _v , _v , _c , _c , _c , _c , _v , _v2, _v2, _v , _c , _c , _v , _v , _c , _c , _c , _c , _c , _c , _c , _c , _c ],
      [_c , _v , _v , _v , _v , _v , _c , _c , _v , _v , _c , _c , _v , _v , _v2, _v2, _v , _v , _v , _v , _c , _c , _v , _v , _v , _v , _v , _c , _c , _c ],
      [_v , _v , _y , _y , _y , _v , _v , _c , _c , _v , _v , _v , _v , _v , _v2, _v2, _PC, _v , _v , _v , _v , _v , _v , _y , _y , _y , _v , _v , _c , _c ],
      [_v , _y , _o , _PB, _o , _shiftYOP, _v , _v , _c , _c , _v , _v , _v , _v , _v2, _v2, _v , _v , _v , _v , _c , _c , _v , _y , _shiftYOP, _o , _S , _y , _v , _c ],
      [_v , _y , _o , _S , _p , _shiftYOP, _y , _v , _v , _c , _c , _c , _v , _v , _v2, _v2, _v , _v , _c , _c , _c , _v , _v , _y , _shiftYOP, _p , _S , _o , _y , _v ],
      [_v , _o , _o , _S , _p , _shiftYOP, _shiftYOP, _v , _v , _v , _c , _c , _c , _v , _v2, _v2, _v , _c , _c , _c , _v , _v , _v , _shiftYOP, _shiftYOP, _p , _S , _o , _o , _v ],
      [_v , _o , _o , _S , _o , _shiftYOP, _shiftYOP, _o , _v , _v , _v , _c , _c , _v , _v2, _v2, _v , _c , _c , _v , _v , _v , _o , _shiftYOP, _shiftYOP, _o , _o , _o , _o , _v ],
      [_v , _o , _y , _y , _y , _shiftYOP, _shiftYOP, _o , _o , _v , _v , _c , _c , _v , _v2, _v2, _v , _c , _c , _v , _v , _o , _o , _shiftYOP, _shiftYOP, _y , _y , _y , _o , _v ],
      [_v , _o , _y , _p , _y , _shiftYOP, _shiftYOP, _o , _shiftYOP, _o , _v , _v , _c , _v , _v2, _v2, _v , _c , _v , _v , _o , _shiftYOP, _o , _shiftYOP, _shiftYOP, _y , _p , _y , _o , _v ],
      [_cp, _v , _y , _y , _y , _shiftYOP, _shiftYOP, _o , _shiftYOP, _o , _v , _v , _c , _v , _v2, _v2, _v , _c , _v , _v , _o , _shiftYOP, _o , _shiftYOP, _shiftYOP, _y , _y , _y , _v , _cp],
      [_cp, _v , _o , _o , _o , _shiftYOP, _shiftYOP, _o , _shiftYOP, _shiftYOP, _o , _v , _c , _v , _v2, _v2, _v , _c , _v , _o , _shiftYOP, _shiftYOP, _o , _shiftYOP, _shiftYOP, _o , _o , _o , _v , _cp],
      [_cp, _c , _v , _o , _o , _shiftYOP, _shiftYOP, _o , _shiftYOP, _shiftYOP, _shiftYOP, _v , _v , _v , _v2, _v2, _v , _v , _v , _shiftYOP, _shiftYOP, _shiftYOP, _o , _shiftYOP, _shiftYOP, _o , _o , _v , _c , _cp],
      [_cp, _c , _v , _v , _o , _shiftYOP, _shiftYOP, _o , _shiftYOP, _shiftYOP, _shiftYOP, _o , _v , _v , _v2, _v2, _v , _v , _o , _shiftYOP, _shiftYOP, _shiftYOP, _o , _shiftYOP, _shiftYOP, _o , _v , _v , _c , _cp],
      [_cp, _c , _c , _v , _v , _shiftYOP, _shiftYOP, _o , _shiftYOP, _o , _shiftYOP, _shiftYOP, _v , _v , _v2, _v2, _v , _v , _shiftYOP, _shiftYOP, _o , _shiftYOP, _o , _shiftYOP, _shiftYOP, _v , _v , _c , _c , _cp],
      [_cp, _c , _c , _c , _v , _v , _v , _o , _shiftYOP, _shiftYOP, _o , _v , _v , _v , _v2, _v2, _v , _v , _v , _o , _shiftYOP, _shiftYOP, _o , _v , _v , _v , _c , _c , _c , _cp],
      [_cp, _c , _c , _c , _c , _v , _v , _v , _v , _v , _v , _v , _c , _v , _v2, _v2, _v , _c , _v , _v , _v , _v , _v , _v , _v , _c , _c , _c , _c , _cp],
      [_cp, _c , _c , _c , _v , _v , _y , _y , _o , _o , _v , _v , _c , _v , _v2, _v2, _v , _c , _v , _v , _o , _o , _y , _y , _v , _v , _c , _c , _c , _cp],
      [_cp, _c , _c , _v , _v , _y , _o , _p , _p , _o , _o , _v , _c , _v , _v2, _v2, _v , _c , _v , _o , _o , _p , _p , _o , _y , _v , _v , _c , _c , _cp],
      [_cp, _c , _v , _v , _y , _o , _p , _p , _p , _p , _o , _v , _v , _v , _v2, _v2, _v , _v , _v , _o , _p , _p , _p , _p , _o , _y , _v , _v , _c , _cp],
      [_cp, _c , _v , _y , _o , _shiftYOP, _p , _p , _p , _p , _shiftYOP, _o , _v , _v , _v2, _v2, _v , _v , _o , _shiftYOP, _p , _p , _p , _p , _shiftYOP, _o , _y , _v , _c , _cp],
      [_cp, _v , _v , _y , _shiftYOP, _shiftYOP, _o , _p , _p , _o , _shiftYOP, _o , _v , _v , _v2, _v2, _v , _v , _o , _shiftYOP, _o , _p , _p , _o , _shiftYOP, _shiftYOP, _y , _v , _v , _cp],
      [_cp, _v , _y , _o , _shiftYOP, _o , _o , _o , _shiftYOP, _o , _shiftYOP, _o , _v , _v , _v2, _v2, _v , _v , _o , _shiftYOP, _o , _shiftYOP, _o , _o , _o , _shiftYOP, _o , _y , _v , _cp],
      [_c , _v , _y , _shiftYOP, _shiftYOP, _y , _y , _o , _shiftYOP, _o , _shiftYOP, _o , _v , _v , _v2, _v2, _v , _v , _o , _shiftYOP, _o , _shiftYOP, _o , _y , _y , _shiftYOP, _shiftYOP, _y , _v , _PB],
      [_c , _v , _y , _shiftYOP, _y , _y , _y , _y , _shiftYOP, _o , _shiftYOP, _o , _v , _v , _v2, _v2, _v , _v , _o , _shiftYOP, _o , _shiftYOP, _y , _y , _y , _y , _shiftYOP, _y , _v , _c ],
      [_c , _c , _v , _v , _o , _y , _y , _o , _shiftYOP, _o , _o , _v , _v , _c , _v2, _v2, _c , _v , _v , _o , _o , _shiftYOP, _o , _y , _y , _o , _v , _v , _c , _c ],
      [_c , _c , _c , _v , _v , _o , _o , _o , _shiftYOP, _o , _v , _v , _c , _c , _v2, _v2, _c , _c , _v , _v , _o , _shiftYOP, _o , _o , _o , _v , _v , _c , _c , _c ],
      [_c , _c , _c , _c , _v , _v , _v , _o , _shiftYOP, _v , _v , _c , _c , _c , _v2, _v2, _c , _c , _c , _v , _v , _shiftYOP, _o , _v , _v , _v , _c , _c , _c , _c ],
      [_c , _c , _c , _c , _c , _c , _v , _v , _v , _v , _c , _c , _c , _c , _v2, _v2, _c , _c , _c , _c , _v , _v , _v , _v , _c , _c , _c , _c , _c , _c ],
      [_c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c ],
      [_c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c ],
      [_c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2],
      [_c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c ],
      [_c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c ],
      [_c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _PC, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2, _c2],
      [_c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _S , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c , _c ],
    ],
    inventory: const [
      PiggyBundle(color: PiggyColor.cyan,   ammo: 62),
      PiggyBundle(color: PiggyColor.purple, ammo: 48),
      PiggyBundle(color: PiggyColor.pink,   ammo: 44),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 62),
      PiggyBundle(color: PiggyColor.purple, ammo: 48),
      PiggyBundle(color: PiggyColor.orange, ammo: 47),
      PiggyBundle(color: PiggyColor.yellow, ammo: 42),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 62),
      PiggyBundle(color: PiggyColor.purple, ammo: 48),
      PiggyBundle(color: PiggyColor.pink,   ammo: 44),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 62),
      PiggyBundle(color: PiggyColor.purple, ammo: 48),
      PiggyBundle(color: PiggyColor.orange, ammo: 47),
      PiggyBundle(color: PiggyColor.yellow, ammo: 42),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 62),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 29, type: PiggyType.filter), // 29 stones ✓
      PiggyBundle(color: PiggyColor.purple, ammo: 48),
      PiggyBundle(color: PiggyColor.pink,   ammo: 44),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 62),
      PiggyBundle(color: PiggyColor.purple, ammo: 48),
      PiggyBundle(color: PiggyColor.orange, ammo: 47),
      PiggyBundle(color: PiggyColor.yellow, ammo: 42),
      PiggyBundle(color: PiggyColor.cyan,   ammo: 62),
      PiggyBundle(color: PiggyColor.purple, ammo: 48),
      PiggyBundle(color: PiggyColor.pink,   ammo: 43), // P sum = 175 ✓
      PiggyBundle(color: PiggyColor.cyan,   ammo: 62),
      PiggyBundle(color: PiggyColor.purple, ammo: 48), // V sum = 384 ✓
      PiggyBundle(color: PiggyColor.orange, ammo: 47),
      PiggyBundle(color: PiggyColor.yellow, ammo: 43), // Y sum = 169 ✓
      PiggyBundle(color: PiggyColor.cyan,   ammo: 62),
      PiggyBundle(color: PiggyColor.orange, ammo: 46), // O sum = 234 ✓
      PiggyBundle(color: PiggyColor.cyan,   ammo: 59), // C sum = 617 ✓
    ],
    targetLaunches: 32,
    perfectLaunchTolerance: 0,
    softLaunchTolerance: 5,
    expectedCombos: 5,
    masteryChallenge: MasteryChallenge.noWastedShots,
    spawnPalette: const [
      PiggyColor.cyan, PiggyColor.pink, PiggyColor.yellow,
      PiggyColor.green, PiggyColor.orange, PiggyColor.purple,
    ],
    piggySpeed: 380,
    spawnInterval: 0.6,
  ),
];
