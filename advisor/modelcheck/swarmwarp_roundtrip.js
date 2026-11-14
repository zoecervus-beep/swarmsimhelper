// Loads exported simulator states (decoded saves) in the real game and prints what the swarmwarp route's rules read:
// energy, its rate and cap, lepidoptera, bats, nightbugs, the ascension cost, energy spent and the halving amount
// (measured from the game's cost function), mutagen, premutagen, every mutant, the unlocks held and the next unlock's
// price, swarmwarp's power and the seconds it skips, expansions, ascensions, House of Mirrors casts this run, the
// achievements the route's stages read, larvae, larvae/s, meat, run age, and each territory unit's empower price.
// Usage: node swarmwarp_roundtrip.js <save.json> [<save.json> ...]    (prints one JSON object keyed by file)
'use strict';
var path = require('path');
var G = require('./lib/game');
var S = function (d) { return d === undefined || d === null ? null : String(d); };
var MUTANTS = ['mutanthatchery', 'mutantbat', 'mutantclone', 'mutantswarmwarp', 'mutantrush', 'mutanteach', 'mutantfreq', 'mutantnexus',
  'mutantarmy', 'mutantmeat'];
var TERR = ['swarmling', 'stinger', 'spider', 'mosquito', 'locust', 'roach', 'giantspider', 'centipede', 'wasp', 'devourer', 'goon'];
var PROBE = 1e5;
var out = {};
process.argv.slice(2).forEach(function (file) {
  var g = G.loadSave(path.resolve(file)).game;
  var energy = g.unit('energy'), mutagen = g.unit('mutagen');
  var c0 = g.ascendCost({spent: 0}), c1 = g.ascendCost({spent: PROBE});
  var unlockUps = mutagen.upgrades.list.filter(function (up) {
    return up.type.maxlevel == 1 && up.effect.some(function (e) { return e.type.name === 'addUnit'; });
  });
  var unlocked = [], nextPrice = null;
  unlockUps.forEach(function (up) {
    if (up.count().greaterThanOrEqualTo(1)) unlocked.push(up.name);
    else if (nextPrice === null) nextPrice = S(up.totalCost()[0].val);
  });
  var warp = g.upgrade('swarmwarp').effect[0];
  var r = {energy: S(energy.count()), energyRate: S(energy.velocity()), cap: S(energy.capValue()), moth: S(g.unit('moth').count()),
    bat: S(g.unit('bat').count()), nightbug: S(g.unit('nightbug').count()), ascendCost: S(g.ascendCost()), spent: S(g.ascendEnergySpent()),
    halving: String(PROBE / (Math.log(c0.dividedBy(c1).toNumber()) / Math.LN2)),
    mutagen: S(mutagen.count()), premutagen: S(g.unit('premutagen').count()), mutants: {}, unlocked: unlocked,
    unlockCount: g.upgrade('mutatehidden').count().toNumber(), nextUnlockPrice: nextPrice,
    warpPower: S(warp.power()), warpSkip: S(warp.output()), expansion: S(g.upgrade('expansion').count()),
    ascension: S(g.unit('ascension').count()), clonearmy: S(g.upgrade('clonearmy').count()),
    swarmwarp: S(g.upgrade('swarmwarp').count()), skippedMillis: g.session.state.skippedMillis,
    larva: S(g.unit('larva').count()), larvaRate: S(g.unit('larva').velocity()), meat: S(g.unit('meat').count()),
    runAge: (g.now.getTime() - g.session.state.date.restarted.getTime()) / 1000, earned: {}, empowerPrice: {}};
  MUTANTS.forEach(function (m) { r.mutants[m] = S(g.unit(m).count()); });
  ['expansion9', 'overmind6_3', 'mutation4'].forEach(function (a) { r.earned[a] = g.achievement(a).isEarned(); });
  TERR.forEach(function (n) { r.empowerPrice[n] = S(g.upgrade(n + 'empower').totalCost()[0].val); });
  out[path.basename(file)] = r;
});
process.stdout.write(JSON.stringify(out) + '\n');
