// Checks the native advisor's long-run climb mode (advisor.coffee, ASCENSION.md A.10.2) against the
// simulator's reference cases in longrun_cases/, field by field as longrun_cases/README.md says:
//   exact            gate, lepidoptera target, horizon, the frontier of the state as loaded, each tier's
//                    break-even H (1e-12 relative) and plain pass, the twin guard, climb outcomes
//                    "fails" and "bank", push "nothing below" and "cooldown" (memory seeded from
//                    since_last_hatch_s)
//   given inputs     LR-1's L with the simulator's purchase count (the port's own fasterLevels) and with
//                    the port's own count (against the case's got_min table); each push line's n and
//                    binding from the line's own inputs (the port's own pushLine)
//   not comparable   purchase counts, larvae left for the push, and what follows from them (the
//                    frontier after the climb and the port's own push lines): printed, not failed on
//
// Each case is loaded into the real game (lib/game.js), the advisor's own snapshot() is taken, and
// advise() runs with the mode on and the case's settings.
//
// Usage: node advisor/modelcheck/longrun_check.js [case ...]     (all cases by default)
// Exits 1 on any difference in an exact or given-inputs field.
'use strict';
var fs = require('fs'), path = require('path');
var G = require('./lib/game');

var DIR = path.join(__dirname, 'longrun_cases');
var CHAIN = ['drone', 'queen', 'nest', 'greaterqueen', 'hive', 'hivequeen', 'empress', 'prophet', 'goddess',
  'pantheon', 'pantheon2', 'pantheon3', 'pantheon4', 'pantheon5', 'overmind', 'overmind2', 'overmind3', 'overmind4',
  'overmind5', 'overmind6'];
var D = function (x) { return new Decimal(x); };
var rel = function (a, b) { a = D(a); b = D(b); if (a.equals(b)) return 0; return a.minus(b).abs().dividedBy(b.abs()).toNumber(); };

var cases = process.argv.slice(2);
if (!cases.length) cases = JSON.parse(fs.readFileSync(path.join(DIR, 'index.json'), 'utf8')).cases;

var totals = {};  // field class -> {match, differ, na}
function tally(field, ok, note) {
  var t = totals[field] = totals[field] || {match: 0, differ: 0, info: 0, notes: []};
  if (ok === null) t.info++;
  else if (ok) t.match++;
  else { t.differ++; if (note) t.notes.push(note); }
}

cases.forEach(function (name) {
  var c = JSON.parse(fs.readFileSync(path.join(DIR, name + '.json'), 'utf8'));
  var g = G.loadSave(path.join(DIR, c.save));
  var game = g.game, adv = g.get('advisor');
  var conf = c.config, st = c.state, dec = c.decisions || {};
  var cfg = {ageMultiple: conf.age_multiple, territory: conf.territory_share, bank: conf.bank, moths: conf.moth_target,
    cooldown: conf.push_cooldown_s, longRun: 'on'};
  var snap = adv.snapshot(game);
  // Purchase memory seeded from the simulator's last-hatch times; never hatched: available at once.
  var mem = adv.createMemory(snap.now, snap.restartedAt);
  st.tiers.forEach(function (t, i) {
    var u = snap.units[i];
    mem.seen[u.name] = u.purchases;
    mem.boughtAt[u.name] = t.since_last_hatch_s == null ? snap.now - cfg.cooldown * 1000 : snap.now - t.since_last_hatch_s * 1000;
  });
  var r = adv.advise(snap, mem, cfg);
  var lr = r.longRun, out = [];
  var say = function (field, ok, text) { tally(field, ok, name + ': ' + text); if (ok === false || process.env.VERBOSE) out.push((ok === null ? '  info ' : ok ? '  ok   ' : '  DIFF ') + field + ': ' + text); };

  // --- exact, from run age
  say('gate', lr.active === st.gate_active, 'port ' + lr.active + ', sim ' + st.gate_active);
  var target = lr.mothsRaised ? adv.LR.moths : cfg.moths;
  say('moth target', target === st.moth_target, 'port ' + target + ', sim ' + st.moth_target);
  say('horizon', rel(r.horizon, st.horizon_s) <= 1e-12, 'port ' + r.horizon + ', sim ' + st.horizon_s);

  // --- each tier's H and plain pass (tier 2 up: the advisor has no drone H; a drone is never hatched)
  var H = {}, passes = {}, maxRel = 0;
  for (var i = 1; i < 20; i++) {
    var u = snap.units[i];
    H[u.name] = D(u.tier).times(u.cost).dividedBy(u.twin.times(u.prodEach));  // the advisor's H, as advise() computes it
    var row = r.tiers.filter(function (x) { return x.name === u.name; })[0];
    if (row) H[u.name] = row.H;
    passes[u.name] = H[u.name].lessThanOrEqualTo(r.horizon);
    var t = st.tiers[i];
    var e = rel(H[u.name], t.H_s); if (e > maxRel) maxRel = e;
    say('H (1e-12)', e <= 1e-12, u.name + ' port ' + H[u.name].toExponential(15) + ' sim ' + t.H_s + ' rel ' + e);
    say('passes plain', passes[u.name] === t.passes_plain, u.name + ' port ' + passes[u.name] + ', sim ' + t.passes_plain);
  }

  // --- the frontier of the state as loaded (the gate open only)
  if (st.gate_active) {
    var fb = CHAIN.indexOf(lr.frontierBefore) + 1;
    say('frontier (state)', fb === st.frontier, 'port ' + fb + ' (' + lr.frontierBefore + '), sim ' + st.frontier);
    // --- twin guard: suppressed iff the pay tier is above that frontier and holds < 1e6 x the price
    st.tiers.forEach(function (t, i) {
      if (!t.twin_guard || i === 0) return;
      var payIdx = i + 1, price = snap.units[i].twinCost, held = snap.units[payIdx].count;
      if (!price) return;
      var sup = payIdx + 1 > fb && held.lessThan(price.times(adv.LR.twinGuard));
      say('twin guard', sup === t.twin_guard.suppressed, t.name + ' twin paid in ' + CHAIN[payIdx] + ': port ' + (sup ? 'suppressed' : 'allowed') + ', sim ' + (t.twin_guard.suppressed ? 'suppressed' : 'allowed') +
        ' (held/price ' + held.dividedBy(price).toExponential(7) + ')');
    });
  } else {
    // the gate shut: the advice must be the mode-off advice
    var off = adv.advise(snap, mem, Object.assign({}, cfg, {longRun: 'off'}));
    var text = function (x) { return JSON.stringify([x.tiers.map(adv.renderAction), x.tips.map(adv.renderTip), adv.renderEnergy(x.energy)]); };
    say('gate shut = mode off', text(off) === text(r), 'advice ' + (text(off) === text(r) ? 'identical' : 'differs'));
  }

  // --- climb outcomes
  (dec.climb || []).forEach(function (cl) {
    if (cl.tier === 1) return;  // drone: the advisor never hatches it
    var row = r.tiers.filter(function (x) { return x.name === cl.name; })[0];
    if (cl.outcome === 'fails' || cl.outcome === 'bank') {
      var want = cl.outcome === 'fails' ? 'tooSlow' : 'bank';
      // a pushed tier's row shows its push instead; its climb verdict is that it failed
      var got = row ? (row.pushed && !row.passes && !row.lrPass ? 'tooSlow' : row.reason) : '(not listed)';
      var above = (dec.climb || []).filter(function (a) { return a.tier === cl.tier + 1; })[0];
      if (got !== want && want === 'bank' && above && above.outcome === 'buys') {
        // The simulator applies rule 4 after the tier above was bought in the same visit (top-down);
        // the advisor applies it to the state as shown and banks once that purchase is made. Check
        // that it would: rule 4 with the tier above holding what the simulator's purchase gave it
        // (count + n_sim x twin, production doubled for each faster level bought after it).
        var ia = cl.tier, ua = snap.units[ia], ub = snap.units[ia - 1];
        var lv = (dec.faster_after_climb || []).filter(function (f) { return f.name === above.name; }).length;
        var cnt = ua.count.plus(D(above.n_sim).times(ua.twin));
        var prod = ua.prodEach.times(Math.pow(2, lv));
        var Hafter = D(ua.tier).times(ua.cost).dividedBy(ua.twin.times(prod));
        var spendable = snap.larvaRate.times(1 - cfg.territory);
        var banks = Hafter.lessThanOrEqualTo(r.horizon) && cnt.greaterThanOrEqualTo(1) &&
          cnt.times(prod).greaterThan(spendable.times(ub.twin).dividedBy(ua.twin).times(cfg.bank));
        say('climb bank after the purchase above', banks, cl.name + ': port shows ' + got + ' on the state as loaded; with ' + above.name +
          ' after the simulator\'s purchase' + (lv ? ' and ' + lv + ' faster level(s)' : '') + ' rule 4 ' + (banks ? 'banks' : 'does not bank'));
        return;
      }
      say('climb ' + cl.outcome, got === want, cl.name + ' port ' + got);
    }
    if (cl.faster_level_L !== undefined && st.gate_active) {
      // LR-1 with the simulator's own purchase count, through the port's own function
      var i = CHAIN.indexOf(cl.name), u = snap.units[i];
      var x = {count: u.count, twin: u.twin, H: H[cl.name]};
      var fit = adv.fasterLevels(x, u, D(cl.n_sim), r.horizon);
      var L = fit ? fit.levels : 0;
      say('LR-1 L (sim n)', L === cl.faster_level_L, cl.name + ' n_sim ' + cl.n_sim + ': port L ' + L + ', sim L ' + cl.faster_level_L);
    }
  });
  // LR-1 with the port's own purchase count, against the case's got_min table
  r.tiers.forEach(function (row) {
    if (row.lrN === undefined) return;
    var t = st.tiers[CHAIN.indexOf(row.name)], table = t.faster_levels_pass_if_got_at_least;
    if (!table) return;
    var got = row.count.plus(row.lrN.times(row.twin)), Ltab = 0;
    for (var k = 0; k < table.length; k++) {
      var m = table[k].got_min;
      if (m != null && got.greaterThanOrEqualTo(D(m).times(1 - 1e-9))) { Ltab = table[k].L; break; }
    }
    var Lport = row.fasterLevels || 0;
    var ok = Lport === Ltab || (Ltab === 0 && Lport > table.length);  // the table stops at L = 8
    say('LR-1 L (port n)', ok, row.name + ' n_port ' + row.lrN.toExponential(6) + ' got ' + got.toExponential(6) + ': port L ' + Lport + ', table L ' + Ltab);
  });

  // --- push lines
  var lines = {};
  (lr.lines || []).forEach(function (l) { lines[l.unit] = l; });
  (dec.push || []).forEach(function (p) {
    var i = CHAIN.indexOf(p.name), u = snap.units[i], below = snap.units[i - 1];
    if (p.outcome === 'nothing below') {
      say('push nothing below', !below.count.greaterThan(0), p.name + ': port holds ' + below.count.toExponential(4) + ' ' + below.name);
    } else if (p.outcome === 'cooldown') {
      var l = lines[p.name];
      say('push cooldown', !!l && l.outcome === 'cooldown', p.name + ': port ' + (l ? l.outcome : 'no line (frontier ' + lr.frontier + ')'));
    } else if (p.outcome === 'hatch' || p.outcome === 'under one') {
      var res = adv.pushLine(p.share, D(p.below_held), u.cost, D(p.larvae_left), D(p.meat), u.meatCost);
      var n = D(p.n), exact = n.lessThan(Math.pow(2, 53));
      var ok = (exact ? res.n.equals(n) : rel(res.n, n) <= 1e-12) && res.binding === p.binding;
      say('push n and binding', ok, p.name + ' (' + p.outcome + '): port ' + res.n.toString() + ' ' + res.binding + ', sim ' + p.n + ' ' + p.binding);
    } else if (p.outcome === 'no larvae') {
      say('push no larvae (sizing)', null, p.name + ': sim had ' + dec.larvae_for_push + ' larvae left; port line ' + (lines[p.name] ? lines[p.name].outcome : 'none'));
    }
  });

  // --- not comparable: printed
  if (st.gate_active) {
    var fa = CHAIN.indexOf(lr.frontier) + 1;
    say('frontier after climb (sizing)', null, 'port ' + fa + ', sim ' + dec.frontier_at_push);
    say('port push lines (sizing)', null, (lr.lines || []).filter(function (l) { return l.outcome === 'hatch' || l.outcome === 'under one'; })
      .map(function (l) { return l.unit + ' ' + l.outcome + ' ' + (l.n ? l.n.toExponential(3) : '') + ' ' + (l.binding || ''); }).join('; ') || 'none');
  }
  var diffs = out.filter(function (s) { return s.indexOf('DIFF') >= 0; }).length;
  console.log(name + ': ' + (diffs ? diffs + ' difference(s)' : 'all exact fields match') + ' | max H rel ' + maxRel.toExponential(2) +
    (st.gate_active ? ' | frontier ' + st.frontier + ' / after climb port ' + (CHAIN.indexOf(lr.frontier) + 1) + ' sim ' + dec.frontier_at_push : ' | gate shut'));
  out.forEach(function (s) { console.log(s); });
});

console.log('\nfield                              match  differ  info');
var bad = 0;
Object.keys(totals).forEach(function (f) {
  var t = totals[f];
  bad += t.differ;
  console.log((f + '                                   ').slice(0, 34) + ' ' + ('     ' + t.match).slice(-5) + '  ' + ('      ' + t.differ).slice(-6) + '  ' + ('    ' + t.info).slice(-4));
});
process.exit(bad ? 1 : 0);
