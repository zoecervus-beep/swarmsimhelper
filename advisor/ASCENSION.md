# Ascension, mutagen and achievements: plan, mechanics and model

Nov 13, 2026. Second pass. The owner's goal is **every achievement, and a bunch of endless** (`overmind6`). They will keep ascending until every achievement is earned, and they will not use crystals. Part A is the plan for that goal. Part B holds the mechanics and the checks of the simulator against the game's code. Part C is the first pass, written for a different objective (most mutagen or most meat); this part overturns some of it (A.8).

Nothing in the game or the advisor was changed. All strategy numbers come from the simulator, playing a perfect policy once every 5 minutes from the owner's 20.1 h save. A person plays more slowly, so read every number of days as a lower bound. The grades say how far to trust each finding.

Tier names: the fork renamed the five upper overmind tiers (display only). They are **ascended** (`overmind2`), **cosmic network** (`overmind3`), **galactic cluster** (`overmind4`), **universal cortex** (`overmind5`) and **endless** (`overmind6`), the last meat tier.

## Part A. The plan for "every achievement, and a bunch of endless"

### A.1 The plan in brief

There are 121 achievements worth 2,410 points; the save has 48 of them (730 points). Every remaining one can be earned except `publictest1`, which is worth 0 points and has no trigger in the code. The full inventory, generated from the game data and checked in code, is in [ACHIEVEMENTS.md](ACHIEVEMENTS.md).

Two achievements set the length of the project, and both are paid for in energy, not attention:
- **"manifest destiny": 5,000 expansions in one run.** That is about 6,400 House of Mirrors casts in a single run. At the most energy the game can make (2.0 energy/s) that takes about 96 days.
- **"prestigious": 20 ascensions.** Each ascension after the first needs 0.56 to 0.80 million energy spent and held within its run. That is about 75 days of energy for ascensions 2 to 20, plus each run's start-up. The simulator measured 3.6 to 3.9 days per ascension.

Everything else falls inside those two:
- every meat-tier achievement up to 1e62 endless bought, by about day 63 of the long run (pass 4, A.10; pass 2 said day 60)
- the territory, mutation and nexus achievements, which only need a deliberate purchase

The route (simulator days at perfect play, 5-minute check-ins):

| Stage | How long | What to aim for | What to buy | When it ends | Achievements that fall |
| --- | --- | --- | --- | --- | --- |
| **1. Finish run 1** (now: 20.1 h, nexus 4) | about 4 days (97.5 h in the simulator) | nexus 5, then House of Mirrors with all energy. Once the ascension cost falls to about 72,000 energy (or the energy cap, if lower), stop spending energy and save it. | lepidoptera to 4,000 (as now), then mirrors. Optionally 1e15 swarmlings/stingers/... once larvae allow (see stage 2). | Ascend as soon as the energy covers the cost (~58,000 here, at run age ~4.9 d) | nexus2 ("power overwhelming"), expansion4–5, a few hive/hive queen ones, ascension1 |
| **2. First ascension: buy the lepidoptera mutation** | minutes | – | Unlock the lepidoptera ("nexus") mutation first (price 1), then buy about 1,000,000 of it (energy ×1.998). Unlock a second mutation (price 15,625): frequency or meat, it makes no difference to this goal (A.5). Keep the rest of the ~6e7 mutagen unspent: it makes larvae. | – | mutation1 |
| **3. The long run** | about 96 days to the end (expansion 5,000) | All energy into mirrors. Lepidoptera to 30,000. Climb everything, and push units up the chain toward endless (A.4). | Lepidoptera 30,000. Faster upgrades as soon as they pay. Feed each tier above the climb frontier from the one below. Hold units for climbing rather than spending them on twins of the tier below. Once larvae exceed ~1e15/s (around day 5–10), hatch 1e15 of each territory unit once (twins count). | When expansion 5,000 is reached (day ~96); the ascension then costs almost nothing | Every meat-tier achievement: first endless ~day 52, 1e31 endless ~day 59, 1e62 endless ~day 60. Expansions 1,000 (day 20), 2,000 (day 39), 5,000 (day 96). The eleven territory "1 quadrillion" ones when you buy them. |
| **4. Ascension 2: unlock everything** | minutes | – | With ~1e335 mutagen, unlock all 10 mutations; the 10th costs 15,625^9 ≈ 5.6e37. Keep the nexus mutation at ≥ 1e6. | – | mutation2–4, ascension11 at the 3rd ascension |
| **5. Quick ascensions 3 to 20** | 18 runs × 3.6–4.6 days ≈ 75–80 days | Energy only: rebuild 5 nexus, lepidoptera, then spend energy (mirrors) until the cost reaches ~108,000, then save it. Climbing does not matter. | Nexus, lepidoptera; mirrors as the energy sink | Each run when the energy covers the cost | ascension2 (5), ascension21 (10), ascension3 (20) |

**Total: about 175 days (6 months) at simulator pace; more like 7 to 9 months for a person** (A.6). The two energy-bound stages (the long run's expansions and the quick ascensions) are about 170 of those days, and no setting found shortens them. The stages can be swapped: do the 18 quick ascensions before the long run. The total is the same. Long run first is recommended, because:
- the endless arrive about 2.5 months sooner;
- its enormous mutagen pays for all 10 unlocks at once, with no respec needed;
- the quick runs that follow are pure routine.

**On a fresh game** (the owner's second game on the fork's site), the route is the same with two differences:
- Run 1 starts from nothing. The first ascension comes at a run age of about 5 days in the simulator.
- The one-off event achievements are still to do: import a save, the Konami code, the debug page, the patch notes, clicking the "clickme" slot, and typing s-e-q-u-e-l ("ask the right question", 0 points). Each takes seconds; see ACHIEVEMENTS.md.

### A.2 Conclusions and grades

| # | Finding | Grade |
| --- | --- | --- |
| 1 | **The inventory.** 121 achievements, 2,410 points, 73 left (1,680 points). Every one was checked through the game's own listener at and just below its threshold. Unit achievements count units *bought* (statistics, twins included, summed over every run); production and House of Mirrors clones never count. `publictest1` cannot be earned. | **solid** |
| 2 | **Expansion 5,000 needs ~6,400 mirror casts in one run: ~96 days at the 2.0 energy/s maximum** (5 nexus × 0.1 × lepidoptera ≤2 × lepidoptera mutation ≤2). Each cast doubles territory, worth 0.774 expansions (measured 0.78). Nothing else lifts that rate: bats do not affect mirrors, crystals are excluded, territory rush only gives a one-off offset. | Mechanics **solid**. 96 days **likely** (simulator; a person loses days to late casts) |
| 3 | **20 ascensions need ~13 million energy for ascensions 2–20: ~75 days at maximum energy, ~3.6–4.6 days per ascension.** It follows from the cost formula: hold C = min(cap, 50,000 × N / ln 2), spend 50,000 × N × log2(cost/C). Huge mutagen does not shorten a run, because energy is the limit (measured: 3.6–3.8 days with 6e7 or with 1e335 mutagen). | **solid** (formula), **likely** (days) |
| 4 | **Ascend once, now (about 4 days from the save), to buy the lepidoptera mutation before the long run.** Without it the long run is about twice as slow: first endless at day 103 instead of 52, expansion 2,000 at day 77 instead of 39, and 5,000 out of reach for ~190 days. | **likely** |
| 5 | **Endless are reachable, and "a bunch" follow quickly.** *(Pass 4 correction: with the rules as now specified in A.10.2 — a 1% push reserve, the advisor's own sizing — first endless about day 50 and 1e62 about day 63 under a person's cadence; the pass-2 days below rested partly on a floating-point artefact, see A.10.)* With the achievement policy the long run buys the first endless on about day 52, passes 1e31 on about day 59 and 1e62 on about day 60. By day 130 it holds ~1e270. The binding constraint on the way up is larvae for the top tiers (endless cannot be twinned, and universal cortex twins cost endless), and larvae come from expansions (1.1^level), i.e. again from mirrors. | **likely** for "about 2 months into the long run". Exact days **guess** (one policy, one start, perfect play) |
| 6 | **Policy matters for the climb.** The tuned climbing rule (H ≤ multiple × run age) stalls at empresses on long runs, as MODEL-CHECK found. Two changes fix it: counting as many faster levels as one purchase pays for ("faster-aware, multi"), and feeding every tier above the frontier toward endless ("push"). The rest of the policy hardly matters: age multiple 5 or 20 makes no difference, and the second mutation does not move it. | **likely** |
| 7 | **Attention matters for the climb only if each visit is a single look** (revised in A.10). With sessions where the panel is open (a few looks minutes apart), a person's cadence (7 to 80 visits a day, gaps up to 14 h) reaches endless within ~5 days of once-a-minute play. Evenly spaced single visits (every 30 min or 2 h) or one glance per session take ~109–111 days. Expansions and ascensions are unchanged: energy is banked up to the cap (15.5 h), and no energy was lost to it in any run. | **likely** |
| 8 | **Mutations for this goal:** lepidoptera ("nexus") first, then any; all 10 once the long run's mutagen pays for them. Unspent mutagen makes 0.1 larva/s each and helps the early part of each run; meat, hatchery and frequency mutations did not change the day the first endless fell (52 either way). | **likely** |
| 9 | **Lepidoptera 30,000 in the long run** (energy ×1.94 instead of ×1.8): the first endless 9 days sooner, expansion 5,000 7 days sooner than with 4,000. | **likely** |
| 10 | **Territory "1 quadrillion" achievements (11 of them)** are cheap late in a run: buy 1e15 of each territory unit once (twins count, mirror clones do not). The simulator's territory rule only buys the top unit in bulk, so it earned goon's but none of the other ten; that is a policy blind spot, not a cost. | **likely** (arithmetic) |

### A.3 What binds: the achievements that set the length

From ACHIEVEMENTS.md, the remaining 73 achievements group like this:

| Group | Remaining | What it needs | Effort |
| --- | --- | --- | --- |
| Meat tiers, first/second/third threshold, hive to endless | 45 (920 pts) | Units bought, all runs together. The largest thresholds: hive queen 1e14, empress 1e16, neuroprophet 1e18, hive neuron 1e20, neural cluster 1e22, … arch-mind 1e30, overmind 1e32, ascended 1e38, cosmic network 1e44, galactic cluster 1e50, universal cortex 1e56, **endless 1e62** | One long run, days 1–60 (A.4) |
| Territory units, 1e15 bought each | 11 (110 pts) | 1 quadrillion bought of each of the 11 territory units | A deliberate purchase once larvae ≥ ~1e15/s |
| Expansions 100, 200, 500, 1,000, 2,000, **5,000** in one run | 6 (390 pts) | Mirrors: 0.78 expansions per cast | **5,000 = ~96 days of one run** |
| Nexus 5 ("power overwhelming") | 1 (10 pts) | Buy nexus 5 | Days, in run 1 |
| Ascend 1, 3, 5, 10, **20** times | 5 (150 pts) | 20 ascensions; each needs its run's energy | **~75–80 days of quick runs** |
| Unlock 1, 3, 6, **10** mutations | 4 (100 pts) | Unlocks cost 15,625^k; all 10 cost 5.6e37 together | Free after the long run; a respec does not take them back |
| Events / secrets | 0 left in this save (`publictest1` is dead) | – | – |

- **Minimum number of ascensions: 20.** Ascension 20's cost is 5e6 × 1.12^19 = 43 million energy before discounts. The 1.12 growth only adds about 13,000 energy per ascension to the bill (0.56M at the 2nd, 0.80M at the 20th), because spending halves the cost every 80,000 energy (with the lepidoptera mutation). So the count, not the growth, is what costs time.
- **Time-based achievements:** none. Nothing asks for an ascension within N minutes or a run of N days; the long-run requirement is only through expansion 5,000.
- **Last to fall:** expansion 5,000 (day ~96 of the long run) if the quick ascensions come first. Otherwise, with the recommended order, "prestigious" (20 ascensions), about 75–80 days after the long run ends.

### A.4 Getting to endless, and to a lot of them

The long run after the first ascension, under the achievement policy. Simulated days of the run:

| Variant | arch-mind | overmind | ascended | cosmic network | galactic cluster | universal cortex | endless 1 | endless 1e31 | endless 1e62 | exp 1,000 | exp 2,000 | exp 5,000 | endless bought by day 130 (log10) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **achievement policy (base)** | 18 | 23 | 24 | 33 | 40 | 45 | **52** | 59 | **60** | 20 | 39 | **96** | 271 |
| push, but twins may take the pushed units | 19 | 26 | 38 | 46 | 60 | 64 | 66 | 68 | 68 | 20 | 39 | 96 | 271 |
| no push (climb rules only, faster-aware) | 34 | 46 | 62 | 83 | 109 | – | – | – | – | 20 | 39 | 96 | – |
| age multiple 5 | 19 | 19 | 28 | 31 | 38 | 44 | 52 | 59 | 61 | 20 | 39 | 96 | 271 |
| lepidoptera 4,000 | 17 | 23 | 28 | 34 | 39 | 48 | 61 | 65 | 67 | 20 | 41 | 103 | 247 |
| check-in every 30 min | 22 | 39 | 41 | 52 | 62 | 83 | 108 | 108 | – | 20 | 39 | 96 | 56 |
| check-in every 2 h | 26 | 40 | 42 | 53 | 65 | 86 | 109 | 109 | – | 21 | 40 | 97 | 57 |
| second unlock meat (50% of mutagen) instead of frequency | 20 | 21 | 27 | 30 | 39 | 46 | 52 | 59 | 61 | 20 | 39 | 96 | 268 |
| **no ascension first**: run 1 continued, no lepidoptera mutation | 33 | 48 | 48 | 63 | 80 | 92 | 103 | 116 | 120 | 39 | 77 | (~190) | 87 |

The base run, every 10 days:

| Run day | Expansions | log10 larvae/s | log10 meat/s | Top tier owned |
| --- | --- | --- | --- | --- |
| 0 | 0 | 7 | 0 | drone |
| 10 | 474 | 23 | 137 | hive network (pantheon2) |
| 20 | 999 | 46 | 298 | arch-mind (pantheon5) |
| 30 | 1,525 | 68 | 495 | ascended |
| 40 | 2,051 | 90 | 680 | cosmic network |
| 50 | 2,576 | 112 | 987 | universal cortex |
| 60 | 3,102 | 134 | 1,246 | endless |
| 90 | 4,678 | 199 | 1,935 | endless |
| 130 | 6,780 | 287 | 2,675 | endless |

First unit of each tier (base):

| Tier | Day |
| --- | --- |
| hive empress | 0.8 |
| neuroprophet | 3.9 |
| hive neuron | 5.0 |
| neural cluster | 7.8 |
| hive network | 8.4 |
| lesser hive mind | 12.3 |
| hive mind and arch-mind | 17.8 |
| overmind | 23.0 |
| ascended | 23.8 |
| cosmic network | 33.0 |
| galactic cluster | 40.0 |
| universal cortex | 45.3 |
| endless | 52.3 |

Every meat-tier "_3" threshold up to universal cortex 1e56 falls by day 51.

**What bottlenecks each step:**
- **Low and middle tiers (to arch-mind).** These grow on their own. Once a tier is held by the 1e40, one purchase pays for dozens of faster levels, so its break-even time collapses. The old run-age rule did not see that, which is why it stalled at empresses (A.2 #6).
- **The overminds.** They are bought with stock pushed up from below. Their twins (×12 to ×20 per level, paid in the tier above) only become affordable once the tier above is plentiful. That is why keeping pushed units for climbing, rather than for twins, saves 2 weeks.
- **Universal cortex and endless.**
  - Endless has no twin, and the cortex twin is paid in endless.
  - So each cortex comes from a separate hatch (one larva per hatch event), and each endless costs 1e58 cortex.
  - Larvae therefore bind. They come from expansions (1.1^level: 1e112/s at day 50), so mirrors set the pace here too.
  - Meat is never short: 1e38 per endless against 1e987/s.
- **Mutations** barely matter for the climb: meat mutation instead of frequency gives the same day 52. The **lepidoptera mutation is worth ~50 days**, through mirrors, expansions and larvae.
- **Banking** (skip a tier when the tier above out-produces larvae) stops mattering once larvae are counted in 1e40s; it is harmless.
- **House of Mirrors versus swarmwarp or clone larvae.** Mirrors drive expansions, and expansions drive larvae, so mirrors stay right for this goal too. Swarmwarp gives no energy and no expansions. Clone larvae is capped at 1e5 seconds of larva income, a one-off.

**Time estimates:**
- **First endless: day ~50 of the long run** (pass 4, A.10.3: 50–53 across cadences with sessions; 96 with single looks), i.e. about 7 weeks after the first ascension. Pass 2 said ~52.
- **The top endless achievement (1e62 bought): ~day 63** (pass 4: 62–66 with sessions; 113–115 with single looks). Pass 2 said ~60.
- **All achievements: ~6 months of real time at simulator pace, 7–9 months for a person.** Weeks for the first endless; months for everything.

### A.5 Ascensions: how many, when, and what each run is for

- **How many: exactly 20.** More earns nothing. The cost multiplies by 1.12 each time, but that adds only ~13,000 energy per ascension; the energy bill is dominated by the count.
- **Run 1 (now):** reach nexus 5 and cast mirrors. Ascend at the earliest moment (simulator: 97.5 h after the save, run age 4.9 days, no crystals). Its only purpose is the lepidoptera mutation.
- **Run 2: the long run** (~96 days). Everything except the ascension count happens here. Ascend at the end, which is almost free: the energy spent on 6,400 mirrors has driven the cost to ~1 energy.
- **Runs 3 to 20: quick runs**, 3.6–4.6 days each in the simulator, energy-bound. In each:
  1. rebuild 5 nexus and 30,000 lepidoptera (they also count as spending);
  2. spend energy on mirrors until the cost reaches about 108,000 (the cap, with the lepidoptera mutation);
  3. stop and save, then ascend.

  Climbing in these runs does not matter.
- **Can the count be collected cheaply?** Not much cheaper than this:
  - Every ascension needs its run to spend about b × log2(cost/cap) energy (b = 80,000 with the mutation) plus the cap held. That is ≥ 3.2 days at the maximum energy rate.
  - Huge mutagen from the long run makes nexus 5 come within hours, but the energy itself still has to accrue.
  - Nightbugs raise the cap (toward 6×) and count as spending, but the best amount to hold is already ~115,000, near the cap.
  - Removing the lepidoptera mutation with a free respec (b = 50,000) halves the energy rate, which is worse: 101 days instead of 75 for ascensions 2–20.
- **Mutation order for this goal:**
  1. lepidoptera ("nexus") at the first ascension;
  2. any second (15,625);
  3. all ten at the second ascension (they cost 5.6e37 together, against ~1e335 held), keeping ≥1e6 nexus.

  The meat, hatchery and frequency mutations did not move the climb. Unspent mutagen gives 0.1 larva/s each, which helps the early days of each run.

### A.6 Settings per stage, and what a person should expect

| Stage | Climb multiple | Lepidoptera target | Territory share | Energy |
| --- | --- | --- | --- | --- |
| 1 (finish run 1) | 5 (as tuned) | 4,000 | 0.1 | nexus 5, mirrors; save for the ascension once the cost is ≤ ~72,000 or the cap |
| 3 (long run) | 20; the advisor also needs the two new rules (A.7) | 30,000 | 0.1 throughout: mirrors need units to double | mirrors, all of it, never letting energy reach the cap (~15 h at full rate) |
| 5 (quick runs) | any | 30,000 | 0.1 | nexus, lepidoptera, mirrors until the cost is ≤ ~108,000, then save |

- **Long run.** Cast mirrors at least twice a day. Climbing needs frequent visits: the simulator's push loses ~8 weeks to the first endless at 30-minute check-ins.
- **Quick runs.** At least two visits a day are enough, because energy is banked up to the cap.
- **For a person:** the energy-bound days (~170) are close to what the simulator says. The climbing part could add weeks.

### A.7 What the advisor should show for this goal (proposal, not built)

1. **Achievements line, always:**
   `achievements: 730 / 2,410 pts · next closest: hive queens 1e7 bought (98%) · long poles: 5,000 expansions (65 now), 20 ascensions (0)`
   - "Next closest" uses the game's own `achievement.progressPercent()` over unearned, unmasked achievements. The data supports it: every unit, upgrade and ascension achievement has a numeric requirement.
2. **Stage line:**
   `stage: long run, day 34 · expansions 1,780 / 5,000 (~62 days at 52/day) · next tier: galactic cluster (needs 1e41 cosmic network; you hold 1e30)`
   - In the quick-run stage it becomes: `ascension 7 of 20: cost 107,000 energy; spend until ≤ 108,000, then save: ready in ~14 h`.
3. **Push line** (new rule): `feed upward: hatch 3.2e15 universal cortex (half your galactic clusters)`, and `faster: buy 37 levels of neuroprophet faster with this purchase`.
4. **Energy line:**
   - long run: "mirrors (expansions are the long pole)";
   - quick runs: "save for ascension";
   - lepidoptera target 30,000 in both.

**What it needs to read:**
- `achievementlist()`: `isEarned`, `isMasked`, `progressPercent`
- the expansion level and `ascension` count
- per tier: counts, `faster`/`twin` levels and prices, hatch cost
- energy rate, cap, `ascendCost()`
- one setting for the stage

The push and multi-faster rules should be ported from `sim.py` and checked with the script-versus-port harness, as the climbing rules were.

### A.8 What this objective overturns in the first pass (Part C)

- **"Ascend once, then never again"** is overturned. 20 ascensions are required. The first-pass reasoning still holds inside the long run: do not reset it.
- **"First purchases: lepidoptera, then frequency"** still holds for the first unlock. The second does not matter for this goal. All ten are needed eventually, and are free after the long run.
- **"Lepidoptera 10,000 for long runs"** becomes 30,000 for the long run.
- **"The age multiple does not matter"** still holds for the long poles. The climb itself needs new rules: the run-age rule stalls at empresses.
- **Crystals.** The first pass counted 500 crystals per 30 minutes as energy. Under the owner's choice they are excluded: the first ascension moves from 84 h to 97.5 h after the save.
- **Break-even reasoning** ("ascend only if you play ≥5 more days") no longer applies: ascensions are required.
- **Float overflow after ~1,000 mirrors** is fixed (B4). The first pass's longest results are unchanged.

### A.9 Not modelled or not verified (this part)

- **One start, one policy family, perfect play.**
  - The push and faster-aware rules are a first design, lightly varied (5 variants), not optimised.
  - The days to endless could move by weeks either way.
  - Slow check-ins were only tried by stretching the same per-check-in shares.
- **Territory "1e15" purchases, mutation unlocks after the long run, and the nexus 5 achievement** are by arithmetic, not simulated end to end. The quick runs were simulated for 4 ascensions from each of two starts, not all 18.
- **The game's limits.** The game caps units at 1e100000; the simulator's long run stays far below (meat ~1e2,675 at day 130). The browser's speed at such numbers is untested.
- **Event achievements** were not simulated; their triggers are read from the code and checked through the listener.
- **The simulator's territory rule** buys only the top unit in bulk (A.2 #10).
- **Swarmling empower** is still not modelled.

### A.10 Long-run climb rules (spec for the advisor's opt-in long-run mode)

**Pass 4 correction.** The pass-3 evidence in this section ran on a floating-point artefact, and A.10.2 now carries the fix.

- **The artefact.** Whenever the climb took every larva it was offered, the push recomputed its larvae as `larvae − purse − reserves`. That left a rounding remainder of about one float ULP, which at 1e100 larvae is ~1e84 larvae. In exact arithmetic, as in the game, the remainder is 0.
- **What the push actually ran on.** Pass 4 traced the long run visit by visit. Push lines are rare, a few per day. Early in the run (to about day 6) they were fed by larvae the climb genuinely left. From about day 9 on, most were fed by the remainder, including the first universal cortex and the endless lines.
- **With honest arithmetic and no other change** the mode stalls exactly where the old rules stall: overmind on day 65, and no universal cortex or endless within 130 days.
- **The fix** is a deliberate rule doing what the artefact did by accident: **keep 1% of the larvae for the push** (LR-2).
- **What pass 4 also simulated.** It simulated the advisor's own purchase sizing (rule 3) for the climbing tiers, which pass 3 never did. It dropped the faster-level rule (LR-1), which carries no weight with the advisor's sizing.
- **Corrected headline** (rule-3 sizing, 1% reserve, human cadence): **first endless day 50, 1e62 endless day 63, 5,000 expansions day 96.** It is day 50 / 62 / 96 at once every 5 minutes, and 52–53 / 64–66 / 98 for the busy, twice-a-day and glance+ cadences.
  - Previously stated: 52 / 60 / 96. So 1e62 endless comes 3–5 days later; everything else is the same or earlier.
  - Single looks per session are still slow: first endless day 96, 1e62 day 113–115.
- **Which tables are pass 3.** A.10.1 and the pass-3 tables in A.10.3 and A.10.4 were made with the artefact; they are kept as they were, marked "pass 3". So is A.4, which was made with the pass-2 rules.
- **What survives.** The cadence findings: sessions are as good as every-5-minute play, single looks are slow, the energy cap never binds. So do the twin-guard and banking findings. **What does not:** "the faster-level rule is cheap insurance", and the exact pass-3 days.

Third pass, revised in pass 4. This section turns the rules that got the simulator to endless into a spec for the native advisor. Everything here comes from the simulator. The long run starts at the first ascension from the 20.1 h save (lepidoptera and frequency mutations, no crystals) and lasts 130 days.

Time is modelled the way a person plays (`advisor/sim/cadence.py`):
- **Sessions with the panel open.** During a session the player acts every 2 minutes on everything the advisor shows.
- **Away between sessions** for random stretches, and asleep 8 hours a night.
- **Energy** is spent at each visit, and mirrors queue up to the cap while away.

**Cadences:**

| Cadence | Pattern | Visits/day | Longest gap |
| --- | --- | --- | --- |
| every5 | the simulator's earlier one-visit-per-5-minutes | 288 | 5 min |
| human | sessions of 15–40 min, away 1–4 h | 80 | 11 h |
| busy | sessions of 5–15 min, away 3–8 h | 17 | 14 h |
| twice | a 10-minute session morning and evening | 10 | 12 h |
| glance | as human, but a single look per session | 7 | 12 h |
| glance+ | glance plus two more looks 1 and 2 minutes later | 20 | 12 h |
| every30 / every120 | even spacing day and night | 48 / 12 | 30 min / 2 h |

#### A.10.1 Why slow check-ins hurt, and what fixes it

**The pass-2 "~108 days at 30-minute or 2-hour check-ins" came from evenly spaced single visits.** It does not happen when the player stays a few minutes per visit. Measured, with the pass-2 rules unchanged:

| Cadence | First endless | 1e62 endless | 5,000 expansions |
| --- | --- | --- | --- |
| every5 | 52 | 60 | 96 |
| human | 52 | 59 | 96 |
| busy | 56 | 62 | 97 |
| twice | 55 | 63 | 98 |
| glance | 111 | not by day 130 | 97 |
| every120 | 109 | not by day 130 | 97 |
| glance+ | 59 | 70 | 97 |

What the loss is not:
- **Not energy capping.** Energy lost to the cap was **0 days in every run**, including 14-hour absences. With 5 nexus, 30,000 lepidoptera and the lepidoptera mutation, the cap (108,500 including the owner's crystal energy) holds 15.5 hours at 1.94 energy/s. No nightbugs are needed unless the player is away longer than that.
- **Not 5,000 expansions.** That pole moves by at most 2 days under any cadence.
- **Not larvae sitting idle.** Expansions and larvae follow mirrors, which are unaffected.
- **Not too little converted per visit.** The obvious per-visit fixes did not help with single looks:

| Fix tried | Effect with single looks |
| --- | --- |
| Shares per minute (`time_share`, the native advisor's `1 − (1 − share)^minutes`) | **worse**: no endless by day 130; it converts whole lower tiers after a long gap |
| Twins counted as "recent" from the previous visit | worse |
| Push repeated 3–10 times within the visit | 1e62 at day 113–115 instead of never; first endless unchanged at ~111 |
| Push bottom-up (all tiers in one round) | same as the repeats; **worse** (72–98 days) at normal cadences |

What it is:
- **The loss comes from not having a second look a minute or two later.** That second look is when the twins for the tiers just hatched, and the next step of the push, get bought.
- Adding two more looks to each single glance brings the first endless back to day 57–59.

**So the fix is in how the advisor is used, not in a share:** stay a couple of minutes, or look again. The owner plays with the panel open, which is the "human" or "busy" pattern, where nothing is lost.

#### A.10.2 The rules, as they should be implemented

The mode is opt-in. With it off, the advisor is exactly what it is now. With it on, the advisor applies the existing rules unchanged, plus the following. In each rule, tier k counts drone as 1 (endless is 20), and "below" means tier k − 1.

**LR-0. When the mode acts.** From a run age of 2 days (run age ≥ 172,800 s; the gate is open at exactly 2 days). Before that the mode changes nothing (measured: identical advice on days 1–2 from a fresh run, from the save and after an ascension). This also makes a mode left on after an ascension harmless for the first two days.

**LR-1. Dropped in pass 4.** With the advisor's own sizing (rule 3), a slow tier's first-look purchase is small, so this rule almost never fires. The port found L = 0 in all five reference cases where the simulator's sizing passed it.

Measured with rule-3 sizing and the 1% reserve, first endless / 1e62 endless:

| Cadence | LR-1 off | LR-1 on rule 3's count | LR-1 on the affordable count |
| --- | --- | --- | --- |
| every5 | 50 / 62 | 50 / 62 | 50 / 62 |
| human | 50 / 63 | 50 / 63 | 50 / 63 |
| busy | 52 / 65 | 52 / 65 | 52 / 65 |
| glance+ | 52 / 64 | 52 / 64 | 52 / 64 |
| glance (single looks) | 96 / 115 | 96 / 115 | 96 / 115 |
| every120 | 96 / 113 | 96 / 113 | 96 / 113 |

It carries no weight, so the port should remove it. The pass-3 text follows for reference only.

*(Pass 3, no longer part of the spec.) Climbing with several faster levels (extends rule 1).* Consider each tier the climb table considers: up to one above the highest owned tier. LR-1 applies to a tier k ≥ 2 that fails the climb test (H > horizon), is affordable, and is not banked (rule 4 still applies first):

| Quantity | Definition |
| --- | --- |
| n | the purchase count rule 3 would give if the tier passed |
| got | count + n × twin |
| F_L | price of the next L faster levels of tier k: Σ 66 × 666^(level+i) for i = 0..L−1, in units of tier k |
| N_L | got − F_L, the units kept |

- **Test:** the tier passes if some L ≥ 1 gives N_L ≥ 1 and H × (N_L + F_L)/(N_L × 2^L) ≤ horizon. Use the smallest such L.
- **The sunk price counts.** (N + F)/N is the honest-accounting factor. The naive H/2^L made no difference in pass 2's checks but is not recommended.
- **The player is told:** `buy n X, then faster X`. After the hatch, buy faster levels of X one at a time at 1× their price (not rule 5's 2×), until X passes the plain test or the next level costs more than X holds. That is usually L levels, but it can be more or fewer: the simulator does exactly this, and the reference cases record the levels it bought.
- **Evidence:** with push but without LR-1 the result is the same at every5 and human (first endless 52), but it fails at 2-hour single visits (no universal cortex). It is cheap insurance.

**LR-2. Feeding the tiers above the frontier ("push"; new action).**

- The **frontier** is the highest owned tier that passes the **plain** climb test (rule 1: H ≤ horizon); LR-1 passes do not count. It is taken after this visit's climbing suggestions are applied (the panel recomputes once they are bought), so a tier the climb has just started, or whose faster levels the climb has just bought, can raise it.
- For each tier k from endless down to frontier + 1, with any of the tier below held: hatch n = floor(share × below.count / cost), where:
  - share = **0.5** for k ≥ frontier + 2;
  - share = **0.02** for k = frontier + 1, because that price comes out of the top growing tier.
- **Reserve (pass 4).**
  1. Before the climb works out its suggestions, set aside **R = floor(0.01 × A)** larvae for the push. A = the larvae the climb could otherwise use: larvae × (1 − territory share), floored, minus the larvae held for the next nexus.
  2. The climb works with A − R: rule 3's "larvae left", its cooldown earmarks and banking all come out of A − R.
  3. The push starts with **R + whatever the climb leaves**, with exact arithmetic. If the climb takes everything offered, the push has exactly R.
- Skip the tier when none of the tier below is held, or when fewer than 1 larva is left.
- Cap n by the larvae the push has left (R + the climb's leftover − earlier push lines) and by half the meat (meat / 2 / the tier's meat price), and take the floor. No line when n < 1.
- **Why the reserve, and why 1%.** Without it the climb's top tier takes every larva on almost every visit (rule 3's limits on a top tier rarely bind), and the push gets nothing.
  - Swept from 1e-12 to 0.5, any reserve gives the same days: first endless 48–50, 1e62 59–63, 5,000 expansions 96, under both sizings and both cadences. The counts are astronomically large, so even 1e-12 of them is plenty late in the run.
  - 1% is chosen to be **independent of the numbers' size**. It gives the push 1 larva from 100 offered, 1e7 from 1e9 on day 2, and so on. Its cost to the climb is not measurable: meat/s on days 20 and 40 is the same from 1e-6 to 10%. At 50% it costs about 10^39 meat/s on day 20.
  - A visible, round share is also easier to explain in the panel than 1e-12.
- **Do cooldown earmarks and banking need their own protection?** No. The reserve is taken before them; with rule-3 sizing, earmarks included, the results match the simulator's sizing (table below).
- Top-down, once per visit. Each line takes its larvae and meat before the next one is worked out.
- No line for a tier hatched less than 60 s ago, by the climb or by a push line (cooldown, as for climbing).
- **The player is told:** `feed upward: hatch 3.2e15 universal cortex (half your galactic clusters)`.
- **Which parts carry it** (first endless, every5 / human):

  | Change | First endless |
  | --- | --- |
  | **without push** | **none by day 130** (it stalls at overmind, day 62) |
  | share 20% or 90% | 52–55 |
  | frontier share 0.5% | 55 |
  | frontier share 10% | 51–52 |
  | bottom-up order | **72–98** |

  Keep top-down. The share values hardly matter.

**LR-3. Do not spend pushed units on twins below (changes rule 6).** A twin of tier k − 1 that is paid in units of a pushed tier k (k above the frontier of the state as it is, before this visit's purchases) is suggested only while tier k holds at least **10^6 ×** the twin's price. Otherwise rule 6 decides as now.
- With twins allowed to take them, the first endless comes at day 66 instead of 52 (every5); with 10^3, day 52.
- This also covers the overmind twins (×12 to ×20 per level): they are bought from surplus, never from the climb.

**LR-4. Lepidoptera target 30,000 from a run age of 3 days** (≥ 259,200 s) (the existing setting raised by the mode). It brings the first endless 9 days and 5,000 expansions 7 days earlier than 4,000. From the start of a run it costs meat early (see A.10.4), so it waits 3 days.

**Kept as they are:**
- **Age multiple.** Your setting. In this mode it makes no difference: 1, 5 and 20 all give first endless 52–55 and 1e62 59–63. The horizon only decides rule 1, and push does the climbing.
- **Banking (rule 4).** Keep it. With banking off the first endless slips to 69 (every5) and fails under single looks.
- **Twin plans (rule 7), territory, energy.** Unchanged.
- **"Use the existing rules below some tier, the new ones above"** cannot be a tier limit. The existing rule stalls at hive empresses, so LR-1 and LR-2 must reach down to wherever the frontier is. Rules from hive network up only never got past empresses. The run-age gate (LR-0) does the job a tier limit would have done.

#### A.10.3 Evidence: the specified mode under each cadence

**Pass 4.** The spec as now written: LR-0, LR-2 with the 1% reserve, LR-3, LR-4; no LR-1; the advisor's rule-3 sizing for the climbing tiers; honest larva arithmetic; age multiple 5. Days of the long run, plus log10 meat/s on days 20 and 40.

| Cadence | arch-mind | overmind | universal cortex | endless 1 | endless 1e62 | exp 5,000 | meat/s day 20 / 40 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| every5 | 15 | 18 | 39 | **50** | **62** | **96** | 340 / 756 |
| **human** | 15 | 18 | 40 | **50** | **63** | **96** | 297 / 703 |
| human, seeds 2 and 3 | 15 | 18 | 40 | 50 | 63 | 96 | 296–304 / 715–738 |
| busy | 17 | 19 | 41 | **52** | **65** | **98** | 290 / 646 |
| busy, seeds 2 and 3 | 17 | 20 | 42 | 52 | 64–65 | 98 | 288–291 / 646–648 |
| twice | 18 | 20 | 45 | 53 | 66 | 98 | 285 / 651 |
| glance+ | 16 | 20 | 41 | 52 | 64 | 97 | 293 / 648 |
| glance (single looks) | 30 | 38 | 81 | 96 | 115 | 98 | 144 / 357 |
| every120 | 28 | 36 | 80 | 96 | 113 | 97 | 155 / 364 |

What carries it:

| Variant | every5 endless 1 / 1e62 | human endless 1 / 1e62 |
| --- | --- | --- |
| honest larvae, **no reserve** (rule-3 sizing) | – / – (stalls: overmind day 65) | – / – |
| honest larvae, no reserve (simulator sizing) | – / – | – / – |
| reserve 1e-12 … 0.5 (simulator sizing) | 48 / 59–60 | 49 / 62 |
| reserve 1e-6, 1%, 10% (rule-3 sizing) | 50 / 62 | 50 / 63 |
| current rules, rule-3 sizing (no mode) | – / – (stalls at hive queens; meat/s 148 on day 20) | – / – |
| the pass-3 spec, with the artefact | 53 / 62 | 53 / 63 |

Tables: `longrun_rules.py honest`, `advisor`, `final4`.

**Pass 3 (made with the artefact; kept for the record).** Days of the long run; "spec" = LR-0 to LR-4 with age multiple 5.

| Variant | Cadence | arch-mind | overmind | universal cortex | endless 1 | endless 1e31 | endless 1e62 | exp 5,000 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| pass-2 mode | every5 | 18 | 23 | 45 | 52 | 59 | 60 | 96 |
| **spec** | every5 | 17 | 25 | 46 | **53** | 62 | **62** | **96** |
| spec, rules from the start | every5 | 17 | 25 | 46 | 54 | 59 | 60 | 96 |
| spec, age multiple 20 | every5 | 18 | 27 | 46 | 53 | 60 | 60 | 96 |
| spec without push | every5 | 48 | 65 | – | – | – | – | 96 |
| pass-2 mode | human | 20 | 20 | 44 | 52 | 58 | 59 | 96 |
| **spec** | human | 22 | 26 | 43 | **53** | 60 | **63** | **96** |
| **spec** | busy | 25 | 25 | 49 | **57** | 59 | **64** | **98** |
| **spec** | glance+ | 22 | 22 | 50 | **57** | 64 | **64** | **97** |
| pass-2 mode | glance (single looks) | 34 | 37 | 88 | 111 | 111 | – | 97 |

Other random schedules (seeds 2 and 3, pass-2 rules) give first endless at 52–55 and 1e62 at 60–62 for "human", and 54–57 and 61–63 for "busy".

#### A.10.4 No harm early

**Pass 4** (rule-3 sizing for both). log10 meat per second (top tier) on days 1, 2, 4 and 7:

| Start | Cadence | Rules | Day 1 | Day 2 | Day 4 | Day 7 |
| --- | --- | --- | --- | --- | --- | --- |
| fresh run | every5 | current | 42.2 (hive) | 47.0 (hive) | 60.6 (hive queen) | 69.5 (hive queen) |
| fresh run | every5 | spec | 42.2 (hive) | 47.0 (hive) | 60.0 (empress) | 65.6 (empress) |
| fresh run | human | current | 26.8 | 34.9 | 49.1 | 67.3 |
| fresh run | human | spec | 26.8 | 34.9 | 48.6 | 62.3 |
| after the first ascension | every5 | current | 46.8 | 49.9 | 69.0 (hive queen) | 85.1 (hive queen) |
| after the first ascension | every5 | spec | 46.8 | 49.9 | 78.4 (hive neuron) | 90.1 (hive neuron) |
| after the first ascension | human | current | 42.7 | 48.2 | 66.6 | 83.0 |
| after the first ascension | human | spec | 42.7 | 48.2 | 65.9 | 88.1 |
| the 20.1 h save | every5 | current | 45.1 | 48.3 | 64.2 | 72.6 (hive queen) |
| the 20.1 h save | every5 | spec | 45.1 | 48.3 | 62.9 | 66.9 (neuroprophet) |
| the 20.1 h save | human | current | 43.9 | 47.2 | 60.7 | 70.9 |
| the 20.1 h save | human | spec | 43.9 | 47.1 | 58.9 | 65.4 |

Days 1–2 are identical. Days 4–7 are between 10^6 below and 10^5 above, the same picture as pass 3: the raised lepidoptera target costs meat early.

**Pass 3** (the simulator's sizing, with the artefact). log10 meat per second (top tier) on days 1, 2, 4 and 7 of a run:

| Start | Cadence | Rules | Day 1 | Day 2 | Day 4 | Day 7 |
| --- | --- | --- | --- | --- | --- | --- |
| fresh run | every5 | current | 42.9 (hive) | 47.2 (hive) | 60.8 (hive queen) | 69.5 (hive queen) |
| fresh run | every5 | spec | 42.9 (hive) | 47.2 (hive) | 60.9 (hive queen) | 65.4 (neuroprophet) |
| fresh run | human | current | 24.7 | 36.6 | 50.5 | 67.7 |
| fresh run | human | spec | 24.7 | 36.6 | 50.1 | 64.1 |
| after the first ascension | every5 | current | 46.7 | 49.9 | 69.0 (hive queen) | 85.1 (hive queen) |
| after the first ascension | every5 | spec | 46.7 | 49.9 | 78.6 (empress) | 90.7 (hive neuron) |
| the 20.1 h save | every5 | current | 45.1 | 48.4 | 64.3 | 72.6 (hive queen) |
| the 20.1 h save | every5 | spec | 45.1 | 53.0 | 63.3 | 66.2 (neuroprophet) |
| the 20.1 h save | human | current | 44.1 | 47.2 | 62.0 | 70.9 |
| the 20.1 h save | human | spec | 44.1 | 47.2 | 60.5 | 65.1 |

- **Days 1–2:** identical (LR-0). One exception: from the save, day 2 counts as run age 2.8 days, so the rules were already on.
- **Days 4–7:** the spec ends between 10^6 below and 10^6 above the current rules. The rules alone would be 10^5 to 10^21 above, climbing to empress or neural cluster instead of hive queen; the raised lepidoptera target takes most of that back, because energy goes into lepidoptera.
  - That is no harm to the achievement goal: it is what brings endless and the expansions sooner.
  - It would cost a player who ascends within a week and only wants meat, which is why the mode is opt-in.
- **Settings to avoid.** Turning on age multiple 20 and lepidoptera 30,000 from the start of a run (the pass-2 settings) costs up to 10^14 meat/s on days 4–7 (day 4: 49.8 vs 64.3 from the save). The spec avoids both.

#### A.10.5 Territory empower

`sim.EMPOWER_MODEL` (default off) models empower:
- level e multiplies a unit's production by 1.53228e18^e and its meat cost by 1.53228e29^e;
- the next level costs the unit's base price × 1.53228e29^e meat;
- buying it wipes that unit's count.

Checked against the game in `bignum_check.py`: 33 empower numbers plus a real empower purchase, all within the game's rounding (3.5e-6).

The policy option `empower` follows the native advisor's `empowerAdvice` rule: empower the cheapest rung when the territory larvae fit in the top rung with the price to spare, and the wiped units make under 1% of territory.

| Variant | Expansions day 10 / 40 / 90 | Exp 5,000 | Endless 1 | Endless 1e62 | Empowers bought |
| --- | --- | --- | --- | --- | --- |
| no empower, every5 | 474 / 2,051 / 4,678 | 96 | 52 | 60 | 0 |
| advisor's empower rule, every5 | 513 / 2,089 / 4,717 | **95** | 54 | 63 | 18 (all units 1–2 levels, first on day 0.2) |
| no empower, human | 463 / 2,039 / 4,667 | 96 | 52 | 59 | 0 |
| advisor's empower rule, human | 487 / 2,063 / 4,691 | 96 | 52 | 62 | 15 |

**Answer:** empowering early gives a constant ~25–40 more expansions, about half a day off 5,000 expansions, and costs 0–3 days on 1e62 endless. That is a wash.
- Why so small: only units bought before most mirror casts matter, because mirrors double every unit thereafter. Early in the run, meat affords only one or two rungs above goons.
- The existing advice is harmless and need not be switched off in the mode. It is not worth chasing.
- The territory 1e15 achievements are unaffected: they count units bought and are a one-off purchase each.

#### A.10.6 What the mode changes in the existing advisor (for the port and its checks)

| Behaviour | Now | In the mode (run age ≥ 2 d) |
| --- | --- | --- |
| Tiers listed | up to top + 2 | up to endless while LR-2 feeds them |
| Rule 1 climb test | H ≤ horizon | unchanged (LR-1 dropped in pass 4) |
| Larvae for the climb | larvae × (1 − territory) | minus the larvae held for the next nexus, minus the 1% push reserve R (pass 4) |
| New action | – | LR-2 "feed upward" lines, run on R plus what the climbing tiers leave |
| Rule 6 twin tips | as now | suppressed for twins paid in a pushed tier unless it holds 10^6× the price (LR-3) |
| Lepidoptera target | setting (4,000) | 30,000 from run age 3 d (LR-4) |
| Everything else | – | unchanged: rule 3 sizing, cooldown, banking, twin plans, energy, territory, empower |

- **What the existing check covers.** The console script versus native port check (`script_vs_port.js`) covers the advisor with the mode **off**. It must still pass unchanged, and that is all it can say.
- **The mode needs its own check:** the port's LR-1 to LR-4 decisions against `sim.py`'s `faster_levels`, `push_up`, `push_frontier`, the twin guard and the `lr_age` / `moth_late` gates, on states from the long run. The reference cases for that check are in `advisor/modelcheck/longrun_cases/`: 30 exported states (pass 4: the reserve on both sides of its one-larva floor, and a climb cooldown earmark), each with the simulator's decisions and per-field comparison rules. See its README. The simulator's states are on disk after `longrun_rules.py`.
- **Sizing.** Pass 4 simulates the native advisor's rule 3 itself (option `advisor_sizing`: time since last hatch, spare, cooldown earmarks). With the 1% reserve it gives 50 / 63 against 49 / 62 for the simulator's own sizing under the human cadence. The reference cases are made with rule-3 sizing, so the climb purchase counts are comparable given the memory seeds in each case (README).

#### A.10.7 Grades

| Finding | Grade |
| --- | --- |
| Energy capping is not binding (0 days lost, gaps up to 14 h) | **solid** (cap arithmetic plus simulation) |
| With sessions (panel open, a few minutes per visit), slow overall cadence costs ≤ 5 days on endless and ≤ 2 on expansions | **likely** |
| Single looks per session cost ~2 months on endless; a second look a minute or two later fixes most of it | **likely** that it matters; the exact mechanism is **guess** |
| Push (LR-2) is what reaches endless; twin protection (LR-3) and banking matter; share values and age multiple do not | **likely**. Pass 4: the push only works with larvae of its own (the reserve). The pass-3 evidence for it came from the artefact. |
| The 1% push reserve: any share from 1e-12 to 0.5 gives the same days; 1% costs the climb nothing measurable | **likely** (pass 4, both sizings, two cadences) |
| With the advisor's own sizing (rule 3) the mode reaches first endless ~day 50, 1e62 endless ~day 63 (human), 5,000 expansions day 96 | **likely**; days are simulator-only |
| LR-1 carries no weight | **likely** (pass 4: identical results with it off, at every cadence tried) |
| LR-0 gate makes days 1–2 identical; LR-4 trades meat on days 4–7 for endless ~9 days sooner | **likely** |
| Empower is a wash in the long run | **likely** |
| Endless days | all simulator-only, one start, one save, perfect execution of what the rules say at each visit |

#### A.10.8 What I would still want tested

- **The port itself**, against the simulator's rule functions on long-run states: the LR-2 reserve and counts, the LR-3 guard. Then the console-script check with the mode off.
- **Pass 4 open points:** the reserve is taken from larvae held back from the nexus in the simulator; check the port's order gives the same R. The 30-minute-cadence advisor memory (spare) after a page reload starts afresh; not simulated.
- **Rule 3 sizing with the mode on**, in the simulator, i.e. `time_share` plus a spare cap, at human and busy cadences over a full long run. Only the per-visit-share version was tuned.
- **More starts:** a long run from a fresh game, and from a later or earlier first ascension. Every run here starts from one state.
- **Raising lepidoptera at day 7 instead of day 3**, and nightbugs for players away longer than 15 hours.
- **Quick-run behaviour with the mode left on.** LR-4's lepidoptera count as spent energy, so ascension timing should not move, but this was not simulated.
- **A person's real check-in log.** The cadence profiles are guesses; the owner's actual pattern would replace them.

## Part B. Mechanics and model check

Unchanged from the first pass except where noted; B.4 is new.

### B2. Mechanics, as the game computes them

Sources:
- Data: `swarmsim-coffee/app/scripts/spreadsheetpreload/v0.2.js`, the table the game loads; it is identical to `tables/src/spreadsheet/original-data.json` for these rows.
- Code: `game.coffee` (`ascend`, `ascendCost`, `respec`), `effect.coffee` (`addUnitRand`, `logStat`, `asympStat`, `expStat`), `upgrade.coffee` (`_totalCost`), `unit.coffee` (`spent`), `seedrand.coffee`.
- Views: `app/views/desc/unit/mutagen.html` and the hatchery and expansion descriptions.

Every worked number below was **measured** by running the game's code in Node (`advisor/modelcheck/ascension_check.js`), on the 20.1 h save unless stated. Time zone: UTC.

#### B2.1 Premutagen: how it is earned

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

#### B2.2 The ascension cost

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

#### B2.3 What ascending resets and keeps

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

#### B2.4 From premutagen to mutagen, and what unspent mutagen does

- Ascending moves all premutagen into mutagen 1:1. Nothing else converts it.
- **Unspent mutagen makes 0.1 larva/s each.** It sits outside the hatchery, expansion, ancestry and hatchery-mutation multipliers. Measured larvae/s (mutagen / hatchery mutants):

  | Mutagen / hatchery mutants | Larvae/s |
  | --- | --- |
  | 0 / 0 | 250,766 |
  | 10^6 / 0 | 350,766 |
  | 10^6 / 10^4 | 1,103,174 (= 250,766 × log10(10,010) + 100,000) |
  | 10^9 / 10^6 | 1.01505×10^8 |

  The game's own tutorial says the same: "Mutagen you haven't spent yet will produce some larvae, don't spend it all right away!"

#### B2.5 What mutagen buys

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
| Meat (`mutantmeat`) | production of each meat tier | log, v=0.1, c from 0.48 (drone) falling ×0.85 per tier to 0.022 (endless, `overmind6`) | drone 2,009 / 2,990 / 4,465 (1,024); hive 60.1 / 80.1 / 110.2 (40) |
| Rush (`mutantrush`) | larva rush power; meat and territory rush power | log, v=1, c=3; c=13 | larva rush 6.02×10^9 / 9.63×10^9 / 1.50×10^10 larvae (6.02×10^8); territory rush 5.8×10^27 / 9.5×10^27 / 1.5×10^28 (1.45×10^26) |
| Clone (`mutantclone`) | clone larvae power (raises only its cap) | log, v=1, c=1.8 | 1.61×10^11 / 2.51×10^11 / 3.86×10^11 larvae (2.51×10^10) |
| Warp (`mutantswarmwarp`) | swarmwarp power (longer skip) | log, v=1, c=2 | drones gained 5.2×10^30 / 3.1×10^31 / 1.7×10^32 (1.0×10^28) |
| Bat (`mutantbat`) | spell power, all spells (mirrors ignore it) | log, v=0.1, c=1 | 3.00 / 5.00 / 8.0 (1) |
| Territory (`mutantarmy`) | production of every territory unit | exp | goon 2.399×10^15 / 2.421×10^15 / 2.534×10^15 (2.384×10^15): ×1.06 at 10^9, ×2 only at 10^15 |

Nothing changes starting resources or unlock thresholds. `mutanteach` also carries the minimum levels 40 and 80 as constants (`initStat`), so the thresholds are fixed.

#### B2.6 Respec

- **Refund.** A respec refunds **all** mutagen spent in the mutagen tab at 100%: every unlock price plus every mutant bought, minus the free unit per unlock. Measured: 1e13 → spend 3.81×10^12 → respec → exactly 1e13 again. All mutants and unlocks go to 0, so the unlock prices restart at 1.
- **Paid respec.** It costs **30% of the current ascension cost** in energy. It also adds `respecEnergy` equal to the energy spent so far, which **wipes the discount** on the next ascension. Measured: the next ascension cost went from 152,103 to 2,974,830.
- **Free respec.** You have 4 to start, plus 1 on every 3rd ascension. A free respec keeps the energy credit.
- **When it is useful.** Only to change an unlock order or reallocate. A paid respec is costly just before an ascension.

#### B2.7 Crystals

Measured:
- With energy visible (nexus ≥ 1), a hatchery or expansion bought at least 30 min after the last grant gives 500 crystals. A purchase 60 s later gives nothing; 31 min later, another 500.
- Buying 500 energy with crystals raises energy by 500 and the cap by 500 for good (`mtxEnergy`, which survives ascension). It does not count as spent energy.
- After an ascension (nexus 0) hatcheries grant nothing until nexus 1.
- The owner's saves show this in use: 5,000 crystals at 14.5 h, then 8,500 crystal-bought energy at 20.1 h.

#### B2.8 Interactions with what the advisor already advises on

- **House of Mirrors and territory units.**
  - Mirrors are the premutagen engine (B2.1).
  - Each cast is also 2,500 spent energy, so it lowers the ascension cost ×0.966.
  - Mirrors need territory units to double. With no territory larvae at all (f=0) premutagen growth collapses to 0.2 log10/day. Stopping territory purchases once mirrors run (`f_mirror=0`) makes no difference, as the handoff found.
- **Lepidoptera** raise energy (the growth rate) and count as spent energy at 10 each.
- **Bats / spell power** do nothing for mirrors; neither does the bat mutation.
- **Clone larvae** only gets a larger cap from its mutation.
- **Nexus.** Nexus 2 to 5 energy counts as spent. All five are lost at an ascension and must be rebought: 49,125 energy plus meat and larvae. In the simulator that is the bottleneck of a new run: nexus 5 about a day in, with or without mutagen.
- **Achievement points and accomplished ancestry:** see B2.3.

### B3. Model check: the new simulator parts against the game

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

### B4. New in the second pass: every tier, numbers past 1e308, and the achievement check

- **All 20 meat tiers.** `sim.py` now models drone through endless (`K=20`).
  - Unit costs come from the game data: 1e16 and 1e19 for hive mind and arch-mind (pantheon4 and 5), then 1e23, 1e28, 1e34, 1e41, 1e49, 1e58 for overmind through endless.
  - Meat per hatch is the formula up to lesser hive mind, then the game's own rounded table values.
  - Twin price factors are ×10 up to arch-mind and ×12, ×14, ×16, ×18, ×20 for overmind through universal cortex. Endless has no twin upgrade: its row in the game requires an impossible `invisiblehatchery` 2.
  - `compare.py` and `ascension_compare.py` gained rows for the new tiers. The game's check scripts now report all 20 tiers, and every new row matches.
- **Numbers that cannot overflow** (`advisor/sim/bignum.py`). Large quantities are an `F`, a float subclass whose every operation is the ordinary float operation. So while results fit in a double they are bit-for-bit what the simulator always computed. An operation that would overflow returns a `Big` instead: a float mantissa with an unbounded integer exponent, 53-bit precision. A `Big` falls back to an `F` under 2^1000.
- **Proof that nothing moved.** `run_example.py` on both saves gives byte-identical output. `compare.py` on both saves and `ascension_compare.py` give the same rows as before; the only differences are added rows for the new tiers. The first pass's `ascension_strategy.py` tables are identical.
- **Check against the game past 1e308.** `advisor/modelcheck/bignum_check.py` edits the 20 h save to hold up to 1e600 of resources, twin levels up to 1,100, faster up to 200, 1,500 expansions, units on every tier up to endless and mutants up to 1e330. It compares 131 numbers with the game (up to 1e1100):
  - rates and production per unit on every tier
  - units per hatch, faster/twin/hatchery/expansion prices
  - one hour of idle production on every tier
  - a 1e200-hive purchase, and the premutagen roll of expansion 1,501

  The worst difference is 1.7e-6, the known rounded goon production. The game keeps only 20 significant digits, so 1e330 − 1e205 is 1e330 in the game; the simulator agrees.
- **Speed.** The simulator is about 2× slower than before on early-game runs and up to 15× slower on runs full of large numbers. The first pass's strategy script now takes about 10 minutes instead of 40 s. A 130-day long run takes about 1 minute at 5-minute check-ins.
- **New policy options, all off by default:**

  | Option | What it does |
  | --- | --- |
  | `faster_aware='multi'` | A tier may be climbed when buying it plus any number of its own faster levels, paid out of that purchase, brings its break-even under the horizon |
  | `push={'goal', 'share', 'base', 'twin_mult'}` | Feed every tier above the climb frontier toward the goal tier each check-in: half the tier below, 2% of the top growing tier. Keep those units from being spent on twins of the tier below unless 1e6× the twin's price is held |
  | achievement logging | `s.ach_log`; the ascension and mutation achievements are now earned by `ascend` / `apply_plan` |

- **Achievement check** (`advisor/modelcheck/achievement_check.js`).
  - It runs the real `AchievementsListener` on all 121 achievements. Each is not earned just below its threshold and earned at it.
  - Owning 10× a unit threshold without having bought it does not earn it.
  - A wrong event parameter does not earn it.
  - The ascension count is checked the way the ascend command does it.

  All 121 pass. `advisor/sim/achievements.py` turns this into ACHIEVEMENTS.md.

## Part C. Earlier analysis: objective most mutagen or most meat (first pass)

Written before the owner chose the achievement goal; A.8 lists what it overturns. Crystals were counted as energy here.

### C1. Conclusions

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

### C4. Strategy

#### C4.1 The objective

Mutagen compounds within a run, not across runs: it grows exponentially with mirror casts. Its uses between runs are either logarithmic (most mutations), asymptotic (frequency, nexus) or linear but small (0.1 larva/s per unspent mutagen). So "maximise long-run growth of mutagen per unit of real time" reduces to "maximise the in-run growth rate, then stop resetting".

Two objectives were scored, both from the 20.1 h save at fixed real-time marks:

- **A. Total mutagen**: held plus not yet activated. This is the natural prestige score, and the long-run growth objective.
- **B. Meat per second**: progress, standing in for "reach a milestone such as the next tier".

They give the same shape. B has a later break-even.

#### C4.2 When to ascend first

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
- The cost falls under the cap at hour 59 and under 72,135 at hour 64. With the saving rule (B2.2) the first ascension happens at **hour 84 (run age 4.3 d) with 4.4×10^7 mutagen**.
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

#### C4.3 What to buy first

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

#### C4.4 Later runs

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

#### C4.5 What this means for the existing in-run advice

All measured in run 2, after the first purchases, unless stated.

| Advice | Run-2 result | Implication |
| --- | --- | --- |
| Age multiple × run age as the climbing horizon | premutagen at 2 / 4 / 6 / 8 d: 3 → 8.20 / 13.32 / 18.44 / 23.51; 5 → 8.20 / 13.32 / 18.44 / 23.56; 10 and 20 within 0.05. Meat/s at 2 d: 50.2 (×3, ×5) vs 59.0 (×10); at 6 d: 91.5 (×20) vs 82.5 | For mutagen it does not matter: meat does not feed premutagen (hatchery premutagen is tiny next to expansions). Before the single first ascension, nothing measurable depends on it either (first ascension at hour 83 or 84). Replacing it with "time until the planned ascension" would only change meat that the ascension throws away. **Keep it for meat**; the MODEL-CHECK finding that bigger multiples win on long runs still applies, and runs after the first ascension are long. |
| Lepidoptera target 4,000 | 0 → +1.55/day; 4,000 → 2.56; 10,000 → 2.71 (ahead from ~6.5 d; +0.10 at 8 d); 30,000 → 2.78 (behind until ~3 weeks) | Lepidoptera now pay for themselves through the growth rate, on any run that matters. Raise the target to 10,000 once a run is meant to last more than about a week. Before the first ascension, 4,000 is fine: more only shifts when the ascension can happen by about 2 h. |
| House of Mirrors from nexus 5, whatever the run length | swarmwarp instead: +0.15/day vs +2.56/day | Mirrors are right on every run, short ones included, when the goal is mutagen. The handoff's "about 25× worse meat on runs under 2 to 3 days" is a meat-only effect. |
| Territory: 10% of larvae, nothing after mirrors start | f = 0 throughout: +0.20/day (collapse); 0.3: same as 0.1; stop after the first mirror: same | Keep it. Mirrors need a base of territory units to double. |
| Energy plan | n/a | Add an ascension reserve when an ascension is planned: keep casting mirrors until the cost is ≤ min(cap, 72,135 × N), then stop all energy spending and save. Crystals: convert to energy every visit; the cap gain is permanent. Never pay for a respec just before an ascension. |

### C5. What an ascension panel could show (proposal, not built)

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
- Two settings from the player: **how long they plan to keep playing**, which decides line 2's "worth it" (C6), and whether to count crystals.

### C6. Questions for the owner

| Question | Why it matters | Findings that change |
| --- | --- | --- |
| **What is the goal?** Most mutagen (prestige), most meat or the next tier (progress), or achievements (an ascension is worth +10 points) | Objectives A and B agree on when to ascend and on the first unlock. They differ on the second unlock: frequency for mutagen, meat or hatchery for meat (10^3 at 6 d). | #4's second pick; the break-even (4.7 vs 6.2 d) |
| **How many more days will you play?** | The whole case for ascending rests on playing at least 5 to 6 more days after it. Under that, never ascending wins. | #3, and whether line 2 says "ascend" at all |
| **How often do you check in, and how long are you away?** | Crystals scale with visits: 500 per visit, at most one per 30 min. The energy cap (58,500 to 108,000) holds 18 to 30 h of energy, so mirrors can be cast in batches without loss. | #7: the ascension is about 14 h later without crystals, and growth is 20% lower; the break-even moves accordingly |
| **How long are you willing to let a run go?** | After the first ascension the best run is open-ended. If you would rather restart periodically anyway, that costs about 10^8 per restart (C4.4). | #5, #6c |
| **Will you respec?** You have 4 free ones. | A free respec could undo a poor unlock order at no cost; a paid one wipes the ascension discount. | Only matters if the first unlocks were already bought differently |
| **Which time zone does your browser use?** | Only for predicting individual rolls exactly; the mean is within 0.3 log10. | Line 1's "spawns: yes/no" if computed outside the game |
| **Do you buy crystals with money or only earn them?** | Bought crystals are more energy: an earlier ascension and faster growth. | #3 timing, #7 |

### C7. Not verified, not modelled, inferred

- **One save, one simulator.**
  - All strategy numbers start from the 20.1 h save and follow the tuned policy at one check-in per minute.
  - A person's next run will reach nexus 5 later than the simulator's (about a day), so the break-evens are probably 1 to 2 days longer.
  - The *shape* follows from the mechanics (growth rate = energy income) and is the more reliable part.
- **Policies not re-tuned for run 2 or later:** climbing, twins, territory share, nexus timing. Lepidoptera and age multiple were spot-checked (C4.5); nothing else was.
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

## Part D. Reproduce

```sh
cd advisor/modelcheck && npm install && cd ../..                 # once; node on PATH (Node 22 used)
python3 -I advisor/modelcheck/ascension_compare.py              # game vs sim, about 15 s; also advisor/modelcheck/out/ascension_compare.md
python3 -I advisor/sim/achievements.py                          # ACHIEVEMENTS.md, with the code check, about 5 s
python3 -I advisor/sim/achievement_strategy.py                  # Part A tables, about 8 minutes (--quick: base policy only, ~2 min)
python3 -I advisor/modelcheck/bignum_check.py                   # game vs sim past 1e308, and territory empower, about 3 s
python3 -I advisor/sim/longrun_rules.py --jobs 4                # A.10 pass-4 tables (honest, advisor, final4, early4), about 8 minutes with 4 cores
python3 -I advisor/sim/longrun_rules.py diag rules rounds glance final early empower --jobs 4   # the pass-3 tables (artefact), about 15 minutes
python3 -I advisor/modelcheck/longrun_cases.py                  # A.10 reference cases for the port + round trip in the game, about 40 s
python3 -I advisor/sim/cadence.py                               # the visit profiles
node advisor/modelcheck/achievement_check.js                    # every achievement through the game's listener (JSON), about 4 s
python3 -I advisor/sim/ascension_strategy.py                    # Part C tables, about 10 minutes (was 40 s before big numbers)
python3 -I advisor/sim/ascension_strategy.py curve timing       # just C4.2
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
