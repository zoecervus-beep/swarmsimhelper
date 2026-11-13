# Ascension and mutagen: mechanics, model and first strategy findings

Nov 13, 2026. First pass. Nothing in the game or the advisor was changed; the simulator gained ascension and mutagen, checked against the game's own code.

Scope: the mutagen side of the game is small enough to cover completely. There are 10 mutations, and every one of them was verified by running the game's code (section 2). The strategy work concentrates on what decides *when to ascend* and on the handful of purchases that matter. Three mutations (clone, warp, bat) do nothing under the advisor's current spell plan, so their strategic value was not explored beyond that.

## 1. Conclusions

"Measured" means run in the game's code or in the simulator. "Inferred" means reasoned from those runs. Every strategy number comes from a simulator tuned on one player's single run, starting from one save (20.1 h). The simulator plays a perfect once-a-minute policy, so it is faster than a person.

| # | Finding | Grade |
| --- | --- | --- |
| 1 | **Mutagen comes almost entirely from expansions, and House of Mirrors drives them.** Premutagen (the game's "mutagen (inactive)") only spawns when a hatchery reaches level 40+ or an expansion reaches level 80+. The amount is about 1.2544^level per hatchery and 1.12^level per expansion. Each mirror cast doubles every territory unit, which pays for about 0.77 more expansions, so each cast multiplies future premutagen by about 1.09. Over a run the total grows exponentially: ×28 a day from the save in the simulator (+1.45 in log10 per day). Hatcheries add a few percent. | Mechanics **solid** (measured in game code). Growth rate **likely** (simulator, one trajectory) |
| 2 | **Energy income sets the growth rate, so the lepidoptera ("nexus") mutation is the purchase that matters.** It raises energy production toward 2× (1.998× at 10^6 units, measured), and premutagen growth doubles with it: +2.56 instead of +1.45 log10 per day. Every other mutation is a fixed multiplier at best. Measured over 6 days of the next run, the best plan without it trails by 10^7. | **Likely** |
| 3 | **When to ascend: as soon as the energy cost can be paid, *if* you will keep playing at least 5 to 6 days after ascending. Otherwise, don't.** The cost is paid in energy and falls as energy is spent. From the 20.1 h save the simulator can first ascend 84 h later (run age 4.3 days). That path overtakes never-ascending 4.7 days after the ascension in mutagen and 6.2 days after in meat/s. By 14 days it is 10^6.6 ahead in mutagen and 10^10.6 ahead in meat/s. Every day of delay costs about 10^2.3 of mutagen at the 14-day mark. | Shape **likely**. Break-even days **guess** to likely, since a person's next run starts slower than the simulator's (probably 1 to 2 days later) |
| 4 | **First purchases:** unlock the lepidoptera mutation first (price 1), then buy about 10^6 of it. Unlock mutation frequency second (price 15,625), then buy about 10^6. Keep the rest unspent: each unspent mutagen makes 0.1 larva/s. A third unlock costs 2.44×10^8, more than the 4.4×10^7 the first ascension yields, so two is the limit. Frequency and "meta-mutation" (quantity) are tied as the second pick at 6 days; frequency is far cheaper to max. | Prices and limits **solid**. Ranking **likely** |
| 5 | **After that, do not ascend again** under either objective. Once the nexus mutation is bought, nothing left raises the growth rate, and an ascension restarts the expansion ladder from zero. A second ascension at run ages 2 to 5 days left total mutagen 10^7.8 to 10^10.8 behind never ascending at the 13.5-day mark, with no catch-up. So runs after the first ascension should be open-ended. | **Likely** for horizons up to about 2 weeks. **Guess** beyond that: the simulator overflows floats after about 1,000 mirror casts, roughly 3 weeks |
| 6 | **In-run advice:** (a) House of Mirrors is the mutagen engine on runs of any length. Casting swarmwarp instead leaves premutagen gaining only 0.15 log10 a day. (b) The age-multiple horizon does not matter for mutagen: 3, 5, 10 and 20 move premutagen by ≤0.05 log10 and the first ascension by ≤1 h. It matters for meat as before. (c) Lepidoptera: 4,000 is right until about 6 days after an ascension; 10,000 wins from there (+0.1 log10 at 8 days); 30,000 only pays after about 3 weeks. (d) Energy needs a reserve rule for the ascension: keep spending until the cost falls to 72,135, or the cap if that is lower, then stop spending and save. | (a) **solid** to likely. (b), (c) **likely**. (d) **solid** (it follows from the cost formula) |
| 7 | **Crystals matter for timing.** Buying a hatchery or expansion grants 500 crystals once per 30 minutes (from nexus 1). Converting them to energy (the owner does) raises the cap for good and adds about 0.28 energy/s with frequent check-ins. In the simulator that brings the first ascension 14 h earlier and raises premutagen growth by about 20%. A player who checks in rarely gets 500 crystals per visit, not per 30 minutes. | Mechanics **solid**. Effect size **likely**, and it depends on check-in cadence |

## 2. Mechanics, as the game computes them

Sources:
- Data: `swarmsim-coffee/app/scripts/spreadsheetpreload/v0.2.js`, the table the game loads; it is identical to `tables/src/spreadsheet/original-data.json` for these rows.
- Code: `game.coffee` (`ascend`, `ascendCost`, `respec`), `effect.coffee` (`addUnitRand`, `logStat`, `asympStat`, `expStat`), `upgrade.coffee` (`_totalCost`), `unit.coffee` (`spent`), `seedrand.coffee`.
- Views: `app/views/desc/unit/mutagen.html` and the hatchery and expansion descriptions.

Every worked number below was **measured** by running the game's code in Node (`advisor/modelcheck/ascension_check.js`), on the 20.1 h save unless stated. Time zone: UTC.

### 2.1 Premutagen: how it is earned

Only two things produce it: buying a **hatchery** or an **expansion** (`addUnitRand` effect). Nothing else does, apart from a one-off backfill for very old saves.

On reaching level L of a hatchery (L ≥ 40) or an expansion (L ≥ 80):

```
spawned  = (L == minlevel) or (L mod 8 == 0) or (roll1 < p)
quantity = ceil( E × f^L × (0.9 + 0.2 × roll2) )      f = 1.2544 (hatchery), 1.12 (expansion)
p = 0.2 × (1 + 4 × (1 − 1/(1 + 0.001 × n_freq)))      (mutation frequency; 0.2 with none, max 1.0)
E = 1 + 0.5 × (log10(10 + 0.1 × n_each) − 1)          (meta-mutation; 1 with none)
```

- **Randomness is seeded.** `roll1` and `roll2` are the first two draws of seedrandom 2.4.2 (ARC4) seeded with `"<start date>:[<run restart time in ms>, hatchery|expansion, L]"`.
  - The start date is `Date.toString()`, so it is in the browser's **local time zone**. On the 20 h save in UTC it is `Thu Nov 12 2026 02:11:33 GMT+0000 (Coordinated Universal Time)`.
  - The result is fully deterministic given the save's start date, the time of the last ascension, the level and the time zone. It does not depend on when you buy.
  - The game's own hatchery page shows "Your next hatchery has a 20% chance to award N mutagen" with N = `outputNext().qty`. That N is the actual roll, and `outputNext().spawned` already says whether it will spawn.
  - The simulator reproduces the generator exactly (`sim._seedrandom`), checked in UTC and in New York time.
- **Worked numbers** (20 h save, UTC):

  | Level | Spawned? | Quantity |
  | --- | --- | --- |
  | Hatchery 40 | yes (guaranteed) | 9,033 (base 8,658.48) |
  | Hatchery 41 | no (would be 11,679) | – |
  | Hatchery 48 | yes (every 8th) | 54,272 |
  | Expansion 80 | yes | 8,738 |
  | Expansion 200 | yes | 6.34×10^9 |
  | Expansion 400 | yes | 4.75×10^19 |

  Of expansion levels 78 to 460, 119 of 383 spawn (31%; expected 30% = (1 + 7 × 0.2)/8). Buying hatcheries 33 to 60 and expansions 66 to 120 for real gave 5.226×10^6 premutagen with no mutants. With 10^6 meta-mutation and 10^4 frequency mutants it gave 3.336×10^7 (p 0.927, E 3.00).
- **Mean per level** (the simulator's `expected` mode): E × f^L × (1 if L is the first level or a multiple of 8, else p). The sum over a run is dominated by the last few levels: about 9× the top expansion level's amount, or 5× the top hatchery's.
- **How it scales through a run.**
  - Hatchery level L costs 300 × 10^L meat, so premutagen from hatcheries goes up ×1.25 per 10× meat. That is slow, and meat grows polynomially.
  - Expansion L costs 10 × 2.45^L territory. House of Mirrors doubles every territory unit, so territory production doubles, which is worth log(2)/log(2.45) = 0.774 expansions. Premutagen per cast therefore goes up ×1.12^0.774 = 1.092.
  - Measured in the simulator, never ascending from the 20 h save: 0.79 expansions per cast, and premutagen ×28 a day (+1.45 log10/day) once mirrors run.
- **On the real saves:** 0 premutagen. The 14.5 h save has hatchery 29 / expansion 57; the 20.1 h save has hatchery 32 / expansion 65. In the simulator the first premutagen comes 5 h after the 20 h save, at hatchery 40.
- **No cap.** The game's unit limit is 1e100000.

### 2.2 The ascension cost

The cost is paid in **energy**:

```
cost = ceil( 5,000,000 × 1.12^ascensions / 2^( S / (50,000 × N) ) )
N    = 1 + 0.6 × (1 − 1/(1 + 0.0005 × n_nexusmutation))   (1 with none, max 1.6)
S    = energy spent this run = Σ (energy price × count) over units owned
       + Σ energy price of every upgrade level bought − respecEnergy
```

- What counts in S: lepidoptera 10 each, nightbugs 10, bats 100. Nexus 2 to 5: 625 / 2,500 / 10,000 / 36,000. Nexus 1 costs only meat. Spells, per cast: House of Mirrors 2,500, larva rush 1,600, swarmwarp 2,000, meat rush 1,600, territory rush 1,600, clone larvae 12,000. Energy bought with crystals is **not** spent energy.
- **The cap rule.** You can only ascend while energy ≥ cost, and energy is capped (10,000 per nexus × nightbug and nexus-mutation multipliers, plus 1 per crystal-bought energy). So the cost has to fall under the cap first.
- **Worked numbers:**

  | Case | S | Cost |
  | --- | --- | --- |
  | 20 h save | 49,775 (3,665 × 10 + 625 + 2,500 + 10,000) | 2,507,811 (cap 48,500) |
  | + nexus 5 | 85,775 | 1,522,486 |
  | + 100 mirrors | 335,775 | 47,578 |
  | + 300 mirrors | – | 47 |
  | 3 earlier ascensions, nexus 5, 100 mirrors | – | 66,844 |
  | 10^6 nexus mutants, nexus 5, 100 mirrors | – | 271,985 |

- **Spend or save?** Spending E more energy lowers the cost by about cost × E × ln 2 / (50,000 × N). So spending beats saving until the cost reaches 50,000 × N / ln 2: 72,135 without the nexus mutation, 115,416 with it maxed, and capped by the energy cap. Then stop spending and save. The simulator's `ascend` rule does exactly this. From the 20 h save it starts saving at hour 64 and ascends at hour 84, paying 71,270.
- **Repeat cost.** With nothing spent, the cost is 5,600,000 / 6,272,000 / 7,024,640 / … after 1, 2, 3 ascensions (×1.12 each).

### 2.3 What ascending resets and keeps

**Measured.** The 20 h save was given 40,000 lepidoptera (so the cost, 16,283, fits the cap), 123,456 premutagen, 777 crystals and 5 frequency mutants, then ascended.

| Kept | Reset |
| --- | --- |
| Mutagen (premutagen is added to it) | Every meat, larva, territory and energy unit, to its start value: meat 35, larvae 10, everything else 0. That includes energy, nexus, lepidoptera, bats, nightbugs and cocoons |
| Ascension count +1 | Every upgrade outside the mutagen tab: hatchery, expansion, accomplished ancestry, faster, twin, nexus 1 to 5, spell counts |
| Free respecs (+1 on every 3rd ascension) | Energy spent, and so the next cost: 5.6M after the first ascension |
| Every mutant unit and every unlock | The run clock (`date.restarted` = the moment of ascending); `date.started` is unchanged |
| Crystals, and crystal-bought energy (`mtxEnergy`), which keeps the energy cap raised: the cap is 8,500 straight after ascending | The premutagen seed, because it uses the restart time |
| Achievements and their points: 730 → 740, as "ascend once" adds 10. The ancestry upgrade must be rebought, but the points are intact | |
| Statistics (units bought), so unit achievements keep counting toward the next tier | |

- **The new run** starts with 1 larva/s plus 0.1/s per unspent mutagen (12,346.6/s here). After 600 s it holds 7,407,970 larvae and still 35 meat, because no drones exist yet.
- **Ascension achievements:** +10 / +20 / +30 / +40 / +50 points at 1 / 3 / 5 / 10 / 20 ascensions. The first unlock adds 10 more ("mutation1"). With accomplished ancestry 5 and 730 points, +20 points is +6% larvae.

### 2.4 From premutagen to mutagen, and what unspent mutagen does

- Ascending moves all premutagen into mutagen 1:1. Nothing else converts it.
- **Unspent mutagen makes 0.1 larva/s each.** It sits outside the hatchery, expansion, ancestry and hatchery-mutation multipliers. Measured larvae/s (mutagen / hatchery mutants):

  | Mutagen / hatchery mutants | Larvae/s |
  | --- | --- |
  | 0 / 0 | 250,766 |
  | 10^6 / 0 | 350,766 |
  | 10^6 / 10^4 | 1,103,174 (= 250,766 × log10(10,010) + 100,000) |
  | 10^9 / 10^6 | 1.01505×10^8 |

  The game's own tutorial says the same: "Mutagen you haven't spent yet will produce some larvae, don't spend it all right away!"

### 2.5 What mutagen buys

- **Unlocks.** Ten "mutation" upgrades, one per mutant unit, each max level 1. The k-th unlock you buy, *of any kind*, costs **15,625^k** mutagen: 1, 15,625, 2.44×10^8, 3.81×10^12, 5.96×10^16, 9.3×10^20, … (measured to the 4th). Order matters enormously: the first unlock is nearly free and the third already costs 2.4×10^8. Each unlock comes with one free mutant.
- **Mutants.** 1 mutagen each, flat price, no cap. Effects (`effect.coffee`; n = count):
  - `log` = 1 + c × (log10(v·n + 10) − 1)
  - `asymp` = 1 + (max − 1)(1 − 1/(1 + w·n))
  - `exp` = 1 + 0.001 × n^0.2

| Mutation (unit) | Effect | Formula | Game value at n = 10^4 / 10^6 / 10^9 (base) |
| --- | --- | --- | --- |
| Hatchery (`mutanthatchery`) | hatchery larvae × | log, v=1, c=1 (i.e. log10(n+10)) | larvae/s 1.003M / 1.505M / 2.257M (250,766) |
| Lepidoptera (`mutantnexus`) | energy production ×, energy cap ×, ascension-cost halving ÷ | asymp max 2, w=0.0005 (production and cap); max 1.6 for N | energy/s 1.637 / 1.784 / 1.786 (0.893); cap 100,167 / 108,400 / 108,500 (58,500); cost 2.26M / 2.38M (1.52M) |
| Frequency (`mutantfreq`) | premutagen chance p | 0.2 × asymp max 5, w=0.001 | 0.927 / 0.9992 / 1.0 (0.2) |
| Meta-mutation (`mutanteach`) | premutagen quantity E | log, v=0.1, c=0.5 | 2.00 / 3.00 / 4.5 (1) |
| Meat (`mutantmeat`) | production of each meat tier | log, v=0.1, c from 0.48 (drone) falling ×0.85 per tier to 0.022 (overmind 6) | drone 2,009 / 2,990 / 4,465 (1,024); hive 60.1 / 80.1 / 110.2 (40) |
| Rush (`mutantrush`) | larva rush power; meat and territory rush power | log, v=1, c=3; c=13 | larva rush 6.02×10^9 / 9.63×10^9 / 1.50×10^10 larvae (6.02×10^8); territory rush 5.8×10^27 / 9.5×10^27 / 1.5×10^28 (1.45×10^26) |
| Clone (`mutantclone`) | clone larvae power (raises only its cap) | log, v=1, c=1.8 | 1.61×10^11 / 2.51×10^11 / 3.86×10^11 larvae (2.51×10^10) |
| Warp (`mutantswarmwarp`) | swarmwarp power (longer skip) | log, v=1, c=2 | drones gained 5.2×10^30 / 3.1×10^31 / 1.7×10^32 (1.0×10^28) |
| Bat (`mutantbat`) | spell power, all spells (mirrors ignore it) | log, v=0.1, c=1 | 3.00 / 5.00 / 8.0 (1) |
| Territory (`mutantarmy`) | production of every territory unit | exp | goon 2.399×10^15 / 2.421×10^15 / 2.534×10^15 (2.384×10^15): ×1.06 at 10^9, ×2 only at 10^15 |

Nothing changes starting resources or unlock thresholds. `mutanteach` also carries the minimum levels 40 and 80 as constants (`initStat`), so the thresholds are fixed.

### 2.6 Respec

- **Refund.** A respec refunds **all** mutagen spent in the mutagen tab at 100%: every unlock price plus every mutant bought, minus the free unit per unlock. Measured: 1e13 → spend 3.81×10^12 → respec → exactly 1e13 again. All mutants and unlocks go to 0, so the unlock prices restart at 1.
- **Paid respec.** It costs **30% of the current ascension cost** in energy. It also adds `respecEnergy` equal to the energy spent so far, which **wipes the discount** on the next ascension. Measured: the next ascension cost went from 152,103 to 2,974,830.
- **Free respec.** You have 4 to start, plus 1 on every 3rd ascension. A free respec keeps the energy credit.
- **When it is useful.** Only to change an unlock order or reallocate. A paid respec is costly just before an ascension.

### 2.7 Crystals

Measured:
- With energy visible (nexus ≥ 1), a hatchery or expansion bought at least 30 min after the last grant gives 500 crystals. A purchase 60 s later gives nothing; 31 min later, another 500.
- Buying 500 energy with crystals raises energy by 500 and the cap by 500 for good (`mtxEnergy`, which survives ascension). It does not count as spent energy.
- After an ascension (nexus 0) hatcheries grant nothing until nexus 1.
- The owner's saves show this in use: 5,000 crystals at 14.5 h, then 8,500 crystal-bought energy at 20.1 h.

### 2.8 Interactions with what the advisor already advises on

- **House of Mirrors and territory units.**
  - Mirrors are the premutagen engine (2.1).
  - Each cast is also 2,500 spent energy, so it lowers the ascension cost ×0.966.
  - Mirrors need territory units to double. With no territory larvae at all (f=0) premutagen growth collapses to 0.2 log10/day. Stopping territory purchases once mirrors run (`f_mirror=0`) makes no difference, as the handoff found.
- **Lepidoptera** raise energy (the growth rate) and count as spent energy at 10 each.
- **Bats / spell power** do nothing for mirrors; neither does the bat mutation.
- **Clone larvae** only gets a larger cap from its mutation.
- **Nexus.** Nexus 2 to 5 energy counts as spent. All five are lost at an ascension and must be rebought: 49,125 energy plus meat and larvae. In the simulator that is the bottleneck of a new run: nexus 5 about a day in, with or without mutagen.
- **Achievement points and accomplished ancestry:** see 2.3.

## 3. Model check: the new simulator parts against the game

`advisor/modelcheck/ascension_compare.py` plays simulated runs with exact premutagen rolls. It hands their hatchery and expansion levels to `ascension_check.js`, which buys the same levels through the real `upgrade.buy()`. It then compares 3,444 numbers. **The largest sim/game difference is 2×10^-6**, which comes from the game table's rounded goon production (already noted in MODEL-CHECK.md); everything else agrees to 10^-12 or exactly. Full tables: `advisor/modelcheck/out/ascension_compare.md`.

| Check | Result |
| --- | --- |
| Premutagen roll per level: hatchery 38 to 140, expansion 78 to 460, both saves (972 levels) | spawn flags 972/972 identical; quantities identical (largest difference 2×10^-13, float vs Decimal) |
| Real purchases: hatchery 33 to 60, expansion 66 to 120, with and without mutants | 5,226,080 and 33,363,900, identical; p and E identical |
| Accrual over a simulated run, 14.5 h save, 4 days (100 levels) | identical at every purchase: 3.52×10^4 at 25 h, 1.79×10^6 at 57 h, 9.28×10^7 at 95 h |
| Accrual, 20.1 h save until it ascends (98 levels) | identical; 6.01×10^7 at 97 h |
| Accrual in run 2, after a simulated ascension (new restart seed, nexus and frequency mutants; 130 levels) | identical; 9.47×10^9 at 167 h |
| Ascension cost, 13 cases (lepidoptera, nexus 5, mirrors, all other spells, bats, nightbugs, past ascensions, nexus mutation, respecEnergy) | spent and cost identical in all 13; respec cost and cap too |
| State after an ascension: units, upgrades, points, larvae/s, cap, next cost, restart time | all identical, including meat 35, larvae 10, mtxEnergy 8,500, achievement points 740, larvae/s 12,346.6, next cost 5.6M |
| Seven ascensions in a row: cost and free respecs | identical |
| Unlock prices in sequence | identical (1, 15,625, 2.44×10^8, 3.81×10^12) |
| Each mutant at 1, 100, 10^4, 10^6, 10^9, 10^12: larvae/s, energy/s, cap, spell power, p, E, ascension cost, every meat tier's and territory unit's production, larva/meat/territory rush, clone larvae, swarmwarp | all identical (rushes compared without their flat +10^11 meat / +10^9 territory, which the simulator leaves out as before) |
| Unspent mutagen's larvae | identical |
| Crystals | the simulator's rule (500 per 30 min of hatchery/expansion purchases from nexus 1; energy +500, cap +500) matches the game's behaviour |

- **The mean against the real roll.** The `expected` mode is within 0.3 log10 of the game's roll at every mark of the 14-day comparison: 10.48 vs 10.74 at +5 d, 23.46 vs 23.34 at +14 d. The ascending path ascends at the same hour (84) either way, with 4.52×10^7 rolled against 4.42×10^7 mean.
- **The rest of the simulator is unchanged.** `run_example.py` (both saves) and `compare.py` (both saves) print byte-identical output before and after, because both saves hold no mutagen and every new multiplier is exactly 1.0.
- **Two simulator fixes were needed for fresh runs.**
  - A run with no drones yet is handled.
  - The territory split no longer spends more meat than it has. When larvae outrun meat, which happens with mutagen larvae, the old "balanced" split could drive meat negative. That never happened on the existing saves.

**What the simulator does not reproduce:**
- It plays a fresh run faster than a person: nexus 4 at 12 h and nexus 5 at 24 h, against the owner's nexus 4 at about 20 h.
- Swarmling empower is still not modelled.
- Event achievements are not modelled.
- Floats overflow after about 1,000 mirror casts in one run, roughly 3 weeks.

## 4. Strategy

### 4.1 The objective

Mutagen compounds within a run, not across runs: it grows exponentially with mirror casts. Its uses between runs are either logarithmic (most mutations), asymptotic (frequency, nexus) or linear but small (0.1 larva/s per unspent mutagen). So "maximise long-run growth of mutagen per unit of real time" reduces to "maximise the in-run growth rate, then stop resetting".

Two objectives were scored, both from the 20.1 h save at fixed real-time marks:

- **A. Total mutagen**: held plus not yet activated. This is the natural prestige score, and the long-run growth objective.
- **B. Meat per second**: progress, standing in for "reach a milestone such as the next tier".

They give the same shape. B has a later break-even.

### 4.2 When to ascend first

Run 1 continued from the save with no ascension: crystals converted, tuned policy, premutagen as the mean of the roll. Measured in the simulator.

| Hours from save | Run age (d) | log10 premutagen | Gain per day | Expansions | Mirrors | Energy spent | Ascension cost | Cap |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 0.8 | – | – | 65 | 0 | 49,775 | 2,507,811 | 48,500 |
| 12 | 1.3 | 4.48 | – | 80 | 8 | 109,125 | 1,101,469 | 65,500 |
| 24 | 1.8 | 5.12 | – | 94 | 26 | 154,125 | 590,263 | 72,500 |
| 48 | 2.8 | 6.55 | 1.44 | 122 | 63 | 246,625 | 163,735 | 86,500 |
| 72 | 3.8 | 7.85 | 1.30 | 151 | 100 | 339,125 | 45,419 | 101,000 |
| 96 | 4.8 | 9.26 | 1.41 | 179 | 137 | 431,625 | 12,599 | 115,000 |
| 120 | 5.8 | 10.74 | 1.48 | 208 | 174 | 524,125 | 3,495 | 129,500 |
| 168 | 7.8 | 13.53 | 1.48 | 265 | 247 | 706,625 | 279 | 158,000 |
| 336 | 14.8 | 23.34 | 1.45 | 464 | 505 | 1,351,625 | 1 | 257,500 |

How to read it:
- The marginal rate is about 3.3 × the current premutagen per day. In other words, waiting a day multiplies what you would bring by about 28.
- The cost falls under the cap at hour 59 and under 72,135 at hour 64. With the saving rule (2.2) the first ascension happens at **hour 84 (run age 4.3 d) with 4.4×10^7 mutagen**.
- Saving for the cost means about 20 h without mirrors, which is why that is less than the never-ascend curve's 3.5×10^8 at hour 84.
- Without crystals: hour 98, 6.2×10^7, and +1.18 log10/day.

Ascending at different moments, each followed by run 2 with the first purchases (lepidoptera and frequency mutations). Total mutagen, log10:

| Ascend | At hour | Brings (log10) | +5 d | +7 d | +10 d | +12 d | +14 d |
| --- | --- | --- | --- | --- | --- | --- | --- |
| never | – | – | 10.74 | 13.53 | 17.63 | 20.43 | 23.34 |
| earliest | 84 | 7.65 | 7.72 | 12.04 | **19.72** | **24.84** | **29.91** |
| save from run age 5 d | 102 | 9.62 | 9.62 | 10.44 | 18.05 | 23.12 | 28.23 |
| save from run age 6 d | 125 | 10.90 | 10.74 | 10.90 | 15.83 | 20.95 | 26.07 |
| save from run age 7 d | 148 | 12.35 | 10.74 | 12.35 | 13.55 | 18.64 | 23.75 |
| save from run age 9 d | 196 | 15.13 | 10.74 | 13.53 | 15.13 | 15.16 | 19.08 |

The same runs, log10 meat per second: never 68.99 / 75.30 / 84.49 / 89.98 / 95.78; earliest 48.31 / 68.37 / 85.31 / 95.68 / 106.36.

- **Break-even.** Ascending at the earliest moment overtakes never ascending at hour 198 for mutagen, 4.7 days after the ascension, and at hour 233 for meat/s, 6.2 days after.
- **Sensitivity.** The best moment is "as soon as affordable" at every horizon past break-even. Each day of delay costs about 2.3 log10 at 14 days. That follows from the mechanism: what you bring matters little, because run 2's own premutagen overtakes it within about 2.5 days, while starting the faster growth later costs its full slope.
- **The game's real rolls give the same picture:** 29.91 at 14 days.

Why the earliest moment is energy-bound, and what would move it:
- The cost needs about 380k energy in total: spent energy plus the cap's worth saved.
- More crystals, or lepidoptera bought earlier (they count as spent), move it slightly. With lepidoptera at 8,000 the ascension is at hour 82.
- Climbing settings do not move it (age multiple 3 or 10: hour 83 or 84).

### 4.3 What to buy first

Every plan starts from the same ascension (4.42×10^7 mutagen, hour 84); run 2 is the tuned policy. The table shows log10 premutagen at each run age (measured, simulator).

| Plan | 1 d | 2 d | 4 d | 6 d | Gain/day | Meat/s at 6 d |
| --- | --- | --- | --- | --- | --- | --- |
| lepidoptera 10^6 + frequency 10^6 | 5.78 | 8.26 | 13.42 | **18.54** | 2.56 | 82.67 |
| lepidoptera 10^5 + frequency 10^5 (either order) | 5.77 | 8.20 | 13.32 | 18.44 | 2.56 | 82.49 |
| lepidoptera 10^5 + meta-mutation 50% | 5.83 | 8.19 | 13.31 | 18.43 | 2.56 | 82.30 |
| lepidoptera 10^5 + hatchery 50% | 5.41 | 7.72 | 12.84 | 17.96 | 2.56 | 85.00 |
| lepidoptera 10^5 + hatchery held at the larva-maximising count | 5.41 | 7.72 | 12.84 | 17.92 | 2.54 | 84.94 |
| lepidoptera 10^5 only | 5.29 | 7.69 | 12.80 | 17.92 | 2.56 | 82.49 |
| lepidoptera 10^5 + meat 50% | 5.37 | 7.66 | 12.77 | 17.89 | 2.56 | **85.85** |
| lepidoptera 10^5 + rush / territory / bat / clone / warp 50% | 5.26 | 7.62 | 12.74 | 17.86 | 2.56 | 82.30 |
| lepidoptera 10^5 + rush 50%, territory rush 1 cast in 4 | 5.26 | 7.04 | 10.87 | 14.71 | 1.92 | 76.85 |
| lepidoptera 10^3 + frequency 10^3 (too few) | 5.25 | 6.62 | 10.34 | 14.06 | 1.86 | 74.80 |
| frequency only / meta-mutation only / hatchery only | ≤5.54 | ≤6.18 | ≤8.80 | ≤11.55 | 1.37 to 1.39 | ≤72.35 |
| nothing (all 4.4×10^7 held: 4.4×10^6 larvae/s) | 5.02 | 5.62 | 8.23 | 10.98 | 1.37 | 69.72 |

- **Ranking for mutagen.**
  1. The lepidoptera mutation is first by a wide margin: about 10^7 at 6 days.
  2. Frequency and meta-mutation are tied as the second pick, about 3.3× each (0.5 log10). Frequency needs only ~10^5 to 10^6 units to max, so it leaves the rest of the mutagen making larvae.
  3. Hatchery and meat are worth about 3× less mutagen than frequency, barely more than the lepidoptera mutation alone.
- **For meat/s** (objective B), the second pick flips: meat (85.85) or hatchery (85.00) beats frequency (82.49), a difference of about 10^3.
- **Bat, clone, warp and rush** do nothing under the current spell plan, which is mirrors only, with larva rush before nexus 5. Mixing territory rush with a strong rush mutation costs growth.
- **Amounts.** The asymptotic mutations need ≥10^5 to reach 98% of their cap; 10^3 is clearly too few. Ten times more (10^6) adds 0.1 log10 for 2.2×10^6 mutagen, about 5% of the haul.
- **A third unlock** (2.44×10^8) is out of reach on a 4.4×10^7 first ascension. Waiting for it costs more (2.3 log10 a day) than it gives: meta-mutation ×3.7 ≈ 0.57 log10.

### 4.4 Later runs

Run 2 has the first purchases (lepidoptera and frequency mutations). It is ascended again once saving starts at run age 2 to 5 days; the second ascension unlocks meta-mutation, hatchery and meat and holds hatchery mutants at the larva-maximising count. The alternative is never ascending again. Total mutagen, log10:

| Second ascension | At hour | Brings (log10) | 180 h | 228 h | 276 h | 324 h |
| --- | --- | --- | --- | --- | --- | --- |
| never | – | – | 13.32 | 18.44 | 23.56 | **28.63** |
| saving from run age 2 d | 167 | 10.27 | 10.11 | 10.73 | 15.73 | 20.85 |
| from 3 d | 168 | 10.96 | 10.80 | 11.03 | 15.76 | 20.88 |
| from 4 d | 183 | 13.42 | 13.32 | 13.20 | 14.62 | 19.74 |
| from 5 d | 204 | 15.93 | 13.32 | 15.77 | 15.77 | 17.85 |

- After a second ascension, run 3 grows at the same rate as run 2 (+5.1 per 48 h). It never closes a gap of 7.8 to 10.8 log10.
- **So the best run length does not settle; it grows without bound.** After the one ascension that buys the lepidoptera mutation, keep the run going.
- This holds while nothing else raises energy income. Measured: lepidoptera beyond 4,000 raise it a little (+0.15 log10/day at 10,000).
- Under objective B the same holds. Meat follows larvae (1.1^expansions), which follow the same mirror count.

### 4.5 What this means for the existing in-run advice

All measured in run 2, after the first purchases, unless stated.

| Advice | Run-2 result | Implication |
| --- | --- | --- |
| Age multiple × run age as the climbing horizon | premutagen at 2 / 4 / 6 / 8 d: 3 → 8.20 / 13.32 / 18.44 / 23.51; 5 → 8.20 / 13.32 / 18.44 / 23.56; 10 and 20 within 0.05. Meat/s at 2 d: 50.2 (×3, ×5) vs 59.0 (×10); at 6 d: 91.5 (×20) vs 82.5 | For mutagen it does not matter: meat does not feed premutagen (hatchery premutagen is tiny next to expansions). Before the single first ascension, nothing measurable depends on it either (first ascension at hour 83 or 84). Replacing it with "time until the planned ascension" would only change meat that the ascension throws away. **Keep it for meat**; the MODEL-CHECK finding that bigger multiples win on long runs still applies, and runs after the first ascension are long. |
| Lepidoptera target 4,000 | 0 → +1.55/day; 4,000 → 2.56; 10,000 → 2.71 (ahead from ~6.5 d; +0.10 at 8 d); 30,000 → 2.78 (behind until ~3 weeks) | Lepidoptera now pay for themselves through the growth rate, on any run that matters. Raise the target to 10,000 once a run is meant to last more than about a week. Before the first ascension, 4,000 is fine: more only shifts when the ascension can happen by about 2 h. |
| House of Mirrors from nexus 5, whatever the run length | swarmwarp instead: +0.15/day vs +2.56/day | Mirrors are right on every run, short ones included, when the goal is mutagen. The handoff's "about 25× worse meat on runs under 2 to 3 days" is a meat-only effect. |
| Territory: 10% of larvae, nothing after mirrors start | f = 0 throughout: +0.20/day (collapse); 0.3: same as 0.1; stop after the first mirror: same | Keep it. Mirrors need a base of territory units to double. |
| Energy plan | n/a | Add an ascension reserve when an ascension is planned: keep casting mirrors until the cost is ≤ min(cap, 72,135 × N), then stop all energy spending and save. Crystals: convert to energy every visit; the cap gain is permanent. Never pay for a respec just before an ascension. |

## 5. What an ascension panel could show (proposal, not built)

Lines a player would see, with numbers the simulator gives around hour 70 to 84 from the 20 h save:

1. **Mutagen line, always shown once premutagen > 0:**
   `mutagen (inactive): 4.4e7, ×28/day · next expansion: +1.2e6 (spawns: yes)`
   - Rate: from the last 24 h of the premutagen count, or 1.12^(expansions per day).
   - "spawns: yes/no" is `upgrade('expansion').effect[1].outputNext().spawned`. The game computes it deterministically, so this is not a guess.
2. **Ascension line, before the first ascension:**
   `ascend: costs 71,270 energy (cap 108,000) · keep casting mirrors until ≤ 72,135, then save · ready in ~12 h · worth it if you'll play ≥ 5 more days after`
   - Once the cost is under the threshold, the energy line becomes `saving for ascension: 38% (12 h)`.
3. **Mutagen tab line, after an ascension:**
   `buy: unlock lepidoptera mutation (1) → 1,000,000 · unlock frequency (15,625) → 1,000,000 · keep 4.2e7 unspent (+4.2e6 larvae/s)`
   - With the nexus mutation owned it becomes: `no further ascension advised: nothing left raises the growth rate`.

**Game state it needs**, all readable from the `game` object:
- Units: `premutagen`, `mutagen`, `ascension`, `freeRespec`, each `mutant*` count, `energy` count, `capValue()` and `velocity()`, `crystal`, `nexus`.
- Upgrades: each `mutate*` upgrade's count and `totalCost()`.
- Ascension: `game.ascendCost()`, `game.ascendEnergySpent()`, the `mutagen` unit's `stat('ascendCost')`.
- Next premutagen: `upgrade('hatchery'|'expansion').effect[1].outputNext()`.
- `session.state.date.restarted` for run age, and the premutagen history kept by the advisor for the rate.
- Two settings from the player: **how long they plan to keep playing**, which decides line 2's "worth it" (§6), and whether to count crystals.

## 6. Questions for the owner

| Question | Why it matters | Findings that change |
| --- | --- | --- |
| **What is the goal?** Most mutagen (prestige), most meat or the next tier (progress), or achievements (an ascension is worth +10 points) | Objectives A and B agree on when to ascend and on the first unlock. They differ on the second unlock: frequency for mutagen, meat or hatchery for meat (10^3 at 6 d). | #4's second pick; the break-even (4.7 vs 6.2 d) |
| **How many more days will you play?** | The whole case for ascending rests on playing at least 5 to 6 more days after it. Under that, never ascending wins. | #3, and whether line 2 says "ascend" at all |
| **How often do you check in, and how long are you away?** | Crystals scale with visits: 500 per visit, at most one per 30 min. The energy cap (58,500 to 108,000) holds 18 to 30 h of energy, so mirrors can be cast in batches without loss. | #7: the ascension is about 14 h later without crystals, and growth is 20% lower; the break-even moves accordingly |
| **How long are you willing to let a run go?** | After the first ascension the best run is open-ended. If you would rather restart periodically anyway, that costs about 10^8 per restart (§4.4). | #5, #6c |
| **Will you respec?** You have 4 free ones. | A free respec could undo a poor unlock order at no cost; a paid one wipes the ascension discount. | Only matters if the first unlocks were already bought differently |
| **Which time zone does your browser use?** | Only for predicting individual rolls exactly; the mean is within 0.3 log10. | Line 1's "spawns: yes/no" if computed outside the game |
| **Do you buy crystals with money or only earn them?** | Bought crystals are more energy: an earlier ascension and faster growth. | #3 timing, #7 |

## 7. Not verified, not modelled, inferred

- **One save, one simulator.**
  - All strategy numbers start from the 20.1 h save and follow the tuned policy at one check-in per minute.
  - A person's next run will reach nexus 5 later than the simulator's (about a day), so the break-evens are probably 1 to 2 days longer.
  - The *shape* follows from the mechanics (growth rate = energy income) and is the more reliable part.
- **Policies not re-tuned for run 2 or later:** climbing, twins, territory share, nexus timing. Lepidoptera and age multiple were spot-checked (§4.5); nothing else was.
- **Spells.**
  - The clone, warp and bat mutations were verified mechanically, but their strategic use is unexplored, because the policy never casts clone larvae or swarmwarp.
  - A strong warp mutation (×11 at 10^6) makes swarmwarp skip about 2.75 h per 2,000 energy. It gives no energy, so it cannot raise the growth rate, but it was not tested as a supplement.
- **Long horizons.** Beyond about 2 to 3 weeks in one run the simulator overflows floats. Whether anything slows premutagen growth there (it should not: costs and doubling stay geometric) was inferred, not run.
- **Crystals.**
  - Modelled as an upper bound (every 30 min).
  - Crystals bought with money are not modelled.
  - The cap gain from crystal energy persists across ascensions; that is modelled.
- **Not exercised:** the browser build, the AngularJS views and the statistics service. The ascension achievements were checked through the achievement listener in Node.
- **Inferred, not measured:** that the per-mirror premutagen gain (×1.092) holds at any run age. It held from 1 to 14 days here.

## 8. Reproduce

```sh
cd advisor/modelcheck && npm install && cd ../..                 # once; node on PATH (Node 22 used)
python3 -I advisor/modelcheck/ascension_compare.py              # game vs sim, about 15 s; also advisor/modelcheck/out/ascension_compare.md
python3 -I advisor/sim/ascension_strategy.py                    # all strategy tables, about 40 s
python3 -I advisor/sim/ascension_strategy.py curve timing       # just 4.2, about 10 s
# unchanged-by-default checks:
(cd advisor/sim && SAVE=example_save_14h.json python3 -I run_example.py 52124)
python3 -I advisor/modelcheck/compare.py; python3 -I advisor/modelcheck/compare.py --save advisor/sim/example_save_20h.json
```

New in `sim.py`; with a save that holds no mutagen, every default is behaviour-neutral:

| Item | What it does |
| --- | --- |
| `PREMUT` | `'expected'` (default) / `'exact'` / `None` |
| `SEED_TZ` | time zone for the exact roll |
| `CRYSTALS` | or policy key `crystals` |
| policy key `ascend` | a list, one entry per future ascension: `{'after': run age in s}` |
| policy key `hatch_dyn` | hold hatchery mutants at the larva-maximising count |
| `ascend(s, p, plan)` | performs an ascension |
| `apply_plan(s, plan)` | spends mutagen; plan = `{'unlock': [...], 'buy': {mutant: count or share}}` |
| `asc_cost(s)` / `espent(s)` | the ascension cost and the energy spent |
| `premut_roll(s, name, level)` | the premutagen a level gives |
| `run_cycles(p, ci, hours, plans, s0, every, until)` | plays across ascensions and returns per-hour rows |
