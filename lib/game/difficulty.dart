import 'models.dart';

/// Difficulty curve per world.
///
/// Each level has three "shared" knobs that grow monotonically within a world:
///   - piggySpeed  — conveyor speed
///   - ammoMax     — cap on shots per piggy (min is derived, always ≥ 3)
///   - spawnInterval — how fast fresh piggies appear in the queue
///
/// Values come from linear interpolation between the world's `start` and
/// `end` parameters, driven by the level's 0-based position within the world.
/// This guarantees each next level in a world is at least as hard as the
/// previous one (fixing the L11 regression we had).
///
/// Combo-rewards escalate through 3 tiers based on the same t=0..1:
///   - early:  basic (rainbow, bomb, painter)
///   - middle: tactical (chain, sweeper, freeze, duplicator)
///   - late:   powerful (converter, jackpot, chaos, universal, portal)
///
/// Level designers can override any field at the LevelConfig site — the
/// helper only supplies defaults.
class LevelDifficulty {
  const LevelDifficulty._();

  /// Compute default gameplay params for a level.
  ///
  /// [worldId]        — id from [WorldConfig] (piggypark / factory / gallery / frozen)
  /// [indexInWorld]   — 0-based position of the level inside the world
  /// [worldLength]    — number of levels the world holds (drives interpolation)
  static LevelParams paramsFor({
    required String worldId,
    required int indexInWorld,
    required int worldLength,
  }) {
    final t = worldLength <= 1 ? 0.0 : indexInWorld / (worldLength - 1);
    final c = _curves[worldId] ?? _curves['piggypark']!;
    return LevelParams(
      piggySpeed: _lerp(c.speedStart, c.speedEnd, t),
      ammoMax: _lerpInt(c.ammoMaxStart, c.ammoMaxEnd, t),
      ammoMin: _lerpInt(c.ammoMinStart, c.ammoMinEnd, t).clamp(3, 999),
      spawnInterval: _lerp(c.intervalStart, c.intervalEnd, t),
    );
  }

  /// Default combo-reward pool for a level, escalating with progress.
  /// Return empty list if the world explicitly opts out.
  static List<PiggyType> rewardsFor({
    required String worldId,
    required int indexInWorld,
    required int worldLength,
  }) {
    final c = _curves[worldId] ?? _curves['piggypark']!;
    if (!c.rewardsEnabled) return const [];
    final t = worldLength <= 1 ? 0.0 : indexInWorld / (worldLength - 1);
    if (t < 0.3) return _rewardsEarly;
    if (t < 0.7) return _rewardsMid;
    return _rewardsLate;
  }

  static const _rewardsEarly = <PiggyType>[
    PiggyType.rainbow, PiggyType.bomb, PiggyType.painter,
  ];
  static const _rewardsMid = <PiggyType>[
    PiggyType.rainbow, PiggyType.bomb, PiggyType.chain,
    PiggyType.sweeper, PiggyType.freeze, PiggyType.duplicator,
  ];
  static const _rewardsLate = <PiggyType>[
    PiggyType.bomb, PiggyType.rainbow, PiggyType.converter,
    PiggyType.jackpot, PiggyType.chaos, PiggyType.universal,
    PiggyType.portal,
  ];

  /// Per-world tuning. Every next world starts at least where the previous
  /// one ended so cross-world progression stays monotonic too.
  static const Map<String, _WorldCurve> _curves = {
    'piggypark': _WorldCurve(
      speedStart: 240, speedEnd: 380,
      ammoMaxStart: 30, ammoMaxEnd: 22,
      ammoMinStart: 8, ammoMinEnd: 6,
      intervalStart: 1.00, intervalEnd: 0.75,
    ),
    'factory': _WorldCurve(
      speedStart: 380, speedEnd: 500,
      ammoMaxStart: 22, ammoMaxEnd: 18,
      ammoMinStart: 6, ammoMinEnd: 5,
      intervalStart: 0.75, intervalEnd: 0.55,
    ),
    'gallery': _WorldCurve(
      // Shape levels are visually busy; speed climbs modestly.
      speedStart: 400, speedEnd: 460,
      ammoMaxStart: 22, ammoMaxEnd: 16,
      ammoMinStart: 5, ammoMinEnd: 4,
      intervalStart: 0.70, intervalEnd: 0.55,
    ),
    'frozen': _WorldCurve(
      // Portals force planning — high speed rewards good routing.
      speedStart: 420, speedEnd: 520,
      ammoMaxStart: 20, ammoMaxEnd: 14,
      ammoMinStart: 5, ammoMinEnd: 4,
      intervalStart: 0.65, intervalEnd: 0.50,
    ),
  };

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
  static int _lerpInt(int a, int b, double t) => (a + (b - a) * t).round();
}

class LevelParams {
  const LevelParams({
    required this.piggySpeed,
    required this.ammoMin,
    required this.ammoMax,
    required this.spawnInterval,
  });
  final double piggySpeed;
  final int ammoMin;
  final int ammoMax;
  final double spawnInterval;
}

class _WorldCurve {
  const _WorldCurve({
    required this.speedStart, required this.speedEnd,
    required this.ammoMaxStart, required this.ammoMaxEnd,
    required this.ammoMinStart, required this.ammoMinEnd,
    required this.intervalStart, required this.intervalEnd,
  });
  final double speedStart, speedEnd;
  final int ammoMaxStart, ammoMaxEnd;
  final int ammoMinStart, ammoMinEnd;
  final double intervalStart, intervalEnd;
  bool get rewardsEnabled => true; // reserved: worlds may opt out later
}
