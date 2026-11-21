// Checks rule SEED in the native advisor (advisor.coffee `seedUpward`; ASCENSION.md A.10.9, "Rule SEED (spec for
// the port; replaces LR-0 to LR-3)") against the reference cases in seed_cases/, as seed_cases/README.md says.
// Each case's save is loaded in the real game (lib/game.js); the advisor's own snapshot() is taken; advise() runs with
// rule SEED on and the case's age multiple. Field classes:
//   exact            the frontier (the plain test on the loaded save, the advisor's H); each line's outcome where it
//                    does not depend on larvae: 'nothing below', 'cooldown' (the purchase memory seeded from the
//                    case's since_s on the game clock)
//   exact given A    with the reference's larvae for the climb passed in (`given.larvae`): each line's outcome, n
//                    (floors equal; 1e-12 relative past 2^53) and binding cap, and the larvae left for the climb
//   own A            the port's own A (the territory share and the next nexus's hold, not the simulator's purse):
//                    its lines, printed, and compared where its A equals the reference's
//   printed only     the simulator's climb records (rule-3 sizing; the meat cap differs)
// Usage: node advisor/modelcheck/seed_check.js [case ...]     (VERBOSE=1 for every line). Exit 1 on any difference.
'use strict';
var fs = require('fs'), path = require('path');
var G = require('./lib/game');

var DIR = path.join(__dirname, 'seed_cases');
var D = function (x) { return new Decimal(x); };
var rel = function (a, b) { a = D(a); b = D(b); if (a.equals(b)) return 0; if (b.isZero()) return Infinity; return a.minus(b).abs().dividedBy(b.abs()).toNumber(); };
var sameCount = function (a, b) { a = D(a); b = D(b); return b.abs().lessThan(Math.pow(2, 53)) ? a.equals(b) : rel(a, b) <= 1e-12; };
// the reference's cap names, in the port's words
var BIND = {'share of the tier below': 'below', 'share of the larvae': 'larvae', 'half the meat': 'meat', 'larvae left': 'left'};

var cases = process.argv.slice(2);
if (!cases.length) cases = JSON.parse(fs.readFileSync(path.join(DIR, 'index.json'), 'utf8')).cases;
var totals = {}, order = [];
function tally(field, ok) {
  if (!totals[field]) { totals[field] = {match: 0, differ: 0, info: 0}; order.push(field); }
  totals[field][ok === null ? 'info' : ok ? 'match' : 'differ']++;
}

cases.forEach(function (name) {
  var c = JSON.parse(fs.readFileSync(path.join(DIR, name + '.json'), 'utf8'));
  var L = G.loadSave(path.join(DIR, c.save)), game = L.game, adv = L.get('advisor');
  var ref = c.rule_SEED, out = [];
  var say = function (field, ok, text) {
    tally(field, ok);
    if (ok === false || process.env.VERBOSE) out.push((ok === null ? '  info ' : ok ? '  ok   ' : '  DIFF ') + field + ': ' + text);
  };
  // rule SEED alone: rule FA and the twin planner's detour do not change the seed lines (they act after them)
  var cfg = {ageMultiple: c.config.age_multiple, seed: 'on', ascension: 'off', spareEnergy: 'save', territory: 0.1};
  var snap = adv.snapshot(game);
  // the purchase memory on the game clock: a line in cooldown was hatched since_s ago
  var memory = function () {
    var mem = adv.createMemory(snap.gameNow, snap.restartedAt);
    ref.lines.forEach(function (l) {
      if (l.outcome !== 'cooldown') return;
      var u = snap.units.filter(function (q) { return q.name === l.name; })[0];
      mem.seen[l.name] = u.purchases;
      mem.boughtAt[l.name] = snap.gameNow - l.since_s * 1000;
    });
    return mem;
  };
  var given = adv.advise(snap, memory(), cfg, {larvae: D(ref.larvae_for_climb)});
  var own = adv.advise(snap, memory(), cfg);
  say('horizon (1 ms of run age)', Math.abs(given.horizon - ref.horizon_s) <= 1e-3 * c.config.age_multiple + 1e-12 * ref.horizon_s, 'port ' + given.horizon + ', ref ' + ref.horizon_s);
  say('frontier', given.seed.frontier === ref.frontier, 'port ' + given.seed.frontier + ', ref ' + ref.frontier);

  var byUnit = function (r) { var m = {}; r.seed.lines.forEach(function (l) { m[l.unit] = l; }); return m; };
  var pg = byUnit(given), po = byUnit(own);
  say('lines: the same tiers, top down', JSON.stringify(given.seed.lines.map(function (l) { return l.unit; })) === JSON.stringify(ref.lines.map(function (l) { return l.name; })),
    'port ' + given.seed.lines.map(function (l) { return l.unit; }).join(',') + ' | ref ' + ref.lines.map(function (l) { return l.name; }).join(','));
  ref.lines.forEach(function (l) {
    var p = pg[l.name];
    if (!p) { say('line listed', false, l.name); return; }
    if (l.outcome === 'nothing below' || l.outcome === 'cooldown') {
      say('outcome: ' + l.outcome, p.outcome === l.outcome, l.name + ': port ' + p.outcome);
      return;
    }
    say('outcome given A', p.outcome === l.outcome, l.name + ': port ' + p.outcome + ', ref ' + l.outcome);
    if (l.n !== undefined) {
      say('n given A', p.n !== undefined && sameCount(p.n, l.n), l.name + ': port ' + (p.n ? p.n.toString() : '-') + ', ref ' + l.n);
      say('binding given A', p.binding === BIND[l.binding], l.name + ': port ' + p.binding + ', ref ' + l.binding);
    }
  });
  say('larvae left for the climb given A', sameCount(given.seed.left, ref.larvae_left_for_climb), 'port ' + given.seed.left.toString() + ', ref ' + ref.larvae_left_for_climb);

  // the port's own A
  var sameA = sameCount(own.seed.larvae, ref.larvae_for_climb);
  var hatches = function (r) { return r.seed.lines.filter(function (l) { return l.outcome === 'hatch'; }).map(function (l) { return l.unit + ' ' + l.n.toExponential(4); }).join(', '); };
  if (sameA) say('own A: the same lines', hatches(own) === hatches(given), 'port ' + hatches(own));
  else say('own A (territory share against the purse)', null, 'port A ' + own.seed.larvae.toExponential(4) + ' [' + hatches(own) + '], ref A ' + D(ref.larvae_for_climb).toExponential(4) + ' [' + hatches(given) + ']');
  // the rows as the panel shows them
  own.tiers.filter(function (t) { return t.reason === 'seed' || t.seed; }).forEach(function (t) {
    say('row (printed)', null, t.name + ': ' + adv.renderAction(t));
  });
  (c.simulator.climb || []).forEach(function (cl) {
    if (cl.outcome === 'buys') say('simulator climb (printed)', null, cl.name + ' buys ' + cl.n_sim);
  });

  var diffs = out.filter(function (q) { return q.indexOf('DIFF') >= 0; }).length;
  console.log(name + ': ' + (diffs ? diffs + ' difference(s)' : 'all compared fields match') + ' | frontier ' + given.seed.frontier + ' | ' + (hatches(given) || 'no seed line'));
  out.forEach(function (q) { console.log(q); });
});

console.log('\nfield                                              match  differ  info');
var bad = 0;
order.forEach(function (f) {
  var t = totals[f];
  bad += t.differ;
  console.log((f + new Array(52).join(' ')).slice(0, 50) + ' ' + ('     ' + t.match).slice(-5) + '  ' + ('      ' + t.differ).slice(-6) + '  ' + ('    ' + t.info).slice(-4));
});
console.log(cases.length + ' cases, ' + bad + ' differences');
process.exit(bad ? 1 : 0);
