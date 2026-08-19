// Puzzle-mode scoring: equality score, DMC-style rank, deviation bars.
//
// Pure computation. No Flame/Flutter engine deps beyond the PiggyColor enum
// from models.dart (which itself only uses Color for palette info — safe to
// import from unit tests).
//
// Design references (as agreed in project chat 2026-08-11):
//  - golf par            → targetLaunches
//  - osu! accuracy       → weighted equality score
//  - DMC ranks           → Rank.d..ss
//  - Hitman GO checklist → ChecklistState
//  - Portal medals       → mapped from rank
//  - Opus Magnum         → normalized per-criterion deviation
//  - WoG OCD             → isPerfect + perfectBonusMultiplier
//
// The 5 criteria the promt asked for map here as:
//   * launches ↔ moves       (weight 0.45 — dominant)
//   * hits (via unused ammo)  (weight 0.25)
//   * colors                  (weight 0.15)
//   * combos                  (weight 0.15)
//   * sequence                (optional checklist only, doesn't feed equality
//                              in the default weights — random spawner era
//                              is over but the ordering criterion stays soft)
//
// Wasted-hits semantics (agreed 2026-08-11): `hitsDev` is driven by
// `unusedAmmo`, defined as Σ leftover ammo across every LAUNCHED piggy at
// end-of-level (both `leaving` piggies and piggies still in waiting slots
// at WIN). Un-launched piggies do NOT count — they are spared, not wasted.
// This makes L2 ("burned all 6 → 2 wasted") and L5 ("keep the spare") share
// one metric.

import 'models.dart';

/// DMC-style rank scale. Serialized as lowercase in prefs / analytics.
enum Rank { d, c, b, a, s, ss }

/// Weights per criterion. Must sum to 1.0 for a well-behaved equality score,
/// but the compute method does not enforce this — override at will.
class EqualityWeights {
  final double launches;
  final double hits;
  final double colors;
  final double combos;

  const EqualityWeights({
    required this.launches,
    required this.hits,
    required this.colors,
    required this.combos,
  });

  static const balanced = EqualityWeights(
    launches: 0.45,
    hits: 0.25,
    colors: 0.15,
    combos: 0.15,
  );

  double get sum => launches + hits + colors + combos;
}

/// Cutoffs for turning an equality score (0..1) into a rank.
/// Perfect requires a separate structural check (isPerfect), not just eq ≥ x.
class ScoringThresholds {
  final double sRank;
  final double aRank;
  final double bRank;
  final double cRank;
  final double perfectEquality;

  const ScoringThresholds({
    this.sRank = 0.90,
    this.aRank = 0.80,
    this.bRank = 0.65,
    this.cRank = 0.45,
    this.perfectEquality = 0.98,
  });
}

/// The design intent for a level — what "perfect" means.
class LevelTargetConfig {
  final int targetLaunches;
  final int targetHits;
  final Map<PiggyColor, int> targetHitsByColor;
  final Set<PiggyColor> allowedColors;
  final List<PiggyColor>? optionalSequence;

  /// launches ≤ targetLaunches + softLaunchTolerance → "insidePar" checklist tick.
  final int softLaunchTolerance;

  /// launches > targetLaunches + failLaunchOverflow → level fails (rank D).
  final int failLaunchOverflow;

  /// launches ≤ targetLaunches + perfectLaunchTolerance → Perfect eligible.
  final int perfectLaunchTolerance;

  /// Baseline for combo criterion — how many combos the designer expects.
  /// Meeting it → deviation 0. Below → linear penalty. Above → still 0 (bonus).
  final int expectedCombos;

  /// Puzzle-mode "third star". Independent from rank/perfect — the level can
  /// be S-ranked with mastery failed, or D-ranked with mastery passed. UI
  /// shows it as a separate checklist tick.
  final MasteryChallenge? masteryChallenge;

  final double baseScore;
  final double perfectBonusMultiplier;
  final EqualityWeights weights;
  final ScoringThresholds thresholds;

  const LevelTargetConfig({
    required this.targetLaunches,
    required this.targetHits,
    this.targetHitsByColor = const {},
    this.allowedColors = const {},
    this.optionalSequence,
    this.softLaunchTolerance = 2,
    this.failLaunchOverflow = 6,
    this.perfectLaunchTolerance = 0,
    this.expectedCombos = 1,
    this.masteryChallenge,
    this.baseScore = 100.0,
    this.perfectBonusMultiplier = 2.5,
    this.weights = EqualityWeights.balanced,
    this.thresholds = const ScoringThresholds(),
  });
}

/// What actually happened by end-of-level.
class ActualPlayStats {
  final int launchesMade;

  /// Total shots that actually hit a block (game.shotsFired). Informational
  /// only — the wasted metric is [unusedAmmo].
  final int shotsFired;

  /// Σ leftover ammo across every LAUNCHED piggy at end-of-level.
  /// Un-launched piggies (still in queue/waiting, never tapped) do not count.
  /// This is the wasted-hits metric.
  final int unusedAmmo;

  final Map<PiggyColor, int> hitsByColor;
  final Set<PiggyColor> colorsUsed;
  final int combosTriggered;
  final int maxComboSize;
  final List<PiggyColor>? actualSequence;

  /// True iff every non-stone/non-portal block was destroyed.
  final bool cleared;

  const ActualPlayStats({
    required this.launchesMade,
    required this.shotsFired,
    required this.unusedAmmo,
    required this.cleared,
    this.hitsByColor = const {},
    this.colorsUsed = const {},
    this.combosTriggered = 0,
    this.maxComboSize = 0,
    this.actualSequence,
  });
}

/// Per-criterion deviation, all in [0, 1]. 0 = perfect, 1 = maximum bad.
/// [sequence] is null iff no optionalSequence was configured.
class Deviation {
  final double launches;
  final double hits;
  final double colors;
  final double combos;
  final double? sequence;

  const Deviation({
    required this.launches,
    required this.hits,
    required this.colors,
    required this.combos,
    this.sequence,
  });

  double weighted(EqualityWeights w) =>
      launches * w.launches +
      hits * w.hits +
      colors * w.colors +
      combos * w.combos;
}

/// Hitman-GO style tick list. `sequencePreserved` is null iff no
/// optionalSequence was configured.
class ChecklistState {
  final bool cleared;
  final bool insidePar;
  final bool noExtraColors;
  final bool allTargetColorsUsed;

  /// No launched piggy left the belt (or sat in waiting at WIN) with ammo > 0.
  final bool noWastedAmmo;

  final bool? sequencePreserved;

  /// Puzzle-mode "third star" — see [MasteryChallenge]. Null iff the level
  /// declared no mastery challenge; false → tried and missed; true → passed.
  final bool? masteryPassed;

  /// Human-readable label for the mastery challenge (e.g. «Ни одного
  /// выстрела впустую»). Null iff [masteryPassed] is null.
  final String? masteryLabel;

  const ChecklistState({
    required this.cleared,
    required this.insidePar,
    required this.noExtraColors,
    required this.allTargetColorsUsed,
    required this.noWastedAmmo,
    this.sequencePreserved,
    this.masteryPassed,
    this.masteryLabel,
  });

  int get completed {
    var n = 0;
    if (cleared) n++;
    if (insidePar) n++;
    if (noExtraColors) n++;
    if (allTargetColorsUsed) n++;
    if (noWastedAmmo) n++;
    if (sequencePreserved == true) n++;
    if (masteryPassed == true) n++;
    return n;
  }

  int get total =>
      5 +
      (sequencePreserved == null ? 0 : 1) +
      (masteryPassed == null ? 0 : 1);
}

class LevelResult {
  /// 0-3 stars. Puzzle-mode scoring:
  ///   0★ — level not cleared (destructibles remain).
  ///   1★ — cleared, but launches > target.
  ///   2★ — cleared AND launches ≤ target.
  ///   3★ — 2★ criteria AND mastery challenge passed (or, if no mastery
  ///        was configured, unusedAmmo == 0 as implicit 3★ criterion).
  final int stars;

  final Rank rank;
  final double equalityScore;
  final double finalScore;
  final Deviation deviation;
  final ChecklistState checklist;
  final bool isPerfect;
  final bool isFailed;
  final int launchOverflow;

  /// Σ leftover ammo across LAUNCHED piggies at end-of-level. See
  /// [ActualPlayStats.unusedAmmo] for the definition.
  final int unusedAmmo;

  final String motivationalHint;
  final List<PiggyColor> extraColors;
  final List<PiggyColor> missingColors;

  /// Convenience — mirrors [ChecklistState.masteryPassed] so UIs that don't
  /// dig into the checklist can still show a mastery star. Null iff no
  /// mastery challenge was configured.
  final bool? masteryPassed;

  /// Convenience — mirrors [ChecklistState.masteryLabel].
  final String? masteryLabel;

  // ── UI-friendly stat mirrors ──────────────────────────────────────────────
  // Overlays read these directly instead of digging into ActualPlayStats +
  // LevelTargetConfig. All are copies of the source data, computed by
  // LevelScorer.evaluate.

  /// Actual launches (piggies fired from queue) — mirrors stats.launchesMade.
  final int movesUsed;

  /// Designer's target launch count — mirrors cfg.targetLaunches.
  final int movesTarget;

  /// Shots that actually left a piggy and hit a block.
  final int shotsUsed;

  /// Upper bound on shots the player could have fired given the LAUNCHED
  /// piggies. Equals shotsUsed + unusedAmmo.
  final int shotsTotal;

  /// Distinct colors the player actually fired.
  final Set<PiggyColor> colorsUsed;

  /// Distinct colors the puzzle *requires* — colors present on the board
  /// (excludes dead-color trap piggies from inventory).
  final Set<PiggyColor> colorsRequired;

  const LevelResult({
    required this.stars,
    required this.rank,
    required this.equalityScore,
    required this.finalScore,
    required this.deviation,
    required this.checklist,
    required this.isPerfect,
    required this.isFailed,
    required this.launchOverflow,
    required this.unusedAmmo,
    required this.motivationalHint,
    required this.extraColors,
    required this.missingColors,
    required this.movesUsed,
    required this.movesTarget,
    required this.shotsUsed,
    required this.shotsTotal,
    required this.colorsUsed,
    required this.colorsRequired,
    this.masteryPassed,
    this.masteryLabel,
  });
}

/// Computes per-criterion deviations. Deterministic, no side-effects.
class EqualityScoringService {
  const EqualityScoringService();

  Deviation compute(LevelTargetConfig cfg, ActualPlayStats stats) {
    // Launches: overshoot only. Undershooting par is impossible in PiFlow
    // (you can't clear a board with fewer piggies than needed) but if it
    // does happen (spec piggy sweep), treat as 0 deviation (bonus).
    final launchOverflow =
        (stats.launchesMade - cfg.targetLaunches).clamp(0, 1 << 30).toInt();
    final failOverflow = cfg.failLaunchOverflow <= 0 ? 1 : cfg.failLaunchOverflow;
    final launchDev = (launchOverflow / failOverflow).clamp(0.0, 1.0);

    // Hits: measured via unusedAmmo (leftover ammo on LAUNCHED piggies at
    // level end). Un-launched piggies don't count — spared, not wasted.
    // Normalised against targetHits so denominator scales with level size.
    final hitsDenom = cfg.targetHits <= 0 ? 1 : cfg.targetHits;
    final hitsDev = (stats.unusedAmmo / hitsDenom).clamp(0.0, 1.0);

    // Colors: symmetric difference vs allowed set, normalized by allowed size.
    // If allowedColors is empty, no color criterion — deviation 0.
    double colorDev = 0;
    if (cfg.allowedColors.isNotEmpty) {
      final extra = stats.colorsUsed.difference(cfg.allowedColors);
      final missing = cfg.allowedColors.difference(stats.colorsUsed);
      colorDev =
          ((extra.length + missing.length) / cfg.allowedColors.length)
              .clamp(0.0, 1.0);
    }

    // Combos: shortfall vs expected. Exceeding expectedCombos → 0 (bonus).
    double comboDev = 0;
    if (cfg.expectedCombos > 0) {
      final shortfall =
          (cfg.expectedCombos - stats.combosTriggered).clamp(0, 1 << 30).toInt();
      comboDev = (shortfall / cfg.expectedCombos).clamp(0.0, 1.0);
    }

    // Sequence: LCS-based dissimilarity. Only when both sides configured.
    double? seqDev;
    if (cfg.optionalSequence != null && stats.actualSequence != null) {
      final target = cfg.optionalSequence!;
      if (target.isEmpty) {
        seqDev = 0.0;
      } else {
        final lcs = _lcsLength(target, stats.actualSequence!);
        seqDev = (1 - lcs / target.length).clamp(0.0, 1.0);
      }
    }

    return Deviation(
      launches: launchDev,
      hits: hitsDev,
      colors: colorDev,
      combos: comboDev,
      sequence: seqDev,
    );
  }

  double equalityScore(Deviation d, EqualityWeights w) =>
      (1 - d.weighted(w)).clamp(0.0, 1.0);

  static int _lcsLength(List<PiggyColor> a, List<PiggyColor> b) {
    final n = a.length;
    final m = b.length;
    if (n == 0 || m == 0) return 0;
    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          final left = dp[i][j - 1];
          final up = dp[i - 1][j];
          dp[i][j] = left > up ? left : up;
        }
      }
    }
    return dp[n][m];
  }
}

class RankCalculator {
  const RankCalculator();

  Rank compute({
    required bool cleared,
    required int launchOverflow,
    required int failOverflow,
    required double equality,
    required bool isPerfect,
    ScoringThresholds t = const ScoringThresholds(),
  }) {
    if (!cleared) return Rank.d;
    if (launchOverflow >= failOverflow) return Rank.d;
    if (isPerfect) return Rank.ss;
    if (equality >= t.sRank) return Rank.s;
    if (equality >= t.aRank) return Rank.a;
    if (equality >= t.bRank) return Rank.b;
    if (equality >= t.cRank) return Rank.c;
    return Rank.d;
  }
}

class RewardCalculator {
  const RewardCalculator();

  double compute({
    required LevelTargetConfig cfg,
    required double equalityScore,
    required int launchOverflow,
    required bool isPerfect,
    required bool isFailed,
  }) {
    if (isFailed) return 0.0;
    // Smooth decay: par = 1.0, fail-boundary = 0.4 (never below — you did clear).
    final failOverflow = cfg.failLaunchOverflow <= 0 ? 1 : cfg.failLaunchOverflow;
    final moveMul =
        (1 - (launchOverflow / failOverflow) * 0.6).clamp(0.4, 1.0);
    final perfectMul = isPerfect ? cfg.perfectBonusMultiplier : 1.0;
    return cfg.baseScore * equalityScore * moveMul * perfectMul;
  }
}

/// Orchestrates the whole pipeline. This is the class the game will call.
class LevelScorer {
  final EqualityScoringService scoring;
  final RankCalculator ranker;
  final RewardCalculator rewarder;

  const LevelScorer({
    this.scoring = const EqualityScoringService(),
    this.ranker = const RankCalculator(),
    this.rewarder = const RewardCalculator(),
  });

  LevelResult evaluate(LevelTargetConfig cfg, ActualPlayStats stats) {
    final dev = scoring.compute(cfg, stats);
    final eq = scoring.equalityScore(dev, cfg.weights);

    final launchOverflow =
        (stats.launchesMade - cfg.targetLaunches).clamp(0, 1 << 30).toInt();
    final extra =
        stats.colorsUsed.difference(cfg.allowedColors).toList(growable: false);
    final missing = cfg.allowedColors.isEmpty
        ? const <PiggyColor>[]
        : cfg.allowedColors.difference(stats.colorsUsed).toList(growable: false);

    final isFailed =
        !stats.cleared || launchOverflow >= cfg.failLaunchOverflow;
    final isPerfect = stats.cleared &&
        launchOverflow <= cfg.perfectLaunchTolerance &&
        stats.unusedAmmo == 0 &&
        extra.isEmpty &&
        missing.isEmpty &&
        eq >= cfg.thresholds.perfectEquality;

    final rank = ranker.compute(
      cleared: stats.cleared,
      launchOverflow: launchOverflow,
      failOverflow: cfg.failLaunchOverflow,
      equality: eq,
      isPerfect: isPerfect,
      t: cfg.thresholds,
    );

    // Mastery — the puzzle-mode "third star". Only awarded on cleared runs;
    // failing to clear the board makes any mastery moot.
    bool? masteryPassed;
    String? masteryLabel;
    if (cfg.masteryChallenge != null) {
      masteryLabel = cfg.masteryChallenge!.label;
      masteryPassed = stats.cleared && _evaluateMastery(
        cfg.masteryChallenge!.kind,
        stats,
        launchOverflow,
      );
    }

    final checklist = ChecklistState(
      cleared: stats.cleared,
      insidePar: stats.cleared && launchOverflow <= cfg.softLaunchTolerance,
      noExtraColors: extra.isEmpty,
      allTargetColorsUsed: missing.isEmpty,
      noWastedAmmo: stats.unusedAmmo == 0,
      sequencePreserved: dev.sequence == null ? null : dev.sequence! < 0.1,
      masteryPassed: masteryPassed,
      masteryLabel: masteryLabel,
    );

    final finalScore = rewarder.compute(
      cfg: cfg,
      equalityScore: eq,
      launchOverflow: launchOverflow,
      isPerfect: isPerfect,
      isFailed: isFailed,
    );

    // Stars — Aleksey's 3-tier system (2026-08-12):
    //   0★ not cleared, 1★ cleared but over target, 2★ within target,
    //   3★ within target AND mastery passed (or noWastedAmmo if no mastery).
    int stars;
    if (!stats.cleared) {
      stars = 0;
    } else if (launchOverflow > 0) {
      stars = 1;
    } else if (cfg.masteryChallenge != null) {
      stars = masteryPassed == true ? 3 : 2;
    } else {
      stars = stats.unusedAmmo == 0 ? 3 : 2;
    }

    return LevelResult(
      stars: stars,
      rank: rank,
      equalityScore: eq,
      finalScore: finalScore,
      deviation: dev,
      checklist: checklist,
      isPerfect: isPerfect,
      isFailed: isFailed,
      launchOverflow: launchOverflow,
      unusedAmmo: stats.unusedAmmo,
      extraColors: extra,
      missingColors: missing,
      masteryPassed: masteryPassed,
      masteryLabel: masteryLabel,
      movesUsed: stats.launchesMade,
      movesTarget: cfg.targetLaunches,
      shotsUsed: stats.shotsFired,
      shotsTotal: stats.shotsFired + stats.unusedAmmo,
      colorsUsed: stats.colorsUsed,
      colorsRequired: cfg.allowedColors,
      motivationalHint: _buildHint(
        cfg: cfg,
        stats: stats,
        launchOverflow: launchOverflow,
        stars: stars,
        isPerfect: isPerfect,
        isFailed: isFailed,
      ),
    );
  }

  /// New verdict text (2026-08-12 rewrite). No mention of "par", "S/SS",
  /// "equality" — see UI spec. Focus on ходы + мастерство.
  static String _buildHint({
    required LevelTargetConfig cfg,
    required ActualPlayStats stats,
    required int launchOverflow,
    required int stars,
    required bool isPerfect,
    required bool isFailed,
  }) {
    if (!stats.cleared) {
      return 'Уровень не пройден. Ты был близко — попробуй ещё раз.';
    }
    if (stars == 3) {
      return 'Идеальное прохождение!';
    }
    if (launchOverflow < 0) {
      return 'На ${-launchOverflow} ходов лучше цели!';
    }
    if (launchOverflow > 0) {
      return '+$launchOverflow ходов к цели. Попробуй пройти меньшим числом ходов.';
    }
    // stars == 2: cleared, within target, but mastery not passed.
    return 'Цель выполнена. Дожми мастерство до трёх звёзд!';
  }

  /// Extend when adding new [MasteryKind] variants. `launchOverflow` is
  /// pre-computed by [evaluate] and passed in so kinds like `underPar`
  /// (future) don't have to redo the arithmetic.
  static bool _evaluateMastery(
    MasteryKind kind,
    ActualPlayStats stats,
    int launchOverflow,
  ) {
    switch (kind) {
      case MasteryKind.noWastedShots:
        // For 1-HP boards with normal piggies this collapses to unusedAmmo=0:
        // every launched piggy emptied its ammo, spare piggies in the queue
        // (never launched) don't count. Future levels with armor/specials
        // may grow a separate wastedShots counter — this stays the umbrella.
        return stats.unusedAmmo == 0;
    }
  }

  static String _ru(PiggyColor c) {
    switch (c) {
      case PiggyColor.pink:
        return 'розовый';
      case PiggyColor.cyan:
        return 'голубой';
      case PiggyColor.yellow:
        return 'жёлтый';
      case PiggyColor.green:
        return 'зелёный';
      case PiggyColor.purple:
        return 'фиолетовый';
      case PiggyColor.orange:
        return 'оранжевый';
    }
  }
}

/// UI-friendly view of a single deviation bar. Colors interpreted by the
/// widget layer (kept out of this file to stay pure-Dart).
enum BarSeverity { green, yellow, red }

class DeviationBarModel {
  final String label;

  /// 1.0 = perfect (full green), 0.0 = worst (empty red). Widget draws
  /// `fillRatio` fraction of the bar in `severity` color.
  final double fillRatio;

  final BarSeverity severity;
  final String hint;

  const DeviationBarModel({
    required this.label,
    required this.fillRatio,
    required this.severity,
    required this.hint,
  });

  static List<DeviationBarModel> fromResult(
    LevelResult r,
    LevelTargetConfig cfg,
  ) {
    final bars = <DeviationBarModel>[
      _bar(
        label: 'Запуски',
        deviation: r.deviation.launches,
        hint: r.launchOverflow == 0
            ? 'Точно в пар'
            : '+${r.launchOverflow} к пар\'у',
      ),
      _bar(
        label: 'Ammo',
        deviation: r.deviation.hits,
        hint: r.unusedAmmo == 0
            ? 'Всё ammo в дело'
            : 'Впустую: ${r.unusedAmmo}',
      ),
      _bar(
        label: 'Цвета',
        deviation: r.deviation.colors,
        hint: r.extraColors.isEmpty && r.missingColors.isEmpty
            ? 'Все нужные'
            : r.extraColors.isNotEmpty
                ? 'Лишний: ${r.extraColors.length}'
                : 'Не хватило: ${r.missingColors.length}',
      ),
      _bar(
        label: 'Комбо',
        deviation: r.deviation.combos,
        hint: r.deviation.combos == 0.0
            ? 'Ожидание закрыто'
            : 'Меньше цепочек, чем ждали',
      ),
    ];
    if (r.deviation.sequence != null) {
      bars.add(_bar(
        label: 'Порядок',
        deviation: r.deviation.sequence!,
        hint: r.deviation.sequence! < 0.1
            ? 'В порядке'
            : 'Порядок сбился',
      ));
    }
    return bars;
  }

  static DeviationBarModel _bar({
    required String label,
    required double deviation,
    required String hint,
  }) {
    final fill = (1 - deviation).clamp(0.0, 1.0);
    final sev = fill >= 0.85
        ? BarSeverity.green
        : fill >= 0.60
            ? BarSeverity.yellow
            : BarSeverity.red;
    return DeviationBarModel(
      label: label,
      fillRatio: fill,
      severity: sev,
      hint: hint,
    );
  }
}

/// Rank helpers for UI (labels, colors — colors as ARGB int to avoid
/// pulling Flutter in). Widget layer maps int → Color.
extension RankUi on Rank {
  String get label {
    switch (this) {
      case Rank.d:
        return 'D';
      case Rank.c:
        return 'C';
      case Rank.b:
        return 'B';
      case Rank.a:
        return 'A';
      case Rank.s:
        return 'S';
      case Rank.ss:
        return 'SS';
    }
  }

  /// ARGB. Widget-layer wraps with Color(...).
  int get argb {
    switch (this) {
      case Rank.d:
        return 0xFF888888;
      case Rank.c:
        return 0xFF6BA96B;
      case Rank.b:
        return 0xFF3B8FE0;
      case Rank.a:
        return 0xFFB76BFF;
      case Rank.s:
        return 0xFFFFD338;
      case Rank.ss:
        return 0xFFFF6BAA;
    }
  }

  /// Portal-medal mapping if a widget prefers medals over letters.
  String get medalEmoji {
    switch (this) {
      case Rank.d:
      case Rank.c:
        return '🥉';
      case Rank.b:
      case Rank.a:
        return '🥈';
      case Rank.s:
        return '🥇';
      case Rank.ss:
        return '💎';
    }
  }
}
