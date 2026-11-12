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

text = (el) -> (el?.textContent ? '').replace(/\s+/g, ' ').trim()

describe 'Directive: advisorPanel', ->
  beforeEach module 'swarmApp'

  scope = advisor = options = game = $compile = $rootScope = null
  beforeEach inject (_$compile_, _$rootScope_, _advisor_, _options_, _game_) ->
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
    expect(header).toContain '1,234 larvae (+5/sec)'
    tips = (text t for t in el.querySelectorAll '.advisor-tip')
    expect(tips).toEqual ['buy faster queens (66 queens)', 'buy twin nests (10 greater queens)']
    expect(text el.querySelector '.advisor-energy').toBe 'Energy: cast House of Mirrors ×3'

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

describe 'Directive: advisorSuggest', ->
  beforeEach module 'swarmApp'

  scope = advisor = advisorView = options = game = parseNumber = $compile = $rootScope = null
  beforeEach inject (_$compile_, _$rootScope_, _advisor_, _advisorView_, _options_, _game_, _parseNumber_) ->
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

  it 'follows the advice as it changes', ->
    spyOn(advisor, 'update').and.returnValue fakeAdvice()
    el = render 'nest'
    advisor.update.and.returnValue withBuys 30
    advisor.invalidate()
    $rootScope.$emit 'tick'
    $rootScope.$digest()
    expect(text el.querySelector 'button').toBe 'Use suggested: 30 nests'

describe 'Directive: advisorOptions', ->
  beforeEach module 'swarmApp'

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
    angular.element(input).triggerHandler 'change'
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
    expect(text el).toContain 'Use 5 for multi-day runs'

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
    type el, 'bank', ''
    expect(options.advisorConfig().bank).toBe 3
    # leaving the box puts the stored value back
    angular.element(input).triggerHandler 'blur'
    $rootScope.$digest()
    expect(input.value).toBe '3'
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
    input = type el, 'moths', '2500.7'
    expect(options.advisorConfig().moths).toBe 2500

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
    expect(options.advisorConfig()).toEqual {ageMultiple: 3, share: 0.5, cooldown: 60, bank: 3, territory: 0.1, moths: 4000}
    expect(el.querySelector('#advisor-moths').value).toBe '4000'
