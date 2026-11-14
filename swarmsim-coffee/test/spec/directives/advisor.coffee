'use strict'

# Hand-built advice in the shape `advisor.update()` returns (tiers lowest first).
fakeAdvice = (over={}) ->
  D = (x) -> new Decimal x
  tier = (name, below, kind, reason, extra={}) ->
    _.extend {name: name, below: below, count: D(1000), H: D(600), kind: kind, reason: reason, buys: D(0), twin: D(1)}, extra
  _.extend {
    age: 3600
    horizon: 10800
    larvae: D(1234)
    larvaRate: D(5)
    tiers: [
      tier 'queen', 'drone', 'wait', 'needBelow'
      tier 'nest', 'queen', 'buy', 'buy', {buys: D(12), twin: D(2)}
      tier 'greaterqueen', 'nest', 'wait', 'tooSlow', {waitSeconds: 3600}
    ]
    tips: [
      {type: 'faster', unit: 'queen', cost: D(66)}
      {type: 'twin', unit: 'nest', payIn: 'greaterqueen', cost: D(10)}
    ]
    energy: {type: 'cast', spell: 'clonearmy', label: 'House of Mirrors', cost: 2500, casts: D(3)}
  }, over

# Hand-built territory advice in the shape `advisorTerritory.update()` returns.
fakeTerritory = (over={}) ->
  D = (x) -> new Decimal x
  hatch = [
    {type: 'hatch', unit: 'wasp', label: 'wasps', role: 'main', buys: D(315778), twin: D(16)}
    {type: 'hatch', unit: 'devourer', label: 'devourers', role: 'spare', buys: D(18210), twin: D(32)}
  ]
  _.extend {records: hatch.slice(), hatch: hatch, twin: null, status: null, setting: null}, over

text = (el) -> (el?.textContent ? '').replace(/\s+/g, ' ').trim()

describe 'Directive: advisorPanel', ->
  beforeEach module 'swarmApp', 'mockFlashStorage'

  scope = advisor = advisorTerritory = options = game = $compile = $rootScope = bignum = null
  beforeEach inject (_$compile_, _$rootScope_, _advisor_, _advisorTerritory_, _options_, _game_, $filter) ->
    bignum = $filter 'bignum'
    advisorTerritory = _advisorTerritory_
    $compile = _$compile_
    $rootScope = _$rootScope_
    advisor = _advisor_
    options = _options_
    game = _game_
    scope = $rootScope.$new()

  render = ->
    el = $compile('<advisor-panel></advisor-panel>') scope
    $rootScope.$digest()
    return el[0]

  it 'renders the tiers highest first, the tips and the energy line', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    spyOn(game.unit('nest'), 'isVisible').and.returnValue true
    el = render()
    rows = el.querySelectorAll 'tbody tr'
    expect(rows.length).toBe 3
    expect(text rows[0].querySelector 'td').toBe 'greater queen'
    expect(text rows[0]).toContain 'wait 60 min'
    expect(text rows[1].querySelector 'td').toBe 'nest'
    expect(text rows[2]).toContain 'need more drones'
    # the buy row is emphasised, with the game's labels and twins
    expect(rows[1].className).toContain 'success'
    expect(text rows[1].querySelector 'strong').toBe 'buy 12 (×2 twins)'
    expect(el.querySelectorAll('tbody strong').length).toBe 1
    # unit names link to the unit's page when it is visible
    expect(rows[1].querySelector('a').getAttribute 'href').toBe '#/tab/meat/unit/nest'
    header = text el.querySelector '.advisor-header'
    expect(header).toContain 'Run 60 min'
    expect(header).toContain 'climb if H < 3.0 h'
    # the game's own number format, whatever it looks like in this browser
    expect(header).toContain bignum(new Decimal 1234) + ' larvae (+5/sec)'
    tips = (text t for t in el.querySelectorAll '.advisor-tip')
    expect(tips).toEqual ['buy faster queens (66 queens)', 'buy twin nests (10 greater queens)']
    expect(text el.querySelector '.advisor-energy').toBe 'Energy: cast House of Mirrors ×3'

  it 'names one unit in the singular', ->
    advice = fakeAdvice()
    advice.tips = [{type: 'twin', unit: 'hive', payIn: 'hivequeen', cost: new Decimal 1}]
    spyOn(advisor, 'update').and.returnValue advice
    el = render()
    expect(text el.querySelector '.advisor-tip').toBe 'buy twin hives (1 hive queen)'

  it 'forgets purchase history when another save is imported', ->
    advisor.update()
    expect(advisor.memory()).not.toBe null
    $rootScope.$broadcast 'import', {source: 'options', success: true}
    expect(advisor.memory()).toBe null

  it 'renders the live advice for a new game', ->
    el = render()
    expect(el.querySelector '.advisor-error').toBe null
    expect((text(r.querySelector 'td') for r in el.querySelectorAll 'tbody tr')).toEqual ['nest', 'queen']

  it 'refreshes from the game tick at most once a second', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    render()
    for i in [0...5]
      $rootScope.$emit 'tick'
      $rootScope.$digest()
    expect(advisor.update.calls.count()).toBe 1

  it 'is hidden, and does no work, while the advisor is off', ->
    options.advisorEnabled false
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    el = render()
    $rootScope.$emit 'tick'
    $rootScope.$digest()
    expect(el.querySelector '.advisor-panel').toBe null
    expect(advisor.update).not.toHaveBeenCalled()

  it 'shows an error from the rules instead of breaking the page', ->
    spyOn(advisor, 'update').and.throwError 'no hive data'
    el = render()
    expect(text el.querySelector '.advisor-error').toBe 'Advisor error: no hive data'
    expect(el.querySelector 'table').toBe null
    advisor.invalidate()
    expect(-> $rootScope.$emit 'tick').not.toThrow()

  it 'shows an energy failure on the energy line only', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice {energy: null, energyError: new Error 'no nexus data'}
    el = render()
    expect(el.querySelectorAll('tbody tr').length).toBe 3
    expect(el.querySelectorAll('.advisor-tip').length).toBe 2
    line = el.querySelector '.advisor-energy'
    expect(text line).toBe 'Energy: no nexus data'
    expect(line.className).toContain 'text-danger'

  it 'renders the territory advice from its records, with game labels and links', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    spyOn(advisorTerritory, 'update').and.returnValue fakeTerritory()
    spyOn(game.unit('wasp'), 'isVisible').and.returnValue true
    el = render()
    lines = el.querySelectorAll '.advisor-territory'
    # main and spare are one plan: one line, both wanted, either order
    expect(lines.length).toBe 1
    expect(text lines[0]).toBe 'Territory: hatch ' + bignum(new Decimal 315778) + ' wasps (×16 twins) and ' + bignum(new Decimal 18210) + ' devourers (×32 twins), in any order'
    expect(lines[0].querySelector('a').getAttribute 'href').toBe '#/tab/territory/unit/wasp'
    expect(lines[0].querySelectorAll('.advisor-plan-part').length).toBe 2
    expect(lines[0].querySelector 'strong').not.toBe null

  it 'says nothing about order for a plan of one unit', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    t = fakeTerritory()
    t.hatch = t.records = t.hatch.slice 0, 1
    spyOn(advisorTerritory, 'update').and.returnValue t
    el = render()
    expect(text el.querySelector '.advisor-territory').toBe 'Territory: hatch ' + bignum(new Decimal 315778) + ' wasps (×16 twins)'

  it 'renders the other territory records', ->
    D = (x) -> new Decimal x
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    records = [
      {type: 'setShare', share: 0.1, to: 0}
      {type: 'mirrors', casts: 2}
      {type: 'upgrade', name: 'expansion', label: 'expansion', levels: 2, from: 50, costs: [{unit: 'territory', val: D(1e9)}]}
      {type: 'twin', unit: 'spider', unitLabel: 'arachnomorphs', name: 'spidertwin', label: 'twin arachnomorphs', larvae: D(2500), meat: D(1)}
      {type: 'saveForTwin', unit: 'spider', name: 'spidertwin', label: 'twin arachnomorphs', larvae: D(2500), meat: D(1e6), have: D(2000)}
      {type: 'idle', reason: 'noMeat', unit: 'swarmling', label: 'swarmling', cost: D(750), meat: D(10)}
      {type: 'idle', reason: 'locked'}
    ]
    spyOn(advisorTerritory, 'update').and.returnValue fakeTerritory {records: records, hatch: []}
    el = render()
    lines = (text l for l in el.querySelectorAll '.advisor-territory')
    expect(lines).toEqual [
      'Territory: set the territory share to 0 in Options (now 0.1)'
      'House of Mirrors is running: hatch no more territory units'
      'buy expansion ×2 (' + bignum(D 1e9) + ' territory)'
      'buy twin arachnomorphs (' + bignum(D 2500) + ' larvae, 1 meat)'
      'save larvae for twin arachnomorphs: ' + bignum(D 2000) + '/' + bignum(D 2500) + ' larvae'
      'need 750 meat per swarmling (can spend 10)'
      'no territory units yet'
    ]
    expect(el.querySelector('.advisor-territory a').getAttribute 'href').toBe '#/options'

  it 'names empowered units as the game does, and renders empower advice', ->
    D = (x) -> new Decimal x
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    game.upgrade('swarmlingempower')._setCount 1
    game.unit('swarmling').stats() # the game sets the "II" suffix while working out the stats
    records = [
      {type: 'empower', unit: 'stinger', name: 'stingerempower', label: 'empower stingers', level: 0, meat: D(5.17144e34), wipes: D(12345), becomes: 'stingers II', above: 'swarmlings II'}
      {type: 'hatch', unit: 'swarmling', label: 'swarmlings II', role: 'main', buys: D(10), twin: D(1)}
    ]
    spyOn(advisorTerritory, 'update').and.returnValue fakeTerritory {records: records, hatch: [records[1]]}
    el = render()
    lines = (text l for l in el.querySelectorAll '.advisor-territory')
    expect(lines).toEqual [
      'Territory: buy empower stingers (' + bignum(D 5.17144e34) + ' meat): they become stingers II, the next unit above swarmlings II; your ' + bignum(D 12345) + ' stingers are lost'
      'hatch 10 swarmlings II'
    ]

  it 'keeps the meat advice when the territory advice fails, and the other way round', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    spyOn(advisorTerritory, 'update').and.throwError 'no territory data'
    el = render()
    expect(el.querySelectorAll('tbody tr').length).toBe 3
    expect(text el.querySelector '.advisor-territory').toBe 'Territory: no territory data'
    advisor.update.and.throwError 'no hive data'
    advisorTerritory.update.and.returnValue fakeTerritory()
    advisor.invalidate()
    advisorTerritory.invalidate()
    $rootScope.$emit 'tick'
    $rootScope.$digest()
    expect(text el.querySelector '.advisor-error').toBe 'Advisor error: no hive data'
    expect(el.querySelectorAll('.advisor-territory').length).toBe 1

  it 'marks the unit of the page it is on, separately from the buy emphasis', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    spyOn(advisorTerritory, 'update').and.returnValue fakeTerritory()
    el = $compile('<advisor-panel current-unit="nest"></advisor-panel>') scope
    $rootScope.$digest()
    el = el[0]
    marked = el.querySelectorAll 'tr.advisor-current'
    expect(marked.length).toBe 1
    expect(text marked[0].querySelector 'td').toBe '(this page) nest'
    expect(marked[0].querySelector '.advisor-here').not.toBe null
    # a row can be both the current unit and a buy
    expect(marked[0].className).toContain 'success'
    expect(el.querySelectorAll('.advisor-territory.advisor-current').length).toBe 0

  it 'marks a territory line for the unit of the page', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    spyOn(advisorTerritory, 'update').and.returnValue fakeTerritory()
    scope.unitName = 'devourer'
    el = $compile('<advisor-panel current-unit="{{unitName}}"></advisor-panel>') scope
    $rootScope.$digest()
    el = el[0]
    marked = el.querySelectorAll '.advisor-territory.advisor-current'
    expect(marked.length).toBe 1
    # within the plan line, only the page's unit carries the marker
    parts = el.querySelectorAll '.advisor-plan-part'
    expect(parts[0].querySelector '.advisor-here').toBe null
    expect(parts[1].querySelector '.advisor-here').not.toBe null
    expect(text parts[1]).toContain '(this page)'
    expect(text parts[1]).toContain 'devourers'
    expect(el.querySelectorAll('tr.advisor-current').length).toBe 0
    # follows the page's unit
    scope.unitName = 'queen'
    $rootScope.$digest()
    expect(text el.querySelector 'tr.advisor-current td').toBe '(this page) queen'

  it 'marks nothing on the list pages', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    spyOn(advisorTerritory, 'update').and.returnValue fakeTerritory()
    el = render()
    expect(el.querySelectorAll('.advisor-current').length).toBe 0
    expect(el.querySelectorAll('.advisor-here').length).toBe 0

  it 'says when the territory larvae are refilling', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    status = {type: 'idle', reason: 'refilling', since: 10, rate: 5, seconds: 30}
    spyOn(advisorTerritory, 'update').and.returnValue fakeTerritory {records: [status], hatch: [], status: status}
    el = render()
    expect(text el.querySelector '.advisor-territory').toBe 'Territory: territory larvae spent for now, more in 30 s'

  it 'links territory upgrades shown on the larva page there', ->
    D = (x) -> new Decimal x
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    spyOn(game.unit('larva'), 'isVisible').and.returnValue true
    rec = {type: 'upgrade', name: 'hatchery', label: 'hatchery', levels: 1, from: 1, costs: [{unit: 'meat', val: D(3000)}]}
    spyOn(advisorTerritory, 'update').and.returnValue fakeTerritory {records: [rec], hatch: []}
    el = render()
    expect(el.querySelector('.advisor-territory a').getAttribute 'href').toBe '#/tab/larva/unit/larva'

  it 'says what spare energy is being saved for', ->
    D = (x) -> new Decimal x
    hold = {type: 'hold', level: 2, energy: D(2000), price: D(625), ready: true, missing: [{unit: 'meat', have: D(8.95e11), need: D(3.33e15)}], mothsNext: false}
    spyOn(advisor, 'update').and.returnValue fakeAdvice {energy: hold}
    el = render()
    expect(text el.querySelector '.advisor-energy').toBe 'Energy: saving for nexus 2: energy ready (' + bignum(D 2000) + '/625); waiting for ' + bignum(D 3.33e15) + ' meat (have ' + bignum(D 8.95e11) + ')'
    hold = {type: 'hold', level: 4, energy: D(2000), price: D(10000), ready: false, missing: [], mothsNext: true}
    advisor.update.and.returnValue fakeAdvice {energy: hold}
    advisor.invalidate()
    $rootScope.$emit 'tick'
    $rootScope.$digest()
    expect(text el.querySelector '.advisor-energy').toBe 'Energy: saving for nexus 4: ' + bignum(D 2000) + '/' + bignum(D 10000) + ' energy; lepidoptera after that'
    full = {type: 'energyFull', energy: D(10000), cap: D(10000), spell: 'larvarush', label: 'larva rush', cost: 1600}
    advisor.update.and.returnValue fakeAdvice {energy: full}
    advisor.invalidate()
    $rootScope.$emit 'tick'
    $rootScope.$digest()
    expect(text el.querySelector '.advisor-energy').toBe 'Energy: energy is full (' + bignum(D 10000) + '/' + bignum(D 10000) + '): cast larva rush ×1 so the income isn\'t wasted'

  it "says how the 'save' plan spends energy at nexus 4, and the larvae it keeps", ->
    D = (x) -> new Decimal x
    show = (rec, over={}) ->
      advisor.update.and.returnValue fakeAdvice _.extend({energy: rec}, over)
      advisor.invalidate()
      $rootScope.$emit 'tick'
      $rootScope.$digest()
      text el.querySelector '.advisor-energy'
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    el = render()
    # the first 1,000 lepidoptera, then nexus 5 (its larvae kept from the climb)
    save = {type: 'save', level: 5, missing: [{unit: 'energy', have: D(8000), need: D(36000)}]}
    early = {type: 'buyMoths', count: D(800), moths: D(0), target: D(1000), early: true, then: save}
    expect(show early, {nexusLarvae: D(3333333000)}).toBe 'Energy: buy ' + bignum(D 800) + ' lepidoptera (0/' + bignum(D 1000) + ': the first ' + bignum(D 1000) + ', before nexus 5); then save for nexus 5: ' + bignum(D 8000) + '/' + bignum(D 36000) + ' energy (the climb above leaves ' + bignum(D 3333333000) + ' larvae for it)'
    expect(show {type: 'mothTarget', moths: D(0), target: D(1000), early: true, then: null}).toBe 'Energy: all energy into lepidoptera (0/' + bignum(D 1000) + ': the first ' + bignum(D 1000) + ', before nexus 5)'
    # just in time: keep part of the price, lepidoptera with the rest
    keep = {type: 'buyMoths', count: D(200), moths: D(1000), target: D(4000), keep: D(30000), wait: 10000, then: null}
    expect(show keep).toBe 'Energy: buy ' + bignum(D 200) + ' lepidoptera (' + bignum(D 1000) + '/' + bignum(D 4000) + '); keep ' + bignum(D 30000) + ' energy for nexus 5: income brings the rest before its larvae (2.8 h)'
    keep.keep = D 0
    expect(show keep).toBe 'Energy: buy ' + bignum(D 200) + ' lepidoptera (' + bignum(D 1000) + '/' + bignum(D 4000) + '); nothing to keep for nexus 5 yet: income brings it before its larvae (2.8 h)'
    hold = {type: 'hold', level: 5, energy: D(1000), price: D(36000), ready: false, missing: [{unit: 'larva', have: D(1333333000), need: D(3333333000)}], mothsNext: false, keep: D(16001), wait: 33333.33}
    expect(show hold).toBe 'Energy: saving for nexus 5: ' + bignum(D 1000) + '/' + bignum(D 36000) + ' energy; also needs ' + bignum(D 3333333000) + ' larvae (have ' + bignum(D 1333333000) + '); only ' + bignum(D 16001) + ' energy needed now: income brings the rest before its larvae (9.3 h)'
    save.keep = D 25000
    save.wait = 10000
    expect(show save).toBe 'Energy: save for nexus 5: ' + bignum(D 8000) + '/' + bignum(D 36000) + ' energy; only ' + bignum(D 25000) + ' energy needed now: income brings the rest before the larvae (2.8 h)'
    # the route's target for the run
    run = {type: 'buyMoths', count: D(600), moths: D(4000), target: D(30000), runStage: 'quickRun', setting: 4000, then: null}
    expect(show run).toBe 'Energy: buy ' + bignum(D 600) + ' lepidoptera (' + bignum(D 4000) + '/' + bignum(D 30000) + ': quick-run target, your setting is ' + bignum(D 4000) + ')'
    # nothing kept: no note
    expect(show run, {nexusLarvae: D(0)}).toBe 'Energy: buy ' + bignum(D 600) + ' lepidoptera (' + bignum(D 4000) + '/' + bignum(D 30000) + ': quick-run target, your setting is ' + bignum(D 4000) + ')'

  it 'collapses to a one-line summary and remembers that with the save', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    el = render()
    angular.element(el.querySelector '.panel-title a').triggerHandler 'click'
    $rootScope.$digest()
    expect(options.advisorCollapsed()).toBe true
    expect(el.querySelector 'table').toBe null
    expect(text el.querySelector '.advisor-summary').toBe '— nest: buy 12 (×2 twins)'
    angular.element(el.querySelector '.panel-title a').triggerHandler 'click'
    $rootScope.$digest()
    expect(options.advisorCollapsed()).toBe false
    expect(el.querySelectorAll('tbody tr').length).toBe 3

  describe 'long-run climb mode', ->
    D = (x) -> new Decimal x
    # hand-built advice with the mode's fields, in the shape `advisor.update()` returns
    lrAdvice = (over={}) ->
      advice = fakeAdvice over
      push = {type: 'push', unit: 'greaterqueen', below: 'nest', buys: D(50), twin: D(2), units: D(100), share: 0.5, limitedBy: 'share', belowCount: D(1e4)}
      advice.tiers[2] = _.extend advice.tiers[2], {kind: 'push', reason: 'push', buys: D(50), twin: D(2), push: push}
      advice.longRun = {active: true, startsIn: 0, mothsRaised: false, frontier: 'nest', pushes: [push], suppressed: [], above: ['hive', 'hivequeen', 'overmind6']}
      return advice

    it 'shows push rows and the empty tiers above on one row', ->
      spyOn(advisor, 'update').and.returnValue lrAdvice()
      el = render()
      rows = el.querySelectorAll 'tbody tr'
      expect(rows.length).toBe 4
      expect(text rows[0]).toBe 'hive to endless: nothing to feed until you own the tier below'
      expect(rows[1].className).toContain 'info'
      expect(text rows[1].querySelector 'strong').toBe 'feed upward: hatch 50 (×2 twins) (half your nests)'
      expect(text rows[2].querySelector 'strong').toBe 'buy 12 (×2 twins)'
      expect(text el.querySelector '.advisor-header').toContain '· long-run climb: 1% of larvae kept for feeding upward'
      # the summary when collapsed counts a push as something to do
      options.advisorCollapsed true
      $rootScope.$digest()
      expect(text el.querySelector '.advisor-summary').toBe '— greater queen: feed upward: hatch 50 (×2 twins) (half your nests)'

    it 'says when the mode starts, while the run is younger than 2 days', ->
      advice = fakeAdvice()
      advice.longRun = {active: false, startsIn: 3600 * 27.6, mothsRaised: false, frontier: null, pushes: [], suppressed: [], above: []}
      spyOn(advisor, 'update').and.returnValue advice
      el = render()
      expect(text el.querySelector '.advisor-longrun').toBe '· long-run climb from run age 2 d (in 27.6 h)'
      expect(el.querySelectorAll('.advisor-above').length).toBe 0

    it 'shows nothing of it with the mode off', ->
      spyOn(advisor, 'update').and.returnValue fakeAdvice()
      el = render()
      expect(el.querySelector '.advisor-longrun').toBe null
      expect(el.querySelector '.advisor-above').toBe null

    it 'says where the lepidoptera target comes from when the mode raised it', ->
      moths = {type: 'buyMoths', count: D(10000), moths: D(4000), target: 30000, then: null, longRun: true, setting: 4000}
      spyOn(advisor, 'update').and.returnValue fakeAdvice {energy: moths}
      el = render()
      expect(text el.querySelector '.advisor-energy').toBe 'Energy: buy ' + bignum(D 10000) + ' lepidoptera (' + bignum(D 4000) + '/' + bignum(D 30000) + ': long-run target, your setting is ' + bignum(D 4000) + ')'

    it 'hints at the mode on the ascension long-run line while it is off', inject (advisorAscension) ->
      spyOn(advisor, 'update').and.returnValue fakeAdvice()
      long = {type: 'longRun', expansion: 0, nextExpansion: {val: D(100)}, lastExpansion: {val: D(5000)}, top: null, endlessBought: D(0), nextEndless: {val: D(1)}, ascensions: 1, of: 20, climbMode: false}
      spyOn(advisorAscension, 'update').and.returnValue {stage: 'longRun', records: [long], plan: null, hold: null, mutagen: null}
      el = render()
      hint = el.querySelector '.advisor-hint a'
      expect(text hint).toBe 'turn on long-run climb in Options'
      expect(hint.getAttribute 'href').toBe '#/options'
      long.climbMode = true
      advisorAscension.invalidate()
      $rootScope.$emit 'tick'
      $rootScope.$digest()
      expect(el.querySelector '.advisor-hint').toBe null

  describe 'ascension advice', ->
    D = (x) -> new Decimal x
    advisorAscension = null
    beforeEach inject (_advisorAscension_) ->
      advisorAscension = _advisorAscension_
    # Hand-built advice in the shape `advisorAscension.update()` returns.
    saving = ->
      plan = {type: 'saveForAscension', stage: 'firstRun', cost: D(52791), energy: D(20000), cap: D(58500), halving: 50000, saveAt: D(58500), need: D(32791), seconds: 36728, ascension: 1, of: 20}
      {stage: 'firstRun', records: [plan], plan: plan, hold: plan, mutagen: null}
    tick = ->
      advisor.invalidate()
      advisorAscension.invalidate()
      $rootScope.$emit 'tick'
      $rootScope.$digest()

    it 'adds nothing, and leaves the energy line as it was, while the setting is off', ->
      # on by default (the achievements route): turn it off
      expect(options.advisorSetting 'ascension', 'off').toBe 'off'
      spyOn(advisor, 'update').and.returnValue fakeAdvice()
      el = render()
      expect(el.querySelectorAll('.advisor-ascension').length).toBe 0
      expect(text el.querySelector '.advisor-energy').toBe 'Energy: cast House of Mirrors ×3'

    it 'turns the cast into the save while saving for the ascension', ->
      spyOn(advisor, 'update').and.returnValue fakeAdvice()
      spyOn(advisorAscension, 'update').and.returnValue saving()
      spyOn(game.unit('mutagen'), 'isVisible').and.returnValue true
      el = render()
      lines = el.querySelectorAll '.advisor-ascension'
      expect(lines.length).toBe 1
      expect(text lines[0]).toBe 'Ascension: stop casting and save for ascension 1 of 20: ' + bignum(D 20000) + '/' + bignum(D 52791) + ' energy, ready in 10.2 h'
      expect(lines[0].querySelector('a').getAttribute 'href').toBe '#/tab/mutagen/unit/mutagen'
      expect(lines[0].querySelector 'strong').not.toBe null
      energy = el.querySelector '.advisor-energy'
      expect(text energy).toBe 'Energy: saving for the ascension, no casting: ' + bignum(D 20000) + '/' + bignum(D 52791) + ' energy, ready in 10.2 h'
      # the rest of the panel is as before
      expect(el.querySelectorAll('tbody tr').length).toBe 3
      expect(el.querySelectorAll('.advisor-tip').length).toBe 2
      # once the save is done the energy line goes back to casting
      advisorAscension.update.and.returnValue {stage: 'longRun', records: [], plan: null, hold: null, mutagen: null}
      tick()
      expect(text el.querySelector '.advisor-energy').toBe 'Energy: cast House of Mirrors ×3'

    it 'cuts lepidoptera short before saving starts, as casts', ->
      rec = {type: 'buyMoths', count: D(5000), moths: D(4000), target: D(10000), runStage: 'firstRun', setting: 4000, then: null}
      spyOn(advisor, 'update').and.returnValue fakeAdvice {energy: rec}
      plan = {type: 'spendForAscension', stage: 'firstRun', cost: D(80000), energy: D(50000), cap: D(58500), halving: 50000, saveAt: D(58500), toSpend: D(22579), nexus: 5, ascension: 1, of: 20}
      spyOn(advisorAscension, 'update').and.returnValue {stage: 'firstRun', records: [plan], plan: plan, hold: null, mutagen: null, moths: {moths: 10000, stage: 'firstRun'}}
      el = render()
      # ceil(22,579 / 10) = 2,258
      expect(text el.querySelector '.advisor-energy').toBe 'Energy: buy ' + bignum(D 2258) + ' lepidoptera (' + bignum(D 4000) + '/' + bignum(D 10000) + ': first-run target, your setting is ' + bignum(D 4000) + '), then save for the ascension'

    it 'cuts a cast short before saving starts', ->
      spyOn(advisor, 'update').and.returnValue fakeAdvice {energy: {type: 'cast', spell: 'clonearmy', label: 'House of Mirrors', cost: 2500, casts: D(20)}}
      plan = {type: 'spendForAscension', stage: 'firstRun', cost: D(80000), energy: D(50000), cap: D(58500), halving: 50000, saveAt: D(58500), toSpend: D(22579), nexus: 5, ascension: 1, of: 20}
      spyOn(advisorAscension, 'update').and.returnValue {stage: 'firstRun', records: [plan], plan: plan, hold: null, mutagen: null}
      el = render()
      expect(text el.querySelector '.advisor-energy').toBe 'Energy: cast House of Mirrors ×10, then save for the ascension'
      expect(text el.querySelector '.advisor-ascension').toBe 'Ascension: ascension 1 of 20 costs ' + bignum(D 80000) + ' energy (cap ' + bignum(D 58500) + '); every ' + bignum(D 50000) + ' energy spent halves it (lepidoptera and House of Mirrors); spend ' + bignum(D 22579) + ' more, then save from ' + bignum(D 58500)

    it 'lists the mutagen to spend, each linked, and the stage, on two lines', ->
      spyOn(advisor, 'update').and.returnValue fakeAdvice {energy: null}
      for name in ['mutagen', 'mutantnexus']
        spyOn(game.unit(name), 'isVisible').and.returnValue true
      mut = {type: 'mutagen', mutagen: D(6e7), keep: D(58984375), steps: [
        {type: 'unlock', name: 'mutatenexus', label: 'mutate lepidoptera', unit: 'mutantnexus', price: D(1)}
        {type: 'mutants', unit: 'mutantnexus', count: D(999999), have: D(1), target: D(1e6), price: D(999999)}
        {type: 'unlocks', count: 1, price: D(15625), remaining: 9, all: false, any: true}
      ]}
      long = {type: 'longRun', expansion: 0, nextExpansion: {val: D(100)}, lastExpansion: {val: D(5000)}, top: 'drone', endlessBought: D(0), nextEndless: {val: D(1)}, ascensions: 1, of: 20}
      spyOn(advisorAscension, 'update').and.returnValue {stage: 'longRun', records: [mut, long], plan: null, hold: null, mutagen: mut}
      el = render()
      lines = el.querySelectorAll '.advisor-ascension'
      expect(lines.length).toBe 2
      expect(text lines[0]).toBe 'Ascension: unlock mutate lepidoptera (1 mutagen), then buy ' + bignum(D 999999) + ' lepidoptera mutations (1/' + bignum(D 1e6) + '), then unlock 1 more mutation, any (' + bignum(D 15625) + ' mutagen); keep the rest (' + bignum(D 58984375) + ') unspent: it makes larvae'
      links = (a.getAttribute('href') for a in lines[0].querySelectorAll 'a')
      expect(links).toEqual ['#/tab/mutagen/unit/mutagen', '#' + game.unit('mutantnexus').url(), '#/tab/mutagen/unit/mutagen']
      expect(text lines[1]).toBe 'long run, do not ascend yet: expansions 0/100 (last ' + bignum(D 5000) + '); endless bought 0/1 (top tier: drone)'
      expect(el.querySelector '.advisor-energy').toBe null

    it 'shows an ascension failure on its own line, and the energy line as without it', ->
      spyOn(advisor, 'update').and.returnValue fakeAdvice()
      spyOn(advisorAscension, 'update').and.throwError 'no mutagen data'
      el = render()
      line = el.querySelector '.advisor-ascension'
      expect(text line).toBe 'Ascension: no mutagen data'
      expect(line.className).toContain 'text-danger'
      expect(text el.querySelector '.advisor-energy').toBe 'Energy: cast House of Mirrors ×3'
      expect(el.querySelectorAll('tbody tr').length).toBe 3
      # and back when it works again
      advisorAscension.update.and.returnValue saving()
      tick()
      expect(el.querySelector('.advisor-ascension').className).not.toContain 'text-danger'
      expect(text el.querySelector '.advisor-energy').toContain 'saving for the ascension'

    it 'shows the live first-run line on a new game once the setting is on', ->
      options.advisorSetting 'ascension', 'achievements'
      el = render()
      expect(text el.querySelector '.advisor-ascension').toContain 'Ascension: ascension 1 of 20 costs'

describe 'Directive: advisorSuggest', ->
  beforeEach module 'swarmApp', 'mockFlashStorage'

  scope = advisor = advisorTerritory = advisorView = options = game = parseNumber = $compile = $rootScope = bignum = null
  beforeEach inject (_$compile_, _$rootScope_, _advisor_, _advisorTerritory_, _advisorView_, _options_, _game_, _parseNumber_, $filter) ->
    advisorTerritory = _advisorTerritory_
    bignum = $filter 'bignum'
    $compile = _$compile_
    $rootScope = _$rootScope_
    advisor = _advisor_
    advisorView = _advisorView_
    options = _options_
    game = _game_
    parseNumber = _parseNumber_
    scope = $rootScope.$new()
    scope.form = {buyCount: ''}

  render = (unitName) ->
    scope.unit = game.unit unitName
    el = $compile('<advisor-suggest unit="unit" form="form"></advisor-suggest>') scope
    $rootScope.$digest()
    return el[0]
  withBuys = (buys) ->
    advice = fakeAdvice()
    advice.tiers[1].buys = new Decimal buys
    return advice

  it 'fills the buy box with the suggested amount, and only that', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    el = render 'nest'
    button = el.querySelector 'button'
    expect(button.disabled).toBe false
    expect(button.getAttribute 'type').toBe 'button' # never submits the buy form
    expect(text button).toBe 'Use suggested: 12 nests'
    expect(scope.form.buyCount).toBe ''
    angular.element(button).triggerHandler 'click'
    expect(scope.form.buyCount).toBe '12'
    expect(parseNumber(scope.form.buyCount, scope.unit).equals 12).toBe true

  it 'fills the box for a push', ->
    advice = fakeAdvice()
    push = {type: 'push', unit: 'greaterqueen', below: 'nest', buys: new Decimal(50), twin: new Decimal(2), share: 0.5, limitedBy: 'share'}
    advice.tiers[2] = _.extend advice.tiers[2], {kind: 'push', reason: 'push', buys: new Decimal(50), twin: new Decimal(2), push: push}
    spyOn(advisor, 'update').and.returnValue advice
    el = render 'greaterqueen'
    button = el.querySelector 'button'
    # the count before twins, as for any purchase
    expect(text button).toBe 'Use suggested: 50 greater queens'
    angular.element(button).triggerHandler 'click'
    expect(scope.form.buyCount).toBe '50'
    el = render 'nest'
    angular.element(el.querySelector 'button').triggerHandler 'click'
    expect(scope.form.buyCount).toBe '12'

  it 'writes counts above 1e21 and 1e308 so they parse back exactly', ->
    for count in ['123456789012345678901234567', '9.87654321098765432109e+308', '1.2345678901234567890123e+400']
      advisor.invalidate()
      advisor.update = jasmine.createSpy('update').and.returnValue withBuys count
      el = render 'nest'
      angular.element(el.querySelector 'button').triggerHandler 'click'
      parsed = parseNumber scope.form.buyCount, scope.unit
      expect(parsed.equals new Decimal count).toBe true
      expect(parsed.toString()).toBe new Decimal(count).toString()

  it 'formats every size of count so parseNumber returns it exactly', ->
    unit = game.unit 'nest'
    for count in ['1', '999', '1000001', '9007199254740993', '999999999999999999999', '1e21', '123456789012345678901234567', '1e308', '1.7976931348623157e+309', '1.2345678901234567890123e+400']
      str = advisorView.buyCountString new Decimal count
      expect(str).not.toMatch /,/
      parsed = parseNumber str, unit
      expect(parsed?.equals new Decimal count).toBe true
    expect(advisorView.buyCountString new Decimal '999999999999999999999').toBe '999999999999999999999'
    expect(advisorView.buyCountString new Decimal '123456789012345678901234567').toBe '1.23456789012345678901234567e+26'

  it 'shows a disabled button and the reason when the advice for this unit is not to buy', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    el = render 'greaterqueen'
    button = el.querySelector 'button'
    expect(button.disabled).toBe true
    expect(text button).toBe 'Use suggested'
    expect(text el.querySelector 'small').toBe 'Advisor: wait 60 min'
    scope.form.buyCount = '7'
    angular.element(button).triggerHandler 'click'
    expect(scope.form.buyCount).toBe '7'

  it 'shows nothing for units the advisor does not list', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    expect(render('hive').querySelector 'button').toBe null
    advisor.update.calls.reset()
    expect(render('larva').querySelector 'button').toBe null
    expect(advisor.update).not.toHaveBeenCalled()

  it 'shows nothing while the advisor is off', ->
    options.advisorEnabled false
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    expect(render('nest').querySelector 'button').toBe null
    expect(advisor.update).not.toHaveBeenCalled()

  it 'writes the count from advice taken at the click, not the one on screen', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    el = render 'nest'
    expect(text el.querySelector 'button').toBe 'Use suggested: 12 nests'
    # a second later the advice has moved on, before the next refresh
    advisor.update.and.returnValue withBuys 40
    advisor.current(1000, Date.now() - 5000) # the cached advice is older than a quarter second
    angular.element(el.querySelector 'button').triggerHandler 'click'
    expect(scope.form.buyCount).toBe '40'
    $rootScope.$digest()
    expect(text el.querySelector 'button').toBe 'Use suggested: 40 nests'
    # and writes nothing if the advice no longer says buy
    scope.form.buyCount = ''
    advisor.update.and.returnValue fakeAdvice {tiers: [fakeAdvice().tiers[0]]}
    advisor.current(1000, Date.now() - 5000)
    angular.element(el.querySelector 'button').triggerHandler 'click'
    expect(scope.form.buyCount).toBe ''

  it 'brings the amount up to date when the pointer reaches the button', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    el = render 'nest'
    advisor.update.and.returnValue withBuys 40
    button = el.querySelector 'button'
    angular.element(button).triggerHandler 'mouseenter'
    $rootScope.$digest()
    expect(text button).toBe 'Use suggested: 40 nests'
    # a click right after writes exactly the amount shown, even if the advice has moved on since
    advisor.update.and.returnValue withBuys 41
    angular.element(button).triggerHandler 'click'
    expect(scope.form.buyCount).toBe '40'

  it 'suggests territory units from the territory advice', ->
    spyOn(advisorTerritory, 'update').and.returnValue fakeTerritory()
    el = render 'wasp'
    button = el.querySelector 'button'
    expect(text button).toBe 'Use suggested: ' + bignum(new Decimal 315778) + ' wasps'
    angular.element(button).triggerHandler 'click'
    expect(scope.form.buyCount).toBe '315778'
    expect(parseNumber(scope.form.buyCount, scope.unit).equals 315778).toBe true
    # a territory unit the advice doesn't hatch gets nothing
    expect(render('swarmling').querySelector 'button').toBe null

  it 'gives the reason when no territory units should be hatched', ->
    D = (x) -> new Decimal x
    status = {type: 'mirrors', casts: 1}
    spyOn(advisorTerritory, 'update').and.returnValue fakeTerritory {records: [status], hatch: [], status: status}
    el = render 'wasp'
    expect(el.querySelector('button').disabled).toBe true
    expect(text el.querySelector 'small').toBe 'Advisor: House of Mirrors is running: hatch no more territory units'
    twin = {type: 'saveForTwin', unit: 'wasp', label: 'twin wasps', larvae: D(5000), meat: D(1), have: D(1000)}
    advisorTerritory.update.and.returnValue fakeTerritory {records: [twin], hatch: [], twin: twin}
    advisorTerritory.invalidate()
    $rootScope.$emit 'tick'
    $rootScope.$digest()
    expect(text el.querySelector 'small').toBe 'Advisor: save larvae for twin wasps: ' + bignum(D 1000) + '/' + bignum(D 5000) + ' larvae'

  it 'says "done here" on a plan unit whose line was bought, pointing to the rest of the plan', ->
    spyOn(game.unit('devourer'), 'isVisible').and.returnValue true
    spyOn(advisorTerritory, 'update').and.returnValue fakeTerritory()
    el = render 'wasp'
    expect(el.querySelector('button').disabled).toBe false
    # the player hatches the wasps; the plan now only names devourers
    spyOn(game.unit('wasp'), 'statistics').and.returnValue {num: 315778, twinnum: 315778 * 16}
    rest = fakeTerritory()
    rest.hatch = rest.records = rest.hatch.slice 1
    advisorTerritory.update.and.returnValue rest
    advisorTerritory.invalidate()
    $rootScope.$emit 'tick'
    $rootScope.$digest()
    expect(el.querySelector('button').disabled).toBe true
    expect(text el.querySelector 'small').toBe 'Advisor: done here; next hatch ' + bignum(new Decimal 18210) + ' devourers (×32 twins)'
    expect(el.querySelector('small a').getAttribute 'href').toBe '#/tab/territory/unit/devourer'

  it 'says nothing on a territory unit the plan never named, nor once the plan is used up', ->
    D = (x) -> new Decimal x
    spyOn(advisorTerritory, 'update').and.returnValue fakeTerritory()
    expect(render('swarmling').querySelector 'button').toBe null
    el = render 'wasp'
    # named but not bought, and dropped from the plan (meat moved it up): no "done here"
    t = fakeTerritory()
    t.hatch = t.records = t.hatch.slice 1
    advisorTerritory.update.and.returnValue t
    advisorTerritory.invalidate()
    $rootScope.$emit 'tick'
    $rootScope.$digest()
    expect(el.querySelector 'button').toBe null
    # bought, then the plan runs out: the purse's reason, not "done here"
    spyOn(game.unit('wasp'), 'statistics').and.returnValue {num: 5, twinnum: 80}
    status = {type: 'idle', reason: 'refilling', purse: D(0.2), rate: D(5), seconds: 30}
    advisorTerritory.update.and.returnValue fakeTerritory {records: [status], hatch: [], status: status}
    advisorTerritory.invalidate()
    $rootScope.$emit 'tick'
    $rootScope.$digest()
    expect(text el.querySelector 'small').toBe 'Advisor: territory larvae spent for now, more in 30 s'

  it 'follows the advice as it changes', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    el = render 'nest'
    advisor.update.and.returnValue withBuys 30
    advisor.invalidate()
    $rootScope.$emit 'tick'
    $rootScope.$digest()
    expect(text el.querySelector 'button').toBe 'Use suggested: 30 nests'

  describe 'holding Shift', ->
    # Key events as the browser sends them to the window; `key` is all the directive reads.
    key = (type, name, extra={}) ->
      ev = document.createEvent 'Event'
      ev.initEvent type, true, true
      ev.key = name
      _.extend ev, extra
      window.dispatchEvent ev
      return ev
    down = (name, extra) -> key 'keydown', name, extra
    up = (name, extra) -> key 'keyup', name, extra
    tick = ->
      $rootScope.$emit 'tick'
      $rootScope.$digest()
    stale = -> advisor.current 1000, Date.now() - 5000 # the cached advice is older than a quarter second
    attached = []
    afterEach ->
      # every directive rendered here goes, and its window listeners with it
      scope.$destroy()
      for node in attached
        node.parentNode?.removeChild node
      attached = []
      up 'Shift'

    it 'fills the box with the suggestion from fresh advice, and puts back what it held on release', ->
      spyOn(advisor, 'update').and.returnValue fakeAdvice()
      el = render 'nest'
      expect(text el.querySelector '.advisor-shift-hint').toBe 'or hold Shift'
      advisor.update.and.returnValue withBuys 40
      stale()
      down 'Shift'
      expect(scope.form.buyCount).toBe '40'
      # the same string the button writes
      expect(scope.form.buyCount).toBe advisorView.suggestion(advisor.current(1000), 'nest').buyCount
      up 'Shift'
      expect(scope.form.buyCount).toBe ''
      scope.form.buyCount = '=500'
      down 'Shift'
      expect(scope.form.buyCount).toBe '40'
      up 'Shift'
      expect(scope.form.buyCount).toBe '=500'

    it 'follows the suggestion while held, and goes back to the old value while there is none', ->
      spyOn(advisor, 'update').and.returnValue fakeAdvice()
      render 'nest'
      scope.form.buyCount = '3'
      down 'Shift'
      down 'Shift', {repeat: true} # a held key repeats its keydown
      expect(scope.form.buyCount).toBe '12'
      advisor.update.and.returnValue withBuys 30
      advisor.invalidate()
      tick()
      expect(scope.form.buyCount).toBe '30'
      # no longer suggested (cooling down after a purchase): never a stale number
      advisor.update.and.returnValue fakeAdvice {tiers: [fakeAdvice().tiers[0]]}
      advisor.invalidate()
      tick()
      expect(scope.form.buyCount).toBe '3'
      advisor.update.and.returnValue withBuys 31
      advisor.invalidate()
      tick()
      expect(scope.form.buyCount).toBe '31'
      up 'Shift'
      expect(scope.form.buyCount).toBe '3'

    it 'takes the advice after a purchase at once, so a second Shift-click cannot repeat it', ->
      spyOn(advisor, 'update').and.returnValue fakeAdvice()
      render 'nest'
      down 'Shift'
      expect(scope.form.buyCount).toBe '12'
      # the purchase puts nests on cooldown; no tick has run since
      advisor.update.and.returnValue fakeAdvice {tiers: [fakeAdvice().tiers[0], _.extend(fakeAdvice().tiers[1], {kind: 'wait', reason: 'cooldown', buys: new Decimal(0), waitSeconds: 60})]}
      $rootScope.$emit 'command', {name: 'buyUnit'}
      expect(scope.form.buyCount).toBe ''
      up 'Shift'
      expect(scope.form.buyCount).toBe ''

    it 'does nothing without a suggestion for this unit', ->
      spyOn(advisor, 'update').and.returnValue fakeAdvice()
      render 'greaterqueen'
      scope.form.buyCount = '7'
      down 'Shift'
      expect(scope.form.buyCount).toBe '7'
      up 'Shift'
      expect(scope.form.buyCount).toBe '7'
      render 'hive'
      down 'Shift'
      expect(scope.form.buyCount).toBe '7'
      up 'Shift'
      expect(scope.form.buyCount).toBe '7'

    it 'fills territory units from the territory advice', ->
      spyOn(advisorTerritory, 'update').and.returnValue fakeTerritory()
      render 'wasp'
      down 'Shift'
      expect(scope.form.buyCount).toBe '315778'
      up 'Shift'
      expect(scope.form.buyCount).toBe ''

    it 'never touches what is typed with Shift: another key undoes the fill before it lands', ->
      spyOn(advisor, 'update').and.returnValue fakeAdvice()
      wrap = $compile('<div><input type="text" ng-model="form.buyCount"><advisor-suggest unit="unit" form="form"></advisor-suggest></div>') _.extend scope, {unit: game.unit 'nest'}
      $rootScope.$digest()
      document.body.appendChild wrap[0]
      attached.push wrap[0]
      input = wrap[0].querySelector 'input'
      input.focus()
      scope.form.buyCount = '15'
      $rootScope.$digest()
      input.setSelectionRange 0, 0
      down 'Shift'
      $rootScope.$digest()
      expect(input.value).toBe '12'
      # '@' needs Shift: the box (and the caret) are back before the character goes in
      down '@'
      expect(scope.form.buyCount).toBe '15'
      expect(input.value).toBe '15'
      expect(input.selectionStart).toBe 0
      # the player's text, typed while Shift is still held
      input.value = '@15'
      angular.element(input).triggerHandler 'input'
      up '@'
      advisor.update.and.returnValue withBuys 30
      advisor.invalidate()
      tick()
      expect(scope.form.buyCount).toBe '@15'
      # no fill on the next Shift-ed key either, and none on release
      down '%'
      up '%'
      expect(scope.form.buyCount).toBe '@15'
      up 'Shift'
      expect(scope.form.buyCount).toBe '@15'
      # the next press fills again
      down 'Shift'
      expect(scope.form.buyCount).toBe '30'
      up 'Shift'
      expect(scope.form.buyCount).toBe '@15'

    it 'counts Shift pressed after another key or with a modifier as typing', ->
      spyOn(advisor, 'update').and.returnValue fakeAdvice()
      render 'nest'
      down '1'
      down 'Shift'
      expect(scope.form.buyCount).toBe ''
      up '1'
      up 'Shift'
      down 'Shift', {ctrlKey: true}
      expect(scope.form.buyCount).toBe ''
      up 'Shift'
      # Shift then Tab (focus moves back): the fill is undone and stays undone
      down 'Shift'
      expect(scope.form.buyCount).toBe '12'
      down 'Tab'
      expect(scope.form.buyCount).toBe ''
      up 'Tab'
      tick()
      expect(scope.form.buyCount).toBe ''
      up 'Shift'
      expect(scope.form.buyCount).toBe ''

    it 'forgets a key whose keyup was lost once it stops repeating', ->
      spyOn(advisor, 'update').and.returnValue fakeAdvice()
      render 'nest'
      spyOn(Date, 'now').and.returnValue 1000000
      down 'a'
      Date.now.and.returnValue 1000000 + 1500
      down 'Shift'
      expect(scope.form.buyCount).toBe '12'

    it 'keeps a value written another way while held, such as the button', ->
      spyOn(advisor, 'update').and.returnValue fakeAdvice()
      el = render 'nest'
      down 'Shift'
      advisor.update.and.returnValue withBuys 40
      stale()
      angular.element(el.querySelector 'button').triggerHandler 'click'
      expect(scope.form.buyCount).toBe '40'
      up 'Shift'
      expect(scope.form.buyCount).toBe '40'

    it 'puts the box back when the window loses focus', ->
      spyOn(advisor, 'update').and.returnValue fakeAdvice()
      render 'nest'
      scope.form.buyCount = '2'
      down 'Shift'
      expect(scope.form.buyCount).toBe '12'
      blur = document.createEvent 'Event'
      blur.initEvent 'blur', false, false
      window.dispatchEvent blur
      expect(scope.form.buyCount).toBe '2'
      # the Shift keyup went elsewhere; the next press works
      down 'Shift'
      expect(scope.form.buyCount).toBe '12'

    it 'puts the box back when destroyed, and stops listening', ->
      spyOn(advisor, 'update').and.returnValue fakeAdvice()
      render 'nest'
      down 'Shift'
      expect(scope.form.buyCount).toBe '12'
      scope.$destroy()
      expect(scope.form.buyCount).toBe ''
      up 'Shift'
      down 'Shift'
      expect(scope.form.buyCount).toBe ''

    it 'does nothing while the advisor is off, and lets go when it is switched off', ->
      spyOn(advisor, 'update').and.returnValue fakeAdvice()
      render 'nest'
      down 'Shift'
      expect(scope.form.buyCount).toBe '12'
      options.advisorEnabled false
      tick()
      expect(scope.form.buyCount).toBe ''
      up 'Shift'
      advisor.update.calls.reset()
      down 'Shift'
      expect(scope.form.buyCount).toBe ''
      expect(advisor.update).not.toHaveBeenCalled()

describe 'Directive: advisorOptions', ->
  beforeEach module 'swarmApp', 'mockFlashStorage'

  scope = options = $compile = $rootScope = null
  beforeEach inject (_$compile_, _$rootScope_, _options_) ->
    $compile = _$compile_
    $rootScope = _$rootScope_
    options = _options_
    scope = $rootScope.$new()

  render = ->
    el = $compile('<advisor-options></advisor-options>') scope
    $rootScope.$digest()
    return el[0]
  type = (el, key, val) ->
    input = el.querySelector '#advisor-' + key
    angular.element(input).val val
    # settings are saved when the box loses focus, not on every keystroke
    angular.element(input).triggerHandler 'input'
    angular.element(input).triggerHandler 'change'
    angular.element(input).triggerHandler 'blur'
    $rootScope.$digest()
    return input
  group = (input) -> input.parentNode

  it 'lists every setting with its current value', ->
    options.advisorSetting 'ageMultiple', 5
    el = render()
    expect(el.querySelectorAll('input.advisor-setting').length).toBe 6
    expect(el.querySelector('#advisor-ageMultiple').value).toBe '5'
    expect(el.querySelector('#advisor-territory').value).toBe '0.1'
    expect(text el).toContain 'Set to 0 once House of Mirrors is casting'
    expect(text el).toContain '5 suits runs lasting several days'

  it 'saves valid input through the option setter', ->
    spyOn(options, 'advisorSetting').and.callThrough()
    el = render()
    input = type el, 'ageMultiple', '5'
    expect(options.advisorSetting).toHaveBeenCalledWith 'ageMultiple', '5'
    expect(options.advisorConfig().ageMultiple).toBe 5
    expect(group(input).className).not.toContain 'has-error'

  it 'rejects bad input without throwing and keeps the stored value', ->
    el = render()
    input = null
    expect(-> input = type el, 'bank', 'lots').not.toThrow()
    expect(options.advisorConfig().bank).toBe 3
    expect(group(input).className).toContain 'has-error'
    expect(text group input).toContain 'Enter a number from 0 to 1000000. Still using 3.'
    expect(input.value).toBe 'lots'
    type el, 'bank', ''
    expect(options.advisorConfig().bank).toBe 3
    type el, 'bank', '4'
    expect(options.advisorConfig().bank).toBe 4
    expect(group(input).className).not.toContain 'has-error'

  it 'survives a setter that throws', ->
    el = render()
    spyOn(options, 'advisorSetting').and.callFake (key, val) ->
      if val?
        throw new Error 'nope'
      return 0.5
    input = null
    expect(-> input = type el, 'share', '0.3').not.toThrow()
    expect(group(input).className).toContain 'has-error'

  it 'says when a value was clamped', ->
    el = render()
    input = type el, 'share', '5'
    expect(options.advisorConfig().share).toBe 1
    expect(text group input).toContain 'Saved as 1'
    expect(input.value).toBe '1'
    input = type el, 'moths', '2500.7'
    expect(options.advisorConfig().moths).toBe 2500

  it 'does not save while typing, only when the box is left or Enter is pressed', ->
    spyOn(options, 'advisorSetting').and.callThrough()
    el = render()
    input = el.querySelector '#advisor-share'
    angular.element(input).val '0.'
    angular.element(input).triggerHandler 'input'
    angular.element(input).triggerHandler 'change'
    $rootScope.$digest()
    expect(options.advisorSetting).not.toHaveBeenCalledWith 'share', jasmine.anything()
    expect(options.advisorConfig().share).toBe 0.5
    spyOn input, 'blur'
    angular.element(input).triggerHandler {type: 'keydown', keyCode: 13}
    expect(input.blur).toHaveBeenCalled()

  it 'offers the spare-energy choice as two options, the plan by default, saved when picked', ->
    spyOn(options, 'advisorSetting').and.callThrough()
    el = render()
    radios = el.querySelectorAll 'input[name=advisor-spareEnergy]'
    expect(radios.length).toBe 2
    expect(radios[0].value).toBe 'save'
    expect(radios[0].checked).toBe true
    expect(text el).toContain 'Planning holds energy for the next nexus and keeps its larvae out of the climb'
    expect(text el).toContain 'Cast larva rush (as the console script did)'
    radios[1].checked = true
    angular.element(radios[1]).triggerHandler 'click'
    $rootScope.$digest()
    expect(options.advisorSetting).toHaveBeenCalledWith 'spareEnergy', 'larvarush'
    expect(options.advisorConfig().spareEnergy).toBe 'larvarush'
    # reset brings the default back, in the control too
    angular.element(el.querySelector '.advisor-options > .well > button').triggerHandler 'click'
    $rootScope.$digest()
    expect(options.advisorConfig().spareEnergy).toBe 'save'
    expect(el.querySelectorAll('input[name=advisor-spareEnergy]')[0].checked).toBe true

  it 'offers the ascension advice as off or the achievements route, the route by default', inject (advisorAscension) ->
    spyOn(options, 'advisorSetting').and.callThrough()
    spyOn(advisorAscension, 'invalidate').and.callThrough()
    el = render()
    radios = el.querySelectorAll 'input[name=advisor-ascension]'
    expect(radios.length).toBe 2
    expect(radios[1].checked).toBe true
    expect(text el).toContain 'The achievements route is a plan for earning every achievement'
    expect(text el).toContain '10,000 in a first run, 30,000 in a quick run and from day 3 of the long run'
    expect(el.querySelector('.advisor-options').innerHTML).not.toContain 'http'
    radios[0].checked = true
    angular.element(radios[0]).triggerHandler 'click'
    $rootScope.$digest()
    expect(options.advisorSetting).toHaveBeenCalledWith 'ascension', 'off'
    expect(options.advisorConfig().ascension).toBe 'off'
    expect(options.session.state.options.advisor.ascension).toBe 'off'
    expect(advisorAscension.invalidate).toHaveBeenCalled()
    angular.element(el.querySelector '.advisor-options > .well > button').triggerHandler 'click'
    $rootScope.$digest()
    expect(options.advisorConfig().ascension).toBe 'achievements'
    expect(el.querySelectorAll('input[name=advisor-ascension]')[1].checked).toBe true

  it 'offers the long-run climb as off or on, off by default', ->
    spyOn(options, 'advisorSetting').and.callThrough()
    el = render()
    radios = el.querySelectorAll 'input[name=advisor-longRun]'
    expect(radios.length).toBe 2
    expect(radios[0].checked).toBe true
    expect(text el).toContain 'It does nothing before a run is 2 days old'
    expect(text el).toContain 'It trades meat income for progress up the chain'
    expect(text el).toContain 'keeping 1% of the larvae for that'
    radios[1].checked = true
    angular.element(radios[1]).triggerHandler 'click'
    $rootScope.$digest()
    expect(options.advisorSetting).toHaveBeenCalledWith 'longRun', 'on'
    expect(options.session.state.options.advisor.longRun).toBe 'on'

  it 'turns the advisor on and off', ->
    el = render()
    box = el.querySelector 'input[type=checkbox]'
    expect(box.checked).toBe true
    box.checked = false
    angular.element(box).triggerHandler 'click'
    $rootScope.$digest()
    expect(options.advisorEnabled()).toBe false
    expect(el.querySelector 'input.advisor-setting').toBe null

  it 'resets the settings to their defaults', ->
    options.advisorConfig {ageMultiple: 5, moths: 10}
    el = render()
    angular.element(el.querySelector '.advisor-options button').triggerHandler 'click'
    $rootScope.$digest()
    expect(options.advisorConfig()).toEqual {ageMultiple: 3, share: 0.5, cooldown: 60, bank: 3, territory: 0.1, moths: 4000, spareEnergy: 'save', ascension: 'achievements', longRun: 'off'}
    expect(el.querySelector('#advisor-moths').value).toBe '4000'
