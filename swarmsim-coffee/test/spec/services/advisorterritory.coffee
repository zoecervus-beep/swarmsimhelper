'use strict'

# Expected values in these specs are worked out by hand from the territory part of the simulator's
# policy (advisor/sim/sim.py, policy(); advisor/sim/policy.json); the comments show the arithmetic.
describe 'Service: advisorTerritory', ->

  beforeEach module 'swarmApp'

  territory = {}
  beforeEach inject (_advisorTerritory_) ->
    territory = _advisorTerritory_

  D = (x) -> new Decimal x

  # A hand-built snapshot. Territory unit j (0 = swarmling) defaults to: meat cost 10^(j+1) per larva,
  # 1 unit per larva, twin upgrade too expensive in larvae to matter (1e30), and shown only for j < 3
  # (swarmling, stinger, spider). Larva upgrades default to shown but unaffordable.
  mksnap = (opts={}) ->
    shown = opts.shown ? 3
    units = for name, j in territory.UNITS
      u = opts.units?[name] ? {}
      visible = u.visible ? j < shown
      name: name
      label: name + 's'
      label1: name
      tier: j
      visible: visible
      count: D(u.count ? 0)
      purchases: String(u.purchases ? 0)
      twin: D(u.twin ? 1)
      meat: D(u.meat ? Math.pow(10, j + 1))
      prodEach: D(1)
      twinUpgrade:
        name: name + 'twin'
        label: 'twin ' + name + 's'
        level: u.twinLevel ? 0
        visible: u.twinVisible ? visible
        larvae: D(u.twinLarvae ? 1e30)
        meat: D(u.twinMeat ? 100)
        larvaFactor: D(50)
        meatFactor: D(500)
    upgrades = for name in territory.LARVA_UPGRADES
      up = opts.upgrades?[name] ? {}
      name: name
      label: {achievementbonus: 'accomplished ancestry'}[name] ? name
      level: up.level ? 0
      maxLevel: if name == 'achievementbonus' then 5 else null
      visible: up.visible ? true
      costs: up.costs ? [{unit: 'meat', val: D(1e300), factor: D(10)}]
    return {
      now: opts.now ? 1000e3
      restartedAt: opts.restartedAt ? 0
      larvae: D(opts.larvae ? 0)
      larvaRate: D(opts.larvaRate ? 0)
      meat: D(opts.meat ? 0)
      territory: D(opts.territory ? 0)
      mirrorCasts: opts.mirrorCasts ? 0
      units: units
      upgrades: upgrades
    }
  texts = (r) -> (territory.render x for x in r.records)
  counts = (r) -> ([h.unit, h.buys.toNumber()] for h in r.hatch)

  it 'should do something', ->
    expect(!!territory).toBe true

  describe 'which unit to hatch (balanced)', ->
    it 'fills the biggest unit all territory larvae can go into, spare meat to the next one up', ->
      # larvae for territory: 1000 - floor(1000 x 0.9) = 100; meat budget 0.9 x 50000 = 45000.
      # spider: 100 x 1000 > 45000; stinger: 100 x 100 <= 45000 => stinger, spare to spiders:
      # y = (45000 - 100 x 100) / (1000 - 100) = 38.9 spiders, x = 100 - 38.9 = 61.1 stingers.
      r = territory.advise mksnap(larvae: 1000, meat: 50000), null, {}
      expect(r.larvae.toNumber()).toBe 100
      expect(r.meatBudget.toNumber()).toBe 45000
      expect(counts r).toEqual [['stinger', 61], ['spider', 38]]
      expect(_.map r.hatch, 'role').toEqual ['main', 'spare']
      expect(r.hatch[0].meat.toNumber()).toBe 6100
      expect(r.hatch[1].meat.toNumber()).toBe 38000
      expect(texts r).toEqual ['hatch 61 stingers', 'hatch 38 spiders']
      expect(r.status).toBe null

    it 'puts everything into the top shown unit when meat allows', ->
      # spider: 100 x 1000 <= 9e8, and mosquitoes are not shown: min(100, 9e8 / 1000) = 100 spiders
      r = territory.advise mksnap(larvae: 1000, meat: 1e9), null, {}
      expect(counts r).toEqual [['spider', 100]]
      # once mosquitoes are shown, they take everything
      r = territory.advise mksnap(larvae: 1000, meat: 1e9, shown: 4), null, {}
      expect(counts r).toEqual [['mosquito', 100]]

    it 'reads the territory share setting', ->
      # 1000 - floor(1000 x 0.7) = 300 larvae; spiders: 300 x 1000 <= 9e8
      r = territory.advise mksnap(larvae: 1000, meat: 1e9), null, {territory: 0.3}
      expect(counts r).toEqual [['spider', 300]]
      expect(r.share).toBe 0.3

    it 'counts the units each larva makes', ->
      r = territory.advise mksnap(larvae: 1000, meat: 1e9, units: {spider: {twin: 8}}), null, {}
      expect(r.hatch[0].buys.toNumber()).toBe 100 # the buy box takes larvae, before twins
      expect(r.hatch[0].units.toNumber()).toBe 800
      expect(texts r).toEqual ['hatch 100 spiders (x8 twins)']

    it 'buys only what the meat pays for when even the smallest unit is too dear for all larvae', ->
      # budget 100 larvae, meat budget 450. swarmlings: 100 x 10 > 450, so the smallest unit is used;
      # stingers cost 100 <= 450 but y = (450 - 1000) / 90 < 0 => none. Swarmlings: 450 / 10 = 45.
      # (sim.py would buy all 100 swarmlings here and let meat go negative.)
      r = territory.advise mksnap(larvae: 1000, meat: 500), null, {}
      expect(counts r).toEqual [['swarmling', 45]]

    it 'says so when there is not meat for even one', ->
      r = territory.advise mksnap(larvae: 1000, meat: 10), null, {}
      expect(r.hatch).toEqual []
      expect(r.status.reason).toBe 'noMeat'
      expect(texts r).toEqual ['need 10 meat per swarmling (can spend 9)']

    it 'says so when no larvae are left for territory', ->
      # floor(0.5) - floor(0.45) = 0
      r = territory.advise mksnap(larvae: 0.5, meat: 1e9), null, {}
      expect(r.status.reason).toBe 'noLarvae'
      expect(texts r).toEqual ['no larvae left for territory']
      # 5 - floor(4.5) = 1
      r = territory.advise mksnap(larvae: 5, meat: 1e9), null, {}
      expect(counts r).toEqual [['spider', 1]]

  describe 'territory twins', ->
    # Larva income 100/s, share 0.1: limit = 600 s x 100 x 0.1 = 6000 larvae.
    # Larvae 30000 => 30000 - 27000 = 3000 for territory; meat 1e9 => budget 9e8; unit: spiders.
    opts = (twin, extra={}) -> _.extend {larvae: 30000, larvaRate: 100, meat: 1e9, units: {spider: twin}}, extra

    it 'buys the twin first when its larva price is under the limit, then hatches with the rest', ->
      r = territory.advise mksnap(opts {twinLevel: 2, twinLarvae: 2500, twinMeat: 2.5e7}), null, {}
      expect(r.twin.type).toBe 'twin'
      expect(r.twin.name).toBe 'spidertwin'
      expect(r.twin.limit.toNumber()).toBe 6000
      expect(r.twin.seconds).toBe 25 # 2500 larvae / 100 per second
      expect(r.twin.have.toNumber()).toBe 30000
      expect(r.twin.budget.toNumber()).toBe 3000
      expect(r.twin.overcommit.toNumber()).toBe 0
      # 3000 - 2500 = 500 spiders, two units per larva after the twin
      expect(counts r).toEqual [['spider', 500]]
      expect(r.hatch[0].units.toNumber()).toBe 1000
      expect(texts r).toEqual ['buy twin spiders (2,500 larvae, 2.50e7 meat)', 'hatch 500 spiders (x2 twins)']

    it 'buys the twin from all larvae on hand when the territory share cannot cover it', ->
      # The live stall: territory larvae 20000 - 18000 = 2000 < 2500, which sim.py would save up for
      # from its purse. All 20000 larvae on hand cover it, so buy it now: 2000 come from the territory
      # share, 500 more from the larvae the meat advice counts on; nothing is left to hatch.
      r = territory.advise mksnap(opts {twinLarvae: 2500, twinMeat: 2.5e7}, larvae: 20000), null, {}
      expect(r.twin.type).toBe 'twin'
      expect(r.twin.have.toNumber()).toBe 20000
      expect(r.twin.budget.toNumber()).toBe 2000
      expect(r.twin.overcommit.toNumber()).toBe 500
      expect(r.hatch).toEqual []
      expect(r.status).toBe null
      expect(texts r).toEqual ['buy twin spiders (2,500 larvae, 2.50e7 meat)']

    it 'saves for the twin, hatching nothing, while all larvae on hand fall short', ->
      # 2000 larvae on hand < 2500 (territory share 2000 - 1800 = 200)
      r = territory.advise mksnap(opts {twinLarvae: 2500}, larvae: 2000), null, {}
      expect(r.twin.type).toBe 'saveForTwin'
      expect(r.twin.have.toNumber()).toBe 2000
      expect(r.hatch).toEqual []
      expect(r.status).toBe null
      expect(texts r).toEqual ['save larvae for twin spiders: 2,000/2,500']

    it 'skips a twin over the limit', ->
      r = territory.advise mksnap(opts {twinLarvae: 6001}), null, {}
      expect(r.twin).toBe null
      expect(counts r).toEqual [['spider', 3000]]

    it 'measures the limit in the territory share of larva income', ->
      # share 0.05: limit 600 x 100 x 0.05 = 3000 < 4000; territory larvae 30000 - 28500 = 1500
      r = territory.advise mksnap(opts {twinLarvae: 4000}), null, {territory: 0.05}
      expect(r.twin).toBe null
      expect(counts r).toEqual [['spider', 1500]]
      # share 0.1: limit 6000 >= 4000; 30000 larvae on hand cover it: buy it with the 3000 territory
      # larvae and 1000 more, leaving none to hatch
      r = territory.advise mksnap(opts {twinLarvae: 4000}), null, {}
      expect(r.twin.type).toBe 'twin'
      expect(r.twin.overcommit.toNumber()).toBe 1000
      expect(r.hatch).toEqual []

    it 'considers the next unit up when the main unit has no cheap twin', ->
      # Meat 2e7 => budget 1.8e7. Spiders: 3000 x 1000 <= 1.8e7, mosquitoes: 3000 x 1e4 > 1.8e7.
      # Spider twin is too dear; the mosquito twin (1000 larvae, 100 meat) is bought.
      # Left: 2000 larvae, 1.8e7 - 100 meat. y = (17999900 - 2000 x 1000) / 9000 = 1777.8 mosquitoes,
      # x = 2000 - 1777.8 = 222.2 spiders.
      snap = mksnap shown: 4, larvae: 30000, larvaRate: 100, meat: 2e7, units: {mosquito: {twinLarvae: 1000}}
      r = territory.advise snap, null, {}
      expect(r.twin.name).toBe 'mosquitotwin'
      expect(counts r).toEqual [['spider', 222], ['mosquito', 1777]]
      expect(r.hatch[1].twin.toNumber()).toBe 2
      expect(texts r).toEqual ['buy twin mosquitos (1,000 larvae, 100 meat)', 'hatch 222 spiders', 'hatch 1,777 mosquitos (x2 twins)']

    it 'ignores twin upgrades the game does not show', ->
      r = territory.advise mksnap(opts {twinLarvae: 2500, twinVisible: false}), null, {}
      expect(r.twin).toBe null
      expect(counts r).toEqual [['spider', 3000]]

  describe 'hatchery, expansion, accomplished ancestry', ->
    ancestry = (extra={}) -> _.extend {costs: [{unit: 'meat', val: D(5e6), factor: D(1e4)}, {unit: 'territory', val: D(500), factor: D(1e4)}]}, extra
    # Functions, not values: under Karma, Decimal only becomes a global once the app's run block has
    # run (app.coffee; angular-mocks' window.module makes decimal.js export to module.exports instead),
    # i.e. inside it/beforeEach, not while describe bodies are declared.
    expansion = -> {costs: [{unit: 'territory', val: D(10), factor: D(2.45)}]}
    hatchery = -> {costs: [{unit: 'meat', val: D(300), factor: D(10)}]}

    it 'buys accomplished ancestry before an expansion', ->
      # 505 territory: ancestry takes 500, the 5 left cannot pay for an expansion (10)
      r = territory.advise mksnap(meat: 1e7, territory: 505, upgrades: {achievementbonus: ancestry(), expansion: expansion()}), null, {}
      expect(_.map r.upgrades, 'name').toEqual ['achievementbonus']
      expect(texts r).toEqual ['buy accomplished ancestry (5.00e6 meat, 500 territory)', 'no larvae left for territory']

    it 'buys an expansion when ancestry is maxed or hidden', ->
      r = territory.advise mksnap(meat: 1e7, territory: 505, upgrades: {achievementbonus: ancestry(visible: false), expansion: expansion()}), null, {}
      # 10 + 24.5 + 60.0 + 147.1 = 241.6 <= 505; the next, 360.3, is not
      expect(r.upgrades[0].levels).toBe 4
      expect(r.upgrades[0].costs[0].val.toNumber()).toBeCloseTo 241.6, 1
      r = territory.advise mksnap(meat: 1e7, territory: 505, upgrades: {achievementbonus: ancestry(level: 5), expansion: expansion()}), null, {}
      expect(_.map r.upgrades, 'name').toEqual ['expansion']

    it 'buys as many levels as are affordable, and leaves territory units the meat that is left', ->
      # hatcheries: 300 + 3000 = 3300 of 3500 meat; the next costs 30000. Meat budget 0.9 x 200 = 180.
      # 100 territory larvae: swarmlings 100 x 10 > 180 => swarmlings, capped by meat at 18.
      r = territory.advise mksnap(larvae: 1000, meat: 3500, upgrades: {hatchery: hatchery()}), null, {}
      expect(r.upgrades[0].levels).toBe 2
      expect(r.upgrades[0].from).toBe 0
      expect(r.meatBudget.toNumber()).toBe 180
      expect(texts r).toEqual ['buy hatchery x2 (3,300 meat)', 'hatch 18 swarmlings']

    it 'goes round again while each pass buys something', ->
      # pass 1: ancestry (5e6 meat, 500 territory), expansion (10), hatchery (300);
      # pass 2: expansion (24.5), hatchery (3000); pass 3: nothing (expansion 60 > 25.5 left, hatchery 3e4)
      up = {achievementbonus: ancestry(), expansion: expansion(), hatchery: hatchery()}
      r = territory.advise mksnap(meat: 5e6 + 3300 + 1, territory: 560, upgrades: up), null, {}
      expect(([u.name, u.levels] for u in r.upgrades)).toEqual [['achievementbonus', 1], ['expansion', 2], ['hatchery', 2]]

  describe 'the territory purse', ->
    # The property tested: whichever line of a suggestion is bought first, with the suggested count or
    # fewer, what is advised next (with no time passed) is the rest of the same plan; once it is all
    # bought the purse is empty and refills at share x larva income; and it never offers more than the
    # share of the larvae on hand.
    #
    # The plan, as in 'fills the biggest unit...': larvae 1000, share 0.1 => purse 100; meat 50000 =>
    # budget 45000; y = (45000 - 100 x 100) / 900 = 38.9 spiders, x = 61.1 stingers: 61 + 38, and one
    # larva left over by the flooring. Larva income 100/s refills the purse at 10/s (no territory twin
    # is cheap enough to be advised). Purchase statistics start at 5000 stingers and 7000 spiders.
    at = (o={}) ->
      mksnap
        now: 1000e3 + (o.secs ? 0) * 1000
        larvae: o.larvae ? 1000
        larvaRate: 100
        meat: o.meat ? 50000
        restartedAt: o.restartedAt ? 0
        units:
          stinger: _.extend {purchases: 5000 + (o.stingers ? 0)}, o.stinger
          spider: _.extend {purchases: 7000 + (o.spiders ? 0)}, o.spider
    first = -> territory.advise at(), null, {}
    # The advice after buying `stingers` stingers and `spiders` spiders since `first()`, at the same
    # moment unless `secs` says otherwise, with larvae and meat lowered by exactly what they cost.
    after = (o, mem=first().memory) ->
      o = _.extend {stingers: 0, spiders: 0}, o
      larvae = (o.larvae ? 1000) - o.stingers - o.spiders
      meat = (o.meat ? 50000) - o.stingers * 100 - o.spiders * 1000
      territory.advise at(_.extend({}, o, larvae: larvae, meat: meat)), mem, {}

    it 'starts as the share of the larvae on hand', ->
      r = first()
      expect(counts r).toEqual [['stinger', 61], ['spider', 38]]
      expect(r.memory.purse.toNumber()).toBe 100
      expect(r.memory.meatSpent.toNumber()).toBe 0
      expect(r.memory.seen.stinger).toBe '5000'

    it 'leaves the spare line when the main line is bought', ->
      # purse 100 - 61 = 39; meat spent 6100, meat 43900: budget 0.9 x (43900 + 6100) - 6100 = 38900.
      # 39 spiders cost 39000 > 38900, so stingers again with spare to spiders:
      # y = (38900 - 3900) / 900 = 38.9 => 38 spiders, x = 0.1 => no stingers
      r = after stingers: 61
      expect(r.memory.purse.toNumber()).toBe 39
      expect(r.memory.meatSpent.toNumber()).toBe 6100
      expect(r.meatBudget.toNumber()).toBe 38900
      expect(counts r).toEqual [['spider', 38]]

    it 'leaves the main line when the spare line is bought', ->
      # purse 62; meat spent 38000: budget 0.9 x 50000 - 38000 = 7000; 62 stingers cost 6200 and
      # y = (7000 - 6200) / 900 = 0.9 => no spiders, 61.1 => 61 stingers
      r = after spiders: 38
      expect(r.memory.purse.toNumber()).toBe 62
      expect(r.meatBudget.toNumber()).toBe 7000
      expect(counts r).toEqual [['stinger', 61]]

    it 'is used up once both lines are bought, then refills', ->
      m = after(spiders: 38).memory
      r = after {spiders: 38, stingers: 61}, m
      # the larva the flooring left over is all that remains: 900 of meat budget buys 1 stinger
      expect(r.memory.purse.toNumber()).toBe 1
      expect(counts r).toEqual [['stinger', 1]]
      r = after {spiders: 38, stingers: 62}, r.memory
      expect(r.memory.purse.toNumber()).toBe 0
      expect(r.memory.meatSpent.toNumber()).toBe 0 # the cycle ended
      expect(r.hatch).toEqual []
      expect(r.status.reason).toBe 'refilling'
      expect(r.status.seconds).toBeCloseTo 0.1, 9 # one larva at 10 a second
      expect(texts r).toEqual ['territory larvae spent for now, more in 1 s']
      # 2 s later: 20 larvae of purse and a fresh meat budget, 0.9 x the 5800 meat on hand = 5220:
      # spiders 20 x 1000 > 5220, stingers 2000 fit; y = (5220 - 2000) / 900 = 3.6 => 3 spiders,
      # x = 16.4 => 16 stingers
      r = after {spiders: 38, stingers: 62, secs: 2, larvae: 1200}, r.memory
      expect(r.memory.purse.toNumber()).toBe 20
      expect(r.meatBudget.toNumber()).toBe 5220
      expect(counts r).toEqual [['stinger', 16], ['spider', 3]]

    it 'keeps the rest of the plan when fewer than suggested are bought', ->
      # 50 of 61 stingers: purse 50, meat spent 5000, budget 45000 - 5000 = 40000;
      # y = (40000 - 5000) / 900 = 38.9 => 38 spiders; x = 11.1 => 11 stingers
      r = after stingers: 50
      expect(counts r).toEqual [['stinger', 11], ['spider', 38]]

    it 'is emptied by buying more than the purse holds (buy-max)', ->
      # 500 stingers: purse max(0, 100 - 500) = 0, cycle over
      r = after stingers: 500
      expect(r.memory.purse.toNumber()).toBe 0
      expect(r.memory.meatSpent.toNumber()).toBe 0
      expect(r.status.reason).toBe 'refilling'

    it 'refills between purchases, keeping the unbought line', ->
      # main line bought, seen 1 s later with 100 more larvae and 1000 more meat:
      # purse 100 + 10 - 61 = 49; budget 0.9 x (44900 + 6100) - 6100 = 39800;
      # y = (39800 - 4900) / 900 = 38.8 => 38 spiders, x = 10.2 => 10 stingers
      r = after stingers: 61, secs: 1, larvae: 1100, meat: 51000
      expect(r.memory.purse.toNumber()).toBe 49
      expect(counts r).toEqual [['stinger', 10], ['spider', 38]]

    it 'stays affordable when meat is spent elsewhere in between', ->
      # main line bought, then 10000 meat on meat units: meat 33900;
      # budget 0.9 x (33900 + 6100) - 6100 = 29900 <= 0.9 x 33900;
      # y = (29900 - 3900) / 900 = 28.9 => 28 spiders, x = 10.1 => 10 stingers: 29000 meat
      r = after stingers: 61, meat: 40000
      expect(r.meatBudget.toNumber()).toBe 29900
      expect(counts r).toEqual [['stinger', 10], ['spider', 28]]
      # with almost no meat left the budget is 0, not negative
      r = after stingers: 61, meat: 6100
      expect(r.meatBudget.toNumber()).toBe 0
      expect(r.status.reason).toBe 'noMeat'

    it 'never holds more than the share of the larvae on hand', ->
      # main line bought, 1000 s later, but larvae spent elsewhere down to 500: purse 39 + 10000,
      # capped at 500 - 450 = 50
      r = after stingers: 61, secs: 1000, larvae: 561
      expect(r.memory.purse.toNumber()).toBe 50

    it 'takes a twin bought after the units out of the purse, never reopening it', ->
      m = after(spiders: 38, stingers: 61).memory # purse 1
      # the stinger twin goes from level 0 to 1; its price when last seen (1e30 larvae) is taken out
      r = after {spiders: 38, stingers: 61, stinger: {twinLevel: 1}}, m
      expect(r.memory.purse.toNumber()).toBe 0
      expect(r.status.reason).toBe 'refilling'

    it 'takes the twin and its meat out of the plan when the twin is bought first', ->
      # As in 'buys the twin first...': 3000 territory larvae, twin 2500 larvae + 2.5e7 meat, then
      # 500 spiders x2. After buying the twin: purse 500, meat spent 2.5e7,
      # budget 0.9 x 1e9 - 2.5e7 = 8.75e8 => the same 500 spiders.
      snap = (level, larvae, meat) ->
        mksnap larvae: larvae, larvaRate: 100, meat: meat, units: {spider: {twinLevel: level, twin: Math.pow(2, level), twinLarvae: 2500 * Math.pow(50, level), twinMeat: 2.5e7 * Math.pow(500, level)}}
      r = territory.advise snap(0, 30000, 1e9), null, {}
      expect(r.twin.type).toBe 'twin'
      expect(counts r).toEqual [['spider', 500]]
      r = territory.advise snap(1, 27500, 1e9 - 2.5e7), r.memory, {}
      expect(r.twin).toBe null
      expect(r.memory.purse.toNumber()).toBe 500
      expect(r.meatBudget.toNumber()).toBe 8.75e8
      expect(counts r).toEqual [['spider', 500]]
      expect(r.hatch[0].twin.toNumber()).toBe 2

    it 'ignores unit counts, which House of Mirrors doubles', ->
      r = territory.advise at(stinger: {count: 1e6}), first().memory, {}
      expect(r.memory.purse.toNumber()).toBe 100
      expect(counts r).toEqual [['stinger', 61], ['spider', 38]]

    it 'starts afresh in a new run', ->
      m = after(stingers: 61).memory
      r = territory.advise at(restartedAt: 1500e3, larvae: 939, meat: 43900), m, {}
      expect(r.memory.restartedAt).toBe 1500e3
      # 939 - floor(845.1) = 94; budget 0.9 x 43900 = 39510
      expect(r.memory.purse.toNumber()).toBe 94
      expect(r.memory.meatSpent.toNumber()).toBe 0

  describe 'once House of Mirrors has been cast', ->
    it 'advises no territory units and a territory share of 0', ->
      snap = mksnap larvae: 30000, larvaRate: 100, meat: 1e9, mirrorCasts: 3, units: {spider: {twinLarvae: 10}}
      r = territory.advise snap, null, {}
      expect(r.mirrors).toBe true
      expect(r.hatch).toEqual []
      expect(r.twin).toBe null
      expect(r.setting).toEqual {type: 'setShare', share: 0.1, to: 0}
      expect(texts r).toEqual ['set the territory share to 0 (now 0.1)', 'House of Mirrors is running: hatch no more territory units']

    it 'drops the setting advice once the share is 0, and still advises larva upgrades', ->
      snap = mksnap meat: 1e4, mirrorCasts: 1, upgrades: {hatchery: {costs: [{unit: 'meat', val: D(300), factor: D(10)}]}}
      r = territory.advise snap, null, {territory: 0}
      expect(r.setting).toBe null
      expect(texts r).toEqual ['House of Mirrors is running: hatch no more territory units', 'buy hatchery x2 (3,300 meat)']

  describe 'early game', ->
    it 'says when no territory unit is shown yet', ->
      r = territory.advise mksnap(larvae: 1000, meat: 1e9, shown: 0), null, {}
      expect(r.status.reason).toBe 'locked'
      expect(texts r).toEqual ['no territory units yet']

    it 'does nothing for territory at a share of 0', ->
      r = territory.advise mksnap(larvae: 1000, meat: 1e9), null, {territory: 0}
      expect(r.hatch).toEqual []
      expect(texts r).toEqual ['territory share is 0: no territory units']

  describe 'on the real game', ->
    Game = {}
    beforeEach inject (_Game_) ->
      Game = _Game_
    mkgame = (unittypes, upgrades={}) ->
      reified = new Date 0
      game = new Game {state: {unittypes: unittypes, upgrades: upgrades, achievements: {}, date: {reified: reified, started: reified, restarted: reified}}, save: ->}
      game.now = new Date 0
      return game

    it 'handles a brand-new game', inject (game) ->
      game.reset true
      r = territory.update()
      # 10 larvae, 35 meat, no queens: territory units need 5 queens; a hatchery costs 300 meat
      expect(r.config.territory).toBe 0.1
      expect(texts r).toEqual ['no territory units yet']

    it 'starts on swarmlings with a hatchery and the first twin', ->
      game = mkgame {invisiblehatchery: 1, larva: 100, meat: 10000, queen: 5}
      snap = territory.snapshot game
      expect(_.map(_.filter(snap.units, 'visible'), 'name')).toEqual ['swarmling'] # stingers need 101250 meat
      expect(snap.larvaRate.toNumber()).toBe 1
      # hatchery 300 + 3000 meat => meat budget 0.9 x 6700 = 6030. Swarmling twin: 1 larva <= 600 s x 1/s
      # x 0.1 = 60, 100 meat: bought. Then 10 - 1 = 9 larvae, 5930 meat: 750 x 9 > 5930 => 7 swarmlings.
      r = territory.advise snap, null, {}
      expect(texts r).toEqual ['buy hatchery x2 (3,300 meat)', 'buy twin swarmlings (1 larva, 100 meat)', 'hatch 7 swarmlings (x2 twins)']

    it 'knows House of Mirrors was cast this run, until the next ascension', ->
      game = mkgame {invisiblehatchery: 1, larva: 1e6, meat: 1e9, queen: 5, nexus: 5, energy: 1e4}
      expect(territory.snapshot(game).mirrorCasts).toBe 0
      game.upgrade('clonearmy').buy 2
      expect(territory.snapshot(game).mirrorCasts).toBe 2
      expect(territory.advise(territory.snapshot(game), null, {}).mirrors).toBe true
      game.ascend true
      expect(territory.snapshot(game).mirrorCasts).toBe 0

    # The owner's run at 27 minutes (the reported bug): two lines, stingers and arachnomorphs.
    ownerGame = (game) ->
      game.reset true
      for name, val of {larva: 2787, meat: 1.596e10, territory: 15527238, queen: 29081, swarmling: 861, stinger: 3908, spider: 1136}
        game.unit(name)._setCount val
      for name, val of {hatchery: 8, expansion: 16, achievementbonus: 1, swarmlingtwin: 2, stingertwin: 3, spidertwin: 3}
        game.upgrade(name)._setCount val
      return game
    # 2787 - floor(2508.3) = 279 territory larvae; meat budget 0.9 x 1.596e10 = 1.4364e10 (hatchery 3e10,
    # expansion 1.66e7 territory and ancestry 5e10 meat are out of reach; twins cost 125000 larvae,
    # over 600 s x 41.4 larvae/s x 0.1). 279 arachnomorphs cost 4.24e10, 279 stingers 9.42e7:
    # y = (1.4364e10 - 9.416e7) / (151875000 - 337500) = 94.2 arachnomorphs, x = 184.8 stingers.
    it 'keeps the second line after the first is bought through the game (owner save)', inject (game, commands, statistics) ->
      ownerGame game
      r = territory.update()
      expect(counts r).toEqual [['stinger', 184], ['spider', 94]]
      commands.buyUnit {unit: game.unit('stinger'), num: r.hatch[0].buys}
      expect(game.unit('stinger').statistics().num.toString()).toBe '184'
      r = territory.update()
      # purse 279 - 184 = 95; budget 1.4364e10 - 184 x 337500 = 1.43019e10 < 95 arachnomorphs:
      # y = (1.43019e10 - 95 x 337500) / 151537500 = 94.2, x = 0.8
      expect(r.memory.purse.toNumber()).toBe 95
      expect(counts r).toEqual [['spider', 94]]
      expect(territory.memory()).toBe r.memory

    it 'keeps the first line after the second is bought through the game (owner save)', inject (game, commands, statistics) ->
      ownerGame game
      territory.update()
      commands.buyUnit {unit: game.unit('spider'), num: 94}
      r = territory.update()
      # purse 185; budget 1.4364e10 - 94 x 151875000 = 8.775e7, less than one arachnomorph, so all 185
      # go to stingers (6.24e7 of meat): the 184 of the plan plus the larva its flooring left over
      expect(r.memory.purse.toNumber()).toBe 185
      expect(counts r).toEqual [['stinger', 185]]

    it 'forgets the purchase memory on import and reset', inject ($rootScope) ->
      territory.update()
      expect(territory.memory()).not.toBe null
      $rootScope.$broadcast 'import', {success: false}
      expect(territory.memory()).not.toBe null
      $rootScope.$broadcast 'import', {success: true}
      expect(territory.memory()).toBe null
      territory.update()
      $rootScope.$broadcast 'reset'
      expect(territory.memory()).toBe null

    it 'advises afresh after any purchase instead of serving the cached advice', inject ($rootScope) ->
      a = territory.current 1000, 5000
      expect(territory.current(1000, 5001)).toBe a
      $rootScope.$emit 'command', {name: 'buyUnit'}
      expect(territory.current(1000, 5002)).not.toBe a

    it 'caches the live advice, at most once per interval', ->
      spyOn(territory, 'update').and.callThrough()
      a = territory.current 1000, 5000
      expect(a.error).toBe null
      expect(territory.current(1000, 5999)).toBe a
      expect(territory.current(1000, 6000)).not.toBe a
      expect(territory.update.calls.count()).toBe 2

describe 'Service: advisorTerritory on a real save', ->

  beforeEach module 'swarmApp'

  territory = {}
  Game = {}
  session = {}
  beforeEach inject (_advisorTerritory_, _Game_, _session_) ->
    territory = _advisorTerritory_
    Game = _Game_
    session = _session_

  # The owner's save from 14.5 hours into a run, loaded as in test/spec/services/advisor.coffee.
  fetchSave = ->
    files = window.__karma__?.files ? {}
    url = _.find _.keys(files), (f) -> /advisor\/sim\/example_save_14h\.json$/.test f
    if not url?
      throw new Error 'advisor/sim/example_save_14h.json is not served by karma; add it to the karma files list'
    xhr = new XMLHttpRequest()
    xhr.open 'GET', url, false
    xhr.send()
    return JSON.parse xhr.responseText
  loadGame = ->
    state = session._loads session._saves fetchSave(), false
    shift = (new Date().getTime() - 3600e3) - state.date.reified.getTime()
    for key, date of state.date
      state.date[key] = new Date date.getTime() + shift
    game = new Game {state: state, save: ->}
    game.now = new Date state.date.reified.getTime()
    game.cache.onUpdate()
    return game

  it 'builds a sane snapshot', ->
    snap = territory.snapshot loadGame()
    expect(snap.mirrorCasts).toBe 0
    expect(snap.meat.toString()).toBe '1.1925445353869864208e+31'
    expect(_.map snap.units, 'name').toEqual territory.UNITS
    expect(_.every snap.units, 'visible').toBe true
    expect(_.map snap.units, 'label').toEqual ['swarmlings', 'stingers', 'arachnomorphs', 'culicimorphs', 'locusts', 'roaches',
      'giant arachnomorphs', 'chilopodomorphs', 'wasps', 'devourers', 'goons']
    # meat per larva: 750 x 450^j, as the game's table stores it
    for u in snap.units
      expect(u.meat.toNumber() / (750 * Math.pow(450, u.tier))).toBeCloseTo 1, 5
    # twin levels 4 (devourer 5): 50^level larvae, 100 x 500^level meat
    byName = _.keyBy snap.units, 'name'
    expect(byName.wasp.twin.toNumber()).toBe 16
    expect(byName.wasp.twinUpgrade.larvae.toNumber()).toBe 6.25e6
    expect(byName.wasp.twinUpgrade.meat.toNumber()).toBe 6.25e12
    expect(byName.devourer.twinUpgrade.larvae.toNumber()).toBe 3.125e8
    ups = _.keyBy snap.upgrades, 'name'
    expect(ups.achievementbonus.visible).toBe false # level 5 of 5
    expect(ups.expansion.costs[0].val.toNumber() / (10 * Math.pow(2.45, 57))).toBeCloseTo 1, 9
    expect(ups.hatchery.costs[0].val.toNumber()).toBe 3e31

  it 'gives the advice the simulator gives', ->
    r = territory.advise territory.snapshot(loadGame()), null, {}
    # Territory larvae: 3339890 - floor(3339890.25 x 0.9) = 333989; meat budget 0.9 x 1.1925e31 = 1.0733e31.
    # Devourers: 333989 x 5.6751e26 > budget; wasps: 333989 x 1.26113e24 = 4.21e29 fits, so wasps,
    # spare meat to devourers: y = (1.0733e31 - 4.212e29) / (5.6751e26 - 1.26113e24) = 18210.5.
    # sim.py's policy at a check-in with purse = 0.1 x the larvae on hand buys the same:
    # 315778 wasps and 18210 devourers.
    expect(r.larvae.toNumber()).toBe 333989
    expect(r.twin).toBe null # wasp twin 6.25e6 larvae > 600 s x 94610/s x 0.1 = 5.68e6
    expect(r.upgrades).toEqual [] # hatchery 3e31 meat, expansion 1.52e23 territory: neither on hand
    expect(([h.unit, h.buys.toNumber(), h.units.toNumber()] for h in r.hatch)).toEqual [['wasp', 315778, 315778 * 16], ['devourer', 18210, 18210 * 32]]
    expect((territory.render x for x in r.records)).toEqual ['hatch 315,778 wasps (x16 twins)', 'hatch 18,210 devourers (x32 twins)']
