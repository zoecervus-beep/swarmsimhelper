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
| Spare energy before House of Mirrors | cast larva rush | Larva rush suits runs of a day or two. "Save it" holds energy for the next nexus and lepidoptera, which reaches nexus 4 and lepidoptera hours sooner; in the simulator it came out ahead from about day 4. No effect from nexus 5. |

A number setting is saved when you leave its box or press Enter; the spare-energy choice is saved as soon as you pick it. Values outside the allowed range are saved at the nearest limit, with a note. Text that isn't a number is not saved. Reset puts all of them back to the defaults. Settings are stored with your save.

## What it does not do

- It never buys, casts or changes settings for you.
- It gives no advice on ascension or mutagen.
- It doesn't know how long you plan to play this run. "Climb multiple" is the only stand-in for that.
- It notices purchases from the game's statistics, about once a second, while the game is open.

## More

- [HANDOFF.md](HANDOFF.md): what the rules are and the evidence behind them.
- [MODEL-CHECK.md](MODEL-CHECK.md): how the simulator and the advisor were checked against the game's code.
- [ASCENSION.md](ASCENSION.md): the plan for earning every achievement (ascensions, the long run to endless), ascension and mutagen mechanics, and the simulator checks (not yet in the panel).
- [ACHIEVEMENTS.md](ACHIEVEMENTS.md): every achievement, how the game evaluates it, and which are earned in the example save (generated).
- [BUILDING.md](BUILDING.md): building, testing and running the game.
