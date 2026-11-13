// Measures the quantities advisor/sim/sim.py models, by running the real game code on a decoded save.
// Prints one JSON object to stdout. compare.py runs this and lays the numbers beside the simulator's.
//
// Usage: node game_check.js [decoded save .json]   (default: ../sim/example_save_14h.json)
'use strict';
var path = require('path');
var G = require('./lib/game');
var SAVE = path.resolve(process.argv[2] || path.join(__dirname, '..', 'sim', 'example_save_14h.json'));

var CHAIN = ['drone', 'queen', 'nest', 'greaterqueen', 'hive', 'hivequeen', 'empress', 'prophet', 'goddess',
  'pantheon', 'pantheon2', 'pantheon3'];
var TERR = ['swarmling', 'stinger', 'spider', 'mosquito', 'locust', 'roach', 'giantspider', 'centipede', 'wasp',
  'devourer', 'goon'];
var S = function (d) { return d === undefined || d === null ? null : String(d); };

function load(edit) { return G.loadSave(SAVE, edit).game; }
function count(g, n) { return S(g.unit(n).count()); }
function counts(g, names) { var r = {}; names.forEach(function (n) { r[n] = count(g, n); }); return r; }
function upCost(g, name) {
  var u = g.upgrade(name), r = {};
  if (!u) return null;
  u.totalCost().forEach(function (c) { r[c.unit.name] = S(c.val); });
  return {level: S(u.count()), cost: r};
}
var WATCH = ['meat', 'larva', 'cocoon', 'territory', 'energy'].concat(CHAIN, TERR);
function snapshot(g) {
  var r = counts(g, WATCH);
  r._upgrades = {};
  ['hatchery', 'expansion', 'achievementbonus'].concat(
    CHAIN.map(function (n) { return n + 'prod'; }), CHAIN.map(function (n) { return n + 'twin'; }),
    TERR.map(function (n) { return n + 'twin'; })).forEach(function (n) {
    if (g.upgrade(n)) r._upgrades[n] = S(g.upgrade(n).count());
  });
  return r;
}
function rates(g) {
  return {larva: S(g.unit('larva').velocity()), meat: S(g.unit('meat').velocity()),
    territory: S(g.unit('territory').velocity()), energy: S(g.unit('energy').velocity()),
    energyCap: S(g.unit('energy').capValue()), achievementPoints: g.achievementPoints(),
    spellPower: S(g.unit('energy').stat('power', 1))};
}

var out = {save: path.relative(G.REPO, SAVE)};

// 1. Rates, units and upgrade prices at the save.
(function () {
  var g = load();
  out.rates = rates(g);
  out.units = {};
  CHAIN.forEach(function (n, i) {
    var u = g.unit(n), below = i ? CHAIN[i - 1] : 'meat', cost = {};
    u.eachCost().forEach(function (c) { cost[c.unit.name] = S(c.val); });
    out.units[n] = {count: S(u.count()), prodEach: S(u.eachProduction()[below]), cost: cost, twin: S(u.twinMult())};
  });
  TERR.forEach(function (n) {
    var u = g.unit(n), cost = {};
    u.eachCost().forEach(function (c) { cost[c.unit.name] = S(c.val); });
    out.units[n] = {count: S(u.count()), prodEach: S(u.eachProduction().territory), cost: cost, twin: S(u.twinMult())};
  });
  out.upgrades = {};
  ['hatchery', 'expansion', 'achievementbonus', 'nexus2', 'nexus3', 'nexus4', 'nexus5'].concat(
    CHAIN.map(function (n) { return n + 'prod'; }), CHAIN.map(function (n) { return n + 'twin'; }),
    TERR.map(function (n) { return n + 'twin'; })).forEach(function (n) { out.upgrades[n] = upCost(g, n); });
})();

// 2. Dynamics with no purchases: advance a fresh copy of the save by each span.
out.idle = {};
[60, 3600, 8 * 3600, 24 * 3600].forEach(function (secs) {
  var g = load();
  G.advance(g, secs);
  out.idle[secs] = snapshot(g);
});

// 3. Identical purchases. Advance 2 h (so a faster upgrade is affordable), then buy, in order:
//    1000 greater queens (twinned x64), nest twin, greater queen faster, 10 goons, expansion, hatchery,
//    and record the state after each, then 1 h later.
(function () {
  var g = load();
  G.advance(g, 7200);
  var steps = [
    ['unit', 'greaterqueen', 1000], ['upgrade', 'nesttwin', 1], ['upgrade', 'greaterqueenprod', 1],
    ['unit', 'goon', 10], ['upgrade', 'expansion', 1], ['upgrade', 'hatchery', 1]];
  out.purchases = {before: snapshot(g), beforeRates: rates(g), steps: []};
  steps.forEach(function (st) {
    var item = st[0] === 'unit' ? g.unit(st[1]) : g.upgrade(st[1]);
    if (!item.isCostMet() || (st[0] === 'unit' && item.maxCostMet().lessThan(st[2]))) {
      out.purchases.steps.push({kind: st[0], name: st[1], num: st[2], skipped: true}); // not affordable on this save
      return;
    }
    var price = st[0] === 'unit' ? (function () {
      var r = {}; g.unit(st[1]).eachCost().forEach(function (c) { r[c.unit.name] = S(c.val.times(st[2])); }); return r;
    })() : upCost(g, st[1]).cost;
    if (st[0] === 'unit') g.unit(st[1]).buy(st[2]); else g.upgrade(st[1]).buy(st[2]);
    out.purchases.steps.push({kind: st[0], name: st[1], num: st[2], price: price, after: snapshot(g)});
  });
  out.purchases.afterRates = rates(g);
  G.advance(g, 3600);
  out.purchases.later = snapshot(g);
})();

// 4. Spells, each cast once from the save edited to nexus 5 with plenty of energy, with 0 and 1000 bats.
//    Before/after counts of what each spell touches.
out.spells = {};
[0, 1000].forEach(function (bats) {
  var res = out.spells[bats] = {};
  var edit = function (larvae, cocoons) {
    return function (j) {
      j.unittypes.nexus = '5'; j.unittypes.energy = '1e6'; j.unittypes.bat = String(bats);
      j.upgrades.nexus5 = '1';
      if (larvae !== undefined) j.unittypes.larva = String(larvae);
      if (cocoons !== undefined) j.unittypes.cocoon = String(cocoons);
    };
  };
  var cast = function (spell, watch, larvae, cocoons) {
    var g = load(edit(larvae, cocoons));
    var before = counts(g, watch), r = rates(g), energyBefore = S(g.unit('energy').count());
    g.upgrade(spell).buy(1);
    return {before: before, after: counts(g, watch), rates: r, energyBefore: energyBefore,
      energyAfter: S(g.unit('energy').count())};
  };
  res.clonearmy = cast('clonearmy', TERR.concat(['territory']));
  res.larvarush = cast('larvarush', ['larva']);
  res.meatrush = cast('meatrush', ['meat']);
  res.territoryrush = cast('territoryrush', ['territory']);
  res.swarmwarp = cast('swarmwarp', WATCH);
  res.clonelarvae = cast('clonelarvae', ['larva', 'cocoon']);
  res.clonelarvae_cocoons = cast('clonelarvae', ['larva', 'cocoon'], 1e6, 2e6);
  res.clonelarvae_capped = cast('clonelarvae', ['larva', 'cocoon'], 1e12, 0);
  // the same warp as plain elapsed time, for comparison
  var g = load(edit());
  var pw = g.unit('energy').stat('power', 1).toNumber();
  G.advance(g, 900 * pw);
  res.warpAsTime = counts(g, WATCH);
  res.warpAsTimeSecs = 900 * pw;
});

// 5. Energy: lepidoptera, bats, nightbugs.
out.energy = {moth: {}, bat: {}, nightbug: {}};
[0, 1000, 2416, 4000, 1e6].forEach(function (n) {
  out.energy.moth[n] = rates(load(function (j) { j.unittypes.moth = String(n); })).energy;
});
[0, 1000, 1e6].forEach(function (n) {
  out.energy.bat[n] = rates(load(function (j) { j.unittypes.nexus = '5'; j.upgrades.nexus5 = '1'; j.unittypes.bat = String(n); })).spellPower;
});
[0, 1000, 1e6].forEach(function (n) {
  out.energy.nightbug[n] = rates(load(function (j) { j.unittypes.nightbug = String(n); })).energyCap;
});

// 6. Accomplished ancestry: larva rate by level, and with no achievements earned; and larvae actually
//    gained over 60 s (so it is the larva count that grows, not just a displayed rate).
out.ancestry = {byLevel: {}, noAchievements: {}};
[0, 1, 5].forEach(function (lvl) {
  var g = load(function (j) { j.upgrades.achievementbonus = String(lvl); });
  var l0 = g.unit('larva').count();
  G.advance(g, 60);
  out.ancestry.byLevel[lvl] = {rate: rates(g).larva, points: g.achievementPoints(),
    gained60s: S(g.unit('larva').count().minus(l0))};
  var g2 = load(function (j) { j.upgrades.achievementbonus = String(lvl); j.achievements = {}; });
  out.ancestry.noAchievements[lvl] = {rate: rates(g2).larva, points: g2.achievementPoints()};
});

// 6b. Cocoons: turning larvae into cocoons and back, 1:1 both ways, and cocoons' own production.
(function () {
  var g = load(function (j) { j.unittypes.larva = '1000000'; j.unittypes.cocoon = '0'; });
  var cocoon = g.unit('cocoon'), larva = g.unit('larva');
  cocoon.buy(400000);
  var mid = {larva: S(larva.count()), cocoon: S(cocoon.count())};
  larva.buy(100000);
  out.cocoons = {afterCocooning400k: mid, afterUncocooning100k: {larva: S(larva.count()), cocoon: S(cocoon.count())},
    cocoonVelocity: S(cocoon.velocity()), cocoonsCost: S(cocoon.eachCost()[0].val), larvaCost: S(larva.eachCost()[0].val),
    larvaTwin: S(larva.twinMult()), cocoonTwin: S(cocoon.twinMult())};
})();

// 7. Achievements earned during a run, through the game's own AchievementsListener (the check it runs
//    after every purchase command). Unit achievements count units *bought* (statistics twinnum), not owned.
out.achievements = {};
(function () {
  var loaded = G.loadSave(SAVE, function (j) {
    j.upgrades.expansion = '100';                                   // expansion4 (100 expansions, 40 points)
    j.statistics.byUnit.hive.twinnum = '1000000';                   // hive2 (1e6 hives bought, 20 points)
    j.unittypes.swarmling = '1e16';                                 // owned, but not bought: swarmling3 must NOT be earned
  });
  var g = loaded.game;
  var L = new (loaded.get('AchievementsListener'))(g, {$on: function () {}});
  var before = {points: g.achievementPoints(), larva: S(g.unit('larva').velocity())};
  L.achieveUpgrade('expansion');
  L.achieveUnit('hive');
  g.cache.onUpdate();
  out.achievements = {before: before, after: {points: g.achievementPoints(), larva: S(g.unit('larva').velocity())},
    earned: ['expansion4', 'hive2', 'swarmling3'].filter(function (n) { return g.achievement(n).isEarned(); })};
})();

process.stdout.write(JSON.stringify(out, null, 1) + '\n');
