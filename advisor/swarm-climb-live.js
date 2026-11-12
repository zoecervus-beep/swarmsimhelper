// Swarm Simulator live climbing panel. Paste into the browser console on swarmsim.com.
// Close with the x in the panel corner, or run: swarmClimbStop()
// Hold Shift while on a unit page to put the suggested BUY amount into the game buy box.
// Settings (change in the console any time):
//   swarmClimbCfg.ageMultiple = 3    climb tiers whose break-even H is under this many x run age
//   swarmClimbCfg.share = 0.5        fraction of the lower tier to convert per minute waited
//   swarmClimbCfg.cooldown = 60      seconds to wait after hatching a unit before it is suggested again
//   swarmClimbCfg.territory = 0.10   fraction of larvae held back for territory units
//   swarmClimbCfg.moths = 4000       lepidoptera target (about 2000 if the run lasts ~4 days, 4000 for 1-2 weeks)
//   swarmClimbCfg.bank = 3           stop hatching a unit once the tier above makes this many x what larvae could
(function () {
  if (window.swarmClimbStop) window.swarmClimbStop();
  var defaults = { ageMultiple: 3, share: 0.5, territory: 0.10, cooldown: 60, bank: 3, moths: 4000 };
  var cfg = window.swarmClimbCfg = window.swarmClimbCfg || {};
  if (cfg.version !== 2) { cfg.share = defaults.share; cfg.version = 2; } // tuned default changed from 0.25
  Object.keys(defaults).forEach(function (k) { if (cfg[k] == null) cfg[k] = defaults[k]; });

  var game = angular.element(document.body).injector().get('game');
  var chain = ['drone', 'queen', 'nest', 'greaterqueen', 'hive', 'hivequeen', 'empress',
    'prophet', 'goddess', 'pantheon', 'pantheon2', 'pantheon3', 'pantheon4', 'pantheon5',
    'overmind', 'overmind2', 'overmind3', 'overmind4', 'overmind5', 'overmind6'];

  // All game math uses the game's own big-number type, so late-game values past 1e308 still work.
  var D = function (x) { return new Decimal(x == null ? 0 : x); };
  var ZERO = D(0), ONE = D(1);
  var fmtNum = function (d) {
    d = D(d);
    if (d.lessThan(1e6)) return Math.floor(d.toNumber()).toLocaleString();
    return d.toExponential(2).replace('e+', 'e');
  };
  var fmtTime = function (s) {
    s = (s && s.toNumber) ? s.toNumber() : Number(s);
    if (isNaN(s)) return '-';
    if (s < 0) s = 0;
    if (s < 90) return s.toFixed(0) + ' s';
    if (s < 5400) return (s / 60).toFixed(0) + ' min';
    if (s < 172800) return (s / 3600).toFixed(1) + ' h';
    if (s < 86400 * 730) return (s / 86400).toFixed(1) + ' d';
    if (s < 3.15e7 * 1e6) return (s / 3.15e7).toFixed(0) + ' y';
    return 'ages';
  };
  var esc = function (s) { return String(s).replace(/[&<>]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]; }); };

  // Detect purchases from the game's own "total hatched" statistic for each unit.
  var seen = {}, boughtAt = {};
  var started = Date.now();
  function lastBuyTime(name) {
    var st = (game.session.state.statistics || {}).byUnit || {};
    var total = String(st[name] ? st[name].num : 0);
    if (seen[name] === undefined) {
      seen[name] = total;
      boughtAt[name] = started - cfg.cooldown * 1000; // first suggestion is available immediately
    } else if (seen[name] !== total) {
      seen[name] = total;
      boughtAt[name] = Date.now();
      delete stockAt[name]; // re-measure the lower tier's stock right after this purchase
    }
    return boughtAt[name];
  }
  // How many purchases of a unit the lower tier can spare right now without being run down:
  // everything the lower tier has gained since you last hatched this unit, plus a slice of the
  // older stock that releases over one payback time. Fast-payback tiers release at once;
  // a slow new top tier (hives when they take hours to repay) only gets the income.
  var stockAt = {};
  function spareBuys(x, since) {
    if (stockAt[x.name] === undefined) stockAt[x.name] = x.belowCount;
    var base = stockAt[x.name];
    var gained = Decimal.max(x.belowCount.minus(base), 0);
    var payback = x.payback.toNumber();
    var release = base.times(Math.min(1, payback > 0 ? since / payback : 1));
    return gained.plus(release).dividedBy(x.cost);
  }

  // Cheapest way to end up holding N of tier j, allowing detours through higher tiers:
  // "hatch some of tier j+1, buy twin j, then hatch tier j at half price", nested as deep as it pays.
  // st[j].have is spent along the way. Returns the final cost in units of the tier below j, or null.
  function acquire(st, j, N, steps, depth) {
    for (var guard = 0; guard < 80; guard++) {
      var t = st[j];
      var need = N.minus(t.have);
      if (need.lessThanOrEqualTo(0)) return ZERO;
      var hatches = need.dividedBy(t.twin).ceil();
      var direct = hatches.times(t.cost);
      if (st[j + 1] && t.twinCost && depth < 8) {
        var trial = st.map(function (o) { return Object.assign({}, o); });
        var tsteps = [];
        var sub = acquire(trial, j + 1, trial[j].twinCost, tsteps, depth + 1); // in tier j units
        if (sub !== null && trial[j].have.greaterThanOrEqualTo(sub)) {
          trial[j].have = trial[j].have.minus(sub);
          trial[j + 1].have = trial[j + 1].have.minus(trial[j].twinCost);
          tsteps.push('twin ' + t.name + 's');
          trial[j].twin = trial[j].twin.times(2);
          trial[j].twinCost = trial[j].twinCost.times(trial[j].twinFactor);
          var via = N.minus(trial[j].have).dividedBy(trial[j].twin).ceil().times(trial[j].cost);
          if (via.lessThan(direct)) {
            for (var q = 0; q < st.length; q++) st[q] = trial[q];
            Array.prototype.push.apply(steps, tsteps);
            continue;
          }
        }
      }
      steps.push('hatch ' + fmtNum(hatches) + ' ' + t.name + (hatches.equals(1) ? '' : 's'));
      t.have = N;
      return direct;
    }
    return null;
  }

  function compute() {
    var dates = game.session.state.date;
    var age = (Date.now() - new Date(dates.restarted || dates.started).getTime()) / 1000;
    var horizon = age * cfg.ageMultiple;
    var larvae = D(game.unit('larva').count());
    var larvaRate = D(game.unit('larva').velocity());

    var top = 0;
    chain.forEach(function (name, i) { if (D(game.unit(name).count()).greaterThanOrEqualTo(1)) top = i; });
    var shown = Math.min(top + 2, chain.length - 1); // tiers listed in the panel

    // all[i - 1] describes chain[i]; every tier is loaded so twin plans can reach upward.
    var all = [];
    var tips = [];
    for (var i = 1; i < chain.length; i++) {
      var unit = game.unit(chain[i]);
      var below = game.unit(chain[i - 1]);
      var t = {
        name: unit.name, below: below.name, tier: i + 1,
        count: D(unit.count()), belowCount: D(below.count()),
        cost: D(unit.costByName[below.name].val),
        twin: D(unit.twinMult()),
        prodEach: D(unit.eachProduction()[below.name])
      };
      t.payback = t.cost.dividedBy(t.twin.times(t.prodEach)); // seconds to regrow the cost
      t.H = t.payback.times(t.tier);                            // meat break-even clock
      t.passes = t.H.lessThanOrEqualTo(horizon);
      t.waitFor = t.H.dividedBy(cfg.ageMultiple).minus(age);
      t.affordable = t.belowCount.dividedBy(t.cost);
      var twinUp = game.upgrade(unit.name + 'twin');
      var tcost = twinUp && twinUp.totalCost()[0];
      t.twinCost = tcost ? D(tcost.val) : null;                 // paid in the tier above
      t.twinFactor = tcost ? D(twinUp.cost[0].factor) : ONE;
      all.push(t);

      if (i <= shown) {
        var prodUp = game.upgrade(unit.name + 'prod');
        if (prodUp && t.count.greaterThan(0)) {
          var pc = D(prodUp.totalCost()[0].val);
          if (t.count.greaterThanOrEqualTo(pc.times(2))) tips.push('faster ' + unit.name + 's (' + fmtNum(pc) + ')');
        }
      }
    }
    // Drones are never hatched under this rule, but their production upgrade still counts.
    var droneUp = game.upgrade('droneprod');
    if (droneUp) {
      var dc = D(droneUp.totalCost()[0].val);
      if (D(game.unit('drone').count()).greaterThanOrEqualTo(dc.times(2))) tips.unshift('faster drones (' + fmtNum(dc) + ')');
    }
    var tiers = all.slice(0, shown);

    var spendable = larvaRate.times(1 - cfg.territory); // larvae per second available to the meat units
    function banksFor(x, up) {
      if (!up || !up.passes || up.count.lessThan(1)) return false;
      var madeAbove = up.count.times(up.prodEach);                         // x per second from the tier above
      var fromLarvae = spendable.times(x.twin).dividedBy(up.twin);         // x per second larvae could hatch
      return madeAbove.greaterThan(fromLarvae.times(cfg.bank));
    }
    // Larvae go to the HIGHEST tier that passes the rule first.
    // Lower tiers only get whatever larvae are left over.
    var left = larvae.times(1 - cfg.territory).floor();
    for (var j = tiers.length - 1; j >= 0; j--) {
      var x = tiers[j];
      if (!x.passes) {
        x.action = 'wait ' + fmtTime(x.waitFor); x.kind = 'wait';
      } else if (x.affordable.lessThan(1)) {
        x.action = 'need more ' + x.below + 's'; x.kind = 'wait';
      } else if (banksFor(x, all[j + 1])) {
        // The tier above already makes far more of this unit than larvae could hatch,
        // so larvae are worth more saved for the tier above than spent here.
        x.action = 'skip: bank larvae for ' + all[j + 1].name + 's'; x.kind = 'skip';
      } else {
        // The allowance builds up with time since you last hatched this unit:
        // nothing right after a purchase, cfg.share of the lower tier after a minute,
        // nearly all of it after ten minutes.
        x.hatching = true; // this tier is being climbed, even while it waits between purchases
        var since = (Date.now() - lastBuyTime(x.name)) / 1000;
        var frac = 1 - Math.pow(1 - cfg.share, since / 60);
        var spare = spareBuys(x, since); // measured every tick so income during the wait counts
        var buys = Decimal.min(left, x.affordable.times(frac), spare).floor();
        if (since < cfg.cooldown) {
          // Just bought: wait, but keep these larvae earmarked so lower tiers don't grab them.
          x.action = 'done, next in ' + fmtTime(cfg.cooldown - since); x.kind = 'wait';
          left = left.minus(Decimal.min(left, x.affordable.times(cfg.share)).floor());
        } else if (buys.greaterThanOrEqualTo(1)) {
          x.action = 'BUY ' + fmtNum(buys) + (x.twin.greaterThan(1) ? ' (x' + fmtNum(x.twin) + ' twins)' : '');
          x.kind = 'buy'; x.buys = buys; left = left.minus(buys);
        } else if (left.lessThan(1)) {
          x.action = 'skip: larvae used above'; x.kind = 'skip';
        } else {
          x.action = 'let ' + x.below + 's build up'; x.kind = 'wait';
        }
      }
    }

    // Twin upgrades only matter for a unit you are actually hatching with larvae.
    // all[k] is that unit; all[k + 1] is the unit its twin upgrade is paid in.
    for (var k = 0; k < tiers.length; k++) {
      var u = all[k], payIn = all[k + 1];
      if (!u.hatching || !payIn || !u.twinCost) continue;
      var tc = u.twinCost;
      // Rate at which u is being hatched, and what the units the twin costs would have produced.
      var uRate = u.twin.times(Decimal.min(spendable, u.count.times(u.prodEach).dividedBy(u.cost)));
      var sacrificed = tc.times(payIn.prodEach);
      if (payIn.count.greaterThanOrEqualTo(tc)) {
        // Affordable now: only worth it if doubling the hatch rate beats what those units were making.
        // Skip it once a tier above that you are climbing already makes more of u than larvae do:
        // larva-hatching of u is about to be banked, so a twin for it would be wasted. If the tier
        // above is only held for twins (not climbed), larvae keep going into u and the twin still counts.
        var aboveMakes = payIn.count.times(payIn.prodEach);
        var larvaeMake = spendable.times(u.twin).dividedBy(payIn.twin);
        if (uRate.greaterThanOrEqualTo(sacrificed) && !(payIn.passes && aboveMakes.greaterThan(larvaeMake))) tips.push('twin ' + u.name + 's (' + fmtNum(tc) + ' ' + payIn.name + 's)');
      } else if (!payIn.passes && payIn.count.lessThan(tc)) {
        // Hatch higher tiers purely to afford this twin, if the whole plan pays for itself in time.
        // The plan may itself detour upward: hatch a tier above to twin the tier you need, and so on.
        // Its cost is counted in units of u; the gain is doubling the rate at which u is hatched.
        // Only suggested once you hold twice the plan's cost, so it never takes most of your stock.
        var st = all.map(function (o) { return { name: o.name, have: o.count, twin: o.twin, cost: o.cost, twinCost: o.twinCost, twinFactor: o.twinFactor }; });
        var steps = [];
        var costInU = acquire(st, k + 1, tc, steps, 0);
        if (costInU === null) continue;
        var hatchRate = uRate;
        if (hatchRate.lessThanOrEqualTo(0)) continue;
        var twinPayback = costInU.dividedBy(hatchRate);
        if (u.count.greaterThanOrEqualTo(costInU.times(2)) && twinPayback.times(u.tier + 1).lessThan(horizon)) {
          tips.push(steps.join(' > ') + ' > twin ' + u.name + 's (pays back in ' + fmtTime(twinPayback) + ')');
        }
      }
    }
    return { age: age, horizon: horizon, larvae: larvae, larvaRate: larvaRate, tiers: tiers, tips: tips };
  }

  // Energy plan: nexus first, lepidoptera up to the target, then every point into House of Mirrors.
  // No bats: House of Mirrors ignores spell power, so bats add nothing to it.
  function energyAdvice(larvaRate) {
    var nexus = D(game.unit('nexus').count()).toNumber();
    if (!(nexus >= 1)) return null;
    var energy = D(game.unit('energy').count());
    var moths = D(game.unit('moth').count());
    var saveFor = ZERO, saving = '';
    var next = nexus < 5 ? game.upgrade('nexus' + (nexus + 1)) : null;
    if (next) {
      var need = {}, missing = [];
      next.totalCost().forEach(function (c) {
        need[c.unit.name] = D(c.val);
        if (D(c.unit.count()).lessThan(c.val)) missing.push(c.unit.name);
      });
      if (!missing.length) return 'buy nexus ' + (nexus + 1);
      // Start saving once the meat is there and the larva price is under ~5.5 hours of larva income.
      var meatReady = missing.indexOf('meat') < 0;
      var larvaNear = !need.larva || need.larva.lessThanOrEqualTo(larvaRate.times(20000));
      if (meatReady && larvaNear) {
        saveFor = need.energy || ZERO;
        saving = 'save for nexus ' + (nexus + 1) + ': ' + missing.map(function (m) {
          return fmtNum(game.unit(m).count()) + '/' + fmtNum(need[m]) + ' ' + m;
        }).join(', ');
      }
    }
    var spare = Decimal.max(energy.minus(saveFor), 0);
    if (nexus >= 4 && moths.lessThan(cfg.moths)) {
      var n = Decimal.min(D(cfg.moths).minus(moths), spare.dividedBy(10)).floor();
      var want = 'lepidoptera ' + fmtNum(moths) + '/' + fmtNum(cfg.moths);
      if (n.greaterThanOrEqualTo(1)) return 'buy ' + fmtNum(n) + ' lepidoptera (' + want + ')' + (saving ? '; then ' + saving : '');
      return saving || ('all energy into ' + want);
    }
    if (saving) return saving;
    var spell = nexus >= 5 ? ['House of Mirrors', 2500] : ['larva rush', 1600];
    var casts = spare.dividedBy(spell[1]).floor();
    if (casts.greaterThanOrEqualTo(1)) return 'cast ' + spell[0] + ' x' + fmtNum(casts);
    return 'next ' + spell[0] + ' at ' + fmtNum(spell[1]) + ' energy (have ' + fmtNum(energy) + ')';
  }

  var box = document.createElement('div');
  box.id = 'swarm-climb-panel';
  box.style.cssText = 'position:fixed;right:12px;bottom:12px;z-index:99999;background:rgba(20,20,24,.94);' +
    'color:#e8e8e8;font:12px/1.45 monospace;padding:10px 12px;border-radius:8px;max-width:460px;' +
    'box-shadow:0 2px 12px rgba(0,0,0,.5)';
  document.body.appendChild(box);

  var colors = { buy: '#7ee787', wait: '#9aa0a6', skip: '#9aa0a6' };
  function render() {
    var html;
    try {
      var d = compute();
      html = '<div style="display:flex;justify-content:space-between;gap:16px"><b>Swarm climb</b>' +
        '<span id="swarm-climb-close" style="cursor:pointer;color:#9aa0a6">x</span></div>' +
        '<div style="color:#9aa0a6">run ' + fmtTime(d.age) + ' | climb if H &lt; ' + fmtTime(d.horizon) +
        ' | larvae ' + fmtNum(d.larvae) + ' (+' + fmtNum(d.larvaRate) + '/s)</div>' +
        '<table style="border-collapse:collapse;margin-top:6px;width:100%">' +
        '<tr style="color:#9aa0a6;text-align:left"><th>unit</th><th style="padding:0 8px">owned</th><th>H</th><th style="padding-left:8px">now</th></tr>';
      for (var i = d.tiers.length - 1; i >= 0; i--) {
        var t = d.tiers[i];
        html += '<tr><td>' + esc(t.name) + '</td><td style="padding:0 8px">' + fmtNum(t.count) + '</td><td>' +
          fmtTime(t.H) + '</td><td style="padding-left:8px;color:' + colors[t.kind] +
          (t.kind === 'buy' ? ';font-weight:bold' : '') + '">' + esc(t.action) + '</td></tr>';
      }
      html += '</table><div style="color:#9aa0a6;margin-top:4px">hold Shift on a unit page to fill its BUY amount (pre-twin, same as the game box)</div>';
      try {
        var ea = energyAdvice(d.larvaRate);
        if (ea) html += '<div style="margin-top:4px;color:#79c0ff">energy: ' + esc(ea) + '</div>';
      } catch (e2) {
        html += '<div style="margin-top:4px;color:#ff7b72">energy: ' + esc(e2 && e2.message ? e2.message : e2) + '</div>';
      }
      d.tips.forEach(function (tip) {
        html += '<div style="margin-top:4px;color:#f2cc60">' + esc(tip) + '</div>';
      });
    } catch (e) {
      html = '<b>Swarm climb</b> <span id="swarm-climb-close" style="cursor:pointer">x</span><div style="color:#ff7b72">' +
        esc(e && e.message ? e.message : e) + '</div>';
    }
    box.innerHTML = html;
    var close = document.getElementById('swarm-climb-close');
    if (close) close.onclick = window.swarmClimbStop;
  }

  // Hold Shift on a unit's page to fill the game's buy box with the suggested amount.
  // Releasing Shift puts the box back to what it held before.
  var shiftHeld = false;
  var filledInput = null, valueBefore = '';
  function setBox(input, value) {
    input.value = value;
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
  }
  function restoreBox() {
    if (filledInput && document.body.contains(filledInput)) setBox(filledInput, valueBefore);
    filledInput = null;
  }
  function fillBuyBox() {
    try {
      var m = /\/unit\/([^/?#]+)/.exec(window.location.hash || window.location.pathname);
      if (!m) return;
      var unit = game.unitBySlug(decodeURIComponent(m[1]));
      var input = document.querySelector('input[ng-model="form.buyCount"]');
      if (!unit || !input) return;
      var d = compute();
      var t = null;
      d.tiers.forEach(function (x) { if (x.name === unit.name) t = x; });
      if (!t || t.kind !== 'buy' || !t.buys) return;
      var value = t.buys.toFixed(0);
      if (input.value === value) return;
      if (filledInput !== input) { filledInput = input; valueBefore = input.value; }
      setBox(input, value);
    } catch (e) { /* the panel shows errors from compute() */ }
  }
  function onKeyDown(e) { if (e.key === 'Shift' && !shiftHeld) { shiftHeld = true; fillBuyBox(); } }
  function onKeyUp(e) { if (e.key === 'Shift') { shiftHeld = false; restoreBox(); } }
  function onBlur() { shiftHeld = false; restoreBox(); }
  window.addEventListener('keydown', onKeyDown, true);
  window.addEventListener('keyup', onKeyUp, true);
  window.addEventListener('blur', onBlur);

  var timer = setInterval(function () { render(); if (shiftHeld) fillBuyBox(); }, 1000);
  window.swarmClimbStop = function () {
    restoreBox();
    window.removeEventListener('keydown', onKeyDown, true);
    window.removeEventListener('keyup', onKeyUp, true);
    window.removeEventListener('blur', onBlur);
    clearInterval(timer);
    if (box.parentNode) box.parentNode.removeChild(box);
  };
  render();
})();
