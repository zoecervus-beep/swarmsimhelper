// Loads exported simulator states (decoded saves) in the real game and prints what the climb rules read:
// each meat tier's count, cost in the tier below and in meat, units per hatch, production per unit, faster and
// twin upgrade prices; larvae, larvae/s, meat, energy, lepidoptera, achievement points, run age.
// Usage: node longrun_roundtrip.js <save.json> [<save.json> ...]    (prints one JSON object keyed by file)
'use strict';
var path = require('path');
var G = require('./lib/game');
var CHAIN = ['drone', 'queen', 'nest', 'greaterqueen', 'hive', 'hivequeen', 'empress', 'prophet', 'goddess',
  'pantheon', 'pantheon2', 'pantheon3', 'pantheon4', 'pantheon5', 'overmind', 'overmind2', 'overmind3', 'overmind4', 'overmind5',
  'overmind6'];
var S = function (d) { return d === undefined || d === null ? null : String(d); };
var out = {};
process.argv.slice(2).forEach(function (file) {
  var g = G.loadSave(path.resolve(file)).game;
  var r = {tiers: {}, larva: S(g.unit('larva').count()), larvaRate: S(g.unit('larva').velocity()), meat: S(g.unit('meat').count()),
    energy: S(g.unit('energy').count()), energyRate: S(g.unit('energy').velocity()), moth: S(g.unit('moth').count()),
    points: g.achievementPoints(), runAge: (g.now.getTime() - g.session.state.date.restarted.getTime()) / 1000,
    territory: S(g.unit('territory').count()), expansion: S(g.upgrade('expansion').count())};
  CHAIN.forEach(function (n, i) {
    var u = g.unit(n), cost = {}, below = i ? CHAIN[i - 1] : 'meat';
    u.eachCost().forEach(function (c) { cost[c.unit.name] = S(c.val); });
    var p = g.upgrade(n + 'prod'), t = g.upgrade(n + 'twin');
    r.tiers[n] = {count: S(u.count()), costBelow: i ? cost[below] : null, costMeat: cost.meat, twin: S(u.twinMult()),
      prodEach: S(u.eachProduction()[below]), prodPrice: S(p.totalCost()[0].val),
      twinPrice: t.totalCost().length ? S(t.totalCost()[0].val) : null,
      bought: S((u.statistics() || {}).twinnum || 0)};
  });
  out[path.basename(file)] = r;
});
process.stdout.write(JSON.stringify(out) + '\n');
