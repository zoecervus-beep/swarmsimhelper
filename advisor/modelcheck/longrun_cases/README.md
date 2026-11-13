# Long-run mode reference cases

**Pass 4.** Regenerated with the corrected rules (ASCENSION.md A.10): honest larva arithmetic, a **1% push reserve**, the advisor's own **rule-3 sizing** for the climbing tiers, and **no faster-level rule (LR-1)**. The pass-3 cases (28) ran the push on a float rounding remainder in three of them, and their LR-1 fields are gone.

Fixtures for checking the native advisor's long-run mode (`advisor/ASCENSION.md` A.10) against the simulator's rule functions. Each case is a simulator state exported as a save the real game loads, plus the simulator's decisions at that instant.

## Generating them

```sh
python3 -I advisor/modelcheck/longrun_cases.py      # about 40 s; needs node on PATH and `npm install` in advisor/modelcheck
```

- **The long run.** The generator plays the long run from the first ascension under the specified rules (`longrun_rules.SPEC4` plus the 60 s push cooldown). The start state is cached by `advisor/sim/longrun_rules.py` in `advisor/modelcheck/out/lr_start.pkl`; it is the 20.1 h save run on to the earliest ascension, with the lepidoptera and frequency mutations. The rules are `longrun_rules.SPEC` plus the spec's 60 s push cooldown, and there is one visit every 5 minutes.
- **Survey.** It records the first visit at which each situation below occurs.
- **Capture.** It replays the run and, at those visits, captures the state **as the climb starts**: after the visit's energy, upgrade, twin and territory purchases.
- **Edited and no-change cases.** It adds edited cases (twin guard either side of the line, push cooldown, meat binding) and two states where the mode must change nothing.
- **Round trip.** It loads every exported save in the real game (`longrun_roundtrip.js`) and compares what the rules read: `roundtrip.md`.

Everything is deterministic: rerunning gives the same files.

## Files

- `<case>.save.json`: a decoded save; load it with `advisor/modelcheck/lib/game.js` `loadSave(file)`. Counts beyond a double are 17-significant-digit decimal strings. See `advisor/sim/export.py` for what is written and how.
- `<case>.json`: the case (fields below).
- `index.json`: the case list and the generation time.
- `roundtrip.md`: game against simulator for every case.

## Round trip

30 cases, 165 numbers each. Compared for each of the 20 meat tiers:
- count, cost in the tier below and in meat;
- units per hatch, production per unit;
- faster and twin prices, units bought.

Also compared: larvae, larvae/s, meat, energy, energy/s, lepidoptera, territory, run age and achievement points.

**Worst |sim/game − 1| = 1.6e-6.** That is lesser hive mind's meat price: the simulator uses 810 × 90^10, the game's table the rounded 2.8243e22, a difference already in MODEL-CHECK.md. Run age and achievement points are equal in every case.

## The cases

"Frontier" is shown before / after the visit's climb purchases. Several situations first occur on the same visit (run age 2.00 d); those cases share a state.

| Case | Run age (d) | Gate | Frontier | Lepidoptera target | What it exercises |
| --- | --- | --- | --- | --- | --- |
| `gate_before` | 1.95 | off | – / – | 4,000 | run age just under 2 days: the mode must change nothing (no reserve, no push lines, no guard) |
| `push_binds_share` | 2.00 | on | 5 / 5 | 4,000 | push lines limited by the share of the tier below (larvae and meat plentiful) |
| `push_fed_by_reserve_only` | 2.00 | on | 5 / 5 | 4,000 | the climb takes every larva it is offered: push lines run on the 1% reserve alone |
| `twin_guard` | 2.00 | on | 5 / 5 | 4,000 | a twin paid in a pushed tier, suppressed by the 1e6x guard |
| `gate_after` | 2.00 | on | 5 / 5 | 4,000 | run age just over 2 days: the mode acts |
| `push_fed_by_reserve_and_leftover` | 2.01 | on | 6 / 6 | 4,000 | push lines run on the reserve plus larvae the climb left (its own caps bound) |
| `push_under_one` | 2.01 | on | 6 / 6 | 4,000 | a push line that rounds down to zero (below one hatch) |
| `bank_with_mode` | 2.05 | on | 6 / 6 | 4,000 | a tier skipped by banking (rule 4) with the mode on |
| `frontier_empress` | 2.24 | on | 7 / 7 | 4,000 | frontier at hive empress (tier 7) |
| `moth_before` | 2.95 | on | 7 / 7 | 4,000 | run age just under 3 days: lepidoptera target 4,000 |
| `moth_after` | 3.00 | on | 7 / 7 | 30,000 | run age just over 3 days: lepidoptera target 30,000 |
| `day_5` | 5.00 | on | 7 / 7 | 30,000 | the long run on day 5 (a typical state) |
| `frontier_pantheon` | 9.72 | on | 10 / 10 | 30,000 | frontier in the neural cluster tiers (10-12) |
| `day_10` | 10.00 | on | 10 / 10 | 30,000 | the long run on day 10 (a typical state) |
| `day_20` | 20.00 | on | 13 / 13 | 30,000 | the long run on day 20 (a typical state) |
| `frontier_overmind` | 26.93 | on | 15 / 15 | 30,000 | frontier at overmind / ascended / cosmic network (15-17) |
| `day_30` | 30.00 | on | 15 / 15 | 30,000 | the long run on day 30 (a typical state) |
| `cortex_owned_no_endless` | 39.24 | on | 16 / 16 | 30,000 | the visit that makes the first universal cortex (push lines on cortex, galactic cluster, cosmic network); endless still empty |
| `day_40` | 40.00 | on | 16 / 16 | 30,000 | the long run on day 40 (a typical state) |
| `endless_owned` | 49.57 | on | 17 / 17 | 30,000 | endless already owned |
| `day_52` | 52.00 | on | 17 / 17 | 30,000 | the long run on day 52 (a typical state) |
| `twin_guard_just_above` | 20.00 | on | 13 / 13 | 30,000 | pay tier overmind held at 1.000001 x 1e6 x the twin price of pantheon5: the guard allows it |
| `twin_guard_just_below` | 20.00 | on | 13 / 13 | 30,000 | pay tier overmind held at 0.999999 x 1e6 x the twin price of pantheon5: the guard suppresses it |
| `push_cooldown` | 2.00 | on | 5 / 5 | 4,000 | hivequeen hatched 30 s ago: inside the 60 s push cooldown, no push line for it (others unchanged) |
| `push_binds_meat` | 2.00 | on | 5 / 5 | 4,000 | meat set to 2 x (what share and larvae allow) x the meat price of hivequeen, so the push line hatches but half the meat binds |
| `climb_cooldown_earmark` | 2.00 | on | 5 / 5 | 4,000 | hive hatched 30 s ago: inside its climb cooldown, larvae earmarked for it (rule 3); the 1% reserve is still taken first |
| `reserve_one_larva` | 2.00 | on | 5 / 5 | 4,000 | larvae offered to the climb and push = 100: the 1% reserve floors to 1 |
| `reserve_zero_larvae` | 2.00 | on | 5 / 5 | 4,000 | larvae offered to the climb and push = 99: the 1% reserve floors to 0 |
| `save_20h` | 0.84 | off | – / – | 4,000 | the owner's 20.1 h save (run age 0.84 d): the mode must change nothing |
| `fresh_run_12h` | 0.50 | off | – / – | 4,000 | a fresh run (no mutagen) at run age 12 h: the mode must change nothing |

## Fields of `<case>.json`

**`config`** is the advisor settings and mode constants the case was made with:

| Field | Meaning |
| --- | --- |
| `age_multiple` | 5 |
| `territory_share` | 0.1 |
| `bank` | 3 |
| `share` | the tuned policy's per-visit share, 0.5 |
| `gate_run_age_s` | 172,800 |
| `push_share` | 0.5 |
| `push_frontier_share` | 0.02 |
| `push_twin_guard_multiple` | 1e6 |
| `push_cooldown_s` | 60 |
| `moth_target` | 4,000 |
| `moth_target_late` | [259,200 s, 30,000] |
| `meat_share_for_push` | 0.5 |
| `push_reserve_share` | 0.01: R = floor(0.01 × larvae the climb could use) |
| `climb_sizing` | rule 3 |
| `cooldown_s` | 60 |
| `faster_level_rule` | false: LR-1 is dropped |

**`state`** holds quantities computed directly on the captured state, which is the exported save:

| Field | Meaning |
| --- | --- |
| `run_age_s`, `horizon_s` | run age and age multiple × run age |
| `gate_active` | run age ≥ 2 days |
| `frontier` | the highest owned tier that passes the **plain** climb test (H ≤ horizon), at least `push.from − 1` = 1; `null` while the gate is off |
| `top_owned` | the highest tier with a count above 0 |
| `moth_target` | the lepidoptera target in force |
| `larvae`, `larva_rate`, `meat`, `achievement_points` | as the state holds them |
| `larvae_held_back` | larvae the simulator holds out of climbing and pushing: territory purse, saving for the next nexus, clone reserve |
| `tiers[]` | one entry per meat tier 1–20; fields below |

Fields of each `tiers[]` entry:

| Field | Meaning |
| --- | --- |
| `count`, `prod_level`, `twin_level` | as held |
| `H_s` | cost / 2^(prod + twin) in seconds; the simulator's H, see the differences below |
| `passes_plain` | H ≤ horizon |
| `since_last_hatch_s` | seconds since the simulator last hatched this tier; `null` = never in this run |
| `stock_below_at_last_look` | rule 3's memory: the tier below's stock as measured at the first look after this tier's last hatch; `null` = not measured yet, so the next look measures it |
| `twin_guard` | for the twin of this tier: `pay_tier`, `price`, `pay_held`; `pushed_pay_tier` = the pay tier is above `frontier`; `suppressed` = pushed pay tier and pay_held < 1e6 × price |

**`decisions`** are from the simulator's own climb and push code run on the state, the end of `sim.policy`, via `sim._climb_and_push`:

| Field | Meaning |
| --- | --- |
| `larvae_before_climb` | the larvae the climb could use, A: larvae − territory purse − nexus saving − clone reserve |
| `push_reserve` | R = floor(0.01 × A), set aside for the push before the climb; `null` while the gate is off |
| `larvae_for_climb` | A − R |
| `climb_left` | what the climb left of A − R. Honest arithmetic: 0 when it took everything. |
| `climb[]` | each tier the climb looked at, top down (up to one above `top_owned`). `outcome`: `fails` (plain test), `bank` (rule 4), `cooldown` (rule 3: hatched < 60 s ago; `earmarked` larvae held for it), `passes_none` (passes but would buy 0), `buys`. `n_sim` = the simulator's purchase count under rule 3. |
| `frontier_at_push` | the frontier after the climb purchases, which is what the push used |
| `larvae_for_push` | what the push starts with: R + `climb_left` |
| `push[]` | from endless down to `frontier_at_push` + 1; fields below |

`outcome` of each `push[]` line:

| Outcome | Meaning |
| --- | --- |
| `nothing below` | none of the tier below held |
| `no larvae` | fewer than 1 larva left |
| `cooldown` | hatched less than 60 s ago |
| `under one` | the formula gives 0 |
| `hatch` | a push line |

For `under one` and `hatch` the line also gives:
- `n` = floor(min(share × below_held / cost_below, larvae_left, meat / 2 / meat_cost));
- `share` (0.5, or 0.02 on frontier + 1);
- `below_held`, `larvae_left`, `meat` (the inputs, as they were at that moment);
- `binding`: `share`, `larvae` or `meat`, whichever term is smallest.

Push lines are worked out top down. Each hatch takes its larvae, meat and units before the next line.

## Comparing the port with these cases: what must match

Pass 4 simulates the advisor's own rule 3 for the climbing tiers, so the climb counts are now comparable given the purchase memory (seeded from each case). What still legitimately differs:
- **Meat cap.** The simulator caps a purchase at half the meat; the advisor does not.
- **Territory larvae.** The simulator holds its territory larvae as a purse; the advisor holds back the territory share.
- **Drones.** The simulator hatches drones by its own rule; the advisor never suggests drones.
- **Arithmetic.** Float against Decimal.

Per field:

| Field | Compare | How |
| --- | --- | --- |
| `state.gate_active`, `state.moth_target` | **exact** | from run age only |
| `state.frontier` | **exact** | plain H test on the loaded save. H must be the same quantity; see the differences below. |
| `state.tiers[].passes_plain` | **exact** | with `H_s` within 1e-12 relative (Decimal vs float) |
| `state.tiers[].twin_guard.suppressed` | **exact** | the `twin_guard_just_*` cases sit 1e-6 either side of the line, far above float error. This decides whether the port's rule-6 twin tip may show; whether rule 6 would show it at all is the existing rule, not tested here. |
| `climb[].outcome` = `fails` / `bank` | **exact** | rule 1 and rule 4 on the loaded state (rule 4 uses larvae/s and the territory share, as now) |
| `decisions.push_reserve`, `larvae_for_climb` | **exact** | R = floor(0.01 × A), with A = larvae × (1 − territory share), floored, minus the larvae held for the next nexus. The simulator's A uses its territory purse rather than the territory share, so compare R given A. With the port's own A, A and R differ by the territory share's bookkeeping. |
| `climb[].outcome` = `cooldown`, `earmarked` | **exact given the memory** | seed the port's memory from `since_last_hatch_s` |
| `climb[].n_sim` | **exact given the memory, unless meat binds** | rule 3 is now simulated: seed the port's memory with boughtAt = now − `since_last_hatch_s` (never hatched: the run start − 60 s) and stockAt = `stock_below_at_last_look`, give it `larvae_for_climb`, and n must match (floor; 1e-12 relative above 2^53). The simulator also caps n at half the meat / meat price, which the advisor does not; where that cap binds, n differs. |
| `climb_left` | **exact given the climb's counts** | `larvae_for_climb` minus the hatched counts and earmarks; 0 when everything was taken |
| `decisions.frontier_at_push` | **exact if** the port evaluates the push after applying its climb suggestions, and its climb buys the same tiers | it differs from `state.frontier` only when a climb purchase makes a tier owned or buys faster levels |
| `push[].outcome` = `nothing below` | **exact** | |
| `push[].outcome` = `cooldown` | **exact given the memory** | the save cannot carry the advisor's purchase memory. Seed the port's memory from `state.tiers[].since_last_hatch_s`; `push_cooldown` needs hive queen hatched 30 s ago; `climb_cooldown_earmark` needs hive hatched 30 s ago. |
| `push[].outcome` = `no larvae` / `under one` / `hatch` and `n` | **exact given the inputs** | with `below_held`, `larvae_left` and `meat` from the line, the port's formula must give the same n (exact while n < 2^53, else 1e-12 relative) and the same `binding`. With its own inputs (its own larvae left after its own climb), n is not comparable. |
| `larvae_for_push` | **exact given the climb** | R + `climb_left` |

## Where the simulator and the advisor differ, and how to handle it

| Difference | What to do |
| --- | --- |
| **Sizing.** Both use rule 3 now, but the simulator's memory differs: it is seeded from the run start, and its territory larvae are a purse. | Seed the port's memory from the case. |
| **H.** The simulator's H is cost / 2^(prod + twin), which leaves out production multipliers other than faster levels. The advisor's H is tier × cost / (twin × prodEach), which includes the meat mutation (`mutantmeat`). | Equal in every case here: no case has meat mutants, and the round trip shows prodEach equal. A save with meat mutants would make them differ, and the advisor's is the right one. |
| **Purchase memory.** The advisor's cooldown and spare rely on its memory, which starts fresh on a loaded save. | Use `since_last_hatch_s`. |
| **Larvae held back.** The simulator's territory purse and nexus saving are policy memory. | The port has its own territory share. |
| **The visit.** The captured state is after the visit's energy, upgrade, twin and territory purchases. A port shown the saved state sees those purchases already made, which is what the cases intend. The simulator bought them by its tuned rules, not the advisor's tips. | None. |

## What the export cannot carry

- **Cocoons** are exported as 0; the simulator holds them as larvae.
- **Policy memory**: the climb's carry/earmark, the territory purse, the nexus saving, last-hatch times.
- **Per-unit `num` statistics** (exported equal to units bought), click counts, and achievement earn times (set to 1).
- **`date.started`.** Before any ascension it is set equal to `restarted`, because the game refuses a save from the future and the run must have started run-age seconds before the template's moment. So the premutagen seed differs from the owner's save. The climb rules do not read it.
- **The crystal timer and options** come from the template.
