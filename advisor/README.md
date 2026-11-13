# Climbing advisor

The climbing advisor is a panel in this fork of Swarm Simulator. It suggests what to do next with larvae, meat, energy and territory. It only gives advice: it never buys anything for you.

## Where it appears

- **Unit list pages**: a panel titled "Climbing advisor". On wide screens it sits beside the unit list; on phones and narrow windows it sits below it. Click the title to fold it to one line. The game remembers this with your save.
- **Unit pages**: a "Use suggested" button under the hatch box, on meat units and territory units the advisor lists. It puts the suggested count into the box. You still press the game's own button to buy. When the advisor says not to hatch that unit, the button is greyed out and the reason is shown beside it.
- **Options page**: the on/off switch and the settings, under "Climbing advisor".

## What the panel says

- **Header**: how long this run has lasted since your last ascension, the climbing limit (a tier is worth hatching when its H is below this), your larvae and larvae per second.
- **Table**: your meat units, highest first:
  - **Owned**: how many you have.
  - **H**: the unit's break-even time. After hatching it, you have less meat than if you hadn't until roughly this long afterwards.
  - **Now**: what to do. "buy N" (highlighted) is the number to type in the hatch box, before twins. "wait …" means the tier isn't worth climbing yet. "done, next in …" means you just hatched it. "skip: bank larvae for …" means keep the larvae for the tier above. "let … build up" and "need more …" mean wait for the tier below.
- **Tips**: faster and twin upgrades worth buying now, and multi-step plans to get a twin upgrade.
- **Energy**: what to do with energy. In order: build the next nexus, save for it, buy lepidoptera up to your target, then cast House of Mirrors. Before nexus 5, spare energy goes to larva rush, or is held for the next nexus if you choose "save it" in the settings. When saving, a full energy bar gets one larva rush so income isn't wasted.
- **Territory**: which territory units to hatch and how many, territory twins to buy or save for, and hatchery, expansion and accomplished ancestry levels to buy. Once House of Mirrors is running, it says to stop hatching territory units and to set the territory share to 0.
  - The suggestion often names two units: the main unit, and the next unit up for the meat left over. Buy them in either order: after you buy one, the other stays. "Up" means by meat cost per larva, so an empowered unit ("swarmling II") counts as the rung above goons. The territory larvae work like a purse: it starts as the territory share of the larvae you have when the page loads, fills up with the territory share of the larvae you make, and goes down by what you spend on territory units and twins. So once the suggestion is bought, only what has come in since is offered ("territory larvae spent for now" while that is less than one larva), and hatching again and again cannot use more than the territory share.
  - Empowering: it suggests empowering your cheapest territory unit once the territory share of your larvae all fits into your most expensive one with the empower's price still to spare, and only while the units it wipes out make under 1% of your territory. Empowering wipes the units of that kind you own and makes them the next rung above the top one (swarmlings become "swarmlings II" above goons). This rule is reasoning, not tested in the simulator.
- **Long-run climb** (only with "Long-run climb: on", and only once the run is 2 days old; before that the header says when it starts): extra rules from [ASCENSION.md](ASCENSION.md) A.10.2 for climbing all the way to endless on runs of many days. The header shows "long-run climb" while they act.
  - A tier that is too slow to climb by its H can still be climbed when hatching it and buying its own faster upgrade out of that purchase pays: "buy N, then faster X". Afterwards the faster upgrade is offered one level at a time at its price (not twice its price), until the tier climbs.
  - "Feed upward" rows: tiers above the highest one being climbed are hatched with half of the tier below (2% for the tier just above it), with the larvae left after climbing, the territory share and the next nexus, and at most half your meat. Highest tier first; a tier hatched in the last 60 s waits. Late in a run the climb often takes all the larvae, and then nothing is fed.
  - Twin upgrades paid in a fed tier are only suggested once you hold a million times their price, so those units go up the chain.
  - From day 3 the lepidoptera target is 30,000 if your setting is lower; the energy line says so.
  - Tiers above the table up to endless are summed up in one row while there is nothing to feed there.
  - Stay a couple of minutes per visit: the next steps show once the last ones are bought.
- **Ascension** (only with "Ascension advice: achievements route" on): one or two lines for the plan in [ASCENSION.md](ASCENSION.md), part A. The advisor works out where you are from your game, you never tell it:
  - **First run** (you have never ascended): the ascension cost against your energy cap, and how much spent energy halves it (50,000 without the lepidoptera mutation, up to 80,000 with it; read from the game's own cost). From nexus 5 it says how much more to spend on House of Mirrors. Once the cost is at or under the lower of your energy cap and that halving amount divided by ln 2 (72,134 without the mutation), it says to stop casting and save, with your energy against the cost and the time to it at your current energy rate. When the energy covers the cost: ascend now, and how much mutagen that brings.
  - **After an ascension, with mutagen unspent**: what to buy, each only while still to do and affordable: unlock the lepidoptera mutation, buy lepidoptera mutations up to 1 million, then one more unlock of any kind (after the first ascension) or all remaining unlocks (from the second). The rest is kept unspent, because unspent mutagen makes larvae.
  - **The long run** (lepidoptera mutation bought, but the expansion or endless achievements not all earned): do not ascend; your expansions against the next expansion achievement and 5,000, and endless bought against the next endless achievement. While the long-run climb is off, the line links to Options to turn it on.
  - **Quick runs** (those achievements earned, fewer than 20 ascensions): spend, save and ascend as in the first run, with "ascension n of 20".
  - **Done**: "no further ascension needed".
  - While it says to save, the energy line agrees: it shows the save instead of a House of Mirrors cast. Just before that point, the cast count is cut to the casts that bring the cost down to where saving starts. With the setting off, the energy line is exactly as before.

Advice refreshes about once a second. If something goes wrong, the panel shows the error text instead of the advice.

## Settings

| Setting | Default | Meaning |
| --- | --- | --- |
| Climb multiple | 3 | Climb a tier once its H is under this many times the run's age. 3 suits runs of a day or so; 5 suits runs lasting several days. |
| Share per minute | 0.5 | How much of the tier below may be converted for each minute since you last hatched a unit. |
| Cooldown | 60 s | After you hatch a unit, how long before it is suggested again. |
| Banking threshold | 3 | Stop hatching a unit once the tier above already makes this many times what larvae could. |
| Territory share | 0.1 | Share of larvae kept for territory units. Set it to 0 once House of Mirrors is casting. |
| Lepidoptera target | 4000 | Lepidoptera to buy before House of Mirrors. |
| Long-run climb | off | "On" adds the long-run rules above from a run age of 2 days. It trades meat income for progress up the chain, so it is for the achievements goal, not for short runs. |
| Ascension advice | off | "Achievements route" adds the ascension lines above and makes the energy line save for the ascension when it is time. Off leaves the panel exactly as without it. |
| Spare energy before House of Mirrors | cast larva rush | Larva rush suits runs of a day or two. "Save it" holds energy for the next nexus and lepidoptera, which reaches nexus 4 and lepidoptera hours sooner; in the simulator it came out ahead from about day 4. No effect from nexus 5. |

A number setting is saved when you leave its box or press Enter; the spare-energy, long-run and ascension choices are saved as soon as you pick them. Values outside the allowed range are saved at the nearest limit, with a note. Text that isn't a number is not saved. Reset puts all of them back to the defaults. Settings are stored with your save.

## What it does not do

- It never buys, casts or changes settings for you.
- It never ascends, unlocks mutations or casts spells for you. Ascension advice is off unless you turn it on, and follows only the achievements route.
- It doesn't know how long you plan to play this run. "Climb multiple" is the only stand-in for that.
- It notices purchases from the game's statistics, about once a second, while the game is open.

## More

- [HANDOFF.md](HANDOFF.md): what the rules are and the evidence behind them.
- [MODEL-CHECK.md](MODEL-CHECK.md): how the simulator and the advisor were checked against the game's code.
- [ASCENSION.md](ASCENSION.md): the plan for earning every achievement (ascensions, the long run to endless), ascension and mutagen mechanics, and the simulator checks. The "achievements route" setting follows its part A.
- [ACHIEVEMENTS.md](ACHIEVEMENTS.md): every achievement, how the game evaluates it, and which are earned in the example save (generated).
- [BUILDING.md](BUILDING.md): building, testing and running the game.
