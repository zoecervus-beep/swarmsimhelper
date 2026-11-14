'use strict'

# The swarmwarp route (advisor/NO-MIRRORS.md sections 11-13), the game clock on every route, and switching routes.
# Expected values are worked out by hand from the spec's rules; the comments show the arithmetic.
describe 'Service: advisor, the game clock and the swarmwarp route', ->

  beforeEach module 'swarmApp'

  advisor = asc = terr = null
  beforeEach inject (_advisor_, _advisorAscension_, _advisorTerritory_) ->
    advisor = _advisor_
    asc = _advisorAscension_
    terr = _advisorTerritory_

  D = (x) -> new Decimal x
  DAY = 86400
  WARP = {ascension: 'swarmwarp'}
  MIRRORS = {ascension: 'achievements'}
  OFF = {ascension: 'off'}

  # A hand-built meat snapshot, as in advisorlongrun.coffee's spec (count 0, cost 100 of the tier below, production
  # = tier number, twin 1, upgrades out of reach), plus the clocks: wall `age` (s), `skipped` (s, this run, on top of
  # a cumulative 1e9 s skipped before this run) and the route facts.
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
      twinCost: D(1e30)
      twinFactor: D(10)
      prodCost: D(1e30)
      prodLevel: 0
      prodFactor: D(666)
      meatCost: null
      purchases: String(u.purchases ? 0)
    now = (opts.age ? 3600) * 1000
    skipped = (opts.skipped ? 0) * 1000
    return {
      now: now
      gameNow: now + 1e12 + skipped
      runSkipped: skipped
      restartedAt: 0
      larvae: D(opts.larvae ? 1e6)
      larvaRate: D(opts.larvaRate ? 0)
      meat: D(1e100)
      units: units
      energy: opts.energy ? {nexus: 0, energy: D(0), moths: D(0), next: null}
      route: opts.route ? null
    }
  # nexus 5 energy, with the swarmwarp route's bats and warp from the game's numbers
  energy5 = (energy, moths, bats) ->
    {nexus: 5, energy: D(energy), rate: D(1), cap: D(1e5), moths: D(moths), next: null, bats: D(bats), batPrice: D(100),
    warp: {cost: D(2000), skip: 2405156.4, power: 2672.4, casts: 0}}
  row = (r, name) -> _.find r.tiers, name: name

  # queens (H = 2 x 100 / 2 = 100 s) on 1e9 drones, hatched 30 s ago on the game clock
  queenSnap = (o={}) -> mksnap _.extend({larvae: 1e9, units: {drone: {count: 1e9}, queen: {count: 10, purchases: 5}}}, o)
  queenMemory = (snap) ->
    mem = advisor.createMemory snap.gameNow, snap.restartedAt
    mem.seen.queen = '5'
    mem.boughtAt.queen = snap.gameNow - 30000
    return mem

  describe 'the game clock (all routes, NO-MIRRORS.md 12.1)', ->
    it 'a swarmwarp releases the 60 s cooldown and the whole purchase share on every route', ->
      for cfg in [OFF, MIRRORS, WARP]
        before = queenSnap()
        r1 = advisor.advise before, queenMemory(before), cfg
        expect(row(r1, 'queen').reason).toBe 'cooldown'
        expect(advisor.renderAction row(r1, 'queen')).toBe 'done, next in 30 s'
        # one warp of 900 s: the wall clock moves 1 s, the game clock 901 s
        after = queenSnap age: 3601, skipped: 900, units: {drone: {count: 1e9}, queen: {count: 10, purchases: 5}}
        r2 = advisor.advise after, r1.memory, cfg
        q = row r2, 'queen'
        expect(q.reason).toBe 'buy'
        expect(q.since).toBeCloseTo 931, 6
        # share released: 1 - 0.5^(931 / 60), spare: the 1e9 drones were the stock at the last look, all released
        # (931 s >= payback 50 s): 1e9 / 100 = 1e7
        expect(q.buys.toNumber()).toBe Math.floor(1e7 * (1 - Math.pow(0.5, 931 / 60)))

    it 'without a warp the two clocks differ by a constant and the advice is the wall clock\'s', ->
      for cfg in [OFF, MIRRORS, WARP]
        s1 = queenSnap()
        mem = queenMemory s1
        r1 = advisor.advise s1, mem, cfg
        # the same state read without the game clock (a snapshot that has none): the memory on the wall clock
        wall = _.omit s1, 'gameNow', 'runSkipped'
        mw = advisor.createMemory wall.now, 0
        mw.seen.queen = '5'
        mw.boughtAt.queen = wall.now - 30000
        r2 = advisor.advise wall, mw, cfg
        expect((advisor.renderAction t for t in r2.tiers)).toEqual (advisor.renderAction t for t in r1.tiers)
        expect(r2.age).toBe r1.age
        expect(r2.horizon).toBe r1.horizon

    it 'ages the run by its swarmwarps: the horizon and the long-run gate (2 days) on the game clock', ->
      cfg = {longRun: 'on', ageMultiple: 5}
      r = advisor.advise mksnap(age: DAY), null, cfg
      expect(r.longRun.active).toBe false
      expect(r.horizon).toBe 5 * DAY
      # 1 wall day + 1 day skipped: the gate opens
      r = advisor.advise mksnap(age: DAY, skipped: DAY), null, cfg
      expect(r.age).toBe 2 * DAY
      expect(r.wallAge).toBe DAY
      expect(r.horizon).toBe 10 * DAY
      expect(r.longRun.active).toBe true
      # one second short of it
      expect(advisor.advise(mksnap(age: DAY, skipped: DAY - 1), null, cfg).longRun.active).toBe false

    it 'keeps the mirrors route\'s day-3 lepidoptera raise (LR-4) on the wall clock', ->
      cfg = {longRun: 'on', ascension: 'off'}
      r = advisor.advise mksnap(age: DAY, skipped: 5 * DAY, energy: energy5(50000, 4000, 0)), null, cfg
      expect(r.longRun.mothsRaised).toBe false
      expect(r.energy.type).toBe 'cast'
      r = advisor.advise mksnap(age: 3 * DAY, energy: energy5(50000, 4000, 0)), null, cfg
      expect(r.longRun.mothsRaised).toBe true

    it 'works every service\'s advice out afresh at once after a swarmwarp (the skipped time changes)', inject (game) ->
      a = (svc.current(1000, 5000) for svc in [advisor, terr, asc])
      b = (svc.current(1000, 5001) for svc in [advisor, terr, asc])
      expect(b[i]).toBe a[i] for i in [0...3]
      # what a cast does to the clock (game.coffee skipMillis); the cast itself: 'reads the game clock' below
      game.session.state.skippedMillis += 900000
      b = (svc.current(1000, 5002) for svc in [advisor, terr, asc])
      expect(b[i]).not.toBe a[i] for i in [0...3]
      expect(b[0].error).toBe null

    it 'works every service\'s advice out afresh at once after a setting changes', inject (options) ->
      a = (svc.current(1000, 5000) for svc in [advisor, terr, asc])
      options.advisorSetting 'ascension', 'swarmwarp'
      b = (svc.current(1000, 5001) for svc in [advisor, terr, asc])
      expect(b[i]).not.toBe a[i] for i in [0...3]
      expect(b[0].advice.route.route).toBe 'swarmwarp'
      expect(b[2].advice.route.route).toBe 'swarmwarp'
      # the stored settings are not changed by the route
      expect(options.advisorConfig().longRun).toBe 'off'
      expect(b[0].advice.config.longRun).toBe 'on'

  describe 'the route setting', ->
    it 'is the ascension setting, the House of Mirrors route by default; the swarmwarp route is a choice', inject (options) ->
      expect(advisor.DEFAULTS.ascension).toBe 'achievements'
      expect(options.advisorConfig().ascension).toBe 'achievements'
      options.advisorSetting 'ascension', 'swarmwarp'
      expect(options.advisorConfig().ascension).toBe 'swarmwarp'
      expect(-> options.advisorSetting 'ascension', 'mirrors').toThrow()

    it 'a saved setting of the achievements route keeps the House of Mirrors route', ->
      cfg = {ascension: 'achievements', ageMultiple: 5, spareEnergy: 'save', longRun: 'off'}
      expect(advisor.routeOf(cfg, null).route).toBe 'mirrors'
      r = advisor.advise mksnap(energy: energy5(50000, 10000, 0)), null, cfg
      expect(r.config.longRun).toBe 'off'
      expect(advisor.renderEnergy r.energy).toBe 'cast House of Mirrors x20'

    it 'the swarmwarp route switches the long-run climb on, without storing it', ->
      r = advisor.advise mksnap(age: 3 * DAY), null, {ascension: 'swarmwarp', longRun: 'off'}
      expect(r.config.longRun).toBe 'on'
      expect(r.longRun.active).toBe true
      # and no LR-4 raise: the route's own lepidoptera target (E2)
      expect(r.longRun.mothsRaised).toBe false

  describe 'energy on the swarmwarp route (12.2, 12.3)', ->
    it 'below nexus 5: the A.11 plan, unchanged', ->
      e4 = {nexus: 4, energy: D(20000), rate: D(1), cap: D(48500), moths: D(500), bats: D(0), batPrice: D(100), warp: {cost: D(2000), skip: 900}, next:
        {name: 'nexus5', level: 5, costs: [{unit: 'meat', val: D(1e24), have: D(1e20)}, {unit: 'energy', val: D(36000), have: D(20000)}, {unit: 'larva', val: D(3.33e9), have: D(1)}]}}
      w = advisor.advise mksnap(energy: e4), null, WARP
      m = advisor.advise mksnap(energy: e4), null, {runMoths: 10000, runStage: 'firstRun'}
      expect(w.energy).toEqual m.energy
      expect(w.energy.type).toBe 'buyMoths'
      expect(w.energy.early).toBe true

    it 'E2: 10,000 lepidoptera every run; a higher setting stays', ->
      r = advisor.advise mksnap(energy: energy5(50000, 4000, 0)), null, WARP
      expect(r.energy.type).toBe 'buyMoths'
      expect(r.energy.count.toNumber()).toBe 5000 # min(10,000 - 4,000, 50,000 / 10)
      expect(r.energy.target).toBe 10000
      expect(advisor.renderEnergy r.energy).toBe 'buy 5,000 lepidoptera (lepidoptera 4,000/10,000, swarmwarp route)'
      r = advisor.advise mksnap(energy: energy5(50000, 12000, 0)), null, _.extend({moths: 20000}, WARP)
      expect(r.energy.target).toBe 20000
      expect(r.energy.runStage).toBeUndefined()

    it 'E3: then 2,000 bats, floor(min(2,000 - bats, spare / 100)), before any swarmwarp', ->
      r = advisor.advise mksnap(energy: energy5(50000, 10000, 0)), null, WARP
      expect(r.energy.type).toBe 'buyBats'
      expect(r.energy.count.toNumber()).toBe 500 # 50,000 / 100
      r = advisor.advise mksnap(energy: energy5(50000, 10000, 1999)), null, WARP
      expect(r.energy.count.toNumber()).toBe 1
      expect(advisor.renderEnergy r.energy).toBe 'buy 1 bats (1,999/2,000, before the first swarmwarp: they raise its power)'
      r = advisor.advise mksnap(energy: energy5(99, 10000, 0)), null, WARP
      expect(r.energy.type).toBe 'batTarget'

    it 'E4: then swarmwarp, one cast at a time, with how many are affordable and what one skips', ->
      r = advisor.advise mksnap(energy: energy5(10700, 10000, 2000)), null, WARP
      expect(r.energy.type).toBe 'warp'
      expect(r.energy.casts.toNumber()).toBe 1
      expect(r.energy.affordable.toNumber()).toBe 5
      expect(advisor.renderEnergy r.energy).toBe 'cast 1 swarmwarp (5 affordable): skips 27.8 d; then follow the other lines: the next swarmwarp is suggested after them'
      # never 'cast xN', however much energy
      r = advisor.advise mksnap(energy: energy5(1e5, 10000, 2000)), null, WARP
      expect(r.energy.casts.toNumber()).toBe 1
      expect(advisor.renderEnergy r.energy).not.toMatch /x\d/
      r = advisor.advise mksnap(energy: energy5(1999, 10000, 2000)), null, WARP
      expect(advisor.renderEnergy r.energy).toBe 'next swarmwarp at 2,000 energy (have 1,999)'
      # the House of Mirrors route on the same state
      r = advisor.advise mksnap(energy: energy5(10700, 10000, 2000)), null, MIRRORS
      expect(advisor.renderEnergy r.energy).toBe 'cast House of Mirrors x4'

    it 'waits with the next warp while the climb, the tips or territory have purchases open', ->
      warp = advisor.advise(mksnap(energy: energy5(10700, 10000, 2000)), null, WARP).energy
      # the queen bought, in cooldown: nothing open, the warp is offered
      s = queenSnap()
      cool = advisor.advise s, queenMemory(s), WARP
      expect(advisor.orderWarp warp, cool, null).toBe warp
      # released by the warp: a climb row to buy first
      after = queenSnap age: 3601, skipped: 900
      open = advisor.advise after, cool.memory, WARP
      held = advisor.orderWarp warp, open, null
      expect(held.type).toBe 'warpAfter'
      expect(held.pending).toEqual {climb: 1, tips: 0, territory: 0}
      expect(advisor.renderEnergy held).toBe 'next: cast 1 swarmwarp (5 affordable): skips 27.8 d, once the purchases on the other lines are made (1 climb row)'
      # tips: faster and twin hold it, a twin plan does not
      tips = (types) -> _.extend {}, cool, tips: ({type: t} for t in types)
      expect(advisor.orderWarp(warp, tips(['twinPlan']), null)).toBe warp
      expect(advisor.orderWarp(warp, tips(['faster', 'twin']), null).pending.tips).toBe 2
      # territory: an expansion / hatchery / ancestry level, an empower, a twin; units only past 60 s of the share
      t = (records, hatch=[]) -> {share: 0.1, records: records, hatch: hatch}
      cool.larvaRate = D(1000) # 0.1 x 1,000 x 60 = 6,000 larvae
      expect(advisor.orderWarp(warp, cool, t([{type: 'upgrade'}, {type: 'empower'}, {type: 'twin'}])).pending.territory).toBe 3
      expect(advisor.orderWarp(warp, cool, t([{type: 'hatch'}], [{buys: D(6000)}]))).toBe warp
      expect(advisor.orderWarp(warp, cool, t([{type: 'hatch'}], [{buys: D(6001)}])).pending.territory).toBe 1
      expect(advisor.orderWarp(warp, cool, t([{type: 'idle'}, {type: 'saveForTwin'}]))).toBe warp
      # other records pass through
      other = {type: 'cast', casts: D(4)}
      expect(advisor.orderWarp other, open, null).toBe other

  describe 'territory on the swarmwarp route (12.4, 13 G5)', ->
    tsnap = (o={}) ->
      unit = (name, j) ->
        name: name, label: name + 's', label1: name, tier: j, visible: j < 2, count: D(0), purchases: '0', twin: D(1)
        meat: D(Math.pow(10, j + 1)), prodEach: D(1)
        twinUpgrade: {name: name + 'twin', label: 'twin ' + name, level: 0, visible: false, larvae: D(1e30), meat: D(1e30), larvaFactor: D(10), meatFactor: D(10)}
        empower: {name: name + 'empower', label: 'empower ' + name, level: 0, visible: false, meat: D(1e30), meatFactor: D(450), becomes: name + 's II'}
      now: 1000e3
      gameNow: 1000e3
      route: o.route ? {ascensions: 1, mirrorCasts: o.mirrorCasts ? 0, warpCasts: 0, expansions: o.expansions ? 100, expansionGoal: {val: 5000, earned: false}}
      restartedAt: 0
      larvae: D(1000)
      larvaRate: D(10)
      meat: D(1e6)
      territory: D(0)
      mirrorCasts: o.mirrorCasts ? 0
      units: (unit(n, j) for n, j in terr.UNITS)
      upgrades: []

    it 'never stops, even with House of Mirrors cast this run (a route switch)', ->
      m = terr.advise tsnap(mirrorCasts: 20), null, MIRRORS
      expect(m.mirrors).toBe true
      expect((terr.render x for x in m.records)).toEqual ['set the territory share to 0 (now 0.1)', 'House of Mirrors is running: hatch no more territory units']
      w = terr.advise tsnap(mirrorCasts: 20), null, WARP
      expect(w.mirrors).toBe false
      expect(w.hatch.length).toBeGreaterThan 0

    it 'advises a share of 0 back to 0.1', ->
      w = terr.advise tsnap(mirrorCasts: 20), null, _.extend({territory: 0}, WARP)
      expect((terr.render x for x in w.records)).toEqual ['set the territory share to 0.1 (now 0): on the swarmwarp route expansions come from territory units', 'territory share is 0: no territory units']
      m = terr.advise tsnap(), null, _.extend({territory: 0}, MIRRORS)
      expect(m.setting).toBe null

    it 'a run finished with House of Mirrors (the near-complete guard) stops territory as the mirrors route does', ->
      w = terr.advise tsnap(mirrorCasts: 20, expansions: 4500), null, WARP
      expect(w.route.guard?).toBe true
      expect(w.mirrors).toBe true

  describe 'ascension and mutagen on the swarmwarp route (12.6, 12.7)', ->
    UNLOCKS = ['mutatehatchery', 'mutatebat', 'mutateclone', 'mutateswarmwarp', 'mutaterush', 'mutateeach',
      'mutatefreq', 'mutatenexus', 'mutatearmy', 'mutatemeat']
    goalList = (pairs, earned) -> ({name: n, label: n, val: D(v), earned: !!earned[n]} for [n, v] in pairs)
    # A hand-built ascension snapshot: `unlocked` names, `mutants` {unit: count}, mutagen held, premutagen.
    amk = (o={}) ->
      earned = {}
      earned[n] = true for n in o.earned ? []
      unlocked = o.unlocked ? []
      mutants = o.mutants ? {}
      n = unlocked.length
      paid = 0
      paid += Math.pow(15625, i) for i in [0...n]
      have = 0
      have += v for k, v of mutants
      expansion = o.expansion ? 100
      ascensions = o.ascensions ? 5
      return {
        now: 1000e3, restartedAt: 0
        ascensions: ascensions
        energy: D(o.energy ? 1000), cap: D(1e5), rate: D(1), spent: D(0), cost: D(o.cost ? 1e6), halving: 79940, nexus: 5
        premutagen: D(o.premutagen ? 0)
        mutagen: D(o.mutagen ? 0)
        unlocks: for name in UNLOCKS
          name: name
          label: name.replace 'mutate', 'mutate '
          unit: name.replace 'mutate', 'mutant'
          unlocked: name in unlocked
          price: D(Math.pow 15625, n)
          factor: D(15625)
          have: D(mutants[name.replace 'mutate', 'mutant'] ? 0)
          mutantPrice: D(1)
        unlockCount: n
        freeRespecs: o.freeRespecs ? 4
        refund: D(paid + have - n) # the game's respecSpent: unlock prices paid + mutants - the free one per unlock
        mirrorCasts: o.mirrorCasts ? 0
        route: {ascensions: ascensions, mirrorCasts: o.mirrorCasts ? 0, warpCasts: 0, expansions: expansion, expansionGoal: {val: 5000, earned: !!earned.expansion9}}
        nexusMutants: D(mutants.mutantnexus ? 0), nexusMutantPrice: D(1)
        expansion: expansion
        top: 'pantheon'
        endlessBought: D(0)
        goals:
          expansion: goalList [['expansion7', 1000], ['expansion8', 2000], ['expansion9', 5000]], earned
          endless: goalList [['overmind6_1', 1], ['overmind6_3', 1e62]], earned
          ascension: goalList [['ascension1', 1], ['ascension3', 20]], earned
          mutation: goalList [['mutation3', 6], ['mutation4', 10]], earned
      }
    LONG = ['expansion9', 'overmind6_3', 'mutation4']
    texts = (r) -> (asc.render x for x in r.records)
    ALL = ['mutatenexus', 'mutateswarmwarp', 'mutatebat', 'mutatefreq', 'mutateeach', 'mutatearmy', 'mutaterush', 'mutateclone', 'mutatemeat', 'mutatehatchery']

    it 'build: ascend once premutagen >= 1,000 x mutagen held, either side of the ratio', ->
      held = 2.1627779080285675e32
      r = asc.advise amk(mutagen: held, premutagen: held * 1000 * 0.999999), WARP
      expect(r.stage).toBe 'build'
      expect(r.plan).toBe null
      expect(r.test.need.toNumber()).toBe held * 1000
      expect(_.last texts r).toMatch /^keep swarmwarping, do not ascend yet: mutagen \(inactive\) 2.16e35\/2.16e35 \(1,000 x mutagen held\)/
      r = asc.advise amk(mutagen: held, premutagen: held * 1000 * 1.000001), WARP
      expect(r.plan.type).toBe 'spendForAscension'
      expect(r.plan.route).toBe 'swarmwarp'
      expect(_.last texts r).toContain '(lepidoptera, bats and swarmwarp)'

    it 'build in a first run: any 1,000 premutagen (nothing held)', ->
      expect(asc.advise(amk(ascensions: 0, premutagen: 999), WARP).plan).toBe null
      r = asc.advise amk(ascensions: 0, premutagen: 1000), WARP
      expect(r.stage).toBe 'build'
      expect(r.plan.type).toBe 'spendForAscension'
      expect(r.test.need.toNumber()).toBe 1000

    it 'final counts the share mutants with the mutagen held, so following the mutagen line keeps the stage (12.6 departure)', ->
      for held in ['1.5e270', '2.5e270']
        s = amk mutagen: D(held), premutagen: D('1e300'), unlocked: ALL, mutants: {mutantnexus: 1e6, mutantfreq: 1e6}
        r = asc.advise s, WARP
        expect([held, r.stage]).toEqual [held, 'final']
        # follow the line
        for st in r.mutagen.steps
          u = _.find s.unlocks, unit: st.unit
          u.have = u.have.plus st.count
          s.mutagen = s.mutagen.minus st.count
        expect(s.mutagen.lessThan D('1e270')).toBe held == '1.5e270' # unspent alone would fall below
        expect([held, asc.advise(s, WARP).stage]).toEqual [held, 'final']
      # held under 1e270 but share mutants that bring it over: final (warp_route.py says build here)
      s = amk mutagen: D('0.9e270'), unlocked: ALL, mutants: {mutantarmy: 2e269}
      s.unlocks = (_.extend({}, u, (if u.unit == 'mutantarmy' then {have: D('2e269')} else {})) for u in s.unlocks)
      expect(asc.warpWealth(s).toExponential(1)).toBe '1.1e+270'
      expect(asc.advise(s, WARP).stage).toBe 'final'

    it 'final from 1e270 mutagen held while 5,000 expansions are missing, never ascending', ->
      r = asc.advise amk(mutagen: D('1e270').times(1.000001), premutagen: D('1e300'), unlocked: ALL), WARP
      expect(r.stage).toBe 'final'
      expect(r.plan).toBe null
      expect(_.last texts r).toMatch /^final run, do not ascend: expansions 100\/5,000; all spare energy into swarmwarp/
      r = asc.advise amk(mutagen: D('1e270').times(0.999999), premutagen: D('1e300'), unlocked: ALL), WARP
      expect(r.stage).toBe 'build'
      expect(r.plan).not.toBe null

    it 'quick, then done, once the long-build achievements are earned', ->
      r = asc.advise amk(earned: LONG, ascensions: 15, energy: 2e6, mutagen: 1e10, unlocked: ALL), WARP
      expect(r.stage).toBe 'quick'
      expect(r.plan.type).toBe 'ascendNow'
      expect(texts(r)[1]).toMatch /^ascend now: .* ascension 16 of 20$/
      r = asc.advise amk(earned: LONG, ascensions: 20, energy: 2e6, mutagen: 1e10, unlocked: ALL), WARP
      expect(r.stage).toBe 'done'
      expect(r.plan).toBe null
      expect(_.last texts r).toBe 'every achievement of the swarmwarp route earned: no further ascension needed'

    it 'asks for 10,000 lepidoptera for the run', ->
      expect(asc.advise(amk(), WARP).moths).toEqual {moths: 10000, stage: 'swarmwarp'}

    it 'unlocks lepidoptera and warp first, whenever affordable', ->
      r = asc.advise amk(mutagen: 15626), WARP
      expect(([s.type, s.name ? s.unit, s.price?.toNumber() ? s.count.toNumber()] for s in r.mutagen.steps)).toEqual [
        ['unlock', 'mutatenexus', 1], ['unlock', 'mutateswarmwarp', 15625]]
      expect(r.mutagen.keep.toNumber()).toBe 0

    it 'buys the 4th unlock only while it costs at most 30% of the mutagen held', ->
      price = Math.pow 15625, 3 # 3.81e12
      base = {unlocked: ['mutatenexus', 'mutateswarmwarp', 'mutatebat'], mutants: {mutantnexus: 1e6, mutantswarmwarp: 1, mutantbat: 1}}
      above = asc.advise amk(_.extend {mutagen: price / 0.3 * 1.000001}, base), WARP
      expect(above.mutagen.steps[0]).toEqual jasmine.objectContaining {type: 'unlock', name: 'mutatefreq'}
      below = asc.advise amk(_.extend {mutagen: price / 0.3 * 0.999999}, base), WARP
      expect(_.some below.mutagen.steps, type: 'unlock').toBe false
      # the third is free of the rule: 2 held, 2.44e8 against 3e8 (81%)
      r = asc.advise amk(mutagen: 3e8, unlocked: ['mutatenexus', 'mutateswarmwarp'], mutants: {mutantnexus: 1e6, mutantswarmwarp: 1}), WARP
      expect(r.mutagen.steps[0]).toEqual jasmine.objectContaining {type: 'unlock', name: 'mutatebat'}

    it 'advises a free respec after the mirrors route\'s purchases, then lepidoptera and warp (13 G3)', ->
      o = {mutagen: 64300788, unlocked: ['mutatenexus', 'mutatefreq'], mutants: {mutantnexus: 1e6, mutantfreq: 1}}
      r = asc.advise amk(o), WARP
      # refund: 1 + 15,625 + 1,000,001 - 2 = 1,015,625
      expect(r.mutagen.respec).toBe true
      expect(r.mutagen.steps[0]).toEqual {type: 'respec', free: 4, refund: D(1015625)}
      # then 65,316,413: unlock lepidoptera (1) and warp (15,625); 999,999 lepidoptera; warp to 10% of
      # W = 64,300,788 + 1 (the warp unlock's own mutant): 6,430,078.9 - 1 => 6,430,077
      expect(([s.type, s.name ? s.unit, (s.price ? s.count).toNumber()] for s in r.mutagen.steps[1..])).toEqual [
        ['unlock', 'mutatenexus', 1], ['unlock', 'mutateswarmwarp', 15625], ['mutants', 'mutantnexus', 999999], ['mutants', 'mutantswarmwarp', 6430077]]
      expect(texts(r)[0]).toMatch /^respec \(free, 4 left\): the swarmwarp route needs the warp mutation/
      # no free respec left: no respec; warp waits (frequency to 1e6 meanwhile)
      r = asc.advise amk(_.extend {freeRespecs: 0}, o), WARP
      expect(r.mutagen.respec).toBe false
      expect(_.some r.mutagen.steps, type: 'unlock').toBe false
      # warp affordable as the next unlock: no respec
      r = asc.advise amk(_.extend {}, o, mutagen: 2.5e8), WARP
      expect(r.mutagen.respec).toBe false
      expect(r.mutagen.steps[0]).toEqual jasmine.objectContaining {type: 'unlock', name: 'mutateswarmwarp'}

    it 'holds 10% / 10% / 30% / 1% of W in warp, bat, territory and meta-mutation; idempotent', ->
      o = {mutagen: 1e20, unlocked: ALL, mutants: {mutantnexus: 1e6, mutantfreq: 1e6, mutantswarmwarp: 1, mutantbat: 1, mutantarmy: 1, mutanteach: 1}}
      r = asc.advise amk(o), WARP
      W = 1e20 + 4
      expect(([s.unit, s.count.toNumber()] for s in r.mutagen.steps)).toEqual [
        ['mutantswarmwarp', Math.floor(W * 0.1 - 1)], ['mutantbat', Math.floor(W * 0.1 - 1)], ['mutantarmy', Math.floor(W * 0.3 - 1)], ['mutanteach', Math.floor(W * 0.01 - 1)]]
      # applied, the rule asks nothing more
      s = amk(o)
      for st in r.mutagen.steps
        u = _.find s.unlocks, unit: st.unit
        u.have = u.have.plus st.count
        s.mutagen = s.mutagen.minus st.count
      expect(asc.warpMutagen s).toBe null

    it 'counts a share short by rounding (under 1e-9 of it) as held', ->
      W = D('1e270')
      o = {mutagen: W.times(0.49), unlocked: ALL}
      s = amk o
      for [mu, sh] in [['mutantswarmwarp', 0.1], ['mutantbat', 0.1], ['mutantarmy', 0.3], ['mutanteach', 0.01]]
        _.find(s.unlocks, unit: mu).have = W.times(sh).times(1 - 1e-12)
      _.find(s.unlocks, unit: 'mutantnexus').have = D(1e6)
      _.find(s.unlocks, unit: 'mutantfreq').have = D(1e6)
      expect(asc.warpMutagen s).toBe null

    it 'says what an ascension out of a House of Mirrors run with 1,000+ expansions restarts (13 G1)', ->
      held = 6.4e7
      r = asc.advise amk(ascensions: 1, mutagen: held, premutagen: 2e25, mirrorCasts: 1879, expansion: 3118, energy: 2e6), WARP
      expect(r.plan.type).toBe 'ascendNow'
      expect(r.plan.restarts).toEqual {expansions: 3118, mirrorCasts: 1879}
      expect(_.last texts r).toContain '; this run has 3,118 expansions from House of Mirrors: ascending restarts them. The swarmwarp route still expects ascending to be faster'
      expect(asc.advise(amk(ascensions: 1, mutagen: held, premutagen: 2e25, mirrorCasts: 1879, expansion: 999, energy: 2e6), WARP).plan.restarts).toBeUndefined()
      expect(asc.advise(amk(ascensions: 1, mutagen: held, premutagen: 2e25, mirrorCasts: 0, expansion: 3118, energy: 2e6), WARP).plan.restarts).toBeUndefined()

    describe 'the near-complete guard', ->
      near = (o={}) -> amk _.extend({ascensions: 1, mutagen: 6.4e7, premutagen: 1e40, mirrorCasts: 3000, expansion: 4695, energy: 2e6, unlocked: ['mutatenexus', 'mutateswarmwarp'], mutants: {mutantnexus: 1e6, mutantswarmwarp: 8e6}}, o)
      it 'finishes a mirrors run at 4,500+ expansions as the mirrors route\'s long run, with a line saying why', ->
        expect(advisor.SW.nearComplete).toBe 4500
        r = asc.advise near(), WARP
        expect(r.route.route).toBe 'mirrors'
        expect(r.stage).toBe 'longRun'
        expect(r.plan).toBe null
        expect(r.hold).toBe null
        expect(texts r).toEqual ['4,695 of 5,000 expansions: finish this run with House of Mirrors, then the swarmwarp route resumes',
          'long run: do not ascend yet; expansions 4,695/5,000; endless bought 0/1 (top tier pantheon)']
        # the mirrors route's long-run lepidoptera
        expect(r.moths).toBe null # before day 3 of the run
        r = asc.advise near(expansion: 4500), WARP
        expect(r.stage).toBe 'longRun'

      it 'does not fire below 4,500, without mirror casts, in a first run (13 G2), or with 5,000 earned', ->
        expect(asc.advise(near(expansion: 4499), WARP).stage).toBe 'build'
        expect(asc.advise(near(mirrorCasts: 0), WARP).stage).toBe 'build'
        expect(asc.advise(near(ascensions: 0, mutagen: 0), WARP).stage).toBe 'build'
        expect(asc.advise(near(earned: ['expansion9']), WARP).stage).toBe 'build'

      it 'shows the swarmwarp route\'s mutagen line without a respec or shares: nothing at the mirrors run\'s expense', ->
        # (before the review fix this advised the respec, dropping the frequency mutation for the rest of the run)
        r = asc.advise near(unlocked: ['mutatenexus', 'mutatefreq'], mutants: {mutantnexus: 1e6, mutantfreq: 1}), WARP
        expect(r.mutagen.route).toBe 'swarmwarp'
        expect(r.mutagen.respec).toBe false
        # frequency to 1e6 (both routes use it); no warp, bat, territory or meta-mutation shares
        expect(([st.type, st.unit] for st in r.mutagen.steps)).toEqual [['mutants', 'mutantfreq']]
        r = asc.advise near(mutagen: 1e20, unlocked: ['mutatenexus', 'mutateswarmwarp', 'mutatebat', 'mutatefreq'], mutants: {mutantnexus: 1e6, mutantfreq: 1e6, mutantswarmwarp: 1, mutantbat: 1}), WARP
        expect(_.some r.mutagen.steps, kind: 'share').toBe false

    it 'advises no free respec while the route wants this run ended (the ascension pays for the warp unlock)', ->
      o = {ascensions: 1, mutagen: 64300788, unlocked: ['mutatenexus', 'mutatefreq'], mutants: {mutantnexus: 1e6, mutantfreq: 1}}
      # premutagen far below 1,000 x held: the G3 respec
      expect(asc.advise(amk(_.extend {premutagen: 1e6}, o), WARP).mutagen.respec).toBe true
      # the test passes (spend, save or ascend now): none
      for extra in [{premutagen: 6.5e10, energy: 10}, {premutagen: 6.5e10, cost: 50000, energy: 30000}, {premutagen: 6.5e10, energy: 2e6}]
        r = asc.advise amk(_.extend {}, o, extra), WARP
        expect(r.plan).not.toBe null
        expect(r.mutagen.respec).toBe false
        expect(_.some r.mutagen.steps, type: 'respec').toBe false

    it 'saves for the ascension: no warps, no bats (E5)', ->
      held = 2e32
      a = asc.advise amk(mutagen: held, premutagen: held * 2000, cost: 50000, energy: 30000), WARP
      expect(a.plan.type).toBe 'saveForAscension'
      for e in [energy5(30000, 10000, 2000), energy5(30000, 10000, 0)]
        rec = advisor.advise(mksnap(energy: e), null, WARP).energy
        held2 = asc.coupleEnergy rec, a
        expect(held2.type).toBe 'ascensionHold'
        expect(advisor.orderWarp held2, null, null).toBe held2
      # before saving: the warp line says how many are left before saving starts
      a = asc.advise amk(mutagen: held, premutagen: held * 2000, cost: 140000, energy: 30000), WARP
      expect(a.plan.type).toBe 'spendForAscension'
      rec = asc.coupleEnergy advisor.advise(mksnap(energy: energy5(30000, 10000, 2000)), null, WARP).energy, a
      # spend 79,940 x log2(140,000 / 100,000) = 38,805 more: 20 warps; 15 affordable stays 15
      expect(rec.affordable.toNumber()).toBe 15
      a = asc.advise amk(mutagen: held, premutagen: held * 2000, cost: 104000, energy: 30000), WARP
      rec = asc.coupleEnergy advisor.advise(mksnap(energy: energy5(30000, 10000, 2000)), null, WARP).energy, a
      # 79,940 x log2(1.04) = 4,524 => 3 warps, then save
      expect(rec.affordable.toNumber()).toBe 3
      expect(advisor.renderEnergy rec).toMatch /^cast 1 swarmwarp \(3 affordable before saving for the ascension\)/

# ---------------------------------------------------------------------------------------------------------------
# Switching routes (NO-MIRRORS.md section 13) on the reference cases' states, loaded into the game.
describe 'Service: advisor, switching routes on real states', ->

  beforeEach module 'swarmApp'

  advisor = asc = terr = Game = session = null
  beforeEach inject (_advisor_, _advisorAscension_, _advisorTerritory_, _Game_, _session_) ->
    advisor = _advisor_
    asc = _advisorAscension_
    terr = _advisorTerritory_
    Game = _Game_
    session = _session_

  # the owner's stored settings, with each route
  M = {ascension: 'achievements', ageMultiple: 5, spareEnergy: 'save', longRun: 'off'}
  W = _.extend {}, M, ascension: 'swarmwarp'

  fetchCase = (name) ->
    files = window.__karma__?.files ? {}
    re = new RegExp 'swarmwarp_cases/' + name + '\\.save\\.json$'
    url = _.find _.keys(files), (f) -> re.test f
    if not url?
      throw new Error 'swarmwarp_cases/' + name + '.save.json is not served by karma'
    xhr = new XMLHttpRequest()
    xhr.open 'GET', url, false
    xhr.send()
    return JSON.parse xhr.responseText
  # As advisorascension.coffee's spec: the save's dates moved so that it was saved an hour ago.
  load = (name, edit) ->
    json = fetchCase name
    edit? json
    state = session._loads session._saves json, false
    shift = (new Date().getTime() - 3600e3) - state.date.reified.getTime()
    for key, date of state.date
      state.date[key] = new Date date.getTime() + shift
    game = new Game {state: state, save: ->}
    game.now = new Date state.date.reified.getTime()
    game.cache.onUpdate()
    return game

  # Every line of the panel for one route, from the game and the memories given (as the live services chain them).
  adviseAll = (game, cfg, mem={}) ->
    a = asc.advise asc.snapshot(game), cfg
    meatCfg = if a.moths? then _.extend({}, cfg, runMoths: a.moths.moths, runStage: a.moths.stage) else cfg
    r = advisor.advise advisor.snapshot(game), mem.meat, meatCfg
    t = terr.advise terr.snapshot(game), mem.terr, cfg
    energy = advisor.orderWarp asc.coupleEnergy(r.energy, a), r, t
    texts =
      header: advisor.renderHeader r
      tiers: (t2.name + ': ' + advisor.renderAction(t2) for t2 in r.tiers)
      tips: (advisor.renderTip x for x in r.tips)
      energy: advisor.renderEnergy energy
      territory: (terr.render x for x in t.records)
      ascension: (asc.render x for x in a.records)
    return {a: a, r: r, t: t, energy: energy, texts: texts, mem: {meat: r.memory, terr: t.memory}}

  # A -> B -> A on the same state, memories carried as the live services would: A's advice comes back exactly.
  roundTrip = (game, A, B) ->
    x1 = adviseAll game, A
    x2 = adviseAll game, B, x1.mem
    x3 = adviseAll game, A, x2.mem
    expect(x3.texts).toEqual x1.texts
    expect(JSON.stringify(x1.texts) + JSON.stringify(x2.texts)).not.toMatch /NaN|undefined|Infinity/
    return [x1, x2]

  both = (game) ->
    [m, w] = roundTrip game, M, W
    roundTrip game, W, M
    return {m: m, w: w}

  it 'reads the game clock and this run\'s skipped time from the game, through a cast', ->
    game = load 'late_warp_test_fails', (j) -> j.unittypes.energy = '6500'
    s0 = advisor.snapshot game
    expect(s0.runSkipped).toBe 0
    expect(s0.gameNow - s0.now).toBe game.session.state.skippedMillis
    skip = game.upgrade('swarmwarp').effect[0].output().toNumber()
    expect(s0.energy.warp.skip).toBe skip
    expect(skip).toBeCloseTo 2405156.408, 2 # the reference case's 900 x power
    before = game.session.state.skippedMillis
    game.upgrade('swarmwarp').buy 1
    s1 = advisor.snapshot game
    expect(game.session.state.skippedMillis - before).toBe Math.floor(skip * 1000)
    expect(s1.now).toBe s0.now # a warp moves no wall clock
    expect(s1.gameNow - s1.now).toBe game.session.state.skippedMillis
    expect(s1.runSkipped).toBeCloseTo skip * 1000, 0
    expect(s1.energy.warp.casts).toBe 1
    expect(advisor.advise(s1, null, W).age - advisor.advise(s0, null, W).age).toBeCloseTo skip, 0

  it 'bounds this run\'s skipped time by the save\'s whole skipped time (power raised after warps)', ->
    # a first run that never warped: 3 warps at 1 bat, then 2,000 bats raise the skip of every past cast in the estimate
    game = load 'first_bats', (j) -> j.unittypes.energy = '9000'
    expect(game.session.state.skippedMillis).toBe 0
    game.upgrade('swarmwarp').buy 1 for i in [0...3]
    truth = game.session.state.skippedMillis
    game.unit('bat')._setCount 2000
    game.cache.onUpdate()
    estimate = 3 * game.upgrade('swarmwarp').effect[0].output().toNumber() * 1000
    expect(estimate).toBeGreaterThan 1.3 * truth
    s = advisor.snapshot game
    expect(s.runSkipped).toBe truth # min(estimate, the save's total): exact in a save's first run
    expect(advisor.advise(s, null, W).age).toBeCloseTo (s.now - s.restartedAt + truth) / 1000, 3

  it 'the free respec: after the first ascension yes; beside an ascension or under the near-complete guard no', ->
    {w} = both load 'switch_mirrors_purchases_made'
    expect(w.a.mutagen.respec).toBe true
    # 1,542 expansions: the test passes, ascend now (it brings 2.00e76 mutagen); no respec
    {w} = both load 'switch_mirrors_long_day30'
    expect(w.a.plan.type).toBe 'ascendNow'
    expect(w.a.mutagen.respec).toBe false
    expect(w.texts.ascension.join(' ')).not.toContain 'respec'
    # 4,500 expansions: the guard keeps the House of Mirrors run; no respec, no warp or bat mutations
    {w} = both load 'switch_mirrors_long_day30', (j) -> j.upgrades.expansion = '4500'
    expect(w.a.route.guard?).toBe true
    expect(w.a.mutagen?.respec ? false).toBe false
    joined = w.texts.ascension.join(' ')
    expect(joined).not.toContain 'respec'
    expect(joined).not.toContain 'mutantswarmwarp'
    expect(joined).not.toContain 'mutantbat'

  it 'keeps the final stage after the mutagen line is followed in the game (1.5e270 and 2.5e270 held)', ->
    for held in ['1.5e270', '2.5e270']
      game = load 'asc_28_lgM272', (j) -> j.unittypes.mutagen = held
      a = asc.advise asc.snapshot(game), W
      expect([held, a.stage]).toEqual [held, 'final']
      for st in a.mutagen.steps
        if st.type == 'unlock' then game.upgrade(st.name).buy 1 else game.unit(st.unit).buy st.count
      b = asc.advise asc.snapshot(game), W
      expect([held, b.stage, b.mutagen]).toEqual [held, 'final', null]

  it 'a warp cast in the game releases every climbing tier at once', ->
    game = load 'late_warp_test_fails', (j) -> j.unittypes.energy = '6500'
    x1 = adviseAll game, W
    # what the panel shows before the warp: buy the climb's rows, as the game's statistics would record them
    for t in x1.r.tiers when t.kind == 'buy'
      game.unit(t.name).buy t.buys
      stats = game.session.state.statistics.byUnit
      stats[t.name] = stats[t.name] ? {num: 0}
      stats[t.name].num = new Decimal(stats[t.name].num).plus(t.buys).toString()
    x2 = adviseAll game, W, x1.mem
    cooling = (t.name for t in x2.r.tiers when t.reason == 'cooldown')
    expect(cooling.length).toBeGreaterThan 0
    expect(x2.texts.tiers.join('\n')).toContain 'done, next in 60 s'
    game.upgrade('swarmwarp').buy 1
    x3 = adviseAll game, W, x2.mem
    expect((t.name for t in x3.r.tiers when t.reason == 'cooldown')).toEqual []
    expect((t.kind for t in x3.r.tiers when t.name in cooling)).toEqual ('buy' for t in cooling)
    # and the next warp waits for them
    expect(x3.energy.type).toBe 'warpAfter'

  it 'first run before nexus 5: the A.11 plan on both routes', ->
    {m, w} = both load 'first_nexus4'
    expect(m.a.stage).toBe 'firstRun'
    expect(w.a.stage).toBe 'build'
    expect(w.texts.energy).toBe m.texts.energy
    expect(w.texts.tiers).toEqual m.texts.tiers
    expect(m.t.mirrors).toBe false
    expect(w.t.mirrors).toBe false

  it 'first run after nexus 5, no mirrors cast: lepidoptera to 10,000 on both, named per route', ->
    {m, w} = both load 'first_moths'
    expect(m.a.stage).toBe 'firstRun'
    expect(w.a.stage).toBe 'build'
    expect(w.a.test.passes).toBe true
    expect(m.energy.type).toBe 'buyMoths'
    expect(w.energy.type).toBe 'buyMoths'
    expect(w.energy.count.toNumber()).toBe 27
    expect(m.texts.energy).toContain 'first-run target'
    expect(w.texts.energy).toContain 'swarmwarp route'

  it 'first run with House of Mirrors cast: territory stops only on the mirrors route; never a guarded long run (13 G2)', ->
    game = load 'first_bats', (j) ->
      j.upgrades.clonearmy = '20'
      j.upgrades.expansion = '4700'
    {m, w} = both game
    expect(m.t.mirrors).toBe true
    expect(m.texts.territory[0]).toBe 'set the territory share to 0 (now 0.1)'
    expect(w.t.mirrors).toBe false
    expect(w.a.route.guard).toBe null
    expect(w.a.stage).toBe 'build'
    expect(m.a.stage).toBe 'firstRun'
    expect(w.energy.type).toBe 'buyBats'
    expect(w.energy.count.toNumber()).toBe 3

  it 'after the first ascension, before any mutagen purchase: each route\'s mutagen line at once (13 G4)', ->
    {m, w} = both load 'switch_mirrors_after_first_ascension_before_purchases'
    expect(m.a.stage).toBe 'longRun'
    expect(w.a.stage).toBe 'build'
    expect(w.a.mutagen.respec).toBe false
    expect(([s.type, s.name ? s.unit] for s in w.a.mutagen.steps)).toEqual [
      ['unlock', 'mutatenexus'], ['unlock', 'mutateswarmwarp'], ['mutants', 'mutantnexus'], ['mutants', 'mutantswarmwarp']]
    expect(_.map m.a.mutagen.steps, 'type').toEqual ['unlock', 'mutants', 'unlocks']

  it 'after the mirrors route\'s purchases: the swarmwarp route advises the free respec (13 G3); without one, none', ->
    {m, w} = both load 'switch_mirrors_purchases_made'
    expect(m.a.mutagen).toBe null
    expect(w.a.mutagen.respec).toBe true
    expect(w.texts.ascension[0]).toMatch /^respec \(free, 4 left\)/
    {m, w} = both load 'switch_mirrors_purchases_no_free_respec'
    expect(w.a.mutagen.respec).toBe false
    expect(_.some w.a.mutagen.steps, type: 'unlock').toBe false

  it 'a mirrors long run, early (day 10): the swarmwarp route ascends (13 G1), the mirrors route does not', ->
    {m, w} = both load 'switch_mirrors_long_day10'
    expect(m.a.stage).toBe 'longRun'
    expect(m.a.plan).toBe null
    expect(m.t.mirrors).toBe true
    expect(w.a.stage).toBe 'build'
    expect(w.a.plan.type).toBe 'ascendNow'
    expect(w.a.plan.restarts).toBeUndefined() # 491 expansions
    expect(w.energy.type).toBe 'ascensionHold'
    expect(w.t.mirrors).toBe false

  it 'a mirrors long run, mid (day 30, 1,542 expansions): ascending says it restarts them', ->
    {m, w} = both load 'switch_mirrors_long_day30'
    expect(m.a.stage).toBe 'longRun'
    expect(w.a.plan.type).toBe 'ascendNow'
    expect(w.a.plan.restarts.expansions).toBe 1542
    expect(_.last w.texts.ascension).toContain 'this run has 1,542 expansions from House of Mirrors: ascending restarts them'

  it 'a mirrors long run near complete (4,695 expansions): both routes finish it with House of Mirrors', ->
    {m, w} = both load 'switch_mirrors_long_day30', (j) -> j.upgrades.expansion = '4695'
    expect(w.a.route.guard.expansions).toBe 4695
    expect(w.a.stage).toBe 'longRun'
    expect(w.a.plan).toBe null
    expect(w.texts.ascension).toContain '4,695 of 5,000 expansions: finish this run with House of Mirrors, then the swarmwarp route resumes'
    # the run itself as the mirrors route plays it: energy, climb, territory
    expect(w.texts.energy).toBe m.texts.energy
    expect(w.texts.energy).toContain 'House of Mirrors'
    expect(w.texts.tiers).toEqual m.texts.tiers
    expect(w.texts.territory).toEqual m.texts.territory
    expect(w.r.config.longRun).toBe 'off'

  # quick_stage was edited from the final run of a 28-ascension route to 15 ascensions; its save still has the
  # 20-ascension achievement, which the mirrors route reads (the swarmwarp route counts ascensions, 12.6)
  quick15 = (j) -> delete j.achievements.ascension3
  it 'quick runs with mirrors cast: both ascend when the energy allows', ->
    {m, w} = both load 'quick_stage', (j) ->
      quick15 j
      j.upgrades.clonearmy = '10'
    expect(m.a.stage).toBe 'quickRun'
    expect(w.a.stage).toBe 'quick'
    expect(m.a.plan?).toBe true
    expect(w.a.plan?).toBe true
    expect(w.t.mirrors).toBe false

  it 'swarmwarp build, final, quick and done states under the mirrors route (13 G6): its own stage logic, sane numbers', ->
    for [name, wStage, mStage] in [['late_warp_test_fails', 'build', 'longRun'], ['final_warp', 'final', 'longRun'],
        ['quick_stage', 'quick', 'quickRun'], ['done_stage', 'done', 'done'], ['asc_08_lgM26', 'build', 'longRun']]
      {m, w} = both load name, (if name == 'quick_stage' then quick15 else null)
      expect([name, w.a.stage]).toEqual [name, wStage]
      expect([name, m.a.stage]).toEqual [name, mStage]
      # the mirrors route ascends only in its quick runs, never in its long run
      expect([name, m.a.plan?]).toEqual [name, mStage == 'quickRun']
      expect([name, m.energy?.type in ['warp', 'warpAfter', 'buyBats', 'batTarget']]).toEqual [name, false]

  it 'swarmwarp states on their own route: build swarmwarps, final never ascends', ->
    {w} = both load 'late_warp_test_fails'
    expect(w.a.plan).toBe null
    expect(w.texts.ascension[0]).toMatch /^keep swarmwarping, do not ascend yet/
    expect(w.texts.energy).toBe 'next swarmwarp at 2,000 energy (have 785)'
    {w} = both load 'final_warp'
    expect(w.a.plan).toBe null
    expect(_.last w.texts.ascension).toMatch /^final run, do not ascend: expansions 1,584\/5,000/
