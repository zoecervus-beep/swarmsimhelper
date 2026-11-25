'use strict'

# Rule 7, twin plans the console script did not make (Nov 25, 2026; setting twinDetour 'on'): a plan for a twin that
# is "free now" (t x S >= c + max(0, c - H): S hatches of the unit affordable now, H held, t its twin, c the plan's
# cost in the unit), or paid in a tier that passes the climb test and pays back in time; two plans that hatch the
# same tier show the higher one only. advisor.coffee `twinPlanNow`.
describe 'Service: advisor, twin plans now (rule 7)', ->

  beforeEach module 'swarmApp'

  advisor = advisorView = Game = session = null
  beforeEach inject (_advisor_, _advisorView_, _Game_, _session_) ->
    advisor = _advisor_
    advisorView = _advisorView_
    Game = _Game_
    session = _session_

  D = (x) -> new Decimal x
  plans = (r) -> (t for t in r.tips when t.type == 'twinPlan')
  text = (r) -> (advisor.renderTip(t) for t in r.tips)

  # Hand-built: the spec's units by name; the others hold none, cost 100, make tier + 1 each, twins out of reach.
  # Larvae 1e6 (+1,000/s), territory 0.1; the run is 1 h old (horizon 5 h).
  mksnap = (spec, o={}) ->
    units = for name, i in advisor.CHAIN
      u = spec[name] ? {}
      name: name, tier: i + 1, below: (if i > 0 then advisor.CHAIN[i - 1] else 'meat'), count: D(u.count ? 0)
      cost: (if i > 0 then D(u.cost ? 100) else null), twin: D(u.twin ? 1), prodEach: D(u.prodEach ? i + 1)
      twinCost: D(u.twinCost ? 1e30), twinFactor: D(10), prodCost: null, prodLevel: 0, prodFactor: D(666), prodMult: D(2)
      meatCost: (if u.meatCost? then D(u.meatCost) else null), purchases: '0'
    {now: 3600e3, restartedAt: 0, larvae: D(o.larvae ? 1e6), larvaRate: D(1000), meat: D(o.meat ? 1e100), units: units, energy: null}
  CFG = {ageMultiple: 5, territory: 0.1, bank: 3, seed: 'off'}

  # Nests (twin 4, n held, 100 nests/s each) climb on q queens: S = q / 100 hatches. The nest twin costs 10 greater
  # queens (none held, 100 nests each, failing the climb test): c = 1,000 nests.
  free = (q, n=100, gq={}) -> mksnap {queen: {count: q}, nest: {count: n, cost: 100, prodEach: 100, twin: 4, twinCost: 10}, greaterqueen: _.extend({cost: 100, prodEach: 1e-6}, gq)}

  it 'free now, H < c: 4 x S >= 1,000 + 900 (S = 475), with the nests hatched first', ->
    r = advisor.advise free(47500), null, CFG
    expect(text r).toEqual ['hatch 225 nests > hatch 10 greaterqueens > twin nests (free now)']
    expect(plans(r)[0].free).toBe true
    expect(plans(r)[0].planCost.toNumber()).toBe 1000
    expect(text advisor.advise(free(47400), null, CFG)).toEqual []
    # the console script's switch: no plan
    expect(text advisor.advise(free(47500), null, _.extend({twinDetour: 'off'}, CFG))).toEqual []

  it 'free now, H >= c: 4 x S >= 1,000 (held units do not double; S = 250)', ->
    expect(text advisor.advise(free(25000, 1500), null, CFG)).toEqual ['hatch 10 greaterqueens > twin nests (free now)']
    expect(text advisor.advise(free(24900, 1500), null, CFG)).toEqual []
    # (S x t + H >= 2c would pass at S = 125: 1,500 - 1,000 + 2 x 4 x 125 = 1,500 = 1,500 + 4 x 125 - 500)
    expect(text advisor.advise(free(20000, 1500), null, CFG)).toEqual []

  it 'not while the twin gains less than its price makes: uRate (4 x min(900, 100)) >= 10 x what a greater queen makes', ->
    expect(plans(advisor.advise free(1e6, 100, {prodEach: 40 * 0.999999}), null, CFG).length).toBe 1
    expect(plans(advisor.advise free(1e6, 100, {prodEach: 40 * 1.000001}), null, CFG).length).toBe 0

  it 'not while the paying tier makes more than uRate (\'script\': uRate / its twin; implied by the line above with \'plain\')', ->
    SCRIPT = _.extend {bankTwin: 'script'}, CFG
    # 5 greater queens held, twin 8: one hatch (100 nests) pays the price; inflow 400 / 8 = 50 nests/s
    gq = (p) -> {count: 5, twin: 8, prodEach: p}
    expect(plans(advisor.advise free(1e6, 100, gq(10 * 0.999999)), null, SCRIPT).length).toBe 1
    expect(plans(advisor.advise free(1e6, 100, gq(10 * 1.000001)), null, SCRIPT).length).toBe 0
    expect(plans(advisor.advise free(1e6, 100, gq(10 * 1.000001)), null, CFG).length).toBe 1

  it 'every hatch affordable now: the plan\'s meat (225 nests at 1, 10 greater queens at 1e6)', ->
    snap = (meat) ->
      s = free 1e6
      s.meat = D meat
      _.find(s.units, name: 'nest').meatCost = D 1
      _.find(s.units, name: 'greaterqueen').meatCost = D 1e6
      return s
    expect(plans(advisor.advise snap(1e7 + 225), null, CFG).length).toBe 1
    expect(plans(advisor.advise snap(1e7 + 224), null, CFG).length).toBe 0

  # Pays back: greater queens pass the climb test (p nests/s each), none held; the nests held cover twice the plan.
  # uRate = 4 x min(900, n) = 3,600; gain = 3,600 - 10p; payback = (1,000 + 10 larvae x 4) / gain; x 4 < 18,000 s.
  pays = (n, p, larvae) -> mksnap {queen: {count: 1e4}, nest: {count: n, cost: 100, prodEach: 100, twin: 4, twinCost: 10}, greaterqueen: {cost: 100, prodEach: p}}, {larvae: larvae}
  P = _.extend {share: 0.01}, CFG # greater queens' own row stays small (1 a look), short of the price
  it 'pays back: the nests held cover twice the plan (2,000)', ->
    r = advisor.advise pays(2000, 1), null, P
    expect(text r).toEqual [jasmine.stringMatching /^hatch 10 greaterqueens > twin nests \(pays back in /]
    expect(plans(r)[0].free).toBe false
    expect(plans(advisor.advise pays(1999, 1), null, P).length).toBe 0

  it 'pays back: inside the horizon', ->
    g = 4 * 1040 / 18000
    expect(plans(advisor.advise pays(2000, (3600 - g * 1.001) / 10), null, P).length).toBe 1
    expect(plans(advisor.advise pays(2000, (3600 - g * 0.999) / 10), null, P).length).toBe 0

  it 'pays back: the larvae for every hatch (10, out of 90% of the larvae)', ->
    expect(plans(advisor.advise pays(2000, 1, 12), null, P).length).toBe 1
    expect(plans(advisor.advise pays(2000, 1, 11), null, P).length).toBe 0

  # Two plans hatch greater queens: the greater queen twin (1 hive, 100 greater queens) and the nest twin (10 greater
  # queens). The higher one shows, the other is named as next.
  two = (n) -> mksnap {queen: {count: 1e6}, nest: {count: n, cost: 100, prodEach: 100, twin: 4, twinCost: 10}, greaterqueen: {count: 1, cost: 100, prodEach: 1, twinCost: 1}, hive: {cost: 100, prodEach: 1e-6}}
  it 'two plans on the same stock: the higher tier\'s first, the other re-priced at the next look', ->
    r = advisor.advise two(20000), null, P
    expect(text r).toEqual ['hatch 99 greaterqueens > hatch 1 hive > twin greaterqueens (free now); then twin nests, re-priced at the next look']
    expect(plans(r)[0].then).toEqual ['nest']
    # the greater queen twin not free (S = 198 < 199): the nest plan alone
    expect(text advisor.advise(two(19800), null, P)).toEqual ['hatch 9 greaterqueens > twin nests (free now)']

  describe 'the owner\'s 7.2 d save, minutes later (the 20th hive neuron twin bought)', ->
    load = ->
      files = window.__karma__?.files ? {}
      url = _.find _.keys(files), (f) -> /advisor\/sim\/example_save_run2_7d_b\.json$/.test f
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
    buy = (game, name, n) ->
      got = game.unit(name).buy(n).num
      stats = game.session.state.statistics.byUnit
      stats[name] = stats[name] ? {num: 0}
      stats[name].num = D(stats[name].num).plus(got).toString()
      return got
    follow = (game, tip) ->
      for s in tip.steps
        if s.type == 'hatch' then buy(game, s.unit, s.count) else game.upgrade(s.unit + 'twin').buy 1
      game.upgrade(tip.unit + 'twin').buy 1

    it 'the neural cluster twin first (free now), then the hive neuron twin re-priced; followed in the game', ->
      {game, cfg} = load()
      snap = advisor.snapshot game
      r = advisor.advise snap, null, cfg
      nc = _.find snap.units, name: 'pantheon'
      hn = _.find snap.units, name: 'goddess'
      # neural clusters: 4.77e18 held, twin 256, 1.65e18 hatches affordable (1e10 hive neurons each); their twin
      # (level 9) costs 1e8 hive networks = 1e20 neural clusters (1 hive network held)
      expect(game.upgrade('pantheontwin').count().toNumber()).toBe 8
      expect(nc.twinCost.toNumber()).toBe 1e8
      expect(nc.count.toExponential(2)).toBe '4.77e+18'
      expect(row = _.find(r.tiers, name: 'pantheon')).toBeDefined()
      expect(row.affordable.toExponential(2)).toBe '1.65e+18'
      expect(row.kind).toBe 'buy'
      tips = plans r
      expect(tips.length).toBe 1
      expect(r.tips.length).toBe 1
      tip = tips[0]
      expect(advisor.renderTip tip).toBe 'hatch 3.72e17 pantheons > hatch 1.00e8 pantheon2s > twin pantheons (free now); then twin goddesss, re-priced at the next look'
      expect(advisor.renderTip tip).not.toMatch /NaN|undefined/
      # the panel's text (the game's labels)
      panel = advisorView.tip(tip).text
      expect(panel).toBe 'plan: hatch 371Qa neural clusters › hatch 99.9M hive networks › twin neural clusters (free now); then twin hive neurons, re-priced at the next look'
      expect(panel).not.toMatch /NaN|undefined/
      expect(tip.free).toBe true
      expect(tip.planCost.toString()).toBe '99999999000000000000'
      expect(tip.steps[0].count.toString()).toBe '371973960290366062'
      # 256 x 1.65e18 = 4.2e20 >= c + (c - H) = 1.95e20
      expect(nc.twin.times(row.affordable).greaterThan tip.planCost.times(2).minus(nc.count)).toBe true
      # the console script's switch: no tip at all on this save
      expect(advisor.advise(snap, null, _.extend({}, cfg, twinDetour: 'off')).tips).toEqual []
      goddessBefore = _.find(r.tiers, name: 'goddess')
      follow game, tip
      expect(game.upgrade('pantheontwin').count().toNumber()).toBe 9
      # the next look: the 21st hive neuron twin, 1e20 neural clusters now at 512 a hatch (1.95e17, not 3.72e17)
      r2 = advisor.advise advisor.snapshot(game), r.memory, cfg
      expect(text r2).toEqual ['hatch 1.95e17 pantheons > twin goddesss (pays back in 14 min)']
      expect(plans(r2)[0].steps[0].count.toString()).toBe '195312500000000000'
      follow game, plans(r2)[0]
      expect(game.upgrade('goddesstwin').count().toNumber()).toBe 21
      r3 = advisor.advise advisor.snapshot(game), r2.memory, cfg
      gd = _.find r3.tiers, name: 'goddess'
      expect(gd.kind).toBe 'buy'
      expect(gd.twin.dividedBy(goddessBefore.twin).toNumber()).toBe 2
      # nothing flips back, and the 22nd (1e21 neural clusters, 1.95e18 hatches = 1.95e28 hive neurons) waits: the
      # 1.08e28 hive neurons held do not cover twice that
      expect(r3.tips).toEqual []
      s3 = advisor.snapshot game
      expect(_.find(s3.units, name: 'goddess').twinCost.toNumber()).toBe 1e21
      expect(_.find(s3.units, name: 'goddess').count.toExponential(2)).toBe '1.08e+28'

    it 'without the neural cluster twin: the 21st hive neuron twin alone (3.72e17 hatches), paying back in 26 min', ->
      {game, cfg} = load()
      snap = advisor.snapshot game
      _.find(snap.units, name: 'pantheon').twinCost = D 1e300
      r = advisor.advise snap, null, cfg
      expect(text r).toEqual ['hatch 3.72e17 pantheons > twin goddesss (pays back in 26 min)']
      expect(plans(r)[0].free).toBe false
