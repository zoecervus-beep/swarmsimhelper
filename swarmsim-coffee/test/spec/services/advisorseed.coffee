'use strict'

# Rule SEED (advisor/ASCENSION.md A.10.9, "Rule SEED (spec for the port; replaces LR-0 to LR-3)"): at every look,
# before the climb, 1% of each tier and of the climb's larvae go into every tier above the frontier. Expected values
# are worked out by hand in the comments, or read from the game.
describe 'Service: advisor, rule SEED', ->

  beforeEach module 'swarmApp'

  advisor = advisorView = Game = session = null
  beforeEach inject (_advisor_, _advisorView_, _Game_, _session_) ->
    advisor = _advisor_
    advisorView = _advisorView_
    Game = _Game_
    session = _session_

  D = (x) -> new Decimal x
  row = (r, name) -> _.find r.tiers, name: name
  lines = (r) -> ([l.unit, l.outcome, l.n?.toNumber(), l.binding] for l in r.seed.lines when l.outcome != 'nothing below')

  # A hand-built snapshot: every unit count 0, cost 100 of the tier below, production = tier number, twin 1, twin
  # upgrades out of reach, no faster upgrade (so no rule-FA clause) unless given, no meat price. Run age 1 h at multiple 5: horizon 18,000 s.
  mksnap = (o={}) ->
    units = for name, i in advisor.CHAIN
      u = o.units?[name] ? {}
      name: name, tier: i + 1, below: (if i > 0 then advisor.CHAIN[i - 1] else 'meat'), count: D(u.count ? 0)
      cost: (if i > 0 then D(u.cost ? 100) else null), twin: D(1), prodEach: D(u.prodEach ? i + 1)
      twinCost: D(u.twinCost ? 1e30), twinFactor: D(10), prodCost: (if u.prodCost? then D(u.prodCost) else null), prodLevel: 0, prodFactor: D(666), prodMult: D(2)
      meatCost: (if u.meatCost? then D(u.meatCost) else null), purchases: String(u.purchases ? 0)
    {now: 3600e3, restartedAt: 0, larvae: D(o.larvae ? 1e12), larvaRate: D(o.larvaRate ? 1), meat: D(o.meat ? 1e100), units: units, energy: null}
  CFG = {ageMultiple: 5, territory: 0.1}
  # queens 1e12 (H 100 s: they pass, the frontier); nests cost 1,000 queens and make 0.1 each: H = 3 x 1e4 = 3e4 s,
  # above the frontier
  nests = (extra={}) -> _.extend {queen: {count: 1e12}, nest: {cost: 1000, prodEach: 0.1}}, extra

  describe 'the lines', ->
    it 'seeds every tier above the frontier with 1% of what the tier below buys', ->
      r = advisor.advise mksnap(units: nests()), null, CFG
      expect(r.seed.frontier).toBe 'queen'
      # A = floor(1e12 x 0.9) = 9e11; n = min(1% x 1e12 / 1,000 = 1e7, 1% x 9e11 = 9e9) = 1e7
      expect(lines r).toEqual [['nest', 'hatch', 1e7, 'below']]
      n = row r, 'nest'
      expect([n.kind, n.reason, n.buys.toNumber()]).toEqual ['seed', 'seed', 1e7]
      expect(advisor.renderAction n).toBe 'seed upward: hatch 1.00e7 nests (1% of what your queens buy)'
      expect(advisorView.action n).toMatch /^seed upward: hatch .* \(1% of what your queens buy\)$/
      # the climb gets what is left
      expect(r.seed.left.toNumber()).toBe 9e11 - 1e7
      # the buy-box button and Shift fill take n
      expect(advisorView.suggestion({advice: r}, 'nest').buyCount).toBe '10000000'

    it 'is limited by 1% of the climb\'s larvae, and by half the meat', ->
      r = advisor.advise mksnap(units: nests(), larvae: 1000), null, CFG
      # A = 900: 1% is 9
      expect(lines r).toEqual [['nest', 'hatch', 9, 'larvae']]
      expect(advisor.renderAction row(r, 'nest')).toBe 'seed upward: hatch 9 nests (1% of the climb\'s larvae)'
      r = advisor.advise mksnap(units: nests(nest: {cost: 1000, prodEach: 0.1, meatCost: 1e6}), meat: 2e12), null, CFG
      # half of 2e12 meat / 1e6 = 1e6
      expect(lines r).toEqual [['nest', 'hatch', 1e6, 'meat']]
      expect(advisor.renderAction row(r, 'nest')).toBe 'seed upward: hatch 1.00e6 nests (half your meat)'
      # under one: no line
      r = advisor.advise mksnap(units: nests(), larvae: 50), null, CFG
      expect(lines r).toEqual [['nest', 'under one', 0, 'larvae']]
      expect(row(r, 'nest').reason).toBe 'tooSlow'

    it 'goes from the top down, each line taking its larvae before the next', ->
      # greater queens cost 100 nests and make 1e-4 (H 4e6 s); 1e9 nests held. A = 9e6 (larvae 1e7): 1% = 9e4 binds both
      units = nests(nest: {count: 1e9, cost: 1000, prodEach: 0.1}, greaterqueen: {cost: 100, prodEach: 1e-4})
      r = advisor.advise mksnap(units: units, larvae: 1e7), null, CFG
      expect(r.seed.frontier).toBe 'queen'
      expect(lines r).toEqual [['greaterqueen', 'hatch', 9e4, 'larvae'], ['nest', 'hatch', 9e4, 'larvae']]
      expect(r.seed.left.toNumber()).toBe 9e6 - 1.8e5

    it 'takes the frontier from owned tiers that pass the plain test; drones count; a FA start does not', ->
      # only drones: the frontier is drone, and queens (H 100 s, passing but not owned) get a seed line as well as
      # their climb, in one purchase
      r = advisor.advise mksnap(units: {drone: {count: 1e6}}), null, CFG
      expect(r.seed.frontier).toBe 'drone'
      expect(lines r).toEqual [['queen', 'hatch', 100, 'below']]
      q = row r, 'queen'
      expect(q.kind).toBe 'buy'
      expect(q.seed.n.toNumber()).toBe 100
      # nests owned but failing the plain test: not the frontier, even when rule FA can start them
      r = advisor.advise mksnap(units: nests(nest: {count: 5, cost: 1000, prodEach: 0.1, prodCost: 66})), null, CFG
      expect(r.seed.frontier).toBe 'queen'
      expect(_.map(r.seed.lines, 'unit')).toContain 'nest'

    it 'skips a tier hatched less than 60 s ago on the game clock, and a tier with nothing below', ->
      snap = mksnap units: nests(nest: {cost: 1000, prodEach: 0.1, purchases: 7})
      snap.gameNow = snap.now + 5e9
      mem = advisor.createMemory snap.gameNow, 0
      mem.seen.nest = '7'
      mem.boughtAt.nest = snap.gameNow - 30000
      r = advisor.advise snap, mem, CFG
      expect(lines r).toEqual [['nest', 'cooldown', undefined, undefined]]
      expect(row(r, 'nest').reason).toBe 'tooSlow'
      expect(_.find(r.seed.lines, unit: 'greaterqueen').outcome).toBe 'nothing below'
      # 61 s later on the game clock (a warp counts)
      snap.gameNow += 31000
      expect(lines advisor.advise(snap, mem, CFG)).toEqual [['nest', 'hatch', 1e7, 'below']]

    it 'is off with the setting off: no seed lines, the climb as without it', ->
      r = advisor.advise mksnap(units: nests()), null, _.extend({seed: 'off'}, CFG)
      expect(r.seed).toBeUndefined()
      expect(row(r, 'nest').reason).toBe 'tooSlow'
      expect(_.some r.tiers, kind: 'seed').toBe false

  describe 'interactions', ->
    it 'twin tips paid in a seeded tier are no longer held back (the long-run mode\'s LR-3 guard is gone)', ->
      # queens climb (drones 1e12, 900 larvae/s spendable); their twin costs 10 nests; 1,000 nests held, far under
      # 1e6 x the price (the old guard), and nests are above the frontier
      units = {drone: {count: 1e12}, queen: {count: 1e6, twinCost: 10}, nest: {count: 1000, cost: 1000, prodEach: 0.1}}
      r = advisor.advise mksnap(units: units, larvaRate: 1000), null, CFG
      expect(r.seed.frontier).toBe 'queen'
      expect(_.find r.tips, {type: 'twin', unit: 'queen'}).toBeDefined()

    it 'keeps rule FA: units seeded this look count, and the row keeps FA\'s reason', ->
      # nests' faster upgrade costs 66 nests: with the 1e7 seeded, 1 level makes H = 3e4 x (N + 66) / (2N) < 18,000
      r = advisor.advise mksnap(units: nests(nest: {cost: 1000, prodEach: 0.1, prodCost: 66})), null, CFG
      n = row r, 'nest'
      expect(n.reason).toBe 'seed'
      expect(n.faster.type).toBe 'held'
      expect(advisor.renderAction n).toBe 'seed upward: hatch 1.00e7 nests (1% of what your queens buy) - buy 1 faster level (66 nests) and they pay back inside the horizon'
      expect(_.find(r.tips, {type: 'faster', unit: 'nest'}).levels).toBe 1

    it 'a seed line holds the next swarmwarp only when it is new since a warp (900 s), not as a 60 s refill', ->
      r = advisor.advise mksnap(units: nests()), null, CFG
      warp = {type: 'warp', casts: D(1), affordable: D(3), cost: D(2000), skip: 900}
      quiet = _.extend {}, r, tips: []
      n = row quiet, 'nest'
      n.seed.since = 120
      expect(advisor.orderWarp warp, quiet, null).toBe warp
      n.seed.since = 900
      expect(advisor.orderWarp(warp, quiet, null).pending.climb).toBe 1

  describe 'the owner\'s saves', ->
    load = (name) ->
      files = window.__karma__?.files ? {}
      url = _.find _.keys(files), (f) -> new RegExp('advisor/sim/' + name + '\\.json$').test f
      xhr = new XMLHttpRequest()
      xhr.open 'GET', url, false
      xhr.send()
      json = JSON.parse xhr.responseText
      state = session._loads session._saves json, false
      shift = (new Date().getTime() - 3600e3) - state.date.reified.getTime()
      for key, date of state.date
        state.date[key] = new Date date.getTime() + shift
      game = new Game {state: state, save: ->}
      game.now = new Date state.date.reified.getTime()
      game.cache.onUpdate()
      return {game: game, cfg: json.options.advisor}

    it 'the 3.0 d save: neuroprophets seeded with 1% of what the empresses buy', ->
      {game, cfg} = load 'example_save_run2_72h'
      # the stored settings hold the retired longRun: ignored
      expect(cfg.longRun).toBe 'off'
      r = advisor.advise advisor.snapshot(game), null, cfg
      expect(r.config.longRun).toBeUndefined()
      expect(r.seed.frontier).toBe 'empress'
      # 1% of 4,398,764,070,659,960,773 empresses / 1e8 each = 439,876,407 (the reference case's 3.4e8 is the same
      # save after the simulator bought the empress twin with 1e18 empresses)
      p = row r, 'prophet'
      expect([p.kind, p.buys.toString(), p.seed.binding]).toEqual ['seed', '439876407', 'below']
      # with rule FA's reason for not starting them outright (5 faster levels)
      expect(advisor.renderAction p).toBe 'seed upward: hatch 4.40e8 prophets (1% of what your empresss buy) - with 5 faster levels (8.66e15 prophets) they would pay back once 3.30e16 are bought; you can afford 4.35e10'
      # the first row with something to do, from the top
      first = _.find r.tiers.slice().reverse(), (t) -> t.kind in ['buy', 'seed']
      expect(first.name).toBe 'prophet'
      texts = (advisorView.action t for t in r.tiers).concat (advisor.renderTip t for t in r.tips)
      expect(JSON.stringify texts).not.toMatch /NaN|undefined|Infinity/

    it 'the 45 h save: empresses seeded, with rule FA\'s reason for not starting them', ->
      {game, cfg} = load 'example_save_run2_45h'
      r = advisor.advise advisor.snapshot(game), null, cfg
      e = row r, 'empress'
      # 1% of 1.04e14 hive queens / 1e7 each = 104,063
      expect([e.kind, e.buys.toNumber(), e.seed.binding]).toEqual ['seed', 104063, 'below']
      expect(advisor.renderAction e).toMatch /^seed upward: hatch 104,063 empresss \(1% of what your hivequeens buy\) - with 3 faster levels \(2\.93e7 empresss\) they would pay back once 2\.69e8 are bought; you can afford 1\.03e7$/
      texts = (advisorView.action t for t in r.tiers).concat (advisor.renderTip t for t in r.tips)
      expect(JSON.stringify texts).not.toMatch /NaN|undefined|Infinity/

  describe 'the setting', ->
    it 'is on by default, stored with the others; a stored longRun is ignored without error', inject (options) ->
      expect(options.advisorConfig().seed).toBe 'on'
      options.session.state.options.advisor = {longRun: 'on', ageMultiple: 7}
      expect(-> options.advisorConfig()).not.toThrow()
      expect(options.advisorConfig().longRun).toBeUndefined()
      expect(options.advisorConfig().ageMultiple).toBe 7
      options.advisorSetting 'seed', 'off'
      expect(options.advisorConfig().seed).toBe 'off'
      expect(-> options.advisorSetting 'longRun', 'on').toThrow()
