import 'dart:math' as math;

import 'difficulty.dart';
import 'models.dart';

/// Procedural level generator.
///
/// Each world has its own family of grid templates and its own "signature"
/// mechanics — the generator picks a template, fills it with parameters that
/// scale with [tier], and runs a reachability check to avoid the L17-yellow
/// bug (unreachable blocks).
///
/// [tier] is 0.0 at the world's easiest difficulty, 1.0 at the boss, and
/// scales above 1.0 for endless mode (harder than any hand-crafted level).
class LevelGenerator {
  const LevelGenerator._();

  /// Generate a fresh [LevelConfig] for [worldId] at [tier], seeded by [seed]
  /// so the same seed always produces the same level.
  ///
  /// [seenHashes], if provided, is a set of grid-signatures the player has
  /// already seen — the generator will reject any grid whose signature is in
  /// this set (up to 30 attempts), guaranteeing no level ever repeats in
  /// a run. On success the new hash is added to the set.
  ///
  /// [levelNumber] is only used for HUD display ("Level N").
  static LevelConfig generate({
    required String worldId,
    required int seed,
    required double tier,
    int levelNumber = 0,
    int? queueSlots,
    int? waitingSlots,
    Set<int>? seenHashes,
  }) {
    final rng = math.Random(seed);
    final params = _paramsAtTier(worldId, tier);

    // Attempt up to 30 layouts — reject anything unplayable OR already seen.
    // Post-process each candidate (rotate/mirror/light noise) so even the same
    // template family produces visually distinct grids.
    List<List<BlockSpec?>>? grid;
    List<PiggyColor>? palette;
    List<PiggyType>? rewards;
    for (var attempt = 0; attempt < 30; attempt++) {
      final gen = _pickGenerator(worldId, rng);
      final result = gen(rng, tier);
      final transformed = _postProcess(result.grid, result.palette, rng);
      if (!_isPlayable(transformed)) continue;
      final h = _hashGrid(transformed);
      if (seenHashes != null && seenHashes.contains(h)) continue;
      grid = transformed;
      palette = result.palette;
      rewards = result.rewards;
      seenHashes?.add(h);
      break;
    }
    // Absolute fallback: dead-simple mosaic that's always playable.
    grid ??= _fallbackMosaic(rng);
    palette ??= _palette4(rng);
    rewards ??= _rewardsAtTier(worldId, tier);

    return LevelConfig(
      levelNumber: levelNumber,
      grid: grid,
      spawnPalette: palette,
      piggySpeed: params.piggySpeed,
      ammoMin: params.ammoMin,
      ammoMax: params.ammoMax,
      spawnInterval: params.spawnInterval,
      queueSlots: queueSlots ?? 3,
      waitingSlots: waitingSlots ?? 5,
      comboRewards: rewards,
    );
  }

  // ---------------------------------------------------------------------
  // Grid hashing (for "never repeat" guarantee)
  // ---------------------------------------------------------------------

  /// Compact signature capturing shape + colours + block types. Two grids
  /// with the same shape but different colour arrangements hash differently.
  static int _hashGrid(List<List<BlockSpec?>> grid) {
    final buf = StringBuffer();
    for (final row in grid) {
      for (final b in row) {
        if (b == null) {
          buf.write('.');
        } else if (b.isStone) {
          buf.write('S');
        } else if (b.isPortal) {
          buf.write('P${b.portalPairId}');
        } else {
          final ci = b.color?.index ?? 9;
          final inner = b.innerColor?.index ?? 9;
          buf.write('c$ci-${b.hp}-$inner');
        }
        buf.write(',');
      }
      buf.write(';');
    }
    return buf.toString().hashCode;
  }

  // ---------------------------------------------------------------------
  // Post-processing — rotate / mirror / noise
  // ---------------------------------------------------------------------

  /// Apply a random combination of rotation, horizontal flip, and light cell
  /// noise. Expands the effective template pool ~8× visually.
  static List<List<BlockSpec?>> _postProcess(
      List<List<BlockSpec?>> grid, List<PiggyColor> palette, math.Random rng) {
    var g = grid;
    // Rotation: only 180 degrees (90/270 would swap dimensions in ways some
    // templates dislike). Enough for visual variety.
    if (rng.nextBool()) g = _rotate180(g);
    if (rng.nextBool()) g = _flipHorizontal(g);
    g = _addColorNoise(g, palette, rng, chance: 0.06);
    return g;
  }

  static List<List<BlockSpec?>> _rotate180(List<List<BlockSpec?>> grid) {
    final rows = grid.length;
    final cols = grid[0].length;
    final out = List.generate(rows, (_) => List<BlockSpec?>.filled(cols, null));
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        out[rows - 1 - r][cols - 1 - c] = grid[r][c];
      }
    }
    return out;
  }

  static List<List<BlockSpec?>> _flipHorizontal(List<List<BlockSpec?>> grid) {
    return [for (final row in grid) row.reversed.toList()];
  }

  /// Randomly re-colour a small fraction of coloured cells. Preserves block
  /// type (armored, dual, stone, portal untouched) so playability is stable.
  static List<List<BlockSpec?>> _addColorNoise(List<List<BlockSpec?>> grid,
      List<PiggyColor> palette, math.Random rng,
      {double chance = 0.05}) {
    if (palette.length < 2) return grid;
    return [
      for (final row in grid) [
        for (final b in row)
          if (b != null && !b.isStone && !b.isPortal && b.innerColor == null && rng.nextDouble() < chance)
            BlockSpec(
              color: palette[rng.nextInt(palette.length)],
              hp: b.hp,
            )
          else
            b,
      ]
    ];
  }

  // ---------------------------------------------------------------------
  // Per-tier parameter scaling
  // ---------------------------------------------------------------------

  /// Difficulty params at [tier]. For tier > 1.0 we extrapolate past the
  /// world's peak by the same slope — endless mode gets progressively harder.
  static LevelParams _paramsAtTier(String worldId, double tier) {
    // Reuse the hand-tuned curve up to tier=1.0, then linearly extrapolate.
    final at0 = LevelDifficulty.paramsFor(
        worldId: worldId, indexInWorld: 0, worldLength: 2); // t=0
    final at1 = LevelDifficulty.paramsFor(
        worldId: worldId, indexInWorld: 1, worldLength: 2); // t=1
    // Extrapolate beyond tier 1 but cap so it's still humanly playable.
    final t = tier.clamp(0.0, 3.0);
    final speed = _lerp(at0.piggySpeed, at1.piggySpeed, t).clamp(180.0, 720.0);
    final ammoMax = _lerpInt(at0.ammoMax, at1.ammoMax, t).clamp(6, 40);
    final ammoMin = _lerpInt(at0.ammoMin, at1.ammoMin, t).clamp(3, ammoMax);
    final interval =
        _lerp(at0.spawnInterval, at1.spawnInterval, t).clamp(0.35, 1.20);
    return LevelParams(
      piggySpeed: speed,
      ammoMin: ammoMin,
      ammoMax: ammoMax,
      spawnInterval: interval,
    );
  }

  static List<PiggyType> _rewardsAtTier(String worldId, double tier) {
    // Piggy-park has 0/2 rewards at low tier; every other world always has
    // combo rewards. Above tier 1, the pool is always "late tier".
    final t = tier.clamp(0.0, 2.0);
    final len = t > 1.0 ? 2 : 2; // both extrapolated cases
    final idx = t > 1.0 ? 1 : (t * (len - 1)).round();
    return LevelDifficulty.rewardsFor(
        worldId: worldId, indexInWorld: idx, worldLength: len);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
  static int _lerpInt(int a, int b, double t) => (a + (b - a) * t).round();

  // ---------------------------------------------------------------------
  // Per-world template dispatch
  // ---------------------------------------------------------------------

  /// Remember the last few templates picked per world, so the same one
  /// doesn't fire twice in a row. Ring-buffer per world, size = min(3, gens/2).
  static final Map<String, List<int>> _recentTemplates = {};

  static _GenFn _pickGenerator(String worldId, math.Random rng) {
    final gens = switch (worldId) {
      'piggypark' => _piggyparkGens,
      'factory' => _factoryGens,
      'gallery' => _galleryGens,
      'frozen' => _frozenGens,
      _ => _piggyparkGens,
    };
    final recent = _recentTemplates.putIfAbsent(worldId, () => <int>[]);
    final banSize = math.min(3, gens.length ~/ 2);
    // Try up to 8 times to pick a non-recently-used template.
    int idx = rng.nextInt(gens.length);
    for (var i = 0; i < 8 && recent.contains(idx); i++) {
      idx = rng.nextInt(gens.length);
    }
    recent.add(idx);
    if (recent.length > banSize) recent.removeAt(0);
    return gens[idx];
  }

  // ---------------------------------------------------------------------
  // PiggyPark: pure colour mosaics, 2..4 colours
  // ---------------------------------------------------------------------

  static final List<_GenFn> _piggyparkGens = [
    _mosaicRandom,
    _mosaicStripes,
    _mosaicCheckerboard,
    _mosaicQuadrants,
    _mosaicHorizontalBands,
    _mosaicScatteredIslands,
  ];

  static _GenResult _mosaicHorizontalBands(math.Random rng, double tier) {
    // Horizontal 2-cell bands per row — like stripes but rotated.
    final palette = _palette(rng, _colorCountForTier(tier, base: 3, peak: 5));
    final rows = 6 + rng.nextInt(2);
    const cols = 8;
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < rows; r++) {
      final row = <BlockSpec?>[];
      final band = (r ~/ 2) % palette.length;
      for (var c = 0; c < cols; c++) {
        row.add(BlockSpec(color: palette[band]));
      }
      grid.add(row);
    }
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'piggypark', indexInWorld: 2, worldLength: 5));
  }

  static _GenResult _mosaicScatteredIslands(math.Random rng, double tier) {
    // 3–5 disconnected islands of coloured blocks on empty board.
    final palette = _palette(rng, _colorCountForTier(tier, base: 3, peak: 5));
    const rows = 7;
    const cols = 9;
    final grid = List.generate(rows, (_) => List<BlockSpec?>.filled(cols, null));
    final islandCount = 3 + rng.nextInt(3);
    for (var i = 0; i < islandCount; i++) {
      final cx = 1 + rng.nextInt(cols - 2);
      final cy = 1 + rng.nextInt(rows - 2);
      final color = palette[rng.nextInt(palette.length)];
      final radius = 1 + rng.nextInt(2);
      for (var dr = -radius; dr <= radius; dr++) {
        for (var dc = -radius; dc <= radius; dc++) {
          final r = cy + dr;
          final c = cx + dc;
          if (r < 0 || r >= rows || c < 0 || c >= cols) continue;
          if (dr.abs() + dc.abs() > radius) continue;
          grid[r][c] = BlockSpec(color: color);
        }
      }
    }
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'piggypark', indexInWorld: 3, worldLength: 5));
  }

  static _GenResult _mosaicRandom(math.Random rng, double tier) {
    final palette = _palette(rng, _colorCountForTier(tier, base: 2, peak: 4));
    final rows = 5 + rng.nextInt(3); // 5..7
    final cols = 6 + rng.nextInt(3); // 6..8
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < rows; r++) {
      final row = <BlockSpec?>[];
      for (var c = 0; c < cols; c++) {
        row.add(BlockSpec(color: palette[rng.nextInt(palette.length)]));
      }
      grid.add(row);
    }
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'piggypark', indexInWorld: 2, worldLength: 5));
  }

  static _GenResult _mosaicStripes(math.Random rng, double tier) {
    final palette = _palette(rng, _colorCountForTier(tier, base: 2, peak: 4));
    final rows = 5 + rng.nextInt(2);
    final cols = 8;
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < rows; r++) {
      final row = <BlockSpec?>[];
      for (var c = 0; c < cols; c++) {
        // Vertical stripes; width 2 for readability.
        final stripe = (c ~/ 2) % palette.length;
        row.add(BlockSpec(color: palette[stripe]));
      }
      grid.add(row);
    }
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'piggypark', indexInWorld: 2, worldLength: 5));
  }

  static _GenResult _mosaicCheckerboard(math.Random rng, double tier) {
    final palette = _palette(rng, _colorCountForTier(tier, base: 2, peak: 3));
    final rows = 5;
    final cols = 8;
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < rows; r++) {
      final row = <BlockSpec?>[];
      for (var c = 0; c < cols; c++) {
        row.add(BlockSpec(color: palette[(r + c) % palette.length]));
      }
      grid.add(row);
    }
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'piggypark', indexInWorld: 2, worldLength: 5));
  }

  static _GenResult _mosaicQuadrants(math.Random rng, double tier) {
    final palette = _palette(rng, 4);
    final rows = 6;
    final cols = 8;
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < rows; r++) {
      final row = <BlockSpec?>[];
      final vertical = r < rows / 2 ? 0 : 2;
      for (var c = 0; c < cols; c++) {
        final horiz = c < cols / 2 ? 0 : 1;
        row.add(BlockSpec(color: palette[vertical + horiz]));
      }
      grid.add(row);
    }
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'piggypark', indexInWorld: 2, worldLength: 5));
  }

  // ---------------------------------------------------------------------
  // Factory: mosaic + scattered armored/dual/stone, density from tier
  // ---------------------------------------------------------------------

  static final List<_GenFn> _factoryGens = [
    _factoryMosaicArmored,
    _factoryMosaicWithStones,
    _factoryDualScattered,
    _factoryFortress,
    _factoryChannels,
  ];

  static _GenResult _factoryFortress(math.Random rng, double tier) {
    // Solid armored border, mixed coloured interior with scattered dual blocks.
    final palette = _palette(rng, 4);
    const rows = 6;
    const cols = 8;
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < rows; r++) {
      final row = <BlockSpec?>[];
      for (var c = 0; c < cols; c++) {
        final onBorder = r == 0 || r == rows - 1 || c == 0 || c == cols - 1;
        final color = palette[rng.nextInt(palette.length)];
        if (onBorder) {
          row.add(BlockSpec(color: color, hp: 2));
        } else if (rng.nextDouble() < 0.20 + 0.15 * tier) {
          var inner = palette[rng.nextInt(palette.length)];
          if (inner == color) inner = palette[(palette.indexOf(inner) + 1) % palette.length];
          row.add(BlockSpec(color: color, hp: 2, innerColor: inner));
        } else {
          row.add(BlockSpec(color: color));
        }
      }
      grid.add(row);
    }
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'factory', indexInWorld: 3, worldLength: 5));
  }

  static _GenResult _factoryChannels(math.Random rng, double tier) {
    // Vertical stone channels forming corridors that force careful column choices.
    final palette = _palette(rng, 4);
    const rows = 6;
    const cols = 9;
    final channelCols = <int>{2, 5}; // fixed narrow stone walls
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < rows; r++) {
      final row = <BlockSpec?>[];
      for (var c = 0; c < cols; c++) {
        if (channelCols.contains(c) && r != 0 && r != rows - 1) {
          row.add(const BlockSpec.stone());
        } else {
          row.add(BlockSpec(color: palette[rng.nextInt(palette.length)]));
        }
      }
      grid.add(row);
    }
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'factory', indexInWorld: 3, worldLength: 5));
  }

  static _GenResult _factoryMosaicArmored(math.Random rng, double tier) {
    final palette = _palette(rng, 4);
    final rows = 6;
    final cols = 8;
    final armoredChance = (0.15 + 0.30 * tier).clamp(0.0, 0.6);
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < rows; r++) {
      final row = <BlockSpec?>[];
      for (var c = 0; c < cols; c++) {
        final color = palette[rng.nextInt(palette.length)];
        final hp = rng.nextDouble() < armoredChance ? 2 : 1;
        row.add(BlockSpec(color: color, hp: hp));
      }
      grid.add(row);
    }
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'factory', indexInWorld: 2, worldLength: 5));
  }

  static _GenResult _factoryMosaicWithStones(math.Random rng, double tier) {
    final palette = _palette(rng, 4);
    final rows = 6;
    final cols = 8;
    final stoneChance = (0.06 + 0.15 * tier).clamp(0.0, 0.28);
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < rows; r++) {
      final row = <BlockSpec?>[];
      for (var c = 0; c < cols; c++) {
        if (rng.nextDouble() < stoneChance) {
          row.add(const BlockSpec.stone());
        } else {
          row.add(BlockSpec(color: palette[rng.nextInt(palette.length)]));
        }
      }
      grid.add(row);
    }
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'factory', indexInWorld: 2, worldLength: 5));
  }

  static _GenResult _factoryDualScattered(math.Random rng, double tier) {
    final palette = _palette(rng, _colorCountForTier(tier, base: 4, peak: 6));
    final rows = 6;
    final cols = 8;
    final dualChance = (0.20 + 0.30 * tier).clamp(0.0, 0.55);
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < rows; r++) {
      final row = <BlockSpec?>[];
      for (var c = 0; c < cols; c++) {
        final outer = palette[rng.nextInt(palette.length)];
        if (rng.nextDouble() < dualChance) {
          var inner = palette[rng.nextInt(palette.length)];
          if (inner == outer) inner = palette[(palette.indexOf(inner) + 1) % palette.length];
          row.add(BlockSpec(color: outer, hp: 2, innerColor: inner));
        } else {
          row.add(BlockSpec(color: outer));
        }
      }
      grid.add(row);
    }
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'factory', indexInWorld: 4, worldLength: 5));
  }

  // ---------------------------------------------------------------------
  // Gallery: symmetric organic shapes (blob, diamond, ring, cross)
  // ---------------------------------------------------------------------

  static final List<_GenFn> _galleryGens = [
    _galleryDiamond,
    _galleryCross,
    _galleryRing,
    _galleryBlob,
    _galleryTriangle,
    _galleryHeart,
  ];

  static _GenResult _galleryTriangle(math.Random rng, double tier) {
    final palette = _palette(rng, _colorCountForTier(tier, base: 3, peak: 5));
    const size = 9;
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < size; r++) {
      final row = <BlockSpec?>[];
      final width = 1 + r * 2;
      final start = (size - width) ~/ 2;
      for (var c = 0; c < size; c++) {
        if (c >= start && c < start + width) {
          row.add(BlockSpec(color: palette[(r + c) % palette.length]));
        } else {
          row.add(null);
        }
      }
      grid.add(row);
    }
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'gallery', indexInWorld: 3, worldLength: 5));
  }

  static _GenResult _galleryHeart(math.Random rng, double tier) {
    // Two-lobed heart: two half-circles on top, triangle bottom.
    final palette = _palette(rng, _colorCountForTier(tier, base: 2, peak: 4));
    const rows = 9;
    const cols = 9;
    final grid = List.generate(rows, (_) => List<BlockSpec?>.filled(cols, null));
    // Lobes: two circles at (1,2) and (1,6), radius 2
    for (final cx in [2, 6]) {
      for (var dr = 0; dr <= 2; dr++) {
        for (var dc = -2; dc <= 2; dc++) {
          if (dr * dr + dc * dc > 4) continue;
          final r = 1 + dr;
          final c = cx + dc;
          if (r < 0 || r >= rows || c < 0 || c >= cols) continue;
          grid[r][c] = BlockSpec(color: palette[rng.nextInt(palette.length)]);
        }
      }
    }
    // Bottom triangle from row 3 tapering down.
    for (var r = 3; r < rows - 1; r++) {
      final half = math.max(0, (rows - 2) - r);
      for (var c = 4 - half; c <= 4 + half; c++) {
        if (c < 0 || c >= cols) continue;
        grid[r][c] = BlockSpec(color: palette[rng.nextInt(palette.length)]);
      }
    }
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'gallery', indexInWorld: 3, worldLength: 5));
  }

  static _GenResult _galleryDiamond(math.Random rng, double tier) {
    final palette = _palette(rng, _colorCountForTier(tier, base: 3, peak: 6));
    const rows = 9;
    const cols = 9;
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < rows; r++) {
      final row = <BlockSpec?>[];
      for (var c = 0; c < cols; c++) {
        final dr = (r - rows ~/ 2).abs();
        final dc = (c - cols ~/ 2).abs();
        if (dr + dc <= rows ~/ 2) {
          row.add(BlockSpec(color: palette[(dr + dc) % palette.length]));
        } else {
          row.add(null);
        }
      }
      grid.add(row);
    }
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'gallery', indexInWorld: 2, worldLength: 5));
  }

  static _GenResult _galleryCross(math.Random rng, double tier) {
    final palette = _palette(rng, _colorCountForTier(tier, base: 3, peak: 5));
    const size = 9;
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < size; r++) {
      final row = <BlockSpec?>[];
      for (var c = 0; c < size; c++) {
        final inArm = r >= 3 && r <= 5 || c >= 3 && c <= 5;
        if (inArm) {
          row.add(BlockSpec(color: palette[(r * c) % palette.length]));
        } else {
          row.add(null);
        }
      }
      grid.add(row);
    }
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'gallery', indexInWorld: 2, worldLength: 5));
  }

  static _GenResult _galleryRing(math.Random rng, double tier) {
    final palette = _palette(rng, _colorCountForTier(tier, base: 3, peak: 5));
    const size = 9;
    final grid = <List<BlockSpec?>>[];
    final cx = size / 2 - 0.5, cy = size / 2 - 0.5;
    for (var r = 0; r < size; r++) {
      final row = <BlockSpec?>[];
      for (var c = 0; c < size; c++) {
        final dist = math.sqrt(math.pow(r - cy, 2) + math.pow(c - cx, 2));
        if (dist > 1.4 && dist < 4.2) {
          row.add(BlockSpec(color: palette[(r + c) % palette.length]));
        } else {
          row.add(null);
        }
      }
      grid.add(row);
    }
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'gallery', indexInWorld: 4, worldLength: 5));
  }

  static _GenResult _galleryBlob(math.Random rng, double tier) {
    // Grow a random blob from centre using flood-fill with random extents.
    final palette = _palette(rng, _colorCountForTier(tier, base: 3, peak: 6));
    const size = 9;
    final grid = List.generate(size, (_) => List<BlockSpec?>.filled(size, null));
    final cx = size ~/ 2, cy = size ~/ 2;
    final cells = <List<int>>[
      [cx, cy]
    ];
    final visited = <String>{'${cx}_$cy'};
    final targetSize = 25 + rng.nextInt(15);
    while (cells.length < targetSize && visited.length < size * size) {
      final pick = cells[rng.nextInt(cells.length)];
      const dirs = [
        [1, 0], [-1, 0], [0, 1], [0, -1],
      ];
      final d = dirs[rng.nextInt(4)];
      final nr = pick[0] + d[0];
      final nc = pick[1] + d[1];
      if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
      final k = '${nr}_$nc';
      if (visited.contains(k)) continue;
      visited.add(k);
      cells.add([nr, nc]);
    }
    for (final cell in cells) {
      grid[cell[0]][cell[1]] = BlockSpec(color: palette[rng.nextInt(palette.length)]);
    }
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'gallery', indexInWorld: 2, worldLength: 5));
  }

  // ---------------------------------------------------------------------
  // Frozen: mosaic + 1..3 portal pairs, ideally in different columns/rows
  // ---------------------------------------------------------------------

  static final List<_GenFn> _frozenGens = [
    _frozenSinglePortalPair,
    _frozenTwoPortalPairs,
    _frozenPortalsWithStones,
    _frozenPortalsWithArmored,
    _frozenDenseWithThreePairs,
  ];

  static _GenResult _frozenPortalsWithArmored(math.Random rng, double tier) {
    final palette = _palette(rng, _colorCountForTier(tier, base: 4, peak: 6));
    const rows = 6;
    const cols = 8;
    final armoredChance = (0.15 + 0.25 * tier).clamp(0.0, 0.45);
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < rows; r++) {
      final row = <BlockSpec?>[];
      for (var c = 0; c < cols; c++) {
        final color = palette[rng.nextInt(palette.length)];
        final hp = rng.nextDouble() < armoredChance ? 2 : 1;
        row.add(BlockSpec(color: color, hp: hp));
      }
      grid.add(row);
    }
    _placePortalPair(grid, rng, id: 0);
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'frozen', indexInWorld: 3, worldLength: 5));
  }

  static _GenResult _frozenDenseWithThreePairs(math.Random rng, double tier) {
    final palette = _palette(rng, _colorCountForTier(tier, base: 4, peak: 6));
    const rows = 7;
    const cols = 8;
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < rows; r++) {
      final row = <BlockSpec?>[];
      for (var c = 0; c < cols; c++) {
        row.add(BlockSpec(color: palette[rng.nextInt(palette.length)]));
      }
      grid.add(row);
    }
    _placePortalPair(grid, rng, id: 0);
    _placePortalPair(grid, rng, id: 1);
    _placePortalPair(grid, rng, id: 2);
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'frozen', indexInWorld: 4, worldLength: 5));
  }

  static _GenResult _frozenSinglePortalPair(math.Random rng, double tier) {
    final palette = _palette(rng, _colorCountForTier(tier, base: 4, peak: 6));
    const rows = 5;
    const cols = 9;
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < rows; r++) {
      final row = <BlockSpec?>[];
      for (var c = 0; c < cols; c++) {
        row.add(BlockSpec(color: palette[rng.nextInt(palette.length)]));
      }
      grid.add(row);
    }
    // Pair A: pick two cells in different columns AND different rows.
    final aR1 = rng.nextInt(rows);
    final aC1 = rng.nextInt(cols ~/ 2);
    var aR2 = rng.nextInt(rows);
    var aC2 = cols ~/ 2 + rng.nextInt(cols - cols ~/ 2);
    if (aR2 == aR1) aR2 = (aR1 + 1) % rows;
    grid[aR1][aC1] = const BlockSpec.portal(0);
    grid[aR2][aC2] = const BlockSpec.portal(0);
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'frozen', indexInWorld: 2, worldLength: 5));
  }

  static _GenResult _frozenTwoPortalPairs(math.Random rng, double tier) {
    final palette = _palette(rng, _colorCountForTier(tier, base: 4, peak: 6));
    const rows = 6;
    const cols = 8;
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < rows; r++) {
      final row = <BlockSpec?>[];
      for (var c = 0; c < cols; c++) {
        row.add(BlockSpec(color: palette[rng.nextInt(palette.length)]));
      }
      grid.add(row);
    }
    _placePortalPair(grid, rng, id: 0);
    _placePortalPair(grid, rng, id: 1);
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'frozen', indexInWorld: 3, worldLength: 5));
  }

  static _GenResult _frozenPortalsWithStones(math.Random rng, double tier) {
    final palette = _palette(rng, _colorCountForTier(tier, base: 4, peak: 6));
    const rows = 6;
    const cols = 8;
    final stoneChance = (0.05 + 0.10 * tier).clamp(0.0, 0.20);
    final grid = <List<BlockSpec?>>[];
    for (var r = 0; r < rows; r++) {
      final row = <BlockSpec?>[];
      for (var c = 0; c < cols; c++) {
        if (rng.nextDouble() < stoneChance) {
          row.add(const BlockSpec.stone());
        } else {
          row.add(BlockSpec(color: palette[rng.nextInt(palette.length)]));
        }
      }
      grid.add(row);
    }
    _placePortalPair(grid, rng, id: 0);
    if (tier > 0.5) _placePortalPair(grid, rng, id: 1);
    return _GenResult(grid, palette, LevelDifficulty.rewardsFor(
        worldId: 'frozen', indexInWorld: 4, worldLength: 5));
  }

  /// Place a portal pair so the two ends are guaranteed different rows AND
  /// different columns — avoids the shot-line cycle bug from L17.
  static void _placePortalPair(
      List<List<BlockSpec?>> grid, math.Random rng, {required int id}) {
    final rows = grid.length;
    final cols = grid[0].length;
    for (var tries = 0; tries < 30; tries++) {
      final r1 = rng.nextInt(rows);
      final c1 = rng.nextInt(cols);
      final r2 = rng.nextInt(rows);
      final c2 = rng.nextInt(cols);
      if (r1 == r2 || c1 == c2) continue;
      // Don't overwrite an existing portal.
      if (grid[r1][c1]?.isPortal == true) continue;
      if (grid[r2][c2]?.isPortal == true) continue;
      grid[r1][c1] = BlockSpec.portal(id);
      grid[r2][c2] = BlockSpec.portal(id);
      return;
    }
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  static List<PiggyColor> _palette(math.Random rng, int count) {
    final all = List<PiggyColor>.from(PiggyColor.values)..shuffle(rng);
    return all.take(count.clamp(1, PiggyColor.values.length)).toList();
  }

  static int _colorCountForTier(double tier,
      {required int base, required int peak}) {
    final n = base + ((peak - base) * tier.clamp(0.0, 1.0)).round();
    return n.clamp(base, peak);
  }

  static List<PiggyColor> _palette4(math.Random rng) => _palette(rng, 4);

  static List<List<BlockSpec?>> _fallbackMosaic(math.Random rng) {
    final palette = _palette(rng, 3);
    return [
      for (var r = 0; r < 4; r++)
        [for (var c = 0; c < 6; c++) BlockSpec(color: palette[(r + c) % palette.length])]
    ];
  }

  // ---------------------------------------------------------------------
  // Playability check — no orphan coloured cell
  // ---------------------------------------------------------------------

  /// Return true if EVERY destroyable (non-stone, non-portal) block is
  /// reachable from at least one board edge, accounting for portal teleports.
  static bool _isPlayable(List<List<BlockSpec?>> grid) {
    final rows = grid.length;
    if (rows == 0) return false;
    final cols = grid[0].length;
    // For each column shoot rays from top and bottom, for each row from left
    // and right. Mark every reachable cell. Then verify all coloured cells
    // are marked.
    final reached = List.generate(rows, (_) => List.filled(cols, false));
    for (var c = 0; c < cols; c++) {
      _rayMark(grid, reached, 0, c, 1, 0);
      _rayMark(grid, reached, rows - 1, c, -1, 0);
    }
    for (var r = 0; r < rows; r++) {
      _rayMark(grid, reached, r, 0, 0, 1);
      _rayMark(grid, reached, r, cols - 1, 0, -1);
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final b = grid[r][c];
        if (b == null || b.isStone || b.isPortal) continue;
        if (!reached[r][c]) return false;
      }
    }
    return true;
  }

  static void _rayMark(List<List<BlockSpec?>> grid,
      List<List<bool>> reached, int r0, int c0, int dr, int dc,
      {int hops = 0}) {
    if (hops > 3) return;
    final rows = grid.length;
    final cols = grid[0].length;
    var r = r0;
    var c = c0;
    while (r >= 0 && r < rows && c >= 0 && c < cols) {
      final b = grid[r][c];
      if (b == null) {
        r += dr;
        c += dc;
        continue;
      }
      if (b.isPortal) {
        // Find pair, continue from pair in same direction.
        for (var rr = 0; rr < rows; rr++) {
          for (var cc = 0; cc < cols; cc++) {
            if (rr == r && cc == c) continue;
            final other = grid[rr][cc];
            if (other == null) continue;
            if (other.isPortal && other.portalPairId == b.portalPairId) {
              _rayMark(grid, reached, rr + dr, cc + dc, dr, dc, hops: hops + 1);
              return;
            }
          }
        }
        return;
      }
      // Hit a solid cell — mark it reached, done for this ray.
      reached[r][c] = true;
      return;
    }
  }
}

// ---------------------------------------------------------------------
// Internal types
// ---------------------------------------------------------------------

typedef _GenFn = _GenResult Function(math.Random rng, double tier);

class _GenResult {
  const _GenResult(this.grid, this.palette, this.rewards);
  final List<List<BlockSpec?>> grid;
  final List<PiggyColor> palette;
  final List<PiggyType> rewards;
}
