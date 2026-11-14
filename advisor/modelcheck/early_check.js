// Check: the advisor's 'save' plan at nexus 4 (energyAdvice, advisor/ASCENSION.md A.11) against the simulator's
// energy decisions on the states in early_cases.json (made by early_cases.py from advisor/sim/early_game.py's PLAN).
// For each state: what the simulator did with energy (nexus 5, lepidoptera and how many, a larva rush, nothing),
// and the energy it kept for nexus 5, against the advisor's record for the same numbers.
// Usage (from the repo root, after `npm install` in this folder): node advisor/modelcheck/early_check.js
// Exits 1 on any difference.
'use strict';
var fs = require('fs'), path = require('path');
var G = require('./lib/game');
var cases = JSON.parse(fs.readFileSync(path.join(__dirname, 'early_cases.json'), 'utf8'));
var g = G.loadSave(path.join(G.REPO, 'advisor/sim/example_save_49min.json'));
var adv = g.get('advisor');
var D = function (x) { return new Decimal(x); };
var tally = {}, diffs = 0;
function count(k, ok) { tally[k] = tally[k] || [0, 0]; tally[k][ok ? 0 : 1]++; if (!ok) diffs++; }
cases.forEach(function (c, i) {
  var costs = [{unit: 'meat', val: D(c.price.meat), have: D(c.meat)}, {unit: 'energy', val: D(c.price.energy), have: D(c.energy)},
    {unit: 'larva', val: D(c.price.larva), have: D(c.larvae)}];
  var snap = {now: 0, restartedAt: 0, larvae: D(c.larvae), larvaRate: D(c.larva_rate), units: [],
    energy: {nexus: 4, energy: D(c.energy), rate: D(c.rate), cap: D(c.cap), moths: D(c.moths), next: {name: 'nexus5', level: 5, costs: costs}}};
  var rec = adv.energyAdvice(snap, {spareEnergy: 'save', moths: c.target});
  var sim = c.sim, what, ok;
  if (sim.nexus5) { what = 'nexus 5 bought'; ok = rec.type === 'buyNexus'; }
  else if (sim.moths) { what = 'lepidoptera bought'; ok = rec.type === 'buyMoths' && rec.count.equals(sim.moths); }
  else if (sim.rush) { what = 'larva rush'; ok = rec.type === 'energyFull'; }
  else { what = 'nothing spent'; ok = ['hold', 'save', 'mothTarget'].indexOf(rec.type) >= 0; }
  count(what, ok);
  // the energy kept for nexus 5 (when the plan is past the early lepidoptera and nexus 5 is not bought)
  if (!sim.nexus5 && c.moths >= c.early && rec.type !== 'buyNexus') {
    var keep = rec.keep !== undefined ? rec.keep.toNumber() : c.price.energy;
    var k = Math.abs(keep - c.sim_keep) <= 1e-9 * c.price.energy;
    count('energy kept for nexus 5', k);
    if (!k) ok = false;
  }
  if (!ok && diffs <= 10) console.log('DIFF case', i, c.run, c.cadence, c.seed, 'age', c.age_h.toFixed(2), 'h:', what, JSON.stringify(sim),
    'sim keep', c.sim_keep, '| advisor', rec.type, rec.count ? rec.count.toString() : '', rec.keep ? 'keep ' + rec.keep.toString() : '', adv.renderEnergy(rec));
});
Object.keys(tally).forEach(function (k) { console.log((k + '                              ').slice(0, 30), 'match', tally[k][0], 'differ', tally[k][1]); });
console.log(cases.length + ' states, ' + diffs + ' differences');
process.exit(diffs ? 1 : 0);
