'use strict'

# Expected values are worked out by hand from the ascension cost formula (game.coffee, ascendCost;
# advisor/ASCENSION.md B2.2) and the route of ASCENSION.md A.1 / A.5; the comments show the arithmetic.
describe 'Service: advisorAscension', ->

  beforeEach module 'swarmApp'

  asc = advisor = null
  beforeEach inject (_advisorAscension_, _advisor_) ->
    asc = _advisorAscension_
    advisor = _advisor_

  D = (x) -> new Decimal x
  ON = {ascension: 'achievements'}
  UNLOCKS = ['mutatehatchery', 'mutatebat', 'mutateclone', 'mutateswarmwarp', 'mutaterush', 'mutateeach',
    'mutatefreq', 'mutatenexus', 'mutatearmy', 'mutatemeat']
  EXPANSIONS = [['expansion1', 1], ['expansion2', 20], ['expansion3', 50], ['expansion4', 100], ['expansion5', 200],
    ['expansion6', 500], ['expansion7', 1000], ['expansion8', 2000], ['expansion9', 5000]]
  ENDLESS = [['overmind6_1', 1], ['overmind6_2', 1e31], ['overmind6_3', 1e62]]
  ASCENSIONS = [['ascension1', 1], ['ascension11', 3], ['ascension2', 5], ['ascension21', 10], ['ascension3', 20]]

  # A hand-built snapshot. Defaults: the first run at nexus 5, no mutation (halving 50,000 energy),
  # cap 58,500, energy 10,000 at 0.5/s, cost 1,000,000.
  mksnap = (o={}) ->
    earned = {}
    for name in o.earned ? []
      earned[name] = true
    goal = ([name, val]) -> {name: name, label: name, val: D(val), earned: !!earned[name], perRun: /^expansion/.test name}
    unlocked = o.unlocked ? []
    {
      now: 1000e3
      restartedAt: 0
      ascensions: o.ascensions ? 0
      energy: D(o.energy ? 10000)
      cap: if o.cap is null then null else D(o.cap ? 58500)
      rate: D(o.rate ? 0.5)
      spent: D(0)
      cost: D(o.cost ? 1e6)
      halving: o.halving ? 50000
      nexus: o.nexus ? 5
      premutagen: D(o.premutagen ? 6e7)
      mutagen: D(o.mutagen ? 0)
      unlocks: for name in UNLOCKS
        name: name
        label: name.replace 'mutate', 'mutate '
        unit: name.replace 'mutate', 'mutant'
        unlocked: name in unlocked
        price: D(Math.pow 15625, unlocked.length)
        factor: D(15625)
      nexusMutants: D(o.nexusMutants ? 0)
      nexusMutantPrice: D(1)
      expansion: o.expansion ? 0
      top: o.top ? 'hivequeen'
      endlessBought: D(o.endlessBought ? 0)
      goals:
        expansion: (goal g for g in EXPANSIONS)
        endless: (goal g for g in ENDLESS)
        ascension: (goal g for g in ASCENSIONS)
    }
  LONG = (g[0] for g in EXPANSIONS.concat ENDLESS)
  ascEarned = (n) -> (g[0] for g in ASCENSIONS when g[1] <= n)
  texts = (r) -> (asc.render x for x in r.records)

  it 'does nothing while the setting is off', ->
    for cfg in [{}, {ascension: 'off'}, null, undefined]
      r = asc.advise mksnap(), cfg
      expect(r.stage).toBe 'off'
      expect(r.records).toEqual []
      expect(r.plan).toBe null
      expect(r.hold).toBe null
    # the live update does not even read the game
    spyOn(asc, 'snapshot').and.callThrough()
    expect(asc.update().stage).toBe 'off'
    expect(asc.snapshot).not.toHaveBeenCalled()

  describe 'the first run: spend, save, ascend', ->
    it 'shows the cost against the cap below nexus 5, and what brings it down', ->
      r = asc.advise mksnap(nexus: 4, cost: 2507811, cap: 48500), ON
      expect(r.stage).toBe 'firstRun'
      expect(r.plan.type).toBe 'spendForAscension'
      expect(r.plan.ascension).toBe 1
      expect(r.plan.of).toBe 20 # the largest ascension achievement
      expect(texts r).toEqual ['ascension 1 of 20 costs 2.51e6 energy (cap 48,500): every 50,000 energy spent halves it, mostly House of Mirrors from nexus 5']

    it 'at nexus 5, says how much more to spend before saving', ->
      # saving starts at min(cap 58,500, 50,000 / ln 2 = 72,134); spend 50,000 x log2(80,000 / 58,500) = 22,578.5
      r = asc.advise mksnap(cost: 80000), ON
      expect(r.plan.saveAt.toNumber()).toBe 58500
      expect(r.plan.threshold.toNumber()).toBe 72134
      expect(r.plan.toSpend.toNumber()).toBe 22579
      expect(texts r).toEqual ['ascension 1 of 20 costs 80,000 energy (cap 58,500): every 50,000 energy spent halves it (House of Mirrors); spend 22,579 more, then save from 58,500']

    it 'starts saving when the cost reaches the cap, if the cap is under 50,000 / ln 2', ->
      # 50,000 x log2(58,501 / 58,500) = 1.23
      r = asc.advise mksnap(cost: 58501), ON
      expect(r.plan.type).toBe 'spendForAscension'
      expect(r.plan.toSpend.toNumber()).toBe 2
      expect(r.hold).toBe null
      r = asc.advise mksnap(cost: 58500), ON
      expect(r.plan.type).toBe 'saveForAscension'
      expect(r.hold).toBe r.plan

    it 'starts saving at 50,000 / ln 2 when the cap is higher', ->
      expect(asc.advise(mksnap(cost: 72135, cap: 100000), ON).plan.type).toBe 'spendForAscension'
      expect(asc.advise(mksnap(cost: 72134, cap: 100000), ON).plan.type).toBe 'saveForAscension'

    it 'gives have/need energy and the time from the energy rate while saving', ->
      # (52,791 - 20,000) / 0.8928 per second = 36,728 s
      r = asc.advise mksnap(cost: 52791, energy: 20000, rate: 0.8928), ON
      expect(r.plan.need.toNumber()).toBe 32791
      expect(r.plan.seconds).toBeCloseTo 36728.27, 1
      expect(texts r).toEqual ['stop spending energy and save for ascension 1 of 20: 20,000/52,791, ready in 10.2 h']
      r = asc.advise mksnap(cost: 52791, energy: 20000, rate: 0), ON
      expect(r.plan.seconds).toBe null
      expect(texts r).toEqual ['stop spending energy and save for ascension 1 of 20: 20,000/52,791']

    it 'says ascend now once the energy covers the cost, and what it brings', ->
      r = asc.advise mksnap(cost: 52791, energy: 52790), ON
      expect(r.plan.type).toBe 'saveForAscension'
      expect(r.plan.seconds).toBe 2
      r = asc.advise mksnap(cost: 52791, energy: 52791, premutagen: 6.01e7), ON
      expect(r.plan.type).toBe 'ascendNow'
      expect(r.hold).toBe r.plan
      expect(texts r).toEqual ['ascend now: 52,791/52,791 energy; brings 6.01e7 mutagen, ascension 1 of 20']

    it 'does not say ascend while the ascension would bring no mutagen', ->
      r = asc.advise mksnap(cost: 52791, energy: 60000, premutagen: 0), ON
      expect(r.plan.noMutagen).toBe true
      expect(texts r).toEqual ['energy covers ascension 1 of 20 (60,000/52,791) but it would bring no mutagen: wait for mutagen (inactive) from hatcheries and expansions']

    it 'needs no cap to work it out', ->
      r = asc.advise mksnap(cap: null, cost: 72134), ON
      expect(r.plan.saveAt.toNumber()).toBe 72134
      expect(r.plan.type).toBe 'saveForAscension'

  describe 'mutagen after an ascension', ->
    it 'after the first: the lepidoptera mutation, a million of it, one more unlock, the rest kept', ->
      # 6e7 - 1 - 999,999 - 15,625 = 58,984,375 kept
      r = asc.advise mksnap(ascensions: 1, mutagen: 6e7, premutagen: 0, cost: 5.6e6, cap: 8500, nexus: 0), ON
      m = r.mutagen
      expect(r.records[0]).toBe m
      expect(_.map m.steps, 'type').toEqual ['unlock', 'mutants', 'unlocks']
      expect(m.steps[0].name).toBe 'mutatenexus'
      expect(m.steps[1].count.toNumber()).toBe 999999
      expect(m.steps[2].count).toBe 1
      expect(m.steps[2].price.toNumber()).toBe 15625
      expect(m.keep.toNumber()).toBe 58984375
      expect(texts(r)[0]).toBe 'unlock mutate nexus (1), then buy 999,999 lepidoptera mutations (1/1.00e6), then unlock 1 more mutation, any (15,625); keep the rest (5.90e7) unspent: it makes larvae'

    it 'drops each purchase once it is done', ->
      base = {ascensions: 1, mutagen: 6e7, premutagen: 0}
      m = asc.advise(mksnap(_.extend {unlocked: ['mutatenexus'], nexusMutants: 1}, base), ON).mutagen
      expect(_.map m.steps, 'type').toEqual ['mutants', 'unlocks']
      expect(m.steps[0].count.toNumber()).toBe 999999
      m = asc.advise(mksnap(_.extend {unlocked: ['mutatenexus'], nexusMutants: 1e6}, base), ON).mutagen
      expect(_.map m.steps, 'type').toEqual ['unlocks']
      r = asc.advise mksnap(_.extend({unlocked: ['mutatenexus', 'mutatefreq'], nexusMutants: 1e6}, base)), ON
      expect(r.mutagen).toBe null
      expect(r.records.length).toBe 1

    it 'only what is affordable', ->
      # 10,000 mutagen: unlock (1), then 9,999 mutants; the second unlock (15,625) is out of reach
      m = asc.advise(mksnap(ascensions: 1, mutagen: 10000), ON).mutagen
      expect(_.map m.steps, 'type').toEqual ['unlock', 'mutants']
      expect(m.steps[1].count.toNumber()).toBe 9999
      expect(m.keep.toNumber()).toBe 0
      # nothing at all with less than one mutagen, nor before any ascension
      expect(asc.advise(mksnap(ascensions: 1, mutagen: 0.5), ON).mutagen).toBe null
      expect(asc.advise(mksnap(ascensions: 0, mutagen: 6e7), ON).mutagen).toBe null

    it 'from the second ascension, every remaining unlock', ->
      # 2 unlocked: the other 8 cost 15,625^2 + ... + 15,625^9 = 5.5514704e37
      snap = mksnap ascensions: 2, mutagen: 1e40, unlocked: ['mutatenexus', 'mutatefreq'], nexusMutants: 1e6, earned: LONG
      m = asc.advise(snap, ON).mutagen
      expect(m.steps.length).toBe 1
      s = m.steps[0]
      expect([s.count, s.all, s.any]).toEqual [8, true, false]
      expect(s.price.toNumber() / 5.5514704172324856e37).toBeCloseTo 1, 12
      expect(asc.renderStep s).toBe 'unlock the 8 remaining mutations (5.55e37)'
      # 3e12 pays for the third (2.44e8) only: the fourth costs 3.81e12
      snap.mutagen = D 3e12
      s = asc.advise(snap, ON).mutagen.steps[0]
      expect([s.count, s.all, s.price.toNumber()]).toEqual [1, false, 244140625]
      # and tops the lepidoptera mutation back up to a million after a respec
      snap.nexusMutants = D 400000
      expect(_.map asc.advise(snap, ON).mutagen.steps, 'type').toEqual ['mutants', 'unlocks']

  describe 'the stage, from the game state', ->
    it 'the long run: the lepidoptera mutation bought, long-run achievements still missing', ->
      snap = mksnap {
        ascensions: 1, unlocked: ['mutatenexus', 'mutatefreq'], nexusMutants: 1e6, mutagen: 6e7, expansion: 1780, top: 'overmind4'
        earned: ['expansion1', 'expansion2', 'expansion3', 'expansion4', 'expansion5', 'expansion6', 'expansion7', 'ascension1']
      }
      r = asc.advise snap, ON
      expect(r.stage).toBe 'longRun'
      expect(r.plan).toBe null
      expect(r.hold).toBe null
      line = r.records[0]
      expect(line.type).toBe 'longRun'
      expect(line.nextExpansion.val.toNumber()).toBe 2000
      expect(line.lastExpansion.val.toNumber()).toBe 5000
      expect(line.nextEndless.val.toNumber()).toBe 1
      expect(texts r).toEqual ['long run: do not ascend yet; expansions 1,780/2,000 (last 5,000); endless bought 0/1 (top tier overmind4)']

    it 'the long run: progress toward the endless achievements', ->
      earned = (g[0] for g in EXPANSIONS).concat ['overmind6_1', 'ascension1']
      snap = mksnap ascensions: 1, unlocked: ['mutatenexus'], nexusMutants: 1e6, expansion: 5100, endlessBought: 3e20, earned: earned, top: 'overmind6'
      r = asc.advise snap, ON
      expect(r.stage).toBe 'longRun'
      expect(r.records[0].nextExpansion).toBe null
      expect(texts r).toEqual ['long run: do not ascend yet; expansions 5,100; endless bought 3.00e20/1.00e31 (top tier overmind6)']

    it 'the long run starts as soon as the lepidoptera mutation is affordable', ->
      r = asc.advise mksnap(ascensions: 1, mutagen: 1), ON
      expect(r.stage).toBe 'longRun'
      expect(_.map r.records, 'type').toEqual ['mutagen', 'longRun']

    it 'another short run when the mutation is neither bought nor affordable', ->
      r = asc.advise mksnap(ascensions: 1, mutagen: 0, cost: 4e6, cap: 8500, nexus: 0, earned: ['ascension1']), ON
      expect(r.stage).toBe 'needMutation'
      expect(r.plan.type).toBe 'spendForAscension'
      expect(r.plan.ascension).toBe 2

    it 'quick runs once the long-run achievements are earned, counting toward 20', ->
      # with the lepidoptera mutation at a million: halving 79,940, so saving starts at min(cap 108,500, 115,329)
      snap = mksnap ascensions: 6, unlocked: UNLOCKS, nexusMutants: 1e6, halving: 79940, cap: 108500, cost: 108501, earned: LONG.concat ascEarned 6
      r = asc.advise snap, ON
      expect(r.stage).toBe 'quickRun'
      expect(r.plan.type).toBe 'spendForAscension'
      expect(r.plan.saveAt.toNumber()).toBe 108500
      expect(texts(r)[0]).toContain 'ascension 7 of 20 costs 108,501 energy'
      snap.cost = D 108500
      r = asc.advise snap, ON
      expect(texts r).toEqual ['stop spending energy and save for ascension 7 of 20: 10,000/108,500, ready in 2.3 d']
      # with no mutagen the quick runs still ascend: they are for the count
      snap.energy = D 108500
      snap.premutagen = D 0
      r = asc.advise snap, ON
      expect(r.plan.noMutagen).toBeUndefined()
      expect(texts r).toEqual ['ascend now: 108,500/108,500 energy; brings 0 mutagen, ascension 7 of 20']

    it 'the quick runs come first too, if the long run is not done but 20 ascensions are not either', ->
      # the long run is recognised by its achievements, not by the ascension count
      r = asc.advise mksnap(ascensions: 5, unlocked: ['mutatenexus'], nexusMutants: 1e6, earned: ascEarned 5), ON
      expect(r.stage).toBe 'longRun'

    it 'done: every ascension and long-run achievement', ->
      r = asc.advise mksnap(ascensions: 20, unlocked: UNLOCKS, nexusMutants: 1e6, earned: LONG.concat ascEarned 20), ON
      expect(r.stage).toBe 'done'
      expect(texts r).toEqual ['every ascension achievement earned: no further ascension needed']
      # 20 ascensions but the long run still to do: no ascension, the long run
      r = asc.advise mksnap(ascensions: 20, unlocked: UNLOCKS, nexusMutants: 1e6, earned: ascEarned 20), ON
      expect(r.stage).toBe 'longRun'

    it 'never more than two lines', ->
      for snap in [mksnap(), mksnap(ascensions: 1, mutagen: 6e7), mksnap(ascensions: 2, mutagen: 1e40, earned: LONG), mksnap(ascensions: 20, earned: LONG.concat ascEarned 20)]
        expect(asc.advise(snap, ON).records.length).toBeLessThan 3

  describe 'the energy line', ->
    cast = -> {type: 'cast', spell: 'clonearmy', label: 'House of Mirrors', cost: 2500, casts: D(20)}

    it 'is the same object, untouched, while the setting is off or the long run is on', ->
      for rec in [cast(), {type: 'buyNexus', level: 5}, null]
        expect(asc.coupleEnergy rec, asc.advise(mksnap(cost: 50000), {})).toBe rec
        expect(asc.coupleEnergy rec, null).toBe rec
        expect(asc.coupleEnergy rec, asc.advise(mksnap(ascensions: 1, unlocked: ['mutatenexus'], nexusMutants: 1e6), ON)).toBe rec

    it 'saves instead of spending once saving has started', ->
      a = asc.advise mksnap(cost: 52791, energy: 20000, rate: 0.8928), ON
      for type in ['cast', 'nextCast', 'buyMoths', 'mothTarget', 'energyFull']
        c = asc.coupleEnergy {type: type}, a
        expect(c.type).toBe 'ascensionHold'
        expect(c.ready).toBe false
        expect(c.replaces).toBe type
        expect(asc.render c).toBe 'saving for the ascension: 20,000/52,791, ready in 10.2 h'
      # a nexus to buy or to save for, and the held spare energy, are left alone
      for rec in [{type: 'buyNexus', level: 5}, {type: 'save', level: 5, missing: []}, {type: 'hold', level: 5}]
        expect(asc.coupleEnergy rec, a).toBe rec
      ready = asc.coupleEnergy cast(), asc.advise(mksnap(cost: 52791, energy: 52791), ON)
      expect(ready.ready).toBe true
      expect(asc.render ready).toBe 'hold it for the ascension (52,791/52,791)'

    it 'cuts the casts to those that bring the cost to the save point', ->
      # spend 22,579 more: ceil(22,579 / 2,500) = 10 casts of House of Mirrors
      a = asc.advise mksnap(cost: 80000), ON
      c = asc.coupleEnergy cast(), a
      expect(c.casts.toNumber()).toBe 10
      expect(c.thenSave).toBe true
      expect(c.spell).toBe 'clonearmy'
      # fewer casts than that: unchanged
      few = _.extend cast(), casts: D(10)
      expect(asc.coupleEnergy few, a).toBe few

    it 'leaves the meat and energy advice itself alone, whatever the setting', ->
      # the coupling lives outside advisor.advise(): the setting never reaches it
      snap =
        now: 1000e3
        restartedAt: 0
        larvae: D(0)
        larvaRate: D(1)
        units: []
        energy: {cap: D(58500), nexus: 5, energy: D(50000), moths: D(4000), next: null}
      expect(advisor.energyAdvice snap, ON).toEqual advisor.energyAdvice(snap, {})
      expect(advisor.renderEnergy advisor.energyAdvice snap, ON).toBe 'cast House of Mirrors x20'
      snap.energy.nexus = 3
      expect(advisor.energyAdvice snap, _.extend({spareEnergy: 'save'}, ON)).toEqual advisor.energyAdvice(snap, {spareEnergy: 'save'})

  describe 'live wiring', ->
    it 'is driven by the advisor tick, once a second, and never throws', inject ($rootScope, options) ->
      spyOn(asc, 'update').and.callThrough()
      $rootScope.$emit 'tick'
      expect(asc.update.calls.count()).toBe 1
      $rootScope.$emit 'tick'
      expect(asc.update.calls.count()).toBe 1
      asc.update.and.throwError 'boom'
      asc.invalidate()
      cur = asc.current 1000, 1
      expect(cur.advice).toBe null
      expect(cur.error.message).toBe 'boom'
      expect(-> $rootScope.$emit 'tick').not.toThrow()

    it 'advises afresh after a purchase or an ascension', inject ($rootScope) ->
      a = asc.current 1000, 5000
      expect(asc.current(1000, 5001)).toBe a
      $rootScope.$emit 'command', {name: 'ascend'}
      expect(asc.current(1000, 5002)).not.toBe a

    it 'advises on a brand-new game when on', inject (game, options) ->
      game.reset true
      options.advisorSetting 'ascension', 'achievements'
      r = asc.update()
      expect(r.stage).toBe 'firstRun'
      # nothing spent, no ascension: 5,000,000; no nexus, so no cap
      expect(r.plan.cost.toNumber()).toBe 5e6
      expect(r.plan.type).toBe 'spendForAscension'

describe 'Service: advisorAscension on a real save', ->

  beforeEach module 'swarmApp'

  asc = advisor = Game = session = null
  beforeEach inject (_advisorAscension_, _advisor_, _Game_, _session_) ->
    asc = _advisorAscension_
    advisor = _advisor_
    Game = _Game_
    session = _session_
  ON = {ascension: 'achievements'}

  # The owner's save from 20.1 hours into a run (advisor/sim/example_save_20h.json, decoded JSON): never
  # ascended, nexus 4. Loaded as in test/spec/services/advisor.coffee.
  fetchSave = ->
    files = window.__karma__?.files ? {}
    url = _.find _.keys(files), (f) -> /advisor\/sim\/example_save_20h\.json$/.test f
    if not url?
      throw new Error 'advisor/sim/example_save_20h.json is not served by karma; add it to the karma files list'
    xhr = new XMLHttpRequest()
    xhr.open 'GET', url, false
    xhr.send()
    return JSON.parse xhr.responseText
  loadGame = ->
    state = session._loads session._saves fetchSave(), false
    shift = (new Date().getTime() - 3600e3) - state.date.reified.getTime()
    for key, date of state.date
      state.date[key] = new Date date.getTime() + shift
    game = new Game {state: state, save: ->}
    game.now = new Date state.date.reified.getTime()
    game.cache.onUpdate()
    return game
  # set a resource high enough to buy with, through the game's own unit
  give = (game, name, val) -> game.unit(name)._setCount val
  texts = (r) -> (asc.render x for x in r.records)

  it 'reads the ascension cost the write-up quotes, and the first-run stage', ->
    game = loadGame()
    snap = asc.snapshot game
    # ASCENSION.md B2.2: spent 49,775 = 3,665 lepidoptera x 10 + nexus 2-4 (625 + 2,500 + 10,000)
    expect(snap.spent.toNumber()).toBe 49775
    expect(snap.cost.toNumber()).toBe 2507811
    expect(snap.cap.toNumber()).toBe 48500
    expect(snap.halving).toBeCloseTo 50000, 3
    expect(snap.ascensions).toBe 0
    expect(snap.nexus).toBe 4
    expect(snap.expansion).toBe 65
    expect(snap.premutagen.toNumber()).toBe 0
    expect(snap.unlocks.length).toBe 10
    expect(_.find(snap.unlocks, name: 'mutatenexus').unit).toBe 'mutantnexus'
    expect(_.every snap.unlocks, (u) -> not u.unlocked and u.price.equals(1) and u.factor.equals(15625)).toBe true
    # the achievement data: expansion levels are per run (reset at an ascension), endless and ascensions are not
    # (the tutorial's last step is an expansion level too: 5)
    expect((g.val.toNumber() for g in snap.goals.expansion)).toEqual [1, 5, 20, 50, 100, 200, 500, 1000, 2000, 5000]
    expect(_.every snap.goals.expansion, 'perRun').toBe true
    expect((g.val.toNumber() for g in snap.goals.endless)).toEqual [1, 1e31, 1e62]
    expect(_.some snap.goals.endless, 'perRun').toBe false
    expect((g.val.toNumber() for g in snap.goals.ascension)).toEqual [1, 3, 5, 10, 20]
    expect(_.map(_.filter(snap.goals.expansion, 'earned'), 'name')).toEqual ['expansion1', 'tutorial', 'expansion2', 'expansion3']
    r = asc.advise snap, ON
    expect(r.stage).toBe 'firstRun'
    expect(texts r).toEqual ['ascension 1 of 20 costs 2.51e6 energy (cap 48,500): every 50,000 energy spent halves it, mostly House of Mirrors from nexus 5']

  it 'follows the run through nexus 5, mirror casts and an ascension, all through the game', ->
    game = loadGame()
    give game, 'meat', 1e25
    give game, 'larva', 4e9
    give game, 'energy', 48500
    game.upgrade('nexus5').buy 1
    snap = asc.snapshot game
    # B2.2: + nexus 5 => spent 85,775, cost 1,522,486; cap 58,500
    expect(snap.cost.toNumber()).toBe 1522486
    expect(snap.cap.toNumber()).toBe 58500
    r = asc.advise snap, ON
    expect(r.plan.type).toBe 'spendForAscension'
    # 50,000 x log2(1,522,486 / 58,500) = 235,092.x
    expect(r.plan.toSpend.toNumber()).toBe 235093
    # the energy line casts mirrors, but only as many as bring the cost to the save point
    give game, 'energy', 58500
    meat = advisor.advise advisor.snapshot(game), null, {moths: 0}
    expect(meat.energy.type).toBe 'cast'
    expect(meat.energy.casts.toNumber()).toBe 23
    expect(asc.coupleEnergy(meat.energy, asc.advise asc.snapshot(game), ON)).toBe meat.energy
    for i in [0...100]
      give game, 'energy', 2500
      game.upgrade('clonearmy').buy 1
    give game, 'energy', 10000
    snap = asc.snapshot game
    # B2.2: + 100 mirrors => cost 47,578, under the cap: save
    expect(snap.cost.toNumber()).toBe 47578
    r = asc.advise snap, ON
    expect(r.plan.type).toBe 'saveForAscension'
    expect(r.plan.need.toNumber()).toBe 37578
    expect(r.plan.seconds).toBeCloseTo 37578 / snap.rate.toNumber(), 3
    meat = advisor.advise advisor.snapshot(game), null, {moths: 0}
    expect(meat.energy.type).toBe 'cast' # the energy advice alone would cast 4
    held = asc.coupleEnergy meat.energy, r
    expect(held.type).toBe 'ascensionHold'
    give game, 'energy', 47578
    give game, 'premutagen', 123456
    r = asc.advise asc.snapshot(game), ON
    expect(texts r).toEqual ['ascend now: 47,578/47,578 energy; brings 123,456 mutagen, ascension 1 of 20']

    game.ascend()
    snap = asc.snapshot game
    expect(snap.ascensions).toBe 1
    expect(snap.mutagen.toNumber()).toBe 123456
    expect(snap.cost.toNumber()).toBe 5.6e6
    r = asc.advise snap, ON
    expect(r.stage).toBe 'longRun'
    # 123,456 - 1 => 123,455 lepidoptera mutations after the free one; nothing left for 15,625
    expect(texts(r)[0]).toBe 'unlock mutate lepidoptera (1), then buy 123,455 lepidoptera mutations (1/1.00e6); keep the rest (0) unspent: it makes larvae'

    game.upgrade('mutatenexus').buy 1
    snap = asc.snapshot game
    expect(_.find(snap.unlocks, name: 'mutatenexus').unlocked).toBe true
    expect(snap.nexusMutants.toNumber()).toBe 1
    expect(_.find(snap.unlocks, name: 'mutatefreq').price.toNumber()).toBe 15625
    r = asc.advise snap, ON
    expect(_.map r.mutagen.steps, 'type').toEqual ['mutants']

  it 'measures the halving energy with the lepidoptera mutation', ->
    game = loadGame()
    give game, 'mutantnexus', 1e6
    # 50,000 x (1 + 0.6 x (1 - 1 / (1 + 0.0005 x 1e6))) = 79,940.12
    expect(asc.snapshot(game).halving).toBeCloseTo 79940.12, 1
