// The mechanics the no-mirrors route leans on, at the counts it reaches, measured with the real game code
// (advisor/NO-MIRRORS.md, "Checked against the game"): swarmwarp, larva rush, territory rush and clone larvae with
// the bat / warp / rush / clone mutations at 1e200 each, on a state holding up to 1e600 of things; territory
// empower at high levels (goon 60, spider 40); unspent mutagen of 1e350 and the territory mutation at 1e330.
// nomirrors_check.py lays these beside advisor/sim/sim.py.
//
// Usage: node nomirrors_check.js
'use strict';
var path = require('path');
var G = require('./lib/game');
var SAVE = path.join(__dirname, '..', 'sim', 'example_save_20h.json');
var S = function (d) { return d === undefined || d === null ? null : String(d); };
var CHAIN = ['drone', 'queen', 'nest', 'greaterqueen', 'hive', 'hivequeen', 'empress', 'prophet', 'goddess',
  'pantheon', 'pantheon2', 'pantheon3', 'pantheon4', 'pantheon5', 'overmind', 'overmind2', 'overmind3', 'overmind4', 'overmind5',
  'overmind6'];
var TERR = ['swarmling', 'stinger', 'spider', 'mosquito', 'locust', 'roach', 'giantspider', 'centipede', 'wasp',
  'devourer', 'goon'];
var BIG = require('./bignum_state.json');
var EDIT = require('./nomirrors_state.json');
function load(extra) {
  var g = G.loadSave(SAVE, function (j) {
    [BIG, EDIT].forEach(function (E) {
      for (var k in E.units) j.unittypes[k] = E.units[k];
      for (var k2 in E.upgrades) j.upgrades[k2] = E.upgrades[k2];
    });
    if (extra) extra(j);
  }).game;
  var tick = g.tick;
  g.tick = function (now, skip) { return tick.call(this, now || this.now, skip); };
  return g;
}
var ALL = ['meat', 'larva', 'territory', 'energy'].concat(CHAIN).concat(TERR);
function counts(g) { var r = {}; ALL.forEach(function (n) { r[n] = S(g.unit(n).count()); }); return r; }
var out = {};
var g = load();
out.rates = {larva: S(g.unit('larva').velocity()), territory: S(g.unit('territory').velocity()), energy: S(g.unit('energy').velocity())};
out.power = {}; out.output = {};
['swarmwarp', 'larvarush', 'territoryrush', 'clonelarvae', 'meatrush'].forEach(function (n) {
  out.power[n] = S(g.upgrade(n).effect[0].power());
  out.output[n] = g.upgrade(n).effect.map(function (e) { return S(e.output()); });
});
// swarmwarp: every unit before and after one cast
var w = load();
out.warpBefore = counts(w);
w.upgrade('swarmwarp').buy(1);
out.warpAfter = counts(w);
out.warpSkipped = S(w.upgrade('swarmwarp').effect[0].output());
// larva rush, territory rush: gained
['larvarush:larva', 'territoryrush:territory'].forEach(function (a) {
  var x = a.split(':'), h = load(), b = h.unit(x[1]).count();
  h.upgrade(x[0]).buy(1);
  out[x[0]] = S(h.unit(x[1]).count().minus(b));
});
// clone larvae with a bank bigger than its cap
var c = load(function (j) { j.unittypes.larva = '1e900'; j.unittypes.cocoon = '0'; });
var cb = c.unit('larva').count();
c.upgrade('clonelarvae').buy(1);
out.clonelarvae = S(c.unit('larva').count().minus(cb));
// territory empower at high levels
out.empower = {};
TERR.forEach(function (n) {
  var u = g.unit(n), meat = null;
  u.eachCost().forEach(function (cc) { if (cc.unit.name === 'meat') meat = S(cc.val); });
  out.empower[n] = {level: S(g.upgrade(n + 'empower').count()), prodEach: S(u.eachProduction().territory), meatCost: meat,
    price: S(g.upgrade(n + 'empower').totalCost()[0].val)};
});
process.stdout.write(JSON.stringify(out) + '\n');
