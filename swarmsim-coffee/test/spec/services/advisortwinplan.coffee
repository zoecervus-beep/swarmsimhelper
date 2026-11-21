'use strict'

# The twin planner (`advisor.acquire`, rule 7): the cheapest way to hold N units of a tier, with detours through the
# tiers above ("hatch some of tier j+1, buy twin j, then hatch tier j at half price"). Since Nov 21, 2026 a detour may
# need some of tier j hatched first (setting twinDetour 'on', the default): the owner's empress twin.
describe 'Service: advisor, twin plans', ->

  beforeEach module 'swarmApp'

  advisor = advisorView = Game = session = null
  beforeEach inject (_advisor_, _advisorView_, _Game_, _session_) ->
    advisor = _advisor_
    advisorView = _advisorView_
    Game = _Game_
    session = _session_

  D = (x) -> new Decimal x

  # ---- an independent exhaustive search on small ladders --------------------------------------------------------
  # Tiers 0 (the target), 1 and 2. A hatch of tier 0 costs cost[0] of the currency (what acquire counts); a hatch of
  # tier i > 0 costs cost[i] units of tier i - 1. Twin i (i = 0, 1) costs twinCost[i] x factor^level units of tier
  # i + 1 and doubles what a hatch of tier i gives. Dial's algorithm over (held 0, 1, 2, twin levels 0, 1), one hatch
  # at a time: the least currency to hold N of tier 0. Bounds keep it small; they exceed any optimum found here.
  brute = (L) ->
    C0 = L.N + 16
    C1 = 30
    C2 = 6
    T = 4
    idx = (s) -> (((s[0] * (C1 + 1) + s[1]) * (C2 + 1) + s[2]) * T + s[3]) * T + s[4]
    seen = {}
    buckets = [[[L.have[0], L.have[1], L.have[2], 0, 0]]]
    c = 0
    while c < buckets.length
      b = buckets[c] ? []
      q = 0
      while q < b.length # moves of no cost add to this same bucket while it is read
        s = b[q]
        q += 1
        i = idx s
        continue if seen[i]
        seen[i] = true
        return c if s[0] >= L.N
        add = (cc, n) ->
          return if n[0] > C0 or n[1] > C1 or n[2] > C2 or n[3] >= T or n[4] >= T or seen[idx n]
          (buckets[cc] ?= []).push n
        add c + L.cost[0], [Math.min(s[0] + Math.pow(2, s[3]), C0), s[1], s[2], s[3], s[4]]
        add c, [s[0] - L.cost[1], s[1] + Math.pow(2, s[4]), s[2], s[3], s[4]] if s[0] >= L.cost[1]
        add c, [s[0], s[1] - L.cost[2], s[2] + 1, s[3], s[4]] if s[1] >= L.cost[2]
        p0 = L.twinCost[0] * Math.pow(L.factor[0], s[3])
        p1 = L.twinCost[1] * Math.pow(L.factor[1], s[4])
        add c, [s[0], s[1] - p0, s[2], s[3] + 1, s[4]] if s[1] >= p0
        add c, [s[0], s[1], s[2] - p1, s[3], s[4] + 1] if s[2] >= p1
      c += 1
    return null

  plan = (L, detour=true) ->
    st = for i in [0..2]
      {name: 't' + i, have: D(L.have[i]), twin: D(1), cost: D(L.cost[i]), twinCost: (if i < 2 then D(L.twinCost[i]) else null), twinFactor: D(if i < 2 then L.factor[i] else 1)}
    steps = []
    cost = advisor.acquire st, 0, D(L.N), steps, 0, detour
    return {cost: cost.toNumber(), steps: steps}

  # Replays a plan's steps: each must be affordable when reached, the target held at the end; returns the currency.
  replay = (L, steps) ->
    h = L.have.slice()
    tw = [1, 1, 1]
    lv = [0, 0]
    spent = 0
    for s in steps
      i = +s.unit.slice(1)
      if s.type == 'hatch'
        k = s.count.toNumber()
        if i == 0
          spent += k * L.cost[0]
        else
          return null if h[i - 1] < k * L.cost[i]
          h[i - 1] -= k * L.cost[i]
        h[i] += k * tw[i]
      else
        p = L.twinCost[i] * Math.pow(L.factor[i], lv[i])
        return null if h[i + 1] < p
        h[i + 1] -= p
        lv[i] += 1
        tw[i] *= 2
    return if h[0] >= L.N then spent else null

  ladders = (seed, n, factor) ->
    rnd = -> (seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648
    ri = (a, b) -> a + Math.floor(rnd() * (b - a + 1))
    for k in [0...n]
      {cost: [ri(1, 5), ri(1, 6), ri(1, 4)], have: [ri(0, 4), ri(0, 3), ri(0, 1)], twinCost: [ri(1, 6), ri(1, 3)], factor: (if factor? then [factor, factor] else [ri(2, 5), ri(2, 5)]), N: ri(4, 24)}

  it 'is the exhaustive minimum when twin prices grow fast (100x a level), and its plans can be followed', ->
    count = 0
    for L in ladders 7, 150, 100
      p = plan L
      expect([JSON.stringify(L), p.cost]).toEqual [JSON.stringify(L), brute L]
      expect([JSON.stringify(L), replay L, p.steps]).toEqual [JSON.stringify(L), p.cost]
      count += 1
    expect(count).toBe 150

  it 'at the game\'s twin price growth (10x) and slower: never dearer than the old planner, and its plans can be followed', ->
    # Measured in Node over 3,000 ladders each: at the minimum in 2,999 at 10x, 2,927 with growth 2-5x (the old planner:
    # 2,331 and 2,133). Where it misses, the minimum interleaves several twin levels of both tiers (below).
    atMin = 0
    for L in ladders(11, 100, 10).concat ladders(12, 100)
      p = plan L
      old = plan L, false
      expect([JSON.stringify(L), p.cost <= old.cost]).toEqual [JSON.stringify(L), true]
      expect([JSON.stringify(L), replay L, p.steps]).toEqual [JSON.stringify(L), p.cost]
      expect([JSON.stringify(L), replay L, old.steps]).toEqual [JSON.stringify(L), old.cost]
      atMin += 1 if p.cost == brute L
    expect(atMin).toBeGreaterThan 190

  it 'a known case above the minimum: one twin level and a hatch, where two levels of both tiers save 4', ->
    L = {cost: [4, 1, 1], have: [3, 2, 1], twinCost: [2, 3], factor: [10, 10], N: 24}
    expect(plan(L).cost).toBe 44
    expect(brute L).toBe 40

  it 'hatches part of the tier first when that pays for a detour (the case it was missing), level after level', ->
    # 1 of tier 0 held, a hatch costs 1e2; a tier-1 unit costs 10 of tier 0; twin 0 costs 1, then 10 tier-1 units; N = 1e3.
    # Direct: 999 hatches = 99,900. First detour: 9 hatches (900), 1 tier-1 unit, twin. Second: 50 hatches at x2
    # (5,000) give 100 for 10 tier-1 units, twin; then 1,000 / 4 = 250 hatches (25,000). In all 30,900.
    L = {cost: [100, 10, 1], have: [1, 0, 0], twinCost: [1, 1e9], factor: [10, 10], N: 1000}
    p = plan L
    expect(p.cost).toBe 30900
    expect(([s.type, s.unit, s.count?.toNumber()] for s in p.steps)).toEqual [['hatch', 't0', 9], ['hatch', 't1', 1], ['twin', 't0', undefined],
      ['hatch', 't0', 50], ['hatch', 't1', 10], ['twin', 't0', undefined], ['hatch', 't0', 250]]
    expect(brute L).toBe 30900
    expect(plan(L, false).cost).toBe 99900

  # ---- the owner's save -------------------------------------------------------------------------------------------
  # Run 2 at 3.0 d (advisor/sim/example_save_twin_3d.json): 4.40e18 hive empresses, 1 neuroprophet, no hive neurons.
  # The empress twin (level 10) costs 1e10 neuroprophets; a neuroprophet costs 1e8 empresses; the neuroprophet twin
  # (level 0) costs 1 hive neuron; a hive neuron costs 1e9 neuroprophets.
  loadGame = ->
    files = window.__karma__?.files ? {}
    url = _.find _.keys(files), (f) -> /advisor\/sim\/example_save_twin_3d\.json$/.test f
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

  it 'plans the empress twin through a neuroprophet twin: 6e17 empresses instead of 1e18, and the plan is followed in the game', ->
    {game, cfg} = loadGame()
    r = advisor.advise advisor.snapshot(game), null, cfg
    tip = _.find r.tips, {type: 'twinPlan', unit: 'empress'}
    # (1e9 - 1) x 1e8 + 5e9 x 1e8: the neuroprophet held counts toward the first 1e9
    expect(tip.planCost.toString()).toBe '599999999900000000'
    expect(([s.type, s.unit, s.count?.toString()] for s in tip.steps)).toEqual [
      ['hatch', 'prophet', '999999999'], ['hatch', 'goddess', '1'], ['twin', 'prophet', undefined], ['hatch', 'prophet', '5000000000']]
    expect(advisor.renderTip tip).toMatch /^hatch 1\.00e9 prophets > hatch 1 goddess > twin prophets > hatch 5\.00e9 prophets > twin empresss \(pays back in \d+ min\)$/
    expect(advisorView.tip(tip).text).toMatch /^plan: hatch .* › hatch 1 .* › .* › hatch .* › .*$/
    # the old planner
    old = _.find advisor.advise(advisor.snapshot(game), null, _.extend({twinDetour: 'off'}, cfg)).tips, {type: 'twinPlan', unit: 'empress'}
    expect(old.planCost.toString()).toBe '999999999900000000'
    expect(old.steps.length).toBe 1
    # follow it in the game, every step affordable when reached
    empresses = game.unit('empress').count()
    for s in tip.steps
      if s.type == 'hatch'
        u = game.unit s.unit
        expect([s.unit, u.isCostMet() and u.maxCostMet().greaterThanOrEqualTo(s.count)]).toEqual [s.unit, true]
        expect(u.buy(s.count).num.toString()).toBe s.count.toString()
      else
        up = game.upgrade s.unit + 'twin'
        expect([up.name, up.isCostMet()]).toEqual [up.name, true]
        up.buy 1
    up = game.upgrade 'empresstwin'
    level = up.count().toNumber()
    expect(up.isCostMet()).toBe true
    up.buy 1
    expect(up.count().toNumber()).toBe level + 1
    expect(empresses.minus(game.unit('empress').count()).toString()).toBe '599999999900000000'
    # the neuroprophet twin is kept
    expect(game.upgrade('prophettwin').count().toNumber()).toBe 1
