import 'models.dart';

/// Legend for pixel-art shape strings passed to [shape]:
///   '.' — empty cell (shot flies through)
///   'p' — pink       'c' — cyan       'y' — yellow
///   'g' — green      'v' — purple     'o' — orange
///   'S' — stone (grey, unbreakable — used for outlines / accents / whites)
///
/// Every row MUST be the same length or [shape] throws. Rows are top-down.
List<List<BlockSpec?>> shape(List<String> rows) {
  const p = BlockSpec(color: PiggyColor.pink);
  const c = BlockSpec(color: PiggyColor.cyan);
  const y = BlockSpec(color: PiggyColor.yellow);
  const g = BlockSpec(color: PiggyColor.green);
  const v = BlockSpec(color: PiggyColor.purple);
  const o = BlockSpec(color: PiggyColor.orange);
  const s = BlockSpec.stone();
  final width = rows.first.length;
  return [
    for (final row in rows)
      [
        for (final ch in _requireWidth(row, width).split(''))
          switch (ch) {
            'p' => p,
            'c' => c,
            'y' => y,
            'g' => g,
            'v' => v,
            'o' => o,
            'S' => s,
            _ => null,
          }
      ]
  ];
}

String _requireWidth(String row, int width) {
  assert(row.length == width,
      'shape row "$row" is ${row.length} chars, expected $width');
  return row;
}

/// Standard palette for shape levels — all 6 colours available.
const List<PiggyColor> allColors = [
  PiggyColor.pink,
  PiggyColor.cyan,
  PiggyColor.yellow,
  PiggyColor.green,
  PiggyColor.purple,
  PiggyColor.orange,
];

// ============================================================
// Shape gallery — L11+. Grid is 12 cols wide × 11 rows tall
// (fits comfortably in the game board without shrinking blocks).
// ============================================================

/// L11 — ДОМИК. Оранжевая крыша, розовые стены, жёлтые окна, зелёная дверь,
/// каменный фундамент.
final List<List<BlockSpec?>> shapeHouse = shape([
  '.....oo.....',
  '....oooo....',
  '...oooooo...',
  '..oooooooo..',
  '.oooooooooo.',
  'oooooooooooo',
  'pppppppppppp',
  'pyyppppppyyp',
  'pyyppppppyyp',
  'pppppggppppp',
  'SSSSSSSSSSSS',
]);

/// L12 — МУХОМОР. Розовая шапка с серо-каменными точками, жёлтая ножка,
/// зелёная трава у основания.
final List<List<BlockSpec?>> shapeMushroom = shape([
  '...pppppp...',
  '..pppSpppp..',
  '.pppppppppp.',
  'ppSpppppSppp',
  'pppppppppppp',
  'ppppSppppppp',
  '..yyyyyyyy..',
  '..yyyyyyyy..',
  '..yyyyyyyy..',
  '.gyyyyyyyyg.',
  'gggggggggggg',
]);

/// L13 — СЕРДЦЕ. Розовая заливка с оранжевой верхней окантовкой и
/// фиолетовым «острым» низом.
final List<List<BlockSpec?>> shapeHeart = shape([
  '..pp....pp..',
  '.oppo..oppo.',
  'oppppppppppo',
  'pppppppppppp',
  'pppppppppppp',
  '.pppppppppp.',
  '..pppppppp..',
  '...vvvvvv...',
  '....vvvv....',
  '.....vv.....',
]);

/// L14 — ЗВЕЗДА. Классическая пятиконечная жёлтая с оранжевой окантовкой.
final List<List<BlockSpec?>> shapeStar = shape([
  '.....yy.....',
  '....yyyy....',
  '....yyyy....',
  'oooyyyyyyooo',
  'oyyyyyyyyyyo',
  '.yyyyyyyyyy.',
  '..yyyyyyyy..',
  '.yyyyyyyyyy.',
  '.yyy.yy.yyy.',
  'yyo...yy...o',
  'yy........yy',
]);

/// L15 — РЫБА. Голубое тело с глазом (жёлтый), оранжевый хвост,
/// зелёная водоросль внизу. Gallery boss — большая, насыщенная.
final List<List<BlockSpec?>> shapeFish = shape([
  '............',
  '...cccccc.oo',
  '..ccccyccooo',
  '.cccccccccoo',
  'cccccccccccc',
  'cccccyccccoo',
  '.cccccccccoo',
  '..ccccccccoo',
  '...cccccc.oo',
  '............',
  '.gg.gg.gg.gg',
]);
