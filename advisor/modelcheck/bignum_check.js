// Late-game numbers beyond a double's range, measured with the real game code: rates, prices and an hour of
// idle production from the 20.1 h save edited to hold up to 1e600 of things, high twin/faster/expansion
// levels and units up to endless. bignum_check.py lays these beside advisor/sim/sim.py (bignum numbers).
//
// Usage: node bignum_check.js
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
var EDIT = require('./bignum_state.json');
function load() {
  var g = G.loadSave(SAVE, function (j) {
    for (var k in EDIT.units) j.unittypes[k] = EDIT.units[k];
    for (var k2 in EDIT.upgrades) j.upgrades[k2] = EDIT.upgrades[k2];
  }).game;
  var tick = g.tick;
  g.tick = function (now, skip) { return tick.call(this, now || this.now, skip); };
  return g;
}
var g = load(), out = {rates: {}, prices: {}, units: {}, idle: {}};
out.rates = {larva: S(g.unit('larva').velocity()), meat: S(g.unit('meat').velocity()), territory: S(g.unit('territory').velocity()),
  energy: S(g.unit('energy').velocity()), points: g.achievementPoints()};
CHAIN.forEach(function (n, i) {
  var u = g.unit(n);
  out.units[n] = {prodEach: S(u.eachProduction()[i ? CHAIN[i - 1] : 'meat']), twin: S(u.twinMult())};
  var p = g.upgrade(n + 'prod'), t = g.upgrade(n + 'twin');
  out.prices[n + 'prod'] = S(p.totalCost()[0].val);
  if (t.totalCost().length) out.prices[n + 'twin'] = S(t.totalCost()[0].val);
});
TERR.forEach(function (n) { out.units[n] = {prodEach: S(g.unit(n).eachProduction().territory), twin: S(g.unit(n).twinMult())}; });
['hatchery', 'expansion'].forEach(function (n) { out.prices[n] = S(g.upgrade(n).totalCost()[0].val); });
out.prices.goontwin = S(g.upgrade('goontwin').totalCost()[0].val);
G.advance(g, 3600);
['meat', 'larva', 'territory'].concat(CHAIN).forEach(function (n) { out.idle[n] = S(g.unit(n).count()); });
// a purchase at this scale: 1e200 hives (twinned), and the expansion upgrade (premutagen at level 1501)
var h = load();
var before = {hive: h.unit('hive').count(), gq: h.unit('greaterqueen').count(), pm: h.unit('premutagen').count()};
h.unit('hive').buy(new Decimal('1e200'));
h.upgrade('expansion').buy(1);
out.buy = {hiveGained: S(h.unit('hive').count().minus(before.hive)), gqSpent: S(before.gq.minus(h.unit('greaterqueen').count())),
  premutagenGained: S(h.unit('premutagen').count().minus(before.pm))};
// territory empower: production, meat cost and the next empower's price for every unit; then empower goons once
out.empower = {};
var e = load();
TERR.forEach(function (n) {
  var u = e.unit(n), meat = null;
  u.eachCost().forEach(function (c) { if (c.unit.name === 'meat') meat = S(c.val); });
  out.empower[n] = {level: S(e.upgrade(n + 'empower').count()), prodEach: S(u.eachProduction().territory), meatCost: meat,
    price: S(e.upgrade(n + 'empower').totalCost()[0].val)};
});
e.unit('meat')._setCount(new Decimal('1e700'));
var g0 = e.unit('goon').count();
e.upgrade('goonempower').buy(1);
out.empowerBuy = {goonBefore: S(g0), goonAfter: S(e.unit('goon').count()), level: S(e.upgrade('goonempower').count()),
  prodEach: S(e.unit('goon').eachProduction().territory)};
process.stdout.write(JSON.stringify(out) + '\n');
