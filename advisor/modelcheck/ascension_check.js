// Measures ascension and mutagen mechanics by running the real game code (lib/game.js) and prints one JSON
// object. ascension_compare.py runs this, computes the same numbers with advisor/sim/sim.py and prints
// the tables in advisor/ASCENSION.md.
//
// Usage: TZ=UTC node ascension_check.js <replay spec .json written by ascension_compare.py>
//
// The game seeds its premutagen rolls with Date.prototype.toString() of the save's start date, which is
// local time: run with TZ=UTC (ascension_compare.py does) unless you mean to test another zone.
'use strict';
var fs = require('fs'), path = require('path');
var G = require('./lib/game');
var SAVES = {s14: path.join(__dirname, '..', 'sim', 'example_save_14h.json'),
  s20: path.join(__dirname, '..', 'sim', 'example_save_20h.json')};
var SPEC = process.argv[2] ? JSON.parse(fs.readFileSync(process.argv[2], 'utf8')) : {replays: []};
var S = function (d) { return d === undefined || d === null ? null : String(d); };
var CHAIN = ['drone', 'queen', 'nest', 'greaterqueen', 'hive', 'hivequeen', 'empress', 'prophet', 'goddess',
  'pantheon', 'pantheon2', 'pantheon3'];
var TERR = ['swarmling', 'stinger', 'spider', 'mosquito', 'locust', 'roach', 'giantspider', 'centipede', 'wasp',
  'devourer', 'goon'];
var MUTANTS = ['mutanthatchery', 'mutantbat', 'mutantclone', 'mutantswarmwarp', 'mutantrush', 'mutanteach',
  'mutantfreq', 'mutantnexus', 'mutantarmy', 'mutantmeat'];

// lib/game.js keeps game time where the save left it, but Game._init (run again by ascend()) ticks to the
// real clock. Pin it to game time so an ascension does not add hours of production.
function pin(g) {
  var tick = g.tick;
  g.tick = function (now, skip) { return tick.call(this, now || this.now, skip); };
  return g;
}
function load(which, edit) { return pin(G.loadSave(SAVES[which], edit).game); }
function nonzero(g) {
  var u = {}, up = {};
  g.unitlist().forEach(function (x) { if (!x.count().isZero()) u[x.name] = S(x.count()); });
  g.upgradelist().forEach(function (x) { if (!x.count().isZero()) up[x.name] = S(x.count()); });
  return {units: u, upgrades: up};
}
var out = {tz: process.env.TZ || null, dateString: {}};

// 1. Premutagen roll per level, straight from the effect's output() (what onBuy adds), for both saves.
out.levels = {};
['s14', 's20'].forEach(function (w) {
  var g = load(w);
  out.dateString[w] = {started: String(g.session.state.date.started), restarted: g.session.state.date.restarted.getTime()};
  var r = out.levels[w] = {hatchery: {}, expansion: {}};
  [['hatchery', 38, 140], ['expansion', 78, 460]].forEach(function (a) {
    var up = g.upgrade(a[0]), eff = up.effect[1];
    for (var lv = a[1]; lv <= a[2]; lv++) {
      var o = eff.type.output(eff, g, up, new Decimal(lv));
      r[a[0]][lv] = [o.spawned, S(o.qty), S(o.baseqty)];
    }
  });
});

// 2. The same through real purchases: buy hatcheries 33..60 and expansions 66..120 one at a time on the 20 h
//    save (resources topped up), with no mutants and with mutanteach 1e6 + mutantfreq 1e4.
out.buys = {};
[['plain', {}], ['mutants', {mutanteach: '1000000', mutantfreq: '10000'}]].forEach(function (c) {
  var g = load('s20', function (j) { for (var k in c[1]) j.unittypes[k] = c[1][k]; });
  var rec = out.buys[c[0]] = {freq: S(g.unit('invisiblehatchery').stat('random.freq')),
    each: S(g.unit('invisiblehatchery').stat('random.each', 1)), steps: []};
  [['hatchery', 60], ['expansion', 120]].forEach(function (a) {
    var up = g.upgrade(a[0]);
    while (up.count().lessThan(a[1])) {
      g.unit('meat')._setCount(new Decimal('1e300')); g.unit('territory')._setCount(new Decimal('1e300'));
      var before = g.unit('premutagen').count();
      up.buy(1);
      rec.steps.push([a[0], up.count().toNumber(), S(g.unit('premutagen').count().minus(before))]);
    }
  });
});

// 3. Replays of simulated runs: the simulator's hatchery/expansion levels, bought in this order through
//    upgrade.buy() with the run's restart time and mutants. Premutagen after each purchase.
out.replays = SPEC.replays.map(function (rp) {
  var g = load(rp.save, function (j) {
    if (rp.restarted_ms !== undefined && rp.restarted_ms !== null) j.date.restarted = new Date(rp.restarted_ms).toISOString();
    for (var k in (rp.mutants || {})) j.unittypes[k] = String(rp.mutants[k]);
    j.unittypes.premutagen = '0';
  });
  var res = [];
  rp.buys.forEach(function (b) {
    var up = g.upgrade(b[0]);
    up._setCount(b[1] - 1);
    g.unit('meat')._setCount(new Decimal('1e300')); g.unit('territory')._setCount(new Decimal('1e300'));
    up.buy(1);
    res.push(S(g.unit('premutagen').count()));
  });
  return {name: rp.name, premutagen: res};
});

// 4. Ascension cost: energy spent from each source, ascension count, mutantnexus, respecEnergy.
out.cost = [];
var costCases = [
  {name: 'save as is', e: {}},
  {name: '4000 lepidoptera', e: {u: {moth: '4000'}}},
  {name: '20000 lepidoptera', e: {u: {moth: '20000'}}},
  {name: 'nexus 5', e: {u: {nexus: '5'}, g: {nexus5: '1'}}},
  {name: 'nexus 5, 100 mirrors', e: {u: {nexus: '5'}, g: {nexus5: '1', clonearmy: '100'}}},
  {name: 'nexus 5, 300 mirrors', e: {u: {nexus: '5'}, g: {nexus5: '1', clonearmy: '300'}}},
  {name: '50 larva rushes, 10 warps, 5 meat rushes, 5 territory rushes, 2 clone larvae', e: {g: {larvarush: '50', swarmwarp: '10', meatrush: '5', territoryrush: '5', clonelarvae: '2'}}},
  {name: '100 bats, 500 nightbugs', e: {u: {nexus: '5', bat: '100', nightbug: '500'}, g: {nexus5: '1'}}},
  {name: '3 ascensions', e: {u: {ascension: '3'}}},
  {name: '3 ascensions, nexus 5, 100 mirrors', e: {u: {ascension: '3', nexus: '5'}, g: {nexus5: '1', clonearmy: '100'}}},
  {name: 'mutantnexus 2000', e: {u: {mutantnexus: '2000'}}},
  {name: 'mutantnexus 1e6, nexus 5, 100 mirrors', e: {u: {mutantnexus: '1000000', nexus: '5'}, g: {nexus5: '1', clonearmy: '100'}}},
  {name: 'respecEnergy 20000', e: {u: {respecEnergy: '20000'}}}
];
costCases.forEach(function (c) {
  var g = load('s20', function (j) {
    for (var k in (c.e.u || {})) j.unittypes[k] = c.e.u[k];
    for (var k2 in (c.e.g || {})) j.upgrades[k2] = c.e.g[k2];
  });
  out.cost.push({name: c.name, edit: c.e, spent: S(g.ascendEnergySpent()), cost: S(g.ascendCost()),
    respecCost: S(g.respecCost()), cap: S(g.unit('energy').capValue())});
});

// 5. Ascending: the 20 h save given enough spent energy (20,000 lepidoptera), its cap's worth of energy,
//    123,456 premutagen and 777 crystals; ascend 1 s later. Everything that is not zero, before and after.
(function () {
  var loaded = G.loadSave(SAVES.s20, function (j) {
    j.unittypes.moth = '40000'; j.unittypes.energy = '48500'; j.unittypes.premutagen = '123456'; j.unittypes.crystal = '777';
    j.unittypes.mutantfreq = '5'; j.upgrades.mutatefreq = '1';
  });
  var g = pin(loaded.game);
  G.advance(g, 1);
  var before = nonzero(g);
  var r = {before: before, costBefore: S(g.ascendCost()), energyBefore: S(g.unit('energy').count()),
    achBefore: g.achievementPoints(), statsBefore: JSON.stringify(g.session.state.statistics.byUnit.hive),
    restartedBefore: g.session.state.date.restarted.getTime(), now: g.now.getTime()};
  g.ascend();
  // the game awards ascension achievements from its command listener (achievement.coffee); do the same
  var L = new (loaded.get('AchievementsListener'))(g, {$on: function () {}});
  L.achieveUnit('ascension', true);
  r.after = nonzero(g);
  r.costAfter = S(g.ascendCost()); r.achAfter = g.achievementPoints();
  r.statsAfter = JSON.stringify(g.session.state.statistics.byUnit.hive);
  r.restartedAfter = g.session.state.date.restarted.getTime();
  r.larvaRate = S(g.unit('larva').velocity()); r.cap = S(g.unit('energy').capValue());
  r.freeRespec = S(g.unit('freeRespec').count());
  G.advance(g, 600);
  r.after600 = {larva: S(g.unit('larva').count()), meat: S(g.unit('meat').count())};
  out.ascend = r;
})();

// 6. Repeated ascensions (free, as the game allows with ascend(true)): count, cost penalty, free respecs.
(function () {
  var g = load('s20');
  var rows = [];
  for (var i = 1; i <= 7; i++) {
    G.advance(g, 1);
    g.ascend(true);
    rows.push({ascensions: S(g.unit('ascension').count()), cost: S(g.ascendCost()), freeRespec: S(g.unit('freeRespec').count())});
  }
  out.repeat = rows;
})();

// 7. Unlocks in sequence, buying mutants, respec (paid and free).
(function () {
  var g = load('s20', function (j) { j.unittypes.mutagen = '1e13'; j.unittypes.ascension = '1'; j.unittypes.moth = '40000'; });
  var seq = [];
  ['mutatenexus', 'mutatefreq', 'mutateeach', 'mutatehatchery', 'mutatemeat', 'mutatearmy'].forEach(function (n) {
    var u = g.upgrade(n), c = u.totalCost()[0].val, m0 = g.unit('mutagen').count();
    var ok = m0.greaterThanOrEqualTo(c);
    if (ok) u.buy(1);
    seq.push({name: n, cost: S(c), bought: ok, mutagenAfter: S(g.unit('mutagen').count()),
      freeUnit: S(g.unit('mutant' + n.slice(6)).count())});
  });
  g.unit('mutantnexus').buy(99999); g.unit('mutantfreq').buy(9999);
  var r = {unlocks: seq, mutagenAfterBuys: S(g.unit('mutagen').count()), respecSpent: S(g.respecSpent()),
    respecCost: S(g.respecCost()), ascendCost: S(g.ascendCost())};
  g.unit('energy')._setCount(new Decimal('1e7'));
  g.respec();
  r.afterPaidRespec = {mutagen: S(g.unit('mutagen').count()), energy: S(g.unit('energy').count()),
    mutantnexus: S(g.unit('mutantnexus').count()), mutatenexus: S(g.upgrade('mutatenexus').count()),
    respecEnergy: S(g.unit('respecEnergy').count()), spent: S(g.ascendEnergySpent()), ascendCost: S(g.ascendCost())};
  g.upgrade('mutatemeat').buy(1);
  g.respecFree();
  r.afterFreeRespec = {mutagen: S(g.unit('mutagen').count()), freeRespec: S(g.unit('freeRespec').count())};
  out.unlocks = r;
})();

// 8. Mutant effects on rates. The 20 h save edited to nexus 5 and 1e6 energy, each mutant at several counts.
var BASE = function (j) { j.unittypes.nexus = '5'; j.upgrades.nexus5 = '1'; j.unittypes.energy = '1e6'; };
function rates(g) {
  var r = {larva: S(g.unit('larva').velocity()), meat: S(g.unit('meat').velocity()),
    territory: S(g.unit('territory').velocity()), energy: S(g.unit('energy').velocity()),
    cap: S(g.unit('energy').capValue()), power: S(g.unit('energy').stat('power', 1)),
    freq: S(g.unit('invisiblehatchery').stat('random.freq')), each: S(g.unit('invisiblehatchery').stat('random.each', 1)),
    ascendCost: S(g.ascendCost()), prod: {}, tprod: {}};
  CHAIN.forEach(function (n, i) { r.prod[n] = S(g.unit(n).eachProduction()[i ? CHAIN[i - 1] : 'meat']); });
  TERR.forEach(function (n) { r.tprod[n] = S(g.unit(n).eachProduction().territory); });
  return r;
}
function spells(edit) {
  var r = {};
  [['larvarush', 'larva'], ['meatrush', 'meat'], ['territoryrush', 'territory']].forEach(function (a) {
    var g = load('s20', edit), b = g.unit(a[1]).count();
    g.upgrade(a[0]).buy(1);
    r[a[0]] = S(g.unit(a[1]).count().minus(b));
  });
  var g = load('s20', function (j) { edit(j); j.unittypes.larva = '1e15'; j.unittypes.cocoon = '0'; });
  var b = g.unit('larva').count();
  g.upgrade('clonelarvae').buy(1);
  r.clonelarvae = S(g.unit('larva').count().minus(b));
  var g2 = load('s20', edit), d0 = g2.unit('drone').count();
  g2.upgrade('swarmwarp').buy(1);
  r.swarmwarpDrones = S(g2.unit('drone').count().minus(d0));
  return r;
}
out.mutants = {};
['none'].concat(MUTANTS).forEach(function (m) {
  var counts = m === 'none' ? [0] : [1, 100, 10000, 1e6, 1e9, 1e12];
  out.mutants[m] = {};
  counts.forEach(function (n) {
    var edit = function (j) { BASE(j); if (m !== 'none') j.unittypes[m] = String(n); };
    var g = load('s20', edit);
    var r = rates(g);
    if (m === 'none' || m === 'mutantbat' || m === 'mutantrush' || m === 'mutantclone' || m === 'mutantswarmwarp') r.spells = spells(edit);
    out.mutants[m][n] = r;
  });
});
// mutagen held: 0.1 larva/s each, outside the hatchery multipliers
out.mutagenLarvae = {};
[[0, 0], [1e6, 0], [1e6, 10000], [1e9, 1e6]].forEach(function (c) {
  var g = load('s20', function (j) { BASE(j); j.unittypes.mutagen = String(c[0]); j.unittypes.mutanthatchery = String(c[1]); });
  out.mutagenLarvae[c[0] + '/' + c[1]] = S(g.unit('larva').velocity());
});

// 9. Crystals: a hatchery or expansion bought while energy is visible (nexus >= 1) and the crystal timer has
//    run 30 min grants 500 crystals; energy bought with crystals raises the cap by the same amount.
(function () {
  var g = load('s20', function (j) { j.unittypes.meat = '1e60'; j.unittypes.territory = '1e60'; });
  var c = function () { return S(g.unit('crystal').count()); };
  var r = {start: c()};
  G.advance(g, 1800); g.upgrade('hatchery').buy(1); r.afterHatchery = c();
  G.advance(g, 60); g.upgrade('expansion').buy(1); r.after60s = c();
  G.advance(g, 1800); g.upgrade('expansion').buy(1); r.after1860s = c();
  var e0 = g.unit('energy').count(), cap0 = g.unit('energy').capValue();
  g.unit('energy').buy(500);
  r.energyBuy = {energy: S(g.unit('energy').count().minus(e0)), cap: S(g.unit('energy').capValue().minus(cap0)),
    mtx: S(g.unit('mtxEnergy').count())};
  // after an ascension (nexus 0) hatcheries grant nothing
  var h = load('s20', function (j) { j.unittypes.moth = '40000'; j.unittypes.energy = '48500'; });
  G.advance(h, 1); h.ascend();
  h.unit('meat')._setCount(new Decimal('1e10'));
  G.advance(h, 3600); var c0 = h.unit('crystal').count(); h.upgrade('hatchery').buy(1);
  r.nexus0 = S(h.unit('crystal').count().minus(c0));
  out.crystals = r;
})();

process.stdout.write(JSON.stringify(out) + '\n');
