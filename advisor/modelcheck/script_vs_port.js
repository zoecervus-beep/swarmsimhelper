// Regression check: the console script (advisor/swarm-climb-live.js) and its port
// (swarmsim-coffee/app/scripts/services/advisor.coffee) must give the same meat and energy advice.
//
// Both run against the same real Game (lib/game.js) on mutated copies of the owner's example save:
// random unit counts up to overmind VI, faster/twin levels, larvae, meat, nexus, energy,
// lepidoptera, run age and settings. Each state is then stepped forward in game time, sometimes
// "buying" a suggested purchase as the game's statistics record it, so the purchase memory, cooldowns
// and the spare-stock rule are exercised. At every step the tier actions (with exact buy counts), the
// tips and the energy line are compared as text: the script's own strings against the port's render*
// functions.
//
// The script is taken from its file as-is: the part between `var chain` and the panel drawing, with
// Date.now() replaced by the game's clock so both see the same time.
//
// Deterministic for a given seed. Never ascends: the port deliberately starts a fresh purchase memory
// after an ascension, where the script keeps the old run's.
//
// Usage (after `npm install` in this folder):
//   node advisor/modelcheck/script_vs_port.js [seed=1] [states=300] [steps=20]
// Exits 1 on any difference, 0 otherwise.
'use strict';
var fs = require('fs'), path = require('path');
var G = require('./lib/game');

var SAVE = path.join(G.REPO, 'advisor/sim/example_save_14h.json');
var SCRIPT_FILE = path.join(G.REPO, 'advisor/swarm-climb-live.js');
var CHAIN = ['drone', 'queen', 'nest', 'greaterqueen', 'hive', 'hivequeen', 'empress',
  'prophet', 'goddess', 'pantheon', 'pantheon2', 'pantheon3', 'pantheon4', 'pantheon5',
  'overmind', 'overmind2', 'overmind3', 'overmind4', 'overmind5', 'overmind6'];

var seed = +(process.argv[2] || 1), N = +(process.argv[3] || 300), STEPS = +(process.argv[4] || 20);

// --- the script's rules, extracted from its file -------------------------------------------------
var SCRIPT = fs.readFileSync(SCRIPT_FILE, 'utf8');
var from = SCRIPT.indexOf('var chain'), to = SCRIPT.indexOf('var box = document.createElement');
if (from < 0 || to < 0) throw new Error('swarm-climb-live.js changed shape: cannot find its rules');
var body = SCRIPT.slice(from, to).replace(/Date\.now\(\)/g, 'clock()');
var makeScript = new Function('game', 'cfg', 'clock', 'Decimal',
  body + '\nreturn {compute: compute, energyAdvice: energyAdvice};');
function scriptFor(game, cfg) {
  return makeScript(game, Object.assign({}, cfg), function () { return game.now.getTime(); }, Decimal);
}

// --- deterministic random states -----------------------------------------------------------------
var state = seed % 2147483648;
function rnd() { state = (state * 1103515245 + 12345) % 2147483648; return state / 2147483648; }
function ri(a, b) { return a + Math.floor(rnd() * (b - a + 1)); }
function pick(a) { return a[ri(0, a.length - 1)]; }

function mutate(json) {
  var topTier = ri(1, 19);
  var lateExp = pick([30, 100, 300, 1000, 5000]);
  CHAIN.forEach(function (name, i) {
    var c;
    if (i > topTier || rnd() < 0.15) c = '0';
    else c = (1 + rnd() * 9).toFixed(3) + 'e' + Math.max(0, Math.round((topTier - i) * lateExp / Math.max(1, topTier) * rnd() * 1.5));
    json.unittypes[name] = c;
    if (rnd() < 0.7) json.upgrades[name + 'prod'] = String(ri(0, 20)); else delete json.upgrades[name + 'prod'];
    if (rnd() < 0.7) json.upgrades[name + 'twin'] = String(ri(0, 12)); else delete json.upgrades[name + 'twin'];
  });
  json.unittypes.meat = (1 + rnd() * 9).toFixed(3) + 'e' + ri(5, lateExp * 2);
  json.unittypes.larva = (1 + rnd() * 9).toFixed(3) + 'e' + ri(0, Math.min(lateExp, 400));
  json.upgrades.hatchery = String(ri(0, 200));
  json.upgrades.expansion = String(ri(0, 300));
  var nexus = ri(0, 5);
  json.unittypes.nexus = String(nexus);
  for (var k = 1; k <= 5; k++) { if (k <= nexus) json.upgrades['nexus' + k] = '1'; else delete json.upgrades['nexus' + k]; }
  json.unittypes.energy = String(ri(0, 60000));
  json.unittypes.moth = String(pick([0, 100, 3999, 4000, 5000, ri(0, 1e6)]));
  var ageHours = pick([0.01, 1, 14, 100, 1000, 20000]);
  json.date.restarted = new Date(new Date(json.date.reified).getTime() - ageHours * 3600e3).toISOString();
  json.date.started = json.date.restarted;
}

// --- compare ---------------------------------------------------------------------------------------
var differences = 0, bothFailed = 0, compared = 0, seen = {};
for (var n = 0; n < N; n++) {
  var cfg = {ageMultiple: pick([3, 5, 1, 0.5, 10]), share: pick([0.5, 0.25, 1, 0.01]), territory: pick([0.1, 0, 0.5]),
    cooldown: pick([60, 0, 5, 600]), bank: pick([3, 0, 1, 100]), moths: pick([4000, 0, 2000, 1e6]),
    // The console script's energy plan. The default is now 'save' (ASCENSION.md A.11), which the script
    // never had; the other settings at their defaults (ascension, long-run mode) do not reach advise().
    spareEnergy: 'larvarush'};
  var g;
  try { g = G.loadSave(SAVE, mutate); } catch (e) { console.log('state', n, 'does not load:', e.message); differences++; continue; }
  var game = g.game, script = scriptFor(game, cfg), port = g.get('advisor'), memory = null;
  for (var s = 0; s < STEPS; s++) {
    var r1, r2, e1 = null, e2 = null;
    try { r1 = script.compute(); } catch (e) { e1 = e.message; }
    try { r2 = port.advise(port.snapshot(game), memory, cfg); memory = r2.memory; } catch (e) { e2 = e.message; }
    if (e1 || e2) {
      if (e1 !== e2) { differences++; console.log('state', n, 'step', s, 'only one failed:', 'script:', e1, '| port:', e2); } else bothFailed++;
      break;
    }
    var a = r1.tiers.map(function (t) { return t.name + ': ' + t.action + (t.buys ? ' [' + t.buys.toString() + ']' : ''); });
    var b = r2.tiers.map(function (t) { return t.name + ': ' + port.renderAction(t) + (t.kind === 'buy' ? ' [' + t.buys.toString() + ']' : ''); });
    var energyA, energyB;
    try { energyA = script.energyAdvice(r1.larvaRate); } catch (e) { energyA = 'error: ' + e.message; }
    energyB = r2.energyError ? 'error: ' + r2.energyError.message : port.renderEnergy(r2.energy);
    a.push.apply(a, r1.tips.map(function (t) { return 'tip: ' + t; }));
    b.push.apply(b, r2.tips.map(function (t) { return 'tip: ' + port.renderTip(t); }));
    a.push('energy: ' + energyA);
    b.push('energy: ' + energyB);
    compared++;
    if (a.join('\n') !== b.join('\n')) {
      differences++;
      if (differences <= 10) console.log('DIFFERENCE: state', n, 'step', s, JSON.stringify(cfg), '\n--- script\n' + a.join('\n') + '\n--- port\n' + b.join('\n') + '\n');
      break;
    }
    r1.tiers.forEach(function (t) { seen[t.kind + ' ' + t.action.split(' ')[0]] = true; });
    r1.tips.forEach(function (t) { seen['tip ' + t.split(' ')[0]] = true; });
    seen['energy ' + String(energyA).split(' ').slice(0, 2).join(' ').replace(/[\d,.]+/g, '#')] = true;
    // Move time on, and sometimes make a suggested purchase, recorded as the game's statistics would.
    G.advance(game, pick([1, 1, 5, 30, 61, 300]));
    var buys = r1.tiers.filter(function (t) { return t.kind === 'buy'; });
    if (buys.length && rnd() < 0.5) {
      var t = pick(buys);
      var stats = game.session.state.statistics.byUnit;
      stats[t.name] = stats[t.name] || {num: 0};
      stats[t.name].num = new Decimal(stats[t.name].num).plus(t.buys);
      var below = game.unit(t.below);
      below._subtractCount(Decimal.min(below.count(), t.buys.times(t.cost)));
      game.unit(t.name)._addCount(t.buys.times(t.twin));
    }
  }
}
console.log('seed', seed, 'states', N, 'steps', STEPS, '| advice compared', compared, 'times | differences', differences,
  '| states where both failed the same way', bothFailed);
console.log('covered:', Object.keys(seen).sort().join(', '));
process.exit(differences ? 1 : 0);
