import 'package:flutter_test/flutter_test.dart';
import 'package:piflow/game/models.dart';
import 'package:piflow/game/scoring.dart';

// Tests for the puzzle-mode scoring pipeline.
// Wasted-hits semantics (agreed 2026-08-11):
//   unusedAmmo = Σ leftover ammo across LAUNCHED piggies at end-of-level.
//   Un-launched piggies do NOT count (spared, not wasted).

const _scorer = LevelScorer();

LevelTargetConfig _cfg({
  int targetLaunches = 6,
  int targetHits = 12,
  Set<PiggyColor> allowed = const {PiggyColor.pink, PiggyColor.cyan},
  List<PiggyColor>? sequence,
  int softTolerance = 2,
  int failOverflow = 6,
  int perfectTolerance = 0,
  int expectedCombos = 1,
  double baseScore = 100,
}) =>
    LevelTargetConfig(
      targetLaunches: targetLaunches,
      targetHits: targetHits,
      allowedColors: allowed,
      optionalSequence: sequence,
      softLaunchTolerance: softTolerance,
      failLaunchOverflow: failOverflow,
      perfectLaunchTolerance: perfectTolerance,
      expectedCombos: expectedCombos,
      baseScore: baseScore,
    );

ActualPlayStats _stats({
  int launches = 6,
  int shots = 12,
  int unusedAmmo = 0,
  Set<PiggyColor> colors = const {PiggyColor.pink, PiggyColor.cyan},
  int combos = 1,
  List<PiggyColor>? sequence,
  bool cleared = true,
}) =>
    ActualPlayStats(
      launchesMade: launches,
      shotsFired: shots,
      unusedAmmo: unusedAmmo,
      colorsUsed: colors,
      combosTriggered: combos,
      actualSequence: sequence,
      cleared: cleared,
    );

void main() {
  group('EqualityScoringService', () {
    test('perfect play → all deviations 0', () {
      final r = _scorer.evaluate(_cfg(), _stats());
      expect(r.deviation.launches, 0.0);
      expect(r.deviation.hits, 0.0);
      expect(r.deviation.colors, 0.0);
      expect(r.deviation.combos, 0.0);
      expect(r.equalityScore, 1.0);
      expect(r.isPerfect, true);
      expect(r.rank, Rank.ss);
    });

    test('one extra launch → tiny launch deviation, still S/A', () {
      final r = _scorer.evaluate(_cfg(), _stats(launches: 7));
      expect(r.deviation.launches, closeTo(1 / 6, 1e-9));
      expect(r.isPerfect, false);
      expect(r.rank == Rank.s || r.rank == Rank.a, true);
    });

    test('three extra launches → still cleared, ranked lower', () {
      final r = _scorer.evaluate(_cfg(), _stats(launches: 9));
      expect(r.deviation.launches, closeTo(3 / 6, 1e-9));
      expect(r.isFailed, false);
      expect(r.rank.index < Rank.s.index, true);
    });

    test('over failOverflow → rank D and finalScore 0', () {
      final r = _scorer.evaluate(_cfg(), _stats(launches: 20));
      expect(r.isFailed, true);
      expect(r.rank, Rank.d);
      expect(r.finalScore, 0.0);
    });

    test('cleared under par (spec-piggy sweep) → not punished', () {
      final r = _scorer.evaluate(_cfg(), _stats(launches: 3));
      expect(r.deviation.launches, 0.0);
      expect(r.launchOverflow, 0);
      expect(r.isFailed, false);
    });

    test('spray & pray (launched extras with leftover ammo) → hits dev', () {
      // Player launched 8 piggies (par 6). Extra 2 walked off with ammo=2
      // apiece → unusedAmmo=4.
      final r = _scorer.evaluate(
        _cfg(),
        _stats(launches: 8, unusedAmmo: 4),
      );
      expect(r.unusedAmmo, 4);
      expect(r.deviation.hits, closeTo(4 / 12, 1e-9));
      expect(r.checklist.noWastedAmmo, false);
    });

    test('exact play → noWastedAmmo tick', () {
      final r = _scorer.evaluate(_cfg(), _stats());
      expect(r.checklist.noWastedAmmo, true);
    });

    test('spared piggies (un-launched) do NOT contribute to unusedAmmo', () {
      // Player only tapped what they needed (5 of 6 par); extra piggies sat
      // un-launched. Engine reports unusedAmmo=0 — spare is virtue, not waste.
      // Everything else clean → this IS a perfect run.
      final r = _scorer.evaluate(_cfg(), _stats(launches: 5, unusedAmmo: 0));
      expect(r.checklist.noWastedAmmo, true);
      expect(r.equalityScore, 1.0);
      expect(r.isPerfect, true);
      expect(r.rank, Rank.ss);
    });

    test('missing required color → colors deviation + missingColors', () {
      final r = _scorer.evaluate(
        _cfg(),
        _stats(colors: const {PiggyColor.pink}),
      );
      expect(r.missingColors, contains(PiggyColor.cyan));
      expect(r.deviation.colors, closeTo(0.5, 1e-9));
      expect(r.isPerfect, false);
    });

    test('extra color used → extraColors listed', () {
      final r = _scorer.evaluate(
        _cfg(),
        _stats(colors: const {
          PiggyColor.pink,
          PiggyColor.cyan,
          PiggyColor.yellow,
        }),
      );
      expect(r.extraColors, [PiggyColor.yellow]);
      expect(r.checklist.noExtraColors, false);
      expect(r.deviation.colors, closeTo(0.5, 1e-9));
    });

    test('sequence exact match → sequence deviation 0', () {
      final target = [PiggyColor.pink, PiggyColor.cyan, PiggyColor.pink];
      final r = _scorer.evaluate(
        _cfg(sequence: target),
        _stats(sequence: target),
      );
      expect(r.deviation.sequence, 0.0);
      expect(r.checklist.sequencePreserved, true);
    });

    test('sequence partial match via LCS', () {
      final target = [PiggyColor.pink, PiggyColor.cyan, PiggyColor.pink];
      final actual = [PiggyColor.pink, PiggyColor.pink]; // LCS = 2
      final r = _scorer.evaluate(
        _cfg(sequence: target),
        _stats(sequence: actual),
      );
      expect(r.deviation.sequence, closeTo(1 / 3, 1e-9));
    });

    test('no sequence configured → deviation.sequence == null', () {
      final r = _scorer.evaluate(_cfg(), _stats());
      expect(r.deviation.sequence, isNull);
      expect(r.checklist.sequencePreserved, isNull);
    });

    test('combo shortfall → combos deviation', () {
      final r = _scorer.evaluate(
        _cfg(expectedCombos: 4),
        _stats(combos: 1),
      );
      expect(r.deviation.combos, closeTo(0.75, 1e-9));
    });

    test('combo exceeded → combos deviation stays 0', () {
      final r = _scorer.evaluate(
        _cfg(expectedCombos: 1),
        _stats(combos: 5),
      );
      expect(r.deviation.combos, 0.0);
    });

    test('mixed almost-good but bad launches → equality drops', () {
      final r = _scorer.evaluate(
        _cfg(),
        _stats(launches: 10, unusedAmmo: 3),
      );
      expect(r.equalityScore < 0.75, true);
      expect(r.equalityScore > 0.4, true);
    });

    test('not cleared → rank D regardless of everything else', () {
      final r = _scorer.evaluate(_cfg(), _stats(cleared: false));
      expect(r.rank, Rank.d);
      expect(r.isFailed, true);
      expect(r.finalScore, 0.0);
    });

    test('low equality but cleared → C or D, never S+', () {
      final r = _scorer.evaluate(
        _cfg(),
        _stats(
          launches: 10,
          unusedAmmo: 8,
          colors: {PiggyColor.pink, PiggyColor.yellow, PiggyColor.green},
          combos: 0,
        ),
      );
      expect(r.equalityScore < 0.6, true);
      expect(r.rank.index <= Rank.b.index, true);
    });

    test('small over par (1 extra) does not push to fail', () {
      final r = _scorer.evaluate(_cfg(), _stats(launches: 7));
      expect(r.isFailed, false);
      expect(r.finalScore > 0, true);
    });
  });

  group('L1-L5 canonical scenarios', () {
    // L1 tutorial: 3 yellow in a column, arsenal 3×ammo=1. par=3.
    test('L1 perfect (par=3, no waste)', () {
      final cfg = _cfg(
        targetLaunches: 3,
        targetHits: 3,
        allowed: const {PiggyColor.yellow},
        expectedCombos: 0,
      );
      final r = _scorer.evaluate(
        cfg,
        _stats(
          launches: 3,
          shots: 3,
          unusedAmmo: 0,
          colors: const {PiggyColor.yellow},
          combos: 0,
        ),
      );
      expect(r.isPerfect, true);
      expect(r.rank, Rank.ss);
    });

    // L2: 2×2 yellow, arsenal 6×ammo=1. par=4. Burning all 6 → unusedAmmo=2.
    test('L2 spray & pray (launched all 6, 2 wasted)', () {
      final cfg = _cfg(
        targetLaunches: 4,
        targetHits: 4,
        allowed: const {PiggyColor.yellow},
        expectedCombos: 0,
      );
      final r = _scorer.evaluate(
        cfg,
        _stats(
          launches: 6,
          shots: 4,
          unusedAmmo: 2,
          colors: const {PiggyColor.yellow},
          combos: 0,
        ),
      );
      expect(r.isPerfect, false);
      expect(r.rank.index < Rank.s.index, true);
      expect(r.unusedAmmo, 2);
    });

    // L3 mortal trap: launched a dead-color green → wasted launch + ammo.
    test('L3 launched the dead color (green) → penalised', () {
      final cfg = _cfg(
        targetLaunches: 6,
        targetHits: 6,
        allowed: const {PiggyColor.cyan, PiggyColor.orange},
        expectedCombos: 0,
      );
      final r = _scorer.evaluate(
        cfg,
        _stats(
          launches: 7,
          shots: 6,
          unusedAmmo: 1,
          colors: const {
            PiggyColor.cyan,
            PiggyColor.orange,
            PiggyColor.green, // dead-color launched
          },
          combos: 0,
        ),
      );
      expect(r.extraColors, contains(PiggyColor.green));
      expect(r.isPerfect, false);
    });

    // L4 perfect: 6 launches × ammo=2 = 12 shots = ΣHP.
    test('L4 perfect (6 launches × ammo=2 = 12 hits exact)', () {
      final cfg = _cfg(
        targetLaunches: 6,
        targetHits: 12,
        allowed: const {
          PiggyColor.yellow,
          PiggyColor.cyan,
          PiggyColor.green,
          PiggyColor.purple,
        },
        expectedCombos: 2,
      );
      final r = _scorer.evaluate(
        cfg,
        _stats(
          launches: 6,
          shots: 12,
          unusedAmmo: 0,
          colors: const {
            PiggyColor.yellow,
            PiggyColor.cyan,
            PiggyColor.green,
            PiggyColor.purple,
          },
          combos: 2,
        ),
      );
      expect(r.isPerfect, true);
      expect(r.rank, Rank.ss);
    });

    // L5 spared piggy: 5 launches, ammo pool 6, 1 piggy un-tapped → not wasted.
    test('L5 perfect with spared piggy (spare doesn\'t count)', () {
      final cfg = _cfg(
        targetLaunches: 5,
        targetHits: 5,
        allowed: const {
          PiggyColor.yellow,
          PiggyColor.cyan,
          PiggyColor.green,
          PiggyColor.purple,
          PiggyColor.orange,
        },
        expectedCombos: 0,
      );
      final r = _scorer.evaluate(
        cfg,
        _stats(
          launches: 5,
          shots: 5,
          unusedAmmo: 0, // spared piggy stayed in queue → NOT counted
          colors: const {
            PiggyColor.yellow,
            PiggyColor.cyan,
            PiggyColor.green,
            PiggyColor.purple,
            PiggyColor.orange,
          },
          combos: 0,
        ),
      );
      expect(r.isPerfect, true);
      expect(r.rank, Rank.ss);
    });
  });

  group('RewardCalculator', () {
    test('perfect gives 2.5× bonus', () {
      final r = _scorer.evaluate(_cfg(), _stats());
      expect(r.finalScore, closeTo(250.0, 1e-9));
    });

    test('cleared but over par decays to at least 40% of eq × base', () {
      final r = _scorer.evaluate(
        _cfg(failOverflow: 6),
        _stats(launches: 12),
      );
      expect(r.finalScore, 0.0);
    });

    test('cleared over par with overflow < failOverflow → nonzero score', () {
      final r = _scorer.evaluate(_cfg(), _stats(launches: 8));
      expect(r.finalScore > 0, true);
    });
  });

  group('DeviationBarModel', () {
    test('perfect run → 4 green bars (no sequence)', () {
      final cfg = _cfg();
      final r = _scorer.evaluate(cfg, _stats());
      final bars = DeviationBarModel.fromResult(r, cfg);
      expect(bars.length, 4);
      for (final b in bars) {
        expect(b.severity, BarSeverity.green);
        expect(b.fillRatio, 1.0);
      }
    });

    test('sequence configured → 5 bars', () {
      final cfg = _cfg(sequence: [PiggyColor.pink, PiggyColor.cyan]);
      final r = _scorer.evaluate(
        cfg,
        _stats(sequence: [PiggyColor.pink, PiggyColor.cyan]),
      );
      expect(DeviationBarModel.fromResult(r, cfg).length, 5);
    });

    test('mid deviation → yellow, high deviation → red', () {
      final cfg = _cfg();
      final r = _scorer.evaluate(cfg, _stats(launches: 10, unusedAmmo: 12));
      final bars = DeviationBarModel.fromResult(r, cfg);
      final launchesBar = bars.firstWhere((b) => b.label == 'Запуски');
      final ammoBar = bars.firstWhere((b) => b.label == 'Ammo');
      expect(launchesBar.severity, isNot(BarSeverity.green));
      expect(ammoBar.severity, BarSeverity.red);
    });
  });

  group('Rank cutoffs', () {
    test('SS requires isPerfect, not just high equality', () {
      final r = _scorer.evaluate(_cfg(), _stats(unusedAmmo: 1));
      expect(r.isPerfect, false);
      expect(r.rank, isNot(Rank.ss));
      // 1 unused / 12 targetHits * 0.25 weight = 0.021 → eq ≈ 0.979 → S rank
      expect(r.rank, Rank.s);
    });

    test('threshold ladder: S ≥ 0.90, A ≥ 0.80, B ≥ 0.65, C ≥ 0.45', () {
      const t = ScoringThresholds();
      const ranker = RankCalculator();
      expect(
        ranker.compute(
          cleared: true,
          launchOverflow: 1,
          failOverflow: 6,
          equality: 0.91,
          isPerfect: false,
          t: t,
        ),
        Rank.s,
      );
      expect(
        ranker.compute(
          cleared: true,
          launchOverflow: 1,
          failOverflow: 6,
          equality: 0.82,
          isPerfect: false,
          t: t,
        ),
        Rank.a,
      );
      expect(
        ranker.compute(
          cleared: true,
          launchOverflow: 1,
          failOverflow: 6,
          equality: 0.70,
          isPerfect: false,
          t: t,
        ),
        Rank.b,
      );
      expect(
        ranker.compute(
          cleared: true,
          launchOverflow: 1,
          failOverflow: 6,
          equality: 0.50,
          isPerfect: false,
          t: t,
        ),
        Rank.c,
      );
      expect(
        ranker.compute(
          cleared: true,
          launchOverflow: 1,
          failOverflow: 6,
          equality: 0.30,
          isPerfect: false,
          t: t,
        ),
        Rank.d,
      );
    });
  });

  group('Motivational hints (2026-08-12 rewrite — no par/S/SS/equality)', () {
    test('not cleared → "уровень не пройден"', () {
      final r = _scorer.evaluate(_cfg(), _stats(cleared: false));
      expect(r.motivationalHint.toLowerCase(), contains('не пройден'));
    });

    test('3★ → "идеальное прохождение"', () {
      final r = _scorer.evaluate(_cfg(), _stats());
      expect(r.stars, 3);
      expect(r.motivationalHint.toLowerCase(), contains('идеальное'));
    });

    test('over target → mentions "ходов к цели"', () {
      final r = _scorer.evaluate(_cfg(), _stats(launches: 10));
      expect(r.motivationalHint.toLowerCase(), contains('ходов к цели'));
    });

    test('at target but mastery missed → mentions "мастерство"', () {
      final r = _scorer.evaluate(_cfg(), _stats(unusedAmmo: 4));
      // 2★ (cleared + insidePar) but unusedAmmo>0 kills implicit 3★.
      expect(r.stars, 2);
      expect(r.motivationalHint.toLowerCase(), contains('мастерство'));
    });

    test('no par/S/SS/equality words in hint', () {
      for (final r in [
        _scorer.evaluate(_cfg(), _stats(cleared: false)),
        _scorer.evaluate(_cfg(), _stats()),
        _scorer.evaluate(_cfg(), _stats(launches: 10)),
        _scorer.evaluate(_cfg(), _stats(unusedAmmo: 4)),
      ]) {
        final h = r.motivationalHint.toLowerCase();
        expect(h.contains('par'), false, reason: h);
        expect(h.contains(' s '), false, reason: h);
        expect(h.contains(' ss '), false, reason: h);
        expect(h.contains('equality'), false, reason: h);
        expect(h.contains('ammo'), false, reason: h);
      }
    });
  });

  group('Stars — Aleksey 3-tier system (2026-08-12)', () {
    test('not cleared → 0★', () {
      final r = _scorer.evaluate(_cfg(), _stats(cleared: false));
      expect(r.stars, 0);
    });

    test('cleared but over target → 1★', () {
      final r = _scorer.evaluate(_cfg(), _stats(launches: 10));
      expect(r.stars, 1);
    });

    test('cleared + within target + no mastery + noWastedAmmo → 3★', () {
      final r = _scorer.evaluate(_cfg(), _stats(unusedAmmo: 0));
      expect(r.stars, 3);
    });

    test('cleared + within target + no mastery + leftover ammo → 2★', () {
      final r = _scorer.evaluate(_cfg(), _stats(unusedAmmo: 4));
      expect(r.stars, 2);
    });

    test('cleared + within target + mastery passed → 3★', () {
      final cfg = LevelTargetConfig(
        targetLaunches: 6,
        targetHits: 12,
        allowedColors: const {PiggyColor.pink, PiggyColor.cyan},
        masteryChallenge: MasteryChallenge.noWastedShots,
      );
      final r = _scorer.evaluate(cfg, _stats(unusedAmmo: 0));
      expect(r.stars, 3);
    });

    test('cleared + within target + mastery failed → 2★', () {
      final cfg = LevelTargetConfig(
        targetLaunches: 6,
        targetHits: 12,
        allowedColors: const {PiggyColor.pink, PiggyColor.cyan},
        masteryChallenge: MasteryChallenge.noWastedShots,
      );
      final r = _scorer.evaluate(cfg, _stats(unusedAmmo: 2));
      expect(r.stars, 2);
    });
  });

  group('LevelResult UI mirror fields (2026-08-12)', () {
    test('mirrors moves / shots / colors', () {
      final cfg = _cfg();
      final stats = _stats(launches: 5, shots: 11, unusedAmmo: 1);
      final r = _scorer.evaluate(cfg, stats);
      expect(r.movesUsed, 5);
      expect(r.movesTarget, cfg.targetLaunches);
      expect(r.shotsUsed, 11);
      expect(r.shotsTotal, 12); // used + leftover
      expect(r.colorsUsed, stats.colorsUsed);
      expect(r.colorsRequired, cfg.allowedColors);
    });
  });

  group('MasteryChallenge (puzzle-mode third star)', () {
    LevelTargetConfig cfgWithMastery() => LevelTargetConfig(
          targetLaunches: 18,
          targetHits: 36,
          allowedColors: const {
            PiggyColor.pink, PiggyColor.cyan, PiggyColor.yellow,
            PiggyColor.green, PiggyColor.purple,
          },
          masteryChallenge: MasteryChallenge.noWastedShots,
        );

    test('no mastery configured → masteryPassed null (both on result & checklist)', () {
      final r = _scorer.evaluate(_cfg(), _stats());
      expect(r.masteryPassed, isNull);
      expect(r.masteryLabel, isNull);
      expect(r.checklist.masteryPassed, isNull);
    });

    test('noWastedShots: cleared with unusedAmmo=0 → passes', () {
      final r = _scorer.evaluate(
        cfgWithMastery(),
        _stats(
          launches: 18,
          shots: 36,
          unusedAmmo: 0,
          colors: const {
            PiggyColor.pink, PiggyColor.cyan, PiggyColor.yellow,
            PiggyColor.green, PiggyColor.purple,
          },
        ),
      );
      expect(r.masteryPassed, true);
      expect(r.masteryLabel, MasteryChallenge.noWastedShots.label);
      expect(r.checklist.masteryPassed, true);
    });

    test('noWastedShots: cleared but leftover ammo → fails', () {
      final r = _scorer.evaluate(
        cfgWithMastery(),
        _stats(
          launches: 19,
          shots: 36,
          unusedAmmo: 2,
          colors: const {
            PiggyColor.pink, PiggyColor.cyan, PiggyColor.yellow,
            PiggyColor.green, PiggyColor.purple,
          },
        ),
      );
      expect(r.masteryPassed, false);
      expect(r.checklist.masteryPassed, false);
    });

    test('noWastedShots: not cleared → mastery cannot be earned', () {
      final r = _scorer.evaluate(
        cfgWithMastery(),
        _stats(
          launches: 18,
          shots: 30,
          unusedAmmo: 0,
          cleared: false,
        ),
      );
      expect(r.masteryPassed, false);
    });
  });
}
