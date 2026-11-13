# Checking the simulator against the game

Nov 12, 2026. Checks `advisor/sim/sim.py` against the game's own code on the owner's example save (`advisor/sim/example_save_14h.json`: 14.5 h into a run, top unit hive, 4 nexus, 2,416 lepidoptera).

## Conclusion

- **One real bug, now fixed. Larvae per second were 2.75× too low.** `sim.py` hard-coded 380 achievement points. The save has 690, and accomplished ancestry (level 5) multiplies larva production by (1 + 0.001 × points)^5. The game makes 94,610 larvae/s on this save; the old simulator said 34,348 (ratio 0.363). The handoff's "about 34,000 larvae a second" came from the simulator, not the game.
- **Everything else the simulator models matches the game to within 1 part in 100,000.** That covers meat and territory per second, energy rate and cap, every meat-chain and territory unit, every upgrade price it uses, 60 s to 24 h of idle time, a sequence of six purchases, and every spell with and without bats. That is about 280 quantities in all. Production between check-ins, the closed-form integration, is exact.
- **The handoff's assumptions about the game all hold, measured by running game code.** Accomplished ancestry multiplies larva production. House of Mirrors doubles every territory unit, has no cap and ignores bats. The lepidoptera, bat and nightbug formulas are right. All rush and warp spells scale with spell power. Clone larvae scales only its cap. Cocoons are larvae parked 1:1.
- **Smaller fixes.** The simulator now earns achievements during a run as the game does: unit achievements count units *bought*, plus expansions and nexus 5. This adds up to 290 points over 14 days, a further 1.6 to 6× in meat earned. It also has the right meat cost per hatch (was up to 2.9× low, but negligible against meat stocks), the right pantheon 2 and 3 unit costs (were 10× and 100× low, never reached), nightbugs in the energy cap, and cocoons counted as larvae.
- **The tuned settings mostly survive.** The fix raises total meat earned by 0.4 to 2.4 orders of magnitude from +4 h on (except −2.5 at +8 h, where a tier starts at a different moment), but the ranking of almost every setting is unchanged. Two things stand out:
  1. The native advisor's default `ageMultiple` is 3, but `policy.json` and the handoff use 5. In no run here did 5 score lower than 3, and it scored 10^1 to 10^6 higher at 2 to 4 days.
  2. **For runs of a week or more, the age-multiple rule stalls at hive queens.** With House of Mirrors, larvae stop being scarce. A multiple of 10 earns 10^15 to 10^16 more meat by 14 days and costs at most 10^1.6 at 1 to 2 days. A multiple of 20 earns 10^12 to 10^13 more already at 7 days, but costs up to 10^11 at 1 to 2 days. The unfixed simulator shows the same, so this is a gap in the original evidence, not an effect of the fix. The handoff only scored the age multiple over 1 to 48 hours.
- **No game fact the native advisor relies on is false.** See the end.

## How the comparison was done

The browser build was not available. Instead, `advisor/modelcheck/lib/game.js` loads the game's real CoffeeScript services into plain Node: the v0.2 spreadsheet the game ships, util, spreadsheetutil, spreadsheet, effect, unit, upgrade, achievement, tab, game, session (with its own lz-string save codec), options and seedrand. It wires them with a few-line stand-in for Angular's injector. Only Angular itself, logging, `$rootScope`, storage, `env` and mathjs's `factorial` are faked. The statistics service is not loaded.

A decoded save is re-encoded the way the game exports it, imported through `session.importSave`, and handed to a real `Game`. Time moves with `game.tick(new Date(now + ms))`, which is how the game's own specs advance time (`test/spec/services/unit.coffee`). Purchases and spells go through the real `unit.buy` and `upgrade.buy`.

`advisor/modelcheck/game_check.js` measures everything from the game and prints JSON. `advisor/modelcheck/compare.py` runs it, computes the same quantities with `sim.py` (its own functions, and the same purchase arithmetic its policy uses), and prints the tables. The game data in `tables/src/spreadsheet/original-data.json` has the same unit table as the `v0.2.js` preload the game actually loads.

### Reproduce

```sh
cd advisor/modelcheck && npm install && cd ../..      # coffee-script, decimal.js, lodash, lz-string, moment, seedrandom, jasmine (pinned to the game's versions)
python3 -I advisor/modelcheck/compare.py              # game vs sim tables, about 3 s; also written to advisor/modelcheck/out/compare.md
git show e34fc82:advisor/sim/sim.py > advisor/modelcheck/out/sim_original.py
python3 -I advisor/modelcheck/compare.py --sim advisor/modelcheck/out/sim_original.py   # the same against the unfixed sim
python3 -I advisor/modelcheck/sensitivity.py --states  # the sensitivity tables below, about 50 s
node advisor/modelcheck/run_specs.js test/spec/services/advisorfacts.coffee            # the pinned game facts
node advisor/modelcheck/script_vs_port.js 1 300 20      # console script vs native port, below; about 25 s
```

Speed: one 14-day simulator run with the tuned policy takes about 1 second.

## Game vs simulator on the example save

Measured. "Before" is the simulator as it was (commit `e34fc82`); "after" is the current one. Ratios are sim/game. The full tables (about 280 rows) come from `compare.py`.

| Quantity | Game | Sim before | Sim after |
| --- | --- | --- | --- |
| Larvae / s | 94,610 | 0.363 | 1.000000 |
| Achievement points | 690 | 380 (0.551) | 1.000000 |
| Meat / s | 2.779e28 | 1.000000 | 1.000000 |
| Territory / s | 9.173e19 | 1.000000 | 1.000000 |
| Energy / s (4 nexus, 2,416 lepidoptera) | 0.6829 | 1.000000 | 1.000000 |
| Energy cap | 40,000 | 1.000000 | 1.000000 |
| Each meat unit, drone to pantheon 3: count, production each, units per hatch | (see compare.md) | 1.000000 | 1.000000 |
| Cost in the tier below, drone to pantheon | 10^k | 1.000000 | 1.000000 |
| Cost in the tier below, pantheon 2 / pantheon 3 | 1e12 / 1e14 | 0.1 / 0.01 | 1.000000 |
| Meat per hatch, nest to pantheon 3 (810 × 90^(k−2)) | 7.29e4 … 2.82e22 | 0.9 … 0.349 | 1.000000 |
| Each territory unit: count, territory/s each, meat cost, units per hatch | (see compare.md) | 1.00000 | 1.00000 |
| Hatchery, expansion, accomplished ancestry (meat and territory) prices | 3e31, 1.52e23, 5e26 / 5e22 | 1.000000 | 1.000000 |
| Faster upgrades, drone to pantheon 3 (66 × 666^level) | | 1.000000 | 1.000000 |
| Twin upgrades, drone to pantheon 2 (10^level of the tier above) | | 1.000000 | 1.000000 |
| Territory twins (100 × 500^level meat, 50^level larvae) | | 1.000000 | 1.000000 |
| Nexus 2 to 5: meat, energy, larvae | | 1.000000 | 1.000000 |
| Idle +60 s / +1 h / +8 h / +24 h: meat, drone … hive, territory, energy | | 1.000000 | 1.000000 |
| Idle +60 s / +1 h / +8 h / +24 h: larvae | 3.34e6 … 8.18e9 | 0.599 … 0.363 | 1.000000 |
| Prices paid: 1000 greater queens (×64 twins), nest twin, greater queen faster, 10 goons, expansion, hatchery | | 1.0 except greater queen meat 0.81 | 1.000000 |
| State and rates right after those purchases, and 1 h later | | larvae 0.363 to 0.366, rest 1.000000 | 1.000000 |
| Spells, 0 and 1000 bats: mirrors, larva rush, meat rush, territory rush, swarmwarp, clone larvae (normal and capped) | | larvae gained 0.363, rest 1.000000 | 1.000000 |
| Achievements earned in a run (expansion 100, 10^6 hives bought) | 750 points | not modelled | 1.000000 |

Differences under 1 part in 100,000 are left out; they come from the game's table storing some large values rounded, for example goon production 2.3835e15 against 0.07 × 45^10.

Every "before" mismatch traces to two lines of `sim.py`. `ACH=380` gives every larva difference, including larvae from larva rush, swarmwarp and clone larvae. `MEATC` / `UNITC` give the cost differences.

## The handoff's assumptions, one by one

All verdicts below come from running the game code (`game_check.js` / `advisorfacts.coffee`), not only from reading it.

| Assumption | Verdict | Evidence (measured) |
| --- | --- | --- |
| Accomplished ancestry multiplies larva production by (1 + 0.001 × points)^level | **Confirmed**, but the simulator used the wrong points | Larvae/s at levels 0 / 1 / 5 with 690 points: 6,862.8 / 11,598 / 94,610 (×1.69 per level). The larvae actually gained in 60 s scale the same way. With no achievements earned, all three levels give 6,862.8. The effect is written on the `larva` unit's stat, but it is applied through the hatchery's upgrade list to the larva producer, as the handoff suspected. |
| House of Mirrors doubles every territory unit | **Confirmed** | All 11 territory units ×2.000000 per cast, with 0 bats and with 1000 bats. |
| …has no cap | **Confirmed** | A second cast doubles again (4×). The 1.18e6 devourers and 4.86e7 centipedes doubled exactly. `compoundUnit` with no `val2` has no cap. |
| …ignores spell power | **Confirmed** | Spell power 1.0 vs 1.3 (1000 bats): the doubling is identical. Larva rush cast the same way gains 1.3× more with the bats, so the bats were active. |
| Lepidoptera energy multiplier 1 + N/(1000 + N) | **Confirmed** | 4 nexus: 0.4 / 0.6 / 0.6829 / 0.72 / 0.7996 energy/s at 0 / 1000 / 2416 / 4000 / 10^6 lepidoptera. |
| Bat spell power 1 + 0.6 × N/(1000 + N) | **Confirmed** | 1 / 1.3 / 1.5994 at 0 / 1000 / 10^6 bats. |
| Nightbugs raise the energy cap toward 6× | **Confirmed** | 4 nexus: 40,000 / 140,000 / 239,800 at 0 / 1000 / 10^6 nightbugs. The cap is 10,000 × nexus × (1 + 5N/(1000 + N)). |
| Larva rush = 2400 s of larvae (+100,000), scales with spell power | **Confirmed** | +2.2716e8 larvae at power 1 (94,610 × 2400 + 1e5); +2.9531e8 at 1.3. |
| Swarmwarp skips 900 s, scales with spell power | **Confirmed** | Swarmwarp gives exactly what advancing 900 s gives (1170 s with 1000 bats) for every unit. Energy only drops by the 2,000 cost, so energy is not earned during the warp. The simulator does the same. |
| Meat rush, territory rush = 7200 s of production, scale with spell power | **Confirmed** | Meat +2.0009e32 / +2.6011e32 and territory +6.6046e23 / +8.5860e23 at power 1 / 1.3. The flat +1e11 meat and +1e9 territory are ignored by the sim and negligible. |
| Clone larvae doubles larvae plus cocoons, up to 100,000 s of larva income, scales with spell power | **Confirmed, with a nuance** | Spell power scales only the cap. Gain = min(larvae + cocoons, larvae/s × 100,000 × power). Measured: +3.34e6 (doubling) at both powers; 9.461e9 vs 1.230e10 when capped at power 1 vs 1.3; +3e6 for 1e6 larvae + 2e6 cocoons. The simulator's formula is the same. |
| Spell energy prices and nexus levels | **Confirmed** | Larva rush 1600 and swarmwarp 2000 (nexus 1), meat rush 1600 (nexus 2), territory rush 1600 (nexus 3), clone larvae 12,000 (nexus 4), House of Mirrors 2500 (nexus 5). These match `SPELL` in sim.py. |
| Cocoons: the sim treats them as larvae | **Was not actually done; now done, and it is right** | The old `load()` ignored the `cocoon` count. Measured: cocooning 400k and uncocooning 100k move larvae 1:1 both ways with no other cost. Cocoons produce nothing and count toward clone larvae. So holding them as larvae is exact for everything the sim does. The example save has 0 cocoons, so no result changed. The advisor reads only the `larva` count, so cocooned larvae are invisible to its hatch and nexus advice, which is reasonable: the nexus price is paid in larvae, not cocoons. |
| Twin upgrades do nothing for units already owned; faster upgrades boost them | **Confirmed** | After the nest twin and the greater queen faster upgrade, unit counts and rates match the sim, which assumes exactly this. |
| Unit caps and number formatting are ignored | **Not an issue on this path** | No meat, larva or territory unit has a cap. Energy's cap is modelled. The game's `UNIT_LIMIT` is 1e100000. The simulator's largest number by day 14 is about 1e154 (the expansion price), well inside float range. |

New, from the game code: **unit achievements count units bought, not units owned** (statistics `twinnum`). So House of Mirrors clones never earn the territory "1e15" achievements. Measured: 10^16 swarmlings owned but not bought did not earn `swarmling3`, while expansion 100 (40 points) and 10^6 hives bought (20 points) did. Larvae/s rose ×1.1906 = (1.75/1.69)^5.

## What changed in `sim.py`

- `ACH=380` → `ACH=None`. `load()` now computes the save's achievement points from the game's own table (`swarmsim-coffee/app/scripts/spreadsheetpreload/v0.2.js`), so `lam()` matches `game.achievementPoints()`. Setting `sim.ACH` to a number still overrides it, and also turns off earning.
- Achievements are earned during a run (`earn_achievements`, switch `sim.EARN_ACH`). Unit achievements use units bought (from the save's statistics plus the simulator's own hatches), and upgrade achievements use expansion and nexus 5. Event and ascension achievements are not modelled.
- `MEATC`: drone 10, then 810 × 90^(k−2), not 10 × 81^(k−1). `UNITC`: pantheon 2 and 3 cost 10^12 and 10^14, not 10^11 and 10^12. `H()` now uses `UNITC`, which is identical up to pantheon.
- Nightbugs enter `ecap()`; the policy still never buys any.
- Cocoons are added to larvae at load.
- Upgrade prices are now small functions (`anc_cost`, `exp_cost`, `hatch_cost`, `prod_cost`, `twin_cost`, `tt_cost`) used both by the policy and by the check. The formulas are unchanged.

The interface is unchanged. `run(policy, 0, check_in_seconds, marks_in_hours)` and the `SAVE` environment variable still work, and so does `run_example.py`.

Effect on the tuned run from the example save (log10 total meat earned):

| | +1 h | +4 h | +8 h | +24 h | +48 h | +96 h | +7 d | +14 d |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Before (380 points) | 32.41 | 33.89 | 39.31 | 47.12 | 50.11 | 64.81 | 73.50 | 91.31 |
| After, points from the save, no earning | 32.41 | 33.96 | 36.53 | 47.70 | 51.48 | 66.58 | 74.91 | 92.92 |
| After (also earning achievements) | 32.41 | 34.31 | 36.84 | 47.91 | 51.70 | 67.18 | 75.69 | 93.61 |

The fixed simulator earns *less* meat at +8 h despite 2.75× the larvae, because it starts hive queens at a different moment. The score at any single mark is sensitive to when a new tier starts. Read the sensitivity results below with that in mind.

## Do the tuned settings survive?

Each row changes one setting of `policy.json` and gives the difference from the tuned policy in log10 meat earned (+1.0 = 10× more meat earned). The handoff averaged 1 to 48 hours; that average is the last column. The example save is the only real start. "+12 h" and "+48 h" are later states of the tuned run itself, so they are not independent evidence. They show whether a conclusion depends on the moment.

| Variant | Start | +4 h | +8 h | +24 h | +48 h | +4 d | +7 d | +14 d | Mean 1–48 h |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Age multiple 1 | save | 0 | 0 | 0 | 0 | −10.3 | −11.5 | −0.05 | 0.00 |
| | +12 h | 0 | 0 | 0 | −6.1 | −10.6 | −11.7 | 0 | −1.02 |
| | +48 h | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0.00 |
| Age multiple 3 (native default) | save | 0 | 0 | 0 | 0 | −2.15 | −0.02 | 0 | 0.00 |
| | +12 h | 0 | 0 | 0 | −6.1 | −0.96 | −0.01 | 0 | −1.02 |
| | +48 h | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0.00 |
| Age multiple 10 | save | 0 | 0 | −0.24 | −1.56 | +0.13 | 0 | **+15.3** | −0.30 |
| | +12 h | −0.01 | −0.10 | −0.71 | +1.82 | +0.06 | 0 | **+15.6** | +0.17 |
| | +48 h | 0 | 0 | 0 | 0 | 0 | 0 | **+16.1** | 0.00 |
| Age multiple 20 | save | 0 | 0 | −8.5 | −11.2 | −0.36 | +11.8 | +15.3 | −3.29 |
| | +12 h | −0.05 | −0.24 | −1.03 | +1.82 | +0.06 | +12.5 | +15.7 | +0.08 |
| | +48 h | 0 | 0 | 0 | 0 | +9.1 | +13.2 | +16.1 | 0.00 |
| Share 0.25 / 0.75 | all three | single marks between −0.46 and +0.24 | | | | | | | −0.08 … +0.05 |
| Bank 1 | save | −0.24 | −0.33 | +0.02 | 0 | 0 | 0 | 0 | −0.09 |
| | +12 h / +48 h | 0 | 0 | 0 | −0.64 / 0 | 0 | 0 | 0 | −0.11 / 0.00 |
| Bank 10 | save | +0.03 | +0.02 | −0.01 | 0 | −0.01 | 0 | 0 | +0.01 |
| | +12 h / +48 h | 0 | 0 | 0 | +0.16 / 0 | −0.01 / 0 | 0 | 0 | +0.03 / 0.00 |
| Never bank | save | +0.03 | +0.02 | −0.23 | −0.05 | −0.14 | −0.01 | 0 | −0.04 |
| | +12 h | 0 | 0 | 0 | −1.19 | −0.06 | 0 | 0 | −0.20 |
| | +48 h | 0 | −1.12 | −0.70 | −0.15 | −0.01 | 0 | 0 | −0.33 |
| Swarmwarp instead of House of Mirrors | save | 0 | 0 | +0.62 | +0.80 | −3.2 | −7.0 | −20.6 | +0.24 |
| | +12 h | 0 | +0.40 | +1.08 | −5.7 | −3.6 | −8.0 | −21.4 | −0.70 |
| | +48 h | +0.24 | +2.71 | +1.38 | +0.54 | −1.9 | −7.3 | −21.5 | +0.88 |
| No hatching a higher tier just for twins | save | 0 | 0 | −3.5 | −3.3 | −12.6 | −6.7 | −11.2 | −1.12 |
| | +12 h | 0 | 0 | −0.01 | −6.6 | −8.5 | −7.0 | −11.4 | −1.10 |
| | +48 h | 0 | −2.8 | −3.6 | −3.3 | −4.8 | −6.9 | −11.2 | −1.61 |
| Check in every 15 min (not 1) | save / +12 h / +48 h | | | | | | | | −0.06 / −0.38 / −0.60 |

The lepidoptera target needs a start with fewer lepidoptera than the targets; the save already has 2,416. So it was tested from the save with lepidoptera set to 0, a counterfactual start with nothing refunded. Differences are from the target 4000:

| Lepidoptera target | +8 h | +24 h | +48 h | +4 d | +7 d | +14 d |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | +0.08 | +0.03 | +0.04 | −0.98 | −3.5 | −11.3 |
| 1000 | 0 | 0 | +0.06 | +0.36 | −0.74 | −3.7 |
| 2000 | 0 | 0 | +0.03 | +0.39 | −0.13 | −1.7 |
| 8000 | 0 | 0 | 0 | −1.25 | −0.71 | +0.09 |

From the real save (2,416 lepidoptera; the "target 0 or 2000" row in the sweep), stopping there is 1.4× worse at 4 to 8 h and 1.4 to 1.5× better at 2 to 4 days. Going on to 4000 is 2× better at 7 days and 8× better at 14 days.

### Verdicts

| Conclusion in the handoff | Now | Recommendation |
| --- | --- | --- |
| Climb at 3× (or 5× for multi-day) run age; 1× or 10× cost 20 to 50× on average over 1–48 h | **Shrank** for 1–48 h: at most 10× on average, 0 in two of three starts. Large single-mark effects remain (10^6 at +48 h from the +12 h start). 5 never lost to 3 and gained 10^1 to 10^6 at 2–4 days. **New:** a multiple of 10 earns 10^15–16 more meat by 14 days (costing up to 10^1.6 at 1–2 days); 20 earns 10^12–13 more by 7 days (costing up to 10^11 at 1–2 days). | Change the native default from 3 to 5. Flag the age rule as wrong for week-long runs. It is a structural problem, not a constant to tune: once mirrors make larvae plentiful, H (production payback) no longer limits climbing. A rule for that phase needs its own work. The unfixed simulator showed it too. |
| `share` 0.25 to 0.75 hardly matters | **Unchanged** (≤0.1 log10 on average) | Keep 0.5. |
| Bank at 3×; never banking costs about 3× | **Shrank**: never banking costs 1.1 to 2.1× on average, up to 10^1.2 at single marks. Banks 1, 3 and 10 are within 1.3× of each other on average, with 10 never worse than 3. | Keep 3. The direction holds; the stakes are small. |
| Lepidoptera: none under about 2 days, 2000–4000 for about 4 days, 4000 for 1–2 weeks | **Unchanged** | Keep 4000 as the default for long runs. Lepidoptera cost nothing measurable in the first 2 days. |
| House of Mirrors plan beats swarmwarp by about 10^4 at 4 days, 10^6 at 7 days, 10^19 at 14 days | **Unchanged**: 10^1.9–3.6 at 4 days, 10^7–8 at 7 days, 10^20.6–21.5 at 14 days | Keep. |
| The mirror plan costs about 25× on runs shorter than 2 to 3 days | **Partly**: swarmwarp is 4 to 25× better at +24 h from all three starts. At +48 h it is 3 to 6× better from two starts and 10^5.7 *worse* from the third. | The native advisor recommends mirrors whenever nexus 5 is owned, whatever the run length. That is right for runs of 4 days or more. It is a minor loss only if the player ascends within about a day. |
| Never hatching a higher tier just for twins costs about 200× on average | **Holds, smaller in the short run**: 13 to 40× on average over 1–48 h, and 10^5 to 10^12 at 4–14 days | Keep the twin planner. |
| Checking in every 15 min instead of every minute costs about 13× | **Shrank**: 1.15 to 4× on average | Not an advisor setting. |

How sure can one be? The mechanics are now verified. The conclusions rest on one real save plus two states of the simulator's own run. Differences under about 0.3 log10 (2×) on the 1–48 h average are within how much single marks jump when a tier starts a little earlier or later, so treat them as "no difference". The large effects all point the same way from all three starts: mirrors over swarmwarp, the twin planner, lepidoptera for long runs, 5 over 3, and big multiples at 14 days.

## The native advisor

Every game fact the advisor depends on was checked and holds:

- larva rate and unit costs, production and twins are read live from the game, so the ancestry bug never affected the advisor
- moth price 10 energy
- larva rush 1600 at nexus ≥ 1
- House of Mirrors 2500 at nexus 5
- buy no bats, because mirrors ignore spell power
- nexus prices read from the game
- the "below" costs it reads (`costByName[below].val`) equal the game's actual price on this save

Two points that are not false facts but are worth knowing:

- `ADVISOR_SETTINGS.defaults.ageMultiple` is 3, while `policy.json` and the handoff's multi-day advice use 5. See the table above.
- The energy line always recommends House of Mirrors at nexus 5 and has no notion of run length. That matches the evidence for runs of 4 days or more.

`swarmsim-coffee/test/spec/services/advisorfacts.coffee` pins four of these facts in the style of the neighbouring specs:

- House of Mirrors doubles every territory unit with 0 and with 1000 bats, and again on a second cast
- larva rush scales with bats
- the lepidoptera multiplier
- accomplished ancestry as (1 + 0.001 × points)^level

It passes in the Node harness (`node advisor/modelcheck/run_specs.js test/spec/services/advisorfacts.coffee`; the game's own effect, unit and upgrade specs also pass there, 57 passed and 2 pending). **Karma was not run.**

## The console script and its port give the same advice

`advisor/modelcheck/script_vs_port.js` is a regression check for the port of the console script's rules (`swarmsim-coffee/app/scripts/services/advisor.coffee`). It runs both against the same real game (`lib/game.js`). The script's rules are taken straight from `advisor/swarm-climb-live.js`, with `Date.now()` swapped for the game clock.

- **What it tests:** random mutations of the example save, seeded and deterministic. These cover unit counts up to overmind VI, faster and twin levels, larvae, meat, nexus 0 to 5, energy, lepidoptera, run ages from 36 s to 2 years, and every setting.
- **How it steps:** each state is stepped forward in game time, and suggested purchases are sometimes recorded in the game's statistics, so cooldowns, the purchase memory and the spare-stock rule all take part.
- **What it compares:** at each step, every tier action with its exact buy count, every tip and the energy line, as text.
- **Exit code:** 1 on any difference.

```sh
node advisor/modelcheck/script_vs_port.js [seed=1] [states=300] [steps=20]
```

Result on Nov 12, 2026:

- Seeds 1 and 2, 300 states × 20 steps each: 6,000 comparisons per seed, no differences.
- An earlier independent run on about 1,300 states found the same.
- Covered: buy, skip, all four wait reasons, faster, twin and twin-plan tips, and all six energy lines.
- A deliberately altered port was caught: exit 1.

It never ascends. The port deliberately starts a fresh purchase memory after an ascension; the script keeps the last run's stock levels and purchase times.

## Faster-aware climbing

Nov 13, 2026. The owner asked whether the climb rule should count the "faster" upgrade when deciding to start a new tier. On their 20.1 h save, hive queens cost 10^6 hives and make 6 hives/s. So H = 6 × 46.3 h = 11.6 d against a horizon of 3 × 20.1 h = 2.5 d, and the advisor says "wait 3.0 d". "Faster hive queens" costs only 66 hive queens and would halve H.

**Answer: it does not matter, as a rule of its own.** In every start and at every age multiple, the faster-aware rule behaves like the run-age rule with the age multiple doubled. Hive queens and empresses start within the same hour, the same numbers are held, and the scores differ by under 0.75 log10, with one exception noted below. Two reasons:
- When a tier first passes the faster-aware test, one check-in's hatch is thousands to 10^18 units, so the 66-unit price is negligible and H_eff ≈ H/2.
- Buying that faster level at its price instead of twice its price changed nothing measurable (≤0.07 log10): the policy holds twice the price within a check-in or two anyway.

So the benefit, where there is one, is "start the tier earlier", which a larger age multiple does just as well. At the native default of 3, starting earlier helps or is neutral in every start; at 5 it trades up to 10× at +24 h for 10^15 at 14 days. **Recommendation: do not add the rule to the native advisor; raise the default age multiple instead** (5, as `policy.json` already uses, or 6 to reproduce "3 with faster" exactly). An optional display-only hint is sketched at the end.

### The 20 h save loads correctly

**Measured.** `compare.py --save advisor/sim/example_save_20h.json` matches the game on every row.

Two things on this save were new, and the comparison showed them:
- **Crystal-bought energy.** The save has 8,500 `mtxEnergy`, which raises the energy cap by 1 each (the game's `capFlat`). The game's cap is 48,500; the simulator said 40,000. Fixed in `sim.py` (`s.mtx`).
- **Empowered swarmlings** (`swarmlingempower` 1). These change the swarmling's cost and production. The simulator does not model empower. The save holds 0 swarmlings and the policy only buys higher territory units, so nothing depends on it.

Two corrections were also made to the checker:
- It now skips purchases the save cannot afford.
- It compares larvae plus cocoons, because the simulator holds cocoons as larvae.

**At its first instant** (`faster_aware.py`, part 1), the native advisor, run as real game code, and the simulator agree on H for every tier:

| Tier | H (advisor = sim) | Advisor | Simulator |
| --- | --- | --- | --- |
| queen, nest, greater queen | 6e-6 s, 0.0076 s, 9.8 s | bank | pass the run-age test, bank |
| hive | 1562.5 s | BUY 1.00e6 (×8 twins) | passes, does not bank |
| hive queen | 1e6 s = 11.6 d | wait 3.0 d | fails; wait 3.02 d |

On the first step the simulator hatches no hives, because its tuned policy holds all 2.78e9 larvae (larvae plus cocoons) for nexus 5 (`nexus_secs`). The advisor's meat rules do not hold larvae for a nexus. With that hold switched off, the simulator hatches 2.09e7 hives on its first step. The count differs from the advisor's 8e6 because the simulator's quantity rule (income share) is not the advisor's share/spare rule. That is a policy difference, not a game-mechanics one.

### The rule as simulated (`faster_aware`, default off)

A tier k that fails the run-age test (H > ageMultiple × age) may still be climbed when this holds:

- n = purchases the policy would make this check-in under its usual limits: free larvae after higher tiers, `share` of the tier below, meat share, and the income earmark (`inc_share` / `stock_rel`).
- F = the next faster level's price, 66 × 666^level units of tier k.
- got = units held + n × twin.
- N = got − F, the units kept after paying for the upgrade.
- H_eff = k × (N + F) × costEach / (N × 2 × prodEach) = H × (N + F) / (2N).
- Test: N ≥ 1 and H_eff ≤ horizon.

This is honest accounting: the sunk F counts as cost, and only the N kept units count, at double rate. When the tier is started on this basis, the policy hatches n and buys that faster level at once, at its price rather than twice its price.

While the test fails, the tier's income earmark keeps growing, as the advisor's spare does. So the start converts a slice of the stock. A variant `fa_accumulate=False` keeps it to income only.

**When it can fire again.** Prices only fall in H (faster and twin levels only go up) and the horizon only grows. So once a tier passes either test it passes for good, and the rule fires at most once per tier. In every run here it fired once for hive queens and once for empresses, both at faster level 0.

A later level (43,956 units at level 1, then ×666) only comes into play for a tier already held at level ≥1 that still fails the plain test, for example one bought up through twin plans. Then the honest N + F accounting matters, and it correctly refuses until one check-in's hatch is large next to F. That is sensible.

**Twin seeking.** It treats a tier as "not climbed" when the plain test fails, so it may still hatch a few hive queens to pay for a hive twin, consuming them, in the same check-in where the faster-aware rule starts the tier. On these saves that never made a difference. The owner's 1 hive queen from a twin plan counts toward `got`.

### Results

Run `python3 -I advisor/modelcheck/faster_aware.py` (about 1.5 minutes; `--quick` takes about 20 s). Full tables are written to stdout and to `advisor/modelcheck/out/faster_aware.json`.

The real starts are the 20.1 h and 14.5 h saves. The other three are states of the simulator's own tuned run (age multiple 5), so they are **not independent**. Scores are log10 meat earned, rule on minus rule off at the same age multiple.

| Start | × | +24 h | +48 h | +4 d | +7 d | +14 d | Hive queens first hatched, off → on (h ahead) | Empresses, off → on |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 20.1 h save | 3 | 0 | **+5.6** | +1.7 | 0 | 0 | 72.5 → 26.2 | – → – |
| | 5 | −0.7 | **+5.3** | +0.1 | 0 | **+15.5** | 35.5 → 7.7 | – → 258 |
| | 10 | −2.8 | −0.3 | 0 | **+12.3** | +0.1 | 7.7 → 0.7 | 258 → 119 |
| 14.5 h save | 3 | 0 | −0.2 | **+2.3** | 0 | 0 | 78.1 → 31.8 | – → – |
| | 5 | −0.5 | −2.1 | +0.1 | 0 | **+15.3** | 41.1 → 13.3 | – → 263 |
| | 10 | −8.2 | −2.5 | −0.1 | **+11.8** | +0.1 | 13.3 → 8.1 | 263 → 124 |
| 14.5 h + 12 h (sim) | 3 | 0 | **+7.6** | +1.0 | 0 | 0 | 66.1 → 19.8 | – → – |
| | 5 | −1.0 | +1.8 | +0.1 | 0 | **+15.6** | 29.1 → 1.3 | – → 251 |
| 14.5 h + 48 h (sim, 4e8 hive queens held) | 3 | 0 | 0 | 0 | 0 | 0 | already climbing | – → – |
| | 5 | 0 | 0 | 0 | 0 | **+16.1** | already climbing | – → 215 |
| 20.1 h + 24 h (sim) | 3 | **+5.3** | **+9.8** | +0.3 | 0 | 0 | 48.5 → 2.2 | – → – |
| | 5 | **+4.0** | +0.2 | 0 | 0 | **+15.8** | 11.4 → 0.0 | – → 234 |

At +8 h every difference is within ±0.2 except −3.0 (20.1 h save, ×10). With the rule on at ×5, the three starts that had not begun hive queens hold 5.7e6 to 3.3e7 of them at +24 h, against 0 with it off. By +4 d both arms hold the same order of hive queens (1.5e17 to 6.7e16, for example), because larvae are no longer scarce.

**Ablations** (largest gap from the faster-aware row over all marks):

| Ablation | Gap |
| --- | --- |
| Upgrade bought at 2× price, as today | ≤0.07 log10 everywhere |
| Naive H/2 (upgrade counted, its price not) | ≤0.04, except 7.1 at one mark (14.5 h save, ×10, +48 h) |
| Income-only start (`fa_accumulate=False`) | ≤0.41, except that same cell |
| Rule off at twice the age multiple | ≤0.74 at ×3 and ×5; that same cell at ×10 (7.2) |

The ×10 cells are where both arms start hive queens within an hour or two of the save, and timing at a single mark swings by up to 10^8. Hive queen and empress start times match the doubled-multiple arm to within 2 hours in every case.

**Interpretation.**
- At ×3 (the native default), starting at about half the age helps from three of the five starts by 10^5 to 10^10 at +24 to +48 h. It never hurts by more than 0.2 log10 (noise). It is neutral from 7 days on, because neither arm reaches empresses in 14 days at ×3.
- On the 20.1 h save the rule starts hive queens at a run age of 46.3 h = 1.9 d, as the owner estimated.
- At ×5, the earlier start costs 3 to 9× at +24 h in three starts (−0.5 to −1.0, around the noise level) and gains 10^4 in a fourth. At +48 h it is mixed (+5.3, −2.1, +1.8, 0, +0.2). It wins 10^15 to 10^16 at 14 days in every start, because empresses get started at about 10 days instead of never.
- This is the same trade the earlier sensitivity sweep found for larger age multiples. The handoff's "starting hive queens as soon as possible costs 10^10 at 24 hours" (from the 11.9 h save) is a much earlier start than these, and was not re-run.

**How sure.** The equivalence to "double the age multiple" is measured in all 15 start × multiple cells, and it has a simple mechanical reason (N ≫ F at the moment of starting), so I am confident in it. That earlier starts help at ×3 is measured from two real saves and three dependent states. It agrees in direction everywhere, with magnitudes that depend on the mark.

### If the owner still wants it in the advisor

As a display hint only. It changes no buy decision, because it is equivalent to a larger age multiple, which is the better lever. Shown on a tier that fails rule 1:

- Quantities: F = the tier's faster price (66 × 666^level of the tier itself); n = the purchase count rule 3 would suggest if the tier passed; got = count + n × twin; N = got − F.
- If N ≥ 1 and H × (N + F)/(2N) ≤ horizon, show the plan "hatch n hive queens > buy faster hive queens (66)". After the hatch, show the faster tip at 1× its price for that level, not 2×.
- If N < 1, keep "wait …" and add "(with faster: wait X)", where X = (H/2)/ageMultiple − age. Leave it out when X ≥ the plain wait.

## What remains unverified

- **The browser build and Karma.** Everything here ran the game's services in Node with a stand-in injector. The Angular wiring, the UI and the statistics service, which the advisor uses to detect purchases, were not exercised.
- **The policy's realism.** The check covers the game mechanics the simulator integrates and the purchases it makes. It does not cover whether a player could follow its once-a-minute policy, or game rules the policy never touches: upgrade visibility, ascension and mutagen, territory "empower" upgrades, event and click achievements.
- **More than one save.** The sensitivity results come from one real state. The other two starts are the simulator's own trajectory. Earlier saves (1.2, 3.3 and 11.9 h) and the handoff's seven simulated states were not available here.
- **The late game.** Pantheons and overminds are still never reached in these runs. The new finding that larger age multiples win at 7 to 14 days comes from runs that move from hive queens to empresses, nothing higher.
- **The handoff's other evidence rows**, not re-run here: hive-queen timing, nexus-saving timing, stockpile dumping, 100 bats, and always buying the top territory unit. The mechanics under them are now verified. The magnitudes may have shifted like those above.
