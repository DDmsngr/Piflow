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

// Empty cell (shot flies through, no block).
const BlockSpec? _e = null;

// World sizes drive the difficulty interpolation. Keep in sync with the
// number of LevelConfig.forSlot calls per world below.
const _piggyparkLen = 5;
const _factoryLen = 5;
const _galleryLen = 5;
const _frozenLen = 5;

final List<LevelConfig> levels = [
  // =========================================================================
  // 🌿 PIGGYPARK  L1-L5 — basics, growing palette
  // =========================================================================

  // L1 — знакомство. Два цвета, половина/половина. Без reward — туториал.
  LevelConfig.forSlot(
    levelNumber: 1, worldId: 'piggypark', indexInWorld: 0, worldLength: _piggyparkLen,
    grid: [
      [_p, _p, _p, _p, _c, _c, _c, _c],
      [_p, _p, _p, _p, _c, _c, _c, _c],
      [_p, _p, _p, _p, _c, _c, _c, _c],
      [_p, _p, _p, _p, _c, _c, _c, _c],
    ],
    spawnPalette: [PiggyColor.pink, PiggyColor.cyan],
    comboRewards: [],
  ),

  // L2 — шахматка.
  LevelConfig.forSlot(
    levelNumber: 2, worldId: 'piggypark', indexInWorld: 1, worldLength: _piggyparkLen,
    grid: [
      [_p, _c, _p, _c, _p, _c, _p, _c],
      [_c, _p, _c, _p, _c, _p, _c, _p],
      [_p, _c, _p, _c, _p, _c, _p, _c],
      [_c, _p, _c, _p, _c, _p, _c, _p],
      [_p, _c, _p, _c, _p, _c, _p, _c],
    ],
    spawnPalette: [PiggyColor.pink, PiggyColor.cyan],
    comboRewards: [],
  ),

  // L3 — три цвета полосами.
  LevelConfig.forSlot(
    levelNumber: 3, worldId: 'piggypark', indexInWorld: 2, worldLength: _piggyparkLen,
    grid: [
      [_p, _p, _p, _c, _c, _c, _y, _y],
      [_p, _p, _p, _c, _c, _c, _y, _y],
      [_p, _p, _p, _c, _c, _c, _y, _y],
      [_p, _p, _p, _c, _c, _c, _y, _y],
      [_p, _p, _p, _c, _c, _c, _y, _y],
    ],
    spawnPalette: [PiggyColor.pink, PiggyColor.cyan, PiggyColor.yellow],
  ),

  // L4 — четыре цвета квадрантами.
  LevelConfig.forSlot(
    levelNumber: 4, worldId: 'piggypark', indexInWorld: 3, worldLength: _piggyparkLen,
    grid: [
      [_p, _p, _p, _p, _c, _c, _c, _c],
      [_p, _p, _p, _p, _c, _c, _c, _c],
      [_p, _p, _p, _p, _c, _c, _c, _c],
      [_y, _y, _y, _y, _g, _g, _g, _g],
      [_y, _y, _y, _y, _g, _g, _g, _g],
      [_y, _y, _y, _y, _g, _g, _g, _g],
    ],
    spawnPalette: [PiggyColor.pink, PiggyColor.cyan, PiggyColor.yellow, PiggyColor.green],
  ),

  // L5 — мозаика 8×8. Boss мира: 4-цветная сетка.
  LevelConfig.forSlot(
    levelNumber: 5, worldId: 'piggypark', indexInWorld: 4, worldLength: _piggyparkLen,
    grid: [
      [_p, _p, _c, _c, _y, _y, _g, _g],
      [_p, _p, _c, _c, _y, _y, _g, _g],
      [_c, _c, _p, _p, _g, _g, _y, _y],
      [_c, _c, _p, _p, _g, _g, _y, _y],
      [_y, _y, _g, _g, _p, _p, _c, _c],
      [_y, _y, _g, _g, _p, _p, _c, _c],
      [_g, _g, _y, _y, _c, _c, _p, _p],
      [_g, _g, _y, _y, _c, _c, _p, _p],
    ],
    spawnPalette: [PiggyColor.pink, PiggyColor.cyan, PiggyColor.yellow, PiggyColor.green],
  ),

  // =========================================================================
  // ⚡ FACTORY  L6-L10 — armored, stone, dual
  // =========================================================================

  // L6 — ДЫРЯВАЯ СЕТКА. Пустые ячейки: луч может улететь в никуда.
  LevelConfig.forSlot(
    levelNumber: 6, worldId: 'factory', indexInWorld: 0, worldLength: _factoryLen,
    grid: [
      [_p, _e, _c, _e, _y, _e, _g, _e],
      [_p, _c, _c, _y, _y, _g, _g, _v],
      [_e, _c, _e, _y, _e, _g, _e, _v],
      [_p, _c, _y, _y, _g, _g, _v, _v],
      [_e, _p, _e, _c, _e, _y, _e, _g],
      [_p, _p, _c, _c, _y, _y, _g, _g],
    ],
    spawnPalette: [PiggyColor.pink, PiggyColor.cyan, PiggyColor.yellow, PiggyColor.green, PiggyColor.purple],
  ),

  // L7 — ПРОЧНЫЕ БЛОКИ. Центр — armored 2hp, периметр — обычные.
  LevelConfig.forSlot(
    levelNumber: 7, worldId: 'factory', indexInWorld: 1, worldLength: _factoryLen,
    grid: [
      [_p,  _p,  _c,  _c,  _y,  _y,  _g,  _g],
      [_p,  _p2, _c,  _c2, _y,  _y2, _g,  _g2],
      [_c,  _c,  _p2, _p2, _g2, _g2, _y,  _y],
      [_c,  _c2, _p2, _p2, _g2, _g2, _y,  _y2],
      [_y,  _y,  _g,  _g,  _p2, _p2, _c,  _c],
      [_g,  _g,  _y,  _y,  _c,  _c,  _p,  _p],
    ],
    spawnPalette: [PiggyColor.pink, PiggyColor.cyan, PiggyColor.yellow, PiggyColor.green],
  ),

  // L8 — КАМЕННЫЕ ПРЕПЯТСТВИЯ.
  LevelConfig.forSlot(
    levelNumber: 8, worldId: 'factory', indexInWorld: 2, worldLength: _factoryLen,
    grid: [
      [_p, _p, _c, _c, _y, _y, _g, _g],
      [_p, _p, _c, _S, _y, _y, _g, _g],
      [_c, _c, _p, _p, _g, _g, _y, _y],
      [_c, _c, _p, _S, _S, _g, _y, _y],
      [_c, _c, _p, _p, _g, _g, _y, _y],
      [_y, _y, _g, _S, _p, _p, _c, _c],
      [_y, _y, _g, _g, _p, _p, _c, _c],
    ],
    spawnPalette: [PiggyColor.pink, PiggyColor.cyan, PiggyColor.yellow, PiggyColor.green],
  ),

  // L9 — ДВА КЛАСТЕРА через каменную стену.
  LevelConfig.forSlot(
    levelNumber: 9, worldId: 'factory', indexInWorld: 3, worldLength: _factoryLen,
    grid: [
      [_p, _p, _c, _c, _S, _y, _y, _g, _g],
      [_p, _c, _c, _p, _S, _y, _g, _g, _y],
      [_c, _p, _p, _c, _S, _g, _y, _y, _g],
      [_p, _c, _p, _c, _S, _g, _g, _y, _y],
      [_c, _p, _c, _p, _S, _y, _y, _g, _g],
    ],
    spawnPalette: [PiggyColor.pink, PiggyColor.cyan, PiggyColor.yellow, PiggyColor.green],
  ),

  // L10 — ДВУХЦВЕТНЫЕ БЛОКИ. Boss мира.
  LevelConfig.forSlot(
    levelNumber: 10, worldId: 'factory', indexInWorld: 4, worldLength: _factoryLen,
    grid: [
      [_p,  _c,  _y,  _g,  _v,  _o,  _p,  _c ],
      [_pc, _cp, _yg, _gy, _vo, _ov, _pc, _cp],
      [_c,  _p,  _g,  _y,  _o,  _v,  _c,  _p ],
      [_pc, _cp, _yg, _gy, _vo, _ov, _pc, _cp],
      [_y,  _g,  _p,  _c,  _y,  _g,  _p,  _c ],
      [_S,  _yg, _S,  _gy, _S,  _vo, _S,  _ov],
      [_g,  _y,  _c,  _p,  _g,  _y,  _c,  _p ],
    ],
    spawnPalette: [PiggyColor.pink, PiggyColor.cyan, PiggyColor.yellow, PiggyColor.green, PiggyColor.purple, PiggyColor.orange],
  ),

  // =========================================================================
  // 🎨 GALLERY  L11-L13 — shape levels
  // =========================================================================

  // L11 — ДОМИК.
  LevelConfig.forSlot(
    levelNumber: 11, worldId: 'gallery', indexInWorld: 0, worldLength: _galleryLen,
    grid: shapeHouse,
    spawnPalette: allColors,
  ),

  // L12 — МУХОМОР.
  LevelConfig.forSlot(
    levelNumber: 12, worldId: 'gallery', indexInWorld: 1, worldLength: _galleryLen,
    grid: shapeMushroom,
    spawnPalette: allColors,
  ),

  // L13 — СЕРДЦЕ.
  LevelConfig.forSlot(
    levelNumber: 13, worldId: 'gallery', indexInWorld: 2, worldLength: _galleryLen,
    grid: shapeHeart,
    spawnPalette: allColors,
  ),

  // L14 — ЗВЕЗДА. Классическая пятиконечная.
  LevelConfig.forSlot(
    levelNumber: 14, worldId: 'gallery', indexInWorld: 3, worldLength: _galleryLen,
    grid: shapeStar,
    spawnPalette: allColors,
  ),

  // L15 — РЫБА. Gallery boss.
  LevelConfig.forSlot(
    levelNumber: 15, worldId: 'gallery', indexInWorld: 4, worldLength: _galleryLen,
    grid: shapeFish,
    spawnPalette: allColors,
  ),

  // =========================================================================
  // ❄ FROZEN  L16-L20 — portals
  // =========================================================================

  // L16 — ЗНАКОМСТВО С ПОРТАЛОМ. Одна пара A делит поле пополам.
  LevelConfig.forSlot(
    levelNumber: 16, worldId: 'frozen', indexInWorld: 0, worldLength: _frozenLen,
    grid: [
      [_p, _p, _c, _c, _PA, _y, _y, _g, _g],
      [_p, _c, _c, _p, _e,  _y, _g, _g, _y],
      [_c, _p, _p, _c, _e,  _g, _y, _y, _g],
      [_p, _c, _p, _c, _e,  _g, _g, _y, _y],
      [_c, _p, _c, _p, _PA, _y, _y, _g, _g],
    ],
    spawnPalette: [PiggyColor.pink, PiggyColor.cyan, PiggyColor.yellow, PiggyColor.green],
  ),

  // L17 — ТРИ ПАРЫ (A/B/C) + камни в центре.
  LevelConfig.forSlot(
    levelNumber: 17, worldId: 'frozen', indexInWorld: 1, worldLength: _frozenLen,
    grid: [
      [_p,  _PA, _c,  _c,  _y,  _y,  _PA, _g ],
      [_p,  _p,  _c,  _c,  _y,  _y,  _g,  _g ],
      [_PB, _p,  _c,  _S,  _S,  _y,  _g,  _PB],
      [_p,  _p,  _c,  _c,  _y,  _y,  _g,  _g ],
      [_p,  _PC, _c,  _c,  _y,  _y,  _PC, _g ],
    ],
    spawnPalette: [PiggyColor.pink, PiggyColor.cyan, PiggyColor.yellow, PiggyColor.green],
  ),

  // L18 — ПОРТАЛ + ARMORED. Одна пара A разделяет armored-колонки.
  //        Портал позволяет добить сложные блоки со второй стороны.
  LevelConfig.forSlot(
    levelNumber: 18, worldId: 'frozen', indexInWorld: 2, worldLength: _frozenLen,
    grid: [
      [_c, _c,  _c2, _PA, _c2, _c,  _c ],
      [_p, _p,  _p2, _e,  _p2, _p,  _p ],
      [_y, _y2, _g,  _e,  _g,  _y2, _y ],
      [_g, _g2, _p,  _e,  _p,  _g2, _g ],
      [_c, _c,  _c2, _PA, _c2, _c,  _c ],
    ],
    spawnPalette: [PiggyColor.pink, PiggyColor.cyan, PiggyColor.yellow, PiggyColor.green],
  ),

  // L19 — ПОРТАЛ + DUAL. Пара A верх/низ, пара B слева/справа.
  //        Порталы A и B в разных столбцах чтобы шар не залипал в цикле.
  LevelConfig.forSlot(
    levelNumber: 19, worldId: 'frozen', indexInWorld: 3, worldLength: _frozenLen,
    grid: [
      [_pc, _c,  _PA, _y,  _v,  _o,  _PA, _cp],
      [_p,  _yg, _c,  _y,  _p,  _gy, _c,  _y ],
      [_PB, _pc, _c,  _y,  _g,  _cp, _p,  _PB],
      [_p,  _yg, _c,  _y,  _p,  _gy, _c,  _y ],
      [_pc, _c,  _PC, _y,  _v,  _o,  _PC, _cp],
    ],
    spawnPalette: [PiggyColor.pink, PiggyColor.cyan, PiggyColor.yellow, PiggyColor.green, PiggyColor.purple, PiggyColor.orange],
  ),

  // L20 — FROZEN BOSS. Три пары порталов + armored + dual + stone.
  LevelConfig.forSlot(
    levelNumber: 20, worldId: 'frozen', indexInWorld: 4, worldLength: _frozenLen,
    grid: [
      [_S,  _PA, _p2, _c2, _y2, _g2, _PA, _S ],
      [_pc, _c,  _p,  _S,  _S,  _y,  _g,  _cp],
      [_PB, _c,  _yg, _v,  _o,  _gy, _y,  _PB],
      [_gy, _g,  _y,  _S,  _S,  _c,  _p,  _yg],
      [_PC, _y,  _g,  _c,  _p,  _y,  _g,  _PC],
      [_S,  _o,  _v,  _p,  _y,  _c,  _v,  _S ],
    ],
    spawnPalette: [PiggyColor.pink, PiggyColor.cyan, PiggyColor.yellow, PiggyColor.green, PiggyColor.purple, PiggyColor.orange],
  ),
];
