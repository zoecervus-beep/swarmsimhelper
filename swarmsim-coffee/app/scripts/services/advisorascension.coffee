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
  SPENDING = ['cast', 'nextCast', 'buyMoths', 'mothTarget', 'energyFull']
  # ASCENSION.md A.11: the lepidoptera target after nexus 5 for each kind of run (the advisor's `moths`
  # setting still applies when it is higher). Every lepidoptera counts as energy spent, as a House of
  # Mirrors cast does, and raises the energy rate besides, so a run that is only waiting to ascend wants
  # many. A first run (or one still short of the lepidoptera mutation) stops at 10,000 so mirrors still
  # bring the mutagen the plan spends (~1e7 with it, ~1.5e5 with 30,000); a quick run takes 30,000; the
  # long run takes 30,000 from a run age of 3 days, as the long-run mode's LR-4 does.
  RUN_MOTHS = {firstRun: 10000, needMutation: 10000, quickRun: 30000}

  isOn = (cfg) -> cfg?.ascension == ROUTE

  # ---------------------------------------------------------------------------
  # Snapshot.

  goalsOf = (g) ->
    expansion = []
    endless = []
    ascension = []
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
    byVal = (list) -> list.sort (a, b) -> a.val.comparedTo b.val
    return {expansion: byVal(expansion), endless: byVal(endless), ascension: byVal(ascension)}

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
    nexusMutant = g.unit 'mutantnexus'
    top = null
    for name in advisor.CHAIN
      if g.unit(name).count().greaterThanOrEqualTo 1
        top = name
    stats = g.unit('overmind6').statistics?() ? {}
    dates = g.session.state.date
    return {
      now: now
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

  advise = (snap, cfg) ->
    records = []
    if not isOn cfg
      return {stage: 'off', records: records, hold: null, plan: null, mutagen: null, moths: null}
    mut = mutagenPlan snap
    goals = snap.goals
    longLeft = (g for g in goals.expansion.concat(goals.endless) when not g.earned)
    target = if goals.ascension.length then _.last(goals.ascension).val.toNumber() else null
    ascLeft = (g for g in goals.ascension when not g.earned)
    nexus = _.find snap.unlocks, name: NEXUS_UNLOCK
    hasNexus = nexus?.unlocked or (mut? and mut.steps[0].name == NEXUS_UNLOCK)
    if snap.ascensions == 0
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

  # The energy line, made to agree with this advice: unchanged unless the route is on and its plan is
  # running. While saving (or able to ascend), any record that would spend energy becomes the save;
  # before that, a cast is cut to the casts that bring the cost down to where saving starts.
  coupleEnergy = (rec, asc) ->
    if not rec? or not asc?.plan?
      return rec
    p = asc.plan
    if asc.hold? and rec.type in SPENDING
      return {type: 'ascensionHold', ready: p.type == 'ascendNow', energy: p.energy, cost: p.cost, seconds: p.seconds ? null, replaces: rec.type}
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
      when 'mutants' then 'buy ' + fmt(s.count) + ' lepidoptera mutations (' + fmt(s.have) + '/' + fmt(s.target) + ')'
      when 'unlocks'
        if s.any
          'unlock ' + s.count + ' more mutation' + (if s.count == 1 then '' else 's') + ', any (' + fmt(s.price) + ')'
        else if s.all
          'unlock the ' + s.count + ' remaining mutation' + (if s.count == 1 then '' else 's') + ' (' + fmt(s.price) + ')'
        else
          'unlock ' + s.count + ' more mutation' + (if s.count == 1 then '' else 's') + ' (' + fmt(s.price) + ')'
      else ''

  render = (rec) ->
    if not rec?
      return null
    switch rec.type
      when 'mutagen'
        (renderStep(s) for s in rec.steps).join(', then ') + '; keep the rest (' + fmt(rec.keep) + ') unspent: it makes larvae'
      # Below nexus 5 the cap still grows with each nexus, so the save point is not shown yet.
      when 'spendForAscension'
        of20(rec) + ' costs ' + fmt(rec.cost) + ' energy (cap ' + fmt(rec.cap) + '): every ' + fmt(rec.halving) + ' energy spent halves it' +
          (if rec.nexus >= 5 and rec.toSpend? then ' (lepidoptera and House of Mirrors); spend ' + fmt(rec.toSpend) + ' more, then save from ' + fmt(rec.saveAt) else ', mostly lepidoptera and House of Mirrors from nexus 5')
      when 'saveForAscension'
        'stop spending energy and save for ' + of20(rec) + ': ' + fmt(rec.energy) + '/' + fmt(rec.cost) +
          (if rec.seconds? then ', ready in ' + time(rec.seconds) else '')
      when 'ascendNow'
        if rec.noMutagen
          return 'energy covers ' + of20(rec) + ' (' + fmt(rec.energy) + '/' + fmt(rec.cost) + ') but it would bring no mutagen: wait for mutagen (inactive) from hatcheries and expansions'
        'ascend now: ' + fmt(rec.energy) + '/' + fmt(rec.cost) + ' energy; brings ' + fmt(rec.premutagen) + ' mutagen, ' + of20(rec)
      when 'longRun'
        text = 'long run: do not ascend yet; expansions ' + fmt(rec.expansion)
        if rec.nextExpansion?
          text += '/' + fmt(rec.nextExpansion.val)
          if rec.lastExpansion? and not rec.lastExpansion.val.equals(rec.nextExpansion.val)
            text += ' (last ' + fmt(rec.lastExpansion.val) + ')'
        if rec.nextEndless?
          text += '; endless bought ' + fmt(rec.endlessBought) + '/' + fmt(rec.nextEndless.val) + (if rec.top? then ' (top tier ' + rec.top + ')' else '')
        text
      when 'done' then 'every ascension achievement earned: no further ascension needed'
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
    current: (maxAgeMs=1000, wallNow=Date.now()) ->
      if not cached? or wallNow - cached.at >= maxAgeMs or wallNow < cached.at
        try
          cached = {at: wallNow, advice: svc.update(), error: null}
        catch e
          cached = {at: wallNow, advice: null, error: e}
      return cached
    invalidate: -> cached = null
  }
  # A purchase, an ascension, an import or a reset changes what to advise: work it out afresh.
  $rootScope.$on 'command', -> cached = null
  $rootScope.$on 'import', -> cached = null
  $rootScope.$on 'reset', -> cached = null
  return svc
