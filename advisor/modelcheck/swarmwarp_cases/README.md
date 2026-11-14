# Swarmwarp route reference cases

Fixtures for checking the native advisor's swarmwarp route (`advisor/NO-MIRRORS.md`, sections 11-13) against the simulator. Each case is a simulator state exported as a save the real game loads, plus the route's rules evaluated on that state by the reference functions in `advisor/sim/warp_route.py`, plus the simulator's own decisions at that instant.

The rules are those of section 12 (`warp_route.CFG`):
- the ascension test: premutagen ≥ 1,000 × mutagen held;
- the final run from 1e270 held;
- the mutagen rule, with a free respec when the warp mutation is locked and unaffordable;
- 10,000 lepidoptera and 2,000 bats;
- the long-run climb mode on;
- every timer on the game clock, and one swarmwarp at a time.

## Generating them

```sh
python3 -I advisor/modelcheck/swarmwarp_cases.py      # about 3 minutes; needs node on PATH and `npm install` in advisor/modelcheck
```

1. **The route.** Plays the swarmwarp route from the 20.1 h save at one visit per 5 minutes.
   - At the first visit of each situation, by phase of the route, it keeps the state **as the visit starts**: after the time passed, before any purchase.
   - At every ascension it keeps the state just after the reset, before any mutagen is spent.
2. **The mirrors route.** Plays the mirrors route (the advisor today) to its first ascension and its long run, for the switch states.
3. **Edited states** either side of every boundary in the rules.
4. **Round trip.** Loads every save in the real game (`swarmwarp_roundtrip.js`) and compares what the rules read (`roundtrip.md`).

Deterministic: rerunning gives the same files.

## Phases and situations

Case names are `<phase>_<situation>`:

| Phase | Meaning |
| --- | --- |
| `first` | never ascended |
| `trough` | build stage, under 1e32 mutagen held |
| `late` | build stage, from 1e32 |
| `final` | final stage |

| Situation | Meaning |
| --- | --- |
| `nexus4` | the A.11 plan, unchanged |
| `moths` | lepidoptera under the target |
| `bats` | bats under 2,000 |
| `warp_test_fails` | the ascension test fails: swarmwarp |
| `warp_test_passes_spend` | test passes, cost above the save point: swarmwarp still |
| `save_for_ascension` | save |
| `ascend_now` | ascend |
| `warp` | final run |

Other cases:

| Case | What it covers |
| --- | --- |
| `asc_NN_lgMx` | just after ascension NN: the mutagen rule's branches (few unlocks, the 3rd free unlock, the 30% rule, all ten, shares only) |
| `ratio_just_above` / `ratio_just_below` | premutagen = 1,000 × held × (1 ± 1e-6) |
| `final_just_above` / `final_just_below` | held = 1e270 × (1 ± 1e-6) |
| `quick_stage`, `done_stage` | long-build achievements earned: ascend whenever the energy allows / never |
| `unlock_share_just_above` / `_below` | the 4th unlock (3.81e12) against 30% of the mutagen held |
| `cooldown_released_by_warp` | the top climbing tier hatched 30 s ago on the game clock: in cooldown without a warp (`climb_without_warp`), released by the first warp (`warp_sequence[0]`) |
| `five_warps_affordable` | energy for 5 warps: one at a time, purchases between them |
| `switch_mirrors_after_first_ascension_before_purchases` | the mirrors route's first ascension, nothing bought: the swarmwarp rule buys lepidoptera, warp (and bat if affordable) |
| `switch_mirrors_purchases_made` | lepidoptera + frequency unlocked by the mirrors route: free respec advised, then lepidoptera + warp |
| `switch_mirrors_purchases_no_free_respec` | the same with no free respec: no respec, warp waits |
| `switch_mirrors_long_day10`, `_day30` | a mirrors long run under the swarmwarp route: no guard, the test passes (ascend) |
| `no_mirrors_many_expansions` | a swarmwarp run with many expansions and no mirror cast |

## Fields of `<case>.json`

**`config`** holds the route's constants (section 12): ascension test, final threshold, unlock order and rules, mutant shares, lepidoptera, bats, territory share, clock choices, age multiple (5), long-run gate (2 days), cooldown (60 s), share per minute (0.5).

**`state`** holds quantities computed directly on the exported state:

| Field | Meaning |
| --- | --- |
| `clock.run_age_wall_s` | now − the run's start (`date.restarted`) |
| `clock.skipped_this_run_s` | seconds swarmwarp skipped in this run |
| `clock.skipped_total_s` | the game's `session.state.skippedMillis` / 1000: cumulative over the save, not reset at an ascension |
| `clock.run_age_game_s` | wall + skipped this run |
| `clock.run_age_game_estimate_s` | wall + swarmwarp casts this run × the current skip (900 × power), the stateless estimate the port can use |
| `clock.horizon_s` | 5 × game run age |
| `clock.long_run_gate_active` | game run age ≥ 2 days |
| `run_age_s` | the game run age, as the rules read it |
| `ascensions`, `nexus`, `energy`, `energy_rate`, `cap`, `moths`, `bats`, `nightbugs` | as held |
| `ascension_cost`, `energy_spent`, `halving`, `threshold`, `save_at` | the existing spend / save / ascend plan's inputs: halving = 50,000 × the lepidoptera mutation's factor, threshold = floor(halving / ln 2), save_at = min(cap, threshold) |
| `mutagen_held`, `premutagen`, `unlocks`, `unlock_count`, `next_unlock_price`, `mutants` | the mutagen tab |
| `swarmwarp_power`, `swarmwarp_skip_s` | spell power (bats × bat mutation × warp mutation) and 900 × power |
| `expansions`, `mirror_casts_this_run`, `swarmwarp_casts_this_run` | as held |
| `earned` | `expansion9`, `overmind6_3`, `mutation4` |
| `stage` | `build`, `final`, `quick` or `done` |
| `test` | the ascension test: `passes`, `premutagen`, `held`, `k`, `need` = k × max(held, 1) |
| `wants_ascension` | the route wants this run ended: quick, or build with the test passing |

**`decisions`**:

| Field | Meaning |
| --- | --- |
| `energy` | the simulator's energy step at this visit (`sim.energy_policy`, casting without purchases in between): `actions` (buyNexus, buyMoths, buyBats, cast swarmwarp × n), `saving_for_ascension`, `ascend_now`, `energy_after` |
| `warp_sequence` | (when a warp is affordable and the run is not saving) up to 5 warps, one at a time. Per warp: `skip_s`, `game_clock_before_s` / `_after_s`, `larvae_from_warp`. `tiers_before_climb`: for each tier with the tier below held, the game-clock time since its last hatch, whether the 60 s cooldown is released, the share released 1 − 0.5^(minutes since), and the stock release min(1, since / payback). Then what the purchases between this warp and the next bought: `bought` (expansions, hatcheries, ancestry, empowers, faster, twins, territory twins) and the `climb` and `push` records (format as in `longrun_cases/README.md`) |
| `climb_without_warp` | (`cooldown_released_by_warp` only) the climb on the same state with no warp |
| `territory` | the advisor's empower test with a fresh memory: cheapest and top rung by live meat cost, the empower price, the territory larvae (the share of the larvae on hand), the meat budget (0.9 × meat), the wiped share, `empower_advised`; `keeps_hatching_territory` is always true on this route |
| `mutagen` | `respec_first`, `respec_refund`, `free_respecs`, then `steps` (unlocks with price, mutants with count), `held_after`. `again` = the rule run on the result: always empty (idempotent); `respec_again` = false |

## Comparing the port with these cases: what must match

| Field | Compare | How |
| --- | --- | --- |
| `state.stage`, `test.passes`, `wants_ascension` | **exact** | from the save alone (premutagen, mutagen, achievements, ascension count) |
| `test.need` | **exact** (1e-12 relative) | k × max(held, 1) |
| `save_at`, `threshold`, `halving`, `ascension_cost` | **exact** | the existing plan; halving measured from the game's cost function as now |
| `mutagen.respec_first`, `mutagen.steps` | **exact** | the rule on the save's holdings; counts floored, 1e-12 relative past 2^53 |
| `mutagen.again` | **exact**: empty | apply the steps to the loaded game, run the rule again |
| `swarmwarp_power`, `swarmwarp_skip_s` | **exact** | the game's own effect power and output |
| `clock.run_age_game_estimate_s` | **exact** | wall run age + `swarmwarp` upgrade count × the current output |
| `clock.run_age_game_s`, `skipped_this_run_s` | **exact if** the port records `skippedMillis` at each ascension | else use the estimate; they agree whenever bats were bought before the first warp (the route's order), as in every case here |
| `clock.horizon_s`, `long_run_gate_active` | **exact given the run age used** | |
| `energy.actions` up to the first cast | **exact** | nexus, lepidoptera and bats as the existing energy line with the route's targets |
| `energy.actions` cast count | **not comparable** | the port suggests one warp at a time; the simulator's energy step alone casts all that is affordable. The comparable sequence is `warp_sequence` |
| `warp_sequence[i].tiers_before_climb` | **exact given the memory** | seed the port's purchase memory on the game clock from the case (hatched `since` game-seconds before) |
| `warp_sequence[i].climb[].n_sim`, `push[]` | **exact given the memory and inputs**, as in `longrun_cases/README.md` | the meat cap and territory purse differences listed there apply |
| `warp_sequence[i].bought.expansions`, `hatcheries`, `empowers` | **likely equal, not exact** | upgrades are bought by the simulator's rules (same prices; the advisor's tips may differ in order) |
| `territory.empower_advised` | **exact** | the advisor's empowerAdvice with a fresh memory |
| `energy.saving_for_ascension`, `ascend_now` | **exact** | the existing plan with the route's wants_ascension |

## Where the simulator and the advisor differ

- **The advisor's memory starts afresh on a loaded save.** Seed it from the case's game-clock times.
- **Run age on the game clock.** The simulator knows this run's skipped time exactly. The game keeps only the cumulative `skippedMillis`, so the port either records it at each ascension or uses the estimate.
- **The meat cap, the territory purse and drones**, as in the long-run cases.

## What the export cannot carry

Everything listed in `longrun_cases/README.md`, and the simulator's per-run skipped time (`skippedMillis` is exported as the save's cumulative total).
