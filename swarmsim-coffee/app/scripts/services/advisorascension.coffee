'use strict'

###*
 # @ngdoc service
 # @name swarmApp.advisorAscension
 # @description
 # Ascension advice for the climbing advisor, on the "achievements route" of advisor/ASCENSION.md
 # (Part A: every achievement and a bunch of endless, no crystals). Off unless the advisor setting
 # `ascension` is 'achievements'; while it is off nothing here reads the game and every other line of
 # the panel is exactly as without it.
 #
 # Same design as the other advisor services: `snapshot()` is the only place live game objects are
 # read; `advise()` is a pure function of that plain snapshot and the settings, returning typed records;
 # `render()` gives the reference wording. There is no remembered state: every number is re-read.
 #
 # The stage of the route is worked out from the game, never asked (ASCENSION.md A.1, A.5):
 # - firstRun: never ascended. Spend energy (House of Mirrors) while that lowers the ascension cost by
 #   more than it uses, then save, then ascend.
 # - needMutation: ascended, but the lepidoptera mutation is neither unlocked nor affordable. Another
 #   run like the first.
 # - longRun: the lepidoptera mutation is unlocked (or affordable now) and an achievement the long run
 #   is for is still missing: an expansion level (single-run: expansions reset at an ascension) or an
 #   endless bought (cumulative, but only a long run climbs that far). Do not ascend.
 # - quickRun: those are earned, fewer ascensions than the largest ascension achievement asks. Spend,
 #   save, ascend, as in the first run.
 # - done: every ascension achievement and every long-run achievement earned.
 # Separately, after any ascension: the mutagen purchases of the plan still outstanding and affordable.
###
angular.module('swarmApp').factory 'advisorAscension', (game, advisor, options, $rootScope) ->
  ZERO = new Decimal 0
  D = (x) -> new Decimal(if x? then x else 0)
  LN2 = Math.log 2

  ROUTE = 'achievements'
  WARP_ROUTE = 'swarmwarp' # NO-MIRRORS.md section 12 (advisor.SW holds its numbers)
  SW = advisor.SW
  # 12.7 step 4: a share short by less than this part of its target counts as held. The amounts are past 2^53
  # (1e32 and up), where Decimal and float arithmetic keep 15-17 digits: without this, the shares bought at the last
  # ascension come out "short" by rounding (1e16 of 1e32) and the line would never be done.
  SHARE_TOLERANCE = 1e-9
  # ASCENSION.md A.1 stage 2 / A.5: unlock the lepidoptera ("nexus") mutation first and buy about a
  # million of it (energy x1.998); keep at least that many later.
  NEXUS_UNLOCK = 'mutatenexus'
  NEXUS_MUTANTS = 1e6
  # A.1 stage 2: at the first ascension, two unlocks (lepidoptera and any second; the third costs
  # 2.44e8, more than a first run brings). A.1 stage 4: from the second ascension, all of them.
  FIRST_UNLOCKS = 2
  # The halving energy is measured from the game's own cost function at two amounts of energy spent.
  PROBE_SPENT = 1e5
  MOTH_ENERGY = 10 # energy per lepidoptera (game data), as advisor.coffee
  # Energy line records that spend energy; while saving for the ascension they give way to the save.
  SPENDING = ['cast', 'nextCast', 'buyMoths', 'mothTarget', 'energyFull', 'warp', 'warpAfter', 'buyBats', 'batTarget']
  # ASCENSION.md A.11: the lepidoptera target after nexus 5 for each kind of run (the advisor's `moths`
  # setting still applies when it is higher). Every lepidoptera counts as energy spent, as a House of
  # Mirrors cast does, and raises the energy rate besides, so a run that is only waiting to ascend wants
  # many. A first run (or one still short of the lepidoptera mutation) stops at 10,000 so mirrors still
  # bring the mutagen the plan spends (~1e7 with it, ~1.5e5 with 30,000); a quick run takes 30,000; the
  # long run takes 30,000 from a run age of 3 days, as the long-run mode's LR-4 does.
  RUN_MOTHS = {firstRun: 10000, needMutation: 10000, quickRun: 30000}

  isOn = (cfg) -> cfg?.ascension in [ROUTE, WARP_ROUTE]

  # ---------------------------------------------------------------------------
  # Snapshot.

  goalsOf = (g) ->
    expansion = []
    endless = []
    ascension = []
    mutation = []
    for a in g.achievementlist()
      req = a.requires[0]
      # unit and upgrade achievements only (event achievements have no number to reach)
      if not req? or not req.val? or not (req.unit? or req.upgrade?)
        continue
      goal =
        name: a.name
        label: a.type.label
        val: D req.val
        earned: a.isEarned()
        # upgrades outside the mutagen tab go back to 0 at an ascension (game.coffee, ascend())
        perRun: req.upgrade? and req.upgrade.unit?.tab?.name != 'mutagen'
      if req.upgrade?.name == 'expansion'
        expansion.push goal
      else if req.unit?.name == 'overmind6'
        endless.push goal
      else if req.unit?.name == 'ascension'
        ascension.push goal
      else if req.upgrade?.name == 'mutatehidden' # unlocks held (the swarmwarp route's stages read the last)
        mutation.push goal
    byVal = (list) -> list.sort (a, b) -> a.val.comparedTo b.val
    return {expansion: byVal(expansion), endless: byVal(endless), ascension: byVal(ascension), mutation: byVal(mutation)}

  snapshot = (g=game, now) ->
    now ?= if g.now? then g.now.getTime() else new Date().getTime()
    energy = g.unit 'energy'
    mutagen = g.unit 'mutagen'
    cost = D g.ascendCost()
    c0 = D g.ascendCost(spent: 0)
    c1 = D g.ascendCost(spent: PROBE_SPENT)
    # the ten "mutate ..." unlocks: one level each, and each comes with its mutant unit
    unlockUps = _.filter mutagen.upgrades.list, (up) ->
      up.type.maxlevel == 1 and _.some(up.effect, (e) -> e.type.name == 'addUnit')
    unlocks = for up in unlockUps
      effect = _.find up.effect, (e) -> e.type.name == 'addUnit'
      price = up.totalCost()[0]
      name: up.name
      label: up.type.label
      unit: effect?.unit?.name ? null
      unlocked: up.count().greaterThanOrEqualTo 1
      price: D price.val
      factor: D price.factor
      have: if effect?.unit? then D(effect.unit.count()) else ZERO # mutants held
      mutantPrice: if effect?.unit? then D(effect.unit.eachCost()[0].val) else D(1) # mutagen per mutant
    nexusMutant = g.unit 'mutantnexus'
    top = null
    for name in advisor.CHAIN
      if g.unit(name).count().greaterThanOrEqualTo 1
        top = name
    stats = g.unit('overmind6').statistics?() ? {}
    dates = g.session.state.date
    refund = null
    try
      # what a respec gives back, as the game works it out (game.coffee _respec)
      refund = D(g.respecSpent()).times(g.respecRate()).floor()
    catch e
      refund = null
    return {
      now: now
      route: advisor.routeFacts g
      mirrorCasts: D(g.upgrade('clonearmy').count()).toNumber()
      unlockCount: D(g.upgrade('mutatehidden').count()).toNumber()
      freeRespecs: D(g.unit('freeRespec').count()).toNumber()
      refund: refund
      restartedAt: new Date(dates.restarted or dates.started).getTime()
      ascensions: D(g.unit('ascension').count()).toNumber()
      energy: D energy.count()
      cap: if energy.capValue()? then D(energy.capValue()) else null
      rate: D energy.velocity() # energy per second
      spent: D g.ascendEnergySpent()
      cost: cost
      # energy spent that halves the cost: 50,000 x the lepidoptera mutation's factor (game.coffee,
      # ascendCost), measured from the cost function rather than restated
      halving: PROBE_SPENT / (Math.log(c0.dividedBy(c1).toNumber()) / LN2)
      nexus: D(g.unit('nexus').count()).toNumber()
      premutagen: D g.unit('premutagen').count()
      mutagen: D mutagen.count()
      unlocks: unlocks
      nexusMutants: D nexusMutant.count()
      nexusMutantPrice: D nexusMutant.eachCost()[0].val # mutagen per lepidoptera mutation
      expansion: D(g.upgrade('expansion').count()).toNumber()
      top: top # highest meat tier owned this run
      endlessBought: D(stats.twinnum ? 0) # what the endless achievements count
      goals: goalsOf g
    }

  # ---------------------------------------------------------------------------
  # Rules.

  # Spend, save or ascend, from the cost formula (ASCENSION.md B2.2): spending E energy lowers the cost
  # by about cost x E x ln 2 / halving, so spending beats saving until the cost is halving / ln 2
  # (72,135 without the lepidoptera mutation, up to 115,416 with it), and it has to fall under the
  # energy cap before it can be paid at all. Saving starts at the lower of the two.
  plan = (snap) ->
    threshold = D(snap.halving / LN2).floor()
    saveAt = if snap.cap? then Decimal.min(snap.cap, threshold) else threshold
    base =
      cost: snap.cost
      energy: snap.energy
      cap: snap.cap
      halving: snap.halving
      threshold: threshold
      saveAt: saveAt
      ascension: snap.ascensions + 1
    if snap.energy.greaterThanOrEqualTo snap.cost
      return _.extend base, type: 'ascendNow', premutagen: snap.premutagen, mutagen: snap.mutagen
    if snap.cost.lessThanOrEqualTo saveAt
      need = snap.cost.minus snap.energy
      return _.extend base,
        type: 'saveForAscension'
        need: need
        rate: snap.rate
        seconds: if snap.rate.greaterThan(0) then need.dividedBy(snap.rate).toNumber() else null
    # energy still to spend before saving starts: halving x log2(cost / saveAt). None while the cap is
    # 0 (no nexus yet after an ascension).
    toSpend = null
    if saveAt.greaterThan 0
      toSpend = D(snap.halving * Math.log(snap.cost.dividedBy(saveAt).toNumber()) / LN2).ceil()
    return _.extend base, type: 'spendForAscension', toSpend: toSpend, nexus: snap.nexus

  # The mutagen purchases of the plan still outstanding and affordable now, in order: unlock the
  # lepidoptera mutation, buy lepidoptera mutations up to a million, then the other unlocks (one more
  # after the first ascension, all of them from the second). Null when there is nothing to buy.
  mutagenPlan = (snap) ->
    if snap.ascensions < 1 or not snap.mutagen.greaterThan(0)
      return null
    budget = snap.mutagen
    steps = []
    nexus = _.find snap.unlocks, name: NEXUS_UNLOCK
    locked = (u for u in snap.unlocks when not u.unlocked)
    # every locked unlock has the same price, the next in the 1, 15,625, 15,625^2... sequence
    price = if locked.length then locked[0].price else null
    factor = if locked.length then locked[0].factor else null
    unlocked = snap.unlocks.length - locked.length
    mutants = snap.nexusMutants
    if nexus? and not nexus.unlocked
      if budget.lessThan nexus.price
        return null
      steps.push {type: 'unlock', name: nexus.name, label: nexus.label, unit: nexus.unit, price: nexus.price}
      budget = budget.minus nexus.price
      price = price.times factor
      unlocked += 1
      locked = (u for u in locked when u.name != nexus.name)
      mutants = mutants.plus 1 # each unlock comes with one free mutant
    if mutants.lessThan(NEXUS_MUTANTS) and nexus?.unit?
      n = Decimal.min(D(NEXUS_MUTANTS).minus(mutants), budget.dividedBy(snap.nexusMutantPrice)).floor()
      if n.greaterThanOrEqualTo 1
        steps.push {type: 'mutants', unit: nexus.unit, count: n, have: mutants, target: D(NEXUS_MUTANTS), price: n.times(snap.nexusMutantPrice)}
        budget = budget.minus n.times(snap.nexusMutantPrice)
    wanted = if snap.ascensions >= 2 then snap.unlocks.length else FIRST_UNLOCKS
    k = 0
    total = ZERO
    while unlocked + k < wanted and k < locked.length and budget.greaterThanOrEqualTo(price)
      budget = budget.minus price
      total = total.plus price
      price = price.times factor
      k += 1
    if k > 0
      steps.push {type: 'unlocks', count: k, price: total, remaining: locked.length, all: k == locked.length, any: snap.ascensions < 2}
    if not steps.length
      return null
    return {type: 'mutagen', mutagen: snap.mutagen, steps: steps, keep: budget}

  # {moths, stage}: this run's lepidoptera target after nexus 5 (RUN_MOTHS), or null.
  runMoths = (stage, snap) ->
    if RUN_MOTHS[stage]?
      return {moths: RUN_MOTHS[stage], stage: stage}
    if stage == 'longRun' and (snap.now - snap.restartedAt) / 1000 >= advisor.LR.mothAge
      return {moths: advisor.LR.moths, stage: stage}
    return null

  nextGoal = (goals, have) ->
    for g in goals when not g.earned
      if have.lessThan g.val
        return g
    return null

  # The route (`advisor.routeOf`) is worked out from the settings and the game every time:
  # - 'achievements': the mirrors route below (ASCENSION.md part A), unchanged;
  # - 'swarmwarp': `warpAdvise` (NO-MIRRORS.md 12.6, 12.7); a run caught by the near-complete guard is finished as
  #   the mirrors route's long run (this function, stage forced to longRun), with the swarmwarp route's mutagen line
  #   (mutagen purchases outlive the run, and the swarmwarp route resumes after it) and a line saying why.
  advise = (snap, cfg) ->
    records = []
    if not isOn cfg
      return {stage: 'off', records: records, hold: null, plan: null, mutagen: null, moths: null}
    route = advisor.routeOf cfg, snap.route
    if route.route == 'swarmwarp'
      return warpAdvise snap, cfg, route
    if route.guard?
      # the run is a House of Mirrors run: no respec (it would drop mutations this run uses) and no swarmwarp-route
      # shares (they spend mutagen that makes larvae now, for warps this run will not cast); only the unlocks and the
      # lepidoptera and frequency mutations, which serve both routes
      return _.extend mirrorsAdvise(snap, cfg, warpMutagen(snap, {respec: false, shares: false}), route.guard), route: route
    return _.extend mirrorsAdvise(snap, cfg, mutagenPlan(snap), null), route: route

  mirrorsAdvise = (snap, cfg, mut, guard) ->
    records = []
    goals = snap.goals
    longLeft = (g for g in goals.expansion.concat(goals.endless) when not g.earned)
    target = if goals.ascension.length then _.last(goals.ascension).val.toNumber() else null
    ascLeft = (g for g in goals.ascension when not g.earned)
    nexus = _.find snap.unlocks, name: NEXUS_UNLOCK
    hasNexus = nexus?.unlocked or (mut? and mut.steps[0].name == NEXUS_UNLOCK)
    if guard?
      stage = 'longRun' # the near-complete guard: never ascend this run (it is never a first run)
    else if snap.ascensions == 0
      stage = 'firstRun'
    else if longLeft.length and not hasNexus
      stage = 'needMutation'
    else if longLeft.length
      stage = 'longRun'
    else if ascLeft.length
      stage = 'quickRun'
    else
      stage = 'done'

    p = null
    if stage in ['firstRun', 'needMutation', 'quickRun']
      p = _.extend plan(snap), stage: stage, of: target
      # these runs are for the lepidoptera mutation: an ascension that brings no mutagen (none yet from
      # hatcheries or expansions) cannot pay for it
      if stage != 'quickRun' and p.type == 'ascendNow' and nexus? and p.premutagen.plus(p.mutagen).lessThan(nexus.price)
        p.noMutagen = true
      line = p
    else if stage == 'longRun'
      line =
        type: 'longRun'
        expansion: snap.expansion
        nextExpansion: nextGoal(goals.expansion, D snap.expansion)
        lastExpansion: if goals.expansion.length then _.last(goals.expansion) else null
        top: snap.top
        endlessBought: snap.endlessBought
        nextEndless: nextGoal(goals.endless, snap.endlessBought)
        ascensions: snap.ascensions
        of: target
        climbMode: cfg.longRun == 'on' # whether the advisor's long-run climb mode is on (a hint if not)
    else
      line = {type: 'done', ascensions: snap.ascensions}
    if mut?
      records.push mut
    if guard?
      records.push _.extend({}, guard, type: 'routeGuard')
    records.push line
    return {
      stage: stage
      records: records
      mutagen: mut
      plan: p
      moths: runMoths(stage, snap)
      # once saving has started (or the energy is there), the energy line holds instead of spending
      hold: if p?.type in ['saveForAscension', 'ascendNow'] then p else null
    }

  # ---------------------------------------------------------------------------
  # The swarmwarp route (NO-MIRRORS.md 12.6-12.8), from the game state alone.

  lastGoal = (list) -> if list?.length then _.last(list) else null

  # 12.6: done / quick / final / build.
  warpStage = (snap) ->
    goals = snap.goals
    exp = lastGoal goals.expansion
    longGoals = _.compact [exp, lastGoal(goals.endless), lastGoal(goals.mutation)]
    target = lastGoal(goals.ascension)?.val.toNumber() ? 0
    if not _.some(longGoals, (g) -> not g.earned)
      return if snap.ascensions < target then 'quick' else 'done'
    if warpWealth(snap).greaterThanOrEqualTo(D('1e' + SW.finalLog10)) and not exp?.earned
      return 'final'
    return 'build'

  # 12.6 final, as the port tests it (a deliberate departure from warp_route.py, NO-MIRRORS.md 12.6): mutagen held
  # plus the mutants the route's shares buy (warp, bat, territory, meta-mutation; unlocked kinds), in mutagen. The
  # mutagen line moves mutagen into those mutants one for one, so following it leaves this, and the stage, unchanged;
  # unspent mutagen alone would drop below 1e270 once the shares are bought (about 51% of it) and turn a final run
  # back into a build run.
  warpWealth = (snap) ->
    w = snap.mutagen
    for [mu, sh] in SW.shares
      u = _.find snap.unlocks, unit: mu
      if u?.unlocked and u.have?
        w = w.plus u.have.times(u.mutantPrice ? 1)
    return w

  # 12.6 build: premutagen >= SW.ratio x max(mutagen held, 1).
  warpTest = (snap) ->
    need = Decimal.max(snap.mutagen, 1).times SW.ratio
    return {passes: snap.premutagen.greaterThanOrEqualTo(need), premutagen: snap.premutagen, held: snap.mutagen, ratio: SW.ratio, need: need}

  # 12.7 step 1: a free respec, when the warp mutation is not unlocked, the next unlock costs more than the mutagen
  # held, a free respec is left, and held + what the respec gives back pays for the lepidoptera and warp unlocks.
  warpRespec = (snap) ->
    warp = _.find snap.unlocks, name: 'mutateswarmwarp'
    if not warp? or warp.unlocked or not (snap.freeRespecs >= 1) or not snap.refund?
      return false
    locked = (u for u in snap.unlocks when not u.unlocked)
    if not locked.length or snap.mutagen.greaterThanOrEqualTo locked[0].price
      return false
    base = locked[0].price.dividedBy Decimal.pow(locked[0].factor, snap.unlockCount)
    return snap.mutagen.plus(snap.refund).greaterThanOrEqualTo base.plus(base.times locked[0].factor)

  # 12.7: the purchases on current holdings, in order (idempotent: once they are made, this returns null):
  # free respec when advised; unlocks in SW.unlockOrder (the first SW.freeUnlocks whenever affordable, later ones only
  # while the price is at most SW.unlockShare of the mutagen held); lepidoptera and frequency mutations to 1e6; then
  # W = mutagen held + the warp, bat, territory and meta-mutation mutants held (unlocked kinds): hold SW.shares of W
  # in each; the rest stays unspent. Prices are the game's. Null when there is nothing to do.
  # opts.respec false: never a respec (the near-complete guard, or an ascension the route wants: it will bring the
  # mutagen for the warp unlock); opts.shares false: no share purchases (the near-complete guard).
  warpMutagen = (snap, opts={}) ->
    if snap.ascensions < 1
      return null
    respec = opts.respec != false and warpRespec snap
    held = snap.mutagen
    count = snap.unlockCount
    units = for u in snap.unlocks
      _.extend {}, u
    steps = []
    locked = (u for u in units when not u.unlocked)
    factor = (locked[0] ? units[0])?.factor ? D(15625)
    base = if locked.length then locked[0].price.dividedBy(Decimal.pow factor, count) else D(1)
    if respec
      steps.push {type: 'respec', free: snap.freeRespecs, refund: snap.refund}
      held = held.plus snap.refund
      count = 0
      for u in units
        u.unlocked = false
        u.have = ZERO
    if not held.greaterThan 0
      return null
    byName = _.keyBy units, 'name'
    byUnit = _.keyBy units, 'unit'
    for name in SW.unlockOrder
      u = byName[name]
      if not u? or u.unlocked
        continue
      price = base.times Decimal.pow(factor, count)
      if held.lessThan price
        break
      if count >= SW.freeUnlocks and price.greaterThan held.times(SW.unlockShare)
        break
      held = held.minus price
      count += 1
      u.unlocked = true
      u.have = u.have.plus 1 # each unlock comes with one mutant
      steps.push {type: 'unlock', name: u.name, label: u.label, unit: u.unit, price: price, nth: count}
    buy = (u, want, kind, share) ->
      short = want.minus u.have
      if short.lessThanOrEqualTo want.times(SHARE_TOLERANCE)
        return
      k = Decimal.min(short, held.dividedBy(u.mutantPrice))
      if k.lessThan 1
        return
      k = k.floor()
      if k.lessThan 1
        return
      steps.push {type: 'mutants', unit: u.unit, count: k, have: u.have, target: want, kind: kind, share: share ? null, price: k.times(u.mutantPrice)}
      held = held.minus k.times(u.mutantPrice)
      u.have = u.have.plus k
    for [mu, want] in SW.fixedMutants
      u = byUnit[mu]
      if u?.unlocked
        buy u, D(want), 'fixed'
    managed = if opts.shares == false then [] else ([byUnit[mu], sh] for [mu, sh] in SW.shares when byUnit[mu]?.unlocked)
    W = held
    for [u, sh] in managed
      W = W.plus u.have
    for [u, sh] in managed
      buy u, W.times(sh), 'share', sh
    if not steps.length
      return null
    return {type: 'mutagen', route: WARP_ROUTE, mutagen: snap.mutagen, steps: steps, keep: held, respec: respec, w: W}

  warpAdvise = (snap, cfg, route) ->
    records = []
    goals = snap.goals
    target = lastGoal(goals.ascension)?.val.toNumber() ? null
    stage = warpStage snap
    test = null
    wants = stage == 'quick'
    if stage == 'build'
      test = warpTest snap
      wants = test.passes
    # no free respec while the route wants this run ended: the ascension brings mutagen for the warp unlock, and the
    # respec would be spent for nothing (13 G3 is for a run that has only started, far below the test)
    mut = warpMutagen snap, {respec: not wants}
    p = null
    if wants
      p = _.extend plan(snap), stage: stage, of: target, route: WARP_ROUTE, test: test
      # 13 G1: ascending out of a run with House of Mirrors casts and many expansions restarts them; say so
      if snap.mirrorCasts > 0 and snap.expansion >= SW.restartNote
        p.restarts = {expansions: snap.expansion, mirrorCasts: snap.mirrorCasts}
      line = p
    else if stage == 'done'
      line = {type: 'done', ascensions: snap.ascensions, route: WARP_ROUTE}
    else
      # build (test fails) or final: keep swarmwarping, and what the run is collecting (12.8)
      line =
        type: if stage == 'final' then 'warpFinal' else 'warpBuild'
        test: test
        expansion: snap.expansion
        nextExpansion: nextGoal(goals.expansion, D snap.expansion)
        lastExpansion: lastGoal goals.expansion
        top: snap.top
        endlessBought: snap.endlessBought
        nextEndless: nextGoal(goals.endless, snap.endlessBought)
        unlocks: snap.unlockCount
        nextMutation: nextGoal(goals.mutation ? [], D snap.unlockCount)
        ascensions: snap.ascensions
        of: target
    if mut?
      records.push mut
    records.push line
    return {
      stage: stage
      route: route
      records: records
      mutagen: mut
      plan: p
      test: test
      moths: {moths: SW.moths, stage: WARP_ROUTE} # 12.2 E2
      hold: if p?.type in ['saveForAscension', 'ascendNow'] then p else null
    }

  # The energy line, made to agree with this advice: unchanged unless the route is on and its plan is
  # running. While saving (or able to ascend), any record that would spend energy becomes the save;
  # before that, a cast is cut to the casts that bring the cost down to where saving starts.
  coupleEnergy = (rec, asc) ->
    if not rec? or not asc?.plan?
      return rec
    p = asc.plan
    if asc.hold? and rec.type in SPENDING
      return {type: 'ascensionHold', ready: p.type == 'ascendNow', energy: p.energy, cost: p.cost, seconds: p.seconds ? null, replaces: rec.type}
    # the swarmwarp route: one cast at a time, so only how many are left before saving can be cut
    if p.type == 'spendForAscension' and p.toSpend? and rec.type == 'warp'
      needed = p.toSpend.dividedBy(rec.cost).ceil()
      if needed.lessThan rec.affordable
        return _.extend {}, rec, affordable: needed, thenSave: true
    if p.type == 'spendForAscension' and p.toSpend? and rec.type == 'buyBats'
      needed = p.toSpend.dividedBy(rec.price).ceil()
      if needed.lessThan rec.count
        return _.extend {}, rec, count: needed, thenSave: true
    if p.type == 'spendForAscension' and p.toSpend? and rec.type == 'cast'
      needed = p.toSpend.dividedBy(rec.cost).ceil()
      if needed.lessThan rec.casts
        return _.extend {}, rec, casts: needed, thenSave: true
    # lepidoptera count as spent energy too (10 each): cut them the same way (ASCENSION.md A.11)
    if p.type == 'spendForAscension' and p.toSpend? and rec.type == 'buyMoths'
      needed = p.toSpend.dividedBy(MOTH_ENERGY).ceil()
      if needed.lessThan rec.count
        return _.extend {}, rec, count: needed, thenSave: true
    return rec

  # ---------------------------------------------------------------------------
  # Reference wording.

  fmt = advisor.formatNumber
  time = advisor.formatTime

  of20 = (r) -> 'ascension ' + r.ascension + (if r.of? then ' of ' + r.of else '')

  renderStep = (s) ->
    switch s.type
      when 'unlock' then 'unlock ' + s.label + ' (' + fmt(s.price) + ')'
      when 'mutants'
        if s.kind == 'share'
          'buy ' + fmt(s.count) + ' ' + s.unit + ' (to ' + (s.share * 100) + '% of your mutagen: ' + fmt(s.target) + ')'
        else if s.kind == 'fixed'
          'buy ' + fmt(s.count) + ' ' + s.unit + ' (' + fmt(s.have) + '/' + fmt(s.target) + ')'
        else
          'buy ' + fmt(s.count) + ' lepidoptera mutations (' + fmt(s.have) + '/' + fmt(s.target) + ')'
      when 'respec' then 'respec (free, ' + s.free + ' left): the swarmwarp route needs the warp mutation, which you cannot afford as your next unlock'
      when 'unlocks'
        if s.any
          'unlock ' + s.count + ' more mutation' + (if s.count == 1 then '' else 's') + ', any (' + fmt(s.price) + ')'
        else if s.all
          'unlock the ' + s.count + ' remaining mutation' + (if s.count == 1 then '' else 's') + ' (' + fmt(s.price) + ')'
        else
          'unlock ' + s.count + ' more mutation' + (if s.count == 1 then '' else 's') + ' (' + fmt(s.price) + ')'
      else ''

  # 13 G1: "; this run has 3,118 expansions from House of Mirrors: ascending restarts them. The swarmwarp route still
  # expects ascending to be faster."
  renderRestarts = (rec) ->
    if not rec.restarts? then return ''
    '; this run has ' + fmt(rec.restarts.expansions) + ' expansions from House of Mirrors: ascending restarts them. The swarmwarp route still expects ascending to be faster'

  # what a swarmwarp-route run is collecting (12.8): "; expansions 357/500; endless bought 0/1; unlocks 8/10"
  renderCollecting = (rec) ->
    text = ''
    if rec.nextExpansion?
      text += '; expansions ' + fmt(rec.expansion) + '/' + fmt(rec.nextExpansion.val)
    if rec.nextEndless?
      text += '; endless bought ' + fmt(rec.endlessBought) + '/' + fmt(rec.nextEndless.val) + (if rec.top? then ' (top tier ' + rec.top + ')' else '')
    if rec.nextMutation?
      text += '; unlocks ' + rec.unlocks + '/' + fmt(rec.nextMutation.val)
    text

  render = (rec) ->
    if not rec?
      return null
    switch rec.type
      when 'mutagen'
        (renderStep(s) for s in rec.steps).join(', then ') + '; keep the rest (' + fmt(rec.keep) + ') unspent: it makes larvae'
      # Below nexus 5 the cap still grows with each nexus, so the save point is not shown yet.
      when 'spendForAscension'
        spells = if rec.route == WARP_ROUTE then 'lepidoptera, bats and swarmwarp' else 'lepidoptera and House of Mirrors'
        of20(rec) + ' costs ' + fmt(rec.cost) + ' energy (cap ' + fmt(rec.cap) + '): every ' + fmt(rec.halving) + ' energy spent halves it' +
          (if rec.nexus >= 5 and rec.toSpend? then ' (' + spells + '); spend ' + fmt(rec.toSpend) + ' more, then save from ' + fmt(rec.saveAt) else ', mostly ' + spells + ' from nexus 5') + renderRestarts(rec)
      when 'saveForAscension'
        'stop spending energy and save for ' + of20(rec) + ': ' + fmt(rec.energy) + '/' + fmt(rec.cost) +
          (if rec.seconds? then ', ready in ' + time(rec.seconds) else '') + renderRestarts(rec)
      when 'ascendNow'
        if rec.noMutagen
          return 'energy covers ' + of20(rec) + ' (' + fmt(rec.energy) + '/' + fmt(rec.cost) + ') but it would bring no mutagen: wait for mutagen (inactive) from hatcheries and expansions'
        'ascend now: ' + fmt(rec.energy) + '/' + fmt(rec.cost) + ' energy; brings ' + fmt(rec.premutagen) + ' mutagen, ' + of20(rec) + renderRestarts(rec)
      when 'warpBuild'
        'keep swarmwarping, do not ascend yet: mutagen (inactive) ' + fmt(rec.test.premutagen) + '/' + fmt(rec.test.need) + ' (' + fmt(rec.test.ratio) + ' x mutagen held)' + renderCollecting(rec)
      when 'warpFinal'
        'final run, do not ascend: expansions ' + fmt(rec.expansion) + '/' + fmt(rec.lastExpansion?.val ? 5000) + '; all spare energy into swarmwarp' + renderCollecting(_.omit rec, 'nextExpansion')
      when 'routeGuard'
        fmt(rec.expansions) + ' of ' + fmt(rec.goal) + ' expansions: finish this run with House of Mirrors, then the swarmwarp route resumes'
      when 'longRun'
        text = 'long run: do not ascend yet; expansions ' + fmt(rec.expansion)
        if rec.nextExpansion?
          text += '/' + fmt(rec.nextExpansion.val)
          if rec.lastExpansion? and not rec.lastExpansion.val.equals(rec.nextExpansion.val)
            text += ' (last ' + fmt(rec.lastExpansion.val) + ')'
        if rec.nextEndless?
          text += '; endless bought ' + fmt(rec.endlessBought) + '/' + fmt(rec.nextEndless.val) + (if rec.top? then ' (top tier ' + rec.top + ')' else '')
        text
      when 'done'
        if rec.route == WARP_ROUTE then 'every achievement of the swarmwarp route earned: no further ascension needed' else 'every ascension achievement earned: no further ascension needed'
      when 'ascensionHold'
        if rec.ready
          'hold it for the ascension (' + fmt(rec.energy) + '/' + fmt(rec.cost) + ')'
        else
          'saving for the ascension: ' + fmt(rec.energy) + '/' + fmt(rec.cost) + (if rec.seconds? then ', ready in ' + time(rec.seconds) else '')
      else ''

  # ---------------------------------------------------------------------------
  # Live wiring.

  cached = null

  svc = {
    ROUTE: ROUTE
    WARP_ROUTE: WARP_ROUTE
    warpStage: warpStage
    warpTest: warpTest
    warpRespec: warpRespec
    warpMutagen: warpMutagen
    warpWealth: warpWealth
    NEXUS_MUTANTS: NEXUS_MUTANTS
    # pure
    snapshot: snapshot
    plan: plan
    mutagenPlan: mutagenPlan
    advise: advise
    coupleEnergy: coupleEnergy
    runMoths: runMoths
    RUN_MOTHS: RUN_MOTHS
    render: render
    renderStep: renderStep
    # live
    enabled: -> isOn options.advisorConfig()
    # With the route off, the game is not read at all.
    update: (now) ->
      cfg = options.advisorConfig()
      if not isOn cfg
        return advise null, cfg
      return advise snapshot(game, now), cfg
    # The latest advice, as `advisor.current()`. Never throws: {at, advice, error}.
    # Also afresh at once after a setting change or a swarmwarp cast (`advisor.liveKey`).
    current: (maxAgeMs=1000, wallNow=Date.now()) ->
      key = advisor.liveKey()
      if not cached? or wallNow - cached.at >= maxAgeMs or wallNow < cached.at or cached.key != key
        try
          cached = {at: wallNow, key: key, advice: svc.update(), error: null}
        catch e
          cached = {at: wallNow, key: key, advice: null, error: e}
      return cached
    invalidate: -> cached = null
  }
  # A purchase, an ascension, an import or a reset changes what to advise: work it out afresh.
  $rootScope.$on 'command', -> cached = null
  $rootScope.$on 'import', -> cached = null
  $rootScope.$on 'reset', -> cached = null
  return svc
