'use strict'

# Settings for the climbing advisor: defaults and the range each one is clamped to.
# `options` stores them with the save; the advisor reads them through `options`.
angular.module('swarmApp').constant 'ADVISOR_SETTINGS',
  defaults:
    # climb tiers whose break-even H is under this many x run age (game time). 5: what every route was simulated with
    # (policy.json, ASCENSION.md, NO-MIRRORS.md); 3 before Nov 16, 2026 (MODEL-CHECK.md, "Faster-aware climbing")
    ageMultiple: 5
    share: 0.5        # fraction of the lower tier to convert per minute waited
    cooldown: 60      # seconds after hatching a unit before it is suggested again
    bank: 3           # stop hatching a unit once the tier above makes this many x what larvae could
    territory: 0.10   # fraction of larvae held back for territory units
    moths: 4000       # lepidoptera target after nexus 5 (the achievements route raises it per run: see `runMoths`)
    # below nexus 5: 'save' plans energy for the next nexus (ASCENSION.md A.11: hold it, keep the nexus's larvae
    # from the climb, at nexus 4 1,000 lepidoptera first and then only what nexus 5 needs just in time);
    # 'larvarush' casts spare energy as larva rush, as the console script did
    spareEnergy: 'save'
    # ascension advice and the route the whole advisor follows (advisorascension.coffee): 'off'; 'achievements', the
    # House of Mirrors route of ASCENSION.md part A; or 'swarmwarp', the swarmwarp route of NO-MIRRORS.md section 12
    ascension: 'achievements'
    # rule SEED (ASCENSION.md A.10.9): 1% of each tier and of the climb's larvae into every tier above the climb, at
    # every look. Shown in Options; 'off' is the console script's climb and the older reference cases'
    seed: 'on'
    # rule FA (MODEL-CHECK.md, "Faster-aware climbing, pass 2"): a tier that fails the climb test is started when
    # buying it together with some of its own faster levels pays back inside the horizon. Not shown in Options; 'off'
    # is the console script's climb (advisor/modelcheck/script_vs_port.js) and the older reference cases'
    fasterStart: 'on'
    # twin plans (`acquire`): 'on' also takes a detour that needs some of the tier hatched first; 'off' is the
    # console script's planner (advisor/modelcheck/script_vs_port.js). Not shown in Options
    twinDetour: 'on'
    # rule 4 (banking): 'plain' compares the tier above with larvae/s x the tier's twin; 'script' divides that by the
    # tier above's twin, as the console script did (advisor/modelcheck/script_vs_port.js). Not shown in Options
    bankTwin: 'plain'
  limits:
    ageMultiple: {min: 0.01, max: 1000}
    share: {min: 0.01, max: 1}
    cooldown: {min: 0, max: 86400}
    bank: {min: 0, max: 1e6}
    territory: {min: 0, max: 0.95}
    moths: {min: 0, max: 1e12, integer: true}
    spareEnergy: {choices: ['larvarush', 'save']} # a choice, not a number
    ascension: {choices: ['off', 'achievements', 'swarmwarp']}
    seed: {choices: ['off', 'on']}
    fasterStart: {choices: ['off', 'on']}
    twinDetour: {choices: ['off', 'on']}
    bankTwin: {choices: ['script', 'plain']}

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

angular.module('swarmApp').factory 'advisor', ($rootScope, $injector, game, options, ADVISOR_SETTINGS, ADVISOR_REFRESH_MILLIS) ->
  ZERO = new Decimal 0
  ONE = new Decimal 1
  D = (x) -> new Decimal(if x? then x else 0)

  CHAIN = ['drone', 'queen', 'nest', 'greaterqueen', 'hive', 'hivequeen', 'empress',
    'prophet', 'goddess', 'pantheon', 'pantheon2', 'pantheon3', 'pantheon4', 'pantheon5',
    'overmind', 'overmind2', 'overmind3', 'overmind4', 'overmind5', 'overmind6']
  DEFAULTS = ADVISOR_SETTINGS.defaults
  NEXUS_LARVA_SECS = 20000 # save for the next nexus once its larva price is under this many seconds of larvae
  MOTH_ENERGY = 10
  # spareEnergy 'save' at nexus 4 (ASCENSION.md A.11): this many lepidoptera are bought first, before
  # saving for nexus 5. Nexus 5 alone would want ~600 and the ascension ~2,000; both are flat around 1,000.
  EARLY_MOTHS = 1000
  # The House of Mirrors route's long-run lepidoptera target (once LR-4 of the retired long-run mode; ASCENSION.md
  # A.10.9: a lepidoptera rule, kept as the route's run target by advisorAscension `runMoths`).
  LR =
    mothAge: 3 * 86400    # from this run age (s, wall clock)
    moths: 30000          # the target (the setting, if higher, stays)
  # Rule SEED (ASCENSION.md A.10.9, "Rule SEED (spec for the port; replaces LR-0 to LR-3)").
  SEED =
    share: 0.01           # 1% of the tier below (in purchases) and 1% of the climb's larvae A, per tier and look
    meatShare: 0.5        # at most half the meat left
  # A seed line holds the next swarmwarp only when its tier was last hatched at least this long ago on the game clock:
  # a warp skips at least 900 s, so after one the seeds are new; a 60 s refill of a 1% line does not hold it.
  WARP_HOLD_SEED_SECS = 900
  SPELLS =
    larvarush: {spell: 'larvarush', label: 'larva rush', cost: 1600}
    clonearmy: {spell: 'clonearmy', label: 'House of Mirrors', cost: 2500}
    swarmwarp: {spell: 'swarmwarp', label: 'swarmwarp', cost: 2000} # the cost is read from the game when the snapshot has it

  # The swarmwarp route (advisor/NO-MIRRORS.md section 12), chosen with the `ascension` setting 'swarmwarp'. Every
  # rule reads the game state only: the route keeps nothing between visits.
  SW =
    moths: 10000           # 12.2 E2: lepidoptera after nexus 5, every run (the setting, if higher, stays)
    bats: 2000             # 12.2 E3: bats after the lepidoptera and before the first swarmwarp, every run
    territory: 0.1         # 12.4: the territory share the route keeps (advised back from 0)
    ratio: 1000            # 12.6 build: ascend once premutagen >= this x max(mutagen held, 1)
    finalLog10: 270        # 12.6 final: from 1e270 mutagen held (5,000 expansions missing), never ascend
    unlockOrder: ['mutatenexus', 'mutateswarmwarp', 'mutatebat', 'mutatefreq', 'mutateeach', 'mutatearmy', 'mutaterush',
      'mutateclone', 'mutatemeat', 'mutatehatchery'] # 12.7 step 2
    freeUnlocks: 3         # 12.7 step 2: the first three unlocks whenever affordable
    unlockShare: 0.3       # 12.7 step 2: from the 4th, only while its price is at most this share of the mutagen held
    fixedMutants: [['mutantnexus', 1e6], ['mutantfreq', 1e6]] # 12.7 step 3: hold this many of each (when unlocked)
    shares: [['mutantswarmwarp', 0.1], ['mutantbat', 0.1], ['mutantarmy', 0.3], ['mutanteach', 0.01]] # 12.7 step 4, of W
    # 13 G1, first protection: an ascension this route advises out of a run with House of Mirrors casts and at least
    # this many expansions says that it restarts them
    restartNote: 1000
    # The owner's near-complete guard (on top of section 13): a run with House of Mirrors casts, after an ascension,
    # with at least this many expansions and the 5,000-expansions achievement missing, is finished as the mirrors
    # route's long run (no ascension, no swarmwarp), then the swarmwarp route resumes. The spec's day-90 switch sample
    # (4,695 expansions) gained only 7 days by ascending.
    nearComplete: 4500
  # The achievement for 5,000 expansions (game data): the near-complete guard and the stages read it.
  EXPANSION_GOAL = 'expansion9'
  # Territory hatch lines hold the next swarmwarp only while they hold more than this many seconds of the territory
  # share's larva income: the purse refills every second, so a smaller line would hold it for ever (12.3).
  WARP_HOLD_TERRITORY_SECS = 60

  # The route the advisor follows, from the settings and the game state (NO-MIRRORS.md section 13):
  #   {setting, route: 'mirrors' | 'swarmwarp' | null (ascension advice off), guard}
  # `facts` is `routeFacts()` (a snapshot's `route`). With the swarmwarp setting, a run caught by the near-complete
  # guard follows the mirrors route (`guard` says why); never in a first run (13 G2), never without mirror casts.
  routeOf = (cfg, facts) ->
    setting = cfg?.ascension ? DEFAULTS.ascension
    if setting != 'swarmwarp'
      return {setting: setting, route: (if setting == 'achievements' then 'mirrors' else null), guard: null}
    guard = nearComplete facts
    return {setting: setting, route: (if guard? then 'mirrors' else 'swarmwarp'), guard: guard}

  nearComplete = (facts) ->
    goal = facts?.expansionGoal
    if not goal? or goal.earned or not (facts.ascensions >= 1) or not (facts.mirrorCasts > 0)
      return null
    if facts.expansions < SW.nearComplete
      return null
    return {type: 'finishMirrors', expansions: facts.expansions, goal: goal.val, threshold: SW.nearComplete, mirrorCasts: facts.mirrorCasts}

  # What the route reads from the game, for every advisor service's snapshot. Null if the game lacks any of it.
  routeFacts = (g) ->
    try
      ach = g.achievement EXPANSION_GOAL
      req = ach?.requires?[0]
      return {
        ascensions: D(g.unit('ascension').count()).toNumber()
        mirrorCasts: D(g.upgrade('clonearmy').count()).toNumber() # House of Mirrors casts this run
        warpCasts: D(g.upgrade('swarmwarp').count()).toNumber()   # swarmwarp casts this run
        expansions: D(g.upgrade('expansion').count()).toNumber()  # this run
        expansionGoal: if req? then {name: ach.name, val: D(req.val).toNumber(), earned: ach.isEarned()} else null
      }
    catch e
      return null

  # The game clock (NO-MIRRORS.md 11, 12.1): wall time plus `session.state.skippedMillis`, the time swarmwarp has
  # skipped over the whole save (exact; kept across reloads and ascensions). This run's skipped time is estimated
  # without memory: this run's swarmwarp casts x what one cast skips now, and never more than the save's whole
  # skipped time. Exact while the power has not changed since this run's first cast (the swarmwarp route buys its
  # bats first). Inexact otherwise: bats or warp mutants bought after earlier casts make it count those casts at the
  # new power, too long, and the bound only binds while earlier runs skipped little (in a first run it is exact).
  # Without a cast both clocks are the wall clock's.
  gameClock = (g, now) ->
    skipped = Number(g.session?.state?.skippedMillis ? 0) or 0
    runSkipped = 0
    try
      warp = g.upgrade 'swarmwarp'
      casts = D(warp.count())
      if casts.greaterThan 0
        effect = _.find(warp.effect, (e) -> e.type?.name == 'skipTime') ? warp.effect[0]
        runSkipped = Math.min casts.times(effect.output()).times(1000).toNumber(), skipped
    catch e
      runSkipped = 0
    return {gameNow: now + skipped, skipped: skipped, runSkipped: runSkipped}

  # What the live advice depends on besides the game's own counts: the settings and the skipped time. A change in
  # either (a setting picked, a swarmwarp cast) makes every advisor service work its advice out afresh at once.
  liveKey = (g=game) ->
    skipped = g?.session?.state?.skippedMillis ? 0
    try
      cfg = JSON.stringify options.advisorConfig()
    catch e
      cfg = ''
    return skipped + '|' + cfg

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
      prodMult: if prodUp then D(_.find(prodUp.effect, (e) -> e.type?.name == 'multStat' and e.stat == 'prod')?.val ? 2) else null # production x per faster level
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
        rate: D g.unit('energy').velocity() # energy per second (the 'save' plan's just-in-time hold)
        moths: D g.unit('moth').count()
        next: next
      # the swarmwarp route's energy (NO-MIRRORS.md 12.2): bats and swarmwarp, prices and power from the game
      bat = g.unit 'bat'
      warpUp = g.upgrade 'swarmwarp'
      if bat? and warpUp?
        energy.bats = D bat.count()
        energy.batPrice = D(_.find(bat.eachCost(), (c) -> c.unit.name == 'energy')?.val ? 100) # energy per bat
        skipEffect = _.find(warpUp.effect, (e) -> e.type?.name == 'skipTime') ? warpUp.effect[0]
        energy.warp =
          cost: D(_.find(warpUp.totalCost(), (c) -> c.unit.name == 'energy')?.val ? SPELLS.swarmwarp.cost)
          skip: D(skipEffect.output()).toNumber() # seconds one cast skips now (900 x power)
          power: D(skipEffect.power()).toNumber()
          casts: D(warpUp.count()).toNumber() # this run
    catch e
      energyError = e

    clock = gameClock g, now
    return {
      now: now # wall clock: energy, the mirrors route's day 3, memory identity
      gameNow: clock.gameNow # game clock (NO-MIRRORS.md 12.1): the timers
      runSkipped: clock.runSkipped # ms skipped by swarmwarp in this run (estimate): run age on the game clock
      restartedAt: new Date(dates.restarted or dates.started).getTime()
      larvae: D larva.count()
      larvaRate: D larva.velocity()
      meat: D g.unit('meat').count()
      units: units
      energy: energy
      energyError: energyError
      route: routeFacts g
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
  # {type:'hatch', unit, count} or {type:'twin', unit}, in the order the player makes them. Returns the
  # cost in units of the tier below j (every hatch of tier j in the plan), or null.
  #
  # `prefix` (setting twinDetour 'on', the default): when the tier-j units held do not cover the detour,
  # hatch the missing ones first, at the current twin, and count them in the cost (the owner's empress
  # twin, Nov 21, 2026: 1e9 prophets, 1 goddess, twin prophets, 5e9 prophets: 6e17 empresses against
  # 1e18 direct). 'off' is the console script's planner: the detour only when the units held cover it.
  acquire = (st, j, N, steps, depth, prefix=true) ->
    spent = ZERO # cost of the hatches already planned (the prefixes)
    for guard in [0...80]
      t = st[j]
      need = N.minus t.have
      if need.lessThanOrEqualTo 0
        return spent
      hatches = need.dividedBy(t.twin).ceil()
      direct = hatches.times t.cost
      if st[j + 1] and t.twinCost and depth < 8
        trial = (cloneEntry o for o in st)
        tsteps = []
        sub = acquire trial, j + 1, trial[j].twinCost, tsteps, depth + 1, prefix # in tier j units
        if sub isnt null and (prefix or trial[j].have.greaterThanOrEqualTo(sub))
          # hatch first what the detour needs beyond the units held (none when they cover it)
          pre = Decimal.max(sub.minus(trial[j].have), 0).dividedBy(trial[j].twin).ceil()
          preCost = pre.times trial[j].cost
          trial[j].have = trial[j].have.plus(pre.times trial[j].twin).minus sub
          trial[j + 1].have = trial[j + 1].have.minus trial[j].twinCost
          tsteps.push {type: 'twin', unit: t.name}
          trial[j].twin = trial[j].twin.times 2
          trial[j].twinCost = trial[j].twinCost.times trial[j].twinFactor
          via = preCost.plus Decimal.max(N.minus(trial[j].have), 0).dividedBy(trial[j].twin).ceil().times(trial[j].cost)
          if via.lessThan direct
            for q in [0...st.length]
              st[q] = trial[q]
            if pre.greaterThan 0
              steps.push {type: 'hatch', unit: t.name, count: pre}
            Array::push.apply steps, tsteps
            spent = spent.plus preCost
            continue
      steps.push {type: 'hatch', unit: t.name, count: hatches}
      t.have = N
      return spent.plus direct
    return null

  # ---------------------------------------------------------------------------
  # Meat-unit rules.

  # The script's compute(), on a snapshot. Returns plain data plus the updated memory; the input
  # snapshot and memory are not modified.
  # `given` is for the rule SEED reference-case check only (advisor/modelcheck/seed_check.js): {larvae} replaces
  # A, the larvae the climb may use, so the seed lines can be compared with the simulator's given the same
  # larvae. The app never passes it.
  #
  # `cfg.runMoths` / `cfg.runStage` (not stored settings): the lepidoptera target after nexus 5 that the
  # ascension route's stage asks for (advisorAscension `runMoths`), passed by `update()`. It raises the
  # `moths` setting, never lowers it. Without it the setting applies.
  #
  # The route (`routeOf`, from the `ascension` setting and the game) is worked out here every time; nothing about it
  # is remembered. On the swarmwarp route (NO-MIRRORS.md 12.2) the lepidoptera target is SW.moths (the setting, if
  # higher, stays), and spare energy after nexus 5 goes into bats, then swarmwarp, one cast at a time.
  #
  # Clocks (NO-MIRRORS.md 12.1): the timers (cooldown, purchase share, stock release, the seed's cooldown) and the
  # run age behind the horizon are on the game clock (`snap.gameNow`, `snap.runSkipped`). With no swarmwarp cast the
  # two clocks differ by a constant.
  advise = (snap, memory, cfg, given) ->
    runMoths = cfg?.runMoths ? null
    runStage = cfg?.runStage ? null
    cfg = withDefaults cfg
    route = routeOf cfg, snap.route
    warpRoute = route.route == 'swarmwarp'
    if warpRoute
      runMoths = SW.moths    # 12.2 E2
      runStage = 'swarmwarp'
    now = snap.gameNow ? snap.now # the game clock
    mem = copyMemory memory, now, snap.restartedAt
    wallAge = (snap.now - snap.restartedAt) / 1000
    age = wallAge + (snap.runSkipped ? 0) / 1000 # this run's age on the game clock
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
    # Rule 4: bank (hatch no more of x) once the tier above makes `bank` times what larvae could make of x: larvae/s
    # x x's twin multiplier. The console script divided that by the tier above's twin multiplier, which understates
    # the larvae by that factor (256 on the owner's 7.2 d save: goddesses banked at a real ratio of 0.022 where the
    # setting says 3); setting bankTwin 'script' keeps its formula for the script comparison (Nov 25, 2026).
    banksFor = (x, up) ->
      if not up or not up.passes or up.count.lessThan(1)
        return false
      madeAbove = up.count.times up.prodEach                   # x per second from the tier above
      fromLarvae = spendable.times(x.twin)                     # x per second from the larvae
      if cfg.bankTwin == 'script'
        fromLarvae = fromLarvae.dividedBy(up.twin)
      return madeAbove.greaterThan fromLarvae.times(cfg.bank)

    energy = null
    energyError = snap.energyError ? null
    if not energyError?
      try
        if warpRoute
          energy = energyAdvice snap, _.extend({}, cfg, moths: Math.max(cfg.moths, runMoths), route: 'swarmwarp')
          if energy?.type in ['buyMoths', 'mothTarget'] and not energy.early and runMoths > cfg.moths
            energy.runStage = runStage
            energy.setting = cfg.moths
        else if runMoths? and runMoths > cfg.moths
          energy = energyAdvice snap, _.extend({}, cfg, moths: runMoths)
          if energy?.type in ['buyMoths', 'mothTarget'] and not energy.early
            energy.runStage = runStage
            energy.setting = cfg.moths
        else
          energy = energyAdvice snap, cfg
      catch e
        energyError = e

    # Larvae go to the highest tier that passes first; lower tiers get what is left.
    left = larvae.times(1 - cfg.territory).floor()
    # spareEnergy 'save' (ASCENSION.md A.11): the larvae the next nexus needs are kept from the climb while
    # the energy line says to buy it or save for it.
    # Without this, a player who follows every suggestion never gathers nexus 5's 3.33e9 larvae.
    nexusHeld = null
    if cfg.spareEnergy == 'save'
      nexusHeld = Decimal.min nexusLarvae(energy, snap, cfg), left
      left = left.minus nexusHeld
    # rule FA: the meat the climb's purchases above have used this visit (the hatch's meat cap)
    faOn = cfg.fasterStart != 'off'
    meatLeft = snap.meat
    faTips = []
    # rule SEED: A = the larvae the climb may use, before rule 3 or FA spend any; the seed lines take theirs first
    seed = null
    if cfg.seed != 'off'
      if given?.larvae?
        left = D given.larvae
      seed = seedUpward snap, all, mem, now, cfg, left, meatLeft
      left = seed.left
      meatLeft = seed.meat
    for j in [tiers.length - 1..0] by -1
      x = tiers[j]
      x.buys = ZERO
      u = snap.units[j + 1]
      if not x.passes
        x.kind = 'wait'
        x.reason = 'tooSlow'
        x.waitSeconds = x.waitFor.toNumber()
        if faOn
          left = fasterStart x, u, all[j + 1], mem, now, cfg, horizon, left, meatLeft, faTips, banksFor
        if x.seed?
          if x.reason == 'fasterStart'
            x.buys = x.buys.plus x.seed.n # the seed line and FA's hatch, in one purchase
          else
            seedRow x
      else if x.affordable.lessThan 1
        x.kind = 'wait'
        x.reason = 'needBelow'
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
          if faOn and u.meatCost?
            meatLeft = meatLeft.minus buys.times(u.meatCost)
          if x.seed?
            x.buys = x.buys.plus x.seed.n # the seed line and the climb's purchase, in one
        else if x.seed?
          seedRow x
        else if left.lessThan 1
          x.kind = 'skip'
          x.reason = 'larvaeUsedAbove'
        else
          x.kind = 'wait'
          x.reason = 'buildUp'

    # rule FA: the faster levels a tier needs show as a tip at 1x their price (rule 5 asks 2x held), replacing the
    # plain tip for that unit
    if faTips.length
      fa = _.keyBy faTips, 'unit'
      tips = (t for t in tips when not (t.type == 'faster' and fa[t.unit]?))
      Array::push.apply tips, faTips

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
        costInU = acquire st, k + 1, tc, steps, 0, cfg.twinDetour != 'off'
        if costInU is null
          continue
        hatchRate = uRate
        if hatchRate.lessThanOrEqualTo 0
          continue
        twinPayback = costInU.dividedBy hatchRate
        if u.count.greaterThanOrEqualTo(costInU.times(2)) and twinPayback.times(u.tier + 1).lessThan(horizon)
          tips.push {type: 'twinPlan', unit: u.name, payIn: payIn.name, cost: tc, steps: steps, planCost: costInU, payback: twinPayback}

    ret = {
      now: snap.now
      gameNow: now
      age: age
      wallAge: wallAge
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
      route: route
      memory: mem
    }
    # Only with the 'save' plan, so the result is unchanged with 'larvarush' (the console script).
    if nexusHeld?
      ret.nexusLarvae = nexusHeld # larvae the climb leaves for the next nexus (0 while not saving for it)
    # Only with rule SEED on, so the result is unchanged with it off.
    if seed?
      ret.seed = {frontier: CHAIN[seed.frontier], larvae: seed.A, lines: seed.lines, left: seed.left}
    return ret

  # ---------------------------------------------------------------------------
  # Rule SEED (ASCENSION.md A.10.9, "Rule SEED (spec for the port; replaces LR-0 to LR-3)"). At every look, before
  # the climb: the frontier is the highest owned tier that passes the plain test (H <= horizon; drones count as
  # passing; FA does not count). For each tier from endless down to frontier + 1:
  # - none of the tier below held: no line ('nothing below');
  # - hatched less than `cooldown` s ago on the game clock: no line ('cooldown');
  # - else n = floor(min(1% x tier below held / cost, 1% x A, half the meat left / meat price, larvae left)), a line
  #   when n >= 1, taking its larvae, its units of the tier below and its meat before the next line.
  # `A` = the larvae the climb may use (territory share and the next nexus's hold already out). Mutates `mem` (first
  # sightings, as the climb) and the tier records it seeds (`x.seed`; `x.affordable` less the units it takes).
  # Returns {frontier (unit index), A, lines, left, meat}.
  seedUpward = (snap, all, mem, now, cfg, A, meat) ->
    frontier = 0 # drone
    for u, i in snap.units when i > 0 and u.count.greaterThan(0) and all[i - 1].passes
      frontier = i
    below = (u.count for u in snap.units)
    left = A
    lines = []
    for k in [CHAIN.length - 1...frontier] by -1
      u = snap.units[k]
      b = snap.units[k - 1]
      x = all[k - 1]
      line = {unit: u.name, below: b.name, belowHeld: below[k - 1]}
      lines.push line
      if not below[k - 1].greaterThan 0
        line.outcome = 'nothing below'
        continue
      since = (now - lastBuyTime(mem, u.name, u.purchases, now, cfg.cooldown)) / 1000
      line.since = since
      if since < cfg.cooldown
        line.outcome = 'cooldown'
        continue
      if left.lessThan 1
        line.outcome = 'no larvae'
        continue
      caps = [['below', below[k - 1].times(SEED.share).dividedBy(u.cost)], ['larvae', D(A).times(SEED.share)]]
      if u.meatCost?
        caps.push ['meat', Decimal.max(meat, 0).times(SEED.meatShare).dividedBy(u.meatCost)]
      caps.push ['left', left]
      bind = caps[0]
      for c in caps when c[1].lessThan bind[1]
        bind = c
      n = bind[1].floor()
      _.extend line, {n: n, binding: bind[0], caps: _.fromPairs(caps)}
      if n.lessThan 1
        line.outcome = 'under one'
        continue
      line.outcome = 'hatch'
      x.seed = {n: n, binding: bind[0], below: b.name, since: since}
      below[k - 1] = below[k - 1].minus n.times(u.cost)
      x.affordable = Decimal.max(x.affordable.minus(n), 0)
      if u.meatCost?
        meat = meat.minus n.times(u.meatCost)
      left = left.minus n
    return {frontier: frontier, A: D(A), lines: lines, left: left, meat: meat}

  # A tier whose action this look is its seed line.
  seedRow = (x) ->
    x.kind = 'seed'
    x.reason = 'seed'
    x.buys = x.seed.n

  # ---------------------------------------------------------------------------
  # Rule FA (advisor/MODEL-CHECK.md, "Faster-aware climbing, pass 2", "Rule FA, if adopted (variant c2)").
  # Pure. A tier failing rule 1 (H > horizon) with `got` units after a hatch: buying its next L faster levels costs
  # F_L units of the tier itself (the game's price and price factor), leaves N_L = got - F_L, and multiplies its
  # production by mult^L (the game's faster effect, x2), so it pays back by H_L = H x (N_L + F_L) / (N_L x mult^L).
  # Returns every L in 1..FA_MAX_LEVELS and the smallest L with N_L >= 1 and H_L <= horizon (`pass`, or null).
  FA_MAX_LEVELS = 12
  fasterTest = (o) ->
    H = D o.H
    horizon = D o.horizon
    got = D o.got
    mult = D(o.mult ? 2)
    price = D o.price
    F = ZERO
    levels = []
    pass = null
    for L in [1..FA_MAX_LEVELS]
      F = F.plus price
      price = price.times o.factor
      N = got.minus F
      Heff = if N.greaterThanOrEqualTo(1) then H.times(N.plus F).dividedBy(N.times Decimal.pow(mult, L)) else null
      ok = Heff? and Heff.lessThanOrEqualTo(horizon)
      levels.push {L: L, price: F, kept: N, H: Heff, passes: ok}
      if ok and not pass?
        pass = L
    return {levels: levels, pass: pass}

  # Why a tier that fails rule 1 is not started (the "wait" line's clause), or null: the fewest levels L* that could
  # ever make it pass (mult^L* x horizon > H), their price F*, and the units that would have to be held for them:
  # U = H x F* / (mult^L* x horizon - H) + F*, as purchases (U - held) / twin. Null when no L <= FA_MAX_LEVELS can.
  fasterWait = (o) ->
    H = D o.H
    horizon = D o.horizon
    mult = D(o.mult ? 2)
    price = D o.price
    F = ZERO
    for L in [1..FA_MAX_LEVELS]
      F = F.plus price
      price = price.times o.factor
      room = Decimal.pow(mult, L).times(horizon).minus(H)
      if room.greaterThan 0
        U = H.times(F).dividedBy(room).plus(F)
        need = Decimal.max(U.minus(o.held), 0).dividedBy(o.twin).ceil()
        return {levels: L, price: F, units: U, hatch: need, affordable: D(o.n)}
    return null

  # ---------------------------------------------------------------------------
  # Long-run climb mode helpers (ASCENSION.md A.10.2). Each mutates `mem` and the tier records passed.

  # Rule FA on one tier `x` that failed rule 1 (unit record `u`, tier above `up`). Mutates `x`, `mem` and `faTips`;
  # returns the larvae left. In order:
  # - a banked tier (rule 4) is left alone;
  # - the units held already pay for the levels (after an FA hatch, say): the levels' tip at 1x, and the row says so;
  # - in its cooldown (rule 3's earmark comes first): no hatch;
  # - n = floor(min(larvae left for the climb, tier below held / cost, meat left / meat price)): all that is
  #   affordable now. (The simulator caps the meat at half; the advisor uses the meat left after this visit's
  #   climb purchases above, as rule 3 has no meat share.) If the test passes with n, the tier is a buy of n
  #   ('fasterStart') with the levels' tip at 1x; else the "wait" line gets `fasterWait`'s clause, when some
  #   L <= FA_MAX_LEVELS could ever pass and n >= 1 (at least one affordable now).
  fasterStart = (x, u, up, mem, now, cfg, horizon, left, meatLeft, faTips, banksFor) ->
    if not u.prodCost? or not u.prodFactor? or banksFor(x, up)
      return left
    io = {H: x.H, horizon: horizon, mult: u.prodMult ? 2, price: u.prodCost, factor: u.prodFactor}
    count = if x.seed? then x.count.plus(x.seed.n.times x.twin) else x.count # with this look's seed line
    held = fasterTest _.extend({got: count}, io)
    if held.pass?
      lv = held.levels[held.pass - 1]
      x.faster = {type: 'held', levels: held.pass, price: lv.price, H: lv.H}
      faTips.push {type: 'faster', unit: x.name, cost: u.prodCost, levels: held.pass, total: lv.price, fasterStart: true}
      return left
    n = Decimal.min(left, x.affordable)
    if u.meatCost?
      n = Decimal.min n, Decimal.max(meatLeft, 0).dividedBy(u.meatCost)
    n = Decimal.max(n, 0).floor()
    since = (now - lastBuyTime(mem, x.name, u.purchases, now, cfg.cooldown)) / 1000
    if since >= cfg.cooldown and n.greaterThanOrEqualTo 1
      res = fasterTest _.extend({got: count.plus n.times(x.twin)}, io)
      if res.pass?
        lv = res.levels[res.pass - 1]
        x.kind = 'buy'
        x.reason = 'fasterStart'
        x.buys = n
        x.faster = {type: 'start', levels: res.pass, price: lv.price, H: lv.H, n: n}
        faTips.push {type: 'faster', unit: x.name, cost: u.prodCost, levels: res.pass, total: lv.price, fasterStart: true}
        return left.minus n
    # the clause only where the player can buy at least one now; for a tier they cannot buy it is clutter
    if n.greaterThanOrEqualTo 1
      w = fasterWait _.extend({held: count, twin: x.twin, n: n}, io)
      if w?
        x.faster = _.extend {type: 'wait'}, w
    return left

  # Larvae held for the next nexus under spareEnergy 'save' (ASCENSION.md A.11.9): the energy record's just-in-time
  # keep (`larvae.keep`, 0 while the record has none: no larva price, its meat missing or its larvae far).
  nexusLarvae = (energy, snap, cfg) ->
    return energy?.larvae?.keep ? ZERO

  # ---------------------------------------------------------------------------
  # Energy: nexus first, lepidoptera up to the target, then every point into House of Mirrors.
  # Returns null below one nexus.
  # `cfg.route` 'swarmwarp' (not a stored setting; `advise` passes it on that route): after nexus 5, bats and then
  # swarmwarp, one cast at a time, instead of House of Mirrors (NO-MIRRORS.md 12.2, 12.3).
  energyAdvice = (snap, cfg) ->
    route = cfg?.route ? null
    cfg = withDefaults cfg
    if route?
      cfg.route = route
    rec = energyRecord snap, cfg
    # the 'save' plan also says how many of the next nexus's larvae to keep from the climb, and why
    if rec? and cfg.spareEnergy == 'save' and snap.energy.nexus < 5 and snap.energy.next?
      plan = larvaPlan snap, cfg
      if plan?
        rec.larvae = plan
    return rec

  # spareEnergy 'save' (ASCENSION.md A.11.9): the next nexus's larvae to keep from the climb, just in time.
  # None while its meat is missing or its larvae are far (price over NEXUS_LARVA_SECS of larva income): the
  # climb is then what raises the larva rate. Otherwise, on the same larva clock as nexus5Plan's energy keep
  # (every larva on hand, the whole larva rate; ASCENSION.md A.11.9 tried leaving the territory share out: no gain):
  #   energyWait = seconds until its energy is there: (price - energy) / energy per s; at nexus 4 the first
  #     lepidoptera still to buy are paid first at today's rate, the price then at the rate they give;
  #     0 when the energy rate is not known (then everything is kept, as before)
  #   larvaWait = 0 if in hand, else (price - larvae) / larvae per s
  #   keep = min(larvae, ceil(max(0, price - larvae per s x max(energyWait, larvaWait))))
  # so all of them while larvae are what it waits for, and only what income will not bring before its energy
  # while energy is. Null when nothing applies.
  larvaPlan = (snap, cfg) ->
    e = snap.energy
    price = {}
    have = {}
    for c in e.next.costs
      price[c.unit] = c.val
      have[c.unit] = c.have
    if not price.larva?
      return null
    if price.meat? and have.meat.lessThan price.meat
      return null
    if price.larva.greaterThan snap.larvaRate.times(NEXUS_LARVA_SECS)
      return null
    onHand = have.larva
    if _.every(e.next.costs, (c) -> c.have.greaterThanOrEqualTo c.val)
      return {keep: Decimal.min(onHand, price.larva), price: price.larva, energyWait: 0, larvaWait: 0, binds: 'ready', level: e.nexus + 1}
    income = snap.larvaRate
    energyPrice = price.energy ? ZERO
    energyWait = 0
    rate = e.rate
    if e.energy.lessThan(energyPrice) or (e.nexus == 4 and e.moths.lessThan Math.min(cfg.moths, EARLY_MOTHS))
      if rate? and rate.greaterThan 0
        early = Math.min cfg.moths, EARLY_MOTHS
        if e.nexus == 4 and e.moths.lessThan early
          mothCost = D(early).minus(e.moths).times(MOTH_ENERGY)
          later = rate.times(1 + early / (1000 + early)).dividedBy(D(1).plus(e.moths.dividedBy(e.moths.plus(1000))))
          if e.energy.greaterThanOrEqualTo mothCost
            energyWait = Decimal.max(energyPrice.minus(e.energy.minus(mothCost)), 0).dividedBy(later).toNumber()
          else
            energyWait = mothCost.minus(e.energy).dividedBy(rate).plus(energyPrice.dividedBy(later)).toNumber()
        else
          energyWait = energyPrice.minus(e.energy).dividedBy(rate).toNumber()
    larvaWait = if have.larva.greaterThanOrEqualTo(price.larva) then 0 else if income.greaterThan(0) then Decimal.max(price.larva.minus(onHand), 0).dividedBy(income).toNumber() else Infinity
    wait = Math.max energyWait, larvaWait
    keep = if wait == Infinity then onHand else Decimal.min(onHand, Decimal.max(price.larva.minus(income.times(wait)), 0).ceil())
    binds = if wait == 0 then 'ready' else if energyWait > larvaWait then 'energy' else 'larvae'
    return {keep: keep, price: price.larva, energyWait: energyWait, larvaWait: larvaWait, binds: binds, level: e.nexus + 1}

  energyRecord = (snap, cfg) ->
    e = snap.energy
    nexus = e.nexus
    if not (nexus >= 1)
      return null
    if nexus == 4 and cfg.spareEnergy == 'save' and e.next?
      return nexus5Plan snap, cfg
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
    if nexus >= 5 and cfg.route == 'swarmwarp'
      return warpRecord e, spare
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

  # The swarmwarp route after nexus 5, once the lepidoptera are at the target (NO-MIRRORS.md 12.2, 12.3):
  # E3 bats up to SW.bats, floor(min(SW.bats - bats, spare / energy per bat)); then
  # E4 swarmwarp, ONE cast at a time: the record says how many are affordable and what one skips. After a cast the
  # game clock has moved on by the skip, the purchases it released come first, and the next cast after them
  # (`orderWarp`). Never 'cast xN' on this route.
  warpRecord = (e, spare) ->
    bats = e.bats ? ZERO
    if bats.lessThan SW.bats
      price = e.batPrice ? D(100)
      n = Decimal.min(D(SW.bats).minus(bats), spare.dividedBy(price)).floor()
      if n.greaterThanOrEqualTo 1
        return {type: 'buyBats', count: n, bats: bats, target: SW.bats, price: price}
      return {type: 'batTarget', bats: bats, target: SW.bats, price: price, energy: e.energy}
    cost = e.warp?.cost ? D(SPELLS.swarmwarp.cost)
    k = spare.dividedBy(cost).floor()
    if k.greaterThanOrEqualTo 1
      return {type: 'warp', spell: SPELLS.swarmwarp.spell, label: SPELLS.swarmwarp.label, cost: cost, casts: ONE, affordable: k, skip: e.warp?.skip ? null}
    return {type: 'nextCast', spell: SPELLS.swarmwarp.spell, label: SPELLS.swarmwarp.label, cost: cost, energy: e.energy}

  # One swarmwarp at a time, with the purchases between (NO-MIRRORS.md 12.3): a 'warp' record waits ('warpAfter')
  # while the panel's other lines have purchases open, so what one warp released is bought before the next:
  #   - climb rows to buy (each goes into its 60 s cooldown once bought);
  #   - seed lines whose tier was last hatched WARP_HOLD_SEED_SECS or more ago on the game clock (new since a warp
  #     or an absence; a 1% line refilled after 60 s does not hold it);
  #   - faster and twin tips (twin plans are steps over time, so they do not hold it);
  #   - territory: hatchery / expansion / ancestry levels, an empower, a territory twin to buy; and territory units
  #     to hatch while they are more than WARP_HOLD_TERRITORY_SECS of the territory share's larva income (the purse
  #     refills every second, so a smaller line would hold the warp for ever).
  # `meat` is this service's advice, `terr` the territory advice (either may be null). Other records unchanged.
  orderWarp = (rec, meat, terr) ->
    if rec?.type != 'warp'
      return rec
    pending = {climb: 0, tips: 0, territory: 0}
    for t in meat?.tiers ? [] when t.kind == 'buy' or (t.kind == 'seed' and t.seed.since >= WARP_HOLD_SEED_SECS)
      pending.climb += 1
    for t in meat?.tips ? [] when t.type in ['faster', 'twin']
      pending.tips += 1
    if terr?
      for r in terr.records ? []
        if r.type in ['upgrade', 'empower', 'twin']
          pending.territory += 1
      rate = meat?.larvaRate ? null
      share = terr.share ? 0
      big = (h) -> not rate? or h.buys.greaterThan rate.times(share).times(WARP_HOLD_TERRITORY_SECS)
      if _.some(terr.hatch ? [], big)
        pending.territory += 1
    if pending.climb + pending.tips + pending.territory == 0
      return rec
    return _.extend {}, rec, type: 'warpAfter', pending: pending

  # spareEnergy 'save' at nexus 4 (ASCENSION.md A.11), in this order:
  # 1. nexus 5, if everything it costs is in hand;
  # 2. the first EARLY_MOTHS lepidoptera (or the target, if lower), with all the energy there is;
  # 3. energy beyond what nexus 5 needs "just in time" into lepidoptera, up to the target. While its meat
  #    is missing, that is the whole price. Once its meat is in hand and only larvae (and energy) are
  #    missing, it is the price less what the energy income brings before the larvae are there:
  #    keep = max(0, price - energy/s x larvae missing / larvae per s), the larvae counted only while they
  #    are held for it (larva price under NEXUS_LARVA_SECS of income, as for saving), else from 0;
  # 4. then save (its meat in hand, its larvae near), one larva rush if energy is at its cap, or hold.
  # Holding the whole price from the start (the earlier 'save') let energy sit at the 40,000 cap for
  # hours while the larvae came, under a person's cadence.
  nexus5Plan = (snap, cfg) ->
    e = snap.energy
    energy = e.energy
    moths = e.moths
    need = {}
    missing = []
    for c in e.next.costs
      need[c.unit] = c
      if c.have.lessThan c.val
        missing.push c
    if not missing.length
      return {type: 'buyNexus', level: 5}
    meatReady = not _.some missing, (c) -> c.unit == 'meat'
    larva = need.larva
    larvaNear = not larva? or larva.val.lessThanOrEqualTo(snap.larvaRate.times(NEXUS_LARVA_SECS))
    # as for saving below: its meat in hand and its larvae near, so the climb keeps the larvae for it
    saving = null
    if meatReady and larvaNear
      saving = {type: 'save', level: 5, missing: ({unit: c.unit, have: c.have, need: c.val} for c in missing)}
    # targets are plain numbers in the records, as the console script's
    target = cfg.moths
    early = Math.min target, EARLY_MOTHS
    if moths.lessThan early
      n = Decimal.min(D(early).minus(moths), energy.dividedBy(MOTH_ENERGY)).floor()
      if n.greaterThanOrEqualTo 1
        return {type: 'buyMoths', count: n, moths: moths, target: early, early: true, then: saving}
      return {type: 'mothTarget', moths: moths, target: early, early: true, then: saving}
    price = need.energy?.val ? ZERO
    keep = price
    wait = null # seconds until nexus 5's larvae are there, when that sets how much energy to keep
    if meatReady and larva? and larva.have.lessThan(larva.val) and e.rate? and e.rate.greaterThan(0) and snap.larvaRate.greaterThan(0)
      have = if larvaNear then larva.have else ZERO
      wait = larva.val.minus(have).dividedBy(snap.larvaRate)
      keep = Decimal.min price, Decimal.max(price.minus(e.rate.times(wait)), 0).ceil()
    spare = Decimal.max energy.minus(keep), 0
    if moths.lessThan target
      n = Decimal.min(D(target).minus(moths), spare.dividedBy(MOTH_ENERGY)).floor()
      if n.greaterThanOrEqualTo 1
        rec = {type: 'buyMoths', count: n, moths: moths, target: target, then: saving}
        if keep.lessThan price
          rec.keep = keep
          rec.wait = wait.toNumber()
        return rec
    if saving
      if keep.lessThan price
        return _.extend {}, saving, keep: keep, wait: wait.toNumber(), keepIdle: energy.greaterThanOrEqualTo(keep)
      return saving
    if e.cap? and energy.greaterThanOrEqualTo(e.cap)
      return {type: 'energyFull', energy: energy, cap: e.cap, spell: SPELLS.larvarush.spell, label: SPELLS.larvarush.label, cost: SPELLS.larvarush.cost}
    hold = {type: 'hold', level: 5, energy: energy, price: price, ready: energy.greaterThanOrEqualTo(price), missing: ({unit: c.unit, have: c.have, need: c.val} for c in missing when c.unit != 'energy'), mothsNext: false}
    if keep.lessThan price
      hold.keep = keep
      hold.wait = wait.toNumber()
      hold.keepIdle = energy.greaterThanOrEqualTo keep
    return hold

  # ---------------------------------------------------------------------------
  # Plain-text rendering, matching the console script's wording.

  renderAction = (t) ->
    switch t.reason
      when 'tooSlow' then 'wait ' + formatTime(t.waitSeconds) + renderFasterWhy(t)
      when 'fasterStart'
        'BUY ' + formatNumber(t.buys) + (if t.twin.greaterThan(1) then ' (x' + formatNumber(t.twin) + ' twins)' else '') +
          ' and ' + t.faster.levels + ' faster ' + t.name + ' level' + (if t.faster.levels == 1 then '' else 's') + ' (' + formatNumber(t.faster.price) + '): with them ' + t.name + 's pay back inside the horizon'
      when 'needBelow' then 'need more ' + t.below + 's'
      when 'bank' then 'skip: bank larvae for ' + t.bankFor + 's'
      when 'cooldown' then 'done, next in ' + formatTime(t.waitSeconds)
      when 'buy' then 'BUY ' + formatNumber(t.buys) + (if t.twin.greaterThan(1) then ' (x' + formatNumber(t.twin) + ' twins)' else '')
      when 'larvaeUsedAbove' then 'skip: larvae used above'
      when 'buildUp' then 'let ' + t.below + 's build up'
      # rule SEED
      when 'seed' then 'seed upward: ' + renderSeed(t) + renderFasterWhy(t)
      else ''

  # rule FA's clause on a "wait" line: " - with 3 faster levels (2.93e7 empresss) they would pay back once 2.69e8 are
  # bought; you can afford 1.04e7", or the levels to buy when the units held already pay for them
  renderFasterWhy = (t) ->
    f = t.faster
    if not f? then return ''
    levels = f.levels + ' faster level' + (if f.levels == 1 then '' else 's')
    if f.type == 'held'
      return ' - buy ' + levels + ' (' + formatNumber(f.price) + ' ' + t.name + 's) and they pay back inside the horizon'
    if f.type == 'wait'
      return ' - with ' + levels + ' (' + formatNumber(f.price) + ' ' + t.name + 's) they would pay back once ' + formatNumber(f.hatch) + ' are bought; you can afford ' + formatNumber(f.affordable)
    return ''

  # "hatch 3.40e8 prophets (1% of what your empresss buy)": what bound the count
  renderSeed = (t) ->
    why = switch t.seed.binding
      when 'larvae' then "1% of the climb's larvae"
      when 'meat' then 'half your meat'
      when 'left' then 'all the larvae left'
      else '1% of what your ' + t.seed.below + 's buy'
    'hatch ' + formatNumber(t.buys) + ' ' + t.name + (if t.buys.equals(1) then '' else 's') + (if t.twin.greaterThan(1) then ' (x' + formatNumber(t.twin) + ' twins)' else '') + ' (' + why + ')'


  renderStep = (step) ->
    if step.type == 'twin'
      return 'twin ' + step.unit + 's'
    return 'hatch ' + formatNumber(step.count) + ' ' + step.unit + (if step.count.equals(1) then '' else 's')

  renderTip = (tip) ->
    switch tip.type
      when 'faster'
        if tip.levels? and tip.levels > 1
          'faster ' + tip.unit + 's x' + tip.levels + ' (' + formatNumber(tip.total) + ')'
        else
          'faster ' + tip.unit + 's (' + formatNumber(tip.cost) + ')'
      when 'twin' then 'twin ' + tip.unit + 's (' + formatNumber(tip.cost) + ' ' + tip.payIn + 's)'
      when 'twinPlan'
        (renderStep(s) for s in tip.steps).join(' > ') + ' > twin ' + tip.unit + 's (pays back in ' + formatTime(tip.payback) + ')'
      else ''

  # Why a lepidoptera target is what it is, when it is not simply the setting.
  RUN_STAGE = {firstRun: 'first-run target', needMutation: 'first-run target', longRun: 'long-run target', quickRun: 'quick-run target', swarmwarp: 'swarmwarp route'}
  mothWhy = (rec, sep) ->
    if rec.early then return sep + 'first ' + formatNumber(rec.target) + ' before nexus 5'
    if rec.runStage? then return sep + (RUN_STAGE[rec.runStage] ? 'run target')
    return ''

  # "; keeping 12,000 energy for nexus 5 (its larvae in 9.6 h)"
  renderKeep = (rec) ->
    if not rec.keep? then return ''
    if rec.keep.isZero() then return '; nothing kept for nexus 5 yet (its larvae in ' + formatTime(rec.wait) + ')'
    '; keeping ' + formatNumber(rec.keep) + ' energy for nexus 5 (its larvae in ' + formatTime(rec.wait) + ')'

  renderSaving = (rec) ->
    'save for nexus ' + rec.level + ': ' + ((formatNumber(m.have) + '/' + formatNumber(m.need) + ' ' + m.unit) for m in rec.missing).join(', ') +
      (if rec.keep? and rec.keepIdle then '; ' + (if rec.keep.isZero() then 'no energy' else 'only ' + formatNumber(rec.keep) + ' energy') + ' needed now: income brings the rest before the larvae (' + formatTime(rec.wait) + ')' else '')

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
    if rec.keep? and rec.keepIdle
      text += '; ' + (if rec.keep.isZero() then 'none' else 'only ' + formatNumber(rec.keep)) + ' needed now: income brings the rest before its larvae (' + formatTime(rec.wait) + ')'
    return text

  # "; keeping no larvae for nexus 5 yet: its energy is 11.9 h away, its larvae 3.6 h" (the 'save' plan)
  renderLarvae = (rec) ->
    lp = rec?.larvae
    if not lp? then return ''
    times = formatTime(lp.energyWait) + ' away, its larvae ' + formatTime(lp.larvaWait)
    if lp.binds == 'ready'
      return '; keeping its ' + formatNumber(lp.keep) + ' larvae'
    if lp.binds == 'larvae'
      return '; keeping all ' + formatNumber(lp.keep) + ' larvae for nexus ' + lp.level + ': larvae are what it waits for (' + formatTime(lp.larvaWait) + '; energy ' + formatTime(lp.energyWait) + ')'
    if lp.keep.isZero()
      return '; keeping no larvae for nexus ' + lp.level + ' yet: its energy is ' + times
    '; keeping ' + formatNumber(lp.keep) + ' larvae for nexus ' + lp.level + ', the rest come in before its energy (' + formatTime(lp.energyWait) + ')'

  # Without the "energy: " prefix the panel puts in front. Null for null.
  renderEnergy = (rec) ->
    text = renderEnergyRecord rec
    if text? then text += renderLarvae(rec)
    return text

  renderEnergyRecord = (rec) ->
    if not rec?
      return null
    switch rec.type
      when 'buyNexus' then 'buy nexus ' + rec.level
      when 'save' then renderSaving rec
      when 'buyMoths'
        want = 'lepidoptera ' + formatNumber(rec.moths) + '/' + formatNumber(rec.target) + mothWhy(rec, ', ')
        'buy ' + formatNumber(rec.count) + ' lepidoptera (' + want + ')' + renderKeep(rec) + (if rec.then then '; then ' + renderSaving(rec.then) else '')
      when 'mothTarget' then 'all energy into lepidoptera ' + formatNumber(rec.moths) + '/' + formatNumber(rec.target) + (if mothWhy(rec, '') then ' (' + mothWhy(rec, '') + ')' else '') + (if rec.then then '; then ' + renderSaving(rec.then) else '')
      when 'cast' then 'cast ' + rec.label + ' x' + formatNumber(rec.casts)
      # the swarmwarp route (NO-MIRRORS.md 12.2, 12.3)
      when 'buyBats' then 'buy ' + formatNumber(rec.count) + ' bats (' + formatNumber(rec.bats) + '/' + formatNumber(rec.target) + ', before the first swarmwarp: they raise its power)' + (if rec.thenSave then ', then save for the ascension' else '')
      when 'batTarget' then 'all energy into bats ' + formatNumber(rec.bats) + '/' + formatNumber(rec.target) + ' (' + formatNumber(rec.price) + ' energy each), then swarmwarp'
      when 'warp' then renderWarp(rec) + '; then follow the other lines: the next swarmwarp is suggested after them'
      when 'warpAfter' then 'next: ' + renderWarp(rec) + ', once the purchases on the other lines are made (' + renderPending(rec.pending) + ')'
      when 'nextCast' then 'next ' + rec.label + ' at ' + formatNumber(rec.cost) + ' energy (have ' + formatNumber(rec.energy) + ')'
      when 'hold' then renderHold rec
      when 'energyFull'
        'energy is full (' + formatNumber(rec.energy) + '/' + formatNumber(rec.cap) + '): cast ' + rec.label + ' x1 so the income is not wasted'
      else ''

  # "cast 1 swarmwarp (5 affordable): skips 27.8 d"
  renderWarp = (rec) ->
    'cast 1 swarmwarp (' + formatNumber(rec.affordable) + ' affordable' + (if rec.thenSave then ' before saving for the ascension' else '') + ')' +
      (if rec.skip? then ': skips ' + formatTime(rec.skip) else '')

  # "2 climb rows, 1 upgrade tip, 1 territory line"
  renderPending = (p) ->
    parts = []
    plural = (n, one) -> n + ' ' + one + (if n == 1 then '' else 's')
    if p.climb then parts.push plural(p.climb, 'climb row')
    if p.tips then parts.push plural(p.tips, 'upgrade tip')
    if p.territory then parts.push plural(p.territory, 'territory line')
    parts.join ', '

  renderHeader = (r) ->
    'run ' + formatTime(r.age) + ' | climb if H < ' + formatTime(r.horizon) + ' | larvae ' + formatNumber(r.larvae) + ' (+' + formatNumber(r.larvaRate) + '/s)'

  # ---------------------------------------------------------------------------
  # Live wiring for the panel: one remembered state per page load.

  liveMemory = null

  # The ascension route's lepidoptera target for this run ({moths, stage}, from advisorAscension), looked
  # up lazily because that service depends on this one. Null when the route is off or has none; never
  # throws (a failure there only loses the run target).
  runTarget = ->
    try
      return $injector.get('advisorAscension').current(ADVISOR_REFRESH_MILLIS)?.advice?.moths ? null
    catch e
      return null
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
    renderSeed: renderSeed
    LR: LR
    EARLY_MOTHS: EARLY_MOTHS
    larvaPlan: larvaPlan
    renderLarvae: renderLarvae
    SEED: SEED
    WARP_HOLD_SEED_SECS: WARP_HOLD_SEED_SECS
    fasterTest: fasterTest
    fasterWait: fasterWait
    FA_MAX_LEVELS: FA_MAX_LEVELS
    # routes and clocks (NO-MIRRORS.md 11-13)
    SW: SW
    EXPANSION_GOAL: EXPANSION_GOAL
    WARP_HOLD_TERRITORY_SECS: WARP_HOLD_TERRITORY_SECS
    routeOf: routeOf
    routeFacts: routeFacts
    gameClock: gameClock
    liveKey: liveKey
    orderWarp: orderWarp
    renderPending: renderPending
    # live
    config: -> options.advisorConfig()
    enabled: -> options.advisorEnabled()
    update: (now) ->
      cfg = options.advisorConfig()
      # the ascension route's run target for lepidoptera (null while the route is off or has none)
      run = runTarget()
      if run?
        cfg = _.extend {}, cfg, runMoths: run.moths, runStage: run.stage
      result = advise snapshot(game, now), liveMemory, cfg
      liveMemory = result.memory
      return result
    memory: -> liveMemory
    resetMemory: ->
      liveMemory = null
      cached = null
    suggestionFor: suggestionFor
    # The latest advice, re-running `update()` only when the cached result is at least `maxAgeMs`
    # old (wall clock), or at once when a setting changed or a swarmwarp was cast (`liveKey`): a warp releases
    # every cooldown, so the panel must not show "next in 59 s" for up to a second after it. Never throws:
    # returns {at, advice, error}, with `error` set (and `advice` null) when `update()` threw. `wallNow` is for tests.
    current: (maxAgeMs=1000, wallNow=Date.now()) ->
      key = liveKey()
      if not cached? or wallNow - cached.at >= maxAgeMs or wallNow < cached.at or cached.key != key
        try
          cached = {at: wallNow, key: key, advice: svc.update(), error: null}
        catch e
          cached = {at: wallNow, key: key, advice: null, error: e}
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
