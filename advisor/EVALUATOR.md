# One purchase evaluator for the meat tiers (design study, Nov 25, 2026)

**The owner's concern:** "I'm concerned by how patchwork this all feels."

The advisor's meat-tier advice is a port of a console script's heuristics, with corrections bolted on, each behind a hidden switch:
- the script's heuristics: the run-age horizon test, share per minute, the 60 s cooldown, banking ratio 3, "hold 2× the price" for faster and twin tips, twin plans;
- the corrections: FA, SEED, twin detours, "free now" plans, plain banking.

Every defect the owner found had the same cause: the advisor did not compare the available purchases on one scale. So it left a resource idle, or took a dearer path.

This document designs one evaluator to replace that set of rules, and tests it. Status:
- **The design holds up on the owner's seven saves** (section 5), with no special cases.
- **The simulator comparison (section 6) is a loss:**
  - swarmwarp is not finished by day 500;
  - first endless is 4–6 days later on every route;
  - the mirrors-route finish is the same.
- **The adversarial pass is in section 7.**
- **What I am unsure of is listed in section 9.**

The prototype is `advisor/sim/evaluator.py`, used in the simulator by `evaluator=True`. Its reference cases are in `advisor/modelcheck/evaluator_cases/`.

## 1. The scale: meat by the horizon

**One number for everything.** The evaluator compares every purchase by the meat the hive will have made by a horizon T, if nothing else were bought after this look.

**A unit's value.** The game's production chain gives that value exactly. One unit of tier j, left alone, makes this much meat by time T:

  **v_j(T) = P_1 × P_2 × … × P_j × T^j / j!**

where:
- P_i is tier i's prodEach (base × 2^faster × mutation);
- meat is v_0 = 1.

This is the game's own polynomial: the simulator's `advance` uses the same coefficients.

**A flow's value.** A flow of r units of tier j per second, kept up over [0, T], is worth r × v_j × T / (j + 1).

**The script's rules are special cases of this scale.** That is the main reason to trust it:

| The script's rule | What it is on this scale |
| --- | --- |
| Rule 1: a tier passes when H_k = k × cost / (twin × prodEach) ≤ horizon | A hatch of tier k gains 2^twin × v_k and spends cost × v_(k−1). The ratio is twin × P_k × T / (k × cost), so it pays exactly when T ≥ H_k. **The factor k is the one between a tier's value and the tier below** (T^k / k! against T^(k−1) / (k−1)!). |
| The twin plan's (k + 1) × cost / rate | A twin of tier k paid in tier-k units (the hatches that make tier k+1) gains a flow of tier-k units. A stock of tier k grows like T^k / k!, a flow over T like T^(k+1) / (k+1)!. So the payback is (k + 1) × cost / added rate. **(k + 1) is the same factor, one tier up.** |
| Faster tip at 2× the price | With N units held and price F, the level leaves N − F units at double rate: 2(N − F) against N. The break-even is N = 2F, at every horizon. **The 2× is exact for the tier's own stock, but it is only part of the value:** a faster level of tier k also doubles v_j for every tier above k, because their meat passes through tier k. In the 7.2 d (later) save, neuroprophets hold 1.1× the price, and the level doubles the meat by T of every hive neuron and neural cluster. |
| Twin flow test (twin_flow, rule 7 plain): the twin's added flow beats what its price in tier k+1 would make | When the price is held in tier k+1, a twin of tier k gains r × v_k × T/(k+1) and spends c × v_(k+1) = c × P_(k+1) × v_k × T/(k+1). **T cancels:** buy when r > c × P_(k+1). This is the plain twin rule, at every horizon. |

**Larva-limited against unit-limited.** Larvae have no value of their own. They take the value of what they hatch:
- **μ** is their shadow price: the value per larva of the last tier the look's larvae go to, or 0 when larvae are left over.
- A unit's value at its best use is **w_j = max(v_j, (2^twin_(j+1) × w_(j+1) − meat cost − μ) / cost_(j+1))**: keep it, or hatch it into the tier above when that is worth more.
- **A unit-limited tier** (more larvae than its stock can pay for): its units are worth w > v, because they become the next tier. A twin or faster level paid from them is charged that.
- **A larva-limited tier:** μ is high, the conversion term vanishes, and w = v.

This is what banking tried to express: it compared "the tier above makes more than larvae could" with a twin divisor that was wrong. Here banking is not a rule; it is the larvae going where they are worth most (section 2).

**The horizon.**
- **Kept as today:** T = age multiple × game-clock run age (multiple 5). One setting.
- **Why not "better grounded":**
  - the run's expected remaining time did nothing in A.10.9 (candidate a);
  - an ascension-aware horizon needs the route to say when it will ascend.
- **Where the horizon matters most:** section 7, case A1. Note that **T enters only through the scale**; no rule has its own horizon any more.
- **Unsure (section 9):** whether T should be capped by the time to a planned ascension.

## 2. The look

The look starts from what is available:
- the larvae after territory and the nexus hold;
- half the meat (the evaluator's one other setting; meat's other uses, territory and hatcheries, sit outside it);
- each tier's stock, twin levels and faster levels.

**The objective:** J = meat by T of the stocks held, plus what this look's hatches add, plus the steady flows over T.

**Every candidate is scored by how much it raises J.**

1. **The hatches (the allocation).** Each tier k whose hatch raises J gets larvae in order of value per larva:
   - value per larva = 2^twin_k × v_k − cost_k × v_(k−1) − meat cost, with any faster levels of k paid out of the result if that is worth more (this is FA, without a rule);
   - each tier takes up to the least of its stock (tier k−1 / cost), the meat budget and the larvae left;
   - the larvae left over (if any) set μ = 0; otherwise μ is the last tier's value per larva.
2. **The steady flows.** The same order applied to larva income per second. Each tier is capped by its income, which is what tier k makes of tier k−1 after this look's hatches, and by the meat income's share. This gives r_j, the units per second of each tier over the horizon.
3. **The candidates** (each re-planned on the ledger of what is left):
   - **a faster level of tier k** from stock;
   - **1 to 3 twin levels of tier k.** The price is in tier k+1: from stock, else by hatching tier k+1, from tier-k stock or from tier k hatched first. Before that hatch, up to two levels of tier k+1's own twin may be bought (the detour), keeping whichever leaves J highest. This covers the owner's catches 3 and 6;
   - **twin jumps:** 6, 12, 24, 48 or 96 levels of tier k at once, for tiers at or above the current larva sink. **This is what replaces SEED** (section 4).
4. **Pick the candidate that raises J most, apply it to the ledger, repeat** (at most 12 picks). Then the larvae left go to the hatches of step 1. **Nothing is left idle while a hatch raises J.**

**The order between looks and the pacing.**
- **No share per minute and no 60 s cooldown:** a hatch that raises J takes all it can.
- **Thrash** would need a purchase that raises J at one look and an undo that raises it at the next. Hatches and upgrades cannot be undone, and J only grows with T, so nothing alternates.
- **The cost of dropping the shares** is that each look's advice depends on the stock since the last look, not on a per-minute rate. For a person looking a few times a day that is what they want.
- **What I cannot rule out without the native port:** the script's share rules were there to make advice stable across checks a few seconds apart. Section 6 measures ideal (5 min) and human cadences.

## 3. What the player is told

**One ranked list,** top to bottom, each line with its reason and payback:

```
1. faster neuroprophets (5.03e35 of your 5.56e35)           +100% meat by the horizon, pays back in 2.9 h
2. hatch 1.94e18 neural clusters, then 1e9 lesser hive minds, then twin neural clusters (level 10)
                                                            +56%, pays back in 21.5 h
3. hatch 2.07e17 neural clusters                            pays back in 14.7 h
4. hatch 1.07e18 hive neurons with the rest of your larvae
   (next best, not affordable together with 2: twin hive neurons (level 22) +48%, 9.5 h)
```

- **"Pays back in"** is the horizon at which the line stops raising J (bisection over T). It is the same quantity for a hatch, a faster level and a twin.
- **A tier that does not pass** shows "wait": the time until the age multiple × run age reaches its payback. This is today's line, explained as before (MODEL-CHECK.md).

## 4. What becomes of each rule

| Rule today | In the evaluator |
| --- | --- |
| Rule 1 (H ≤ multiple × age) | **A consequence**: a hatch raises J exactly when T ≥ H |
| Rule 3 sizing (share per minute, spare, 60 s cooldown) | **Gone**: a hatch that raises J takes what it can; order by value per larva |
| Rule 4 banking (and its divisor) | **Gone**: larvae go by value per larva, so a tier whose larvae are worth more elsewhere gets none |
| Faster tips at 2× | **A consequence**, and wider: J counts the level's effect on every tier above |
| FA (faster-aware climbing) | **A consequence**: a hatch candidate includes the faster levels it can pay for |
| Twin tips at "hold 2× the plan's cost", rule 7 with or without the divisor, twin_flow, twin_used | **Gone**: a twin is a candidate with its price and the flow it doubles |
| Twin plans, the prefix, the detours, "free now" | **One mechanism**: `acquire` (stock, else hatch, else hatch the tier below first; up to two detour levels) |
| SEED (1% of every tier above the frontier) | **Meant to be replaced by twin jumps. Not achieved:** section 6 shows the swarmwarp route still stalls and endless comes later. See the note below |
| The long-run mode, LR-0 to LR-4, the twin guard | Already gone; LR-4 (lepidoptera) stays a route target |
| Age multiple (5) | **Kept**: the one horizon setting |
| Meat share (0.5 of meat for hatches) | **Kept, with a reason**: meat's other uses (territory, hatcheries, expansions) are outside the evaluator |

**SEED and why jumps replace it.** A first prototype without jumps reproduced "seed off": the swarmwarp route never finished. The cause was a non-convexity:
- once a low tier has many twin levels, a tier above is worth less per larva until it too has dozens of twin levels;
- no single level raises J, so a step-by-step greedy never starts it.

In the trap the prototype found, queens had twin 80 and nests twin 0. It never hatched a nest, and meat stalled at 1e133. SEED escaped by feeding every tier a little regardless of value. The jump candidate asks the question directly: "would 6 / 12 / 24 / 48 / 96 levels of this tier's twin, with the hatches that pay for them, raise J?" Once enough levels make the tier the larva sink, J says yes.

**The switches** (`bankTwin`, `seed`, `fasterStart`, `twinDetour`, the long-run setting):
- they become one compatibility key, `purchaseRule: 'evaluator' | 'script'`;
- `'script'` keeps today's rules for the console-script comparison and is not offered in Options;
- the age multiple stays in Options.

## 5. The owner's seven catches

From `advisor/sim/evaluator_saves.py` (cases in `advisor/modelcheck/evaluator_cases/`). Horizon = 5 × run age. Territory share 0.1 on the first-run save, 0 on run 2 (mirrors cast). Saves (3) `twin_3d` and `run2_72h` are the same file.

| # | Save | The catch | The evaluator's first purchases | Falls out? |
| --- | --- | --- | --- | --- |
| 1 | 58 h first run | 66 hive queens + a faster level make the tier pay back | **hatch 1e4 hive queens + 1 faster** (payback 140 h against a 290 h horizon), then hives and greater queens | yes: the hatch candidate includes the faster levels it pays for |
| 2 | run 2, 45 h | can afford 1.04e7 empresses, no faster tip | **twin hive queens (level 8), paid by hatching 1e7 empresses** (+99% J, 0.6 h). Then hive queens and hives. Empresses + 2 faster levels: payback 404 h against a 226 h horizon, so not yet | yes, and it answers the question: the empresses go into a better use (a twin that doubles every hive-queen hatch); the faster level alone is not worth it at this age |
| 3 | run 2, 3.0 d | twin plan hatched 1e10 prophets directly; the detour through the prophet twin costs 40% less | **twin empresses ×2 via the detour**: 1e9 prophets → 1 hive neuron → twin prophets → 5e9 prophets → … (+246% J, 16.7 h) | yes: `acquire` chooses the detour because it leaves J higher |
| 4 | run 2, 7.2 d | 1.26e22 larvae idle, every tier banked; larvae 45× the better source of hive neurons | twin hive neurons ×2 (below), then **hatch 9.35e21 hive neurons: no larva left idle** | yes: no banking; larvae go by value per larva |
| 5 | same | twin tips hidden by the divisor | **twin hive neurons ×2**: the first from 1.4e19 neural clusters held, the second by hatching 3.75e17 neural clusters (+285% J) | yes: no divisor anywhere |
| 6 | run 2, 7.2 d (b) | the hive-neuron twin's price could be hatched at once (payback 26 min), no tip; neural-cluster twin first is cheaper | **twin hive neurons, via the neural-cluster twin first**: 3.72e17 neural clusters → 1e8 lesser hive minds → twin neural clusters → 1.95e17 neural clusters → twin hive neurons (+263% J, 4.0 h). 5.67e17 hatches in all, against 7.63e17 for the two twins bought separately | yes |
| 7 | run 2, now (**the current prototype**: the J version. An earlier first-prototype listing ranked the hive-neuron twin first, at 9.52 h; that listing is superseded) | hive-neuron twin level 22 (1e21 neural clusters = 1.94e18 hatches of 2.15e18 affordable) pays back in ~57 min of income; silent because of "hold twice the plan's cost" | ranked: **faster neuroprophets** +100% (2.9 h), **twin neural clusters** +56% (21.5 h; same price, 1e21 neural clusters), **twin hive neurons** +48% (payback 9.5 h = (k+1) × the owner's 57 min). The neural-cluster twin is taken, then the hive-neuron twin is no longer affordable | yes: the hive-neuron twin qualifies with the owner's numbers. It is outranked by an equally priced twin one tier up and by a faster level the old rules never offered (neuroprophets held 1.1× its price) |

**Unsure on 7.** Under J the two twins are close (56% against 48%). The pantheon twin wins because the flow model values hive neurons at their best use: hatched into neural clusters. With 2.7e18 larvae/s and hive neurons coming from both larvae and neural clusters, the steady flows are an approximation (section 9).

## 6. The simulator: the evaluator against the current rules

`advisor/sim/evaluator_sim.py ideal human1` (out: `advisor/modelcheck/out/evaluator_sim_ideal_human1.json`).

The two policies:
- **current:** plain banking on pre-climb counts, FA c2, SEED 1%, twin rules, rule-3 sizing;
- **evaluator:** everything above replaced by `evaluator.py`.

Energy, territory, hatcheries, routes and mutagen are the same in both. Days from each save.

**The result is a loss.** The evaluator does not finish the swarmwarp route within 500 days. Endless comes later on every route. Only the mirrors-route finish day is unchanged.

| Start | Cadence | Variant | All done | First endless | 1e62 endless | 5,000 exp | First ascension (day, log10 premutagen) | Nexus 5, runs 1 / 2 (h) | log10 meat/s, days 1 / 3 / 7 / 20 / 60 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| swarmwarp | ideal | current | **84** | **51** | **56** | 82 | 3.9, 6.7 | 9.9 / 10.6 | 45 / 59 / 84 / 194 / 2 (just ascended) |
| swarmwarp | ideal | evaluator | **not by day 500** | **57** | **67** | never | 3.9, 6.7 | 9.9 / 10.6 | 44 / 60 / 86 / 230 / 1039 |
| swarmwarp | human 1 | current | **98** | 57 | 61 | 98 | 4.2, 6.5 | 19.0 / 22.7 | 45 / 50 / 52 / 237 / 1332 |
| swarmwarp | human 1 | evaluator | **not by day 500** | 59 | 70 | never | 4.2, 6.6 | 19.0 / 25.3 | 44 / 57 / 54 / 297 / 1434 |
| mirrors (20.1 h) | ideal | current | 174 | **50** | 58 | 100 | 3.9, 7.8 | 9.9 | 45 / 61 / 78 / 313 / 1221 |
| mirrors (20.1 h) | ideal | evaluator | 174 | **55** | 58 | 100 | 3.9, 7.7 | 9.9 | 44 / 61 / 78 / 314 / 1221 |
| mirrors (20.1 h) | human 1 | current | 181 | 52 | 60 | 101 | 4.2, 8.2 | 19.0 | 45 / 55 / 60 / 272 / 1198 |
| mirrors (20.1 h) | human 1 | evaluator | 183 | 56 | 59 | 101 | 4.2, 8.1 | 19.0 | 44 / 59 / 61 / 282 / 1201 |
| run 2 at 3.0 d | ideal | current | 167 | 44 | 51 | 93 | – | 10.2 (run 2) | 85 / 106 / 187 / 451 / 1365 |
| run 2 at 3.0 d | ideal | evaluator | 167 | 48 | 51 | 93 | – | 10.2 | 82 / 105 / 192 / 452 / 1365 |
| run 2 at 3.0 d | human 1 | current | 171 | 44 | 52 | 93 | – | 11.7 | 85 / 104 / 174 / 446 / 1361 |
| run 2 at 3.0 d | human 1 | evaluator | 172 | 49 | 52 | 93 | – | 11.7 | 82 / 104 / 174 / 449 / 1363 |

Busy was not run.

**Where it is no worse:**
- first runs: first ascension and nexus 5 are the same;
- the mirrors-route finish: equal ideal, +1 to 2 days human;
- meat on the swarmwarp route until about day 20: equal or higher (day 20: 10^230 against 10^194).

**Where it loses:**
- **Swarmwarp, ideal:** ascensions keep pace with the current rules to about ascension 8. They then fall behind: 10^200 premutagen at ascension 17 on day 69, against 10^219 by then. **After ascension 17 (ideal; 18 for human) it never ascends again.**
- **First endless:** 4–6 days later on every route. 1e62 endless is 11 days later on the swarmwarp route.

**Diagnosis, partly confirmed.**

*The swarmwarp stall.* Its state on day 72 (ascension 17, build stage):
- game-clock run age 1.9e6 h, so T = 9.7e6 h;
- larva income 1.2e199/s, with **no larvae left after any look**.

The tier table at that state was not printed: the diagnostic crashed formatting a number past 1e308, and I was told not to run another long pass. **What is confirmed:** the run spends every larva and still never reaches the ascension test, so this is not idle larvae. The same signature (all larvae spent, meat stalled, no ascension) was confirmed in tier detail for the first prototype, without jumps: drones and queens with 100 and 80 twin levels, nests at 0, meat stuck at 1e133 (section 4).

**My best explanation, not confirmed:** the same non-convex trap, one level up. The jump ladder stops at 96 levels. On the swarmwarp route the game-clock horizon is enormous (T ≈ 10^7 h), so the flows of whichever tier holds the larvae dominate J. Every twin of that tier "pays", and the larvae are spent pumping it. A tier above needs more than 96 twin levels to overtake it, so no jump raises J.

*First endless later on all routes.* Rule SEED starts every tier above the frontier from the first look, at 1% of the tier below. The evaluator starts a tier only when a hatch, twin or jump raises J at T = 5 × age. So the top tiers (cosmic network to endless) start later. Expansions and the mirrors-route finish are set by energy, so the finish day does not move.

**Why the last pass took 5,735 s against 321 s for the first:**
- **J is a full re-plan** (allocation, flows, best-use values, all in big numbers). The second prototype computes it for every candidate (about 20 tiers × 3 twin levels + 5 jumps + faster levels) at each of up to 12 picks per look. Inside `acquire` it computes J again for each detour option. The first prototype scored candidates with one gain/cost formula.
- **Past 1e308** every operation goes through the Python big-number class, about 10× slower.
- **The two swarmwarp runs that never finish** simulate 500 days instead of 84–98, which is about 6× the looks.


## 7. Adversarial pass

`advisor/sim/evaluator_adversarial.py` builds states meant to make the evaluator do what a careful player would call wrong.

| # | State | What the evaluator does | Verdict |
| --- | --- | --- | --- |
| A1 | 3.0 d save, but the run will ascend in 2 h | At the age horizon (364 h) it buys **twin empresses ×2** via the detour. That pays back in 16.7 h, so with 2 h left it never pays. At a 2 h horizon it buys nothing but empresses | **Wrong if the route ascends soon.** The evaluator is only as good as its horizon. The current rules share the flaw. Fix: cap T at the route's time to its next ascension (section 9) |
| A2 | 58 h save at a horizon just under hive queens' H (250 h) and at 5 × age (290 h) | The same purchases in both: hive queens + 1 faster pass on the faster level at 250 h too, and no twin is bought for the tier that is about to lose the larvae | **Fine** |
| A3 | run 2 now: neuroprophets held at 1.1× the faster price | Buys the level (+100% J): it doubles the meat by T of every hive neuron and neural cluster. It spends 90% of the neuroprophets, which the hive neurons remake in ~30 min | **Fine**, and a purchase the old 2× rule hid. A3b (hive neurons cut to a millionth): still buys it, still right, because the level doubles the upper tiers' value whatever their size |
| A4 | run 2 now with larvae and larva income cut a millionfold | All larvae into neural clusters, none into hive neurons; the faster level as above | **Fine**: larvae go where each is worth most |
| A5 | The trap of section 4: queens with twin 80, nests with none (found by the simulator on the swarmwarp route, run 12, without jumps) | Without jumps: hatches only queens and buys queen and drone twins every look. Meat stalls at 1e133 and the route never ascends again | **Wrong**, and the reason for the jump candidates. With jumps the route no longer stalls (section 6). **A state needing more than 96 levels would still trap it.** |
| A6 | The steady flows assume the current larva sink keeps the larvae for the whole horizon | A twin of the sink is valued over up to T of larva income, even when a tier above will take the larvae within hours. In the 45 h save the hive-queen twin (+99% J) pays back in 0.6 h, so this does not bite there. I did not find a save where it does | **Unsure** (section 9) |
| A7 | "Hold nothing back": a hatch that raises J takes the whole tier below | A tier below that is short of its own faster price never accumulates 2×. That is harmless: the faster candidate no longer needs 2× (A3) | **Fine** |


## 8. Spec for the port

Inputs at a look, all already in the native snapshot:
- each meat tier's count, twin level, faster level, prodEach (with the mutation), cost in the tier below, meat cost;
- twin price (TWINF_k^level in tier k+1) and faster price (66 × 666^level in tier k);
- larvae for the look (after territory and the nexus hold);
- larva income (larvaRate × (1 − territory));
- meat;
- the horizon T = age multiple × game-clock run age.

```
values(T):   v[0] = 1;  v[j] = v[j-1] * prodEach[j] * T / j                       (big numbers throughout)
allocate(L): for each tier k with n = min(L, count[k-1]/cost[k], meatBudget/meatCost[k]) >= 1:
                 nv(k, n) = best over F = 0.. faster levels paid from the result of
                            (count[k] + n*2^twin[k] - priceOf(F levels)) * 2^F * v[k] - count[k]*v[k] - n*(cost[k]*v[k-1] + meatCost[k])
             keep the tiers with nv > 0; sort by nv / n; give each its n from what is left; mu = nv/n of the last one
             if the larvae ran out, else 0
flows(rate): the same order with larva income per second; tier k capped by (count[k] + this look's hatch) * prodEach[k] / cost[k]
             and by half the meat income / meatCost[k]; r[k] = hatches/s * 2^twin[k]
best use:    w[j] = max(v[j], (2^twin[j+1] * w[j+1] - meatCost[j+1] - mu) / cost[j+1]), top down; deg[j] = degree of w[j] in T
J(ledger)  = meatBudget + sum_j count[j]*v[j] + sum of the allocation's nv + sum_j r[j]*w[j]*T/(deg[j]+1)
acquire(j, amount, depth, down): stock; else hatch ceil(need / 2^twin[j]) of tier j from tier j-1 stock (or, down > 0,
             hatch tier j-1 first); with depth > 0 also try 1 and 2 levels of tier j's twin first (each paid by acquire
             one tier up); keep the option with the highest J
candidates:  faster level of k (price held); twin of k, 1-3 levels, each paid by acquire(k+1, price, depth 1, down 1);
             twin jumps of k, 6/12/24/48/96 levels paid at once (depth 0), for k at or above the highest tier the
             allocation hatches
look:        repeat up to 12 times: score every candidate by J(after) - J(before); stop when none is > 0; else take the
             best, record its steps; finally the allocation's hatches (with their faster levels)
payback:     the smallest T at which the line still raises J (bisection on log T), shown on each line
```

**Reference cases:** `advisor/modelcheck/evaluator_cases/*.json`, from `python3 -I advisor/sim/evaluator_saves.py --write`. There is one case per owner save: 58h, run2_45h, twin_3d (= run2_72h), run2_7d (catches 4 and 5), run2_7d_b, run2_now. Each case holds:
- the horizon, the larvae for the look, larva income and the meat share;
- log10 v_j per tier (to check the scale first);
- the purchases in order, with their steps (hatch / twin / faster, amounts as numbers), the % by which each raises J, and the payback;
- the first pick's ranked alternatives.

**What must match:**
- **exact:** the order and kind of the purchases, and the hatch amounts of twin plans (ceil);
- **to 1e-6 relative:** log10 v_j;
- **to 1e-3 relative:** the % raises and the paybacks.

The final allocation's hatch counts depend on the larvae-for-look the port computes; **compare them given the case's `larvae_for_look`.**


## 9. Where I am unsure

- **The horizon.** T = 5 × run age is inherited, not derived. It is grounded only by the fact that rule 1 is "a hatch pays by T". Near a planned ascension it overstates what pays (A1). The fix would be T = min(5 × age, time to the ascension the route plans), and it needs the route's own estimate.
- **The steady flows.** A tier's income counts what the tier above makes of it plus this look's hatch. It ignores the units the tier below receives from larvae, beyond the best-use value w. In catch 7 that decides between two near-equal twins. A full steady-state solve of the chain (larvae, income and conversion together) would be more exact; I have not shown it would change a decision that matters.
- **Twin jumps** are a fixed ladder (6 … 96 levels). A tier that needs more than 96 levels to become the larva sink would not be started. I have not seen one in the simulator, but the trap is real (section 4).
- **The meat share** (0.5) is a kept constant, not a consequence.
- **Speed.** About 30 ms per look in Python at a 12-tier state, more past 1e308. The port's big numbers are slower; the 12-pick cap and the jump ladder are the knobs.
- **Detour depth** is 1 (with one recursion down). A plan needing two nested detours would be priced at the direct cost.
- **Only meat tiers.** Territory, energy, hatcheries and expansions keep their own rules. They could join the same scale later: a hatchery or expansion adds larvae, and the evaluator already knows a larva's value μ.

## 10. Recommendation (as of Nov 26, 2026)

**(b), a hybrid:**
- keep today's hatch rules for the climb: rule-3 sizing, plain banking on the counts before the climb, rule SEED;
- use the evaluator's scale only to **rank and size faster and twin candidates**, including `acquire` with detours.

**Why:**
- **The part that is right is the upgrade part.** The upgrade candidates are what answered catches 2, 3, 5, 6 and 7, and what found the faster neuroprophet level. Catch 4 is already fixed by plain banking.
- **The part that loses is the hatch part.** Replacing the climb loses the swarmwarp route. My best explanation is a non-convex trap that the jump ladder does not escape, and it is not yet confirmed.
- **The hybrid needs one simulator pass to show it is no worse.** I expect it to run near the current rules' speed: J is only needed for the upgrade candidates, a few per look. That is my estimate, not a measurement.

**(a), fix the full evaluator and re-measure,** would need two things:
- one diagnostic run to see the stalled state (about 15 min);
- then a fix, probably one of: an open-ended jump search (levels until the tier becomes the larva sink, not a fixed ladder of up to 96); T capped by the time to the next ascension on the swarmwarp route; or keeping SEED.

One full pass at the current speed is about 1.6 h on 4 cores, and less if it finishes. I would not choose it while usage is scarce.

**(c), drop it,** throws away the one measurable gain: the upgrade ranking that handles the owner's catches without special cases.

## 11. The hybrid (Nov 26, 2026): evaluator for upgrades only. **Fails on the swarmwarp route**

**What it is:**
- Option `evaluator='upgrades'` in `sim.py`; `evaluator.upgrades()` in `evaluator.py`.
- Hatches are exactly today's native defaults: rule 1, share sizing and the cooldown, plain banking with `bank_pre`, FA, and rule SEED.
- The evaluator decides only:
  - a faster level of tier k from stock;
  - 1–3 twin levels of tier k, paid through `acquire` (stock, hatch, hatch the tier below first, up to two detour levels).
- There are no jumps. It replaces the 2× faster rule, the twin rules (`twin_r`, `twin_flow`, `twin_used`), twin plans (`twinseek`) and the prefix.

**How they share the look:**
- The upgrades go first: where today's faster/twin rules and twin plans sit, before territory and the climb.
- They work on a ledger of the climb's larvae (larvae − reserve − nexus hold) and half the meat. What they spend is gone before the climb runs.
- Candidates are scored on J with two parts:
  - **the larva price:** the evaluator's own allocation of the larvae left (μ, the larvae's best use). An upgrade that spends larvae is charged their highest value, which is conservative;
  - **the flows:** what the hatches will make over the horizon. These were first the evaluator's own; the fix below changed them to today's climb.

**Fix attempt (the one allowed).** On the first pass the swarmwarp route stalled after ascension 14. The day-62 state showed why: twin levels piled on the tiers the evaluator's own allocation hatches (drone 99, queen 101, empress 111, neural cluster 105), and 0 on the tiers SEED and the climb actually hatch (lesser hive mind and up). The evaluator valued flows that today's climb does not make.

**Fix:** J's flows are the hatches today's climb made at the last look, divided by the gap (`ev_flows='climb'`). Twin candidates are considered only for tiers with such a flow.

**Days from each save (ideal / human seed 1); the current rules are from section 6:**

| Start | Current | Hybrid, pass 1 (evaluator flows) | Hybrid, pass 2 (climb flows, the fix) |
| --- | --- | --- | --- |
| swarmwarp: all / first endless / 1e62 endless | 84, 51, 56 / 98, 57, 61 | **not by day 250** / not by day 250 | **not by day 250** / **not by day 250** |
| run 2 at 3.0 d | 167, 44, 51 / 171, 44, 52 | 167, 43, 51 / 171, 44, 52 | 167, 43, 51 / 171, 44, 52 |
| mirrors 20.1 h | 174, 50, 58 / 181, 52, 60 | 174, 50, 58 / 181, 52, 60 | 174, 50, 58 / 181, 52, 59 |

- **The mirrors route and run 2 are equal or a day better.** First ascension, nexus 5 and the meat marks are equal within 1–3 log10.
- **The swarmwarp route, pass 2, ideal:** the hybrid matches the current rules to the decimal through ascension 11 (day 42.5, 10^81 against 10^82 premutagen). After that each ascension brings only about 10^3 more, against 10^10 to 10^30 for the current rules:
  - ascension 16 on day 66 brings 10^96, against 10^190 by then;
  - ascension 18 comes on day 126, and the route is not finished by day 250.

  At human cadence it reaches ascension 16 by day 75.

**The drain check (risk 2).** Every twin level bought, out of all levels:

| Run | Levels bought | Spending ≥ half the paying tier's stock | An upper tier (top or next) paying for a tier 3+ below |
| --- | --- | --- | --- |
| swarmwarp, current rules | 22,655 | 2,452 (11%) | 0 |
| swarmwarp, hybrid pass 2 | 15,740 | 7,015 (45%) | 0 |
| mirrors and run 2, current rules | – | about 4% | 0 |
| mirrors and run 2, hybrid | – | about 98% | 0 |

- **The pattern I was asked about did not show:** no upper tier paid for a twin of a tier three or more below it.
- **A drain one tier up did show:** almost every hybrid twin level spends at least half of the tier above, which is often the tier SEED and the climb have just started. That pattern is the likeliest cause of the late swarmwarp runs flattening. **Not confirmed:** I did not capture a late-run state after the fix.

**Speed:**
- The pass took **3,920 s** wall (pass 1, after pruning twin candidates to tiers with a flow) and **6,910 s** (pass 2). The current rules take 18–89 s per run.
- The cost is J: a full re-plan in big numbers, for every candidate, at every look, at a 5-minute cadence.
- **The 5-minute target was not met.**

**The seven saves under the hybrid.** At a single save there is no last look, so the flows are the evaluator's own allocation (`ev_flows='evaluator'`); in the simulator they are the climb's. The upgrade purchases are the full evaluator's minus its hatches:

| Save | The hybrid's upgrades | Differs from the full evaluator |
| --- | --- | --- |
| 58 h | none; the climb's FA hatches 1e4 hive queens + 1 faster | no |
| run 2, 45 h | twin hive queens (by hatching 1e7 empresses), +99% | no |
| run 2, 3.0 d | twin empresses ×2 via the prophet-twin detour, +246% | no |
| run 2, 7.2 d | twin hive neurons ×2, +285%; the idle larvae are handled by plain banking with `bank_pre` | no |
| run 2, 7.2 d (b) | twin hive neurons via the neural-cluster twin, +263% | no |
| run 2, now | ranked: faster neuroprophets +100%, twin neural clusters +56%, twin hive neurons +48% | no. The neural-cluster and hive-neuron twins are a near tie at the same price (1e21 neural clusters), so only one is affordable |

**Verdict: the hybrid fails the acceptance test on the swarmwarp route.** It never finishes and never reaches endless by day 250. It is no worse elsewhere. Per the brief:
- I made one fix attempt, and it did not help;
- I did not regenerate the cases or write the hybrid port spec.

**Not run:** busy cadence, and a late-run state table after the fix.

