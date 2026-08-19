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
    lastLevel: 25,
    tagline: 'Спец-пиги: бомбы и реакции',
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
];
