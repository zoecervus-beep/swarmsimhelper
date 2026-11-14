# Climbing advisor

The climbing advisor is a panel in this fork of Swarm Simulator. It suggests what to do next with larvae, meat, energy and territory. It only gives advice: it never buys anything for you.

## Where it appears

- **Unit list pages**: a panel titled "Climbing advisor". On wide screens it sits beside the unit list; on phones and narrow windows it sits below it. Click the title to fold it to one line. The game remembers this with your save.
- **Unit pages**: a "Use suggested" button under the hatch box, on meat units and territory units the advisor lists. It puts the suggested count into the box. You still press the game's own button to buy. When the advisor says not to hatch that unit, the button is greyed out and the reason is shown beside it. Or hold Shift: the box shows the suggested count for as long as Shift is held (so Shift-click the game's hatch button to buy it), and releasing Shift puts back what the box held. Typing a Shift character such as `%` or `@` into the box cancels this until Shift is released, so typed input is never changed.
- **Options page**: the on/off switch and the settings, under "Climbing advisor".

## What the panel says

- **Header**: how long this run has lasted since your last ascension, the climbing limit (a tier is worth hatching when its H is below this), your larvae and larvae per second. The run age is on the game clock (see "The game clock" below): once you have cast swarmwarp this run it reads, for example, "Run 30.0 d game time (2.0 d real)".
- **Table**: your meat units, highest first:
  - **Owned**: how many you have.
  - **H**: the unit's break-even time. After hatching it, you have less meat than if you hadn't until roughly this long afterwards.
  - **Now**: what to do. "buy N" (highlighted) is the number to type in the hatch box, before twins. "wait …" means the tier isn't worth climbing yet. "done, next in …" means you just hatched it. "skip: bank larvae for …" means keep the larvae for the tier above. "let … build up" and "need more …" mean wait for the tier below.
- **Tips**: faster and twin upgrades worth buying now, and multi-step plans to get a twin upgrade.
- **Energy**: what to do with energy. In order: build the next nexus, save for it, buy lepidoptera up to the target, then cast House of Mirrors. By default energy is planned for the next nexus ([ASCENSION.md](ASCENSION.md) A.11):
  - Below nexus 5 it is held for the next nexus, not cast; a full energy bar gets one larva rush so income isn't wasted.
  - The climb leaves the next nexus's larvae alone just in time, and the line says how many and why ([ASCENSION.md](ASCENSION.md) A.11.9):
    - none while its meat is missing or its larvae are far away;
    - none while its energy is further off than its larvae ("keeping no larvae for nexus 5 yet: its energy is 11.9 h away, its larvae 3.1 h");
    - then only those your larva income won't bring before the energy is there ("keeping 235M larvae for nexus 5, the rest come in before its energy (3.9 h)");
    - all of them while larvae are what it waits for.

    Every other larva goes to the climb as usual.
  - At nexus 4, the first 1,000 lepidoptera come first ("the first 1,000, before nexus 5").
  - Then it keeps only the energy nexus 5 will need by the time its larvae are there: its price less what your energy income brings while the larvae come in. The rest goes into lepidoptera. While nexus 5's meat is missing, the whole price is kept. The line says how much is kept and when the larvae will be there.
  - After nexus 5, lepidoptera up to the target, then House of Mirrors. On the House of Mirrors route the target depends on the kind of run (see Ascension below).
  - On the swarmwarp route (see "The swarmwarp route" below), after nexus 5: 10,000 lepidoptera, then 2,000 bats ("buy 500 bats (1,500/2,000, before the first swarmwarp: they raise its power)"), then swarmwarp, one cast at a time.
  - With "cast larva rush" in the settings, it works as the console script did: spare energy below nexus 5 goes to larva rush, and lepidoptera are bought up to the target at nexus 4.
- **Territory**: which territory units to hatch and how many, territory twins to buy or save for, and hatchery, expansion and accomplished ancestry levels to buy. Once House of Mirrors is running, it says to stop hatching territory units and to set the territory share to 0. On the swarmwarp route it never says that, even in a run where House of Mirrors was cast before you switched; with a share of 0 it says to set it back to 0.1.
  - The suggestion often names two units: the main unit, and the next unit up for the meat left over. Buy them in either order: after you buy one, the other stays. "Up" means by meat cost per larva, so an empowered unit ("swarmling II") counts as the rung above goons. The territory larvae work like a purse: it starts as the territory share of the larvae you have when the page loads, fills up with the territory share of the larvae you make, and goes down by what you spend on territory units and twins. So once the suggestion is bought, only what has come in since is offered ("territory larvae spent for now" while that is less than one larva), and hatching again and again cannot use more than the territory share.
  - Empowering: it suggests empowering your cheapest territory unit once the territory share of your larvae all fits into your most expensive one with the empower's price still to spare, and only while the units it wipes out make under 1% of your territory. Empowering wipes the units of that kind you own and makes them the next rung above the top one (swarmlings become "swarmlings II" above goons). This rule is reasoning, not tested in the simulator.
- **Long-run climb** (only with "Long-run climb: on" or on the swarmwarp route, and only once the run is 2 days old on the game clock; before that the header says when it starts): extra rules from [ASCENSION.md](ASCENSION.md) A.10.2 for climbing all the way to endless on runs of many days. The header shows "long-run climb: 1% of larvae kept for feeding upward" while they act.
  - "Feed upward" rows: tiers above the highest one being climbed are hatched with half of the tier below (2% for the tier just above it), counting what the climb suggests this visit, and with at most half your meat. Highest tier first; a tier hatched in the last 60 s waits.
  - The larvae: after the territory share and the larvae for the next nexus (while the energy line saves for it), 1% is kept for feeding upward and the climb gets the rest, so it suggests slightly fewer than with the mode off. Feeding upward gets that 1% plus whatever the climb leaves.
  - Twin upgrades paid in a fed tier are only suggested once you hold a million times their price, so those units go up the chain.
  - From day 3 the lepidoptera target is 30,000 if your setting is lower; the energy line says so. This day 3 is on the real clock. On the swarmwarp route there is no such raise: its target is 10,000.
  - Tiers above the table up to endless are summed up in one row while there is nothing to feed there.
  - Stay a couple of minutes per visit: the next steps show once the last ones are bought.
- **Ascension** (only with Route set to one of the two routes). On the House of Mirrors route, one or two lines for the plan in [ASCENSION.md](ASCENSION.md), part A. The advisor works out where you are from your game, you never tell it:
  - **First run** (you have never ascended): the ascension cost against your energy cap, and how much spent energy halves it (50,000 without the lepidoptera mutation, up to 80,000 with it; read from the game's own cost). From nexus 5 it says how much more to spend on lepidoptera and House of Mirrors (lepidoptera count as spent energy too). Once the cost is at or under the lower of your energy cap and that halving amount divided by ln 2 (72,134 without the mutation), it says to stop casting and save, with your energy against the cost and the time to it at your current energy rate. When the energy covers the cost: ascend now, and how much mutagen that brings.
  - **After an ascension, with mutagen unspent**: what to buy, each only while still to do and affordable: unlock the lepidoptera mutation, buy lepidoptera mutations up to 1 million, then one more unlock of any kind (after the first ascension) or all remaining unlocks (from the second). The rest is kept unspent, because unspent mutagen makes larvae.
  - **The long run** (lepidoptera mutation bought, but the expansion or endless achievements not all earned): do not ascend; your expansions against the next expansion achievement and 5,000, and endless bought against the next endless achievement. While the long-run climb is off, the line links to Options to turn it on.
  - **Quick runs** (those achievements earned, fewer than 20 ascensions): spend, save and ascend as in the first run, with "ascension n of 20".
  - **Done**: "no further ascension needed".
  - While it says to save, the energy line agrees: it shows the save instead of a House of Mirrors cast or lepidoptera. Just before that point, the cast or lepidoptera count is cut to what brings the cost down to where saving starts. With the setting off, the energy line is exactly as without it.
  - **The lepidoptera target for the run** ([ASCENSION.md](ASCENSION.md) A.11): 10,000 in a first run (and a run still short of the lepidoptera mutation), so House of Mirrors still brings the mutagen; 30,000 in a quick run; in the long run, 30,000 from a run age of 3 days. Your setting applies when it is higher. Every lepidoptera counts as spent energy, as a cast does, and raises the energy rate, so a run that will ascend soon wants many. The energy line names the target ("first-run target, your setting is 4,000").

Advice refreshes about once a second, and at once when you change a setting or cast swarmwarp. If something goes wrong, the panel shows the error text instead of the advice.

## The game clock

Swarmwarp moves production forward by the time it skips, but no clock the game shows. The advisor counts that skipped time as time passed, on every route. The game keeps the total time skipped over your whole save (`skippedMillis`, kept across reloads and ascensions), so the advisor's clock is the real time plus that total ([NO-MIRRORS.md](NO-MIRRORS.md) sections 11 and 12.1).

- **On the game clock**: the 60 s wait after you hatch a unit ("done, next in …"), the share of the tier below offered per minute since then, the release of the tier below's older stock, the feed-upward wait, the territory larvae coming in, the run age behind the climbing limit, and the long-run climb's 2 days.
- **On the real clock**: everything about energy (its rate, the cap, "ready in …", what is kept for nexus 5) and the House of Mirrors route's day 3.
- **This run's age** is the real time since the ascension plus what this run's swarmwarps skipped: their count times what one cast skips now, never more than the total your save has skipped. That is exact as long as the spell's power has not changed since this run's first cast, which is the case on the swarmwarp route (the bats come before the first cast), and in a save's first run. Otherwise it is too long: bats or warp mutations bought after some casts make those casts count at the new power. In a later run the bound rarely helps, because earlier runs' warps are in the total too.
- Every swarmwarp skips at least 900 s, so one cast releases every 60 s wait and the whole share: the panel shows the released purchases straight after the cast, not "next in 59 s".
- Without a swarmwarp cast nothing changes: the advice is the same as before this clock was added.

## The swarmwarp route

Pick "Swarmwarp route" under Route, the first of the advisor's settings in Options. It earns the same achievements without House of Mirrors ([NO-MIRRORS.md](NO-MIRRORS.md) section 12). Everything is worked out from your game each time; the advisor stores nothing for it, and your other settings are not changed.

- **Energy**: below nexus 5, the same plan as the House of Mirrors route. After nexus 5: 10,000 lepidoptera every run ("lepidoptera 4,000/10,000, swarmwarp route"; a higher setting stays), then 2,000 bats, then swarmwarp **one cast at a time**: "cast 1 swarmwarp (5 affordable): skips 27.8 d; then follow the lines above and below: the next swarmwarp is suggested after them". It never says "×5" on this route.
- **The purchases between warps**: a cast releases days or years of production. While the panel has purchases open (a climb row to buy or feed upward, a faster or twin upgrade, a hatchery, expansion or ancestry level, an empower or a territory twin, or territory units worth more than a minute of the territory share's larvae), the energy line holds the next cast: "next: cast 1 swarmwarp (4 affordable): skips 27.8 d, once the purchases above and below are made (3 climb rows, 11 upgrade tips, 4 territory lines)". Once they are bought (the climb rows go into their 60 s wait), it offers the cast again. You can always cast anyway. Empowers are offered one per look, as everywhere in the advisor, and the hold follows that rule to the end. So after a large warp you may empower several units in a row (up to 10 in the reference cases) before the next cast is offered. The simulator's 141 days for this route were measured with one empower per visit.
- **Climbing**: the long-run climb is on whatever the Long-run climb setting says; Options shows that setting as on and greyed out, with your own choice kept for the House of Mirrors route.
- **Territory**: never stopped; a share of 0 is advised back to 0.1. Empowering as on the other route.
- **When to ascend** (stages from your game):
  - **build**: ascend once this run's mutagen (inactive) is at least 1,000 times the mutagen you hold. Until then: "keep swarmwarping, do not ascend yet: mutagen (inactive) 3.57e20/2.16e35 (1,000 × your mutagen) to ascend", with expansions, endless and unlocks toward their next achievement. Once it passes, the usual spend, save and ascend lines, and while saving no swarmwarp or bats.
  - **final** (1e270 mutagen, counting the warp, bat, territory and meta-mutation mutations you hold with the mutagen, since the mutagen line turns one into the other; 5,000 expansions not yet earned): "final run, do not ascend: expansions x/5,000; all spare energy into swarmwarp".
  - **quick** (5,000 expansions, 1e62 endless and 10 unlocks earned, fewer than 20 ascensions): ascend whenever the energy allows.
  - **done**: "every achievement of the swarmwarp route earned".
- **Mutagen**, whenever you hold some, worked out from what you hold (once bought, the line goes away): a free respec when the warp mutation is locked and you cannot afford it as your next unlock (after the House of Mirrors route's first ascension, for example), but not while the route says to ascend (the ascension brings the mutagen for it); then unlocks in the order lepidoptera, warp, bat, frequency, meta-mutation, territory, rush, clone, meat, hatchery (the first three whenever affordable, later ones only while one costs at most 30% of your mutagen); lepidoptera and frequency mutations to 1 million; then 10% of your mutagen in warp, 10% in bat, 30% in territory and 1% in meta-mutation mutations, counting those you hold. The rest stays unspent.

## Switching routes

You can switch at any time; the next refresh follows the new route, and its mutagen line shows at once. Switching back and forth on the same game gives the same advice as before the switch. Two protections, since an ascension cannot be undone:

- **An ascension out of a House of Mirrors run with 1,000 or more expansions** says what it costs: "this run has 3,118 expansions from House of Mirrors: ascending restarts them. The swarmwarp route still expects ascending to be faster." (In the simulator, ascending there was 7 to 67 days faster than keeping the long run.)
- **A House of Mirrors run near 5,000 expansions** (House of Mirrors cast this run, 4,500 or more expansions, the 5,000 achievement not earned, and not your first run): the swarmwarp route does not advise ascending or swarmwarp. It finishes the run as the House of Mirrors route's long run would, with the line "4,695 of 5,000 expansions: finish this run with House of Mirrors, then the swarmwarp route resumes". Its mutagen line shows only unlocks and the lepidoptera and frequency mutations: no respec, which would drop mutations this run uses, and no warp, bat, territory or meta-mutation shares until the run is over.
- A first run is never treated as a long run on either route.
- From the swarmwarp route back to the House of Mirrors route needs nothing special: that route works out its own stage from your game.

## Settings

| Setting | Default | Meaning |
| --- | --- | --- |
| Climb multiple | 3 | Climb a tier once its H is under this many times the run's age. 3 suits runs of a day or so; 5 suits runs lasting several days. |
| Share per minute | 0.5 | How much of the tier below may be converted for each minute since you last hatched a unit. |
| Cooldown | 60 s | After you hatch a unit, how long before it is suggested again. |
| Banking threshold | 3 | Stop hatching a unit once the tier above already makes this many times what larvae could. |
| Territory share | 0.1 | Share of larvae kept for territory units. Set it to 0 once House of Mirrors is casting. |
| Lepidoptera target | 4000 | Lepidoptera to buy with energy. The House of Mirrors route raises it for the kind of run (10,000 first run, 30,000 quick runs and from day 3 of the long run); the swarmwarp route uses 10,000 every run, then 2,000 bats. A higher setting stays. Options shows the target for the route picked. |
| Long-run climb | off | "On" adds the long-run rules above from a run age of 2 days, keeping 1% of the larvae for feeding upward. It trades meat income for progress up the chain, so it is for the achievements goal, not for short runs. |
| Route (stored as `ascension`) | House of Mirrors route | First in Options. "House of Mirrors route" or "Swarmwarp route": the ascension lines above, energy saved for the ascension when it is time, and the lepidoptera target for the kind of run. "No ascension advice" leaves the panel exactly as without them. Every other setting's help text in Options describes the route picked. (Default "off" before Nov 14, 2026.) |
| Spare energy before nexus 5 | plan it for the next nexus | Holds energy and larvae for the next nexus; at nexus 4, 1,000 lepidoptera first, then only the energy nexus 5 needs by the time its larvae are there, the rest into lepidoptera. In the simulator that reached the next ascension 7 to 13 hours sooner. "Cast larva rush" is the console script's rule. No effect from nexus 5. (Default "cast larva rush" before Nov 14, 2026.) |

**To get the console script's behaviour**: spare energy "cast larva rush", ascension advice off, climb multiple 3, share 0.5, cooldown 60, banking 3, territory 0.1, lepidoptera 4,000, long-run climb off.

**Changed defaults (Nov 14, 2026).** Settings you have saved keep their values; the ones you never set follow the new defaults. So with untouched settings the energy line now plans for the next nexus and the ascension lines appear, with the lepidoptera target set by the kind of run. Pick "cast larva rush" and "off" to go back.

A number setting is saved when you leave its box or press Enter; the spare-energy, long-run and ascension choices are saved as soon as you pick them. Values outside the allowed range are saved at the nearest limit, with a note. Text that isn't a number is not saved. Reset puts all of them back to the defaults. Settings are stored with your save.

## What it does not do

- It never buys, casts or changes settings for you.
- It never ascends, unlocks mutations or casts spells for you. Ascension advice follows one of the two routes; pick "No ascension advice" if you are on neither.
- It doesn't know how long you plan to play this run. "Climb multiple" is the only stand-in for that.
- It notices purchases from the game's statistics, about once a second, while the game is open.

## More

- [HANDOFF.md](HANDOFF.md): what the rules are and the evidence behind them.
- [MODEL-CHECK.md](MODEL-CHECK.md): how the simulator and the advisor were checked against the game's code.
- [ASCENSION.md](ASCENSION.md): the plan for earning every achievement (ascensions, the long run to endless), ascension and mutagen mechanics, and the simulator checks. The "House of Mirrors route" setting follows its part A.
- [NO-MIRRORS.md](NO-MIRRORS.md): whether every achievement can be earned without ever casting House of Mirrors (yes, with swarmwarp instead), and the swarmwarp route as rules for the advisor: with swarmwarp counted as elapsed time it takes about 141 simulator days (154-158 at a person's cadence) against 174 for the mirrors route; route switching and reference cases. The "swarmwarp route" setting follows its section 12.
- [ACHIEVEMENTS.md](ACHIEVEMENTS.md): every achievement, how the game evaluates it, and which are earned in the example save (generated).
- [BUILDING.md](BUILDING.md): building, testing and running the game.
