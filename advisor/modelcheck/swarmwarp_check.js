// Checks the native advisor's swarmwarp route (advisor/NO-MIRRORS.md sections 11-13; advisor.coffee,
// advisorascension.coffee, advisorterritory.coffee with the setting ascension: 'swarmwarp') against the reference
// cases in swarmwarp_cases/, field by field as swarmwarp_cases/README.md says.
//
// Each case's save is loaded into the real game (lib/game.js); the advisor services' own snapshot() functions read it;
// advise() runs with the owner's settings and the route set to swarmwarp. Field classes (README, "what must match"):
//   exact                stage, test passes, wants ascension, test need (1e-12), save_at / threshold / halving /
//                        ascension cost, mutagen respec and steps (counts floored; 1e-12 past 2^53), steps again
//                        after applying them in the game (empty), swarmwarp power and skip, the game run age estimate,
//                        horizon and long-run gate given that age, the energy line up to the first cast (nexus,
//                        lepidoptera, bats), saving / ascend now, empower advised (fresh memory)
//   exact given memory   cooldown_released_by_warp and five_warps_affordable: the port's purchase memory is seeded on
//                        the game clock from the case; per tier the game-clock time since the last hatch, cooldown
//                        released, share released, stock release; the climb's outcome per tier (buys / fails / bank
//                        / cooldown), checked before the warp (climb_without_warp) and after warps CAST IN THE GAME
//   one at a time        every energy line that casts says 1 cast and how many are affordable; after each warp the
//                        line waits ('warpAfter') while the panel has the released purchases open
//   printed only         the simulator's cast count (it casts all affordable at once), climb counts after a warp
//                        (they depend on the simulator's territory purse, not on the rules), the purchases made
//                        between warps (expansions, hatcheries, empowers: "likely equal, not exact")
// Usage: node advisor/modelcheck/swarmwarp_check.js [case ...]     (all cases by default; VERBOSE=1 for every line)
// Exits 1 on any difference in a compared field.
'use strict';
var fs = require('fs'), path = require('path');
var G = require('./lib/game');
G.loadCoffee(path.join(G.COFFEE, 'app/scripts/services/advisorterritory.coffee'));
G.loadCoffee(path.join(G.COFFEE, 'app/scripts/services/advisorascension.coffee'));

var DIR = path.join(__dirname, 'swarmwarp_cases');
var D = function (x) { return new Decimal(x); };
var rel = function (a, b) { a = D(a); b = D(b); if (a.equals(b)) return 0; if (b.isZero()) return Infinity; return a.minus(b).abs().dividedBy(b.abs()).toNumber(); };
// counts: exact below 2^53, else 1e-12 relative
var sameCount = function (a, b) { a = D(a); b = D(b); return b.abs().lessThan(Math.pow(2, 53)) ? a.equals(b) : rel(a, b) <= 1e-12; };
// The owner's stored settings (ASCENSION.md, README: ageMultiple 5, spareEnergy 'save', longRun 'off'), with the
// route set to swarmwarp. The route switches the long-run climb on and sets lepidoptera 10,000 itself.
var CFG = {ascension: 'swarmwarp', ageMultiple: 5, spareEnergy: 'save', longRun: 'off', territory: 0.1};

var cases = process.argv.slice(2);
if (!cases.length) cases = JSON.parse(fs.readFileSync(path.join(DIR, 'index.json'), 'utf8')).cases;

var totals = {}, order = [];
function tally(field, ok) {
  if (!totals[field]) { totals[field] = {match: 0, differ: 0, info: 0}; order.push(field); }
  totals[field][ok === null ? 'info' : ok ? 'match' : 'differ']++;
}

function services(L) { return {adv: L.get('advisor'), asc: L.get('advisorAscension'), terr: L.get('advisorTerritory')}; }

// The panel's energy line: the meat advisor's record, coupled with the ascension advice, then ordered against the
// open purchases (advisorView does the same).
function energyLine(S, game, mem, tmem) {
  var snap = S.adv.snapshot(game), asnap = S.asc.snapshot(game), tsnap = S.terr.snapshot(game);
  var a = S.asc.advise(asnap, CFG);
  var r = S.adv.advise(snap, mem, Object.assign({}, CFG, a.moths ? {runMoths: a.moths.moths, runStage: a.moths.stage} : {}));
  var t = S.terr.advise(tsnap, tmem, CFG);
  var rec = S.asc.coupleEnergy(r.energy, a);
  return {snap: snap, asnap: asnap, a: a, r: r, t: t, coupled: rec, ordered: S.adv.orderWarp(rec, r, t)};
}

// The climb outcome per tier in the simulator's words.
function outcome(x) {
  if (!x) return '(not listed)';
  if (x.reason === 'tooSlow') return 'fails';
  if (x.reason === 'bank') return 'bank';
  if (x.reason === 'cooldown') return 'cooldown';
  if (x.kind === 'buy') return 'buys';
  return x.reason;
}

// Seed the port's memory on the game clock: tier hatched `since` game-seconds before `at` (game clock, ms).
function seedMemory(adv, snap, tiers, at) {
  var mem = adv.createMemory(snap.gameNow, snap.restartedAt);
  snap.units.forEach(function (u) {
    var t = tiers[u.name];
    if (!t || t.since_last_hatch_game_s == null) return;
    mem.seen[u.name] = u.purchases;
    mem.boughtAt[u.name] = at - t.since_last_hatch_game_s * 1000;
  });
  return mem;
}

// Make the port's suggestions in the game (as a player following the panel would), recording hatches in the game's
// statistics as its statistics service would. Returns what was bought.
function follow(S, game, x) {
  var stats = game.session.state.statistics.byUnit, done = {climb: 0, tips: 0, territory: 0, expansions: 0, hatcheries: 0, empowers: 0};
  var hatch = function (name, n) {
    var u = game.unit(name);
    try { var res = u.buy(D(n)); } catch (e) { return false; }
    stats[name] = stats[name] || {num: 0, twinnum: 0, clicks: 0};
    stats[name].num = D(stats[name].num).plus(res.num).toString();
    return true;
  };
  var upgrade = function (name, levels) {
    var up = game.upgrade(name), n = 0;
    for (var i = 0; i < levels; i++) { try { up.buy(1); n++; } catch (e) { break; } }
    return n;
  };
  x.r.tiers.forEach(function (t) { if ((t.kind === 'buy' || t.kind === 'push') && t.buys.greaterThanOrEqualTo(1) && hatch(t.name, t.buys)) done.climb++; });
  x.r.tips.forEach(function (t) {
    if (t.type === 'faster') { var up = game.upgrade(t.unit + 'prod'); try { up.buyMax(); done.tips++; } catch (e) {} }
    if (t.type === 'twin') { if (upgrade(t.unit + 'twin', 1)) done.tips++; }
  });
  // territory afresh after the climb (it reads the meat left)
  var t = S.terr.advise(S.terr.snapshot(game), x.t.memory, CFG);
  t.records.forEach(function (rec) {
    if (rec.type === 'upgrade') {
      var n = upgrade(rec.name, rec.levels);
      if (rec.name === 'expansion') done.expansions += n;
      if (rec.name === 'hatchery') done.hatcheries += n;
      done.territory++;
    } else if (rec.type === 'empower') { done.empowers += upgrade(rec.name, 1); done.territory++; }
    else if (rec.type === 'twin') { upgrade(rec.name, 1); done.territory++; }
    else if (rec.type === 'hatch') { if (hatch(rec.unit, rec.buys)) done.territory++; }
  });
  return done;
}

cases.forEach(function (name) {
  var c = JSON.parse(fs.readFileSync(path.join(DIR, name + '.json'), 'utf8'));
  var L = G.loadSave(path.join(DIR, c.save));
  var game = L.game, S = services(L);
  var st = c.state, dec = c.decisions || {}, out = [];
  var say = function (field, ok, text) {
    tally(field, ok);
    if (ok === false || process.env.VERBOSE) out.push((ok === null ? '  info ' : ok ? '  ok   ' : '  DIFF ') + field + ': ' + text);
  };
  var x = energyLine(S, game, null, null);
  var a = x.a, asnap = x.asnap, snap = x.snap;

  // --- exact, from the save alone
  say('stage', a.stage === st.stage, 'port ' + a.stage + ', ref ' + st.stage);
  var test = S.asc.warpTest(asnap);
  say('test passes', test.passes === st.test.passes, 'port ' + test.passes + ', ref ' + st.test.passes);
  say('test need (1e-12)', rel(test.need, st.test.need) <= 1e-12, 'port ' + test.need.toExponential(10) + ', ref ' + st.test.need);
  say('wants ascension', (a.plan !== null) === st.wants_ascension, 'port ' + (a.plan !== null) + ', ref ' + st.wants_ascension);
  var p = S.asc.plan(asnap);
  say('save_at', rel(p.saveAt, st.save_at) <= 1e-12, 'port ' + p.saveAt.toString() + ', ref ' + st.save_at);
  say('threshold', p.threshold.equals(st.threshold), 'port ' + p.threshold.toString() + ', ref ' + st.threshold);
  // halving: the round trip measured the game's own cost function against the simulator's 50,000 x factor to 3.7e-7
  say('halving (round trip 1e-6)', rel(p.halving, st.halving) <= 1e-6, 'port ' + p.halving + ', ref ' + st.halving + ', rel ' + rel(p.halving, st.halving).toExponential(2));
  // the port reads the game's own ascendCost(); the reference is the simulator's, one below the game where the game's
  // unrounded cost is just above an integer (final_nexus4: 99,319,568.047 ceils to 99,319,569)
  say('ascension cost = the game\'s', D(p.cost).equals(game.ascendCost()), 'port ' + p.cost.toString() + ', game ' + game.ascendCost().toString());
  var dc = D(p.cost).minus(D(st.ascension_cost));
  say('ascension cost vs ref (exact, or the game\'s ceil 1 above)', dc.isZero() || dc.equals(1), 'port ' + p.cost.toString() + ', ref ' + st.ascension_cost);

  // --- the game's swarmwarp numbers and the clock
  var w = snap.energy.warp;
  say('swarmwarp power (1e-12)', rel(w.power, st.swarmwarp_power) <= 1e-12, 'port ' + w.power + ', ref ' + st.swarmwarp_power);
  say('swarmwarp skip (1e-12)', rel(w.skip, st.swarmwarp_skip_s) <= 1e-12, 'port ' + w.skip + ', ref ' + st.swarmwarp_skip_s);
  var ck = st.clock;
  say('run age estimate (game clock)', Math.abs(x.r.age - ck.run_age_game_estimate_s) <= 1e-3 + 1e-12 * ck.run_age_game_estimate_s,
    'port ' + x.r.age + ', ref ' + ck.run_age_game_estimate_s);
  say('run age = exact game age (bats before the first warp)', Math.abs(x.r.age - ck.run_age_game_s) <= 1e-3 + 1e-9 * ck.run_age_game_s,
    'port ' + x.r.age + ', ref ' + ck.run_age_game_s + ' (skipped this run ' + ck.skipped_this_run_s + ' s)');
  say('skipped total (game)', Math.abs(game.session.state.skippedMillis / 1000 - ck.skipped_total_s) <= 1e-3, 'game ' + game.session.state.skippedMillis / 1000 + ', ref ' + ck.skipped_total_s);
  say('horizon given the run age', rel(x.r.horizon, D(x.r.age).times(c.config.age_multiple)) <= 1e-12 && Math.abs(ck.horizon_s - ck.run_age_game_s * c.config.age_multiple) <= 1e-6 * ck.horizon_s,
    'port ' + x.r.horizon + ', ref ' + ck.horizon_s);
  say('long-run gate', x.r.longRun.active === ck.long_run_gate_active, 'port ' + x.r.longRun.active + ', ref ' + ck.long_run_gate_active);

  // --- the energy line up to the first cast; saving; ascend now
  var e = dec.energy, rec = x.coupled, acts = e.actions;
  var first = acts.filter(function (q) { return q.type !== 'cast'; });
  var casts = acts.filter(function (q) { return q.type === 'cast'; });
  var want = first[0];
  if (e.saving_for_ascension || e.ascend_now) {
    say('saving / ascend now', rec && rec.type === 'ascensionHold' && rec.ready === !!e.ascend_now && a.hold !== null,
      'port ' + (rec && rec.type) + (rec && rec.ready ? ' ready' : '') + ', ref saving ' + e.saving_for_ascension + ' ascend ' + e.ascend_now);
  } else {
    say('not saving', !(rec && rec.type === 'ascensionHold') && a.hold === null, 'port ' + (rec && rec.type));
    if (want && want.type === 'buyNexus') say('energy: nexus', rec.type === 'buyNexus', 'port ' + rec.type);
    else if (want && want.type === 'buyMoths') say('energy: lepidoptera', rec.type === 'buyMoths' && sameCount(rec.count, want.count), 'port ' + rec.type + ' ' + (rec.count || '') + ', ref ' + want.count);
    else if (want && want.type === 'buyBats') say('energy: bats', rec.type === 'buyBats' && sameCount(rec.count, want.count), 'port ' + rec.type + ' ' + (rec.count || '') + ', ref ' + want.count);
    else if (casts.length) {
      var k = casts[0].casts;
      var one = (rec.type === 'warp' || rec.type === 'warpAfter') && rec.casts.equals(1);
      say('energy: one swarmwarp at a time', one, 'port ' + rec.type + ' casts ' + (rec.casts || '') + ' affordable ' + (rec.affordable || ''));
      say('energy: affordable = the simulator\'s cast count (it casts them all at once)', null, 'port ' + (rec.affordable || '') + ', sim casts ' + k);
    } else {
      // nothing spent by the simulator: the port neither buys nor casts
      var idle = ['nextCast', 'hold', 'save', 'mothTarget', 'batTarget'].indexOf(rec ? rec.type : 'none') >= 0 || rec === null;
      say('energy: nothing to spend', idle, 'port ' + (rec && rec.type) + ' ' + S.adv.renderEnergy(rec));
    }
  }

  // --- territory: never stops on this route; empower with a fresh memory
  var t = x.t, td = dec.territory;
  say('territory keeps hatching (no mirrors stop)', !t.mirrors && !(t.setting && t.setting.to === 0), 'port mirrors ' + t.mirrors + ', setting ' + JSON.stringify(t.setting));
  // The reference's empower test uses a meat budget of 0.9 x meat; the port's advice takes the hatchery, expansion
  // and ancestry levels it advises out of the meat first. Compared exactly with the reference's inputs (no larva
  // upgrades: the same snapshot with them hidden); the full advice is printed where it differs.
  var tsnap0 = S.terr.snapshot(game);
  var tsnapRef = Object.assign({}, tsnap0, {upgrades: tsnap0.upgrades.map(function (u) { return Object.assign({}, u, {visible: false}); })});
  var tref = S.terr.advise(tsnapRef, null, CFG), emp = tref.empower;
  say('empower advised (reference inputs)', !!emp === td.empower_advised && (!emp || emp.unit === td.cheapest_rung),
    'port ' + (emp ? emp.unit : 'none') + ', ref ' + td.empower_advised + ' (' + td.cheapest_rung + ')');
  if (!!t.empower !== td.empower_advised) say('empower in the full advice (meat after the larva upgrades it advises)', null,
    'port ' + (t.empower ? t.empower.unit : 'none') + ' after ' + t.upgrades.map(function (u) { return u.name + ' x' + u.levels; }).join(', '));

  // --- mutagen
  if (dec.mutagen) {
    var m = dec.mutagen, mut = a.mutagen;
    var steps = mut ? mut.steps : [];
    say('mutagen respec', (mut ? mut.respec : false) === m.respec_first, 'port ' + (mut ? mut.respec : false) + ', ref ' + m.respec_first);
    var portSteps = steps.filter(function (s) { return s.type !== 'respec'; });
    // Reference share purchases under 1e-9 of W are float rounding of shares bought at an earlier ascension (W past
    // 1e32: 1e16 of 1e32, 7.5e255 of 1e270); the port counts a share short by under 1e-9 of its target as held.
    var W = D(st.mutagen_held);
    ['mutantswarmwarp', 'mutantbat', 'mutantarmy', 'mutanteach'].forEach(function (mu) { if (st.mutants[mu]) W = W.plus(D(st.mutants[mu])); });
    var noise = m.steps.filter(function (r) { return r.type === 'mutants' && D(r.count).lessThan(W.times(1e-9)) && r.name !== 'mutantnexus' && r.name !== 'mutantfreq'; });
    if (noise.length) say('mutagen steps: reference rounding (under 1e-9 of W)', null, noise.map(function (r) { return r.name + ' ' + r.count; }).join(', ') + ' of W ' + W.toExponential(3));
    var refSteps = m.steps.filter(function (r) { return noise.indexOf(r) < 0; });
    var okSteps = portSteps.length === refSteps.length && refSteps.every(function (r, i) {
      var s = portSteps[i];
      if (r.type === 'unlock') return s.type === 'unlock' && s.name === r.name && sameCount(s.price, r.price);
      return s.type === 'mutants' && s.unit === r.name && sameCount(s.count, r.count);
    });
    var show = function (list) { return list.map(function (s) { return s.type === 'unlock' ? 'unlock ' + s.name + ' ' + D(s.price).toExponential(4) : s.type === 'respec' ? 'respec' : (s.unit || s.name) + ' ' + D(s.count).toExponential(6); }).join(', '); };
    say('mutagen steps', okSteps, 'port [' + show(portSteps) + '], ref [' + show(refSteps) + ']');
    // apply them in the game and run the rule again: nothing (and no respec)
    var applied = true;
    try {
      steps.forEach(function (s) {
        if (s.type === 'respec') game.respecFree();
        else if (s.type === 'unlock') game.upgrade(s.name).buy(1);
        else game.unit(s.unit).buy(s.count);
      });
    } catch (err) { applied = false; say('mutagen steps apply in the game', false, err.message); }
    if (applied) {
      var again = S.asc.warpMutagen(S.asc.snapshot(game));
      say('mutagen again (applied in the game): nothing', again === null, again ? show(again.steps) : 'nothing');
      L = G.loadSave(path.join(DIR, c.save)); game = L.game; S = services(L);   // back to the save for what follows
    }
  }

  // --- the clock: warps cast in the game, one at a time, purchases between them
  var seq = dec.warp_sequence;
  if (seq && seq.length && (name === 'cooldown_released_by_warp' || name === 'five_warps_affordable')) {
    var s0 = S.adv.snapshot(game);
    var skipMs = s0.energy.warp.skip * 1000;
    var mem = seedMemory(S.adv, s0, seq[0].tiers_before_climb, s0.gameNow + skipMs);
    var tmem = null;
    if (c.climb_without_warp) {
      var before = energyLine(S, game, mem, tmem);
      c.climb_without_warp.forEach(function (cl) {
        if (cl.tier === 1) return;
        var row = before.r.tiers.filter(function (q) { return q.name === cl.name; })[0];
        var got = outcome(row);
        // a pushed tier's row shows its push; its climb verdict is that it failed the plain test (as longrun_check)
        if (row && row.kind === 'push' && cl.outcome === 'fails' && !row.passes) got = 'fails';
        say('climb without the warp (given memory)', got === cl.outcome, cl.name + ': port ' + got + ', ref ' + cl.outcome);
      });
      mem = before.r.memory; tmem = before.t.memory;
    }
    for (var i = 0; i < seq.length; i++) {
      var sq = seq[i];
      var pre = energyLine(S, game, mem, tmem);
      var line = pre.ordered;
      say('warp ' + (i + 1) + ': one cast offered', line && (line.type === 'warp' || line.type === 'warpAfter') && line.casts.equals(1),
        'port ' + (line && line.type) + ' ' + S.adv.renderEnergy(line));
      if (i > 0) say('warp ' + (i + 1) + ': offered only once the released purchases are made', line.type === 'warp', 'port ' + line.type + ' ' + JSON.stringify(line.pending || {}));
      var g0 = S.adv.snapshot(game).gameNow;
      game.upgrade('swarmwarp').buy(1);
      var g1 = S.adv.snapshot(game).gameNow;
      say('game clock moved by one skip', Math.abs((g1 - g0) - Math.floor(skipMs)) <= 1 && Math.abs((sq.game_clock_after_s - sq.game_clock_before_s) * 1000 - skipMs) <= 1e-6 * skipMs,
        'port +' + (g1 - g0) + ' ms, ref +' + ((sq.game_clock_after_s - sq.game_clock_before_s) * 1000).toFixed(0) + ' ms');
      var post = energyLine(S, game, pre.r.memory, pre.t.memory);
      // tiers_before_climb, given the seeded memory (first warp; later warps follow the port's own purchases)
      if (i === 0) {
        Object.keys(sq.tiers_before_climb).forEach(function (n) {
          var ref = sq.tiers_before_climb[n];
          var tr = post.r.tiers.filter(function (q) { return q.name === n; })[0] || null;
          var at = post.r.memory.boughtAt[n];
          var since = at === undefined ? null : (post.snap.gameNow - at) / 1000;
          if (ref.since_last_hatch_game_s === null) {
            say('released by the warp (never hatched)', since === null || since >= 60, n + ': port since ' + since);
            return;
          }
          var payback = tr ? tr.payback.toNumber() : null;
          var share = 1 - Math.pow(0.5, Math.min(since / 60, 1e6));
          var stock = payback ? Math.min(1, since / payback) : null;
          say('since last hatch (game clock)', Math.abs(since - ref.since_last_hatch_game_s) <= 1e-3, n + ': port ' + since + ', ref ' + ref.since_last_hatch_game_s);
          say('cooldown released', (since >= 60) === ref.cooldown_released, n + ': port ' + (since >= 60) + ', ref ' + ref.cooldown_released);
          say('share released', Math.abs(share - ref.share_released) <= 1e-12, n + ': port ' + share + ', ref ' + ref.share_released);
          if (stock !== null) say('stock release (1e-9)', Math.abs(stock - ref.stock_release) <= 1e-9 * Math.max(1e-300, ref.stock_release) || stock === ref.stock_release,
            n + ': port ' + stock + ', ref ' + ref.stock_release);
        });
        sq.climb.forEach(function (cl) {
          if (cl.tier === 1) return;
          var row = post.r.tiers.filter(function (q) { return q.name === cl.name; })[0];
          var got = outcome(row);
          if (row && row.kind === 'push' && cl.outcome === 'fails' && !row.passes) got = 'fails';
          say('climb after the warp: outcome (given memory)', got === cl.outcome, cl.name + ': port ' + got + ', ref ' + cl.outcome);
          if (cl.outcome === 'buys') say('climb after the warp: count (territory purse differs)', null, cl.name + ': port ' + (row ? row.buys.toExponential(6) : '-') + ', sim ' + cl.n_sim);
        });
      }
      var released = post.r.tiers.filter(function (q) { return q.kind === 'buy'; }).map(function (q) { return q.name; });
      var cooling = post.r.tiers.filter(function (q) { return q.reason === 'cooldown'; }).map(function (q) { return q.name; });
      say('after warp ' + (i + 1) + ': no tier left in cooldown', cooling.length === 0, 'cooldown: ' + cooling.join(',') + '; buys: ' + released.join(','));
      var hold = post.ordered;
      var more = i + 1 < seq.length;
      if (more) say('after warp ' + (i + 1) + ': the next warp waits for the purchases', hold && hold.type === 'warpAfter', 'port ' + (hold && hold.type) + ' ' + S.adv.renderEnergy(hold));
      // follow the panel until the next warp is offered: a pass can reveal more (one empower per look)
      var done = {climb: 0, tips: 0, territory: 0, expansions: 0, hatcheries: 0, empowers: 0}, cur = post, passes = 0;
      while (passes < 100) {
        var d1 = follow(S, game, cur); passes++;
        Object.keys(done).forEach(function (k2) { done[k2] += d1[k2]; });
        cur = energyLine(S, game, cur.r.memory, cur.t.memory);
        if (!cur.ordered || cur.ordered.type !== 'warpAfter') break;
        if (process.env.DEBUG) console.log('pass', passes, cur.t.records.map(S.terr.render).join(' / '), '|', cur.r.tips.map(S.adv.renderTip).join(' / '));
      }
      say('after warp ' + (i + 1) + ': bought between warps (likely equal, not exact)', null,
        'port expansions ' + done.expansions + ' hatcheries ' + done.hatcheries + ' empowers ' + done.empowers + ' in ' + passes + ' pass(es) (climb rows ' + done.climb + ', tips ' + done.tips + ', territory lines ' + done.territory + '); sim expansions ' +
        sq.bought.expansions + ' hatcheries ' + sq.bought.hatcheries + ' empowers ' + JSON.stringify(sq.bought.empowers));
      mem = cur.r.memory; tmem = cur.t.memory;
    }
  }

  var diffs = out.filter(function (q) { return q.indexOf('DIFF') >= 0; }).length;
  console.log(name + ': ' + (diffs ? diffs + ' difference(s)' : 'all compared fields match') + ' | stage ' + a.stage + ', energy: ' + S.adv.renderEnergy(x.ordered));
  out.forEach(function (q) { console.log(q); });
});

console.log('\nfield                                                          match  differ  info');
var bad = 0;
order.forEach(function (f) {
  var t = totals[f];
  bad += t.differ;
  console.log((f + new Array(64).join(' ')).slice(0, 62) + ' ' + ('     ' + t.match).slice(-5) + '  ' + ('      ' + t.differ).slice(-6) + '  ' + ('    ' + t.info).slice(-4));
});
console.log(cases.length + ' cases, ' + bad + ' differences');
process.exit(bad ? 1 : 0);
