# Swarm Simulator climbing advisor: handoff for the fork

Nov 12, 2026

## Goal and scope

Build the climbing advisor into a fork of Swarm Simulator ([swarmsim/swarm](https://github.com/swarmsim/swarm)) as a native panel, replacing the console script that does the job today.

The advisor tells the player, live, what to do with larvae and energy:

- which meat unit to hatch and how many
- when to start a new tier, and when to stop hatching a lower one
- which faster-production and twin upgrades are worth buying now
- what to do with energy (nexus, lepidoptera, House of Mirrors)

In scope for the first version: everything the console script does, plus a proper button to fill the buy box in place of the hold-Shift workaround.

Out of scope so far: ascension and mutagen. The owner wants to look at those later. Territory advice is worked out (see the territory section) but is not in the script yet, so it is a second step.

This doc is written for a fresh session with no memory of the original conversation. Two files should travel with it: `swarm-climb-live.js` (the console script) and `swarm-advisor-sim.zip` (the simulator, its tuned settings and helpers). The appendix lists what is in each.

## Where things stand

The rules are settled enough to build, but none of the code has been run against the real game by the author.

| Piece | What it is | Status |
| --- | --- | --- |
| Console script | `swarm-climb-live.js`, about 400 lines of plain JavaScript pasted into the browser console on swarmsim.com. Draws a panel bottom-right, refreshes every second. | Syntax-checked only by the author. The owner has been running it through a full day of play and reporting behaviour; bugs found that way were fixed. |
| Simulator | `sim.py`, a Python re-implementation of the game's production, purchase, territory and energy math, with a parameterised policy. | Built from reading the repo's data tables and CoffeeScript. Never compared number-for-number with the live game. |
| Tuned policy | `policy.json`, the settings the simulator scored best with. | Tuned on the owner's saves from one run, 1.2 to 14.5 hours in, plus seven simulated states up to 43 hours. |
| Game source | Cloned and read, not built. | The build toolchain is untested. |

The owner's run at the last save: 14.5 hours in, top unit hive (175,000), 4 nexus, 2,416 lepidoptera, about 34,000 larvae a second. No ascension yet.

## Game mechanics the advisor relies on

Everything below was read from the repo's data (`tables/src/spreadsheet/original-data.json`) and services (`swarmsim-coffee/app/scripts/services/`). The advisor reads live values from the game objects, so it does not hard-code these.

### Meat units

The chain is drone, queen, nest, greater queen, hive, hive queen, empress, prophet, goddess, pantheon 1 to 5, overmind 1 to 6. Drone is tier 1.

| Property | Rule |
| --- | --- |
| Production | A tier-k unit makes k units of the tier below per second (drones make 1 meat), doubled per faster-production level. |
| Purchase | Costs 1 larva, some meat (negligible in practice), and units of the tier below. Yields 2^(twin level) units. |
| Cost in the tier below | Queen 100, nest 1,000, greater queen 10^4, hive 10^5, hive queen 10^6, then ×10 per tier to pantheon 1 (10^10). Steeper after: pantheon 2 to 5 cost 10^12, 10^14, 10^16, 10^19; overmind 1 to 6 cost 10^23, 10^28, 10^34, 10^41, 10^49, 10^58. |
| Faster-production upgrade | Costs 66 × 666^level of the unit itself. Doubles its production. |
| Twin upgrade | Costs 10^level units of the tier above (factor 12 to 20 for overminds). Doubles units per purchase. It does nothing for units already owned or produced. |

### Larvae and territory

- Larvae per second = (1 + hatchery level) × 1.1^expansions × (1 + 0.001 × achievement points)^(accomplished ancestry level).
- Hatchery costs 300 × 10^level meat. Expansion costs 10 × 2.45^level territory. Accomplished ancestry costs 5e6 × 10^(4 × level) meat plus 500 × 10^(4 × level) territory, max level 5.
- Territory units: 11 tiers, swarmling to goon. Tier j (from 0) costs 750 × 450^j meat plus 1 larva and makes 0.07 × 45^j territory a second. Their twins cost 100 × 500^level meat plus 50^level larvae.

### Energy

- Each nexus makes 0.1 energy a second. Cap is 10,000 per nexus.
- Nexus 2 to 5 cost 3.33e15, 3.33e18, 3.33e21, 3.33e24 meat; 625, 2,500, 10,000, 36,000 energy; and 0, 3.33M, 33.3M, 3.33B larvae.
- Lepidoptera (`moth`): 10 energy and 1 larva each, needs nexus 4. Energy rate multiplier is 1 + N / (1000 + N), so it approaches 2×.
- Bat: 100 energy and 1 larva each, needs nexus 5. Spell power multiplier is 1 + 0.6 × N / (1000 + N).
- Nightbug: 10 energy and 1 larva, needs nexus 3. Raises the energy cap toward 6×.
- House of Mirrors (`clonearmy`): 2,500 energy, needs nexus 5. Doubles every territory unit. No cap, and it does not use spell power (`effect.coffee`, `compoundUnit` with no `val2`).
- Other spells: larva rush (1,600 energy, 2,400 s of larvae), swarmwarp (2,000, skips 900 s), meat rush and territory rush (1,600, 7,200 s each), clone larvae (12,000, doubles larvae plus cocoons up to 100,000 s of larva income). All of these scale with spell power.

## The rules for meat units

These are the rules as the console script implements them today. Defaults are in brackets and live in `swarmClimbCfg`.

### Quantities computed per unit

For unit u at tier k, with the unit below it called "below":

- `cost` = units of below per purchase. `twin` = units per purchase. `prodEach` = below made per second by one u.
- `payback` = cost / (twin × prodEach). Seconds for one purchase to regrow what it cost.
- `H` = k × payback. The meat break-even clock: buying u leaves you with less meat than not buying until about H later.
- `horizon` = ageMultiple [3] × run age. Run age counts from the last ascension (`session.state.date.restarted`).
- `spendable` = larvae per second × (1 − territory share [0.10]).

### 1. When a tier may be climbed

A tier passes when H ≤ horizon. For runs meant to last several days, ageMultiple 5 tested better than 3.

### 2. Where larvae go

Work from the highest shown tier down. Each passing tier takes larvae before any tier below it. Larvae on hand are first reduced by the territory share.

### 3. How much to convert per visit

For a passing, affordable tier, the suggested purchase count is the smallest of:

- larvae still unallocated
- affordable × (1 − (1 − share [0.5])^(minutes since u was last hatched))
- spare / cost, where spare = what below has gained since u was last hatched, plus the stock held at that moment × min(1, seconds since / payback)

After a purchase, the unit shows a 60-second cooldown and its larvae stay earmarked so lower tiers do not take them. Purchases are detected from `statistics.byUnit[name].num`.

The third term is the newest rule. It means a slow new top tier takes the lower tier's income, not its stockpile.

### 4. Banking larvae

Skip hatching u, and leave those larvae unspent, when the tier above passes, at least one is owned, and:

    above.count × above.prodEach > bank [3] × spendable × u.twin / above.twin

In words: the tier above already makes more than three times what larvae could hatch. The banked larvae are spent when the tier above can absorb them.

### 5. Faster-production upgrades

Suggest when the unit count is at least 2× the cost. This applies to every tier including drones, because it boosts units already owned.

### 6. Twin upgrades

Only considered for a unit that is currently being climbed (passes, affordable, not banked). Call the unit u and the tier its twin is paid in "payIn".

- **Affordable now** (payIn.count ≥ twin cost): suggest only if u's hatch rate is at least what the sacrificed payIn units were producing, and not when payIn is itself being climbed and already makes more u than larvae do.
- **Not affordable, and payIn does not pass rule 1**: plan the cheapest way to get the payIn units (below). Suggest the plan if u.count ≥ 2 × plan cost and (k + 1) × plan cost / hatch rate < horizon.
- u's hatch rate is estimated as u.twin × min(spendable, u.count × u.prodEach / u.cost).

### 7. Twin plans that chain upward

`acquire(tier j, N)` finds the cheapest way to hold N of tier j. At each tier it compares hatching directly against first buying that tier's own twin (which needs units of tier j+1, obtained by the same function) and then hatching at half price. It repeats while the detour is cheaper and payable from current stock. The result is a step list such as "hatch 1 hive > twin greater queens > hatch 10 hives > twin greater queens > hatch 2.28e6 greater queens".

## Territory and energy rules

### Territory (worked out in the simulator, not yet in the script)

- **Larva share:** about 10% of larvae go to territory units until House of Mirrors is running, then 0%. Anything from 3% to 10% scored about the same; 0% before mirrors and 40% or more were clearly worse.
- **Which unit:** the biggest unit you could put all your territory larvae into without running out of meat, with spare meat going to the next unit up. In the simulator this is `terr='balanced'`.
- **Territory twins:** buy when the larva cost is under about one minute of total larva income.
- **Hatchery, expansion, accomplished ancestry:** buy whenever affordable. Ancestry before an expansion when both cost similar territory.
- **After mirrors start:** buying territory units stops mattering. Stopping entirely was 1.2 to 1.5× better.

### Energy (in the script as the blue "energy:" line)

1. Buy each nexus as soon as its meat, energy and larvae are all in hand.
2. Start saving energy and larvae for the next nexus once the meat is there and its larva price is under 20,000 seconds (about 5.5 hours) of larva income.
3. Before nexus 4, spend spare energy on larva rush.
4. At nexus 4, put all spare energy into lepidoptera up to the target [4,000]. Do this before saving for nexus 5.
5. From nexus 5, finish the lepidoptera, then put every 2,500 energy into House of Mirrors.
6. Buy no bats. Mirrors ignore spell power.

Lepidoptera target by run length: none for runs under about 2 days, 2,000 to 4,000 for about 4 days, 4,000 for one to two weeks. Nightbugs are only for players away longer than about 15 hours at a time.

## Evidence

Every rule was scored in the simulator by total meat earned at fixed times ahead, starting from the owner's real saves. The figures below are how much worse the run gets when the rule is broken, so they show which rules the fork must get right.

| Rule broken | Cost | Measured over |
| --- | --- | --- |
| Using swarmwarp instead of the House of Mirrors plan | about 10^4 at 4 days, 10^6 at 7 days, 10^19 at 14 days | two saves |
| Using the House of Mirrors plan on a run shorter than 2 to 3 days | about 25× at 24 and 48 hours | two saves |
| Never hatching a higher tier just for twins | about 200× on average | two saves, 1 to 48 hours |
| Climbing at 1× or 10× run age instead of 3× | about 20 to 50× on average | two saves, 1 to 48 hours |
| Checking in every 15 minutes instead of every minute | about 13× on average | two saves, 1 to 48 hours |
| Starting hive queens as soon as possible | 10^10 at 24 hours | 11.9-hour save |
| Saving for nexus 5 before the larvae are close | 10^10 at 24 hours, 3 to 10× from 4 days | 11.9-hour save |
| Never banking larvae | about 3× on average | ten states |
| Dumping a lower-tier stockpile into a new top tier | 3 to 10× over the next 8 hours | 11.9-hour save |
| 100 bats | 2 to 4× | two saves |
| Always buying the top territory unit | about 1.5× on average | two saves |
| Thresholds for faster production, hatcheries, territory share | under 1.3× each | two saves |

Two checks on headroom. A 600-combination random search over the meat-unit settings found nothing better than the tuned policy. Handing the simulator free resources, doubling larvae was worth about 7× and doubling meat about 2×.

The ten test states are three real saves (1.2, 3.3 and 11.9 hours in) plus seven taken from simulated runs between 6 and 43 hours.

## Known weaknesses and open questions

The biggest risk is that the simulator has never been checked against the real game. Do that before trusting any number here.

**Unverified assumptions**

- The simulator's rates were never compared with the game's. From the first save it computed 309.5 larvae, 3.99e13 meat and 1.06e8 territory per second. Loading that save in the real game and comparing is the cheapest check.
- The accomplished ancestry bonus is defined on the `larva` unit's `prod` stat but belongs to the hatchery's upgrade list. The simulator assumes it multiplies larva production. Confirm in `unit.coffee`.
- House of Mirrors being uncapped and ignoring spell power comes from reading `effect.coffee`, not from casting it.
- The simulator treats cocoons as larvae and ignores unit caps and number formatting.

**Rule soft spots**

- **New top tier timing.** The run-age rule starts a brand-new top tier a little early. From the 11.9-hour save, "no hives for two hours, then resume" beat the current rule by 3 to 5× over eight hours. No general rule tested captured that without hurting other positions.
- **Twin payback estimate.** The hatch-rate estimate counts only units made by the tier itself and ignores those hatched from larvae into the tier below. It is slightly cautious while the lower tier is still larva-fed.
- **Twin guard.** A very cheap twin can still pay shortly before banking starts; the guard blocks it. Stakes are small.
- **Horizon.** "3× run age" stands in for how long the run will last. That is really the ascension question, which is not modelled.
- **Late game.** Simulated runs only reached hive queens. Everything about pantheons and overminds, including the chained twin planner, is the same rules extrapolated. The planner was tested on made-up states only, and never produced a three-tier chain there.
- **Clone larvae.** It ranked second among spells, but the reserve policy used to test it was crude, so that ranking is the least certain.
- **Check-in cadence.** The simulator acts once a minute and casts spells the moment energy allows. Real play is burstier.

**Open questions for the owner**

- Should the fork only advise, or also offer one-click "do it" buttons?
- Should territory advice ship in the first version?
- Publish the fork or keep it private? The repo is GPL-3.0, so a published fork must stay GPL-3.0.

## Suggested implementation plan

Start by getting the game to build and by checking the simulator against it; the port itself is small.

1. **Fork and build.** The repo is a yarn workspace with three parts: `tables` (game data), `swarmsim-ts` (embedded pages) and `swarmsim-coffee` (the game: AngularJS 1, CoffeeScript, Grunt, Bower). The root `package.json` defines `yarn install`, `yarn start` and `yarn test`. This toolchain dates from 2014 and has not been tried; expect to pin an old Node version. There is also a `Dockerfile`.
2. **Verify the model.** Import the owner's saves into the local build and compare larvae, meat and territory per second with the simulator's figures. Cast House of Mirrors once on a test save to confirm it doubles every territory unit regardless of bats.
3. **Port the rules as a service.** Add an `advisor` factory under `swarmsim-coffee/app/scripts/services/`. Keep it a pure function of a game snapshot plus a small remembered state (last purchase time and lower-tier stock per unit), so it can be unit-tested. Use `Decimal` throughout; the script already does.
4. **Unit tests.** `swarmsim-coffee/test/spec/services/` holds Karma specs. Cover each rule with a snapshot built from the owner's saves, and the twin planner with the made-up late-game states.
5. **Panel UI.** A directive that renders the same table as the script (unit, owned, H, action), the upgrade tips and the energy line. Put it on the main view, collapsible.
6. **Buy-box button.** Replace the hold-Shift workaround with a "use suggested" button beside the buy input in `app/views/buyunit-input.html` (the input is bound to `form.buyCount`).
7. **Settings.** Expose age multiple, share, bank threshold, territory share and lepidoptera target on the options page, persisted with the save.
8. **Territory advice.** Add the rules from the territory section once the meat side is solid.
9. **Later, with the owner:** ascension and mutagen. This is where the run-length question gets a real answer.

## Appendix

### Files to attach with this doc

| File | Contents |
| --- | --- |
| `swarm-climb-live.js` | The console script. The reference implementation of every rule in the meat-unit and energy sections. |
| `swarm-advisor-sim.zip` | `sim.py` (simulator), `policy.json` (tuned settings), `decode_save.py`, `run_example.py`, and `example_save_14h.json` (the owner's last save, decoded). |

### Game API the script uses

All of it was read from the CoffeeScript source. The fork can call the same things directly.

| Need | Call |
| --- | --- |
| Game object | `angular.element(document.body).injector().get('game')` |
| Unit, upgrade | `game.unit(name)`, `game.upgrade(name)`, `game.unitBySlug(slug)` |
| Count, rate | `unit.count()`, `unit.velocity()` (both `Decimal`) |
| Cost in the tier below | `unit.costByName[belowName].val` |
| Units per purchase | `unit.twinMult()` |
| Production per unit | `unit.eachProduction()[belowName]` |
| Upgrade price | `upgrade.totalCost()` gives a list of `{unit, val, factor}` |
| Run start | `game.session.state.date.restarted` |
| Purchases so far | `game.session.state.statistics.byUnit[name].num` |
| Buy box | `input[ng-model="form.buyCount"]`; set the value and dispatch an `input` event |

Upgrade names follow a pattern: `<unit>prod`, `<unit>twin`, `nexus1` to `nexus5`. The lepidoptera unit is `moth`. Unit page URLs look like `#/tab/meat/unit/greater%20queen`.

### Script settings (`swarmClimbCfg`)

| Setting | Default | Meaning |
| --- | --- | --- |
| `ageMultiple` | 3 | Climb tiers whose H is under this many times run age. Use 5 for multi-day runs. |
| `share` | 0.5 | Fraction of the lower tier that may be converted per minute waited. |
| `cooldown` | 60 | Seconds after a purchase before that unit is suggested again. |
| `bank` | 3 | Stop hatching a unit once the tier above makes this many times what larvae could. |
| `territory` | 0.10 | Share of larvae held back for territory. Set to 0 once mirrors are casting. |
| `moths` | 4000 | Lepidoptera target. |

### Save format

An export string is `base64(version) | base64("Cheater :(\n\n") + LZString.compressToBase64(json)`. The "Cheater" prefix is the game's own joke header on every save. The JSON has `unittypes` (counts by name), `upgrades` (levels by name), `date` and `statistics`. `decode_save.py` does this.

### Simulator notes

- `sim.py` reads the save named in the `SAVE` environment variable. `run(policy, 0, check_in_seconds, marks_in_hours)` returns, per mark, log10 meat per second, log10 larvae per second, top tier, a state copy, and log10 total meat earned.
- Production between check-ins is integrated exactly (it is a polynomial in time), so the step size only affects how often the policy acts.
- The score used throughout is log10 of total meat earned, averaged over several marks and starting states.
- Policy keys map to the rules: `theta_age` (age multiple), `share`, `inc_share` and `stock_rel` (income-only conversion), `bank`, `prod_mult`, `twin_flow` and `twin_r` (twin tests), `twinseek` and `seek_mult` (hatching a tier for twins), `f`, `terr` and `tt_secs` (territory), `spells`, `moth_N`, `nexus_secs` (energy).
- The many experiment scripts from the original session were not kept. `run_example.py` shows the pattern for writing new ones.
