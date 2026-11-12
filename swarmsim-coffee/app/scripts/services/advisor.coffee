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
  limits:
    ageMultiple: {min: 0.01, max: 1000}
    share: {min: 0.01, max: 1}
    cooldown: {min: 0, max: 86400}
    bank: {min: 0, max: 1e6}
    territory: {min: 0, max: 0.95}
    moths: {min: 0, max: 1e12, integer: true}

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
      purchases: String(if stats[name] then stats[name].num else 0)

    nexus = D(g.unit('nexus').count()).toNumber()
    next = null
    if nexus < 5 and (up = g.upgrade 'nexus' + (nexus + 1))
      next =
        name: up.name
        level: nexus + 1
        costs: ({unit: c.unit.name, val: D(c.val), have: D(c.unit.count())} for c in up.totalCost())

    return {
      now: now
      restartedAt: new Date(dates.restarted or dates.started).getTime()
      larvae: D larva.count()
      larvaRate: D larva.velocity()
      units: units
      energy:
        nexus: nexus
        energy: D g.unit('energy').count()
        moths: D g.unit('moth').count()
        next: next
    }

  # ---------------------------------------------------------------------------
  # Remembered state: per unit, the purchase statistic last seen, when it last changed, and the stock
  # of the tier below at that moment.

  createMemory = (now) ->
    startedAt: now
    seen: {}
    boughtAt: {}
    stockAt: {}

  copyMemory = (memory, now) ->
    if not memory?
      return createMemory now
    startedAt: if memory.startedAt? then memory.startedAt else now
    seen: copyMap memory.seen
    boughtAt: copyMap memory.boughtAt
    stockAt: copyMap memory.stockAt

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
    mem = copyMemory memory, now
    age = (now - snap.restartedAt) / 1000
    horizon = age * cfg.ageMultiple
    larvae = snap.larvae
    larvaRate = snap.larvaRate

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
      if not x.passes
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

    return {
      now: now
      age: age
      horizon: horizon
      larvae: larvae
      larvaRate: larvaRate
      spendable: spendable
      top: CHAIN[top]
      tiers: tiers
      tips: tips
      energy: energyAdvice snap, cfg
      config: cfg
      memory: mem
    }

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
      else ''

  renderStep = (step) ->
    if step.type == 'twin'
      return 'twin ' + step.unit + 's'
    return 'hatch ' + formatNumber(step.count) + ' ' + step.unit + (if step.count.equals(1) then '' else 's')

  renderTip = (tip) ->
    switch tip.type
      when 'faster' then 'faster ' + tip.unit + 's (' + formatNumber(tip.cost) + ')'
      when 'twin' then 'twin ' + tip.unit + 's (' + formatNumber(tip.cost) + ' ' + tip.payIn + 's)'
      when 'twinPlan'
        (renderStep(s) for s in tip.steps).join(' > ') + ' > twin ' + tip.unit + 's (pays back in ' + formatTime(tip.payback) + ')'
      else ''

  renderSaving = (rec) ->
    'save for nexus ' + rec.level + ': ' + ((formatNumber(m.have) + '/' + formatNumber(m.need) + ' ' + m.unit) for m in rec.missing).join(', ')

  # Without the "energy: " prefix the panel puts in front. Null for null.
  renderEnergy = (rec) ->
    if not rec?
      return null
    switch rec.type
      when 'buyNexus' then 'buy nexus ' + rec.level
      when 'save' then renderSaving rec
      when 'buyMoths'
        want = 'lepidoptera ' + formatNumber(rec.moths) + '/' + formatNumber(rec.target)
        'buy ' + formatNumber(rec.count) + ' lepidoptera (' + want + ')' + (if rec.then then '; then ' + renderSaving(rec.then) else '')
      when 'mothTarget' then 'all energy into lepidoptera ' + formatNumber(rec.moths) + '/' + formatNumber(rec.target)
      when 'cast' then 'cast ' + rec.label + ' x' + formatNumber(rec.casts)
      when 'nextCast' then 'next ' + rec.label + ' at ' + formatNumber(rec.cost) + ' energy (have ' + formatNumber(rec.energy) + ')'
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
  $rootScope.$on 'import', -> svc.resetMemory()
  $rootScope.$on 'reset', -> svc.resetMemory()
  return svc
