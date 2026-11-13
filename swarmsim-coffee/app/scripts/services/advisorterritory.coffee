'use strict'

###*
 # @ngdoc service
 # @name swarmApp.advisorTerritory
 # @description
 # Territory advice for the climbing advisor: which territory unit to hatch and how many, which
 # territory twin upgrades to buy, and when to buy hatcheries, expansions and accomplished ancestry.
 #
 # A port of the territory part of the simulator's policy (advisor/sim/sim.py, `policy()`, sections
 # "larva multipliers" and "territory", with advisor/sim/policy.json: f=0.1, g=0.9, terr='balanced',
 # tt_secs=600). Same design as the `advisor` service: `snapshot()` is the only place live game objects
 # are read; `advise()` is a pure function of that plain snapshot, a small remembered state
 # (`createMemory()`, returned updated by `advise()`) and the settings.
 #
 # Translations from the simulator, which acts once a minute with a remembered territory "purse":
 # - The purse (f x larvae gained since the last check-in, kept until spent) starts as the share of the
 #   larvae on hand that the meat advice leaves unspent, floor(larvae) - floor(larvae x (1 - share)),
 #   then refills with the share of the larva income and goes down by what is spent on territory,
 #   never holding more than that share of the larvae on hand (see `updatePurse`).
 # - Fractional purchases are floored, as the simulator floors them before buying.
 # - Only units and upgrades the game shows (isVisible) are considered; the simulator has all 11.
###
angular.module('swarmApp').factory 'advisorTerritory', (game, advisor, $rootScope) ->
  ZERO = new Decimal 0
  ONE = new Decimal 1
  D = (x) -> new Decimal(if x? then x else 0)

  UNITS = ['swarmling', 'stinger', 'spider', 'mosquito', 'locust', 'roach', 'giantspider',
    'centipede', 'wasp', 'devourer', 'goon']
  # Larva multipliers, in the order sim.py's loop tries them each pass: ancestry, expansion, hatchery.
  LARVA_UPGRADES = ['achievementbonus', 'expansion', 'hatchery']
  # policy.json "g": territory units may spend this fraction of the meat on hand.
  MEAT_SHARE = 0.9
  # policy.json "tt_secs": buy a territory twin when its larva price is under this many seconds of the
  # territory share's larva income (lam x f). The handoff's "about a minute of total larva income" is
  # the same thing at f = 0.1; the tuned value is 600, applied to the territory share as sim.py does.
  TWIN_SECS = 600
  MAX_PASSES = 10000 # guard for the upgrade loop; every pass buys a level whose price grows geometrically

  withDefaults = (cfg={}) ->
    ret = {}
    for key, val of advisor.DEFAULTS
      ret[key] = if cfg[key]? then cfg[key] else val
    return ret

  costsOf = (up) ->
    ({unit: c.unit.name, val: D(c.val), factor: D(c.factor)} for c in up.totalCost())

  # ---------------------------------------------------------------------------
  # Snapshot: everything the rules read from the game, as plain data.

  snapshot = (g=game, now) ->
    now ?= if g.now? then g.now.getTime() else new Date().getTime()
    units = for name, j in UNITS
      unit = g.unit name
      twinUp = g.upgrade name + 'twin'
      cost = {}
      for c in unit.eachCost()
        cost[c.unit.name] = D c.val
      tcost = {}
      tfactor = {}
      for c in twinUp.totalCost()
        tcost[c.unit.name] = D c.val
        tfactor[c.unit.name] = D c.factor
      name: name
      label: unit.unittype.plural # as the game shows it, e.g. 'arachnomorphs' for spider
      label1: unit.unittype.label # singular
      tier: j # 0 = swarmling, as sim.py's TN index
      visible: unit.isVisible()
      count: D unit.count()
      # times hatched (larvae spent, before twins), from the game's statistics: buying through the
      # hatch button and the buy-max buttons both add to it; House of Mirrors does not
      purchases: String(unit.statistics().num ? 0)
      twin: D unit.twinMult() # units per larva
      meat: cost.meat # meat per larva, with any cost modifiers
      prodEach: D unit.eachProduction().territory
      twinUpgrade:
        name: twinUp.name
        label: twinUp.type.label
        level: twinUp.count().toNumber()
        visible: twinUp.isVisible()
        larvae: tcost.larva
        larvaFactor: tfactor.larva # price growth per level
        meatFactor: tfactor.meat
        meat: tcost.meat
    upgrades = for name in LARVA_UPGRADES
      up = g.upgrade name
      name: name
      label: up.type.label
      level: up.count().toNumber()
      maxLevel: up.type.maxlevel or null
      visible: up.isVisible()
      costs: costsOf up
    dates = g.session.state.date
    return {
      now: now
      restartedAt: new Date(dates.restarted or dates.started).getTime()
      larvae: D g.unit('larva').count()
      larvaRate: D g.unit('larva').velocity()
      meat: D g.unit('meat').count()
      territory: D g.unit('territory').count()
      # House of Mirrors casts this run: spells are upgrades whose level counts casts, and ascending
      # resets every upgrade outside the mutagen tab (game.coffee, ascend()).
      mirrorCasts: g.upgrade('clonearmy').count().toNumber()
      units: units
      upgrades: upgrades
    }

  # ---------------------------------------------------------------------------
  # Remembered state, one per run: the territory purchase statistics and twin levels (with the twin
  # prices) last seen, when the advice was last worked out, the territory purse in larvae, and the
  # meat spent on territory since the purse was last empty.

  createMemory = (now, restartedAt) ->
    restartedAt: restartedAt
    seen: {}
    prices: {}
    at: null
    purse: null # null until the first advice: the purse then starts as the share of the larvae on hand
    meatSpent: ZERO

  copyMemory = (memory, now, restartedAt) ->
    if not memory? or (memory.restartedAt? and restartedAt? and memory.restartedAt != restartedAt)
      return createMemory now, restartedAt
    ret = createMemory now, (if memory.restartedAt? then memory.restartedAt else restartedAt)
    for own key, val of memory.seen
      ret.seen[key] = val
    for own key, val of memory.prices ? {}
      ret.prices[key] = val
    ret.at = memory.at ? null
    ret.purse = memory.purse ? null
    ret.meatSpent = memory.meatSpent ? ZERO
    return ret

  # What was spent on territory since the last call, from the units' purchase statistics (larvae
  # spent, before twins) and the twin upgrades' levels, never from unit counts, which House of Mirrors
  # doubles. The first sighting of a value is not a purchase. Mutates `mem`; returns {larvae, meat}.
  seePurchases = (mem, snap) ->
    larvae = ZERO
    meat = ZERO
    for u in snap.units
      prev = mem.seen[u.name]
      if prev? and prev isnt u.purchases
        n = Decimal.max 0, D(u.purchases).minus(prev)
        larvae = larvae.plus n
        meat = meat.plus n.times(u.meat)
      mem.seen[u.name] = u.purchases
      t = u.twinUpgrade
      prev = mem.seen[t.name]
      price = mem.prices[t.name]
      if prev? and price? and t.level > prev
        # the price of each level bought, from the price last seen
        for i in [0...t.level - prev]
          larvae = larvae.plus price.larvae.times(Decimal.pow t.larvaFactor, i)
          meat = meat.plus price.meat.times(Decimal.pow t.meatFactor, i)
      mem.seen[t.name] = t.level
      mem.prices[t.name] = {larvae: t.larvae, meat: t.meat}
    return {larvae: larvae, meat: meat}

  # Live translation of sim.py's territory purse. The simulator adds f x the larvae gained since the
  # last check-in, takes out what it spends on territory, and keeps the rest. Live, the purse starts
  # as the share of the larvae on hand (page load, new run, import), refills at share x larva income,
  # goes down by the larvae actually spent on territory units and twins, never below zero, and never
  # holds more than the share of the larvae on hand. So after one line of a two-line suggestion is
  # bought, the other is still there; after both, it is empty and refills; and repeated hatching
  # cannot spend more than the share. Mutates `mem`.
  #
  # Meat is kept consistent with it: the meat budget is MEAT_SHARE x (meat + meat spent on territory
  # this cycle) - meat spent this cycle, never below zero. A cycle ends whenever the purse holds less
  # than one larva (the suggestion was used up, larvae were spent elsewhere, or a twin took it all),
  # or the memory starts afresh. Within a cycle, buying one line of the plan leaves exactly the rest
  # of it, and territory takes at most MEAT_SHARE of the meat there would be without it.
  updatePurse = (mem, snap, share, spent) ->
    cap = snap.larvae.floor().minus snap.larvae.times(1 - share).floor()
    rate = snap.larvaRate.times share
    if not mem.purse?
      mem.purse = cap
      mem.meatSpent = ZERO
    else
      dt = Math.max 0, (snap.now - mem.at) / 1000
      mem.purse = Decimal.min cap, Decimal.max(0, mem.purse.plus(rate.times dt).minus(spent.larvae))
      mem.meatSpent = mem.meatSpent.plus spent.meat
    mem.at = snap.now
    if mem.purse.lessThan 1
      mem.meatSpent = ZERO
    budget = mem.purse.floor()
    refill = null
    if budget.lessThan(1) and cap.greaterThanOrEqualTo(1)
      refill =
        type: 'idle'
        reason: 'refilling'
        purse: mem.purse
        rate: rate # territory larvae per second
        # seconds until the purse holds one larva (null with no larva income)
        seconds: if rate.greaterThan(0) then ONE.minus(mem.purse).dividedBy(rate).toNumber() else null
    return {budget: budget, refill: refill}

  # ---------------------------------------------------------------------------
  # Rules.

  # sim.py policy(), "larva multipliers": repeat passes of ancestry, expansion, hatchery, buying each
  # one level whenever its whole price is on hand, until a pass buys nothing. Returns one record per
  # upgrade bought, in the order first bought, and what is left of each resource.
  larvaUpgrades = (snap) ->
    have = {meat: snap.meat, territory: snap.territory}
    state = for up in snap.upgrades
      up: up
      level: up.level
      costs: ({unit: c.unit, val: c.val, factor: c.factor} for c in up.costs)
      spent: {}
      levels: 0
    order = []
    for pass in [0...MAX_PASSES]
      bought = false
      for s in state
        if not s.up.visible or (s.up.maxLevel? and s.level >= s.up.maxLevel)
          continue
        if not _.every(s.costs, (c) -> have[c.unit]? and have[c.unit].greaterThanOrEqualTo(c.val))
          continue
        for c in s.costs
          have[c.unit] = have[c.unit].minus c.val
          s.spent[c.unit] = (s.spent[c.unit] or ZERO).plus c.val
          c.val = c.val.times c.factor
        s.level += 1
        s.levels += 1
        if s.levels == 1
          order.push s
        bought = true
      if not bought
        break
    records = for s in order
      type: 'upgrade'
      name: s.up.name
      label: s.up.label
      levels: s.levels
      from: s.up.level
      costs: ({unit: c.unit, val: s.spent[c.unit]} for c in s.up.costs)
    return {records: records, meat: have.meat, territory: have.territory}

  # sim.py policy(), "territory", with terr='balanced'. `budget` is the territory larvae, `meatBudget`
  # the meat they may use. Returns {twin, hatch: [records], idle}.
  territoryUnits = (snap, share, budget, meatBudget) ->
    vis = (u for u in snap.units when u.visible)
    if not vis.length
      return {twin: null, hatch: [], idle: {type: 'idle', reason: 'locked'}}
    # The biggest unit all the territory larvae could go into within the meat budget (max(L, 1) as
    # sim.py), else the smallest shown unit.
    top = 0
    for u, i in vis
      if u.meat.times(Decimal.max budget, 1).lessThanOrEqualTo meatBudget
        top = i
    unit = vis[top]
    next = vis[top + 1] ? null

    # Twin for that unit, else for the next one up: the first whose larva price is under TWIN_SECS of
    # the territory share's larva income, and whose meat price and unit price fit the meat budget.
    #
    # Deliberate departure from sim.py: there the twin is paid from the territory purse, which builds up
    # over check-ins while it saves. Live play has no such purse: the territory budget is the share of
    # the larvae on hand and the meat advice spends the rest, so a twin priced near the limit could never
    # be reached and the advice would save for it forever. So the twin counts as affordable when ALL the
    # larvae on hand cover it (meat as in sim.py). Its larvae come first out of the territory budget; the
    # part beyond it (`overcommit`) is larvae the meat advice is also counting on this visit, which is
    # acceptable since both re-read the game every second. Only when the larvae on hand fall short is
    # the advice to save for it, hatching nothing meanwhile as sim.py does; that is short-lived, as the
    # price is at most TWIN_SECS x share of larva income (about a minute of it at share 0.1).
    twin = null
    onHand = snap.larvae.floor()
    limit = snap.larvaRate.times(share).times(TWIN_SECS)
    for u in (if next? then [unit, next] else [unit])
      t = u.twinUpgrade
      if not t.visible
        continue
      if t.larvae.lessThanOrEqualTo(limit) and t.meat.lessThanOrEqualTo(meatBudget) and u.meat.lessThanOrEqualTo(meatBudget)
        twin =
          type: if onHand.greaterThanOrEqualTo(t.larvae) then 'twin' else 'saveForTwin'
          unit: u.name
          unitLabel: u.label
          name: t.name
          label: t.label
          level: t.level
          larvae: t.larvae
          meat: t.meat
          have: onHand # all larvae on hand
          budget: budget # the territory share of them
          overcommit: Decimal.max 0, t.larvae.minus(budget) # larvae taken beyond the territory share
          limit: limit
          seconds: if snap.larvaRate.greaterThan(0) then t.larvae.dividedBy(snap.larvaRate).toNumber() else null
        break
    if twin?.type == 'saveForTwin'
      return {twin: twin, hatch: [], idle: null}
    if twin?
      budget = Decimal.max 0, budget.minus(twin.larvae)
      meatBudget = meatBudget.minus twin.meat
      # the units bought below come out twinned at the new level
      if twin.unit == unit.name
        unit = _.extend {}, unit, twin: unit.twin.times(2)
      else
        next = _.extend {}, next, twin: next.twin.times(2)

    if budget.lessThan 1
      return {twin: twin, hatch: [], idle: (if twin? then null else {type: 'idle', reason: 'noLarvae', larvae: budget})}
    # All into `unit`, except that the meat left over beyond that goes to the next unit up.
    if next? and next.meat.lessThanOrEqualTo meatBudget
      y = Decimal.max(0, Decimal.min(budget, meatBudget.minus(budget.times unit.meat).dividedBy(next.meat.minus unit.meat)))
      # sim.py buys x = L - y here even when the meat cannot pay for them (only possible when even the
      # smallest unit is too dear for all the larvae; its meat then goes negative). Cap x by the meat.
      x = Decimal.min budget.minus(y), meatBudget.minus(y.times next.meat).dividedBy(unit.meat)
      buys = [[unit, x, 'main'], [next, y, 'spare']]
    else
      buys = [[unit, Decimal.min(budget, meatBudget.dividedBy unit.meat), 'main']]
    hatch = []
    for [u, n, role] in buys
      n = n.floor()
      if n.lessThan 1
        continue
      hatch.push
        type: 'hatch'
        unit: u.name
        label: u.label
        role: role
        buys: n                # larvae used: what goes in the game's buy box
        twin: u.twin           # units per larva
        units: n.times u.twin
        meat: n.times u.meat
    idle = if hatch.length or twin? then null else {type: 'idle', reason: 'noMeat', meat: meatBudget, cost: unit.meat, unit: unit.name, label: unit.label1}
    return {twin: twin, hatch: hatch, idle: idle}

  # Territory advice for a snapshot, the remembered state and the advisor settings (only `territory`,
  # the larva share, is read). Returns the advice with the updated memory as `memory`; the inputs are
  # not modified.
  advise = (snap, memory, cfg) ->
    cfg = withDefaults cfg
    share = cfg.territory
    mirrors = snap.mirrorCasts > 0
    mem = copyMemory memory, snap.now, snap.restartedAt
    purse = updatePurse mem, snap, share, seePurchases(mem, snap)
    budget = purse.budget

    up = larvaUpgrades snap
    meatBudget = Decimal.max 0, up.meat.plus(mem.meatSpent).times(MEAT_SHARE).minus(mem.meatSpent)

    status = null
    setting = null
    twin = null
    hatch = []
    if mirrors
      # Once House of Mirrors is being cast, territory units only matter through the mirrors' doubling:
      # hatch none, and stop holding larvae back for them.
      status = {type: 'mirrors', casts: snap.mirrorCasts}
      if share > 0
        setting = {type: 'setShare', share: share, to: 0}
    else if not (share > 0)
      status = {type: 'idle', reason: 'shareZero'}
    else
      res = territoryUnits snap, share, budget, meatBudget
      twin = res.twin
      hatch = res.hatch
      status = res.idle
      # nothing to hatch because the purse is still refilling after a purchase: say so
      if status?.reason == 'noLarvae' and purse.refill?
        status = purse.refill

    records = []
    if setting?
      records.push setting
    if status?.type == 'mirrors'
      records.push status
    Array::push.apply records, up.records
    if twin?
      records.push twin
    Array::push.apply records, hatch
    if status? and status.type != 'mirrors'
      records.push status
    return {
      now: snap.now
      share: share
      mirrors: mirrors
      larvae: budget
      meatBudget: meatBudget
      upgrades: up.records
      twin: twin
      hatch: hatch
      status: status
      setting: setting
      records: records
      config: cfg
      memory: mem
    }

  # ---------------------------------------------------------------------------
  # Plain-text rendering, in the voice of the advisor's other lines.

  fmt = advisor.formatNumber

  larvaText = (n) -> fmt(n) + (if n.equals(1) then ' larva' else ' larvae')

  renderCosts = (costs) ->
    ((if c.unit == 'larva' then larvaText(c.val) else fmt(c.val) + ' ' + c.unit) for c in costs).join(', ')

  render = (rec) ->
    if not rec?
      return null
    switch rec.type
      when 'upgrade' then 'buy ' + rec.label + (if rec.levels > 1 then ' x' + rec.levels else '') + ' (' + renderCosts(rec.costs) + ')'
      when 'twin' then 'buy ' + rec.label + ' (' + larvaText(rec.larvae) + ', ' + fmt(rec.meat) + ' meat)'
      when 'saveForTwin' then 'save larvae for ' + rec.label + ': ' + fmt(rec.have) + '/' + fmt(rec.larvae)
      when 'hatch' then 'hatch ' + fmt(rec.buys) + ' ' + rec.label + (if rec.twin.greaterThan(1) then ' (x' + fmt(rec.twin) + ' twins)' else '')
      when 'mirrors' then 'House of Mirrors is running: hatch no more territory units'
      when 'setShare' then 'set the territory share to ' + rec.to + ' (now ' + rec.share + ')'
      when 'idle'
        switch rec.reason
          when 'locked' then 'no territory units yet'
          when 'shareZero' then 'territory share is 0: no territory units'
          when 'noLarvae' then 'no larvae left for territory'
          when 'refilling'
            'territory larvae spent for now' + (if rec.seconds? then ', more in ' + advisor.formatTime(Math.max 1, Math.ceil rec.seconds) else '')
          when 'noMeat' then 'need ' + fmt(rec.cost) + ' meat per ' + rec.label + ' (can spend ' + fmt(rec.meat) + ')'
          else ''
      else ''

  # ---------------------------------------------------------------------------
  # Live wiring.

  liveMemory = null
  cached = null

  svc = {
    UNITS: UNITS
    LARVA_UPGRADES: LARVA_UPGRADES
    MEAT_SHARE: MEAT_SHARE
    TWIN_SECS: TWIN_SECS
    # pure
    snapshot: snapshot
    createMemory: createMemory
    advise: advise
    render: render
    # live
    update: (now) ->
      result = advise snapshot(game, now), liveMemory, advisor.config()
      liveMemory = result.memory
      return result
    memory: -> liveMemory
    resetMemory: ->
      liveMemory = null
      cached = null
    # The latest advice, re-running `update()` only when the cached result is at least `maxAgeMs`
    # old. Never throws: returns {at, advice, error}, as `advisor.current()`.
    current: (maxAgeMs=1000, wallNow=Date.now()) ->
      if not cached? or wallNow - cached.at >= maxAgeMs or wallNow < cached.at
        try
          cached = {at: wallNow, advice: svc.update(), error: null}
        catch e
          cached = {at: wallNow, advice: null, error: e}
      return cached
    invalidate: -> cached = null
  }
  # A different save (imported, or the game reset) starts a fresh memory, as the meat advice's does.
  $rootScope.$on 'import', (event, args) ->
    if args?.success
      svc.resetMemory()
  $rootScope.$on 'reset', -> svc.resetMemory()
  # After any purchase through the game's buttons, advise afresh at the next call instead of serving
  # advice cached from before it for up to a second (which would offer the bought share again).
  $rootScope.$on 'command', -> cached = null
  return svc
