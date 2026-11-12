'use strict'

# Game facts the climbing advisor's energy advice depends on (advisor/HANDOFF.md, "Energy";
# advisor/MODEL-CHECK.md). If one of these changes, the advisor's energy line needs another look.
describe 'Game facts the advisor relies on', ->

  beforeEach module 'swarmApp'

  Game = {}
  beforeEach inject (_Game_) ->
    Game = _Game_
  mkgame = (unittypes, upgrades={}, achievements={}) ->
    reified = new Date 0
    game = new Game {state:{unittypes: unittypes, upgrades: upgrades, achievements: achievements, date:{reified:reified,started:reified,restarted:reified}}, save:->}
    game.now = new Date 0
    return game

  TERRITORY = ['swarmling', 'stinger', 'spider', 'mosquito', 'locust', 'roach', 'giantspider', 'centipede', 'wasp', 'devourer', 'goon']
  army = (extra={}) ->
    units = _.extend {nexus: 5, energy: 1e6, larva: 1e6, invisiblehatchery: 1}, extra
    for name, i in TERRITORY
      units[name] = 1000 + i
    return units

  it 'House of Mirrors doubles every territory unit, uncapped, ignoring spell power', ->
    for bats in [0, 1000]
      game = mkgame army {bat: bats}
      expect(game.unit('energy').stat('power', 1).toNumber()).toBe (if bats then 1.3 else 1)
      game.upgrade('clonearmy').buy 1
      for name, i in TERRITORY
        expect(game.unit(name).count().toNumber()).toBe 2 * (1000 + i)
      # a second cast doubles again: no cap
      game.upgrade('clonearmy').buy 1
      expect(game.unit('goon').count().toNumber()).toBe 4 * 1010

  it 'scales larva rush with spell power, unlike House of Mirrors', ->
    gains = for bats in [0, 1000]
      game = mkgame army {bat: bats}
      before = game.unit('larva').count()
      rate = game.unit('larva').velocity()
      game.upgrade('larvarush').buy 1
      game.unit('larva').count().minus(before).dividedBy(rate.times(2400).plus(100000)).toNumber()
    expect(gains[0]).toBeCloseTo 1, 9
    expect(gains[1]).toBeCloseTo 1.3, 9

  it 'raises energy production by 1 + N / (1000 + N) for N lepidoptera', ->
    for moths in [0, 1000, 4000]
      game = mkgame {nexus: 4, moth: moths}
      expect(game.unit('energy').velocity().toNumber()).toBeCloseTo 0.4 * (1 + moths / (1000 + moths)), 12

  it 'multiplies larva production by (1 + 0.001 x achievement points) ^ accomplished ancestry', ->
    achievements = {tutorial: 1, drone1: 1} # 50 + 10 points
    base = mkgame({invisiblehatchery: 1}, {}, achievements).unit('larva').velocity().toNumber()
    game = mkgame {invisiblehatchery: 1}, {achievementbonus: 2}, achievements
    expect(game.achievementPoints()).toBe 60
    expect(game.unit('larva').velocity().toNumber()).toBeCloseTo base * 1.06 * 1.06, 9
