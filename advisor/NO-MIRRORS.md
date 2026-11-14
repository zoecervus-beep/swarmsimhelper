# Every achievement without House of Mirrors

Nov 14, 2026. The question: can the owner earn every achievement without ever casting House of Mirrors (`clonearmy`), and if so how, and how long does it take? The existing plan ([ASCENSION.md](ASCENSION.md), part A) uses mirrors and takes about 175 simulator days.

This is analysis only. Nothing in the game or the advisor changed, and the advisor does not follow this route. Every strategy number comes from the simulator (`advisor/sim/sim.py`), started from the owner's 20.1 h save with no crystals, as in ASCENSION.md. The mechanics it leans on were checked against the game's own code (last section). Grades: **solid** (follows from the game's code or arithmetic, or measured in it), **likely** (simulator, robust across the variants tried), **guess**.

> **Pass 2 (later on Nov 14, 2026): the headline moved, and the route is now faster than the mirrors plan.** Sections 1–10 are the first pass and are kept as they were. They simulated swarmwarp the way the advisor would have handled it:
> - every timer (the 60 s cooldown, the purchase share, the release of the lower tier's stock, the run age behind the climb horizon) measured on the wall clock;
> - every affordable warp cast back to back, with no purchases between them.
>
> A warp skips days to years of production but moves no clock, so that wasted most of each warp. With the advisor counting a warp as the time it skips, and the player buying between warps (sections 11–13), the specified route takes:
>
> | Cadence | Swarmwarp route, pass 2 | Mirrors route, same driver | Swarmwarp route, pass 1 |
> | --- | --- | --- | --- |
> | ideal | **141** | 174 | 223 |
> | human | **154–158** | 181 | 245–253 |
> | busy | **198** | 193 | 366 |
> | twice a day | **243** | – | never |
>
> The trough (mutagen 1e15 → 1e32) shrinks from about 80 days to about 34. The rules for the advisor, route switching and the reference cases are in sections 11–15.

## 1. The verdict

| Subset | Without mirrors? | Simulator days from the save (once every 5 minutes) | A person's cadence ("human", 2 seeds) | With mirrors (ASCENSION.md) |
| --- | --- | --- | --- | --- |
| **Every achievement** | **Yes**, if all energy goes into **swarmwarp** | **223** | **245 to 253** | ~175 |
| Every achievement except "manifest destiny" (5,000 expansions) | yes | 186 | 204 | ~175 (20 ascensions are its last) |
| Every achievement except the expansion ones (500 and up) | yes | 186 (1e62 endless is the last) | 204 | ~175 |
| Everything, but no swarmwarp either (larva rush, clone larvae, territory rush or lepidoptera as the energy sink) | **No.** 39 to 52 achievements stay out of reach, by decades or more at the measured rates (section 4) | – | – | – |

**In plain words.**
- Mirrors are not required. A route that never casts them earns every achievement in about **7.5 months** at the simulator's pace. The mirrors plan takes about 6 months, so this is about 7 weeks longer; with a person's cadence it is about 2.5 months longer.
- The route replaces mirrors with **swarmwarp** and a **loop across ascensions**:
  1. Unspent mutagen makes larvae.
  2. Larvae make meat.
  3. Meat buys hatcheries, which pay premutagen, and with **territory empower** meat also buys expansions.
  4. Swarmwarp, made strong by the **warp and bat mutations**, multiplies every run's production. That tips the loop into compounding: mutagen grows from about 1e7 to 1e270 over 27 ascensions.
  5. The last run starts with so much mutagen that it reaches 5,000 expansions in 5 days.
- **The cost is not only time.** The route has 27 runs instead of 20, and every run needs climbing. It is much more sensitive to how often you look:
  - "human" (sessions with the panel open): 245–253 days;
  - "busy": 366 days;
  - "glance+": 320 days;
  - twice a day: it never reaches arch-mind within 418 days.

  The mirrors plan, by contrast, is energy-bound and barely moves with cadence.
- **Swarmwarp is cast about as often as mirrors would be:** about one cast per 1,100 seconds of energy, against one per 1,250. If mirror-spamming is what is dull, this route is equally spammy. If the objection is that mirrors are an exploit, swarmwarp is a time skip, and the route depends on it just as much (section 4: without it, the route fails).
- **Hybrid.** The least use of mirrors that keeps the existing plan's ~175 days is **one run: the long run** (section 6). Run 1 and the 18 quick runs can cast swarmwarp instead with no loss. Mirrors in any other single run do not help.

## 2. Which achievements House of Mirrors actually gates

The save has 73 achievements left (ACHIEVEMENTS.md). Here is what each group needs without mirrors, and when the no-mirrors route earns it (simulator days from the save, base route):

| Group | What it needs | Gated by mirrors? | No-mirrors route |
| --- | --- | --- | --- |
| Nexus 5 | Buy nexus 5 | no | day 0.4 |
| Territory units, 1e15 bought each (11) | Larvae ~1e15 / 2^twin. Twins count, empower does not matter (units *bought* count) | no | days 9–15 (all 11). Buy each one deliberately; the simulator does it in passing |
| Ascensions 1, 3, 5, 10, 20 | Energy spent and held per run (cost formula, ASCENSION.md B2.2). **Any** energy spent counts: every spell, lepidoptera, nightbugs, bats, nexus | **no**: swarmwarp spends energy exactly as mirrors do | 5, 17, 49, 129, **178** |
| Mutation unlocks 1, 3, 6, 10 | Mutagen: 1 / 15,626 / 9.3e20 / 5.6e37 in all | **yes, indirectly.** Mutagen comes from hatcheries (≈ meat^0.098) and expansions (1.12^L), and both stall without mirrors unless swarmwarp compounds | 5, 11, 81, **134** |
| Meat tiers up to 1e62 endless (45) | Units bought. Endless has no twin, so **1e62 endless needs 1e62 larvae** over all runs. Larvae come from expansions (1.1^L) or unspent mutagen (0.1 each) | **yes, indirectly** (larvae) | first endless 181, 1e62 endless **186** |
| Expansions 100, 200 | Territory 10^40, 10^79 in all | no | 2, 14 |
| Expansions 500, 1,000, 2,000 | Territory 10^196, 10^390, 10^780 | **yes** without empower; reachable with empower and large mutagen | 106, 150, 182 |
| **Expansions 5,000** ("manifest destiny") | Territory **10^1947 in one run** | **yes**: the hardest, and the last to fall | **223** |
| Events, secrets | done in this save | – | – |

The territory mutation is listed in ASCENSION.md as negligible. That holds for the mirrors plan, but not here. It is `1 + 0.001 n^0.2`, a power law: ×2 at 1e15 mutants, ×10^17 at 1e100, ×10^47 at 1e250. With the mutagen this route ends with, it adds roughly 10^50 territory income in the last runs. Without it, the last run stalls about 10 expansions short of 5,000 (route table: "territory mutation 0") unless it starts from more mutagen. **solid** (formula, checked in the game at 1e330); its role **likely**.

## 3. The bounding arguments

### 3.1 Inside one run, expansions stall without mirrors (solid)

Expansion L costs 10 × 2.45^L territory, so 5,000 expansions need 10^1947 territory in one run. With mirrors, each cast doubles every territory unit, so territory income doubles and the run gains 0.774 expansions per cast, about 52 a day. Nothing else doubles territory income repeatedly. Without mirrors, territory income is:

  units bought (≤ larvae spent × 2^territory-twin) × production per unit,

where production per unit is at most goon's (0.07 × 45^10) without empower, or ∝ meat^0.623 per larva with empower (each rung costs 450× the meat for 45× the territory). The loop back from expansions is weak:
- an expansion multiplies larvae by 1.1, but costs 2.45× the territory of the one before;
- larvae buy territory at most linearly, and meat follows larvae as a power law (3.2).

So territory income grows like a power of time, and expansions like its logarithm. Measured, from the mirrors plan's first ascension (mutagen 6e7), with all energy in each other spell instead (`nomirrors.py stall`):

| Energy spent on | Expansions day 10 / 20 / 40 | log10 larvae/s day 40 | log10 meat/s day 40 | Top tier day 40 |
| --- | --- | --- | --- | --- |
| House of Mirrors (the existing plan) | 470 / 996 / 2,047 | 89.9 | 759 | universal cortex |
| swarmwarp, empower off | 87 / 89 / 91 | 7.3 | 87 | neuroprophet |
| larva rush, empower off | 87 / 88 / 90 | 7.3 | 85 | neuroprophet |
| territory rush, empower off | 89 / 91 / 93 | 7.4 | 83 | neuroprophet |
| clone larvae, empower off | 87 / 88 / 90 | 7.3 | 88 | neuroprophet |
| meat rush, empower off | 87 / 88 / 90 | 7.3 | 83 | neuroprophet |
| swarmwarp, empower on | 163 / 178 / 188 | 11.3 | 96 | hive neuron |
| no spells, empower on | 138 / 167 / 179 | 11.0 | 91 | hive neuron |

**Arithmetic.**
- Best case, empower on: about +12 expansions per doubling of run length, about 40 per tenfold.
- The 4,800 missing levels would therefore need a run about **10^120 times** longer than 40 days.
- With mirrors it is 96 days.

So a single long run without mirrors cannot reach 5,000, or even 500, on any human timescale, whatever the spell, unless it starts with enormous mutagen (3.2). This is why the existing plan needs mirrors in its long run. It is also why the other spells do not change the picture inside one run: each multiplies larvae, territory or time by a factor fixed by its power. That is worth a fixed number of expansions, not a rate.

### 3.2 Across ascensions: unspent mutagen and the break-even loop (likely)

What a run *can* turn into an exponential is the mutagen it starts with:
- Unspent mutagen makes **0.1 larva/s each** (ASCENSION.md B2.4), outside every multiplier.
- Measured over 8-day runs, the simulator's climb turns larvae L/s into **meat ≈ L^10**. log10 meat/s ÷ log10 larvae/s is 10.05 at 1e256 mutagen and 10.3 at 1e128; it is lower at small mutagen, where the climb does not reach the top tiers.
- Hatchery level H costs 300 × 10^H meat and pays premutagen ≈ 1.2544^H, so premutagen ≈ **meat^0.098**.
- Chained together: **premutagen ≈ M^0.99**, almost exactly break-even per run.

The details (time, spells, the frequency and meta-mutations) decide whether mutagen grows or shrinks from one ascension to the next. One 8-day run without spells (`nomirrors.py transfer`):

| log10 mutagen at the start | Empower off: expansions | log10 premutagen | Empower on: expansions | log10 premutagen | log10 meat/s | log10 larvae/s |
| --- | --- | --- | --- | --- | --- | --- |
| 8 | 86 | 7.3 | 135 | 7.8 | 67 | 8.9 |
| 16 | 110 | 10.8 | 182 | 11.0 | 91 | 14.7 |
| 32 | 166 | 24.9 | 437 | 24.7 | 232 | 30.7 |
| 64 | 279 | 60.1 | 1,064 | 60.0 | 586 | 62.7 |
| 96 | 392 | 88.3 | 1,581 | 88.1 | 870 | 94.7 |
| 128 | 506 | 131.6 | 2,347 | 131.5 | 1,310 | 126.7 |
| 256 | 958 | 255.1 | 4,597 | 254.9 | 2,560 | 254.7 |

- **Without spells there are two regimes.**
  - Below about 1e100 mutagen a run earns less premutagen than the mutagen it started with. Longer runs add only 1–5 log10 per tenfold of run length (4 to 64 days at 1e16: 10.5 → 13.4).
  - Mutagen accumulates (what a run brings is added to what you hold), so it still creeps up, but linearly. From 1e13, each 64-day run adds about 10^13.
  - Getting to the 9.3e20 that six unlocks need would take about 10^8 runs; to the ~1e60 that 1e62 endless needs, far longer. That is far beyond a human lifetime.
  - Above about 1e100 it compounds by itself. The start is far below that.
- **Expansions scale with log10 M:** about 3.7 × log10 M without empower (capped by goons) and about **18 × log10 M with empower**. **5,000 expansions need a run that starts with about 1e250–1e270 mutagen**, with empower and the territory mutation.

### 3.3 What tips the loop: swarmwarp with the warp and bat mutations (likely; mechanics solid)

Swarmwarp skips 900 × power seconds of everything except energy (the game's second effect takes the skipped energy back). Its power is:

  bats (up to ×1.6) × the bat mutation (log, ≈ log10 n) × the warp mutation (log, ≈ 2 log10 n).

It therefore grows with the mutagen held. Each cast (2,000 energy, about one every 1,100 s) skips:
- about 6 days of production at 1e16 mutagen (power 567);
- 4 months at 1e64 (10,842);
- 5 years at 1e256 (180,968).

The other spells' powers grow the same way, but they multiply one input (larvae or territory) instead of all production. Measured, log10 premutagen after a run started with 10^M mutagen, 10% of it in the bat mutation and 10% in the spell's own mutation, 2,000 bats:

| Spell | Spell power at log10 M = 16 / 32 / 64 / 96 | log10 premutagen after 4 days | after 16 days |
| --- | --- | --- | --- |
| **swarmwarp** | 567 / 2,558 / 10,842 / 24,860 | 14.2 / **33.9 / 70.0 / 109.5** | **18.3 / 37.2 / 74.1 / 115.0** |
| larva rush | 840 / 3,816 / 16,220 / 37,225 | 10.4 / 25.3 / 58.5 / 84.5 | 11.1 / 26.8 / 61.3 / 87.5 |
| clone larvae | 512 / 2,306 / 9,767 / 22,387 | 9.8 / 24.0 / 50.9 / 82.8 | 12.8 / 25.7 / 53.1 / 86.0 |
| territory rush | 3,575 / 16,396 / 69,996 / 160,869 | 9.8 / 23.9 / 50.9 / 82.8 | 10.9 / 25.7 / 53.1 / 85.9 |

**Only swarmwarp earns more than the run started with (bold)**, from about 1e10 up, given a long enough run. The ranking for this goal is therefore:
1. swarmwarp, far ahead;
2. clone larvae and larva rush, both below break-even;
3. territory rush and meat rush.

The earlier studies ranked swarmwarp and clone larvae as runners-up to mirrors, under another objective. For this goal the gap between swarmwarp and the rest is the whole answer.

How long each run should be depends on the mutagen held. Growth of log10 mutagen per day, by run length (`transfer`; these runs use the pass-4 rules with lepidoptera 30,000):

| log10 M | warp power | 4 d | 6 d | 8 d | 12 d | 16 d | 24 d | 32 d | Expansions in 8 d |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 7 | 15 | 0.039 | **0.053** | 0.046 | 0.034 | 0.027 | 0.020 | 0.016 | 189 |
| 10 | 189 | 0.009 | 0.015 | 0.015 | 0.013 | **0.018** | 0.015 | 0.012 | 212 |
| 12 | 293 | 0.001 | 0.002 | 0.011 | **0.013** | 0.012 | 0.009 | 0.012 | 240 |
| 16 | 567 | 0.000 | 0.000 | 0.001 | 0.008 | **0.009** | 0.007 | **0.009** | 275 |
| 24 | 1,383 | 0.002 | 0.004 | 0.005 | 0.005 | 0.004 | **0.008** | 0.007 | 431 |
| 32 | 2,558 | 0.014 | **0.017** | 0.015 | 0.012 | 0.009 | 0.007 | 0.005 | 628 |
| 64 | 10,842 | **0.022** | 0.019 | 0.016 | 0.012 | 0.009 | 0.007 | 0.005 | 1,278 |
| 128 | 44,613 | **0.036** | 0.027 | 0.021 | 0.015 | 0.011 | 0.008 | 0.006 | 2,681 |
| 256 | 180,968 | **0.018** | 0.014 | 0.011 | 0.008 | 0.006 | 0.004 | 0.003 | **5,013** |

- **Below about 1e10:** short runs.
- **From 1e12 to 1e32 (the "trough"):** runs of 12 to 32 days. Growth is slowest here, about 1% of log10 M a day, and this stretch takes half the route.
- **Above 1e32:** runs as short as the ascension allows, about 4–6 days (the energy for the ascension is the limit), each multiplying log10 M by 1.1–1.15.
- **At 1e256 one run reaches 5,000 expansions in 6–8 days.**

## 4. Without swarmwarp as well

The same route with another energy sink (`nomirrors.py nowarp`, 400 days):

| Energy sink | 20 ascensions (day) | log10 mutagen at day 400 | Most expansions in a run | Achievements never earned |
| --- | --- | --- | --- | --- |
| larva rush | 120 | 9.5 | 179 | 43: 6 and 10 unlocks; expansions 200 to 5,000; neuroprophet 1e18 (the third neuroprophet one) and every tier from hive neuron 1e10 up |
| clone larvae | 120 | 10.8 | 201 | 39: 6 and 10 unlocks; expansions 500 to 5,000; hive neuron 1e20, and every tier from neural cluster 1e11 up |
| territory rush | 120 | 9.4 | 167 | 43, as larva rush |
| lepidoptera only (no spell) | 120 | 8.2 | 136 | 52: as larva rush, plus neuroprophet 1e9, hive neuron 1, hive empress 1e16 and six territory 1e15 ones (the larvae went to lepidoptera; the territory ones only need a deliberate purchase) |

- Mutagen stays at 1e8–1e11, where every run earns less than it holds (3.2).
- The missing achievements need 9.3e20 mutagen (6 unlocks), larvae of 1e20+ per second (the upper tiers), or expansions that grow with log10 M. At the measured creep (+10^10 to 10^13 per run, added linearly) they are out of reach **by decades to geological times**.
- **Verdict for "no mirrors and no swarmwarp": all but about 40 achievements, and those take longer than a human lifetime.** **likely**: the policy is not tuned for this case, but closing a gap of 10^10 to 10^50 would need a mechanism, not tuning.

## 5. The no-mirrors route (simulated)

### 5.1 What to do

| Step | What |
| --- | --- |
| Energy | **All of it into swarmwarp**, every visit, after nexus 1–5 and 4,000 lepidoptera. **Do not raise lepidoptera to 30,000:** that costs 300,000 energy in every one of ~27 runs (223 vs 267 days). Buy **2,000 bats** each run (0 bats: 281 days; 6,000: 377). |
| Territory | Territory share 0.1 as now, **and empower**: the advisor's existing empower rule, which is the simulator's option `empower` (off: no expansion above 500 within 300 days). |
| Climb | The long-run climb rules (ASCENSION.md A.10.2, pass 4), as they are. |
| Mutations, at every ascension | Unlock **lepidoptera ("nexus"), warp, bat** first (costs 1, 15,625, 2.44e8, in that order or any order), then frequency, meta-mutation, territory. Then rush, clone, meat, hatchery, only when the unlock costs at most 30% of the mutagen held; they are needed only for "unlock 10". Each ascension buy: lepidoptera mutation +1e6, frequency +1e6, **10% of the mutagen in warp, 10% in bat, 30% in territory, 1% in meta-mutation**; keep the rest unspent (larvae). |
| Run length | By the mutagen held after the ascension: **below 1e10, 6 days; 1e10 to 1e32, 16 days; from 1e32, ascend as soon as the energy allows** (about 4.5–6 days). Then, at least 20 ascensions done and **from 1e250, do not ascend: that run goes to 5,000 expansions** (about 5 days). |

### 5.2 Result (simulator, once every 5 minutes)

Day of the route (from the save) on which each milestone falls (`nomirrors.py route`):

| Variant | 20 asc. | 6 unlocks | 10 unlocks | endless 1 | endless 1e62 | exp 500 | exp 1,000 | exp 2,000 | exp 5,000 | Ascensions | All done |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **base** (5.1) | 178 | 81 | 134 | 181 | 186 | 106 | 150 | 182 | **223** | 27 | **223** |
| lepidoptera 30,000 from run age 3 d (as the mirrors plan) | 189 | 97 | 154 | 223 | 229 | 122 | 176 | 224 | 267 | 33 | 267 |
| lepidoptera 1,000 | 198 | 97 | 156 | 213 | 219 | 124 | 171 | 214 | 256 | 28 | 256 |
| lepidoptera 10,000 | 176 | 81 | 134 | 183 | 189 | 105 | 150 | 184 | 224 | 28 | 224 |
| final run from 1e200 | 178 | 81 | 134 | 181 | 186 | 106 | 150 | 182 | – (stalls ~4,400) | 25 | – |
| final run from 1e280 | 178 | 81 | 134 | 181 | 186 | 106 | 150 | 182 | 223 | 27 | 223 |
| runs 12 days in the trough | 165 | 89 | 135 | 184 | 189 | 111 | 148 | 185 | 244 | 29 | 244 |
| runs 24 days in the trough | 195 | 89 | 142 | 187 | 192 | 109 | 158 | 188 | 228 | 25 | 228 |
| runs of 16 days throughout | 319 | 95 | 159 | 273 | 289 | 120 | 178 | 258 | 356 | 22 | 356 |
| short runs from 1e24 (not 1e32) | 155 | 81 | 130 | 179 | 185 | 109 | 147 | 180 | 238 | 30 | 238 |
| all ten unlocks as soon as affordable | 178 | 81 | 134 | 186 | 191 | 105 | 150 | 182 | 223 | 27 | 223 |
| territory mutation 0 | 178 | 81 | 134 | 181 | 186 | 107 | 150 | 182 | – (stalls ~4,990) | 26 | – |
| territory mutation 0, final run from 1e280 | 178 | 81 | 134 | 181 | 186 | 107 | 150 | 182 | 223 | 27 | 223 |
| bats 0 | 213 | 113 | 182 | 237 | 243 | 143 | 200 | 238 | 281 | 31 | 281 |
| bats 6,000 | 190 | 97 | 248 | 323 | 333 | 123 | 278 | 325 | 377 | 48 | 377 |
| empower off (300 days) | 247 | 183 | 236 | 283 | 288 | 290 | – | – | – | 29 | – |
| **human cadence** | 183 | 81 | 140 | 198 | 204 | 109 | 159 | 201 | **253** | 28 | **253** |
| human cadence, seed 2 | 184 | 82 | 140 | 192 | 204 | 106 | 159 | 201 | 245 | 28 | 245 |
| busy cadence | 201 | 129 | 189 | 270 | 278 | 152 | 288 | 327 | 366 | 36 | 366 |
| glance+ cadence | 187 | 88 | 158 | 228 | 236 | 116 | 245 | 287 | 320 | 33 | 320 |
| twice a day | 128 | 379 | – | – | – | – | – | – | – | 47 | not by day 418 (stuck below arch-mind) |

The cadences are those of ASCENSION.md A.10 (`cadence.py`).

The base route, ascension by ascension:

| # | Day | Run length (d) | Expansions | Hatchery | log10 premutagen | log10 mutagen after |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 5.2 | 6.1 | 131 | 67 | 7.1 | 7.1 |
| 2 | 11.2 | 6.0 | 186 | 98 | 10.1 | 10.0 |
| 3 | 17.3 | 6.0 | 237 | 127 | 12.7 | 12.6 |
| 4 | 33.3 | 16.0 | 273 | 145 | 14.6 | 14.5 |
| 5 | 49.3 | 16.0 | 307 | 167 | 17.2 | 17.1 |
| 6 | 65.3 | 16.0 | 344 | 187 | 19.1 | 19.0 |
| 7 | 81.3 | 16.0 | 404 | 222 | 23.5 | 23.2 |
| 8 | 97.3 | 16.0 | 443 | 241 | 25.5 | 25.2 |
| 9 | 113.3 | 16.0 | 518 | 285 | 29.8 | 29.6 |
| 10 | 129.3 | 16.0 | 625 | 346 | 35.9 | 35.6 |
| 11 | 133.8 | 4.5 | 694 | 387 | 40.0 | 39.8 |
| 12 | 138.4 | 4.6 | 773 | 430 | 44.3 | 44.0 |
| 13 | 143.1 | 4.7 | 879 | 492 | 50.4 | 50.2 |
| 14 | 147.9 | 4.8 | 988 | 552 | 56.4 | 56.2 |
| 15 | 152.8 | 4.9 | 1,060 | 589 | 60.1 | 59.9 |
| 16 | 157.8 | 5.0 | 1,201 | 673 | 68.4 | 68.2 |
| 17 | 162.8 | 5.0 | 1,316 | 734 | 74.5 | 74.2 |
| 18 | 167.9 | 5.1 | 1,506 | 846 | 85.5 | 85.3 |
| 19 | 173.2 | 5.2 | 1,672 | 935 | 94.4 | 94.1 |
| 20 | 178.5 | 5.3 | 1,943 | 1,094 | 110.0 | 109.8 |
| 21 | 183.8 | 5.4 | 2,177 | 1,221 | 122.6 | 122.4 |
| 22 | 189.3 | 5.5 | 2,579 | 1,457 | 145.9 | 145.6 |
| 23 | 194.8 | 5.5 | 2,926 | 1,645 | 164.5 | 164.2 |
| 24 | 200.5 | 5.6 | 3,469 | 1,961 | 195.6 | 195.4 |
| 25 | 206.2 | 5.7 | 3,992 | 2,251 | 224.3 | 224.0 |
| 26 | 212.0 | 5.8 | 4,467 | 2,514 | 250.2 | 250.0 |
| 27 | 217.9 | 5.9 | 4,896 | 2,752 | 273.7 | 273.4 |
| last run | 222.9 | 5.0 | **5,030** | | | |

**Every achievement in the base route, by day from the save:**
- **Days 0–17:** hive 1e12 and nexus 5 (0); hive queens (1–2); empress (1–8); neuroprophet 1 and 1e9 (4–8); ascension 1 and the first unlock (5); hive neuron 1 (8); every territory 1e15 (9–15); 3 unlocks (11); expansion 200 (14); neuroprophet 1e18 (16); ascension 3 (17).
- **Days 47–120:** hive neuron 1e20 and neural cluster 1e11 (47); hive network 1 (48); ascension 5 (49); neural cluster 1e22 (71); hive network 1e12 and lesser hive mind 1 (73); 6 unlocks (81); hive network 1e24 (84); lesser hive mind 1e13 and hive mind 1 (100); expansion 500 and lesser hive mind 1e26 (106); hive mind 1e14 (115); arch-mind 1 (118); hive mind 1e28 (120).
- **Days 129–155:** ascension 10 (129); arch-mind 1e15 (131); overmind 1 (132); arch-mind 1e30 (133); 10 unlocks (134); overmind 1e16 (136); ascended 1, 1e19, 1e38 (141, 145, 155); overmind 1e32 (142); cosmic network 1 (150); expansion 1,000 (150).
- **Days 155–223:** cosmic network 1e22 and 1e44 (155, 165); galactic cluster 1, 1e25, 1e50 (162, 165, 171); universal cortex 1, 1e28, 1e56 (170, 176, 181); 20 ascensions (178); first endless (181); expansion 2,000 (182); endless 1e31 and 1e62 (186); **expansion 5,000 (223)**.

**Where the time goes.**
- The trough (1e12 to 1e32 mutagen, 16-day runs) takes **days 17 to 129**. That is half the route, and the part a better policy could most shorten (section 8).
- Above 1e32, each 5-day run multiplies log10 mutagen by about 1.1–1.2. 1e36 → 1e273 takes 16 runs and 89 days.

### 5.3 Against the mirrors plan

| | Mirrors plan (ASCENSION.md) | No-mirrors route |
| --- | --- | --- |
| Simulator, every 5 minutes | ~175 days (4 + 96 + 75–80) | **223 days** |
| "human" cadence | ~176–178 (the long run is 96–98 days at any cadence with sessions; the quick runs are energy-bound) | **245–253 days** |
| "busy" | ~180 (inferred: long run 98 days, quick runs energy-bound) | 366 |
| Runs | 20 | 27 |
| Climbing that matters | one long run | every run |
| Casts | ~6,400 mirrors in the long run (one per ~1,250 s of energy), plus a spell in the quick runs | roughly 13,000 swarmwarp over the route (estimated from the energy: one per ~1,100 s, less nexus, lepidoptera and bats each run) |
| Last achievement | 20 ascensions (or 5,000 expansions if the order is swapped) | 5,000 expansions |

## 6. Hybrids: the least use of mirrors

`nomirrors.py hybrid`. Days from the save:

| Mirrors used in | All done | Note |
| --- | --- | --- |
| **the long run only** (the existing plan; run 1 casts swarmwarp instead, the 18 quick runs any spell) | **~175** | Run 1 ascends on day 4.1 with only 1.6e6 mutagen, against 6e7 with mirrors. The long run is unchanged: first endless day 50, 1e62 endless day 62, 5,000 expansions day 96 (day 51 / 63 / 97 at the human cadence; ASCENSION.md: 50 / 62–63 / 96). The quick runs need energy spent, and any spell spends it. |
| run 1 only, then the no-mirrors route | 251 | no help |
| no mirrors until 20 ascensions (mutagen 1e64 or 1e32), then one last run with mirrors to 5,000 expansions | 264 | worse than no mirrors: that run still needs ~5,700 casts (86 days), while the no-mirrors route's last 45 days do it |
| the same, switching at 1e128 | 272 | worse |
| none | 223 | section 5 |

So mirrors are close to all-or-nothing:
- **One mirror run, the long run, ~96 days and ~6,000 casts**, gives the 175-day plan.
- **No mirror run at all** gives 223 days (253 for a person) with swarmwarp.

There is no cheap middle, because the expansion count resets every run: a run with mirrors starts from 0 expansions whatever came before. In the quick runs of the existing plan, swapping mirrors for swarmwarp costs nothing. **likely** (long-run simulation; the quick-run claim follows from the cost formula, ASCENSION.md A.5).

## 7. Grades: what is measured and what is inferred

| # | Finding | Grade | Basis |
| --- | --- | --- | --- |
| 1 | Swarmwarp, larva rush, territory rush, meat rush and clone larvae, with the bat / warp / rush / clone mutations at 1e200, a 1e8-second warp, empower at levels 40 and 60, mutagen larvae at 1e350, the territory mutation at 1e330: the simulator matches the game | **solid** | measured in the game's code, 48 numbers, worst 1.7e-6 (section 9) |
| 2 | Inside one run, without mirrors, expansions grow with the logarithm of time; 5,000 (and even 500) is out of reach in any single run that starts with little mutagen | **solid** | the cost arithmetic, plus the stall table (every spell, empower on and off) |
| 3 | 20 ascensions do not need mirrors: any spent energy lowers the cost | **solid** | the cost formula (game code, ASCENSION.md B2.2) |
| 4 | Across ascensions premutagen ≈ M^0.99 per run (meat ≈ larvae^10, premutagen ≈ meat^0.098): break-even, decided by the details | **likely** | the exponents are measured in the simulator, not derived |
| 5 | Swarmwarp with the warp and bat mutations is the one alternative that compounds; the other spells and no spell stall at 1e8–1e11 mutagen | **likely** | transfer runs and 400-day routes |
| 6 | Every achievement without mirrors in **~223 simulator days** (245–253 at the human cadence) | **likely** that it is feasible in about 7–9 months; the exact days are a **guess** (one start, one policy family, a route tuned over ~20 variants) | simulator only |
| 7 | Cadence matters much more than in the mirrors plan (busy 366, glance+ 320, twice a day fails) | **likely** | |
| 8 | Lepidoptera 4,000 to 10,000, 2,000 bats, empower on, territory mutation 30% | **likely** | route variants |
| 9 | Hybrid: mirrors only in the long run gives the full ~175-day plan; mirrors elsewhere do not help | **likely** | long run simulated from a swarmwarp first ascension; quick runs by formula |
| 10 | Without mirrors and without swarmwarp: about 40 achievements stay out of reach for decades or longer | **likely** | |

**Simulator-only:** every number of days, the run-length schedule, the 1e250 threshold for the last run, and the exponent 10.

## 8. Not modelled, not verified

- **The policy** is the long-run climb (pass 4), designed for a mirrors run, plus swarmwarp as the energy sink.
  - It was not re-tuned for runs where each check-in follows days of skipped production.
  - Twenty route variants were tried; nothing was optimised jointly.
  - The trough (1e12–1e32) is where a better policy could save the most. Some single changes moved the end by ±20 days.
- **The mean premutagen roll** (`PREMUT='expected'`). The game rolls (±10% on quantity, a 20–100% chance per level). In the trough, where each run is close to break-even, an unlucky stretch could cost a run or two. Not tested with the exact roll.
- **One start** (the 20.1 h save), one random schedule per cadence (two for "human"), perfect execution of each visit's suggestions.
- **The advisor** does not show this route:
  - its energy line suggests mirrors, not swarmwarp;
  - its mutation advice is the mirrors plan's;
  - the run-length schedule and the final-run threshold are not in it.
- **Things the game might do differently at these sizes, not exercised:**
  - the browser's speed with 1e270 mutagen and meat around 1e2,800 (the unit cap of 1e100000 is far away);
  - swarmwarp casts of five years each, 30 to 80 times a day.
- **Crystals** are excluded throughout, as the owner chose. Crystal energy would shorten runs, since energy sets the swarmwarp rate.
- **Nightbugs** (energy cap) are not used. At the human cadence, energy lost to the cap was not measured for this route.

## 9. Checked against the game

`advisor/modelcheck/nomirrors_check.py` (with `nomirrors_check.js` and `nomirrors_state.json`) edits the 20.1 h save to the scale of the route's last runs:
- up to 1e600 of resources, mutagen 1e350, the territory mutation at 1e330, 1,500 expansions;
- nexus 5, 2,000 bats, 30,000 lepidoptera;
- the bat, warp, rush and clone mutations at 1e200 each;
- goon empower 60, spider empower 40.

It then compares the game and the simulator:

| Quantity | Game | Simulator |
| --- | --- | --- |
| swarmwarp power | 111,161.4 | 111,161.4 |
| swarmwarp: seconds skipped; energy debit | 1.000453e8; 1.968631e8 | same |
| larva rush (velocity and flat parts), territory rush, meat rush, clone larvae (cap) | e.g. 3.998467e357 larvae, 1.632256e1579 territory | same (territory to 1.7e-6) |
| every meat tier, meat, larvae, territory after one swarmwarp; energy 100,000 → 98,000 | e.g. drones 7.467541e445, overmind5 1.274225e81 | same |
| goon empower 60: territory each, meat cost, next price | 3.144202e1169, 3.368797e1780, 5.161932e1809 | same within 1.7e-6 |
| spider empower 40 | 3.673232e792, 3.935606e1175, 6.030450e1204 | same |

**48 numbers; worst |sim/game − 1| = 1.7e-6**, the known rounding of goon production in the game's table (MODEL-CHECK.md). Full table: `advisor/modelcheck/out/nomirrors_check.md`.

## 10. Reproduce

```sh
cd advisor/modelcheck && npm install && cd ../..                 # once, if node_modules is missing
python3 -I advisor/modelcheck/nomirrors_check.py                # game vs simulator at the route's scale, ~3 s
python3 -I advisor/sim/nomirrors.py --jobs 4                    # every table here, ~11 min on 4 cores
python3 -I advisor/sim/nomirrors.py route --jobs 4              # section 5 only, ~7 min (also: bound, stall, transfer, nowarp, hybrid)
```

**Changes to `sim.py`.** Two options, both off by default; with them off, every earlier result is unchanged (byte-identical outputs of `run_example.py` on both saves, `compare.py` on both saves, `ascension_compare.py` and `bignum_check.py`, before and after):

| Option | What it does |
| --- | --- |
| policy key `ascend_rule` | a function of the state that returns the ascension entry (`{'after': run age}` or None), so run length can follow the mutagen held |
| plan keys `unlock_max_share`, `unlock_free` | after the first `unlock_free` unlocks, buy an unlock only while it costs at most this share of the mutagen held |

Everything else (territory empower, spell powers, the mutations, ascension) was already in the simulator and checked.

## 11. Game time: what swarmwarp does to the clocks (measured in the game)

`advisor/modelcheck/swarmwarp_clock.js` runs the game's code. Starting from the 20.1 h save, edited to nexus 5, 2,000 bats and the warp and bat mutations at 1e10, it casts swarmwarp, exports and re-imports the save, casts again and ascends:

| After | `game.now` | `game.skippedMillis` | `session.state.skippedMillis` | `date.restarted` | swarmwarp count | drones | energy |
| --- | --- | --- | --- | --- | --- | --- | --- |
| loading | 22:18:19.823 | 0 | 0 | 02:11:33 | 0 | 1.38e28 | 58,500 |
| one swarmwarp (power 239.4, skip 215,460 s) | **unchanged** | 0 | **215,460,000** | unchanged | 1 | **6.70e36** | 56,500 |
| 60 s of wall time | +60 s | 0 | 215,460,000 | unchanged | 1 | 6.70e36 | +59 |
| export and re-import | – | 0 | **215,460,000** | unchanged | 1 | same | same |
| a second swarmwarp | unchanged | 0 | 430,920,000 | unchanged | 2 | 1.07e38 | 54,500 |
| ascending | – | 0 | **430,920,000 (not reset)** | the ascension | **0** | 0 | 0 |

What follows (**solid**: game code):
- A swarmwarp moves production forward by its skip but **no clock the advisor reads**. `game.now` and the run's dates stay on the wall clock. `game.skippedMillis` is 0 again after the cast's reify.
- **`session.state.skippedMillis` is the cumulative time skipped over the whole save.** It survives a reload and is not reset by an ascension.
- So the **game clock** is: wall now + `session.state.skippedMillis`. It is monotonic, exact, and needs no memory.
- **The game time of this run** is: wall run age + skipped since the run began. The game does not store the skipped time at the run's start. The port can either:
  - record `skippedMillis` when it sees an ascension, or
  - use the stateless estimate: this run's `swarmwarp` upgrade count × the current skip (900 × power). The upgrade count is reset at an ascension.

  The estimate is exact whenever power has not changed during the run since the first cast. On this route the bats are bought before the first warp (rule E3), and the mutations do not change within a run. The reference cases check the estimate against the game.

## 12. Rules for the advisor: the swarmwarp route

A selectable route, beside today's mirrors route ("achievements route", ASCENSION.md part A). Everything below is the reference implementation in `advisor/sim/warp_route.py` (`stage`, `ascension_test`, `wants_ascension`, `mutagen_steps`, `respec_advised`, `policy`). Each rule reads the game state only, so it gives the same advice after a reload or a route switch. Anything not mentioned is today's advisor unchanged.

### 12.1 The time base (all routes)

| Timed quantity | Clock | Why |
| --- | --- | --- |
| 60 s cooldown after a hatch (rule 3) | **game** | a warp is elapsed production: the tier below has grown by the whole skip |
| purchase share 1 − (1 − share)^(minutes since the last hatch) | **game** | same |
| release of the lower tier's stock, min(1, since / payback) | **game** | payback is measured in production seconds |
| push cooldown (LR-2), twin "used recently" | **game** | same |
| territory purse refill (share × larvae gained) | **game** | a warp's larvae are larvae gained |
| run age behind the climb horizon (age multiple × run age) and the long-run gate (LR-0, 2 days) | **game** (this run's game time; the estimate of section 11 is enough) | the horizon asks whether a tier pays back within the run's production time. Warps are production time. Measured: 206 → 141 days (below) |
| energy: rate, cap, "ready in" for the ascension, the just-in-time keep for nexus 5 | **wall** | a warp makes no energy (the game takes the skipped energy back) |
| lepidoptera, bats, nexus | no clock (counts) | – |
| the mirrors route's day-3 lepidoptera raise (LR-4) | wall | nobody warps on that route |

- **Use the game clock on every route.** On the mirrors route nobody casts swarmwarp, so `skippedMillis` does not move and the change is a no-op. The console-script comparison never casts a warp either.
- The purchase memory should store hatch times on the game clock. That memory starts afresh on a reload, as now.
- **No threshold is needed for a warp to "count".** Every warp skips 900 × power ≥ 900 s, more than the 60 s cooldown, so on the game clock every warp releases every cooldown and the full share (1 − 0.5^15 or more).

Measured (days to every achievement, from the save):

| Variant | Ideal | Human | Busy | Twice a day |
| --- | --- | --- | --- | --- |
| wall clock, warps back to back (the advisor today, as pass 1 simulated it) | 217 | 231 | 350 | not by day 426 |
| game clock for the timers, one warp at a time, run age on the wall clock | 206 | 211 | – | – |
| **game clock for the timers and the run age, one warp at a time (the spec)** | **141** | **158** | **198** | **243** |

### 12.2 Energy

| Rule | Quantity | Test | The player is told |
| --- | --- | --- | --- |
| **E1. Below nexus 5** | A.11's plan, unchanged: save for the next nexus; 1,000 lepidoptera first at nexus 4; the just-in-time keep for nexus 5 | as now | as now |
| **E2. Lepidoptera after nexus 5** | **10,000 in every run** (the setting, if higher, stays). Not the mirrors route's per-stage targets (10,000 / 30,000 / 4,000 → 30,000 from day 3) | as now (`buyMoths`) | "lepidoptera n/10,000 (swarmwarp route)" |
| **E3. Bats** | **2,000**, after the lepidoptera target and before the first swarmwarp, every run | at nexus 5, lepidoptera ≥ target, bats < 2,000: floor(min(2,000 − bats, spare / 100)) | "buy n bats (n/2,000): swarmwarp power ×1.4" |
| **E4. Swarmwarp** | every 2,000 energy above what E1–E3 and the ascension plan keep | always, except while saving for the ascension (12.6) | **one at a time**: "cast swarmwarp (k affordable): skips <900 × power>" (12.3) |
| **E5. Ascension coupling** | today's spend / save / ascend plan (`plan`, `coupleEnergy`), unchanged, when the route wants an ascension (12.6): spend until the cost ≤ min(cap, halving / ln 2), save, ascend | `wants_ascension` | as now: "stop spending energy and save …" |
| E6. Nightbugs | none | – | – |

Measured (days, ideal / human):

| Variant | Days |
| --- | --- |
| E1 A.11 plan below nexus 5 (spec) | 141 / 158 |
| E1 swarmwarp from nexus 1 instead | 145 / 162 |
| E2 lepidoptera 4,000 | 138 / 158 |
| E2 lepidoptera 10,000 (spec) | 141 / 158 |
| E2 lepidoptera 30,000 | 172 ideal |
| E3 bats 0 | 138 ideal |
| E3 bats 1,000 | 137 / 153 |
| E3 bats 2,000 (spec) | 141 / 158 |
| E3 bats 4,000 | 167 / 189 |

- **The bat count is flat from 0 to 2,000.** 4,000 is clearly worse, because 400,000 energy is not cast. No state dependence was found worth a rule; 2,000 is kept because the cases are made with it.
- **Energy lost at the cap:** 0 days per route at the ideal cadence, 1.0–2.1 days at human and busy, 3.9 days twice a day. Nightbugs are not worth a rule.

### 12.3 One warp at a time, and the purchases between warps

- **The rule.** With k ≥ 1 warps affordable, the advisor suggests **one** swarmwarp. After the cast, it re-advises everything with the game clock moved on by the skip, and only then suggests the next.
- **What is re-taken after each warp** (the simulator runs the whole non-energy part of the visit after each warp):
  - the climb (rule 3 sizing, now fully released) and the push (LR-2);
  - faster and twin upgrades;
  - territory units, territory twins and empower;
  - expansions, hatcheries and accomplished ancestry.

  Each warp makes days to years of meat, larvae and territory. In the `five_warps_affordable` case, the five warps bought 11, 16, 3, 6 and 1 expansions in between.
- **What the player is told:** "cast 1 swarmwarp (5 affordable), then follow the lines below; the next warp is suggested after them". **Never "cast ×N"** as for mirrors.
  - Mirrors double the territory units whatever was bought between casts.
  - A warp's value is in what is bought after it. Casting a stored-up batch back to back is what made pass 1 lose 70 to 90+ days.
- **Saving for the ascension:** no warps (E5), as for mirrors today.

### 12.4 Territory

- **Share 0.1 and the balanced unit choice, unchanged, and territory buying never stops on this route.**
  - The mirrors route's line "House of Mirrors is running: hatch no more territory units", and its "set the territory share to 0", are keyed on House of Mirrors casts this run. They must be off on this route, even when mirrors were cast in the run (a route switch).
  - When the share is 0 (left from that advice), the route says: "set the territory share to 0.1 (swarmwarp route: expansions come from territory units)".
- **Empower (confirmation for the owner): the simulations used the advisor's own rule.** `sim.empower_policy` is a port of `empowerAdvice`:
  - the cheapest rung by **live** meat cost is empowered;
  - it fires when its price + the top rung's meat cost × max(territory larvae, 1) fits the meat budget (0.9 × meat), and the units it wipes make under 1% of territory income;
  - one empower per look.

  The ladder and the balanced choice run over the units sorted by live meat cost (`sim.tcosts`), so an empowered swarmling ranks above goons ("wrap-around"), as in `ladder()`.
  - The one difference: the simulator's territory larvae are its purse, the advisor's are the territory share of the larvae on hand (`cap`).
  - The cases' `territory.empower_advised` uses the advisor's form.
  - Empower off: the route never passes 500 expansions (pass 1, section 5). **Empower is required on this route.**

### 12.5 The climb

- **The long-run climb mode on**, as specified in ASCENSION.md A.10.2 (pass 4): advisor sizing, the 1% push reserve, LR-3, banking, age multiple 5. The route was simulated with exactly that (`longrun_rules.SPEC4`, which has `advisor_sizing`, honest larvae and the reserve).
- The lepidoptera target comes from E2, not LR-4.
- The route should switch the mode on, or ask the player to.
- **With the game clock** (12.1) the gate opens at the first strong warp, and the horizon (5 × game run age) grows by years with the warps. Most tiers then pass the plain climb test, and the push matters less. That is the 206 → 141 days.

### 12.6 Ascension: stages and tests

The stage comes from the game state:

| Stage | Test | Advice |
| --- | --- | --- |
| **done** | `expansion9` (5,000 expansions), `overmind6_3` (1e62 endless), `mutation4` (10 unlocks) earned, and ascensions ≥ 20 | never ascend: "every achievement of the route earned" |
| **quick** | those three earned, ascensions < 20 | ascend whenever the energy allows (E5): "ascension n of 20" |
| **final** | log10 mutagen held ≥ **270**, and `expansion9` not earned | do not ascend: "final run: expansions x/5,000 (do not ascend)"; all energy into swarmwarp |
| **build** | otherwise | **ascend when premutagen ≥ 1,000 × max(mutagen held, 1)** (E5 then decides spend / save / ascend). Until then: "keep swarmwarping: mutagen (inactive) x / need y" |

- **Why a ratio, not a run length.** The pass-1 schedule (6 / 16 / 0 days by mutagen held) was in wall days. It is wrong for a player whose warps are stronger or weaker than the simulator's at the same point, and it waited 73 wall days after a switch (13). The ratio needs no clock: a run is ended when what it brings dwarfs what it started with.

  | Test (days to all achievements) | Ideal | Human | Busy |
  | --- | --- | --- | --- |
  | run age 6 / 16 / 0 days by mutagen held | 177 | 212 | 260 |
  | premutagen ≥ 10 × held | 165 | 186 | 242 |
  | premutagen ≥ 100 × held | 150 | 170 | 213 |
  | **premutagen ≥ 1,000 × held** | **141** | **158** | **198** |
  | premutagen ≥ 10^4 × held | 143 | 153 | 198 |

  Flat between 1,000 and 10^4, with an edge to 1,000 at the ideal cadence.
- **The first run:** held is 0, so the need is 1,000. The test passes at the first spawn (hatchery 40 brings ~9,000), and the run behaves like "ascend as soon as affordable".
- **The final threshold:** 5,000 expansions need a run started from about 1e270 (expansions ≈ 18.5 × log10 M). In the simulated routes a run starting at ~1e265 reached 5,000 before its own test passed, so 1e250–1e300 all gave 141. The threshold is the safety that stops a run near 5,000 from being ended.
- **No guard for a mirrors long run** (13): ascending out of one under this route's test was faster in every case simulated.
- Mutation achievements and the 20 ascensions come in the build stage (6 unlocks day 34, 10 unlocks day 58, 20 ascensions day 95).

### 12.7 Mutagen purchases (idempotent, on current holdings)

Shown whenever mutagen is held. Applied twice, the second time buys nothing. In order:

1. **Free respec, when advised.** All of these hold:
   - the warp mutation is not unlocked;
   - the next unlock costs more than the mutagen held;
   - a free respec is left;
   - held + refund ≥ 15,626 (the lepidoptera and warp unlocks).

   The refund is every unlock price paid (15,625^0 … 15,625^(n−1)) plus every mutant bought, minus the free mutant per unlock. A free respec keeps the energy credit (ASCENSION.md B2.6). This is the state after the mirrors route's first ascension: lepidoptera and frequency unlocked, so warp would be the 3rd unlock at 2.44e8 against ~6e7 held. Measured: 148 days with the respec, 181 without, 173 with a 16-day wall-clock backstop instead.

   Say: "respec (free, n left): the swarmwarp route needs the warp mutation, which you cannot afford as your 3rd unlock".
2. **Unlocks**, in the order lepidoptera, warp, bat, frequency, meta-mutation, territory, rush, clone, meat, hatchery, skipping those held.
   - The k-th costs 15,625^(k−1) (read from the game).
   - The first three unlocks: whenever affordable.
   - From the 4th: only while the price is at most 30% of the mutagen held. Unlocks 7–10 are only for "unlock 10".
3. **Lepidoptera and frequency mutations** up to 10^6 each (when unlocked), as far as the mutagen held goes.
4. **Shares.** Let W = mutagen held + the warp, bat, territory and meta-mutation mutants held (unlocked kinds only). Hold at least **10% of W in warp, 10% in bat, 30% in territory, 1% in meta-mutation**: buy each shortfall, as far as the mutagen held goes.
5. **The rest stays unspent** (0.1 larva/s each).

From the mirrors route's holdings (1e6 lepidoptera mutants, frequency unlocked) the rule gives: respec, then lepidoptera + warp unlocks, lepidoptera to 1e6, warp 10% of W (`switch_mirrors_purchases_made`). After the mirrors long run (all ten unlocked, 1e246 held): shares only.

### 12.8 Achievements the route collects, and what to say

- **Territory 1e15 bought, each unit (11):** they come by themselves in the first 2–3 weeks (pass 1: days 9–15). Today's territory lines suffice; a line naming any still missing would help.
- **Unlocks 1 / 3 / 6 / 10:** from 12.7 (days 4 / 8 / 34 / 58).
- **Endless:** cumulative. 1e62 bought on day 107, before the final run. Today's long-run line ("endless bought x/next") can show in the build stage.
- **Expansions:** single-run. 1,000 / 2,000 come in build runs (days 74 / 103), 5,000 in the final run (day 141).
- **20 ascensions:** day 95, in the build stage. There is no separate quick stage unless a player reaches 1e270 with fewer.

### 12.9 What the route changes in the existing advisor

| Behaviour | Mirrors route (today) | Swarmwarp route |
| --- | --- | --- |
| timers and run age | wall clock | game clock (12.1), on every route |
| spell from nexus 5 | House of Mirrors, "cast ×N" | swarmwarp, one at a time (12.3) |
| lepidoptera target after nexus 5 | 10,000 first run / 30,000 quick runs / 4,000 then 30,000 from day 3 in the long run | 10,000 every run |
| bats | none | 2,000 before the first warp |
| stages | firstRun / needMutation / longRun / quickRun / done | build / final / quick / done (12.6) |
| ascension test | first run, quick runs: as soon as affordable; long run: never | premutagen ≥ 1,000 × held; final: never; quick: as soon as affordable |
| mutagen line | lepidoptera, 1e6 of it, 1 more unlock, then all from the 2nd ascension | 12.7 (respec, order, 30% rule, shares) |
| territory once mirrors are cast | hatch none; set the share to 0 | never stops; restore the share to 0.1 |
| long-run climb mode | the player's setting | on |
| unchanged | A.11 below nexus 5, the spend / save / ascend plan, empower, the balanced unit choice, banking, push, LR-3 | |

**Conflicts with the advisor as it is:**
1. **The timers and the run age read `game.now`.** After a warp they say "done, next in 59 s" on a tier whose lower tier has just grown by years. That needs the game clock (12.1).
2. **`energyAdvice` returns `cast ×N` with N = spare / cost.** This route needs one at a time.
3. **`advisorAscension` works out its stage from the mirrors plan.** It would call a swarmwarp run with the lepidoptera mutation "longRun: do not ascend", and its mutagen line would unlock frequency second. Both must be route-dependent.
4. **`runMoths` raises the target to 30,000 in quick and long runs.** That costs this route 30 days (172 against 141).
5. **The territory service stops on `clonearmy` casts > 0** and advises a share of 0. It must not on this route.
6. **The long-run mode's LR-0 gate and horizon use wall run age** (12.1).

## 13. Switching routes

`warp_route.py switch`. A switch happens at a visit; from then on the other route's rules apply, and its mutagen line shows at once, since it reads holdings. Days to every achievement (ideal cadence):

| Switch | Days | Alone: mirrors 174, swarmwarp 141 |
| --- | --- | --- |
| mirrors → swarmwarp, first run day 1 (no mirror cast) | 141 | no cost |
| mirrors → swarmwarp, first run after 20 mirror casts | 141 | no cost |
| same, with a guard that keeps any run with mirror casts and 100+ expansions | **271** | the guard turned the first run into a 192-day long run without the lepidoptera mutation |
| mirrors → swarmwarp, right after the first ascension (mirrors purchases made), **with the free respec** | **148** | +7 |
| same, no respec | 181 | warp is the 3rd unlock (2.44e8): the next run took 73 wall days to pass the test |
| same, no respec, 16-day wall backstop | 173 | |
| mirrors → swarmwarp in the long run, day 10 (premutagen 1e25: the test passes, ascend) | **118** | faster than either route |
| day 30 (premutagen 1e76) | **110** | the fastest schedule seen |
| day 60 (premutagen 1e154, 3,118 expansions) | 140 | |
| day 90 (premutagen 1e232, 4,695 expansions) | 170 | |
| days 10 / 30 / 60 / 90, with a guard that keeps the long run (mirrors to 5,000) | 177 | the guard costs 7–67 days |
| mirrors → swarmwarp in the quick runs (5 ascensions done) | 175 | stage quick: as the mirrors route |
| swarmwarp → mirrors, first run day 2 | 174 | |
| swarmwarp → mirrors at 5 ascensions (1e18 held) | 176 | the current run becomes the mirrors long run |
| swarmwarp → mirrors at 20 ascensions (1e94) | 182 | |
| swarmwarp → mirrors in the final run, day 2 (1,492 expansions) | 147 | mirrors finish the expansions |

**Guard rules for the port, each from a case above:**
- **G1. No guard for a mirrors long run.** Do not hold a run because it has mirror casts and many expansions. The route's own test, premutagen ≥ 1,000 × held, ascends at once there, and that was faster in all four cases (by 7 to 67 days). If the owner wants protection anyway, the only safe one is a confirmation ("this run has 3,118 expansions; ascending restarts them"), not a rule that keeps the run.
- **G2. Never treat a first run (no ascension yet) as a long run** under any route. With that guard the switch cost 130 days.
- **G3. The free respec of 12.7** when the warp mutation is locked and unaffordable (+7 days instead of +40).
- **G4. The new route's mutagen line shows at once**, from holdings, not at the next ascension.
- **G5. Territory share back to 0.1** on the swarmwarp route (12.4).
- **G6. Swarmwarp → mirrors needs nothing.** It completed from every point tried (147–182 days). The mirrors route's "unlock all from the 2nd ascension" costs mutagen larvae, but nothing it needs.

What is irreversible:
- **An ascension.** The only one this route advises out of a mirrors run is the case where it pays (G1).
- **Mutagen spending.** A respec undoes it. There are 4 free respecs to start, plus 1 every 3rd ascension; a paid respec costs 30% of the ascension cost and wipes its discount. The route uses at most one free respec, on the switch.

Neither route advises anything the other route cannot recover from.

**A hybrid worth telling the owner:** mirrors for the first ~30 days of the long run, then this route, took **110 days**, the fastest schedule seen. It was sampled only at switch days 10, 30, 60 and 90 (118 / 110 / 140 / 170). **likely** that something near day 20–30 beats both pure routes; the best day is a **guess**.

## 14. The re-validated headline (advisor sizing, honest arithmetic)

The route as specified in section 12: the advisor's rule-3 sizing, honest push larvae with the 1% reserve, the game clock, and one warp at a time. Days from the 20.1 h save (`warp_route.py validate`, `mirrors`):

| Variant | 6 unlocks | 10 unlocks | 20 asc. | endless 1 | endless 1e62 | exp 1,000 | exp 2,000 | exp 5,000 | **all** |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **spec, ideal** | 34 | 58 | 95 | 102 | 107 | 74 | 103 | 141 | **141** |
| spec, human seeds 1 / 2 / 3 | 27–29 | 63–66 | 103–106 | 111–114 | 117–120 | 77–83 | 112–116 | 154–158 | **154–158** |
| spec, glance+ | 38 | 73 | 109 | 123 | 134 | 92 | 149 | 179 | 179 |
| spec, every 2 h | 39 | 73 | 111 | 131 | 143 | 93 | 170 | 190 | 190 |
| spec, busy | 46 | 79 | 118 | 139 | 151 | 105 | 160 | 198 | 198 |
| spec, twice a day | 55 | 106 | 138 | 182 | 190 | 137 | 221 | 243 | 243 |
| pass 1's route, re-run with the idempotent mutagen rule, ideal / human | | | | | | | | | 239 / 255 |
| mirrors route (the advisor today, same driver), ideal / human / busy | 100 | 100 | 174 / 181 / 193 | 53 | 66 | 24 | 43 | 100 | **174 / 181 / 193** |

- **Pass 1's 223 / 245–253 hold on pass 1's assumptions** (wall clock, warps back to back): 217 / 231 with this section's ascension test and mutagen rule.
- **The game clock and one warp at a time take the route to 141 / 154–158.**
- **The trough:** mutagen 1e15 → 1e32 took days 49–129 in pass 1. With the spec it takes days 16–50 (ideal), 18–56 (human), 32–73 (busy).
- **Slow cadences gain the most.** Busy: 366 → 198. Twice a day: never → 243. Banked warps are no longer cast in one batch.

## 15. Reference cases, grades, what is not modelled

**Reference cases:** `advisor/modelcheck/swarmwarp_cases/`, 45 cases, made by `advisor/modelcheck/swarmwarp_cases.py` in about 80 s. The README lists each case, every field and how the port must compare it. They cover:
- each energy situation by phase: lepidoptera, bats, test fails / passes with spend / save / ascend;
- the clock: a tier in cooldown released by one warp; five warps affordable, one at a time with the purchases between;
- both sides of the ratio test, the final threshold and the 30% unlock rule;
- the quick and done stages;
- the mutagen rule after ascensions 1, 2, 3, 8, 15, 22 and 28;
- the switch states: the mirrors route's purchases with and without a free respec, and its long run on days 10 and 30.

**Round trip in the real game:** 34–35 numbers per case, worst |sim/game − 1| = 3.7e-7. That figure is the halving amount, which the game measures from its own ceiled costs, as the advisor does. Larvae/s just after an ascension agree to 1.7e-7. Unlocks held and the earned flags are equal in every case. The numbers include:
- swarmwarp power and skip with bats and the warp mutation;
- bats, nightbugs, lepidoptera;
- every mutant, the unlocks held and the next unlock price;
- the cumulative skipped time and the game-time run age estimate;
- the ascension cost, energy spent and the cap.

| Finding | Grade |
| --- | --- |
| A warp moves no clock the advisor reads; `session.state.skippedMillis` is cumulative, survives reload and ascension | **solid** (game code) |
| The route needs the game clock: 217 → 141 days (ideal), 350 → 198 (busy); the run age matters most (206 → 141) | **likely** (simulator; one start, cadence seeds) |
| The swarmwarp route under the spec is faster than the mirrors route at the ideal and human cadences (141 vs 174; 154–158 vs 181) and about equal when busy (198 vs 193) | **likely**; days simulator-only |
| Ratio test 1,000× (flat to 10^4); lepidoptera 4,000–10,000; bats 0–2,000; A.11 below nexus 5 | **likely** |
| No guard for a mirrors long run; the free respec after mirrors purchases; G1–G6 | **likely** (one simulated case each) |
| Mirrors for ~30 days of the long run, then swarmwarp: ~110 days | **likely** faster than either; the best switch day **guess** |
| The game-clock change is a no-op on the mirrors route | **solid** (no warps, `skippedMillis` constant) |

**Not modelled:**
- **The player's work.** The route assumes a returning player casts their banked warps one at a time and follows the purchases after each, up to 50 warps per visit. Whether a person will is untested. The advisor should make it a single click per step.
- **The advisor's own code.** Simulated rules, not the port: the differences in `longrun_cases/README.md` apply (meat cap, territory purse, drones).
- **The game run age.** The simulator knows it exactly; the port's estimate agrees only when bats come before the first warp.
- **One start** (the 20.1 h save). Premutagen is the mean roll. Switches were simulated once each, at the ideal cadence.
- **The hybrid's best switch day.**
- **The browser** at many warps of years each (the game's own numbers are checked; speed is not).

**Reproduce:**

```sh
node advisor/modelcheck/swarmwarp_clock.js                      # section 11, the game's clocks
python3 -I advisor/sim/warp_route.py --jobs 4                   # sections 12-14, about 15 minutes on 4 cores
python3 -I advisor/modelcheck/swarmwarp_cases.py                # section 15, about 80 s (and the round trip)
```

New `sim.py` options, all off by default. With them off, `run_example.py` (both saves), `compare.py` (both saves), `ascension_compare.py` and `bignum_check.py` are byte-identical:

| Option | What it does |
| --- | --- |
| `game_clock` | the advisor's timers (cooldown, rule-3 memory, push cooldown, twin recency) read wall time + time skipped by swarmwarp (`s.gskip`) |
| `game_age` | run age (horizon, long-run gate, ascension) adds this run's skipped time (`s.gskip_run`, reset at an ascension) |
| `warp_visits` | after each swarmwarp, the non-energy part of the visit runs again (purchases between warps) |
| a callable ascension plan | `sim.ascend(s, p, plan)` with `plan(s)` deciding the mutagen purchases (`warp_route.apply_mutagen`) |
