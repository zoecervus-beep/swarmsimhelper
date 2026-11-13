'use strict'

# The long-run climb mode (advisor/ASCENSION.md A.10.2, rules LR-0 to LR-4). Expected values are worked
# out by hand from the spec's formulas; the comments show the arithmetic.
describe 'Service: advisor, long-run climb mode', ->

  beforeEach module 'swarmApp'

  advisor = {}
  beforeEach inject (_advisor_) ->
    advisor = _advisor_

  D = (x) -> new Decimal x
  DAY = 86400
  ON = {longRun: 'on'}

  # A hand-built snapshot, as in advisor.coffee's spec: every chain unit defaults to count 0, cost 100
  # of the tier below, production = its tier number, twin 1, twin and faster upgrades priced out of
  # reach, no meat price. Plenty of meat. `age` is the run age in seconds.
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
      prodLevel: u.prodLevel ? 0
      prodFactor: D(u.prodFactor ? 666)
      meatCost: if u.meatCost? then D(u.meatCost) else null
      purchases: String(u.purchases ? 0)
    return {
      now: (opts.age ? 2 * DAY) * 1000
      restartedAt: 0
      larvae: D(opts.larvae ? 1e6)
      larvaRate: D(opts.larvaRate ? 0)
      meat: D(opts.meat ? 1e100)
      units: units
      energy: opts.energy ? {nexus: 0, energy: D(0), moths: D(0), next: null}
    }
  tier = (r, name) -> _.find r.tiers, (t) -> t.name == name
  pushes = (r) -> ([p.unit, p.buys.toNumber(), p.limitedBy] for p in r.longRun.pushes)
  without = (r, keys...) -> _.omit r, keys

  # Queens held (1e6) but no drones: queens pass (H = 2 x 100 / 2 = 100 s) but cannot be bought, so the
  # frontier is queen. Nests (cost 1,000 queens, 0.001 each) fail: H = 3 x 1e6 = 3e6 s > 3 x 172,800.
  base = (extra={}) -> _.extend {queen: {count: 1e6}, nest: {cost: 1000, prodEach: 1e-3}}, extra

  describe 'LR-0: from a run age of 2 days', ->
    it 'changes nothing one second before, and acts from the second itself', ->
      snap = mksnap age: 2 * DAY - 1, units: base()
      rOff = advisor.advise snap, null, {}
      rOn = advisor.advise snap, null, ON
      expect(rOn.longRun.active).toBe false
      expect(rOn.longRun.startsIn).toBe 1
      expect(rOn.longRun.pushes).toEqual []
      # everything else exactly as with the mode off, memory included
      expect(without rOn, 'longRun', 'config').toEqual without(rOff, 'config')
      expect(tier(rOn, 'nest').reason).toBe 'tooSlow'

      snap = mksnap age: 2 * DAY, units: base()
      rOn = advisor.advise snap, null, ON
      expect(rOn.longRun.active).toBe true
      expect(rOn.longRun.frontier).toBe 'queen'
      # nest is frontier + 1: 2% of the queens, 0.02 x 1e6 / 1,000 = 20
      expect(pushes rOn).toEqual [['nest', 20, 'share']]
      nest = tier rOn, 'nest'
      expect([nest.kind, nest.reason, nest.buys.toNumber()]).toEqual ['push', 'push', 20]
      expect(advisor.renderAction nest).toBe 'feed upward: hatch 20 nests (2% of your queens)'
      # and nothing at all with the mode off
      rOff = advisor.advise snap, null, {}
      expect(rOff.longRun).toBeUndefined()
      expect(tier(rOff, 'nest').reason).toBe 'tooSlow'
      expect(rOff.memory.push).toBeUndefined()

    it 'a fresh run (a new game, or just after an ascension) with the mode on is the mode off', ->
      for age in [0, 60, DAY, 2 * DAY - 0.001]
        snap = mksnap age: age, larvae: 10, units: {drone: {count: 50}}
        expect(without advisor.advise(snap, null, ON), 'longRun', 'config').toEqual without(advisor.advise(snap, null, {}), 'config')

  describe 'LR-2: the push reserve', ->
    # drones 1e12 make queens buyable without limit (affordable 1e10, share 0.5, spare 1e10), so the
    # climb takes every larva it is offered; nests are frontier + 1 (2% of 1e6 queens / 1,000 = 20).
    climbAll = (extra={}) -> base _.extend {drone: {count: 1e12}}, extra
    larvaeOf = (r) -> _.mapValues r.longRun.larvae, (v) -> v.toNumber()

    it 'sets aside floor(1%) of the larvae the climb could use: none below 100, one from 100', ->
      # 111 larvae: floor(99.9) = 99, R = floor(0.99) = 0; the climb takes all 99, the push has nothing
      r = advisor.advise mksnap(larvae: 111, units: climbAll()), null, ON
      expect(larvaeOf r).toEqual {available: 99, nexus: 0, reserve: 0, forClimb: 99, climbLeft: 0, forPush: 0}
      expect(tier(r, 'queen').buys.toNumber()).toBe 99
      expect(_.find(r.longRun.lines, unit: 'nest').outcome).toBe 'no larvae'
      # 112 larvae: floor(100.8) = 100, R = 1; the climb takes 99 and the push its 1 larva
      r = advisor.advise mksnap(larvae: 112, units: climbAll()), null, ON
      expect(larvaeOf r).toEqual {available: 100, nexus: 0, reserve: 1, forClimb: 99, climbLeft: 0, forPush: 1}
      expect(tier(r, 'queen').buys.toNumber()).toBe 99
      expect(pushes r).toEqual [['nest', 1, 'larvae']]

    it 'leaves the climb exactly as before with the mode off, or before day 2', ->
      for [cfg, age] in [[{}, 2 * DAY], [ON, 2 * DAY - 1]]
        r = advisor.advise mksnap(age: age, larvae: 112, units: climbAll()), null, cfg
        expect(tier(r, 'queen').buys.toNumber()).toBe 100

    it 'starts the push with the reserve plus what the climb left', ->
      # no drones: the climb buys nothing; 1e6 larvae => A = 900,000, R = 9,000, the climb leaves 891,000
      r = advisor.advise mksnap(units: base()), null, ON
      expect(larvaeOf r).toEqual {available: 900000, nexus: 0, reserve: 9000, forClimb: 891000, climbLeft: 891000, forPush: 900000}

    it 'counts the units the climb suggests this visit in the tier below a push line', ->
      # queens x4 twins, nests cost 100 queens. 1e6 larvae: R = 9,000 and the climb takes the other 891,000
      # for queens, so the nest line works on the queens held once those are bought (as the simulator does)
      r = advisor.advise mksnap(units: climbAll(queen: {count: 1e6, twin: 4}, nest: {cost: 100, prodEach: 1e-5})), null, ON
      expect(tier(r, 'queen').buys.toNumber()).toBe 891000
      line = _.find r.longRun.lines, unit: 'nest'
      # 1e6 + 891,000 x 4 = 4,564,000 queens; 2% / 100 = 912.8 => 912
      expect(line.belowCount.toNumber()).toBe 4564000
      expect(pushes r).toEqual [['nest', 912, 'share']]

    it 'takes a cooling-down tier\'s earmark out of the climb\'s share, not the reserve', ->
      r = advisor.advise mksnap(units: climbAll()), null, ON
      expect(tier(r, 'queen').buys.toNumber()).toBe 891000
      # bought 1 s later: the queens cool down; their earmark min(891,000, 1e10 x 0.5) is all of A - R
      snap = mksnap units: climbAll(queen: {count: 1e6, purchases: 891000})
      snap.now += 1000
      r = advisor.advise snap, r.memory, ON
      expect(tier(r, 'queen').reason).toBe 'cooldown'
      expect(tier(r, 'queen').earmarked.toNumber()).toBe 891000
      expect(larvaeOf r).toEqual {available: 900000, nexus: 0, reserve: 9000, forClimb: 891000, climbLeft: 0, forPush: 9000}
      expect(pushes r).toEqual [['nest', 20, 'share']]

    it 'takes the next nexus\'s larvae out before the reserve', ->
      # the energy line saves for nexus 5 (500,000 larvae): A = 900,000 - 500,000, R = 4,000
      energy = {nexus: 4, energy: D(1000), moths: D(4000), cap: D(5e4), next: {name: 'nexus5', level: 5, costs: [
        {unit: 'meat', val: D(1e6), have: D(1e7)}, {unit: 'energy', val: D(36000), have: D(1000)}, {unit: 'larva', val: D(500000), have: D(1e6)}]}}
      r = advisor.advise mksnap(larvaRate: 100, energy: energy, units: climbAll()), null, ON
      expect(r.energy.type).toBe 'save'
      expect(larvaeOf r).toEqual {available: 400000, nexus: 500000, reserve: 4000, forClimb: 396000, climbLeft: 0, forPush: 4000}
      expect(tier(r, 'queen').buys.toNumber()).toBe 396000

  describe 'LR-2: feeding upward', ->
    # greaterqueens (cost 100 nests) fail too: H = 4 x 100 / 1e-6
    two = (extra={}) -> base _.extend {nest: {count: 1e4, cost: 1000, prodEach: 1e-3}, greaterqueen: {prodEach: 1e-6}}, extra

    it 'half the tier below from frontier + 2, 2% for frontier + 1, top-down', ->
      r = advisor.advise mksnap(units: two()), null, ON
      expect(r.longRun.frontier).toBe 'queen'
      # greaterqueen: 0.5 x 1e4 / 100 = 50; nest: 0.02 x 1e6 / 1,000 = 20; hive: no greaterqueens held
      expect(pushes r).toEqual [['greaterqueen', 50, 'share'], ['nest', 20, 'share']]
      expect(advisor.renderAction tier r, 'greaterqueen').toBe 'feed upward: hatch 50 greaterqueens (half your nests)'

    it 'is capped by the larvae left after territory, the top tier first', ->
      # 40 larvae, territory 0.1: floor(36). greaterqueen takes all 36; none left for nests
      r = advisor.advise mksnap(larvae: 40, units: two()), null, ON
      expect(pushes r).toEqual [['greaterqueen', 36, 'larvae']]
      expect(tier(r, 'nest').reason).toBe 'tooSlow'
      expect(advisor.renderAction tier r, 'greaterqueen').toBe 'feed upward: hatch 36 greaterqueens (all larvae left)'

    it 'takes only the larvae the climbing tiers left', ->
      # drones 1e4 make queens buyable: affordable 100, share 0.5 => 50, spare 100 => queens take 50 of
      # floor(1e6 x 0.9) = 900,000
      r = advisor.advise mksnap(larvae: 1e6, units: two(drone: {count: 1e4})), null, ON
      expect(tier(r, 'queen').buys.toNumber()).toBe 50
      # with 75 larvae: floor(67.5) = 67, queens 50, 17 left for greaterqueens
      r = advisor.advise mksnap(larvae: 75, units: two(drone: {count: 1e4})), null, ON
      expect(pushes r).toEqual [['greaterqueen', 17, 'larvae']]

    it 'is capped by half the meat left after climbing', ->
      # queens take 50 at 10 meat each: 650 - 500 = 150; greaterqueens at 2 meat: 0.5 x 150 / 2 = 37.5 => 37;
      # then 150 - 74 = 76 left, nests at 1 meat: 0.5 x 76 = 38 > 20 => 20 by share
      units = two drone: {count: 1e4}, queen: {count: 1e6, meatCost: 10}, greaterqueen: {prodEach: 1e-6, meatCost: 2}
      units.nest.meatCost = 1
      r = advisor.advise mksnap(meat: 650, units: units), null, ON
      expect(pushes r).toEqual [['greaterqueen', 37, 'meat'], ['nest', 20, 'share']]
      expect(advisor.renderAction tier r, 'greaterqueen').toBe 'feed upward: hatch 37 greaterqueens (half your meat)'

    it 'records every tier it looked at, with the reason for no line', ->
      r = advisor.advise mksnap(units: base()), null, ON
      # from endless down to frontier + 1 (nest): nothing below everywhere but on nest
      expect(r.longRun.lines.length).toBe 18
      expect(_.uniq(_.map r.longRun.lines.slice(0, 17), 'outcome')).toEqual ['nothing below']
      expect(_.last(r.longRun.lines).outcome).toBe 'hatch'

    it 'computes a line from its inputs as the simulator does (first term on a tie)', ->
      # share 0.5 x 10 / 1 = 5, larvae 5, meat 1e9 / 2 / 1 => tie between share and larvae: share
      expect(_.values(advisor.pushLine 0.5, D(10), D(1), D(5), D(1e9), D(1))).toEqual [D(5), 'share']
      expect(advisor.pushLine(0.5, D(10), D(1), D(4.9), D(1e9), D(1)).binding).toBe 'larvae'
      # meat / 2 / price = 3.5 => 3
      res = advisor.pushLine 0.02, D(1e6), D(1000), D(1e6), D(7), D(1)
      expect([res.n.toNumber(), res.binding]).toEqual [3, 'meat']

    it 'cools down for 60 s per unit after a purchase is seen', ->
      r = advisor.advise mksnap(units: base()), null, ON
      expect(pushes r).toEqual [['nest', 20, 'share']]
      bought = (secs) ->
        snap = mksnap units: base(nest: {count: 20, cost: 1000, prodEach: 1e-3, purchases: 20})
        snap.now += secs * 1000
        return snap
      r = advisor.advise bought(1), r.memory, ON
      nest = tier r, 'nest'
      expect([nest.kind, nest.reason, nest.waitSeconds]).toEqual ['wait', 'cooldown', 60]
      expect(pushes r).toEqual []
      r2 = advisor.advise bought(60.999), r.memory, ON
      expect(tier(r2, 'nest').reason).toBe 'cooldown'
      r3 = advisor.advise bought(61), r.memory, ON
      expect(pushes r3).toEqual [['nest', 20, 'share']]

    it 'takes the frontier from owned tiers that pass, and from a tier being bought this visit', ->
      # no drones: queens cannot be bought, none held => the frontier is drone; nothing to feed
      r = advisor.advise mksnap(units: {nest: {cost: 1000, prodEach: 1e-3}}), null, ON
      expect(r.longRun.frontier).toBe 'drone'
      # drones held: queens (none held) pass and are bought, so they are the frontier
      r = advisor.advise mksnap(units: {drone: {count: 1e4}, nest: {cost: 1000, prodEach: 1e-3}}), null, ON
      expect(tier(r, 'queen').kind).toBe 'buy'
      expect(r.longRun.frontier).toBe 'queen'

    it 'lists the empty tiers above the table, up to endless, in the result', ->
      r = advisor.advise mksnap(units: base()), null, ON
      # top owned: queen => listed up to greaterqueen; hive to overmind6 above
      expect(_.last(r.tiers).name).toBe 'greaterqueen'
      expect(r.longRun.above[0]).toBe 'hive'
      expect(_.last r.longRun.above).toBe 'overmind6'
      expect(r.longRun.above.length).toBe 16

  describe 'LR-3: twins paid in a pushed tier', ->
    # queens climb (drones 1e4) and are the frontier; their twin costs 10 nests; nests are pushed.
    twinSnap = (nests) ->
      # (greaterqueens fail too, so the nests held do not make them the frontier)
      mksnap larvaRate: 100, units: {drone: {count: 1e4}, queen: {count: 1e6, twinCost: 10}, nest: {count: nests, cost: 1000, prodEach: 1e-3}, greaterqueen: {prodEach: 1e-6}}
    twinTip = (r) -> _.find r.tips, type: 'twin'

    it 'are suggested only from 1e6 x their price held', ->
      expect(twinTip(advisor.advise twinSnap(1e7), null, ON).cost.toNumber()).toBe 10
      r = advisor.advise twinSnap(1e7 - 1), null, ON
      expect(twinTip r).toBeUndefined()
      expect(r.longRun.suppressed[0].need.toNumber()).toBe 1e7
      # the mode off: as always
      expect(twinTip(advisor.advise twinSnap(1e7 - 1), null, {}).cost.toNumber()).toBe 10

  describe 'LR-4: lepidoptera 30,000 from day 3', ->
    energy = -> {nexus: 5, energy: D(1e5), moths: D(4000), next: null, cap: D(1e6)}

    it 'raises the target from a run age of 3 days, and says so', ->
      r = advisor.advise mksnap(age: 3 * DAY - 1, energy: energy()), null, ON
      expect(advisor.renderEnergy r.energy).toBe 'cast House of Mirrors x40'
      expect(r.longRun.mothsRaised).toBe false
      r = advisor.advise mksnap(age: 3 * DAY, energy: energy()), null, ON
      # min(30,000 - 4,000, 1e5 / 10) = 10,000
      expect([r.energy.type, r.energy.count.toNumber(), r.energy.target, r.energy.longRun, r.energy.setting]).toEqual ['buyMoths', 10000, 30000, true, 4000]
      expect(advisor.renderEnergy r.energy).toBe 'buy 10,000 lepidoptera (lepidoptera 4,000/30,000, long-run target)'
      expect(r.longRun.mothsRaised).toBe true

    it 'never lowers a higher setting, and does nothing with the mode off', ->
      r = advisor.advise mksnap(age: 3 * DAY, energy: energy()), null, _.extend({moths: 40000}, ON)
      expect(r.energy.target).toBe 40000
      expect(r.energy.longRun).toBeUndefined()
      expect(advisor.renderEnergy advisor.advise(mksnap(age: 3 * DAY, energy: energy()), null, {}).energy).toBe 'cast House of Mirrors x40'

  describe 'the setting', ->
    it 'is off by default and stored with the other advisor settings', inject (options) ->
      expect(options.advisorSetting 'longRun').toBe 'off'
      expect(options.advisorSetting 'longRun', 'on').toBe 'on'
      expect(options.session.state.options.advisor.longRun).toBe 'on'
      expect(-> options.advisorSetting 'longRun', true).toThrow()
      options.session.state.options.advisor.longRun = 'yes'
      expect(options.advisorSetting 'longRun').toBe 'off'
      options.advisorSetting 'longRun', 'on'
      options.resetAdvisorConfig()
      expect(options.advisorSetting 'longRun').toBe 'off'

    it 'keeps the memory of a run in the same shape as without the mode', ->
      r = advisor.advise mksnap(units: base()), null, ON
      expect(_.keys(r.memory).sort()).toEqual ['boughtAt', 'restartedAt', 'seen', 'startedAt', 'stockAt']

describe 'Service: advisor, long-run climb mode on a real save', ->

  beforeEach module 'swarmApp'

  advisor = Game = session = null
  beforeEach inject (_advisor_, _Game_, _session_) ->
    advisor = _advisor_
    Game = _Game_
    session = _session_

  # The 20.1 h save (advisor/sim/example_save_20h.json), loaded as in advisorascension.coffee's spec.
  fetchSave = ->
    files = window.__karma__?.files ? {}
    url = _.find _.keys(files), (f) -> /advisor\/sim\/example_save_20h\.json$/.test f
    xhr = new XMLHttpRequest()
    xhr.open 'GET', url, false
    xhr.send()
    return JSON.parse xhr.responseText
  loadGame = (ago=3600e3) ->
    state = session._loads session._saves fetchSave(), false
    shift = (new Date().getTime() - ago) - state.date.reified.getTime()
    for key, date of state.date
      state.date[key] = new Date date.getTime() + shift
    game = new Game {state: state, save: ->}
    game.now = new Date state.date.reified.getTime()
    game.cache.onUpdate()
    return game
  ON = {longRun: 'on'}
  without = (r, keys...) -> _.omit r, keys

  it 'changes nothing on the save itself (run age 20.1 h)', ->
    snap = advisor.snapshot loadGame()
    rOn = advisor.advise snap, null, ON
    expect(rOn.longRun.active).toBe false
    expect(rOn.longRun.startsIn).toBeCloseTo 2 * 86400 - rOn.age, 6
    expect(without rOn, 'longRun', 'config').toEqual without(advisor.advise(snap, null, {}), 'config')

  it 'feeds hive queens once the run is past 2 days, aged by the game clock', ->
    # saved 2 days ago, so the game can tick forward 1.2 days without passing the real clock
    game = loadGame 2 * 86400e3
    game.tick new Date(game.now.getTime() + 1.2 * 86400e3)
    snap = advisor.snapshot game
    rOn = advisor.advise snap, null, ON
    expect(rOn.age).toBeGreaterThan 2 * 86400
    expect(rOn.longRun.active).toBe true
    # hives pass and are bought; hive queens (H 11.6 d against a horizon of 6.1 d) do not, and LR-1 finds
    # no level (a faster level costs far more than the hive queens a purchase gets)
    expect(rOn.longRun.frontier).toBe 'hive'
    # 2% of the hives, counting those the climb suggests this visit (bought before the push is worked
    # out, as the simulator does), / 1e6 hives per hive queen
    hiveRow = _.find rOn.tiers, name: 'hive'
    expect(hiveRow.kind).toBe 'buy'
    hives = _.find(snap.units, name: 'hive').count.plus hiveRow.buys.times(hiveRow.twin)
    hq = _.find snap.units, name: 'hivequeen'
    expected = hives.times(0.02).dividedBy(hq.cost).floor()
    expect(expected.toNumber()).toBeGreaterThan 0
    expect(([p.unit, p.buys.toString()] for p in rOn.longRun.pushes)).toEqual [['hivequeen', expected.toString()]]
    rOff = advisor.advise snap, null, {}
    expect(_.find(rOff.tiers, name: 'hivequeen').reason).toBe 'tooSlow'
