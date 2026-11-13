# Long-run mode reference cases

Fixtures for checking the native advisor's long-run mode (`advisor/ASCENSION.md` A.10) against the simulator's rule functions. Each case is a simulator state exported as a save the real game loads, plus the simulator's decisions at that instant.

## Generating them

```sh
python3 -I advisor/modelcheck/longrun_cases.py      # about 40 s; needs node on PATH and `npm install` in advisor/modelcheck
```

- **The long run.** The generator plays the long run from the first ascension under the specified rules. The start state is cached by `advisor/sim/longrun_rules.py` in `advisor/modelcheck/out/lr_start.pkl`; it is the 20.1 h save run on to the earliest ascension, with the lepidoptera and frequency mutations. The rules are `longrun_rules.SPEC` plus the spec's 60 s push cooldown, and there is one visit every 5 minutes.
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

28 cases, 165 numbers each. Compared for each of the 20 meat tiers:
- count, cost in the tier below and in meat;
- units per hatch, production per unit;
- faster and twin prices, units bought.

Also compared: larvae, larvae/s, meat, energy, energy/s, lepidoptera, territory, run age and achievement points.

**Worst |sim/game − 1| = 1.6e-6.** That is lesser hive mind's meat price: the simulator uses 810 × 90^10, the game's table the rounded 2.8243e22, a difference already in MODEL-CHECK.md. Run age and achievement points are equal in every case.

## The cases

"Frontier" is shown before / after the visit's climb purchases. "FL" means a pass through the faster-level rule (LR-1); L = 0 means the tier fails both tests.

| Case | Run age (d) | Gate | Frontier | Lepidoptera target | What it exercises |
| --- | --- | --- | --- | --- | --- |
| `gate_before` | 1.95 | off | – | 4,000 | just under 2 days: the mode changes nothing (no FL, no push, no guard) |
| `gate_after` | 2.00 | on | 5 / 6 | 4,000 | first visit with the mode on; hive queen passes by FL with L = 1 |
| `twin_guard` | 2.00 | on | 5 / 6 | 4,000 | the guard suppressing twins paid in pushed tiers (same visit as `gate_after`) |
| `push_binds_share` | 2.01 | on | 6 / 6 | 4,000 | a push line on the frontier tier (2% share), limited by the share |
| `push_under_one` | 2.02 | on | 6 / 6 | 4,000 | a 50% push line that rounds to 0 (neuroprophet), and a 2% one that hatches (empress) |
| `fa_fails` | 2.05 | on | 6 / 6 | 4,000 | tiers failing the plain test and FL with a purchase of n > 0 |
| `fa_L1` | 2.90 | on | 6 / 7 | 4,000 | empress passes by FL with L = 1 |
| `frontier_empress` | 2.90 | on | 6 / 7 | 4,000 | frontier at hive empress at push time |
| `moth_before` | 2.95 | on | 7 / 7 | 4,000 | lepidoptera target before day 3 |
| `moth_after` | 3.00 | on | 7 / 7 | 30,000 | lepidoptera target from day 3 |
| `day_5` | 5.00 | on | 7 / 7 | 30,000 | typical state |
| `fa_Lmulti` | 6.69 | on | 7 / 8 | 30,000 | neuroprophet passes by FL with L = 3 |
| `push_binds_larvae` | 8.01 | on | 8 / 8 | 30,000 | three push lines: one under one, one limited by share (50%), one by larvae left (2%) |
| `day_10` | 10.00 | on | 8 / 8 | 30,000 | typical: the climb takes all larvae, every push line has none left |
| `frontier_pantheon` | 12.74 | on | 9 / 10 | 30,000 | frontier at neural cluster at push time; neural cluster by FL with L = 2 |
| `day_20` | 20.00 | on | 12 / 12 | 30,000 | typical, frontier at lesser hive mind |
| `day_30` | 30.00 | on | 14 / 14 | 30,000 | typical, frontier at arch-mind |
| `frontier_overmind` | 31.20 | on | 14 / 15 | 30,000 | frontier at overmind; overmind by FL with L = 5; push lines on ascended |
| `day_40` | 40.00 | on | 15 / 15 | 30,000 | typical, frontier at overmind |
| `cortex_owned_no_endless` | 45.55 | on | 16 / 16 | 30,000 | the visit that makes the first universal cortex (push hatches 4 from galactic clusters); endless still empty, so the endless line is `nothing below` |
| `day_52` | 52.00 | on | 17 / 17 | 30,000 | typical state on day 52, just before the first endless |
| `endless_owned` | 52.52 | on | 17 / 17 | 30,000 | endless owned; push lines on endless, universal cortex (share) and galactic cluster (larvae) |
| `twin_guard_just_above` | 20.00 | on | 12 / 12 | 30,000 | arch-mind held at 1.000001 × 1e6 × hive mind's twin price: that twin is **allowed** |
| `twin_guard_just_below` | 20.00 | on | 12 / 12 | 30,000 | arch-mind held at 0.999999 × 1e6 × that price: **suppressed** |
| `push_cooldown` | 2.01 | on | 6 / 6 | 4,000 | `push_binds_share` with empress hatched 30 s ago: no push line for it (`outcome: cooldown`) |
| `push_binds_meat` | 2.01 | on | 6 / 6 | 4,000 | `push_binds_share` with meat cut so the empress push line hatches 3, limited by half the meat |
| `save_20h` | 0.84 | off | – | 4,000 | the owner's 20.1 h save: the mode changes nothing |
| `fresh_run_12h` | 0.50 | off | – | 4,000 | a fresh run (after an ascension, no mutagen) at 12 h: the mode changes nothing |

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
| `twin_guard` | for the twin of this tier: `pay_tier`, `price`, `pay_held`; `pushed_pay_tier` = the pay tier is above `frontier`; `suppressed` = pushed pay tier and pay_held < 1e6 × price |
| `faster_levels_pass_if_got_at_least` | for tiers failing the plain test (gate on). For L = 1..8: `faster_price_total` (the next L levels' price in units of this tier) and `got_min`, the smallest "units held after the purchase" for which L levels pass, from H × (N + F_L)/(N × 2^L) ≤ horizon with N = got − F_L. `null` = L levels cannot pass at any size. The smallest L whose `got_min` ≤ got is the L LR-1 uses. |

**`decisions`** are from the simulator's own climb and push code run on the state, the end of `sim.policy`, via `sim._climb_and_push`:

| Field | Meaning |
| --- | --- |
| `larvae_before_climb` | larvae available to the climb: larvae − territory purse − reserves |
| `climb[]` | each tier the climb looked at, top down (up to one above `top_owned`). `outcome`: `fails` (plain test and no FL considered), `bank` (rule 4), `fa_fails` (failed the plain test and FL with the purchase it would make), `passes_none` (passes but would buy 0), `buys`. `test`: `plain` / `faster-level`. `faster_level_L` (0 = fails). `n_sim` = the simulator's purchase count. |
| `faster_after_climb[]` | faster levels bought straight after an FL hatch, one at a time at 1× price, until the tier passes the plain test or the next level is unaffordable |
| `frontier_at_push` | the frontier after the climb purchases, which is what the push used |
| `larvae_for_push` | larvae left after the climb, minus territory purse and reserves |
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

The simulator and the advisor legitimately differ in how they size ordinary purchases:
- the simulator uses its income-share and carry rule;
- the advisor uses rule 3: time-since-last-hatch share and spare, with a purchase memory, floors, a 60 s cooldown and Decimal arithmetic.

So the climb purchase count, and everything downstream of it, cannot be compared directly. Per field:

| Field | Compare | How |
| --- | --- | --- |
| `state.gate_active`, `state.moth_target` | **exact** | from run age only |
| `state.frontier` | **exact** | plain H test on the loaded save. H must be the same quantity; see the differences below. |
| `state.tiers[].passes_plain` | **exact** | with `H_s` within 1e-12 relative (Decimal vs float) |
| `state.tiers[].twin_guard.suppressed` | **exact** | the `twin_guard_just_*` cases sit 1e-6 either side of the line, far above float error. This decides whether the port's rule-6 twin tip may show; whether rule 6 would show it at all is the existing rule, not tested here. |
| `climb[].outcome` = `fails` / `bank` | **exact** | rule 1 and rule 4 on the loaded state (rule 4 uses larvae/s and the territory share, as now) |
| `climb[].faster_level_L` | **exact given the port's own purchase count** | compute got = count + n_port × twin, and L = the smallest L with `got_min` ≤ got (boundary tolerance 1e-9 relative). With the simulator's n (`n_sim`), L equals `faster_level_L`; with the port's n it may legitimately differ. |
| `climb[].n_sim`, `faster_after_climb[]` | **not comparable** | sizing. The port should check its own count against rule 3 as now. |
| `decisions.frontier_at_push` | **exact if** the port evaluates the push after applying its climb suggestions, and its climb buys the same tiers | it differs from `state.frontier` only when a climb purchase makes a tier owned or buys faster levels |
| `push[].outcome` = `nothing below` | **exact** | |
| `push[].outcome` = `cooldown` | **exact given the memory** | the save cannot carry the advisor's purchase memory. Seed the port's memory from `state.tiers[].since_last_hatch_s`; `push_cooldown` needs empress hatched 30 s ago. |
| `push[].outcome` = `no larvae` / `under one` / `hatch` and `n` | **exact given the inputs** | with `below_held`, `larvae_left` and `meat` from the line, the port's formula must give the same n (exact while n < 2^53, else 1e-12 relative) and the same `binding`. With its own inputs (its own larvae left after its own climb), n is not comparable. |
| Larvae left for the push | **not comparable** | depends on the climb sizing. The port computes it as larvae − what its climb lines take − territory share − nexus saving. |

## Where the simulator and the advisor differ, and how to handle it

| Difference | What to do |
| --- | --- |
| **Sizing.** As above. | Compare decisions given inputs, not counts. |
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
