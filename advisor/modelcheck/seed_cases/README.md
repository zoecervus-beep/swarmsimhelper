# Rule SEED: reference cases

Fixtures for rule SEED, the always-on rule that replaces the long-run climb mode (`advisor/ASCENSION.md` A.10, pass 5). Each case is a simulator state exported as a save the real game loads, with:
- `rule_SEED`: the rule evaluated on the state as the climb starts, by the reference function `seed_test` in `advisor/modelcheck/seed_cases.py`;
- `simulator`: the simulator's own decisions on the same state, variant f = 1e-2 of `advisor/sim/lr_cut.py` (rule FA and the twin prefix on, no mode). These are the seed lines, the climb records and the twin-prefix hatches.

In every case the rule's hatch lines equal the simulator's seed lines.

## Generating them

```sh
python3 -I advisor/modelcheck/seed_cases.py      # about 30 s; node on PATH, `npm install` in advisor/modelcheck
```

## The cases

| Case | What it exercises |
| --- | --- |
| `run2_save` | the owner's run 2 at 45 h: frontier hive queen, seed 1.04e5 empresses (1% of what the hive queens afford) |
| `run2b_save` | the owner's run 2 at 3.0 d (4.4e18 empresses, 1 neuroprophet): frontier empress, seed 3.4e8 neuroprophets |
| `mirrors20_day0.5` | first run, 12 h after the 20.1 h save: nothing to seed (no tier above the frontier with any of the tier below held) |
| `mirrors20_day2`, `_day3.5` | first run, days 2 and 3.5: seed lines of 1.5e5 empresses and of 1 neuroprophet |
| `mirrors20_day6` | the long run, day 2 |
| `mirrors20_day20`, `_day45` | the long run, days 16 and 41: two seed lines each, up to galactic cluster / universal cortex |
| `warp_day2`, `_day10`, `_day30` | the swarmwarp route (game-clock horizon): day 30 seeds overmind and ascended |
| `cooldown` | `run2_save` with the seeded tier hatched 30 s ago (game clock): no line for it |
| `few_larvae` | `run2_save` with 10 larvae: 1% of the larvae is under one hatch, so no line |

## Fields of `rule_SEED`

| Field | Meaning |
| --- | --- |
| `run_age_s`, `horizon_s` | game-clock run age and 5 × it |
| `frontier` | the highest owned tier that passes the plain test (H ≤ horizon, the advisor's H); drones always pass |
| `larvae_for_climb` | A = larvae less the territory purse, the nexus hold and the clone reserve (the port uses its own A: the territory share and the nexus hold) |
| `lines[]` | from endless down to frontier + 1; see below |
| `larvae_left_for_climb` | A less the seeded hatches: what the climb then works with |

Each entry of `lines[]` has:
- `tier`, `name`, `H_s`, and `below_held` at that moment (earlier lines have already taken their units);
- `outcome`: `nothing below`, `cooldown` (hatched < 60 s ago on the game clock; `since_s`), `no larvae`, `under one` or `hatch`;
- for `under one` and `hatch`: `n` = floor of the smallest of the four `caps`, and `binding`, the cap that gave it. The caps are:
  - 1% × below / cost;
  - 1% × A;
  - half the meat / meat cost;
  - larvae left.

## What must match

| Field | Compare |
| --- | --- |
| `frontier` | **exact**: the plain test on the loaded save, with the advisor's H |
| `lines[].outcome` = `nothing below` / `cooldown` | **exact** (`cooldown` given the purchase memory: seed it from the case) |
| `lines[].n`, `binding` | **exact given A**: with `larvae_for_climb` given, floors equal (1e-12 relative past 2^53) |
| `larvae_left_for_climb` | **exact given A** |
| `simulator.climb[]` | as in `longrun_cases/README.md` (rule-3 sizing; the meat cap differs) |

## What the export cannot carry

The same as for the long-run cases (`longrun_cases/README.md`).
