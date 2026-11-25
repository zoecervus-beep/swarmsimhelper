'use strict'

# Rule 4, banking (Nov 25, 2026): stop hatching a tier once the tier above makes `bank` times what larvae could make
# of it, larvae/s x the tier's twin multiplier. The console script divided the larva side by the tier above's twin
# multiplier (setting bankTwin 'script'), which banked tiers far too early once that multiplier was large.
describe 'Service: advisor, banking (rule 4)', ->

  beforeEach module 'swarmApp'

  advisor = Game = session = null
  beforeEach inject (_advisor_, _Game_, _session_) ->
    advisor = _advisor_
    Game = _Game_
    session = _session_

  D = (x) -> new Decimal x
  row = (r, name) -> _.find r.tiers, name: name

  # Hand-built: queens 1e9 under nests; a nest costs 100 queens, makes 100 queens/s and comes 4 to a hatch (twin 4);
  # one greater queen (twin 8, cost 100 nests) making `p` nests/s. Larvae 1,000/s, territory 0.1: spendable 900/s.
  # Both pass the climb test. Larvae could make 900 x 4 = 3,600 nests/s; the bank line is 3 x 3,600 = 10,800.
  mksnap = (p, twins=[4, 8]) ->
    spec = {queen: {count: 1e9}, nest: {cost: 100, prodEach: 100, twin: twins[0]}, greaterqueen: {count: 1, cost: 100, prodEach: p, twin: twins[1]}}
    units = for name, i in advisor.CHAIN
      u = spec[name] ? {}
      name: name, tier: i + 1, below: (if i > 0 then advisor.CHAIN[i - 1] else 'meat'), count: D(u.count ? 0)
      cost: (if i > 0 then D(u.cost ? 100) else null), twin: D(u.twin ? 1), prodEach: D(u.prodEach ? i + 1)
      twinCost: D(1e30), twinFactor: D(10), prodCost: null, prodLevel: 0, prodFactor: D(666), prodMult: D(2), meatCost: null, purchases: '0'
    {now: 3600e3, restartedAt: 0, larvae: D(1e6), larvaRate: D(1000), meat: D(1e100), units: units, energy: null}
  CFG = {ageMultiple: 5, territory: 0.1, bank: 3, seed: 'off'}

  it 'banks once the tier above makes more than 3 x larvae/s x the tier\'s twin', ->
    above = advisor.advise mksnap(10800 * 1.000001), null, CFG
    expect(row(above, 'nest').reason).toBe 'bank'
    expect(row(above, 'nest').bankFor).toBe 'greaterqueen'
    below = advisor.advise mksnap(10800 * 0.999999), null, CFG
    expect(row(below, 'nest').reason).not.toBe 'bank'
    expect(row(below, 'nest').kind).toBe 'buy'

  it '\'script\' is the console script\'s decision: the larva side divided by the tier above\'s twin (8)', ->
    # the script's line is 10,800 / 8 = 1,350: both states bank
    for p in [10800 * 0.999999, 1350 * 1.000001]
      expect(row(advisor.advise(mksnap(p), null, _.extend({bankTwin: 'script'}, CFG)), 'nest').reason).toBe 'bank'
    expect(row(advisor.advise(mksnap(1350 * 0.999999), null, _.extend({bankTwin: 'script'}, CFG)), 'nest').reason).not.toBe 'bank'

  it 'decides as before when the tier above has no twins', ->
    for p in [3600 * 3 * 1.000001, 3600 * 3 * 0.999999]
      plain = row advisor.advise(mksnap(p, [4, 1]), null, CFG), 'nest'
      script = row advisor.advise(mksnap(p, [4, 1]), null, _.extend({bankTwin: 'script'}, CFG)), 'nest'
      expect(plain.reason).toBe script.reason
    expect(advisor.DEFAULTS.bankTwin).toBe 'plain'

  describe 'the owner\'s 7.2 d save', ->
    load = ->
      files = window.__karma__?.files ? {}
      url = _.find _.keys(files), (f) -> /advisor\/sim\/example_save_run2_7d\.json$/.test f
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

    it 'hatches hive neurons with the idle larvae instead of banking them; the tiers below stay banked', ->
      {game, cfg} = load()
      # the stored settings: seed off, territory 0, and a stale longRun (ignored)
      expect(cfg.seed).toBe 'off'
      snap = advisor.snapshot game
      r = advisor.advise snap, null, cfg
      g = _.find snap.units, name: 'goddess'
      p = _.find snap.units, name: 'pantheon'
      pr = _.find snap.units, name: 'prophet'
      # what the pantheons make against what larvae could make of goddesses: 1.40e19 x 1,849 = 2.58e22 against
      # 2.22e18 x 524,288 = 1.16e24 a second, a real ratio of 0.022 (the script's formula: 5.7, over 3)
      madeAbove = p.count.times p.prodEach
      fromLarvae = snap.larvaRate.times g.twin
      expect(madeAbove.toExponential(2)).toBe '2.58e+22'
      expect(fromLarvae.toExponential(2)).toBe '1.16e+24'
      expect(madeAbove.dividedBy(fromLarvae).toNumber()).toBeCloseTo 0.0222, 3
      expect(madeAbove.dividedBy(fromLarvae.dividedBy p.twin).toNumber()).toBeGreaterThan 3
      expect(row(r, 'goddess').kind).toBe 'buy'
      expect(row(advisor.advise(snap, null, _.extend({bankTwin: 'script'}, cfg)), 'goddess').reason).toBe 'bank'
      # neuroprophets stay banked: the goddesses make 1.65e7 times what larvae could make of them
      ratio = g.count.times(g.prodEach).dividedBy(snap.larvaRate.times pr.twin)
      expect(ratio.toNumber()).toBeCloseTo 1.65e7, -5
      for name in ['prophet', 'empress', 'hivequeen', 'hive', 'greaterqueen', 'nest', 'queen']
        expect([name, row(r, name).reason]).toEqual [name, 'bank']
      # every larva goes to the climb at this look: pantheons (limited by goddesses) then goddesses take the rest,
      # 1.26e22 x 524,288 = 6.6e27 goddesses, 19x the 3.42e26 held
      buys = D(0)
      buys = buys.plus t.buys for t in r.tiers when t.kind == 'buy'
      expect(buys.toString()).toBe snap.larvae.floor().toString()
      gd = row r, 'goddess'
      expect(gd.buys.times(gd.twin).dividedBy(g.count).toNumber()).toBeCloseTo 19.3, 1

    it 'the goddess purchase, made in the game, raises what the pantheons can buy accordingly', ->
      {game, cfg} = load()
      r = advisor.advise advisor.snapshot(game), null, cfg
      before = row(r, 'pantheon').affordable
      held = game.unit('goddess').count()
      gd = row r, 'goddess'
      bought = game.unit('goddess').buy gd.buys
      expect(bought.num.toString()).toBe gd.buys.toString()
      stats = game.session.state.statistics.byUnit
      stats.goddess = stats.goddess ? {num: 0}
      stats.goddess.num = D(stats.goddess.num).plus(gd.buys).toString()
      r2 = advisor.advise advisor.snapshot(game), r.memory, cfg
      after = row(r2, 'pantheon').affordable
      # goddesses held went from 3.42e26 to 3.42e26 + 1.26e22 x 524,288; a pantheon costs 1e10 of them
      expect(after.dividedBy(before).toNumber()).toBeCloseTo held.plus(gd.buys.times gd.twin).dividedBy(held).toNumber(), 6
      expect(after.dividedBy(before).toNumber()).toBeGreaterThan 19
