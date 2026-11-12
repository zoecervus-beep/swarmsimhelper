'use strict'

# Expected values in these specs are worked out by hand from the rules in advisor/swarm-climb-live.js
# (the reference implementation); the comments show the arithmetic.
describe 'Service: advisor', ->

  beforeEach module 'swarmApp'

  advisor = {}
  beforeEach inject (_advisor_) ->
    advisor = _advisor_

  D = (x) -> new Decimal x

  # A hand-built snapshot. Every chain unit defaults to: count 0, cost 100 of the tier below,
  # production = its tier number (as in the game), twin 1, and twin/faster upgrades too expensive
  # to matter. Times are in milliseconds; the run starts at 0.
  mksnap = (opts={}) ->
    units = for name, i in advisor.CHAIN
      u = opts.units?[name] ? {}
      name: name
      tier: i + 1
      below: if i > 0 then advisor.CHAIN[i - 1] else 'meat'
      count: D(u.count ? 0)
      cost: if i > 0 then D(u.cost ? 100) else null
      twin: D(u.twin ? 1)
      prodEach: D(u.prodEach ? i + 1)
      twinCost: if u.twinCost is null then null else D(u.twinCost ? 1e30)
      twinFactor: D(u.twinFactor ? 10)
      prodCost: if u.prodCost is null then null else D(u.prodCost ? 1e30)
      purchases: String(u.purchases ? 0)
    return {
      now: opts.now ? 1000e3
      restartedAt: opts.restartedAt ? 0
      larvae: D(opts.larvae ? 0)
      larvaRate: D(opts.larvaRate ? 0)
      units: units
      energy: opts.energy ? {nexus: 0, energy: D(0), moths: D(0), next: null}
    }
  tier = (result, name) -> _.find result.tiers, (t) -> t.name == name
  tipsOf = (result, type) -> _.filter result.tips, (t) -> t.type == type
  texts = (result) -> (advisor.renderTip t for t in result.tips)

  it 'should do something', ->
    expect(!!advisor).toBe true

  it 'formats numbers and times like the console script', ->
    expect(advisor.formatNumber 0).toBe '0'
    expect(advisor.formatNumber 999999.9).toBe '999,999'
    expect(advisor.formatNumber 175270).toBe '175,270'
    expect(advisor.formatNumber 1e6).toBe '1.00e6'
    expect(advisor.formatNumber D '1.1925445353869864208e+31').toBe '1.19e31'
    expect(advisor.formatNumber D '1e400').toBe '1.00e400'
    expect(advisor.formatTime 89).toBe '89 s'
    expect(advisor.formatTime 90).toBe '2 min'
    expect(advisor.formatTime 5400).toBe '1.5 h'
    expect(advisor.formatTime 172800).toBe '2.0 d'
    expect(advisor.formatTime 86400 * 730).toBe '2 y'
    expect(advisor.formatTime D '1e400').toBe 'ages'
    expect(advisor.formatTime -5).toBe '0 s'
    expect(advisor.formatTime NaN).toBe '-'

  describe 'when a tier may be climbed', ->
    # nest: payback = 1000 / (1 twin x 1 prod) = 1000 s, H = 3 x 1000 = 3000 s
    units = drone: {count: 1e12}, queen: {count: 1e6}, nest: {cost: 1000, prodEach: 1}

    it 'climbs exactly when H = horizon', ->
      r = advisor.advise mksnap(now: 1000e3, units: units, larvae: 1e6, larvaRate: 10), null, {}
      expect(r.age).toBe 1000
      expect(r.horizon).toBe 3000
      nest = tier r, 'nest'
      expect(nest.payback.toNumber()).toBe 1000
      expect(nest.H.toNumber()).toBe 3000
      expect(nest.passes).toBe true
      # affordable 1e6/1000 = 1000; first look: 60 s since, share 0.5 => 500;
      # spare = 1e6 queens x 60/1000 released / 1000 = 60; larvae left 900000
      expect(nest.kind).toBe 'buy'
      expect(nest.buys.toNumber()).toBe 60
      expect(advisor.renderAction nest).toBe 'BUY 60'

    it 'waits just below the boundary', ->
      r = advisor.advise mksnap(now: 1000e3 - 1, units: units, larvae: 1e6, larvaRate: 10), null, {}
      nest = tier r, 'nest'
      expect(nest.passes).toBe false
      expect(nest.kind).toBe 'wait'
      expect(nest.reason).toBe 'tooSlow'
      # H / ageMultiple - age = 1000 - 999.999
      expect(nest.waitSeconds).toBeCloseTo 0.001, 9
      expect(nest.buys.toNumber()).toBe 0
      expect(advisor.renderAction nest).toBe 'wait 0 s'

    it 'reports the wait time and honours ageMultiple', ->
      r = advisor.advise mksnap(now: 500e3, units: units, larvae: 1e6, larvaRate: 10), null, {}
      expect(tier(r, 'nest').waitSeconds).toBe 500 # 3000/3 - 500
      expect(advisor.renderAction tier r, 'nest').toBe 'wait 8 min'
      r = advisor.advise mksnap(now: 500e3, units: units, larvae: 1e6, larvaRate: 10), null, {ageMultiple: 6}
      expect(tier(r, 'nest').passes).toBe true # 3000 <= 6 x 500

    it 'asks for more of the tier below when not affordable', ->
      r = advisor.advise mksnap(now: 1000e3, units: {drone: {count: 1e12}, queen: {count: 999}, nest: {cost: 1000, prodEach: 1}}, larvae: 1e6), null, {}
      nest = tier r, 'nest'
      expect(nest.reason).toBe 'needBelow'
      expect(advisor.renderAction nest).toBe 'need more queens'

    it 'shows two tiers above the highest owned unit', ->
      r = advisor.advise mksnap(units: {drone: {count: 1e12}, queen: {count: 1e6}}), null, {}
      expect(r.top).toBe 'queen'
      expect(_.map r.tiers, 'name').toEqual ['queen', 'nest', 'greaterqueen']
      r = advisor.advise mksnap(units: {overmind5: {count: 1}}), null, {}
      expect(_.last(r.tiers).name).toBe 'overmind6'
      expect(r.tiers.length).toBe 19

  describe 'larva allocation', ->
    it 'gives larvae to the highest passing tier first', ->
      # nest count 1 => tiers queen..hive; GQ and hive cannot be afforded.
      units = drone: {count: 1e12}, queen: {count: 1e12}, nest: {count: 1}
      r = advisor.advise mksnap(units: units, larvae: 1000, larvaRate: 1000), null, {}
      expect(_.map r.tiers, 'name').toEqual ['queen', 'nest', 'greaterqueen', 'hive']
      expect(tier(r, 'hive').reason).toBe 'needBelow'
      expect(tier(r, 'greaterqueen').reason).toBe 'needBelow'
      # left = floor(1000 x 0.9) = 900, all of it to nests
      expect(tier(r, 'nest').buys.toNumber()).toBe 900
      queen = tier r, 'queen'
      expect(queen.kind).toBe 'skip'
      expect(queen.reason).toBe 'larvaeUsedAbove'
      expect(queen.hatching).toBe true
      expect(advisor.renderAction queen).toBe 'skip: larvae used above'

    it 'passes what the higher tier cannot use down to the lower one', ->
      units = drone: {count: 1e12}, queen: {count: 1e5}, nest: {count: 1, twin: 4}
      r = advisor.advise mksnap(units: units, larvae: 3000, larvaRate: 1000), null, {}
      # nest: affordable 1e5/100 = 1000, x share 0.5 = 500; spare 1e5/100 = 1000; left 2700 => 500
      nest = tier r, 'nest'
      expect(nest.buys.toNumber()).toBe 500
      expect(advisor.renderAction nest).toBe 'BUY 500 (x4 twins)'
      # queen gets the remaining 2700 - 500
      expect(tier(r, 'queen').buys.toNumber()).toBe 2200
      expect(advisor.renderAction tier r, 'queen').toBe 'BUY 2,200'

    it 'holds back the territory share', ->
      # only drones owned: queen is the only affordable tier
      units = drone: {count: 1e12}
      r = advisor.advise mksnap(units: units, larvae: 1000, larvaRate: 1000), null, {territory: 0.25}
      expect(tier(r, 'queen').buys.toNumber()).toBe 750
      expect(r.spendable.toNumber()).toBe 750

  describe 'purchase sizing over time', ->
    # A slow new top tier: nest payback = 1000 / 0.01 = 1e5 s, H = 3e5 s; run age 2e5 s, horizon 6e5 s.
    # Queens below it are the stockpile. 1000 larvae => 900 to spend.
    t0 = 2e8
    mk = (now, queens, nestPurchases) ->
      mksnap
        now: now
        larvae: 1000
        larvaRate: 1
        units:
          drone: {count: 1e12}
          queen: {count: queens}
          nest: {cost: 1000, prodEach: 0.01, purchases: nestPurchases}

    it 'converts income, not the stockpile, into a slow top tier, with a cooldown after buying', ->
      # Tick 1: first look counts as 60 s since the last purchase.
      r1 = advisor.advise mk(t0, 1e6, 0), null, {}
      nest = tier r1, 'nest'
      expect(nest.since).toBe 60
      # spare = 1e6 x 60/1e5 / 1000 = 0.6 purchases
      expect(nest.spare.toNumber()).toBeCloseTo 0.6, 12
      expect(nest.reason).toBe 'buildUp'
      expect(advisor.renderAction nest).toBe 'let queens build up'
      expect(tier(r1, 'queen').buys.toNumber()).toBe 900
      m1 = r1.memory
      expect(m1.startedAt).toBe t0
      expect(m1.seen.nest).toBe '0'
      expect(m1.boughtAt.nest).toBe t0 - 60e3
      expect(m1.stockAt.nest.toNumber()).toBe 1e6

      # Tick 2, 1000 s later; queens grew to 1.5e6.
      # since 1060; affordable 1500 x (1 - 0.5^(1060/60)) ~ 1499.99;
      # spare = (5e5 gained + 1e6 x 1060/1e5) / 1000 = 510.6
      r2 = advisor.advise mk(t0 + 1000e3, 1.5e6, 0), m1, {}
      nest = tier r2, 'nest'
      expect(nest.spare.toNumber()).toBeCloseTo 510.6, 9
      expect(nest.buys.toNumber()).toBe 510
      expect(advisor.renderAction nest).toBe 'BUY 510'
      expect(tier(r2, 'queen').buys.toNumber()).toBe 390 # 900 - 510
      m2 = r2.memory

      # Tick 3, 1 s later: the player bought 510 nests (510000 queens).
      # Purchase detected: cooldown, and min(900, 990 x 0.5) = 495 larvae stay earmarked.
      r3 = advisor.advise mk(t0 + 1001e3, 990000, 510), m2, {}
      nest = tier r3, 'nest'
      expect(nest.kind).toBe 'wait'
      expect(nest.reason).toBe 'cooldown'
      expect(nest.waitSeconds).toBe 60
      expect(nest.earmarked.toNumber()).toBe 495
      expect(nest.hatching).toBe true
      expect(advisor.renderAction nest).toBe 'done, next in 60 s'
      expect(tier(r3, 'queen').buys.toNumber()).toBe 405 # 900 - 495
      expect(r3.memory.boughtAt.nest).toBe t0 + 1001e3
      expect(r3.memory.stockAt.nest.toNumber()).toBe 990000 # re-measured after the purchase
      # the earlier memory was not touched
      expect(m2.seen.nest).toBe '0'
      expect(m2.stockAt.nest.toNumber()).toBe 1e6

      # Tick 4, 61 s after the purchase, no growth: spare = 990000 x 61/1e5 / 1000 = 0.6039
      r4 = advisor.advise mk(t0 + 1062e3, 990000, 510), r3.memory, {}
      nest = tier r4, 'nest'
      expect(nest.since).toBe 61
      expect(nest.spare.toNumber()).toBeCloseTo 0.6039, 12
      expect(nest.reason).toBe 'buildUp'
      expect(tier(r4, 'queen').buys.toNumber()).toBe 900

    it 'releases the whole stock at once for a fast-payback tier', ->
      # queen payback = 100 / 2 = 50 s < 60 s since: spare = 1e12/100 = 1e10, share caps it at 5e9
      snap = mksnap now: t0, larvae: 1e12, larvaRate: 1, units: {drone: {count: 1e12}}
      r = advisor.advise snap, null, {territory: 0}
      expect(tier(r, 'queen').spare.toNumber()).toBe 1e10
      expect(tier(r, 'queen').buys.toNumber()).toBe 5e9
      r = advisor.advise snap, null, {territory: 0, share: 0.25}
      expect(tier(r, 'queen').buys.toNumber()).toBe 2.5e9

  describe 'banking larvae', ->
    # queen twin 4, nest twin 2, nest makes 3 queens/s each. Larvae 100/s => 90/s spendable.
    # Larvae could hatch 90 x 4 / 2 = 180 queens/s (as the script computes it); bank above 3 x 180 = 540,
    # i.e. above 180 nests.
    mk = (nests, nestCost=100) ->
      mksnap larvae: 1e6, larvaRate: 100, units:
        drone: {count: 1e12}
        queen: {count: 1000, twin: 4}
        nest: {count: nests, twin: 2, cost: nestCost}

    it 'banks once the tier above makes more than bank x what larvae could', ->
      queen = tier advisor.advise(mk(181), null, {}), 'queen'
      expect(queen.kind).toBe 'skip'
      expect(queen.reason).toBe 'bank'
      expect(queen.bankFor).toBe 'nest'
      expect(queen.hatching).toBe false
      expect(advisor.renderAction queen).toBe 'skip: bank larvae for nests'

    it 'does not bank at the threshold', ->
      expect(tier(advisor.advise(mk(180), null, {}), 'queen').reason).toBe 'buy'

    it 'uses the bank setting', ->
      expect(tier(advisor.advise(mk(180), null, {bank: 2.9}), 'queen').reason).toBe 'bank'

    it 'does not bank for a tier above that does not pass', ->
      # nest H = 3 x 1e9 / (2 x 3) = 5e8 s
      expect(tier(advisor.advise(mk(1e6, 1e9), null, {}), 'queen').reason).toBe 'buy'

  describe 'faster production tips', ->
    it 'suggests a faster upgrade once the count is twice its cost, drones first', ->
      units =
        drone: {count: 2000, prodCost: 1000}
        queen: {count: 200, prodCost: 100}
        nest: {count: 199, prodCost: 100}
        greaterqueen: {count: 10, prodCost: 5}
      r = advisor.advise mksnap(units: units), null, {}
      expect(_.map tipsOf(r, 'faster'), 'unit').toEqual ['drone', 'queen', 'greaterqueen']
      expect(texts r).toEqual ['faster drones (1,000)', 'faster queens (100)', 'faster greaterqueens (5)']
      expect(tipsOf(r, 'faster')[1].cost.toNumber()).toBe 100

    it 'only looks at drones and the listed tiers', ->
      # top owned: queen => tiers queen, nest, greaterqueen; hive is not listed
      units =
        drone: {count: 1999, prodCost: 1000}
        queen: {count: 1}
        nest: {count: 0.5, prodCost: 0.1}
        hive: {count: 0.5, prodCost: 0.1}
      r = advisor.advise mksnap(units: units), null, {}
      expect(_.map r.tips, 'unit').toEqual ['nest']

  describe 'twin tips, affordable now', ->
    # Queens are climbed. Spendable larvae 90/s. Queens' own rate: 1000 x 2 / 100 = 20/s, so the
    # hatch rate is min(90, 20) = 20 queens/s. Twin cost tc nests, each making 3 queens/s.
    mk = (tc, nests, nestCost=100) ->
      mksnap larvae: 1e6, larvaRate: 100, units:
        drone: {count: 1e12}
        queen: {count: 1000, twinCost: tc}
        nest: {count: nests, cost: nestCost}

    it 'suggests a twin when the hatch rate beats what the sacrificed units made', ->
      # sacrificed 5 x 3 = 15 <= 20; nests make 10 x 3 = 30 < 90 larvae could
      r = advisor.advise mk(5, 10), null, {}
      expect(r.tips).toEqual [{type: 'twin', unit: 'queen', payIn: 'nest', cost: D(5)}]
      expect(texts r).toEqual ['twin queens (5 nests)']

    it 'does not when the sacrificed units made more', ->
      # sacrificed 7 x 3 = 21 > 20
      expect(advisor.advise(mk(7, 10), null, {}).tips).toEqual []

    it 'does not when the climbed tier above already makes more than larvae do', ->
      # nests make 31 x 3 = 93 > 90
      expect(advisor.advise(mk(5, 31), null, {}).tips).toEqual []

    it 'still suggests it when the tier above is held only for twins', ->
      # nest H = 3 x 1e6 / 3 = 1e6 s > horizon 3000 s, so the guard does not apply
      r = advisor.advise mk(5, 31, 1e6), null, {}
      expect(texts r).toEqual ['twin queens (5 nests)']

    it 'ignores tiers that are not being climbed', ->
      units = drone: {count: 1e12}, queen: {count: 1000, twinCost: 5, cost: 1e9}, nest: {count: 10}
      expect(advisor.advise(mksnap(larvae: 1e6, larvaRate: 100, units: units), null, {}).tips).toEqual []

  describe 'twin plans', ->
    # Run age 1e5 s, horizon 3e5 s. Queens are climbed with all 90 spendable larvae/s
    # (own rate 1.2e7 x 2 / 100 is far higher). Their twin costs 10 nests; nests cost 1e6 queens and
    # do not pass (H = 3 x 1e6 / 3 = 1e6 s).
    mk = (queens, nests, now=1e8) ->
      mksnap now: now, larvae: 1e6, larvaRate: 100, units:
        drone: {count: 1e12}
        queen: {count: queens, twinCost: 10}
        nest: {count: nests, cost: 1e6, twinCost: 1}

    it 'plans hatching the tier a twin is paid in', ->
      # need 6 nests = 6e6 queens; twin nests first would need 100 nests' worth of greater queens: no.
      # payback 6e6 / 90 = 66667 s; x (tier 2 + 1) = 2e5 < 3e5; queens 1.2e7 >= 2 x 6e6
      r = advisor.advise mk(1.2e7, 4), null, {}
      tips = tipsOf r, 'twinPlan'
      expect(tips.length).toBe 1
      expect(tips[0].unit).toBe 'queen'
      expect(tips[0].payIn).toBe 'nest'
      expect(tips[0].planCost.toNumber()).toBe 6e6
      expect(tips[0].payback.toNumber()).toBeCloseTo 66666.667, 2
      expect(tips[0].steps).toEqual [{type: 'hatch', unit: 'nest', count: D(6)}]
      expect(texts r).toEqual ['hatch 6 nests > twin queens (pays back in 18.5 h)']

    it 'uses the singular for one hatch', ->
      # 1e6 / 90 = 11111 s
      expect(texts advisor.advise(mk(2e6, 9), null, {})).toEqual ['hatch 1 nest > twin queens (pays back in 3.1 h)']

    it 'needs twice the plan cost in stock', ->
      expect(advisor.advise(mk(1.2e7 - 1, 4), null, {}).tips).toEqual []

    it 'needs the plan to pay back within the horizon', ->
      # horizon 1.8e5 < 2e5
      expect(advisor.advise(mk(1.2e7, 4, 6e7), null, {}).tips).toEqual []

    it 'chains through more than one tier in a late-game state', ->
      # Made-up late game. Arch-minds (pantheon5) are climbed with 9e4 larvae/s; their twin costs
      # 2e6 overminds; overminds cost 1000 arch-minds and do not pass (H = 15 x 1000 / 0.01).
      # Holding 5e5 overminds, 150 overmind IIs, no overmind IIIs:
      #   direct: 1.5e6 overminds = 1.5e9 arch-minds.
      #   detour: twin overminds (1000 overmind IIs). Getting those: 850 more at 1000 overminds each
      #     = 8.5e5, or first twin overmind IIs (1 overmind III = 100 overmind IIs, held), then
      #     ceil(950/2) = 475 overmind IIs = 4.75e5 overminds. 5e5 overminds cover that, leaving 25000,
      #     then ceil((2e6 - 25000)/2) = 987500 overminds = 9.875e8 arch-minds < 1.5e9.
      #   A second round of twins (12000 overmind IIs, then 14 overmind IIIs) is not affordable.
      # payback 9.875e8 / 9e4 = 10972 s; x (14 + 1) = 1.65e5 < 3e5; 2e9 arch-minds >= 2 x 9.875e8.
      snap = mksnap now: 1e8, larvae: 1e6, larvaRate: 1e5, units:
        pantheon4: {count: 1e6}
        pantheon5: {count: 2e9, cost: 100, prodEach: 15, twinCost: 2e6}
        overmind: {count: 5e5, cost: 1000, prodEach: 0.01, twinCost: 1000, twinFactor: 12}
        overmind2: {count: 150, cost: 1000, twinCost: 1, twinFactor: 14}
        overmind3: {count: 0, cost: 100}
      r = advisor.advise snap, null, {}
      expect(tier(r, 'overmind').passes).toBe false
      expect(tier(r, 'pantheon5').hatching).toBe true
      tips = tipsOf r, 'twinPlan'
      expect(tips.length).toBe 1
      expect(tips[0].unit).toBe 'pantheon5'
      expect(tips[0].planCost.toNumber()).toBe 9.875e8
      expect(tips[0].steps).toEqual [
        {type: 'hatch', unit: 'overmind3', count: D(1)}
        {type: 'twin', unit: 'overmind2'}
        {type: 'hatch', unit: 'overmind2', count: D(475)}
        {type: 'twin', unit: 'overmind'}
        {type: 'hatch', unit: 'overmind', count: D(987500)}
      ]
      expect(texts r).toEqual ['hatch 1 overmind3 > twin overmind2s > hatch 475 overmind2s > twin overminds > hatch 987,500 overminds > twin pantheon5s (pays back in 3.0 h)']

    it 'exposes the planner', ->
      st = [
        {name: 'a', have: D(0), twin: D(1), cost: D(10), twinCost: null, twinFactor: D(10)}
      ]
      steps = []
      expect(advisor.acquire(st, 0, D(3), steps, 0).toNumber()).toBe 30
      expect(steps).toEqual [{type: 'hatch', unit: 'a', count: D(3)}]
      expect(st[0].have.toNumber()).toBe 3

  describe 'energy advice', ->
    mk = (nexus, energy, moths, larvaRate, next) ->
      snap = mksnap larvaRate: larvaRate
      snap.energy =
        nexus: nexus
        energy: D energy
        moths: D moths
        next: if next then {name: "nexus#{nexus + 1}", level: nexus + 1, costs: ({unit: c[0], val: D(c[1]), have: D(c[2])} for c in next)} else null
      return snap
    say = (snap, cfg={}) -> advisor.renderEnergy advisor.energyAdvice snap, cfg

    it 'says nothing without a nexus', ->
      expect(advisor.energyAdvice mk(0, 0, 0, 1, null), {}).toBe null
      expect(advisor.renderEnergy null).toBe null

    it 'buys the next nexus when everything is in hand', ->
      snap = mk 2, 3000, 0, 1, [['meat', 3.33333e18, 1e19], ['energy', 2500, 3000], ['larva', 3333333, 4e6]]
      expect(advisor.energyAdvice snap, {}).toEqual {type: 'buyNexus', level: 3}
      expect(say snap).toBe 'buy nexus 3'

    it 'saves once the meat is there and the larvae are under 20000 s away', ->
      # 33333330 <= 2000 x 20000
      snap = mk 3, 2000, 0, 2000, [['meat', 3.33333e21, 1e22], ['energy', 10000, 2000], ['larva', 33333330, 1e6]]
      rec = advisor.energyAdvice snap, {}
      expect(rec.type).toBe 'save'
      expect(_.map rec.missing, 'unit').toEqual ['energy', 'larva']
      expect(say snap).toBe 'save for nexus 4: 2,000/10,000 energy, 1.00e6/3.33e7 larva'

    it 'casts larva rush while the next nexus is far off', ->
      # larvae too far: 33333330 > 1000 x 20000
      snap = mk 3, 2000, 0, 1000, [['meat', 3.33333e21, 1e22], ['energy', 10000, 2000], ['larva', 33333330, 1e6]]
      expect(say snap).toBe 'cast larva rush x1'
      # meat missing
      snap = mk 3, 2000, 0, 2000, [['meat', 3.33333e21, 1e20], ['energy', 10000, 2000], ['larva', 33333330, 1e6]]
      expect(say snap).toBe 'cast larva rush x1'
      snap = mk 3, 1000, 0, 1000, [['meat', 3.33333e21, 1e22], ['energy', 10000, 1000], ['larva', 33333330, 1e6]]
      expect(advisor.energyAdvice(snap, {}).type).toBe 'nextCast'
      expect(say snap).toBe 'next larva rush at 1,600 energy (have 1,000)'

    describe 'at nexus 4', ->
      nexus5 = (energy, larvae) -> [['meat', 3.33333e24, 1e25], ['energy', 36000, energy], ['larva', 3333333000, larvae]]

      it 'buys lepidoptera with energy beyond the nexus reserve, then saves', ->
        # saving: 3333333000 <= 2e5 x 20000; spare 40000 - 36000 = 4000 => 400 moths
        snap = mk 4, 40000, 2416, 2e5, nexus5(40000, 3e9)
        rec = advisor.energyAdvice snap, {}
        expect(rec.type).toBe 'buyMoths'
        expect(rec.count.toNumber()).toBe 400
        expect(rec.then.type).toBe 'save'
        expect(say snap).toBe 'buy 400 lepidoptera (lepidoptera 2,416/4,000); then save for nexus 5: 3.00e9/3.33e9 larva'

      it 'saves when no energy is spare', ->
        snap = mk 4, 36005, 2416, 2e5, nexus5(36005, 3e9)
        expect(say snap).toBe 'save for nexus 5: 3.00e9/3.33e9 larva'

      it 'puts all energy into lepidoptera when not saving', ->
        snap = mk 4, 5, 2416, 1000, nexus5(5, 3e9)
        expect(advisor.energyAdvice(snap, {}).type).toBe 'mothTarget'
        expect(say snap).toBe 'all energy into lepidoptera 2,416/4,000'
        snap = mk 4, 1000, 2416, 1000, nexus5(1000, 3e9)
        expect(say snap).toBe 'buy 100 lepidoptera (lepidoptera 2,416/4,000)'

      it 'casts larva rush once the lepidoptera target is met', ->
        snap = mk 4, 3300, 4000, 1000, nexus5(3300, 3e9)
        expect(say snap).toBe 'cast larva rush x2'
        snap = mk 4, 3300, 2416, 1000, nexus5(3300, 3e9)
        expect(say snap, {moths: 0}).toBe 'cast larva rush x2'

    describe 'at nexus 5', ->
      it 'finishes the lepidoptera', ->
        expect(say mk 5, 6000, 3990, 1, null).toBe 'buy 10 lepidoptera (lepidoptera 3,990/4,000)'

      it 'then casts House of Mirrors', ->
        rec = advisor.energyAdvice mk(5, 6000, 4000, 1, null), {}
        expect(rec.type).toBe 'cast'
        expect(rec.spell).toBe 'clonearmy'
        expect(rec.casts.toNumber()).toBe 2
        expect(say mk 5, 6000, 4000, 1, null).toBe 'cast House of Mirrors x2'
        expect(say mk 5, 100, 4000, 1, null).toBe 'next House of Mirrors at 2,500 energy (have 100)'

    it 'is part of the full advice', ->
      snap = mk 5, 6000, 4000, 1, null
      expect(advisor.advise(snap, null, {}).energy.type).toBe 'cast'

  describe 'live wiring', ->
    it 'advises on the live game and remembers between updates', ->
      r = advisor.update()
      expect(r.config).toEqual advisor.DEFAULTS
      expect(_.map r.tiers, 'name').toEqual ['queen', 'nest']
      expect(r.energy).toBe null
      expect(advisor.memory()).toBe r.memory
      advisor.resetMemory()
      expect(advisor.memory()).toBe null

describe 'Service: advisor on a real save', ->

  beforeEach module 'swarmApp'

  advisor = {}
  Game = {}
  session = {}
  beforeEach inject (_advisor_, _Game_, _session_) ->
    advisor = _advisor_
    Game = _Game_
    session = _session_

  # The owner's save from 14.5 hours into a run (advisor/sim/example_save_14h.json, decoded JSON).
  # Karma serves it (included: false); see test/karma-unit.conf.coffee.
  fetchSave = ->
    files = window.__karma__?.files ? {}
    url = _.find _.keys(files), (f) -> /advisor\/sim\/example_save_14h\.json$/.test f
    if not url?
      throw new Error 'advisor/sim/example_save_14h.json is not served by karma; add it to the karma files list'
    xhr = new XMLHttpRequest()
    xhr.open 'GET', url, false
    xhr.send()
    return JSON.parse xhr.responseText

  # Load it through the game's own save codec, then stop the clock at the moment it was saved.
  loadGame = ->
    state = session._loads session._saves fetchSave(), false
    # Shift every date so the save is an hour old, whatever the test machine's clock says;
    # the game refuses to tick backwards. Run age is unchanged.
    shift = (new Date().getTime() - 3600e3) - state.date.reified.getTime()
    for key, date of state.date
      state.date[key] = new Date date.getTime() + shift
    game = new Game {state: state, save: ->}
    game.now = new Date state.date.reified.getTime()
    game.cache.onUpdate()
    return game

  it 'builds a sane snapshot', ->
    game = loadGame()
    snap = advisor.snapshot game
    # restarted 02:11:33.812, reified 16:40:17.915
    expect(snap.now - snap.restartedAt).toBe 52124103
    expect(game.achievementPoints()).toBe 690
    # larvae/s = (1 + 29 hatcheries) x 1.1^57 expansions x (1 + 0.001 x 690 points)^5 ancestry
    expected = 30 * Math.pow(1.1, 57) * Math.pow(1.69, 5)
    expect(Math.abs(snap.larvaRate.toNumber() / expected - 1)).toBeLessThan 1e-9
    expect(snap.larvaRate.toNumber()).toBeGreaterThan 94000
    expect(snap.larvae.toString()).toBe '3339890.249984757388'

    byName = _.keyBy snap.units, 'name'
    expect(_.map snap.units, 'name').toEqual advisor.CHAIN
    expect(byName.hive.count.toNumber()).toBe 175270
    expect(byName.drone.below).toBe 'meat'
    expect(byName.drone.cost).toBe null
    # cost in the tier below: 100, 1000, 1e4, ... 1e10, then 1e12 ... 1e58
    expect((u.cost.toNumber() for u in snap.units[1..])).toEqual [1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e12, 1e14, 1e16, 1e19, 1e23, 1e28, 1e34, 1e41, 1e49, 1e58]
    # units per purchase: 2^twin level
    expect((byName[n].twin.toNumber() for n in ['queen', 'nest', 'greaterqueen', 'hive', 'hivequeen'])).toEqual [64, 32, 64, 1, 1]
    # production of the tier below: tier x 2^faster level
    expect((byName[n].prodEach.toNumber() for n in ['drone', 'queen', 'nest', 'greaterqueen', 'hive', 'hivequeen'])).toEqual [512, 256, 96, 32, 20, 6]
    # twin price, in the tier above: 10^level; factor 10, or 12..20 for overminds
    expect(byName.greaterqueen.twinCost.toNumber()).toBe 1e6
    expect(byName.hive.twinCost.toNumber()).toBe 1
    expect(byName.overmind.twinFactor.toNumber()).toBe 12
    expect(byName.overmind6.twinCost).toBe null
    # faster price: 66 x 666^level
    expect(byName.hive.prodCost.toNumber()).toBe 66 * 666 * 666
    expect(byName.hive.purchases).toBe '330403'
    expect(byName.hivequeen.purchases).toBe '0'
    expect(snap.energy.nexus).toBe 4
    expect(snap.energy.moths.toNumber()).toBe 2416
    expect(snap.energy.next.level).toBe 5
    expect(({unit: c.unit, val: c.val.toNumber()} for c in snap.energy.next.costs)).toEqual [
      {unit: 'meat', val: 3.33333e24}
      {unit: 'energy', val: 36000}
      {unit: 'larva', val: 3333333000}
    ]

  it 'gives sane advice', ->
    game = loadGame()
    r = advisor.advise advisor.snapshot(game), null, {}
    expect(r.age).toBeCloseTo 52124.103, 6
    expect(r.top).toBe 'hive'
    expect(_.map r.tiers, 'name').toEqual ['queen', 'nest', 'greaterqueen', 'hive', 'hivequeen', 'empress']
    actions = {}
    for t in r.tiers
      actions[t.name] = advisor.renderAction t
    expect(actions).toEqual
      # H = 7 x 1e7/7 = 1e7 s; 1e7/3 - 52124 s
      empress: 'wait 38.0 d'
      # H = 6 x 1e6/6 = 1e6 s; 1e6/3 - 52124 = 281209 s
      hivequeen: 'wait 3.3 d'
      # H = 5 x 1e5/20 = 25000 s passes. Spare: 5.91e9 greater queens x 60/5000 / 1e5 = 709.3
      hive: 'BUY 709'
      # the rest of floor(3339890 x 0.9) = 3005901 larvae: 3005192, shown as 3.01e6
      greaterqueen: 'BUY 3.01e6 (x64 twins)'
      # greater queens make 5.91e9 x 32 nests/s, far over 3 x 85149 x 32/64
      nest: 'skip: bank larvae for greaterqueens'
      queen: 'skip: bank larvae for nests'
    expect(t.H.toNumber() for t in r.tiers).toEqual [2 * 100 / (64 * 256), 3 * 1000 / (32 * 96), 4 * 1e4 / (64 * 32), 25000, 1e6, 1e7]
    expect(_.find(r.tiers, name: 'greaterqueen').buys.toNumber()).toBe 3005192
    # hive twin plan: 1 hive queen = 1e6 hives, more than half the 175270 held => no tip
    expect(r.tips).toEqual []
    # 104.8 energy at nexus 4 with 2416 lepidoptera; nexus 5's 3.3e9 larvae are too far off to save for
    expect(advisor.renderEnergy r.energy).toBe 'buy 10 lepidoptera (lepidoptera 2,416/4,000)'
    # 30 x 1.1^57 x 1.69^5 = 94610.17 larvae/s
    expect(advisor.renderHeader r).toBe 'run 14.5 h | climb if H < 43.4 h | larvae 3.34e6 (+94,610/s)'
