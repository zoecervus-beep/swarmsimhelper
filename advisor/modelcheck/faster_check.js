// Checks rule FA in the native advisor (advisor.coffee `fasterTest` / `fasterWait` and the climb; MODEL-CHECK.md,
// "Faster-aware climbing, pass 2", "Rule FA, if adopted (variant c2)") against the reference cases in faster_cases/,
// as faster_cases/README.md says. Each case's save is loaded in the real game (lib/game.js); the advisor's own
// snapshot() is taken; advise() runs with rule FA on and the case's age multiple, territory share and long-run mode.
// Field classes:
//   exact                plain passes, H (1e-12), the horizon
//   no clause            a waiting tier with none affordable shows the plain "wait" (no rule-FA clause)
//   exact given n        (and the reference's horizon) every level L = 1..12 (price of L levels, units kept, H with them, passes) and the decision
//                        (start with L, or wait with the levels needed, their price, the units and hatch needed), from
//                        the port's pure functions given the reference's n
//   exact given A        n itself, from the reference's larvae for the climb with the advisor's min(A, below / cost,
//                        meat / meat price)
//   the port's own A     the advice as the app gives it: the port's n and decision. Compared exactly when its n equals
//                        the reference's; otherwise printed (territory share and nexus bookkeeping, as in the long-run
//                        cases)
//   follow in the game   where the port's own advice starts a tier: hatch n in the game, re-advise (the levels' tip at
//                        1x, the tier not started again), buy the L levels in the game, re-advise (the tier passes the
//                        plain test), 61 s later re-advise again (no flip back to "wait")
//   printed only         the simulator's own climb (its hatch is capped at half the meat; README)
// Usage: node advisor/modelcheck/faster_check.js [case ...]     (VERBOSE=1 for every line). Exit 1 on any difference.
'use strict';
var fs = require('fs'), path = require('path');
var G = require('./lib/game');

var DIR = path.join(__dirname, 'faster_cases');
var D = function (x) { return new Decimal(x); };
var rel = function (a, b) { a = D(a); b = D(b); if (a.equals(b)) return 0; if (b.isZero()) return Infinity; return a.minus(b).abs().dividedBy(b.abs()).toNumber(); };
var same = function (a, b) { a = D(a); b = D(b); return b.abs().lessThan(Math.pow(2, 53)) && b.isInteger() ? a.equals(b) : rel(a, b) <= 1e-12; };

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
  var cfg = {ageMultiple: c.config.age_multiple, territory: c.config.territory_share, longRun: c.config.long_run_mode,
    spareEnergy: 'save', ascension: 'off', fasterStart: 'on',
    twinDetour: 'off'};   // made with the old twin planner (on: no field moves)
  var out = [];
  var say = function (field, ok, text) {
    tally(field, ok);
    if (ok === false || process.env.VERBOSE) out.push((ok === null ? '  info ' : ok ? '  ok   ' : '  DIFF ') + field + ': ' + text);
  };
  var snap = adv.snapshot(game);
  var r = adv.advise(snap, null, cfg);
  var row = function (res, n) { return res.tiers.filter(function (t) { return t.name === n; })[0]; };
  var unit = function (n) { return snap.units.filter(function (u) { return u.name === n; })[0]; };
  // to 1 ms of run age x the multiple: on the swarmwarp route the game skips whole milliseconds per cast, the run-age
  // estimate uses the unrounded skip (warp_asc1_empress: 0.5 ms)
  say('horizon (1 ms of run age)', Math.abs(r.horizon - c.state.horizon_s) <= 1e-3 * c.config.age_multiple + 1e-12 * c.state.horizon_s, 'port ' + r.horizon + ', ref ' + c.state.horizon_s);
  c.plain_passes.forEach(function (n) {
    var t = row(r, n);
    say('plain passes', !!t && t.passes, n + ': port ' + (t ? t.passes : 'not listed'));
  });

  c.rule_FA.forEach(function (ref) {
    var t = row(r, ref.name), u = unit(ref.name);
    if (!t) { say('tier listed', false, ref.name + ' not among the port\'s tiers'); return; }
    say('H (1e-12)', rel(t.H, ref.H_s) <= 1e-12, ref.name + ': port ' + t.H.toExponential(12) + ', ref ' + ref.H_s);
    say('fails the plain test', !t.passes, ref.name);
    if (ref.n_affordable === undefined) return;
    // n given the reference's larvae for the climb
    var nA = Decimal.min(D(ref.larvae_for_climb), t.affordable);
    if (u.meatCost) nA = Decimal.min(nA, snap.meat.dividedBy(u.meatCost));
    nA = nA.floor();
    say('n given A', same(nA, ref.n_affordable), ref.name + ': port ' + nA.toString() + ', ref ' + ref.n_affordable);
    // the levels and the decision, given the reference's n
    // given the reference's horizon too: the wait clause's units amplify a 1e-9 horizon difference near 2^L x horizon = H
    var io = {H: t.H, horizon: c.state.horizon_s, mult: u.prodMult, price: u.prodCost, factor: u.prodFactor};
    var res = adv.fasterTest(Object.assign({got: D(ref.got)}, io));
    var okL = ref.levels.every(function (lv, i) {
      var p = res.levels[i];
      // units kept are not integer counts (held is fractional): 1e-12 relative (the reference's float drops the
      // fraction near 2^53: run2_asc1_prophet L 2, -8585974175440812.188 against -8585974175440812.0)
      return p.L === lv.L && same(p.price, lv.price_total) && rel(p.kept, lv.N_kept) <= 1e-12 && p.passes === lv.passes &&
        ((p.H === null) === (lv.H_eff_s === null)) && (p.H === null || rel(p.H, lv.H_eff_s) <= 1e-12);
    });
    say('levels 1..12 given n', okL, ref.name + (okL ? '' : ': ' + JSON.stringify(res.levels.slice(0, 4).map(function (p) { return [p.L, p.price.toString(), p.kept.toString(), p.passes]; }))));
    var d = ref.decision;
    if (d.type === 'start') {
      say('decision given n: start with L', res.pass === d.faster_levels && same(res.levels[res.pass - 1].price, d.faster_price_total),
        ref.name + ': port L ' + res.pass + ', ref L ' + d.faster_levels);
    } else {
      var w = adv.fasterWait(Object.assign({held: t.count, twin: t.twin, n: D(d.affordable)}, io));
      // the clause shows only where at least one is affordable now (Nov 20 polish): where none is, the row must have none
      if (D(d.affordable).lessThan(1)) say('no clause where none is affordable', !(t.faster && t.faster.type === 'wait'), ref.name + ': row ' + adv.renderAction(t));
      else if (d.levels_needed > adv.FA_MAX_LEVELS) say('decision given n: wait, no clause past 12 levels', res.pass === null && w === null, ref.name);
      else say('decision given n: wait and its clause', res.pass === null && !!w && w.levels === d.levels_needed && same(w.price, d.their_price) &&
        rel(w.units, d.units_needed_after_hatch) <= 1e-12 && same(w.hatch, D(d.hatch_needed).ceil()),
        ref.name + ': port ' + (w ? w.levels + ' levels, ' + w.price.toString() + ', units ' + w.units.toExponential(8) + ', hatch ' + w.hatch.toString() : 'none') +
        '; ref ' + d.levels_needed + ', ' + d.their_price + ', ' + d.units_needed_after_hatch + ', ' + d.hatch_needed);
    }
    // the advice as the app gives it
    var own = t.reason === 'fasterStart' ? 'start L' + t.faster.levels : t.faster && t.faster.type === 'held' ? 'held L' + t.faster.levels : 'wait';
    var ownN = t.reason === 'fasterStart' ? t.buys : t.faster && t.faster.affordable;
    var refD = d.type === 'start' ? 'start L' + d.faster_levels : 'wait';
    var nSame = ownN !== undefined && ownN !== null && same(ownN, ref.n_affordable);
    if (d.type === 'wait' && D(d.affordable).lessThan(1)) { /* compared above: no clause */ }
    else if (nSame) say('own advice (n equal)', own === refD, ref.name + ': port ' + own + ', ref ' + refD);
    else say('own advice (port A differs)', null, ref.name + ': port ' + own + ' n ' + (ownN ? ownN.toString() : '-') + ', ref ' + refD + ' n ' + ref.n_affordable + ' | row: ' + adv.renderAction(t));
    var sc = (c.simulator.climb || []).filter(function (q) { return q.name === ref.name; })[0];
    if (sc) say('simulator (printed)', null, ref.name + ': ' + sc.outcome + (sc.faster_level_L ? ' L' + sc.faster_level_L : '') + (sc.n_sim ? ' n ' + sc.n_sim : ''));
  });

  // follow a start in the game
  r.tiers.filter(function (t) { return t.reason === 'fasterStart'; }).forEach(function (t) {
    var Lv = t.faster.levels, n = t.buys;
    var stats = game.session.state.statistics.byUnit;
    var bought = game.unit(t.name).buy(n);
    stats[t.name] = stats[t.name] || {num: 0};
    stats[t.name].num = D(stats[t.name].num).plus(bought.num).toString();
    say('follow: hatch n in the game', bought.num.equals(n), t.name + ': ' + bought.num.toString() + ' of ' + n.toString());
    var r1 = adv.advise(adv.snapshot(game), r.memory, cfg), t1 = row(r1, t.name);
    var tip = r1.tips.filter(function (q) { return q.type === 'faster' && q.unit === t.name; })[0];
    say('follow: after the hatch, the levels\' tip at 1x', !!tip && tip.levels === Lv && t1.reason !== 'fasterStart',
      t.name + ': row ' + adv.renderAction(t1) + '; tip ' + (tip ? adv.renderTip(tip) : 'none'));
    var up = game.upgrade(t.name + 'prod'), k = 0;
    for (var i = 0; i < Lv; i++) { try { up.buy(1); k++; } catch (e) { break; } }
    say('follow: the L levels bought in the game', k === Lv, t.name + ': ' + k + ' of ' + Lv);
    var r2 = adv.advise(adv.snapshot(game), r1.memory, cfg), t2 = row(r2, t.name);
    say('follow: the tier now passes the plain test', t2.passes, t.name + ': ' + adv.renderAction(t2) + ', H ' + t2.H.toExponential(4) + ' horizon ' + r2.horizon.toExponential(4));
    G.advance(game, 61);
    var r3 = adv.advise(adv.snapshot(game), r2.memory, cfg), t3 = row(r3, t.name);
    say('follow: 61 s later, no flip back to wait', t3.passes && t3.reason !== 'tooSlow', t.name + ': ' + adv.renderAction(t3));
  });

  var diffs = out.filter(function (q) { return q.indexOf('DIFF') >= 0; }).length;
  console.log(name + ': ' + (diffs ? diffs + ' difference(s)' : 'all compared fields match') + ' | ' +
    r.tiers.filter(function (t) { return t.faster || t.reason === 'fasterStart'; }).map(function (t) { return t.name + ': ' + adv.renderAction(t); }).join(' | '));
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
