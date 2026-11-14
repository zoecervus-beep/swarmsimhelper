// Checks the native advisor's long-run climb mode (advisor.coffee, ASCENSION.md A.10.2, pass 4) against the
// simulator's reference cases in longrun_cases/, field by field as longrun_cases/README.md says.
//
// Each case is loaded into the real game (lib/game.js); the advisor's own snapshot() is taken; its purchase
// memory is seeded from the case (boughtAt = now - since_last_hatch_s, never hatched: run start - 60 s;
// stockAt = stock_below_at_last_look); advise() runs with the mode on and the case's settings twice:
//   - "own":   as the app runs it (its own A and R),
//   - "given": with the simulator's R and A - R (`larvae_for_climb`) passed in, so the climb's counts, what
//              it leaves, and what the push starts with can be compared exactly.
// Field classes:
//   exact             gate, lepidoptera target, horizon, frontier as loaded, each tier's H (1e-12 relative)
//                     and plain pass, twin guard, climb "fails"/"bank", push "nothing below", R given A,
//                     A - R given A
//   given the memory  climb "cooldown" and its earmark, climb counts (unless the simulator's half-the-meat
//                     cap binds), push "cooldown"
//   given the climb   what the climb left, what the push starts with, the frontier after the climb
//   given inputs      each push line's n and binding from that line's own inputs
//   printed only      the port's own A and R against the simulator's (territory purse versus share)
//
// Usage: node advisor/modelcheck/longrun_check.js [case ...]     (all cases by default; VERBOSE=1 for every line)
// Exits 1 on any difference in a compared field.
'use strict';
var fs = require('fs'), path = require('path');
var G = require('./lib/game');

var DIR = path.join(__dirname, 'longrun_cases');
var CHAIN = ['drone', 'queen', 'nest', 'greaterqueen', 'hive', 'hivequeen', 'empress', 'prophet', 'goddess',
  'pantheon', 'pantheon2', 'pantheon3', 'pantheon4', 'pantheon5', 'overmind', 'overmind2', 'overmind3', 'overmind4',
  'overmind5', 'overmind6'];
var D = function (x) { return new Decimal(x); };
var rel = function (a, b) { a = D(a); b = D(b); if (a.equals(b)) return 0; if (b.isZero()) return Infinity; return a.minus(b).abs().dividedBy(b.abs()).toNumber(); };
// equal as the README asks: exact below 2^53 (integers), else 1e-12 relative; tiny float remainders (< 1) equal to 1e-9
// Integers exactly below 2^53; otherwise 1e-12 relative. A fractional remainder under 1 larva (the
// simulator's A is not floored) is compared to 1e-14 of `scale`, the quantity it was cut from: the game's
// Decimal keeps 15 significant digits, so 3.7e12 - 3.7e12 keeps two decimals.
var same = function (a, b, scale) {
  a = D(a); b = D(b);
  if (!b.isInteger() || !a.isInteger()) {
    if (b.abs().lessThan(1) && a.abs().lessThan(1)) return a.minus(b).abs().lessThanOrEqualTo(D(scale || 1).times(1e-14).plus(1e-9));
    return rel(a, b) <= 1e-12;
  }
  return b.abs().lessThan(Math.pow(2, 53)) ? a.equals(b) : rel(a, b) <= 1e-12;
};

var cases = process.argv.slice(2);
if (!cases.length) cases = JSON.parse(fs.readFileSync(path.join(DIR, 'index.json'), 'utf8')).cases;

var totals = {}, order = [];
function tally(field, ok) {
  if (!totals[field]) { totals[field] = {match: 0, differ: 0, info: 0}; order.push(field); }
  totals[field][ok === null ? 'info' : ok ? 'match' : 'differ']++;
}

cases.forEach(function (name) {
  var c = JSON.parse(fs.readFileSync(path.join(DIR, name + '.json'), 'utf8'));
  var g = G.loadSave(path.join(DIR, c.save));
  var game = g.game, adv = g.get('advisor');
  var conf = c.config, st = c.state, dec = c.decisions || {};
  var cfg = {ageMultiple: conf.age_multiple, territory: conf.territory_share, bank: conf.bank, moths: conf.moth_target,
    cooldown: conf.cooldown_s || conf.push_cooldown_s, share: 0.5, longRun: 'on',
    spareEnergy: 'larvarush'};   // the simulator's reference policy casts spare energy below nexus 5, as the script did
  var snap = adv.snapshot(game);
  // the advisor's timers are on the game clock (wall + skippedMillis; NO-MIRRORS.md 12.1); these saves never warped
  var clock = snap.gameNow, start = snap.restartedAt + (clock - snap.now);
  var seed = function () {
    var mem = adv.createMemory(clock, snap.restartedAt);
    st.tiers.forEach(function (t, i) {
      var u = snap.units[i];
      mem.seen[u.name] = u.purchases;
      mem.boughtAt[u.name] = t.since_last_hatch_s == null ? start - cfg.cooldown * 1000 : clock - t.since_last_hatch_s * 1000;
      if (t.stock_below_at_last_look != null) mem.stockAt[u.name] = D(t.stock_below_at_last_look);
    });
    return mem;
  };
  var own = adv.advise(snap, seed(), cfg);
  var lr = own.longRun, out = [];
  var say = function (field, ok, text) {
    tally(field, ok);
    if (ok === false || process.env.VERBOSE) out.push((ok === null ? '  info ' : ok ? '  ok   ' : '  DIFF ') + field + ': ' + text);
  };

  // --- exact, from run age
  say('gate', lr.active === st.gate_active, 'port ' + lr.active + ', sim ' + st.gate_active);
  var target = lr.mothsRaised ? adv.LR.moths : cfg.moths;
  say('moth target', target === st.moth_target, 'port ' + target + ', sim ' + st.moth_target);
  say('horizon', rel(own.horizon, st.horizon_s) <= 1e-12, 'port ' + own.horizon + ', sim ' + st.horizon_s);

  // --- H and plain pass, tiers 2-20 (the advisor has no drone H; it never hatches drones)
  var H = {}, maxRel = 0;
  for (var i = 1; i < 20; i++) {
    var u = snap.units[i], t = st.tiers[i];
    H[u.name] = D(u.tier).times(u.cost).dividedBy(u.twin.times(u.prodEach));
    var e = rel(H[u.name], t.H_s); if (e > maxRel) maxRel = e;
    say('H (1e-12)', e <= 1e-12, u.name + ' rel ' + e);
    say('passes plain', H[u.name].lessThanOrEqualTo(own.horizon) === t.passes_plain, u.name);
  }

  if (!st.gate_active) {
    var off = adv.advise(snap, seed(), Object.assign({}, cfg, {longRun: 'off'}));
    var text = function (x) { return JSON.stringify([x.tiers.map(adv.renderAction), x.tips.map(adv.renderTip), adv.renderEnergy(x.energy)]); };
    say('gate shut = mode off', text(off) === text(own), 'advice ' + (text(off) === text(own) ? 'identical' : 'differs'));
  } else {
    // --- frontier as loaded, twin guard
    var fb = CHAIN.indexOf(lr.frontierBefore) + 1;
    say('frontier (state)', fb === st.frontier, 'port ' + fb + ', sim ' + st.frontier);
    st.tiers.forEach(function (t, i) {
      if (!t.twin_guard || i === 0 || !snap.units[i].twinCost) return;
      var price = snap.units[i].twinCost, held = snap.units[i + 1].count;
      var sup = i + 2 > fb && held.lessThan(price.times(adv.LR.twinGuard));
      say('twin guard', sup === t.twin_guard.suppressed, t.name + ': port ' + sup + ', sim ' + t.twin_guard.suppressed);
    });

    // --- the reserve, given the simulator's A
    var A = D(dec.larvae_before_climb), R = A.times(adv.LR.reserve).floor();
    say('R given A', same(R, dec.push_reserve), 'A ' + A.toExponential(6) + ': port R ' + R.toString() + ', sim ' + dec.push_reserve);
    say('A - R given A', same(A.minus(R), dec.larvae_for_climb), 'port ' + A.minus(R).toExponential(10) + ', sim ' + dec.larvae_for_climb);
    // the port's own A and R: territory share against the simulator's purse, so printed only
    var L = lr.larvae;
    say('own A and R (territory bookkeeping)', null, 'port A ' + L.available.toExponential(6) + ' (nexus ' + L.nexus.toExponential(3) + ') R ' + L.reserve.toExponential(6) +
      '; sim A ' + A.toExponential(6) + ' R ' + D(dec.push_reserve).toExponential(6) + ' (purse ' + st.larvae_held_back.territory_purse + ', nexus ' + st.larvae_held_back.nexus_saving + ')');

    // --- the climb, given the simulator's larvae and the seeded memory
    var r = adv.advise(snap, seed(), cfg, {reserve: dec.push_reserve, climbLarvae: dec.larvae_for_climb});
    var row = function (n) { return r.tiers.filter(function (x) { return x.name === n; })[0]; };
    var meat = D(st.meat), droneBought = false, comparable = true;
    (dec.climb || []).forEach(function (cl) {
      var x = row(cl.name), u = snap.units[cl.tier - 1];
      if (cl.tier === 1) {
        if (cl.outcome === 'buys') { droneBought = true; say('climb drones (the advisor never hatches drones)', null, 'sim buys ' + cl.n_sim); }
        return;
      }
      var got = x ? (x.pushed ? 'push row' : x.reason) : '(not listed)';
      if (cl.outcome === 'fails' || cl.outcome === 'bank') {
        var want = cl.outcome === 'fails' ? 'tooSlow' : 'bank';
        // a pushed tier's row shows its push; its climb verdict is that it failed the plain test
        if (x && x.pushed && cl.outcome === 'fails' && !x.passes) got = 'tooSlow';
        var above = (dec.climb || []).filter(function (a) { return a.tier === cl.tier + 1; })[0];
        if (got !== want && want === 'bank' && above && above.outcome === 'buys') {
          // The simulator applies rule 4 after buying the tier above in the same visit (top-down); the
          // advisor applies it to the state as shown and banks once that purchase is made. Check it would:
          // rule 4 with the tier above holding what the simulator's purchase gave it.
          var ua = snap.units[cl.tier], ub = snap.units[cl.tier - 1];
          var cnt = ua.count.plus(D(above.n_sim).times(ua.twin));
          var spendable = snap.larvaRate.times(1 - cfg.territory);
          var banks = H[ua.name].lessThanOrEqualTo(own.horizon) && cnt.greaterThanOrEqualTo(1) &&
            cnt.times(ua.prodEach).greaterThan(spendable.times(ub.twin).dividedBy(ua.twin).times(cfg.bank));
          say('climb bank after the purchase above', banks, cl.name + ': port ' + got + ' on the state shown; with ' + above.name + ' after the simulator\'s purchase rule 4 ' + (banks ? 'banks' : 'does not bank'));
          comparable = false;
          return;
        }
        say('climb ' + cl.outcome, got === want, cl.name + ' port ' + got);
      } else if (cl.outcome === 'cooldown') {
        var ok = !!x && x.reason === 'cooldown' && same(x.earmarked, cl.earmarked);
        say('climb cooldown and earmark', ok, cl.name + ': port ' + got + ' ' + (x && x.earmarked ? x.earmarked.toString() : '') + ', sim earmark ' + cl.earmarked);
        if (!ok) comparable = false;
      } else if (cl.outcome === 'buys' || cl.outcome === 'passes_none') {
        var nSim = cl.outcome === 'buys' ? D(cl.n_sim) : D(0);
        var meatCap = u.meatCost ? meat.times(0.5).dividedBy(u.meatCost).floor() : null;
        var meatBinds = meatCap !== null && cl.outcome === 'buys' && nSim.equals(meatCap);
        var nPort = x ? x.buys : D(0);
        if (meatBinds) say('climb count (simulator meat cap binds)', null, cl.name + ': port ' + nPort.toString() + ', sim ' + cl.n_sim);
        else {
          var ok2 = same(nPort, nSim);
          say('climb count', ok2, cl.name + ': port ' + nPort.toString() + ' (' + got + '), sim ' + nSim.toString());
          if (!ok2) comparable = false;
        }
        if (u.meatCost) meat = meat.minus(nSim.times(u.meatCost));
        if (meatBinds) comparable = false;
      }
    });
    // --- given the climb
    if (comparable && !droneBought) {
      say('climb left', same(r.longRun.larvae.climbLeft, dec.climb_left, dec.larvae_for_climb), 'port ' + r.longRun.larvae.climbLeft.toString() + ', sim ' + dec.climb_left);
      say('larvae for push', same(r.longRun.larvae.forPush, dec.larvae_for_push), 'port ' + r.longRun.larvae.forPush.toString() + ', sim ' + dec.larvae_for_push);
      var fa = CHAIN.indexOf(r.longRun.frontier) + 1;
      say('frontier after climb', fa === dec.frontier_at_push, 'port ' + fa + ', sim ' + dec.frontier_at_push);
    } else {
      say('climb left / push larvae / frontier (climb differs)', null, droneBought ? 'the simulator hatched drones' : 'the climbs differ (meat cap, or a bank after the purchase above)');
    }

    // --- push lines
    var lines = {};
    (r.longRun.lines || []).forEach(function (l) { lines[l.unit] = l; });
    (dec.push || []).forEach(function (p) {
      var i = CHAIN.indexOf(p.name), u = snap.units[i], below = snap.units[i - 1];
      if (p.outcome === 'nothing below') {
        say('push nothing below', !below.count.greaterThan(0), p.name);
      } else if (p.outcome === 'cooldown') {
        var l = lines[p.name];
        say('push cooldown', !!l && l.outcome === 'cooldown', p.name + ': port ' + (l ? l.outcome : 'no line'));
      } else if (p.outcome === 'hatch' || p.outcome === 'under one') {
        var res = adv.pushLine(p.share, D(p.below_held), u.cost, D(p.larvae_left), D(p.meat), u.meatCost);
        var okp = same(res.n, p.n) && res.binding === p.binding;
        say('push n and binding (given inputs)', okp, p.name + ' ' + p.outcome + ': port ' + res.n.toString() + ' ' + res.binding + ', sim ' + p.n + ' ' + p.binding);
        // and the port's own line, when its climb matched
        if (comparable && !droneBought) {
          var lp = lines[p.name];
          var okl = !!lp && lp.outcome === p.outcome && same(lp.n, p.n) && lp.binding === p.binding;
          say('push line (given the climb)', okl, p.name + ': port ' + (lp ? lp.outcome + ' ' + (lp.n ? lp.n.toString() : '') + ' ' + (lp.binding || '') : 'no line') + ', sim ' + p.outcome + ' ' + p.n + ' ' + p.binding);
        }
      } else if (p.outcome === 'no larvae') {
        var lq = lines[p.name];
        if (comparable && !droneBought) say('push no larvae (given the climb)', !!lq && lq.outcome === 'no larvae', p.name + ': port ' + (lq ? lq.outcome : 'no line'));
        else say('push no larvae', null, p.name);
      }
    });
  }
  var diffs = out.filter(function (s) { return s.indexOf('DIFF') >= 0; }).length;
  console.log(name + ': ' + (diffs ? diffs + ' difference(s)' : 'all compared fields match') + ' | max H rel ' + maxRel.toExponential(2) +
    (st.gate_active ? ' | R ' + dec.push_reserve + ', push starts with ' + dec.larvae_for_push + ', sim push lines ' +
      (dec.push || []).filter(function (p) { return p.outcome === 'hatch'; }).map(function (p) { return p.name; }).join(',') : ' | gate shut'));
  out.forEach(function (s) { console.log(s); });
});

console.log('\nfield                                              match  differ  info');
var bad = 0;
order.forEach(function (f) {
  var t = totals[f];
  bad += t.differ;
  console.log((f + new Array(52).join(' ')).slice(0, 50) + ' ' + ('     ' + t.match).slice(-5) + '  ' + ('      ' + t.differ).slice(-6) + '  ' + ('    ' + t.info).slice(-4));
});
process.exit(bad ? 1 : 0);
