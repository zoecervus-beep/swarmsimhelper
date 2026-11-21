'use strict'

# Rule FA (advisor/MODEL-CHECK.md, "Faster-aware climbing, pass 2", "Rule FA, if adopted (variant c2)"): a tier that
# fails the climb test is started when buying it with a few of its own faster levels pays back inside the horizon;
# otherwise its "wait" line says what it would take. Expected numbers come from the reference cases
# (advisor/modelcheck/faster_cases/) and the arithmetic in the comments.
describe 'Service: advisor, rule FA (faster levels in the climb test)', ->

  beforeEach module 'swarmApp'

  advisor = advisorView = Game = session = null
  beforeEach inject (_advisor_, _advisorView_, _Game_, _session_) ->
    advisor = _advisor_
    advisorView = _advisorView_
    Game = _Game_
    session = _session_

  D = (x) -> new Decimal x
  fetchJson = (re) ->
    files = window.__karma__?.files ? {}
    url = _.find _.keys(files), (f) -> re.test f
    if not url?
      throw new Error 'not served by karma: ' + re
    xhr = new XMLHttpRequest()
    xhr.open 'GET', url, false
    xhr.send()
    return JSON.parse xhr.responseText
  load = (json) ->
    state = session._loads session._saves json, false
    shift = (new Date().getTime() - 3600e3) - state.date.reified.getTime()
    for key, date of state.date
      state.date[key] = new Date date.getTime() + shift
    game = new Game {state: state, save: ->}
    game.now = new Date state.date.reified.getTime()
    game.cache.onUpdate()
    return game
  loadCase = (name) -> load fetchJson new RegExp('faster_cases/' + name + '\\.save\\.json$')
  loadSave = (name) -> load fetchJson new RegExp('advisor/sim/' + name + '\\.json$')
  row = (r, name) -> _.find r.tiers, name: name
  texts = (r) -> (advisor.renderAction t for t in r.tiers).concat (advisor.renderTip t for t in r.tips)
  # the cases' settings (faster_cases/<case>.json `config`): multiple 5, territory share 0.1. They were made
  # without rule SEED (and run 2 with the retired long-run mode): seed off
  CASE = {ageMultiple: 5, territory: 0.1, spareEnergy: 'save', ascension: 'off', seed: 'off'}
  RUN2 = CASE

  describe 'on the owner\'s saves', ->
    it 'save (2), run 2 at 45 h: empresses wait, and the line says why (3 levels, 2.93e7; 2.69e8 against 1.04e7)', ->
      json = fetchJson /advisor\/sim\/example_save_run2_45h\.json$/
      # the owner's stored settings (multiple 5, territory 0), with rule SEED off: this is rule FA's reference; with SEED
      # the row is the seed line and keeps the same clause (advisorseed.coffee)
      cfg = _.extend {}, json.options.advisor, seed: 'off'
      r = advisor.advise advisor.snapshot(load json), null, cfg
      e = row r, 'empress'
      expect(e.reason).toBe 'tooSlow'
      expect(e.H.toNumber() / 86400).toBeCloseTo 67.1, 1
      expect(r.horizon / 86400).toBeCloseTo 9.4, 1
      # 2^3 >= 67.1 / 9.4 = 7.1: 3 levels, 66 + 43,956 + 29,274,696 = 29,318,718 empresses
      expect(e.faster.type).toBe 'wait'
      expect(e.faster.levels).toBe 3
      expect(e.faster.price.toNumber()).toBe 29318718
      # held N >= H x F / (8 x horizon - H) = 2.4e8, so 2.69e8 in all; 1.04e14 hive queens / 1e7 = 1.04e7 affordable
      expect(e.faster.hatch.toExponential(2)).toBe '2.69e+8'
      expect(e.faster.affordable.toNumber()).toBe 10406316
      expect(advisor.renderAction e).toBe 'wait 11.5 d - with 3 faster levels (2.93e7 empresss) they would pay back once 2.69e8 are bought; you can afford 1.04e7'
      expect(advisorView.action e).toMatch /^wait 11\.5 d — with 3 levels of .* they would pay back once .* are bought; you can afford /
      # no levels' tip: they would not pay off on what is held
      expect(_.some r.tips, unit: 'empress').toBe false
      # neuroprophets: none affordable (2 empresses / 1e8 each), so the plain "wait", no clause
      p = row r, 'prophet'
      expect(p.reason).toBe 'tooSlow'
      expect(p.faster).toBeUndefined()
      expect(advisor.renderAction p).toBe 'wait 141.4 d'
      expect(advisorView.action p).toBe 'wait 141.4 d'

    it 'the 58 h save: hive queens a plain buy at multiple 5, a start with 1 faster level at 3', ->
      game = loadSave 'example_save_58h'
      snap = advisor.snapshot game
      OWNER = {spareEnergy: 'save', territory: 0, seed: 'off'}
      hq = row advisor.advise(snap, null, OWNER), 'hivequeen'
      expect(hq.reason).toBe 'buy'
      expect(hq.faster).toBeUndefined()
      r3 = advisor.advise snap, null, _.extend({ageMultiple: 3}, OWNER)
      hq = row r3, 'hivequeen'
      expect(hq.reason).toBe 'fasterStart'
      expect(hq.faster.levels).toBe 1
      expect(hq.buys.toNumber()).toBe 10014
      expect(advisor.renderAction hq).toBe 'BUY 10,014 and 1 faster hivequeen level (66): with them hivequeens pay back inside the horizon'
      tip = _.find r3.tips, unit: 'hivequeen'
      expect(tip.levels).toBe 1
      expect(tip.cost.toNumber()).toBe 66
      # the buy-box button and Shift fill take n
      expect(advisorView.suggestion({advice: r3}, 'hivequeen').buyCount).toBe '10014'

  describe 'the line, and L = 1, 2, 3 (reference cases)', ->
    it 'starts just above the line and waits just below it', ->
      above = advisor.advise advisor.snapshot(loadCase 'line_just_above'), null, RUN2
      expect(row(above, 'pantheon2').reason).toBe 'fasterStart'
      expect(row(above, 'pantheon2').faster.levels).toBe 1
      below = advisor.advise advisor.snapshot(loadCase 'line_just_below'), null, RUN2
      p = row below, 'pantheon2'
      expect(p.reason).not.toBe 'fasterStart'
      expect(p.passes).toBe false

    it 'starts tiers with 1, 2 and 3 levels', ->
      for [name, cfg, tier, L, n] in [['mirrors58_save_x3', _.extend({}, CASE, ageMultiple: 3), 'hivequeen', 1, 10014],
          ['mirrors20_asc0_hivequeen', CASE, 'hivequeen', 2, 109014], ['mirrors20_asc0_empress', CASE, 'empress', 3, 186150235]]
        r = advisor.advise advisor.snapshot(loadCase name), null, cfg
        t = row r, tier
        expect([name, t.reason, t.faster?.levels, t.buys.toNumber()]).toEqual [name, 'fasterStart', L, n]
        expect([name, (_.find r.tips, unit: tier)?.levels]).toEqual [name, L]
        expect(JSON.stringify texts r).not.toMatch /NaN|undefined|Infinity/

    it 'after the hatch, the levels\' tip at 1x; once they are bought the tier passes the plain test', ->
      game = loadCase 'mirrors20_asc0_empress'
      r = advisor.advise advisor.snapshot(game), null, CASE
      e = row r, 'empress'
      game.unit('empress').buy e.buys
      stats = game.session.state.statistics.byUnit
      stats.empress = stats.empress ? {num: 0}
      stats.empress.num = D(stats.empress.num).plus(e.buys).toString()
      r1 = advisor.advise advisor.snapshot(game), r.memory, CASE
      e1 = row r1, 'empress'
      expect(e1.reason).toBe 'tooSlow'
      expect(e1.faster.type).toBe 'held'
      tip = _.find r1.tips, unit: 'empress'
      expect(advisor.renderTip tip).toBe 'faster empresss x3 (2.93e7)'
      game.upgrade('empressprod').buy 1 for i in [0...3]
      r2 = advisor.advise advisor.snapshot(game), r1.memory, CASE
      expect(row(r2, 'empress').passes).toBe true
      expect(row(r2, 'empress').reason).not.toBe 'tooSlow'

  describe 'interactions (hand-built states)', ->
    # queens 1e12 under nests; nests cost 1,000 queens and make 0.1 each: payback 1e4 s, H = 3e4 s. Run age 1 h
    # at multiple 5: horizon 18,000 s, so nests fail; 1 level (66 nests, x2) makes it 15,000 s with 1e9 bought.
    mksnap = (o={}) ->
      units = for name, i in advisor.CHAIN
        u = o.units?[name] ? {}
        name: name, tier: i + 1, below: (if i > 0 then advisor.CHAIN[i - 1] else 'meat'), count: D(u.count ? 0)
        cost: (if i > 0 then D(u.cost ? 100) else null), twin: D(1), prodEach: D(u.prodEach ? i + 1)
        twinCost: D(1e30), twinFactor: D(10), prodCost: D(u.prodCost ? 1e30), prodLevel: 0, prodFactor: D(666), prodMult: D(2)
        meatCost: null, purchases: String(u.purchases ? 0)
      {now: 3600e3, restartedAt: 0, larvae: D(1e12), larvaRate: D(o.larvaRate ? 1), meat: D(1e100), units: units, energy: null}
    nests = (extra={}) -> _.extend {queen: {count: 1e12}, nest: {cost: 1000, prodEach: 0.1, prodCost: 66}}, extra
    FA = {ageMultiple: 5, territory: 0.1, seed: 'off'} # rule FA alone (with SEED on, the seed takes 1% first)

    it 'starts a failing tier with all that is affordable, and FA off is the advice without it', ->
      r = advisor.advise mksnap(units: nests()), null, FA
      n = row r, 'nest'
      expect(n.reason).toBe 'fasterStart'
      # min(floor(1e12 x 0.9), 1e12 / 1,000) = 1e9
      expect(n.buys.toNumber()).toBe 1e9
      expect(n.faster.levels).toBe 1
      rOff = advisor.advise mksnap(units: nests()), null, _.extend({fasterStart: "off"}, FA)
      expect(row(rOff, "nest").reason).toBe 'tooSlow'
      expect(row(rOff, "nest").faster).toBeUndefined()
      expect(advisor.renderAction row(rOff, "nest")).toBe 'wait 40 min' # 3e4 / 5 - 3,600 s
      expect(_.some rOff.tips, unit: 'nest').toBe false

    it 'leaves a banked tier alone', ->
      # greater queens make far more nests than larvae could: nests are banked, never started
      units = nests greaterqueen: {count: 1, cost: 1, prodEach: 1e9}
      r = advisor.advise mksnap(units: units, larvaRate: 1), null, FA
      n = row r, 'nest'
      expect(n.reason).toBe 'tooSlow'
      expect(n.faster).toBeUndefined()

    it 'does not hatch a tier in its cooldown', ->
      snap = mksnap units: nests(nest: {cost: 1000, prodEach: 0.1, prodCost: 66, purchases: 7})
      mem = advisor.createMemory snap.now, 0
      mem.seen.nest = '7'
      mem.boughtAt.nest = snap.now - 10000
      r = advisor.advise snap, mem, FA
      n = row r, 'nest'
      expect(n.reason).toBe 'tooSlow'
      expect(n.buys.toNumber()).toBe 0

    it 'holds the next swarmwarp while a start is open', ->
      r = advisor.advise mksnap(units: nests()), null, FA
      warp = {type: 'warp', casts: D(1), affordable: D(3), cost: D(2000), skip: 900}
      held = advisor.orderWarp warp, _.extend({}, r, tips: []), null
      expect(held.type).toBe 'warpAfter'
      expect(held.pending.climb).toBe 1
