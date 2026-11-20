# Faster-aware climb test: reference cases

These are fixtures for rule FA in `advisor/MODEL-CHECK.md` ("Faster-aware climbing, pass 2"). Rule FA is what the climb test does with a tier that fails the plain test (H > age multiple × run age). Each case is a simulator state exported as a save the real game loads, together with:
- `rule_FA`: the rule evaluated on every failing tier, by the reference function `faster_test` in `advisor/modelcheck/faster_cases.py`;
- `simulator`: the simulator's own climb decisions on the same state, variant c2 of `advisor/sim/faster_study.py`.

## Generating them

```sh
python3 -I advisor/modelcheck/faster_cases.py      # about 20 s; node on PATH, `npm install` in advisor/modelcheck
```

The generator does four things:
1. **The owner's two saves as they stand.** Save (2) is `example_save_run2_45h.json`, run 2 of the mirrors route at 45.2 h. The 58 h first-run save is evaluated at age multiple 5 and at 3.
2. **The first starts by the rule** along three routes, playing variant c2 at one visit per 5 minutes:
   - the mirrors route's first run from the 20.1 h save;
   - run 2 from save (2);
   - the swarmwarp route.

   The state kept is the one the climb sees at that visit.
3. **Both sides of the line.** The tier below is set so that what the tier would hold after hatching all it can afford is 1 ± 1e-6 times what the test needs.
4. **Round trip.** Every save is loaded in the game (`longrun_roundtrip.js`) and compared with the simulator (`roundtrip.md`).

## Fields

**`state`**: the run age (s); horizon = age multiple × run age; the top tier owned; larvae; `larvae_for_climb` (larvae less the territory purse, the nexus saving and the clone reserve; the port uses its own A); meat.

**`plain_passes`**: the tiers that pass the plain test, so rule FA does not apply to them.

**`rule_FA[]`**: one entry per tier that fails the plain test.

| Field | Meaning |
| --- | --- |
| `H_s` | the advisor's H = tier × cost / (twin × prodEach), with every production multiplier (the meat mutation included). The simulator's own H leaves the meat mutation out; these cases use the advisor's form |
| `held`, `twin`, `faster_level` | as held |
| `below_held`, `cost_below`, `meat`, `meat_cost` | the price inputs |
| `n_affordable` | floor(min(larvae for the climb, below / cost, meat / meat cost)): all that can be bought now |
| `got` | held + n × twin |
| `levels[]` | for L = 1..12: `price_total` F_L = Σ 66 × 666^(level + i), i < L; `N_kept` = got − F_L; `H_eff_s` = H × (N + F_L) / (N × 2^L) (null when N < 1); `passes` = N ≥ 1 and H_eff ≤ horizon |
| `decision` | `start` (`hatch` = n, `faster_levels` = the smallest L that passes, `faster_price_total`), or `wait`. A wait carries `levels_needed` = ceil(log2(H / horizon)), `their_price`, `units_needed_after_hatch` = H × F / (2^L × horizon − H) + F, `hatch_needed` and `affordable` |

**`simulator`**: the climb records in the long-run cases' format (`longrun_cases/README.md`). A tier started by the test has outcome `buys` with `faster_level_L`; `faster_after_climb` lists the faster levels bought at 1× price right after.

## The cases

| Case | What it exercises |
| --- | --- |
| `run2_save` | save (2): empress H 67.1 d against a horizon of 9.4 d. It needs 3 faster levels (2.93e7 empresses, plus the units to keep), and only 1.04e7 are affordable: **wait**. The panel should say why (below) |
| `mirrors58_save` | the 58 h save at multiple 5: hive queens pass the plain test; empresses wait (4 levels needed) |
| `mirrors58_save_x3` | the same at multiple 3: hive queens fail the plain test, and rule FA starts them with 1 faster level (the owner's "66 hive queens + faster") |
| `mirrors20_asc0_*`, `mirrors20_asc1_hive`, `run2_asc1_*`, `warp_asc*_*` | the visit where the rule first starts each tier on a route: hives and hive queens (L = 1–2), empresses (L = 3, first run and run 2), neuroprophets, hive neurons and hive networks in run 2 (L = 1) |
| `line_just_above` / `line_just_below` | from `run2_asc1_pantheon2`: hive networks after hatching all they can afford = 1 ± 1e-6 × what 1 faster level needs: start / wait (the simulator agrees on both sides) |

## What must match

| Field | Compare |
| --- | --- |
| `plain_passes`, `rule_FA[].H_s` | **exact** (1e-12 relative): the advisor's own H and horizon |
| `rule_FA[].levels[]` | **exact given `n_affordable`**: give the port the same n |
| `rule_FA[].n_affordable` | **exact given the larvae for the climb**: the port's A differs by its territory share and nexus bookkeeping, as in the long-run cases |
| `rule_FA[].decision` | **exact given n** |
| `simulator.climb[].n_sim` | **not comparable**: the simulator caps the hatch at half the meat. The decision type and L are comparable |

## What the export cannot carry

The same as for the long-run cases (`longrun_cases/README.md`).
