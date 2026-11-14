'use strict'

###*
 # @ngdoc service
 # @name swarmApp.advisorView
 # @description
 # Turns the climbing advisor's records (reason codes and numbers) into what the panel and the
 # buy-box button show: the game's unit labels, its number format and links to unit pages.
 # The advisor's own render* functions are the reference wording and the fallback for any record
 # this doesn't know.
###
angular.module('swarmApp').factory 'advisorView', (game, advisor, advisorTerritory, advisorAscension, $filter) ->
  bignum = (n, maxSmall=0) -> $filter('bignum')(n, maxSmall)
  time = advisor.formatTime

  unitOf = (name) ->
    try
      return game.unit name
    catch e
      return null
  # The game's names, with the suffix of an empowered territory unit ("swarmling II"). The game sets
  # `unit.suffix` while it works out the unit's stats, which the territory advice reads every second.
  suffixed = (u, text) -> if u?.suffix then text + ' ' + u.suffix else text
  label = (name) ->
    u = unitOf name
    if u?.unittype?.label? then suffixed(u, u.unittype.label) else name
  plural = (name) ->
    u = unitOf name
    if u?.unittype?.plural? then suffixed(u, u.unittype.plural) else name
  # "1 hive queen", "2 hive queens"
  count = (n, name) -> bignum(n) + ' ' + (if new Decimal(n).equals(1) then label(name) else plural(name))
  # Link to a unit's page, or null if the unit doesn't exist or isn't visible yet (the game
  # redirects away from hidden units).
  href = (name) ->
    u = unitOf name
    if u?.tab? and u.isVisible()
      return '#' + u.url()
    return null
  # An upgrade's page is its unit's page. Hatchery, expansion and accomplished ancestry belong to
  # the hidden 'invisiblehatchery' unit and are shown on the larva page.
  upgradeHref = (name) ->
    try
      return href(game.upgrade(name).unit.name) ? href('larva')
    catch e
      return null
  upgradeLabel = (name, fallback) ->
    try
      return game.upgrade(name)?.type?.label ? fallback
    catch e
      return fallback

  action = (t) ->
    switch t.reason
      when 'tooSlow' then 'wait ' + time(t.waitSeconds)
      when 'needBelow' then 'need more ' + plural(t.below)
      when 'bank' then 'skip: bank larvae for ' + plural(t.bankFor)
      when 'cooldown' then 'done, next in ' + time(t.waitSeconds)
      when 'buy'
        ret = 'buy ' + bignum(t.buys)
        if t.twin.greaterThan 1
          ret += ' (×' + bignum(t.twin) + ' twins)'
        ret
      when 'larvaeUsedAbove' then 'skip: larvae used above'
      when 'buildUp' then 'let ' + plural(t.below) + ' build up'
      # long-run mode
      when 'push' then 'feed upward: ' + pushText(t.push)
      else advisor.renderAction t

  # "hatch 3.20e15 (half your galactic clusters)", in the row of the unit hatched
  pushText = (rec) ->
    why = switch rec.limitedBy
      when 'larvae' then 'all the larvae left'
      when 'meat' then 'half your meat'
      else (if rec.share == 0.5 then 'half' else (rec.share * 100) + '% of') + ' your ' + plural(rec.below)
    'hatch ' + bignum(rec.buys) + (if rec.twin.greaterThan(1) then ' (×' + bignum(rec.twin) + ' twins)' else '') + ' (' + why + ')'

  step = (s) ->
    if s.type == 'twin'
      return upgradeLabel s.unit + 'twin', 'twin ' + plural(s.unit)
    return 'hatch ' + count(s.count, s.unit)

  tip = (t) ->
    text = switch t.type
      when 'faster'
        'buy ' + upgradeLabel(t.unit + 'prod', 'faster ' + plural(t.unit)) + ' (' + count(t.cost, t.unit) + ')'
      when 'twin'
        'buy ' + upgradeLabel(t.unit + 'twin', 'twin ' + plural(t.unit)) + ' (' + count(t.cost, t.payIn) + ')'
      when 'twinPlan'
        steps = (step(s) for s in t.steps)
        steps.push upgradeLabel(t.unit + 'twin', 'twin ' + plural(t.unit))
        'plan: ' + steps.join(' › ') + ' (pays back in ' + time(t.payback) + ')'
      else advisor.renderTip t
    return {type: t.type, unit: t.unit, text: text, href: href(t.unit)}

  # Why a lepidoptera target is not simply the setting, said where it shows: the first ones before
  # nexus 5 ('save' plan), the ascension route's target for this kind of run, or the long-run mode's.
  RUN_STAGE = {firstRun: 'first-run target', needMutation: 'first-run target', longRun: 'long-run target', quickRun: 'quick-run target', swarmwarp: 'swarmwarp route'}
  mothWhy = (rec) ->
    if rec.early then return ': the first ' + bignum(rec.target) + ', before nexus 5'
    if rec.runStage? then return ': ' + (RUN_STAGE[rec.runStage] ? 'run target') + ', your setting is ' + bignum(rec.setting)
    if rec.longRun then return ': long-run target, your setting is ' + bignum(rec.setting)
    return ''
  # the 'save' plan at nexus 4 keeps only part of nexus 5's energy price while its larvae are hours away
  keepText = (rec) ->
    if not rec.keep? then return ''
    if new Decimal(rec.keep).isZero() then return '; nothing to keep for nexus 5 yet: income brings it before its larvae (' + time(rec.wait) + ')'
    '; keep ' + count(rec.keep, 'energy') + ' for nexus 5: income brings the rest before its larvae (' + time(rec.wait) + ')'

  saving = (rec) ->
    'save for nexus ' + rec.level + ': ' + ((bignum(m.have) + '/' + count(m.need, m.unit)) for m in rec.missing).join(', ') +
      (if rec.keep? and rec.keepIdle then '; ' + (if new Decimal(rec.keep).isZero() then 'no energy' else 'only ' + count(rec.keep, 'energy')) + ' needed now: income brings the rest before the larvae (' + time(rec.wait) + ')' else '')

  energy = (rec) ->
    if not rec?
      return null
    link = 'energy'
    switch rec.type
      when 'buyNexus'
        text = 'buy nexus ' + rec.level
        link = 'nexus'
      when 'save'
        text = saving rec
        link = 'nexus'
      when 'buyMoths'
        text = 'buy ' + bignum(rec.count) + ' ' + plural('moth') + ' (' + bignum(rec.moths) + '/' + bignum(rec.target) + mothWhy(rec) + ')' + keepText(rec)
        if rec.thenSave
          # cut short by the ascension advice: these bring the cost to where saving starts
          text += ', then save for the ascension'
        if rec.then
          text += '; then ' + saving(rec.then)
        link = 'moth'
      when 'mothTarget'
        text = 'all energy into ' + plural('moth') + ' (' + bignum(rec.moths) + '/' + bignum(rec.target) + mothWhy(rec) + ')'
        if rec.then
          text += '; then ' + saving(rec.then)
        link = 'moth'
      when 'cast'
        text = 'cast ' + rec.label + ' \u00d7' + bignum(rec.casts)
        if rec.thenSave
          # cut short by the ascension advice: these casts bring the cost to where saving starts
          text += ', then save for the ascension'
      when 'nextCast'
        text = 'next ' + rec.label + ' at ' + bignum(rec.cost) + ' energy (have ' + bignum(rec.energy) + ')'
      # the swarmwarp route (NO-MIRRORS.md 12.2, 12.3): bats, then one swarmwarp at a time
      when 'buyBats'
        text = 'buy ' + count(rec.count, 'bat') + ' (' + bignum(rec.bats) + '/' + bignum(rec.target) + ', before the first swarmwarp: they raise its power)'
        if rec.thenSave
          text += ', then save for the ascension'
        link = 'bat'
      when 'batTarget'
        text = 'all energy into ' + plural('bat') + ' (' + bignum(rec.bats) + '/' + bignum(rec.target) + ', ' + count(rec.price, 'energy') + ' each), then swarmwarp'
        link = 'bat'
      when 'warp'
        text = warpText(rec) + '; then follow the lines above and below: the next swarmwarp is suggested after them'
      when 'warpAfter'
        text = 'next: ' + warpText(rec) + ', once the purchases above and below are made (' + advisor.renderPending(rec.pending) + ')'
      when 'hold'
        # spare energy kept for the next nexus (setting spareEnergy 'save')
        text = 'saving for nexus ' + rec.level + ': '
        if not rec.price?
          text += bignum(rec.energy) + ' energy'
        else if rec.ready
          text += 'energy ready (' + bignum(rec.energy) + '/' + bignum(rec.price) + ')'
        else
          text += bignum(rec.energy) + '/' + count(rec.price, 'energy')
        if rec.missing.length
          text += (if rec.ready then '; waiting for ' else '; also needs ') + ((count(m.need, m.unit) + ' (have ' + bignum(m.have) + ')') for m in rec.missing).join(', ')
        if rec.mothsNext
          text += '; lepidoptera after that'
        if rec.keep? and rec.keepIdle
          text += '; ' + (if new Decimal(rec.keep).isZero() then 'none' else 'only ' + count(rec.keep, 'energy')) + ' needed now: income brings the rest before its larvae (' + time(rec.wait) + ')'
        link = 'nexus'
      when 'energyFull'
        text = 'energy is full (' + bignum(rec.energy) + '/' + bignum(rec.cap) + '): cast ' + rec.label + ' \u00d71 so the income isn\'t wasted'
      when 'ascensionHold'
        # the ascension advice is saving: no spending
        if rec.ready
          text = 'hold it for the ascension (' + bignum(rec.energy) + '/' + count(rec.cost, 'energy') + ')'
        else
          text = 'saving for the ascension, no casting: ' + bignum(rec.energy) + '/' + count(rec.cost, 'energy') + (if rec.seconds? then ', ready in ' + time(rec.seconds) else '')
        link = 'mutagen'
      else
        text = advisor.renderEnergy _.omit(rec, 'larvae') # the larvae part is added below, with the game's labels
    return {type: rec.type, text: text + larvaeText(rec), href: href(link)}

  # "cast 1 swarmwarp (5 affordable): skips 27.8 d"; never "×N" on the swarmwarp route
  warpText = (rec) ->
    'cast 1 swarmwarp (' + bignum(rec.affordable) + ' affordable' + (if rec.thenSave then ' before saving for the ascension' else '') + ')' +
      (if rec.skip? then ': skips ' + time(rec.skip) else '')

  # The 'save' plan (ASCENSION.md A.11.9): how many of the next nexus's larvae the climb leaves for it, and why.
  larvaeText = (rec) ->
    lp = rec?.larvae
    if not lp? or rec.type == 'ascensionHold' then return ''
    if lp.binds == 'ready'
      return '; keeping its ' + count(lp.keep, 'larva')
    if lp.binds == 'larvae'
      return '; keeping all ' + count(lp.keep, 'larva') + ' for nexus ' + lp.level + ': larvae are what it waits for (' + time(lp.larvaWait) + '; energy ' + time(lp.energyWait) + ')'
    if new Decimal(lp.keep).isZero()
      return '; keeping no larvae for nexus ' + lp.level + ' yet: its energy is ' + time(lp.energyWait) + ' away, its larvae ' + time(lp.larvaWait)
    '; keeping ' + count(lp.keep, 'larva') + ' for nexus ' + lp.level + ', the rest come in before its energy (' + time(lp.energyWait) + ')'

  errorText = (e) -> String(e?.message ? e)

  # The text the "use suggested" button writes into the buy box: a plain integer below 1e21, an
  # exact exponent form above (1.2345e+400). Both parse back to the same count through
  # `parseNumber`; the exponent form keeps huge counts short.
  buyCountString = (count) ->
    count = new Decimal count
    if count.abs().lessThan '1e21'
      return count.toFixed 0
    return count.toExponential()

  # Every digit, with thousands separators, for the button's tooltip.
  exactText = (count) ->
    if count.lessThan '1e21'
      return count.toFixed(0).replace /\B(?=(\d{3})+(?!\d))/g, ','
    return count.toExponential()

  # The energy record as the panel shows it: made to agree with the ascension advice when that is on
  # (`acur`, from `advisorAscension.current()`); then, on the swarmwarp route, a warp waits while the climb, the tips
  # and the territory lines (`tcur`) have purchases open (`advisor.orderWarp`). Without them, or if they failed, the
  # record unchanged.
  coupledEnergy = (rec, acur, advice, tcur) ->
    if acur?.advice?
      try
        rec = advisorAscension.coupleEnergy rec, acur.advice
      catch e
    try
      return advisor.orderWarp rec, advice, tcur?.advice
    catch e
      return rec

  # From `advisor.current()`'s {advice, error} to the panel's view model. Never throws.
  panel = (cur, acur, tcur) ->
    if not cur?
      return null
    if cur.error?
      return {error: errorText cur.error}
    try
      r = cur.advice
      rows = for t in r.tiers by -1 # highest tier first
        name: t.name
        label: label t.name
        href: href t.name
        count: t.count
        H: time t.H
        kind: t.kind
        reason: t.reason
        action: action t
      buys = _.filter rows, (row) -> row.kind == 'buy' or row.kind == 'push'
      lr = r.longRun
      longRun = null
      if lr?
        longRun =
          active: lr.active
          text: if lr.active then 'long-run climb: 1% of larvae kept for feeding upward' else 'long-run climb from run age 2 d (in ' + time(lr.startsIn) + ')'
        # the empty tiers above the table, up to endless, on one row
        if lr.above.length
          longRun.above = label(lr.above[0]) + (if lr.above.length > 1 then ' to ' + label(_.last lr.above) else '') + ': nothing to feed until you own the tier below'
      # the swarmwarp route: the long-run climb is on whatever the setting says
      if r.route?.route == 'swarmwarp' and longRun?
        longRun.route = 'swarmwarp'
        longRun.text = longRun.text.replace 'long-run climb', 'long-run climb (swarmwarp route)'
      return {
        longRun: longRun
        error: null
        header:
          age: time r.age
          # the run age is on the game clock (NO-MIRRORS.md 12.1): with swarmwarp cast this run, the real time too
          wallAge: if r.wallAge? and r.age - r.wallAge >= 1 then time(r.wallAge) else null
          horizon: time r.horizon
          larvae: bignum r.larvae
          larvaRate: bignum r.larvaRate, 1
        rows: rows
        tips: (tip(t) for t in r.tips)
        # an energy failure costs only this line, as in the console script
        energy: if r.energyError? then {type: 'error', error: true, text: errorText(r.energyError)} else energy coupledEnergy(r.energy, acur, r, tcur)
        summary: if buys.length then {label: buys[0].label, action: buys[0].action} else null
      }
    catch e
      return {error: errorText e}

  # One territory record as a panel line: text from the record's fields with the game's labels and
  # number format, a link where the game has a page for it, and `buy` for what to hatch.
  territoryLine = (rec) ->
    line = {type: rec.type, unit: rec.unit ? null, href: null, buy: false}
    switch rec.type
      when 'setShare'
        line.text = 'set the territory share to ' + rec.to + ' in Options (now ' + rec.share + ')' + (if rec.route == 'swarmwarp' then ': on the swarmwarp route expansions come from territory units' else '')
        line.href = '#/options'
      when 'mirrors'
        line.text = 'House of Mirrors is running: hatch no more territory units'
        line.href = href 'energy'
      when 'upgrade'
        line.text = 'buy ' + rec.label + (if rec.levels > 1 then ' ×' + rec.levels else '') + ' (' + (count(c.val, c.unit) for c in rec.costs).join(', ') + ')'
        line.href = upgradeHref rec.name
      when 'empower'
        line.text = 'buy ' + rec.label + ' (' + count(rec.meat, 'meat') + '): they become ' + rec.becomes + ', the next unit above ' + rec.above + '; ' +
          (if rec.wipes.greaterThan(0) then 'your ' + count(rec.wipes, rec.unit) + (if rec.wipes.equals(1) then ' is' else ' are') + ' lost' else 'you have none to lose')
        line.href = href rec.unit
      when 'twin'
        line.text = 'buy ' + rec.label + ' (' + count(rec.larvae, 'larva') + ', ' + count(rec.meat, 'meat') + ')'
        line.href = href rec.unit
      when 'saveForTwin'
        line.text = 'save larvae for ' + rec.label + ': ' + bignum(rec.have) + '/' + count(rec.larvae, 'larva')
        line.href = href rec.unit
      when 'hatch'
        line.amount = count(rec.buys, rec.unit) + (if rec.twin.greaterThan(1) then ' (×' + bignum(rec.twin) + ' twins)' else '')
        line.text = 'hatch ' + line.amount
        line.href = href rec.unit
        line.buy = true
      when 'idle'
        if rec.reason == 'noMeat'
          line.text = 'need ' + count(rec.cost, 'meat') + ' per ' + label(rec.unit) + ' (can spend ' + bignum(rec.meat) + ')'
          line.href = href rec.unit
        else
          line.text = advisorTerritory.render rec
      else
        line.text = advisorTerritory.render rec
    return line

  # From `advisorTerritory.current()` to the panel's territory lines. Never throws.
  # The `hatch` records (main and spare) are one plan, bought in either order, so they make one line:
  # "hatch 184 stingers (×8 twins) and 94 arachnomorphs (×8 twins), in any order", each unit its own
  # link. Other records keep a line each.
  territory = (cur) ->
    if not cur?
      return null
    if cur.error?
      return {error: errorText cur.error, lines: []}
    try
      notePlan cur
      lines = []
      plan = null
      for rec in cur.advice.records
        line = territoryLine rec
        if rec.type != 'hatch'
          lines.push line
        else if plan?
          plan.parts.push line
          plan.units.push line.unit
        else
          plan = {type: 'hatchPlan', parts: [line], units: [line.unit], buy: true}
          lines.push plan
      if plan?
        plan.text = 'hatch ' + (p.amount for p in plan.parts).join(' and ') + (if plan.parts.length > 1 then ', in any order' else '')
      return {error: null, lines: lines}
    catch e
      return {error: errorText e, lines: []}

  # Territory units in the current plan whose line was bought: a unit the plan named is remembered
  # with its purchase count at the time; once it has been hatched since and the plan no longer names
  # it, its page says "done here" instead of nothing. Forgotten when the plan runs out (no hatch
  # lines), so units the plan never named, or named in an earlier cycle, show nothing.
  planned = {}
  plannedAt = null # the advice last noted (each update is a new object, so compare by identity)
  purchases = (name) -> new Decimal(unitOf(name)?.statistics?()?.num ? 0)
  notePlan = (cur) ->
    if not cur?.advice? or cur == plannedAt
      return
    plannedAt = cur
    if not cur.advice.hatch.length
      planned = {}
      return
    for rec in cur.advice.hatch when not planned[rec.unit]?
      planned[rec.unit] = purchases rec.unit
    return

  buyView = (buys, unitName) ->
    buys: buys
    buyCount: buyCountString buys
    amount: bignum buys
    exact: exactText buys
    noun: if buys.equals(1) then label(unitName) else plural(unitName)
    reason: null

  # The buy-box button's view for one meat unit, or null when the advisor doesn't list it.
  suggestion = (cur, unitName) ->
    t = advisor.suggestionFor cur?.advice, unitName
    if not t?
      return null
    if (t.kind == 'buy' or t.kind == 'push') and t.buys.greaterThanOrEqualTo 1
      return buyView t.buys, unitName
    return {buys: null, reason: action t}

  # The same for a territory unit: its `hatch` record, else the reason nothing is hatched (House of
  # Mirrors running, saving for a twin, no larvae or meat), else null (another unit is advised).
  territorySuggestion = (cur, unitName) ->
    a = cur?.advice
    if not a?
      return null
    notePlan cur
    for rec in a.hatch when rec.unit == unitName and rec.buys.greaterThanOrEqualTo 1
      return buyView rec.buys, unitName
    if a.hatch.length and planned[unitName]? and purchases(unitName).greaterThan(planned[unitName])
      next = territoryLine a.hatch[0]
      return {buys: null, reason: 'done here; next', next: {text: next.text, href: next.href}}
    why = if a.status?.type == 'mirrors' then a.status else if a.twin?.type == 'saveForTwin' then a.twin else if a.status?.type == 'idle' then a.status else null
    if why?
      return {buys: null, reason: territoryLine(why).text}
    return null

  # ---------------------------------------------------------------------------
  # Ascension lines (advisorAscension), at most two: the mutagen to spend, then the stage of the run.

  of20 = (r) -> 'ascension ' + r.ascension + (if r.of? then ' of ' + r.of else '')

  # 13 G1: an ascension the swarmwarp route advises out of a run with House of Mirrors casts and many expansions
  restartsText = (rec) ->
    if not rec.restarts? then return null
    'this run has ' + bignum(rec.restarts.expansions) + ' expansions from House of Mirrors: ascending restarts them. The swarmwarp route still expects ascending to be faster.'

  # what a swarmwarp-route run is collecting (NO-MIRRORS.md 12.8)
  collecting = (rec) ->
    text = ''
    if rec.nextExpansion?
      text += '; expansions ' + bignum(rec.expansion) + '/' + bignum(rec.nextExpansion.val)
    if rec.nextEndless?
      text += '; endless bought ' + bignum(rec.endlessBought) + '/' + bignum(rec.nextEndless.val) + (if rec.top? then ' (top tier: ' + label(rec.top) + ')' else '')
    if rec.nextMutation?
      text += '; unlocks ' + rec.unlocks + '/' + bignum(rec.nextMutation.val)
    text

  mutagenStep = (s) ->
    switch s.type
      when 'unlock'
        {text: 'unlock ' + s.label + ' (' + count(s.price, 'mutagen') + ')', href: upgradeHref(s.name)}
      when 'mutants'
        if s.kind == 'share'
          {text: 'buy ' + count(s.count, s.unit) + ' (to ' + (s.share * 100) + '% of your mutagen: ' + bignum(s.target) + ')', href: href(s.unit)}
        else
          {text: 'buy ' + count(s.count, s.unit) + ' (' + bignum(s.have) + '/' + bignum(s.target) + ')', href: href(s.unit)}
      when 'respec'
        {text: 'respec (free, ' + s.free + ' left): the swarmwarp route needs the warp mutation, which you cannot afford as your next unlock', href: href('mutagen')}
      when 'unlocks'
        what = if s.count == 1 then 'mutation' else 'mutations'
        text = if s.any then 'unlock ' + s.count + ' more ' + what + ', any' else if s.all then 'unlock the ' + s.count + ' remaining ' + what else 'unlock ' + s.count + ' more ' + what
        {text: text + ' (' + count(s.price, 'mutagen') + ')', href: href('mutagen')}
      else {text: advisorAscension.renderStep(s), href: null}

  ascensionLine = (rec) ->
    line = {type: rec.type, href: null, strong: false}
    switch rec.type
      when 'mutagen'
        line.parts = (mutagenStep(s) for s in rec.steps)
        line.text = (p.text for p in line.parts).join(', then ')
        line.after = 'keep the rest (' + bignum(rec.keep) + ') unspent: it makes larvae'
        line.strong = true
      when 'spendForAscension'
        # below nexus 5 the cap still grows with each nexus, so no save point yet
        spells = if rec.route == 'swarmwarp' then 'lepidoptera, bats and swarmwarp' else 'lepidoptera and House of Mirrors'
        line.text = of20(rec) + ' costs ' + count(rec.cost, 'energy') + ' (cap ' + bignum(rec.cap) + '); every ' + bignum(rec.halving) + ' energy spent halves it' +
          (if rec.nexus >= 5 and rec.toSpend? then ' (' + spells + '); spend ' + bignum(rec.toSpend) + ' more, then save from ' + bignum(rec.saveAt) else ', mostly ' + spells + ' from nexus 5')
        line.href = href 'mutagen'
      when 'saveForAscension'
        line.text = 'stop casting and save for ' + of20(rec) + ': ' + bignum(rec.energy) + '/' + count(rec.cost, 'energy') +
          (if rec.seconds? then ', ready in ' + time(rec.seconds) else '')
        line.href = href 'mutagen'
        line.strong = true
      when 'ascendNow'
        if rec.noMutagen
          line.text = 'energy covers ' + of20(rec) + ' (' + bignum(rec.energy) + '/' + count(rec.cost, 'energy') + '), but it would bring no mutagen: wait for ' + label('premutagen') + ' from hatcheries and expansions'
          line.href = href 'premutagen'
        else
          line.text = 'ascend now (' + bignum(rec.energy) + '/' + count(rec.cost, 'energy') + '): brings ' + count(rec.premutagen, 'mutagen') + ', ' + of20(rec)
          line.href = href 'mutagen'
          line.strong = true
      when 'longRun'
        text = 'long run, do not ascend yet: expansions ' + bignum(rec.expansion)
        if rec.nextExpansion?
          text += '/' + bignum(rec.nextExpansion.val)
          if rec.lastExpansion? and not rec.lastExpansion.val.equals(rec.nextExpansion.val)
            text += ' (last ' + bignum(rec.lastExpansion.val) + ')'
        if rec.nextEndless?
          text += '; endless bought ' + bignum(rec.endlessBought) + '/' + bignum(rec.nextEndless.val) + (if rec.top? then ' (top tier: ' + label(rec.top) + ')' else '')
        line.text = text
        line.href = upgradeHref 'expansion'
        # the long-run climb mode is what climbs to endless; a hint only, never switched on here
        if rec.climbMode == false
          line.hint = {text: 'turn on long-run climb in Options', href: '#/options'}
      when 'done'
        line.text = if rec.route == 'swarmwarp' then 'every achievement of the swarmwarp route earned: no further ascension needed' else 'every ascension achievement earned: no further ascension needed'
      # the swarmwarp route (NO-MIRRORS.md 12.6, 12.8)
      when 'warpBuild'
        line.text = 'keep swarmwarping, do not ascend yet: ' + label('premutagen') + ' ' + bignum(rec.test.premutagen) + '/' + bignum(rec.test.need) + ' (' + bignum(rec.test.ratio) + ' × your mutagen) to ascend' + collecting(rec)
        line.href = href 'premutagen'
      when 'warpFinal'
        line.text = 'final run, do not ascend: expansions ' + bignum(rec.expansion) + '/' + bignum(rec.lastExpansion?.val ? 5000) + '; all spare energy into swarmwarp' + collecting(_.omit rec, 'nextExpansion')
        line.href = upgradeHref 'expansion'
        line.strong = true
      # the near-complete guard: this run is finished as the mirrors route's long run
      when 'routeGuard'
        line.text = bignum(rec.expansions) + ' of ' + bignum(rec.goal) + ' expansions: finish this run with House of Mirrors, then the swarmwarp route resumes'
        line.href = upgradeHref 'expansion'
        line.strong = true
      else
        line.text = advisorAscension.render rec
    # 13 G1: say plainly what an ascension out of a mirrors run with many expansions loses
    if rec.restarts? and rec.type in ['spendForAscension', 'saveForAscension', 'ascendNow']
      line.warning = restartsText rec
    return line

  # From `advisorAscension.current()` to the panel's ascension lines. Never throws.
  ascension = (acur) ->
    if not acur?
      return null
    if acur.error?
      return {error: errorText acur.error, lines: []}
    try
      return {error: null, lines: (ascensionLine(rec) for rec in acur.advice.records)}
    catch e
      return {error: errorText e, lines: []}

  return {
    panel: panel
    ascension: ascension
    suggestion: suggestion
    territory: territory
    territorySuggestion: territorySuggestion
    buyCountString: buyCountString
    action: action
    tip: tip
    energy: energy
  }


###*
 # @ngdoc directive
 # @name swarmApp.directive:advisorPanel
 # @description
 # The climbing advisor's panel: run age and larvae, a table of meat tiers with what to do with
 # each, upgrade tips and the energy line. Collapsible; hidden while the advisor is off.
###
angular.module('swarmApp').directive 'advisorPanel', ($rootScope, $log, advisor, advisorTerritory, advisorAscension, advisorView, options, ADVISOR_REFRESH_MILLIS) ->
  restrict: 'E'
  # current-unit: on a unit page, the unit shown there; its row (or territory line) is marked.
  scope:
    currentUnit: '@'
  template: """
<div class="panel panel-default advisor-panel" ng-if="enabled()">
  <div class="panel-heading">
    <h4 class="panel-title">
      <a href="javascript:" ng-click="toggle()" aria-expanded="{{!collapsed()}}">
        <span class="glyphicon" ng-class="collapsed() ? 'glyphicon-chevron-right' : 'glyphicon-chevron-down'" aria-hidden="true"></span>
        Climbing advisor
      </a>
      <small ng-if="collapsed() && view.summary" class="advisor-summary">&mdash; <span class="titlecase">{{view.summary.label}}</span>: {{view.summary.action}}</small>
    </h4>
  </div>
  <!-- the body parts are direct children of .panel so Bootstrap's panel table/list-group styles apply -->
  <div class="panel-body text-danger advisor-error" ng-if="!collapsed() && view.error">
    <span class="glyphicon glyphicon-exclamation-sign" aria-hidden="true"></span> Advisor error: {{view.error}}
  </div>
  <div class="panel-body text-muted" ng-if="!collapsed() && !view">Working it out&hellip;</div>
  <div class="panel-body small advisor-header" ng-if="!collapsed() && view.header">
    Run {{view.header.age}}<span ng-if="view.header.wallAge" class="advisor-gametime" title="Run age on the game clock: swarmwarp's skipped time counts as time passed"> game time ({{view.header.wallAge}} real)</span> &middot; climb if H &lt; {{view.header.horizon}} &middot;
    <span class="text-nowrap">{{view.header.larvae}} larvae (+{{view.header.larvaRate}}/sec)</span>
    <span ng-if="view.longRun" class="text-nowrap advisor-longrun" ng-class="{'text-muted': !view.longRun.active}">&middot; {{view.longRun.text}}</span>
  </div>
  <div class="table-responsive advisor-body" ng-if="!collapsed() && view.rows">
    <table class="table table-condensed advisor-table">
      <thead><tr>
        <th>Unit</th>
        <th class="text-right">Owned</th>
        <th class="text-right" title="Break-even time: hatching this leaves you with less meat than not hatching until about this long afterward">H</th>
        <th>Now</th>
      </tr></thead>
      <tbody>
        <tr ng-if="view.longRun.above" class="advisor-above"><td colspan="4" class="text-muted small">{{view.longRun.above}}</td></tr>
        <tr ng-repeat="row in view.rows track by row.name" ng-class="{success: row.kind == 'buy', info: row.kind == 'push', 'advisor-current': row.name == currentUnit}" class="advisor-row advisor-{{row.kind}}">
          <td class="titlecase text-nowrap"><span ng-if="row.name == currentUnit" class="glyphicon glyphicon-map-marker advisor-here" title="The unit on this page"></span><span ng-if="row.name == currentUnit" class="sr-only">(this page) </span><a ng-if="row.href" ng-href="{{row.href}}">{{row.label}}</a><span ng-if="!row.href">{{row.label}}</span></td>
          <td class="text-right text-nowrap">{{row.count|bignum:0}}</td>
          <td class="text-right text-nowrap">{{row.H}}</td>
          <td class="advisor-action" ng-class="{'text-muted': row.kind != 'buy' && row.kind != 'push'}"><strong ng-if="row.kind == 'buy' || row.kind == 'push'">{{row.action}}</strong><span ng-if="row.kind != 'buy' && row.kind != 'push'">{{row.action}}</span></td>
        </tr>
      </tbody>
    </table>
  </div>
  <ul class="list-group" ng-if="!collapsed() && (view.tips.length || view.energy || terr.error || terr.lines.length || asc.error || asc.lines.length)">
    <li class="list-group-item advisor-tip" ng-repeat="tip in view.tips">
      <span class="glyphicon glyphicon-circle-arrow-up" aria-hidden="true"></span>
      <a ng-if="tip.href" ng-href="{{tip.href}}">{{tip.text}}</a><span ng-if="!tip.href">{{tip.text}}</span>
    </li>
    <li class="list-group-item advisor-energy" ng-if="view.energy" ng-class="{'text-danger': view.energy.error}">
      <span class="glyphicon glyphicon-flash text-info" aria-hidden="true"></span> Energy:
      <a ng-if="view.energy.href" ng-href="{{view.energy.href}}">{{view.energy.text}}</a><span ng-if="!view.energy.href">{{view.energy.text}}</span>
    </li>
    <li class="list-group-item advisor-territory text-danger" ng-if="terr.error">
      <span class="glyphicon glyphicon-flag" aria-hidden="true"></span> Territory: {{terr.error}}
    </li>
    <!-- hatch lines are bold, not tinted: a tinted item hides its link on some dark themes (darkly) -->
    <li class="list-group-item advisor-territory" ng-repeat="line in terr.lines" ng-class="{'advisor-current': (line.unit && line.unit == currentUnit) || (line.units && line.units.indexOf(currentUnit) >= 0), 'advisor-plan': line.parts}">
      <span class="glyphicon glyphicon-flag" aria-hidden="true"></span> <span ng-if="$first">Territory:</span>
      <span ng-if="!line.parts">
        <span ng-if="line.unit && line.unit == currentUnit" class="glyphicon glyphicon-map-marker advisor-here" title="The unit on this page"></span><span ng-if="line.unit && line.unit == currentUnit" class="sr-only">(this page) </span>
        <a ng-if="line.href" ng-href="{{line.href}}"><strong ng-if="line.buy">{{line.text}}</strong><span ng-if="!line.buy">{{line.text}}</span></a><span ng-if="!line.href">{{line.text}}</span>
      </span>
      <span ng-if="line.parts" title="One plan: the territory larvae go into the biggest unit they can all afford, and spare meat moves some of them up to the next unit. Buy both, in either order.">
        <strong>hatch</strong>
        <span ng-repeat="part in line.parts" class="advisor-plan-part" ng-class="{'advisor-current': part.unit == currentUnit}"><span ng-if="!$first"> and </span><span ng-if="part.unit == currentUnit" class="glyphicon glyphicon-map-marker advisor-here" title="The unit on this page"></span><span ng-if="part.unit == currentUnit" class="sr-only">(this page) </span><a ng-if="part.href" ng-href="{{part.href}}"><strong>{{part.amount}}</strong></a><strong ng-if="!part.href">{{part.amount}}</strong></span><span ng-if="line.parts.length > 1" class="text-muted">, in any order</span>
      </span>
    </li>
    <li class="list-group-item advisor-ascension text-danger" ng-if="asc.error">
      <span class="glyphicon glyphicon-globe" aria-hidden="true"></span> Ascension: {{asc.error}}
    </li>
    <li class="list-group-item advisor-ascension" ng-repeat="line in asc.lines">
      <span class="glyphicon glyphicon-globe" aria-hidden="true"></span> <span ng-if="$first">Ascension:</span>
      <span ng-if="line.parts"><span ng-repeat="part in line.parts"><span ng-if="!$first">, then </span><a ng-if="part.href" ng-href="{{part.href}}"><strong>{{part.text}}</strong></a><strong ng-if="!part.href">{{part.text}}</strong></span><span class="text-muted">; {{line.after}}</span></span>
      <span ng-if="!line.parts"><a ng-if="line.href" ng-href="{{line.href}}"><strong ng-if="line.strong">{{line.text}}</strong><span ng-if="!line.strong">{{line.text}}</span></a><span ng-if="!line.href"><strong ng-if="line.strong">{{line.text}}</strong><span ng-if="!line.strong">{{line.text}}</span></span></span><span ng-if="line.hint" class="advisor-hint"> &middot; <a ng-href="{{line.hint.href}}">{{line.hint.text}}</a></span><span ng-if="line.warning" class="text-warning advisor-warning"> &middot; {{line.warning}}</span>
    </li>
  </ul>
</div>
"""
  link: (scope, element, attrs) ->
    scope.view = null
    scope.terr = null
    scope.asc = null
    scope.enabled = -> options.advisorEnabled()
    scope.collapsed = -> options.advisorCollapsed()
    scope.toggle = -> options.advisorCollapsed not options.advisorCollapsed()

    lastAt = null
    lastTerrAt = null
    lastAscAt = null
    # Called on every game tick (each animation frame). The advice itself is kept current by the
    # service-level tick (advisor.coffee); `current()` here normally just returns that cached result,
    # and the view is only rebuilt when it changed. The meat and territory parts are built separately,
    # so a failure in one leaves the other. Never throws: an exception here would stop the game loop.
    scope.refresh = ->
      if not options.advisorEnabled()
        scope.view = scope.terr = scope.asc = lastAt = lastTerrAt = lastAscAt = null
        return
      # The ascension advice first: the energy line agrees with it. A failure there costs only the
      # ascension lines (the energy line is then shown as without it).
      acur = null
      ascChanged = false
      try
        acur = advisorAscension.current ADVISOR_REFRESH_MILLIS
        if acur != lastAscAt or not scope.asc?
          lastAscAt = acur
          ascChanged = true
          scope.asc = advisorView.ascension acur
      catch e
        $log.warn 'advisor ascension', e
        acur = null
        scope.asc = {error: String(e?.message ? e), lines: []}
      # Territory before the meat panel: on the swarmwarp route the energy line waits for its open purchases.
      tcur = null
      terrChanged = false
      try
        tcur = advisorTerritory.current ADVISOR_REFRESH_MILLIS
        if tcur != lastTerrAt or not scope.terr?
          lastTerrAt = tcur
          terrChanged = true
          scope.terr = advisorView.territory tcur
      catch e
        $log.warn 'advisor territory', e
        tcur = null
        scope.terr = {error: String(e?.message ? e), lines: []}
      try
        cur = advisor.current ADVISOR_REFRESH_MILLIS
        if cur != lastAt or ascChanged or terrChanged or not scope.view?
          lastAt = cur
          scope.view = advisorView.panel cur, acur, tcur
      catch e
        $log.warn 'advisor panel', e
        scope.view = {error: String(e?.message ? e)}
      return
    scope.refresh()
    scope.$on '$destroy', $rootScope.$on 'tick', scope.refresh

###*
 # @ngdoc directive
 # @name swarmApp.directive:advisorSuggest
 # @description
 # Beside the buy box: when the climbing advisor suggests hatching this unit, a button that puts
 # the suggested amount into the box. Holding Shift does the same for as long as it is held, and
 # releasing it puts back what the box held before. It only fills the box; buying is still the
 # game's button.
###
angular.module('swarmApp').directive 'advisorSuggest', ($rootScope, $log, $window, $document, advisor, advisorTerritory, advisorView, options, ADVISOR_REFRESH_MILLIS) ->
  restrict: 'E'
  scope:
    unit: '='
    form: '='
  template: """
<div class="advisor-suggest form-group" ng-if="view">
  <button type="button" class="btn btn-sm" ng-class="view.buys ? 'btn-success' : 'btn-default'" ng-disabled="!view.buys" ng-click="use()" ng-mouseenter="peek()" ng-focus="peek()"
      title="{{view.buys ? 'Climbing advisor: put ' + view.exact + ' in the box. You still choose when to buy.' : 'The climbing advisor has no suggestion for this unit right now.'}}">
    <span class="glyphicon glyphicon-arrow-up" aria-hidden="true"></span>
    Use suggested<span ng-if="view.buys">: {{view.amount}} {{view.noun}}</span>
  </button>
  <small class="text-muted advisor-shift-hint" ng-if="view.buys" title="Holding Shift puts the suggested amount in the box (Shift-click the game's button to buy it); releasing Shift puts back what the box held. Typing a character with Shift leaves the box as you typed it.">or hold Shift</small>
  <small class="text-muted" ng-if="!view.buys" title="Advisor: {{view.reason}}{{view.next ? ' ' + view.next.text : ''}}">Advisor: {{view.reason}}<span ng-if="view.next"> <a ng-if="view.next.href" ng-href="{{view.next.href}}">{{view.next.text}}</a><span ng-if="!view.next.href">{{view.next.text}}</span></span></small>
</div>
"""
  link: (scope, element, attrs) ->
    scope.view = null
    lastAt = null
    # Meat units take the climbing advice, territory units the territory advice; others get nothing.
    source = ->
      name = scope.unit?.name
      if name in advisor.CHAIN
        return {service: advisor, view: advisorView.suggestion}
      if name in advisorTerritory.UNITS
        return {service: advisorTerritory, view: advisorView.territorySuggestion}
      return null
    read = (maxAgeMs) ->
      src = source()
      if not (options.advisorEnabled() and src?)
        lastAt = null
        return scope.view = null
      cur = src.service.current maxAgeMs
      if cur != lastAt or maxAgeMs == 0
        lastAt = cur
        scope.view = src.view cur, scope.unit.name
      return scope.view
    scope.refresh = ->
      try
        read ADVISOR_REFRESH_MILLIS
      catch e
        $log.warn 'advisor suggestion', e
        scope.view = null
      return
    # Pointing at (or tabbing to) the button refreshes its amount, so the number read just before the
    # click is the one the click writes: one extra rule run per hover, nothing per frame.
    scope.peek = ->
      try
        read 0
      catch e
        $log.warn 'advisor suggestion', e
      return
    # Writes the count from advice at most a quarter of a second old: normally exactly the amount on
    # the button, which the hover just refreshed; else (keyboard, touch) fresh advice, never the
    # up-to-a-second-old amount the button may still show.
    scope.use = ->
      try
        view = read 250
      catch e
        $log.warn 'advisor suggestion', e
        view = scope.view = null
      if view?.buys and scope.form?
        scope.form.buyCount = view.buyCount

    # Holding Shift fills the box with the suggestion and keeps it on the suggestion while held;
    # releasing Shift (or leaving the window, the tab or the page) puts back exactly what the box
    # held before. Shift is also how `%`, `@` and `=` are typed into the box, so a Shift that is
    # used for typing must never touch it: if any other key goes down while Shift is held, the fill
    # is undone at once (before that key's character lands) and Shift does nothing more until it
    # is released. A Shift pressed while another key or modifier is already down is typing too.
    # `filled` is the text Shift wrote, `saved` what the box held before; null while not filling.
    shift = {held: false, typing: false, filled: null, saved: null, caret: null}
    # Other keys down now, with when each last went down. A held key repeats its keydown, so an
    # entry older than a second is a key whose keyup was lost; it no longer counts.
    otherKeys = {}
    KEY_HELD_MILLIS = 1000
    isShift = (e) -> e.key == 'Shift' or e.keyCode == 16
    keyId = (e) -> e.code or e.key or String e.keyCode
    otherKeyDown = ->
      now = Date.now()
      for id, at of otherKeys when now - at < KEY_HELD_MILLIS
        return true
      return false
    # Where the caret was in the focused buy box before the fill, so undoing the fill for a
    # Shift-ed character puts it back there and the character lands where the player meant.
    caretBefore = ->
      try
        el = $document[0].activeElement
        if el?.tagName == 'INPUT' and el.value == String(scope.form.buyCount ? '')
          return {el: el, start: el.selectionStart, end: el.selectionEnd}
      catch e
      return null
    restoreCaret = (caret) ->
      try
        if caret? and $document[0].activeElement == caret.el and caret.el.value == String(scope.form?.buyCount ? '')
          caret.el.setSelectionRange caret.start, caret.end
      catch e
      return
    # Puts back what the box held, unless something else (the player) has changed it since the
    # fill: then what is there now stays.
    unfill = ->
      caret = null
      if shift.filled? and scope.form? and scope.form.buyCount == shift.filled
        scope.form.buyCount = shift.saved
        caret = shift.caret
      shift.filled = shift.saved = shift.caret = null
      return caret
    # Keeps the box on the suggestion while Shift is held. With no suggestion (none for this unit,
    # the advisor off, or a purchase just made and the unit now cooling down) the box goes back to
    # what it held before Shift, never a stale number; it fills again if a suggestion comes back.
    follow = (view) ->
      return if not (shift.held and not shift.typing and scope.form?)
      if shift.filled? and scope.form.buyCount != shift.filled
        # changed some other way while held (the "use suggested" button, a paste): that stays
        shift.filled = shift.saved = shift.caret = null
        shift.typing = true
        return
      if view?.buys
        if not shift.filled?
          shift.caret = caretBefore()
          shift.saved = scope.form.buyCount
        scope.form.buyCount = shift.filled = view.buyCount
      else
        unfill()
      return
    readFresh = (maxAgeMs) ->
      try
        return read maxAgeMs
      catch e
        $log.warn 'advisor suggestion', e
        return scope.view = null
    release = ->
      shift.held = shift.typing = false
      return unfill()
    apply = (fn) ->
      if $rootScope.$$phase then fn() else scope.$apply fn
      return

    onKeyDown = (e) ->
      if not isShift e
        otherKeys[keyId e] = Date.now()
        if shift.held and not shift.typing
          # Shift is being used with another key: put the box back before this key acts
          shift.typing = true
          if shift.filled?
            caret = null
            apply -> caret = unfill()
            restoreCaret caret
        return
      # a repeat is Shift still held from before (from another page, say): only a new press fills
      return if shift.held or e.repeat
      shift.held = true
      if e.ctrlKey or e.altKey or e.metaKey or otherKeyDown() or not options.advisorEnabled()
        shift.typing = true
        return
      # fresh advice, as for the button
      apply -> follow readFresh 250
      return
    onKeyUp = (e) ->
      if not isShift e
        delete otherKeys[keyId e]
        return
      if shift.held or shift.filled?
        apply release
      return
    onBlur = ->
      otherKeys = {}
      if shift.held or shift.filled?
        apply release
      return
    onVisibility = ->
      if $document[0].hidden
        onBlur()
      return
    $window.addEventListener 'keydown', onKeyDown, true
    $window.addEventListener 'keyup', onKeyUp, true
    $window.addEventListener 'blur', onBlur
    $document[0].addEventListener 'visibilitychange', onVisibility
    scope.$on '$destroy', ->
      $window.removeEventListener 'keydown', onKeyDown, true
      $window.removeEventListener 'keyup', onKeyUp, true
      $window.removeEventListener 'blur', onBlur
      $document[0].removeEventListener 'visibilitychange', onVisibility
      release()
      return
    # A purchase while held (Shift-click on the game's button): the advice after it, at once, so
    # the box never offers the same amount again from advice made before the purchase.
    scope.$on '$destroy', $rootScope.$on 'command', ->
      if shift.held and not shift.typing
        follow readFresh 0
      return

    scope.refresh()
    scope.$on '$destroy', $rootScope.$on 'tick', ->
      scope.refresh()
      follow scope.view
      return

###*
 # @ngdoc directive
 # @name swarmApp.directive:advisorOptions
 # @description
 # Climbing advisor settings on the options page.
###
angular.module('swarmApp').directive 'advisorOptions', ($log, options, advisor, advisorAscension, advisorTerritory, ADVISOR_SETTINGS) ->
  restrict: 'E'
  scope: {}
  template: """
<div class="form-group advisor-options">
  <label class="control-label">
    <span class="glyphicon glyphicon-education"></span> Climbing advisor
    <input type="checkbox" ng-model="form.enabled" ng-change="setEnabled(form.enabled)">
  </label>
  <p>Shows a panel beside your unit list saying which meat units to hatch and how many, which upgrades are worth buying, and what to do with energy, plus a "use suggested" button by the hatch box. It only advises: nothing is bought unless you press the game's own buttons.</p>
  <div ng-if="form.enabled" class="well well-sm">
    <div class="form-group advisor-route" ng-class="{'has-error': !!errors.ascension}">
      <label class="control-label">Route</label>
      <div class="radio"><label><input type="radio" name="advisor-ascension" value="off" ng-model="form.values.ascension" ng-change="setChoice('ascension')"> No ascension advice</label></div>
      <div class="radio"><label><input type="radio" name="advisor-ascension" value="achievements" ng-model="form.values.ascension" ng-change="setChoice('ascension')"> House of Mirrors route</label></div>
      <div class="radio"><label><input type="radio" name="advisor-ascension" value="swarmwarp" ng-model="form.values.ascension" ng-change="setChoice('ascension')"> Swarmwarp route</label></div>
      <p class="help-block advisor-help-route">{{routeHelp()}}</p>
      <p class="help-block advisor-help-switch" ng-if="route() != 'off'">You can switch routes at any time: the advisor works out where you are from your game. A run with House of Mirrors casts and 4,500 or more expansions is finished with House of Mirrors before the swarmwarp route takes over, and an ascension that would restart 1,000 or more expansions from House of Mirrors says so.</p>
      <p class="help-block" ng-if="errors.ascension">{{errors.ascension}}</p>
    </div>
    <div class="form-group" ng-repeat="field in fields" ng-class="{'has-error': !!errors[field.key], 'has-warning': !errors[field.key] && !!notes[field.key]}">
      <label class="control-label" for="advisor-{{field.key}}">{{field.label}}</label>
      <input type="text" inputmode="decimal" class="form-control input-sm advisor-setting" id="advisor-{{field.key}}" style="max-width:10em"
        ng-model="form.values[field.key]" ng-model-options="{updateOn: 'blur'}" ng-change="setValue(field.key)" ng-keydown="enterCommits($event)">
      <p class="help-block advisor-help-{{field.key}}">{{help(field.key)}} Default {{defaults[field.key]}}.</p>
      <p class="help-block" ng-if="errors[field.key]">{{errors[field.key]}}</p>
      <p class="help-block" ng-if="!errors[field.key] && notes[field.key]">{{notes[field.key]}}</p>
    </div>
    <div class="form-group" ng-class="{'has-error': !!errors.spareEnergy}">
      <label class="control-label">Spare energy before nexus 5</label>
      <div class="radio"><label><input type="radio" name="advisor-spareEnergy" value="save" ng-model="form.values.spareEnergy" ng-change="setChoice('spareEnergy')"> Plan it for the next nexus</label></div>
      <div class="radio"><label><input type="radio" name="advisor-spareEnergy" value="larvarush" ng-model="form.values.spareEnergy" ng-change="setChoice('spareEnergy')"> Cast larva rush (as the console script did)</label></div>
      <p class="help-block advisor-help-spareEnergy">Planning holds energy for the next nexus and keeps its larvae out of the climb; at nexus 4 it buys 1,000 lepidoptera first, then keeps only the energy nexus 5 will need by the time its larvae are there and puts the rest into lepidoptera. Larva rush casts spare energy instead. Default: plan it.</p>
      <p class="help-block" ng-if="errors.spareEnergy">{{errors.spareEnergy}}</p>
    </div>
    <div class="form-group" ng-class="{'has-error': !!errors.longRun}">
      <label class="control-label">Long-run climb</label>
      <div ng-if="route() != 'swarmwarp'">
        <div class="radio"><label><input type="radio" name="advisor-longRun" value="off" ng-model="form.values.longRun" ng-change="setChoice('longRun')"> Off</label></div>
        <div class="radio"><label><input type="radio" name="advisor-longRun" value="on" ng-model="form.values.longRun" ng-change="setChoice('longRun')"> On</label></div>
      </div>
      <div ng-if="route() == 'swarmwarp'" class="advisor-longrun-forced">
        <div class="radio disabled"><label><input type="radio" name="advisor-longRun-forced" disabled> Off</label></div>
        <div class="radio disabled"><label><input type="radio" name="advisor-longRun-forced" checked disabled> On</label></div>
        <p class="help-block">Always on with the swarmwarp route; your choice here is kept for the House of Mirrors route.</p>
      </div>
      <p class="help-block advisor-help-longRun">{{longRunHelp()}}</p>
      <p class="help-block" ng-if="errors.longRun">{{errors.longRun}}</p>
    </div>
    <button type="button" class="btn btn-default btn-sm" ng-click="reset()">Reset advisor settings to defaults</button>
  </div>
</div>
"""
  link: (scope, element, attrs) ->
    scope.defaults = ADVISOR_SETTINGS.defaults
    scope.fields = [
      {key: 'ageMultiple', label: 'Climb multiple'}
      {key: 'share', label: 'Share per minute'}
      {key: 'cooldown', label: 'Cooldown (seconds)'}
      {key: 'bank', label: 'Banking threshold'}
      {key: 'territory', label: 'Territory share'}
      {key: 'moths', label: 'Lepidoptera target'}
    ]
    # Every help text says what is true for the route picked (the `ascension` setting), live as it changes.
    scope.route = ->
      switch scope.form.values.ascension
        when 'swarmwarp' then 'swarmwarp'
        when 'off' then 'off'
        else 'mirrors'
    ROUTE_HELP =
      off: "No ascension advice: the advisor climbs and spends energy within the run (House of Mirrors from nexus 5), and never says when to ascend or what to buy with mutagen."
      mirrors: "Every achievement with House of Mirrors: one early ascension for the lepidoptera mutation, one long run to 5,000 expansions and the endless achievements, then quick runs up to 20 ascensions. The advisor says when to spend energy, save it and ascend, and what to buy with mutagen. This is the default."
      swarmwarp: "Every achievement without House of Mirrors: after nexus 5, lepidoptera and 2,000 bats, then swarmwarp one cast at a time with the purchases each cast releases in between; an ascension whenever this run's mutagen (inactive) reaches 1,000 times the mutagen you hold, until a final run from 1e270 mutagen to 5,000 expansions. In the simulator it reached every achievement in about 141 days, against 174 for the House of Mirrors route (simulator figures, not measured in play)."
    scope.routeHelp = -> ROUTE_HELP[scope.route()]
    fmt = advisor.formatNumber
    setting = (key) ->
      v = Number scope.form.values[key]
      if _.isFinite(v) then v else Number(options.advisorSetting key)
    scope.help = (key) ->
      route = scope.route()
      switch key
        when 'ageMultiple'
          "Hatch a tier once its break-even time (H) is under this many times the run's age, in game time (real time plus what swarmwarp skipped). " +
            (if route == 'swarmwarp' then "This route was simulated with 5; each swarmwarp adds its skip to the age, so the limit jumps with every cast." else "3 suits runs of a day or so; 5 suits runs lasting several days.")
        when 'share' then "Share of the tier below offered for each minute of game time since you last hatched a unit (0.5 = half). Any swarmwarp releases all of it."
        when 'cooldown' then "After you hatch a unit, wait this many seconds of game time before suggesting it again. Any swarmwarp ends the wait."
        when 'bank' then "Stop hatching a unit, and save its larvae, once the tier above already makes this many times what larvae could."
        when 'territory'
          switch route
            when 'swarmwarp' then "Share of larvae kept for territory units. Keep it at 0.1: territory units are never stopped on this route (expansions come from them), and the advisor asks for 0.1 back if it is 0."
            when 'mirrors' then "Share of larvae kept for territory units. Set to 0 once House of Mirrors is casting (the advisor tells you when)."
            else "Share of larvae kept for territory units (0.1 = 10%)."
        when 'moths'
          v = setting 'moths'
          switch route
            when 'swarmwarp' then "Lepidoptera bought with energy after nexus 5. With this setting the swarmwarp route buys " + fmt(Math.max v, 10000) + " in every run (this setting when higher), then 2,000 bats, then swarmwarp."
            when 'mirrors'
              if v < 10000
                "Lepidoptera bought with energy, before House of Mirrors from nexus 5. With this setting the route buys 10,000 in a first run, 30,000 in a quick run and from day 3 of the long run, and " + fmt(v) + " in the long run before that (this setting when higher)."
              else
                "Lepidoptera bought with energy, before House of Mirrors from nexus 5. With this setting the route buys " + fmt(v) + " in a first run and early in the long run, and " + fmt(Math.max v, 30000) + " in a quick run and from day 3 of the long run."
            else "Lepidoptera bought with energy, before House of Mirrors from nexus 5: " + fmt(v) + "."
    scope.longRunHelp = ->
      if scope.route() == 'swarmwarp'
        return "From a run age of 2 days of game time it feeds the tiers above your climb upward (\"feed upward\"), keeping 1% of the larvae for that, and keeps those units from twin upgrades. Stay a couple of minutes per visit: the next steps show once the last ones are bought."
      "For climbing to endless on runs of many days. It does nothing before a run is 2 days old in game time. From then it feeds the tiers above your climb upward (\"feed upward\"), keeping 1% of the larvae for that, keeps those units from twin upgrades, and from day 3 raises the lepidoptera target to 30,000. It trades meat income for progress up the chain, so leave it off for short runs. Default: off."
    limits = ADVISOR_SETTINGS.limits

    scope.form = {enabled: options.advisorEnabled(), values: {}}
    # a changed setting changes every advisor line: work them all out afresh at once
    invalidateAll = ->
      advisor.invalidate()
      advisorAscension.invalidate()
      advisorTerritory.invalidate()
    scope.errors = {}
    scope.notes = {}
    syncAll = ->
      config = options.advisorConfig()
      for key, val of config
        scope.form.values[key] = String val
      scope.errors = {}
      scope.notes = {}
    syncAll()

    # A two-way choice, saved as soon as it is picked (as the game's own radio options are).
    scope.setChoice = (key) ->
      delete scope.errors[key]
      try
        options.advisorSetting key, scope.form.values[key]
        invalidateAll()
      catch e
        $log.debug 'advisor setting rejected', key, e
        scope.errors[key] = 'Not a valid choice. Still using ' + options.advisorSetting(key) + '.'
        scope.form.values[key] = options.advisorSetting key
      return

    scope.setEnabled = (enabled) ->
      options.advisorEnabled !!enabled
      advisor.invalidate()

    # Save one setting from its text box, when the box loses focus or on Enter (not per keystroke,
    # so half-typed values are never stored). Bad input shows an error and leaves the stored value
    # as it was; a clamped value is written back into the box with a note.
    scope.setValue = (key) ->
      text = scope.form.values[key]
      delete scope.errors[key]
      delete scope.notes[key]
      limit = limits[key]
      range = "#{limit.min} to #{limit.max}"
      if not text? or String(text).trim() == '' or not _.isFinite Number text
        scope.errors[key] = "Enter a number from #{range}. Still using #{options.advisorSetting key}."
        return
      try
        stored = options.advisorSetting key, String(text).trim()
      catch e
        $log.debug 'advisor setting rejected', key, text, e
        scope.errors[key] = "Enter a number from #{range}. Still using #{options.advisorSetting key}."
        return
      invalidateAll()
      if stored != Number text
        scope.notes[key] = "Saved as #{stored} (allowed: #{range}#{if limit.integer then ', whole numbers' else ''})."
      scope.form.values[key] = String stored
      return

    # The boxes aren't in a form, so make Enter commit like leaving the box does.
    scope.enterCommits = ($event) ->
      if $event?.keyCode == 13
        $event.target?.blur?()
      return

    scope.reset = ->
      options.resetAdvisorConfig()
      invalidateAll()
      syncAll()
