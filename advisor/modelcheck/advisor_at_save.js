// Prints the native advisor's meat-unit advice for a decoded save, at the save's own instant, as JSON.
// Usage: node advisor_at_save.js <decoded save .json> [ageMultiple]
'use strict';
var G = require('./lib/game');
var g = G.loadSave(process.argv[2]);
var a = g.get('advisor');
var cfg = process.argv[3] ? {ageMultiple: Number(process.argv[3])} : {};
var r = a.advise(a.snapshot(g.game), null, cfg);
process.stdout.write(JSON.stringify({
  header: a.renderHeader(r), age: r.age, horizon: r.horizon,
  tiers: r.tiers.map(function (t) {
    return {name: t.name, count: String(t.count), H: t.H.toNumber(), payback: t.payback.toNumber(),
      reason: t.reason, action: a.renderAction(t), buys: String(t.buys || 0)};
  }),
  tips: r.tips.map(a.renderTip)
}) + '\n');
