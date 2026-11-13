'use strict'

describe 'Service: options', ->

  # load the service's module
  beforeEach module 'swarmApp'

  # instantiate service
  options = {}
  beforeEach inject (_options_) ->
    options = _options_

  it 'should do something', ->
    expect(!!options).toBe true

  it 'sets velocity', ->
    expect(options.VELOCITY_UNITS.list.length).toBeGreaterThan 0
    for vu in options.VELOCITY_UNITS.list
      options.velocityUnit vu.name
      expect(options.velocityUnit().name).toBe vu.name

  it 'special-cases Swarmwarp velocity', ->
      options.velocityUnit 'warp'
      expect(options.velocityUnit().name).toBe 'warp'
      expect(options.velocityUnit().mult+'').toBe '900'
      expect(options.getVelocityUnit(unit:'drone').name).toBe 'warp'
      expect(options.getVelocityUnit(unit:'drone').mult+'').toBe '900'
      # energy is a special case: swarmwarp generates no energy
      expect(options.getVelocityUnit(unit:'energy').name).toBe 'sec'
      expect(options.getVelocityUnit(unit:'energy').mult+'').toBe '1'

  it 'defaults the advisor settings', ->
    expect(options.advisorConfig()).toEqual {ageMultiple: 3, share: 0.5, cooldown: 60, bank: 3, territory: 0.1, moths: 4000, spareEnergy: 'larvarush', ascension: 'off', longRun: 'off'}
    expect(options.advisorEnabled()).toBe true

  it 'sets, clamps and validates advisor settings', ->
    expect(options.advisorSetting 'share', 0.25).toBe 0.25
    expect(options.advisorSetting 'share').toBe 0.25
    expect(options.advisorSetting 'ageMultiple', '5').toBe 5
    expect(options.advisorSetting 'territory', 2).toBe 0.95
    expect(options.advisorSetting 'cooldown', -5).toBe 0
    expect(options.advisorSetting 'moths', 2500.7).toBe 2500
    expect(-> options.advisorSetting 'share', 'lots').toThrow()
    expect(-> options.advisorSetting 'share', '').toThrow()
    expect(-> options.advisorSetting 'bogus', 1).toThrow()
    expect(-> options.advisorSetting 'bogus').toThrow()
    expect(options.advisorSetting 'share').toBe 0.25
    # all or nothing
    expect(-> options.advisorConfig {bank: 4, share: 'x'}).toThrow()
    expect(options.advisorSetting 'bank').toBe 3
    expect(options.advisorConfig({bank: 4, moths: 2000}).bank).toBe 4
    expect(options.advisorConfig()).toEqual {ageMultiple: 5, share: 0.25, cooldown: 0, bank: 4, territory: 0.95, moths: 2000, spareEnergy: 'larvarush', ascension: 'off', longRun: 'off'}
    options.advisorEnabled false
    expect(options.advisorEnabled()).toBe false
    options.advisorEnabled true
    expect(options.advisorEnabled()).toBe true
    options.resetAdvisorConfig()
    expect(options.advisorSetting 'share').toBe 0.5

  it 'reads missing or corrupt stored advisor settings as defaults', ->
    options.session.state.options.advisor = {share: 'garbage', bank: null, cooldown: 1e9, moths: '1000'}
    expect(options.advisorConfig()).toEqual {ageMultiple: 3, share: 0.5, cooldown: 86400, bank: 3, territory: 0.1, moths: 1000, spareEnergy: 'larvarush', ascension: 'off', longRun: 'off'}
    options.session.state.options.advisor = 'not an object'
    expect(options.advisorConfig().share).toBe 0.5
    delete options.session.state.options.advisor
    expect(options.advisorConfig().share).toBe 0.5

  it 'saves advisor settings with the game', ->
    options.advisorConfig {share: 0.3, moths: 2000}
    options.advisorEnabled false
    loaded = options.session._loads options.session._saves()
    expect(loaded.options.advisor).toEqual {share: 0.3, moths: 2000}
    expect(loaded.options.advisorEnabled).toBe false

  it 'remembers whether the advisor panel is collapsed, with the save', ->
    expect(options.advisorCollapsed()).toBe false
    expect(options.advisorCollapsed true).toBe true
    loaded = options.session._loads options.session._saves()
    expect(loaded.options.advisorCollapsed).toBe true
    expect(options.advisorCollapsed false).toBe false

  it 'stores the spare-energy choice, with the default for old saves and after a reset', ->
    # an old save has no such key
    delete options.session.state.options.advisor
    expect(options.advisorSetting 'spareEnergy').toBe 'larvarush'
    expect(options.advisorSetting 'spareEnergy', 'save').toBe 'save'
    expect(options.session.state.options.advisor.spareEnergy).toBe 'save'
    loaded = options.session._loads options.session._saves()
    expect(loaded.options.advisor.spareEnergy).toBe 'save'
    # only the listed choices
    expect(-> options.advisorSetting 'spareEnergy', 'hoard').toThrow()
    expect(-> options.advisorSetting 'spareEnergy', 1).toThrow()
    expect(options.advisorSetting 'spareEnergy').toBe 'save'
    # a corrupt stored value reads as the default
    options.session.state.options.advisor.spareEnergy = 'bogus'
    expect(options.advisorSetting 'spareEnergy').toBe 'larvarush'
    options.advisorSetting 'spareEnergy', 'save'
    options.resetAdvisorConfig()
    expect(options.advisorSetting 'spareEnergy').toBe 'larvarush'

  it 'stores the ascension advice choice, off for old saves, after a reset and when corrupt', ->
    delete options.session.state.options.advisor
    expect(options.advisorSetting 'ascension').toBe 'off'
    expect(options.advisorSetting 'ascension', 'achievements').toBe 'achievements'
    expect(options.session.state.options.advisor).toEqual {ascension: 'achievements'}
    loaded = options.session._loads options.session._saves()
    expect(loaded.options.advisor.ascension).toBe 'achievements'
    expect(-> options.advisorSetting 'ascension', 'on').toThrow()
    expect(-> options.advisorSetting 'ascension', true).toThrow()
    expect(options.advisorSetting 'ascension').toBe 'achievements'
    options.session.state.options.advisor.ascension = 'bogus'
    expect(options.advisorSetting 'ascension').toBe 'off'
    options.advisorSetting 'ascension', 'achievements'
    options.resetAdvisorConfig()
    expect(options.advisorSetting 'ascension').toBe 'off'
