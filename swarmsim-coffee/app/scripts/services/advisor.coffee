'use strict'

# Settings for the climbing advisor: defaults and the range each one is clamped to.
# `options` stores them with the save; the advisor reads them through `options`.
angular.module('swarmApp').constant 'ADVISOR_SETTINGS',
  defaults:
    ageMultiple: 3    # climb tiers whose break-even H is under this many x run age
    share: 0.5        # fraction of the lower tier to convert per minute waited
    cooldown: 60      # seconds after hatching a unit before it is suggested again
    bank: 3           # stop hatching a unit once the tier above makes this many x what larvae could
    territory: 0.10   # fraction of larvae held back for territory units
    moths: 4000       # lepidoptera target
    spareEnergy: 'larvarush' # below nexus 5, spare energy: 'larvarush' casts it, 'save' holds it for the next nexus
    ascension: 'off'  # ascension advice (advisorascension.coffee): 'off', or 'achievements' for ASCENSION.md's route
    longRun: 'off'    # long-run climb mode (ASCENSION.md A.10): 'on' adds rules LR-1 to LR-4 from a run age of 2 days
  limits:
    ageMultiple: {min: 0.01, max: 1000}
    share: {min: 0.01, max: 1}
    cooldown: {min: 0, max: 86400}
    bank: {min: 0, max: 1e6}
    territory: {min: 0, max: 0.95}
    moths: {min: 0, max: 1e12, integer: true}
    spareEnergy: {choices: ['larvarush', 'save']} # a choice, not a number
    ascension: {choices: ['off', 'achievements']}
    longRun: {choices: ['off', 'on']}

###*
 # @ngdoc service
 # @name swarmApp.advisor
 # @description
 # Climbing advisor: which meat unit to hatch and how many, which faster/twin upgrades to buy, and what
 # to do with energy. A port of the `swarm-climb-live.js` console script.
 #
 # The rules are a pure function of a plain snapshot of the game (`snapshot()`), a small remembered
 # state (`createMemory()`, returned updated by `advise()`), the settings, and the snapshot's time.
 # `update()` wires those to the live game for the UI.
###
# The live advice is re-run at most this often.
angular.module('swarmApp').constant 'ADVISOR_REFRESH_MILLIS', 1000

angular.module('swarmApp').factory 'advisor', ($rootScope, game, options, ADVISOR_SETTINGS) ->
  ZERO = new Decimal 0
  ONE = new Decimal 1
  D = (x) -> new Decimal(if x? then x else 0)

  CHAIN = ['drone', 'queen', 'nest', 'greaterqueen', 'hive', 'hivequeen', 'empress',
    'prophet', 'goddess', 'pantheon', 'pantheon2', 'pantheon3', 'pantheon4', 'pantheon5',
    'overmind', 'overmind2', 'overmind3', 'overmind4', 'overmind5', 'overmind6']
  DEFAULTS = ADVISOR_SETTINGS.defaults
  NEXUS_LARVA_SECS = 20000 # save for the next nexus once its larva price is under this many seconds of larvae
  MOTH_ENERGY = 10
  # Long-run climb mode (ASCENSION.md A.10.2), all of it gated on the setting and the run age.
  LR =
    age: 2 * 86400        # LR-0: the mode acts from this run age (s)
    mothAge: 3 * 86400    # LR-4: the raised lepidoptera target from this run age (s)
    moths: 30000          # LR-4: the raised target (the setting, if higher, stays)
    maxLevels: 400        # LR-1: most faster levels tried, as sim.py's faster_levels
    share: 0.5            # LR-2: share of the tier below, tiers frontier + 2 and up
    frontierShare: 0.02   # LR-2: share of the tier below for the tier just above the frontier
    meatShare: 0.5        # LR-2: at most this share of the meat left
    twinGuard: 1e6        # LR-3: a twin paid in a pushed tier needs this many times its price held
  SPELLS =
    larvarush: {spell: 'larvarush', label: 'larva rush', cost: 1600}
    clonearmy: {spell: 'clonearmy', label: 'House of Mirrors', cost: 2500}

  withDefaults = (cfg={}) ->
    ret = {}
    for key, val of DEFAULTS
      ret[key] = if cfg[key]? then cfg[key] else val
    return ret

  copyMap = (obj) ->
    ret = {}
    for own key, val of obj ? {}
      ret[key] = val
    return ret

  # ---------------------------------------------------------------------------
  # Text formatting, as the console script does it.

  # Whole numbers with thousands separators below a million, else 1.23e45.
  # (The script used toLocaleString; this is the en-US output on every browser.)
  formatNumber = (d) ->
    d = D d
    if d.lessThan 1e6
      n = Math.floor d.toNumber()
      sign = if n < 0 then '-' else ''
      digits = String Math.abs n
      return sign + digits.replace /\B(?=(\d{3})+(?!\d))/g, ','
    return d.toExponential(2).replace 'e+', 'e'

  formatTime = (s) ->
    s = if s?.toNumber? then s.toNumber() else Number s
    if isNaN s
      return '-'
    if s < 0
      s = 0
    if s < 90
      return s.toFixed(0) + ' s'
    if s < 5400
      return (s / 60).toFixed(0) + ' min'
    if s < 172800
      return (s / 3600).toFixed(1) + ' h'
    if s < 86400 * 730
      return (s / 86400).toFixed(1) + ' d'
    if s < 3.15e7 * 1e6
      return (s / 3.15e7).toFixed(0) + ' y'
    return 'ages'

  # ---------------------------------------------------------------------------
  # Snapshot: everything the rules read from the game, as plain data.

  snapshot = (g=game, now) ->
    now ?= if g.now? then g.now.getTime() else new Date().getTime()
    dates = g.session.state.date
    stats = (g.session.state.statistics or {}).byUnit or {}
    larva = g.unit 'larva'
    units = for name, i in CHAIN
      unit = g.unit name
      prev = if i > 0 then g.unit CHAIN[i - 1] else null
      belowName = if prev? then prev.name else 'meat'
      prodUp = g.upgrade name + 'prod'
      twinUp = g.upgrade name + 'twin'
      tcost = if twinUp then twinUp.totalCost()[0] else undefined
      name: name
      tier: i + 1
      below: belowName
      count: D unit.count()
      # cost in units of the tier below, per purchase (base cost, as the script reads it)
      cost: if prev? then D(unit.costByName[belowName].val) else null
      twin: D unit.twinMult()
      prodEach: D unit.eachProduction()[belowName]
      twinCost: if tcost then D(tcost.val) else null # twin upgrade price, in units of the tier above
      twinFactor: if tcost then D(twinUp.cost[0].factor) else ONE
      prodCost: if prodUp then D(prodUp.totalCost()[0].val) else null # faster upgrade price, in this unit
      prodLevel: if prodUp then prodUp.count().toNumber() else 0 # faster levels bought
      prodFactor: if prodUp then D(prodUp.totalCost()[0].factor) else null # price growth per faster level
      meatCost: if unit.costByName.meat? then D(unit.costByName.meat.val) else null # meat per purchase
      purchases: String(if stats[name] then stats[name].num else 0)

    # Energy is read separately, as the script did, so a failure there only loses the energy line.
    energy = null
    energyError = null
    try
      nexus = D(g.unit('nexus').count()).toNumber()
      next = null
      if nexus < 5 and (up = g.upgrade 'nexus' + (nexus + 1))
        next =
          name: up.name
          level: nexus + 1
          costs: ({unit: c.unit.name, val: D(c.val), have: D(c.unit.count())} for c in up.totalCost())
      cap = g.unit('energy').capValue()
      energy =
        cap: if cap? then D(cap) else null # as the game computes it: nexus, nightbugs, crystal energy
        nexus: nexus
        energy: D g.unit('energy').count()
        moths: D g.unit('moth').count()
        next: next
    catch e
      energyError = e

    return {
      now: now
      restartedAt: new Date(dates.restarted or dates.started).getTime()
      larvae: D larva.count()
      larvaRate: D larva.velocity()
      meat: D g.unit('meat').count()
      units: units
      energy: energy
      energyError: energyError
    }

  # ---------------------------------------------------------------------------
  # Remembered state: per unit, the purchase statistic last seen, when it last changed, and the stock
  # of the tier below at that moment.

  createMemory = (now, restartedAt) ->
    startedAt: now
    restartedAt: restartedAt
    seen: {}
    boughtAt: {}
    stockAt: {}

  # A memory belongs to one run: after an ascension (a new `restartedAt`) it starts afresh, so the
  # last run's purchase times and stock levels don't leak into the new one. (The console script
  # kept them; this is the one deliberate difference.)
  copyMemory = (memory, now, restartedAt) ->
    if not memory? or (memory.restartedAt? and restartedAt? and memory.restartedAt != restartedAt)
      return createMemory now, restartedAt
    ret =
      startedAt: if memory.startedAt? then memory.startedAt else now
      restartedAt: if memory.restartedAt? then memory.restartedAt else restartedAt
      seen: copyMap memory.seen
      boughtAt: copyMap memory.boughtAt
      stockAt: copyMap memory.stockAt
    # long-run mode only (absent otherwise): push purchase memory and faster levels promised by LR-1
    if memory.push?
      ret.push = {seen: copyMap(memory.push.seen), boughtAt: copyMap(memory.push.boughtAt)}
    if memory.lrFaster?
      ret.lrFaster = {}
      for own key, val of memory.lrFaster
        ret.lrFaster[key] = copyMap val
    return ret

  # Detect purchases from the game's own "total hatched" statistic. Mutates `mem`.
  lastBuyTime = (mem, name, total, now, cooldown) ->
    if mem.seen[name] is undefined
      mem.seen[name] = total
      mem.boughtAt[name] = mem.startedAt - cooldown * 1000 # first suggestion is available immediately
    else if mem.seen[name] isnt total
      mem.seen[name] = total
      mem.boughtAt[name] = now
      delete mem.stockAt[name] # re-measure the lower tier's stock right after this purchase
    return mem.boughtAt[name]

  # How many purchases the lower tier can spare: what it gained since this unit was last hatched, plus
  # a slice of the older stock that releases over one payback time. Mutates `mem`.
  spareBuys = (mem, x, since) ->
    if mem.stockAt[x.name] is undefined
      mem.stockAt[x.name] = x.belowCount
    base = mem.stockAt[x.name]
    gained = Decimal.max x.belowCount.minus(base), 0
    payback = x.payback.toNumber()
    release = base.times Math.min(1, if payback > 0 then since / payback else 1)
    return gained.plus(release).dividedBy(x.cost)

  # ---------------------------------------------------------------------------
  # Twin planner.

  cloneEntry = (o) ->
    name: o.name, have: o.have, twin: o.twin, cost: o.cost, twinCost: o.twinCost, twinFactor: o.twinFactor

  # Cheapest way to end up holding N of tier j, allowing detours through higher tiers:
  # "hatch some of tier j+1, buy twin j, then hatch tier j at half price", nested as deep as it pays.
  # st[j].have is spent along the way (st is mutated). Steps are appended to `steps` as
  # {type:'hatch', unit, count} or {type:'twin', unit}. Returns the final cost in units of the tier
  # below j, or null.
  acquire = (st, j, N, steps, depth) ->
    for guard in [0...80]
      t = st[j]
      need = N.minus t.have
      if need.lessThanOrEqualTo 0
        return ZERO
      hatches = need.dividedBy(t.twin).ceil()
      direct = hatches.times t.cost
      if st[j + 1] and t.twinCost and depth < 8
        trial = (cloneEntry o for o in st)
        tsteps = []
        sub = acquire trial, j + 1, trial[j].twinCost, tsteps, depth + 1 # in tier j units
        if sub isnt null and trial[j].have.greaterThanOrEqualTo(sub)
          trial[j].have = trial[j].have.minus sub
          trial[j + 1].have = trial[j + 1].have.minus trial[j].twinCost
          tsteps.push {type: 'twin', unit: t.name}
          trial[j].twin = trial[j].twin.times 2
          trial[j].twinCost = trial[j].twinCost.times trial[j].twinFactor
          via = N.minus(trial[j].have).dividedBy(trial[j].twin).ceil().times(trial[j].cost)
          if via.lessThan direct
            for q in [0...st.length]
              st[q] = trial[q]
            Array::push.apply steps, tsteps
            continue
      steps.push {type: 'hatch', unit: t.name, count: hatches}
      t.have = N
      return direct
    return null

  # ---------------------------------------------------------------------------
  # Meat-unit rules.

  # The script's compute(), on a snapshot. Returns plain data plus the updated memory; the input
  # snapshot and memory are not modified.
  advise = (snap, memory, cfg) ->
    cfg = withDefaults cfg
    now = snap.now
    mem = copyMemory memory, now, snap.restartedAt
    age = (now - snap.restartedAt) / 1000
    horizon = age * cfg.ageMultiple
    larvae = snap.larvae
    larvaRate = snap.larvaRate
    # Long-run climb mode (ASCENSION.md A.10.2): on by the setting, acting from a run age of 2 days (LR-0).
    # Everything it adds is behind `lrActive`; with it false, this function is exactly the console port.
    lrOn = cfg.longRun == 'on'
    lrActive = lrOn and age >= LR.age
    if lrActive
      mem.push ?= {seen: {}, boughtAt: {}}
      mem.lrFaster ?= {}
      seeFasterPromises mem, snap
    else
      delete mem.push
      delete mem.lrFaster

    top = 0
    for u, i in snap.units
      if u.count.greaterThanOrEqualTo 1
        top = i
    shown = Math.min top + 2, CHAIN.length - 1 # tiers listed

    # all[i - 1] describes units[i]; every tier is built so twin plans can reach upward.
    all = []
    tips = []
    for i in [1...snap.units.length]
      s = snap.units[i]
      b = snap.units[i - 1]
      t =
        name: s.name
        below: b.name
        tier: i + 1
        count: s.count
        belowCount: b.count
        cost: s.cost
        twin: s.twin
        prodEach: s.prodEach
      t.payback = t.cost.dividedBy t.twin.times(t.prodEach) # seconds to regrow the cost
      t.H = t.payback.times t.tier                          # meat break-even clock
      t.passes = t.H.lessThanOrEqualTo horizon
      t.waitFor = t.H.dividedBy(cfg.ageMultiple).minus(age)
      t.affordable = t.belowCount.dividedBy t.cost
      t.twinCost = s.twinCost
      t.twinFactor = s.twinFactor
      t.hatching = false
      all.push t

      if i <= shown and s.prodCost? and t.count.greaterThan(0)
        if t.count.greaterThanOrEqualTo s.prodCost.times(2)
          tips.push {type: 'faster', unit: s.name, cost: s.prodCost}
    # Drones are never hatched under this rule, but their production upgrade still counts.
    drone = snap.units[0]
    if drone.prodCost?
      if drone.count.greaterThanOrEqualTo drone.prodCost.times(2)
        tips.unshift {type: 'faster', unit: drone.name, cost: drone.prodCost}
    tiers = all.slice 0, shown

    spendable = larvaRate.times(1 - cfg.territory) # larvae per second available to the meat units
    banksFor = (x, up) ->
      if not up or not up.passes or up.count.lessThan(1)
        return false
      madeAbove = up.count.times up.prodEach                   # x per second from the tier above
      fromLarvae = spendable.times(x.twin).dividedBy(up.twin)  # as the script computes it
      return madeAbove.greaterThan fromLarvae.times(cfg.bank)

    # Larvae go to the highest tier that passes first; lower tiers get what is left.
    left = larvae.times(1 - cfg.territory).floor()
    for j in [tiers.length - 1..0] by -1
      x = tiers[j]
      x.buys = ZERO
      # LR-1: a tier that fails the climb test but is affordable may still pass with faster levels.
      lrTry = lrActive and not x.passes and x.affordable.greaterThanOrEqualTo(1)
      if not x.passes and not lrTry
        x.kind = 'wait'
        x.reason = 'tooSlow'
        x.waitSeconds = x.waitFor.toNumber()
      else if x.affordable.lessThan 1
        x.kind = 'wait'
        x.reason = 'needBelow'
      else if banksFor x, all[j + 1]
        x.kind = 'skip'
        x.reason = 'bank'
        x.bankFor = all[j + 1].name
      else if lrTry
        climbWithFaster x, snap.units[j + 1], mem, now, cfg, horizon, left
        left = left.minus(x.buys).minus(x.earmarked ? ZERO)
      else
        x.hatching = true # being climbed, even while it waits between purchases
        since = (now - lastBuyTime(mem, x.name, snap.units[j + 1].purchases, now, cfg.cooldown)) / 1000
        frac = 1 - Math.pow(1 - cfg.share, since / 60)
        spare = spareBuys mem, x, since # measured every tick so income during the wait counts
        buys = Decimal.min(left, x.affordable.times(frac), spare).floor()
        x.since = since
        x.spare = spare
        if since < cfg.cooldown
          # Just bought: wait, but keep these larvae earmarked so lower tiers don't grab them.
          x.kind = 'wait'
          x.reason = 'cooldown'
          x.waitSeconds = cfg.cooldown - since
          x.earmarked = Decimal.min(left, x.affordable.times(cfg.share)).floor()
          left = left.minus x.earmarked
        else if buys.greaterThanOrEqualTo 1
          x.kind = 'buy'
          x.reason = 'buy'
          x.buys = buys
          left = left.minus buys
        else if left.lessThan 1
          x.kind = 'skip'
          x.reason = 'larvaeUsedAbove'
        else
          x.kind = 'wait'
          x.reason = 'buildUp'

    # LR-2: feed the tiers above the frontier, with the larvae the climbing tiers left.
    lr = null
    if lrActive
      lr = pushUp snap, all, tiers, mem, now, cfg, left
      left = lr.left
      fasterTips snap, mem, tips

    # Twin upgrades only matter for a unit being hatched with larvae.
    # all[k] is that unit; all[k + 1] is the unit its twin upgrade is paid in.
    for k in [0...tiers.length]
      u = all[k]
      payIn = all[k + 1]
      if not u.hatching or not payIn or not u.twinCost
        continue
      tc = u.twinCost
      uRate = u.twin.times Decimal.min(spendable, u.count.times(u.prodEach).dividedBy(u.cost))
      sacrificed = tc.times payIn.prodEach
      if payIn.count.greaterThanOrEqualTo tc
        aboveMakes = payIn.count.times payIn.prodEach
        larvaeMake = spendable.times(u.twin).dividedBy(payIn.twin)
        if uRate.greaterThanOrEqualTo(sacrificed) and not (payIn.passes and aboveMakes.greaterThan(larvaeMake))
          # LR-3: units of a pushed tier (above the frontier) are kept for climbing, unless plentiful
          if lr? and k + 2 > lr.frontierIndex and payIn.count.lessThan(tc.times LR.twinGuard)
            lr.suppressed.push {type: 'twin', unit: u.name, payIn: payIn.name, cost: tc, need: tc.times(LR.twinGuard), have: payIn.count}
          else
            tips.push {type: 'twin', unit: u.name, payIn: payIn.name, cost: tc}
      else if not payIn.passes and payIn.count.lessThan(tc)
        st = ({name: o.name, have: o.count, twin: o.twin, cost: o.cost, twinCost: o.twinCost, twinFactor: o.twinFactor} for o in all)
        steps = []
        costInU = acquire st, k + 1, tc, steps, 0
        if costInU is null
          continue
        hatchRate = uRate
        if hatchRate.lessThanOrEqualTo 0
          continue
        twinPayback = costInU.dividedBy hatchRate
        if u.count.greaterThanOrEqualTo(costInU.times(2)) and twinPayback.times(u.tier + 1).lessThan(horizon)
          tips.push {type: 'twinPlan', unit: u.name, payIn: payIn.name, cost: tc, steps: steps, planCost: costInU, payback: twinPayback}

    energy = null
    energyError = snap.energyError ? null
    # LR-4: from a run age of 3 days the mode raises the lepidoptera target to 30,000 (never lowers it)
    raiseMoths = lrOn and age >= LR.mothAge and cfg.moths < LR.moths
    if not energyError?
      try
        if raiseMoths
          energy = energyAdvice snap, _.extend({}, cfg, moths: LR.moths)
          if energy?.type in ['buyMoths', 'mothTarget']
            energy.longRun = true
            energy.setting = cfg.moths
        else
          energy = energyAdvice snap, cfg
      catch e
        energyError = e
    ret = {
      now: now
      age: age
      horizon: horizon
      larvae: larvae
      larvaRate: larvaRate
      spendable: spendable
      top: CHAIN[top]
      tiers: tiers
      tips: tips
      energy: energy
      energyError: energyError
      config: cfg
      memory: mem
    }
    # Only with the setting on, so the result is unchanged with it off.
    if lrOn
      ret.longRun =
        active: lrActive
        startsIn: if lrActive then 0 else LR.age - age # seconds until the mode acts
        mothsRaised: raiseMoths
        frontier: if lr? then CHAIN[lr.frontierIndex] else null
        pushes: if lr? then lr.pushes else []
        suppressed: if lr? then lr.suppressed else []
        # tiers above the listed ones, up to endless: nothing can be fed there (LR-2 needs the tier below)
        above: if lrActive then CHAIN.slice(shown + 1) else []
    return ret

  # ---------------------------------------------------------------------------
  # Long-run climb mode helpers (ASCENSION.md A.10.2). Each mutates `mem` and the tier records passed.

  # LR-1 bookkeeping. `mem.lrFaster[name]` is a promise made by LR-1: {level, levels, purchases, bought,
  # fresh}. Once the purchase it advised is seen (the unit's purchase statistic changed), it is
  # `bought`, and the faster tip shows those levels at 1x their price until they are bought. A promise
  # not bought is dropped as soon as LR-1 stops advising it.
  seeFasterPromises = (mem, snap) ->
    for u in snap.units when mem.lrFaster[u.name]?
      p = mem.lrFaster[u.name]
      p.fresh = false
      if not p.bought and p.purchases isnt u.purchases
        p.bought = true
      if p.bought and u.prodLevel >= p.level + p.levels
        delete mem.lrFaster[u.name]
    return

  # The smallest L >= 1 for which hatching n (giving n x twin units) and buying L faster levels out of
  # the units held brings the break-even under the horizon, counting the levels' price as cost:
  #   got = count + n x twin, F_L = price of the next L levels, N_L = got - F_L >= 1,
  #   H x (N_L + F_L) / (N_L x 2^L) <= horizon.
  # Returns {levels, price} or null.
  fasterLevels = (x, s, n, horizon) ->
    if not s.prodCost? or not s.prodFactor? or not n.greaterThanOrEqualTo(1)
      return null
    got = x.count.plus n.times(x.twin)
    F = ZERO
    price = s.prodCost
    for L in [1..LR.maxLevels]
      F = F.plus price
      price = price.times s.prodFactor
      N = got.minus F
      if N.lessThan 1
        return null
      if x.H.times(N.plus F).dividedBy(N.times Decimal.pow(2, L)).lessThanOrEqualTo horizon
        return {levels: L, price: F}
    return null

  # LR-1 for a tier that fails the climb test: size the purchase as rule 3 would if it passed, then test.
  # Sets the tier's kind/reason/buys (and earmark while it cools down after an LR-1 purchase).
  climbWithFaster = (x, s, mem, now, cfg, horizon, left) ->
    promise = mem.lrFaster[x.name]
    since = (now - lastBuyTime(mem, x.name, s.purchases, now, cfg.cooldown)) / 1000
    x.since = since
    if since < cfg.cooldown and promise?.bought
      # just bought on LR-1's advice: it cools down like a climbing tier, larvae earmarked
      x.hatching = true
      x.lrPass = true
      x.fasterLevels = promise.levels
      x.kind = 'wait'
      x.reason = 'cooldown'
      x.waitSeconds = cfg.cooldown - since
      x.earmarked = Decimal.min(left, x.affordable.times(cfg.share)).floor()
      return
    frac = 1 - Math.pow(1 - cfg.share, since / 60)
    spare = spareBuys mem, x, since
    x.spare = spare
    n = Decimal.min(left, x.affordable.times(frac), spare).floor()
    fit = if since >= cfg.cooldown then fasterLevels(x, s, n, horizon) else null
    if fit?
      x.hatching = true
      x.lrPass = true
      x.kind = 'buy'
      x.reason = 'buyFaster'
      x.buys = n
      x.fasterLevels = fit.levels
      x.fasterPrice = fit.price
      mem.lrFaster[x.name] = {level: s.prodLevel, levels: fit.levels, purchases: s.purchases, bought: false, fresh: true}
    else
      x.kind = 'wait'
      x.reason = 'tooSlow'
      x.waitSeconds = x.waitFor.toNumber()
    return

  # The faster tip for a tier bought on LR-1's advice: the promised levels still to buy, at 1x their
  # price (the purchase was sized to pay for them), in place of the usual 2x tip. Mutates `tips`.
  fasterTips = (snap, mem, tips) ->
    for own name, p of mem.lrFaster
      if not p.bought and not p.fresh
        delete mem.lrFaster[name]
        continue
      if not p.bought
        continue
      u = _.find snap.units, name: name
      remaining = p.level + p.levels - u.prodLevel
      if remaining < 1 or not u.prodCost?
        continue
      price = ZERO
      each = u.prodCost
      for i in [0...remaining]
        price = price.plus each
        each = each.times u.prodFactor
      _.remove tips, (t) -> t.type == 'faster' and t.unit == name
      if u.count.greaterThanOrEqualTo price
        tips.unshift {type: 'faster', unit: name, cost: price, levels: remaining, longRun: true}
    return

  # When a pushed unit was last bought, from its purchase statistic, as `lastBuyTime` does for climbing
  # (first sighting: available at once). Kept apart from the climbing memory. Mutates `mem.push`.
  pushBuyTime = (mem, name, total, now, cooldown) ->
    m = mem.push
    if m.seen[name] is undefined
      m.seen[name] = total
      m.boughtAt[name] = now - cooldown * 1000
    else if m.seen[name] isnt total
      m.seen[name] = total
      m.boughtAt[name] = now
    return m.boughtAt[name]

  # LR-2 "feed upward". The frontier is the highest tier that passes the climb test (rule 1 or LR-1)
  # and is owned or bought this visit. From endless down to frontier + 1, with any of the tier below
  # held: hatch floor(share x below / cost), share 0.5 (0.02 for frontier + 1), capped by the larvae
  # left and by half the meat left. Top-down; a pushed unit cools down for `cooldown` seconds after a
  # purchase is seen (no earmark meanwhile). Returns {frontierIndex, pushes, suppressed, left}.
  pushUp = (snap, all, tiers, mem, now, cfg, left) ->
    frontier = 0 # drone
    meatLeft = snap.meat
    for x, j in tiers
      if (x.passes or x.lrPass) and (x.count.greaterThan(0) or x.kind == 'buy')
        frontier = j + 1
      if x.kind == 'buy' and snap.units[j + 1].meatCost?
        meatLeft = meatLeft.minus x.buys.times(snap.units[j + 1].meatCost)
    meatLeft = Decimal.max meatLeft, 0
    pushes = []
    for k in [CHAIN.length - 1...frontier] by -1
      u = snap.units[k]
      b = snap.units[k - 1]
      if not b.count.greaterThan(0) or left.lessThan(1)
        continue
      share = if k >= frontier + 2 then LR.share else LR.frontierShare
      byShare = b.count.times(share).dividedBy u.cost
      byMeat = if u.meatCost? then meatLeft.times(LR.meatShare).dividedBy(u.meatCost) else null
      n = Decimal.min byShare, left
      limitedBy = if byShare.lessThanOrEqualTo(left) then 'share' else 'larvae'
      if byMeat? and byMeat.lessThan n
        n = byMeat
        limitedBy = 'meat'
      n = n.floor()
      if n.lessThan 1
        continue
      x = all[k - 1]
      since = (now - pushBuyTime(mem, u.name, u.purchases, now, cfg.cooldown)) / 1000
      x.pushed = true
      if since < cfg.cooldown
        x.kind = 'wait'
        x.reason = 'cooldown'
        x.waitSeconds = cfg.cooldown - since
        x.buys = ZERO
        continue
      rec = {type: 'push', unit: u.name, below: b.name, buys: n, twin: u.twin, units: n.times(u.twin), share: share, limitedBy: limitedBy, belowCount: b.count}
      pushes.push rec
      x.kind = 'push'
      x.reason = 'push'
      x.buys = n
      x.push = rec
      left = left.minus n
      if u.meatCost?
        meatLeft = meatLeft.minus n.times(u.meatCost)
    return {frontierIndex: frontier, pushes: pushes, suppressed: [], left: left}

  # ---------------------------------------------------------------------------
  # Energy: nexus first, lepidoptera up to the target, then every point into House of Mirrors.
  # Returns null below one nexus.
  energyAdvice = (snap, cfg) ->
    cfg = withDefaults cfg
    e = snap.energy
    nexus = e.nexus
    if not (nexus >= 1)
      return null
    energy = e.energy
    moths = e.moths
    saveFor = ZERO
    saving = null
    next = if nexus < 5 then e.next else null
    if next
      need = {}
      missing = []
      for c in next.costs
        need[c.unit] = c.val
        if c.have.lessThan c.val
          missing.push c
      if not missing.length
        return {type: 'buyNexus', level: nexus + 1}
      meatReady = not _.some missing, (c) -> c.unit == 'meat'
      larvaNear = not need.larva or need.larva.lessThanOrEqualTo(snap.larvaRate.times(NEXUS_LARVA_SECS))
      if meatReady and larvaNear
        saveFor = need.energy or ZERO
        saving =
          type: 'save'
          level: nexus + 1
          missing: ({unit: c.unit, have: c.have, need: c.val} for c in missing)
    spare = Decimal.max energy.minus(saveFor), 0
    if nexus >= 4 and moths.lessThan(cfg.moths)
      n = Decimal.min(D(cfg.moths).minus(moths), spare.dividedBy(MOTH_ENERGY)).floor()
      if n.greaterThanOrEqualTo 1
        return {type: 'buyMoths', count: n, moths: moths, target: cfg.moths, then: saving}
      return saving or {type: 'mothTarget', moths: moths, target: cfg.moths}
    if saving
      return saving
    # Setting spareEnergy 'save': below nexus 5, hold spare energy for the next nexus (and, from
    # nexus 4, the lepidoptera) instead of casting larva rush. The one exception is energy at its cap,
    # where further income is wasted: one larva rush brings it back under.
    if nexus < 5 and cfg.spareEnergy == 'save'
      if e.cap? and energy.greaterThanOrEqualTo(e.cap)
        return {type: 'energyFull', energy: energy, cap: e.cap, spell: SPELLS.larvarush.spell, label: SPELLS.larvarush.label, cost: SPELLS.larvarush.cost}
      hold = {type: 'hold', level: nexus + 1, energy: energy, price: null, ready: false, missing: [], mothsNext: nexus == 3}
      if next
        hold.price = need.energy ? null
        hold.ready = not hold.price? or energy.greaterThanOrEqualTo(hold.price)
        hold.missing = ({unit: c.unit, have: c.have, need: c.val} for c in missing when c.unit != 'energy')
      return hold
    spell = if nexus >= 5 then SPELLS.clonearmy else SPELLS.larvarush
    casts = spare.dividedBy(spell.cost).floor()
    if casts.greaterThanOrEqualTo 1
      return {type: 'cast', spell: spell.spell, label: spell.label, cost: spell.cost, casts: casts}
    return {type: 'nextCast', spell: spell.spell, label: spell.label, cost: spell.cost, energy: energy}

  # ---------------------------------------------------------------------------
  # Plain-text rendering, matching the console script's wording.

  renderAction = (t) ->
    switch t.reason
      when 'tooSlow' then 'wait ' + formatTime(t.waitSeconds)
      when 'needBelow' then 'need more ' + t.below + 's'
      when 'bank' then 'skip: bank larvae for ' + t.bankFor + 's'
      when 'cooldown' then 'done, next in ' + formatTime(t.waitSeconds)
      when 'buy' then 'BUY ' + formatNumber(t.buys) + (if t.twin.greaterThan(1) then ' (x' + formatNumber(t.twin) + ' twins)' else '')
      when 'larvaeUsedAbove' then 'skip: larvae used above'
      when 'buildUp' then 'let ' + t.below + 's build up'
      # long-run mode
      when 'buyFaster'
        'BUY ' + formatNumber(t.buys) + (if t.twin.greaterThan(1) then ' (x' + formatNumber(t.twin) + ' twins)' else '') + ', then ' + t.fasterLevels + 'x faster ' + t.name + 's'
      when 'push' then 'feed upward: ' + renderPush(t.push)
      else ''

  # "hatch 3.20e15 overmind5s (half your overmind4s)"
  renderPush = (rec) ->
    why = switch rec.limitedBy
      when 'larvae' then 'all larvae left'
      when 'meat' then 'half your meat'
      else (if rec.share == 0.5 then 'half' else (rec.share * 100) + '% of') + ' your ' + rec.below + 's'
    'hatch ' + formatNumber(rec.buys) + ' ' + rec.unit + (if rec.buys.equals(1) then '' else 's') + (if rec.twin.greaterThan(1) then ' (x' + formatNumber(rec.twin) + ' twins)' else '') + ' (' + why + ')'

  renderStep = (step) ->
    if step.type == 'twin'
      return 'twin ' + step.unit + 's'
    return 'hatch ' + formatNumber(step.count) + ' ' + step.unit + (if step.count.equals(1) then '' else 's')

  renderTip = (tip) ->
    switch tip.type
      when 'faster' then 'faster ' + tip.unit + 's' + (if tip.levels? then ' x' + tip.levels else '') + ' (' + formatNumber(tip.cost) + ')'
      when 'twin' then 'twin ' + tip.unit + 's (' + formatNumber(tip.cost) + ' ' + tip.payIn + 's)'
      when 'twinPlan'
        (renderStep(s) for s in tip.steps).join(' > ') + ' > twin ' + tip.unit + 's (pays back in ' + formatTime(tip.payback) + ')'
      else ''

  renderSaving = (rec) ->
    'save for nexus ' + rec.level + ': ' + ((formatNumber(m.have) + '/' + formatNumber(m.need) + ' ' + m.unit) for m in rec.missing).join(', ')

  # "saving energy for nexus 2: 2,000/625 energy (ready); still need 3.33e15 meat (have 8.95e11)"
  renderHold = (rec) ->
    text = 'saving energy for nexus ' + rec.level
    if rec.price?
      text += ': ' + formatNumber(rec.energy) + '/' + formatNumber(rec.price) + ' energy' + (if rec.ready then ' (ready)' else '')
    else
      text += ': ' + formatNumber(rec.energy) + ' energy'
    if rec.missing.length
      text += '; still need ' + ((formatNumber(m.need) + ' ' + m.unit + ' (have ' + formatNumber(m.have) + ')') for m in rec.missing).join(', ')
    if rec.mothsNext
      text += '; then lepidoptera'
    return text

  # Without the "energy: " prefix the panel puts in front. Null for null.
  renderEnergy = (rec) ->
    if not rec?
      return null
    switch rec.type
      when 'buyNexus' then 'buy nexus ' + rec.level
      when 'save' then renderSaving rec
      when 'buyMoths'
        want = 'lepidoptera ' + formatNumber(rec.moths) + '/' + formatNumber(rec.target) + (if rec.longRun then ', long-run target' else '')
        'buy ' + formatNumber(rec.count) + ' lepidoptera (' + want + ')' + (if rec.then then '; then ' + renderSaving(rec.then) else '')
      when 'mothTarget' then 'all energy into lepidoptera ' + formatNumber(rec.moths) + '/' + formatNumber(rec.target) + (if rec.longRun then ' (long-run target)' else '')
      when 'cast' then 'cast ' + rec.label + ' x' + formatNumber(rec.casts)
      when 'nextCast' then 'next ' + rec.label + ' at ' + formatNumber(rec.cost) + ' energy (have ' + formatNumber(rec.energy) + ')'
      when 'hold' then renderHold rec
      when 'energyFull'
        'energy is full (' + formatNumber(rec.energy) + '/' + formatNumber(rec.cap) + '): cast ' + rec.label + ' x1 so the income is not wasted'
      else ''

  renderHeader = (r) ->
    'run ' + formatTime(r.age) + ' | climb if H < ' + formatTime(r.horizon) + ' | larvae ' + formatNumber(r.larvae) + ' (+' + formatNumber(r.larvaRate) + '/s)'

  # ---------------------------------------------------------------------------
  # Live wiring for the panel: one remembered state per page load.

  liveMemory = null
  # Shared by the panel and the buy-box button, so the rules run at most once per `maxAgeMs`
  # however many views ask. Wall-clock time, so a page left in the background doesn't skew it.
  cached = null

  # The advice record for one unit (by name), or null when that unit isn't among the listed tiers.
  suggestionFor = (advice, name) ->
    for t in advice?.tiers ? []
      if t.name == name
        return t
    return null

  svc = {
    CHAIN: CHAIN
    DEFAULTS: DEFAULTS
    # pure
    snapshot: snapshot
    createMemory: createMemory
    advise: advise
    energyAdvice: energyAdvice
    acquire: acquire
    formatNumber: formatNumber
    formatTime: formatTime
    renderAction: renderAction
    renderTip: renderTip
    renderStep: renderStep
    renderEnergy: renderEnergy
    renderHeader: renderHeader
    renderPush: renderPush
    LR: LR
    # live
    config: -> options.advisorConfig()
    enabled: -> options.advisorEnabled()
    update: (now) ->
      result = advise snapshot(game, now), liveMemory, options.advisorConfig()
      liveMemory = result.memory
      return result
    memory: -> liveMemory
    resetMemory: ->
      liveMemory = null
      cached = null
    suggestionFor: suggestionFor
    # The latest advice, re-running `update()` only when the cached result is at least `maxAgeMs`
    # old. Never throws: returns {at, advice, error}, with `error` set (and `advice` null) when
    # `update()` threw. `wallNow` is for tests.
    current: (maxAgeMs=1000, wallNow=Date.now()) ->
      if not cached? or wallNow - cached.at >= maxAgeMs or wallNow < cached.at
        try
          cached = {at: wallNow, advice: svc.update(), error: null}
        catch e
          cached = {at: wallNow, advice: null, error: e}
      return cached
    invalidate: -> cached = null
  }
  # A different save (imported, or the game reset) must not inherit this one's purchase history:
  # its statistics would read as a purchase just made, and put every unit on cooldown.
  # Every sender of 'import' passes {success}; a failed import leaves the old save in place.
  $rootScope.$on 'import', (event, args) ->
    if args?.success
      svc.resetMemory()
  $rootScope.$on 'reset', -> svc.resetMemory()
  return svc

# Keep the live advice (and the purchase memory behind it) current on every page, not only while an
# advisor view is showing, as the console script's timer did. Runs on the game's own tick, at most
# once per ADVISOR_REFRESH_MILLIS, only while the advisor is on; views just read the cached result.
# The services are looked up on the first tick, so loading the module creates nothing. Never throws:
# an exception here would stop the game loop.
angular.module('swarmApp').run ($rootScope, $injector, $log, ADVISOR_REFRESH_MILLIS) ->
  $rootScope.$on 'tick', ->
    try
      if $injector.get('options').advisorEnabled()
        $injector.get('advisor').current ADVISOR_REFRESH_MILLIS
        $injector.get('advisorTerritory').current ADVISOR_REFRESH_MILLIS
        # does no work while the ascension setting is off
        $injector.get('advisorAscension').current ADVISOR_REFRESH_MILLIS
    catch e
      $log.warn 'advisor tick', e
    return
