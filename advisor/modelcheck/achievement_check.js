// Checks how the game evaluates every achievement, with the real AchievementsListener (achievement.coffee).
// For each one, starting from the 20.1 h save with that achievement removed:
//   unit:    statistics twinnum (units bought) just below and at the threshold, then achieveUnit()
//            (the 'ascension' count is checked the way the ascend command does: raw count, achieveUnit(name, true))
//   upgrade: upgrade level just below and at the threshold, then achieveUpgrade()
//   event:   the event emitted with a wrong and the right parameter, through the listener's own $on handlers
// Also prints the description as the game renders it ($REQUIRED filled in) and whether it is masked now.
// Usage: node achievement_check.js     (prints JSON)
'use strict';
var path = require('path');
var G = require('./lib/game');
var SAVE = path.join(__dirname, '..', 'sim', 'example_save_20h.json');

function setup(name, edit) {
  var handlers = {};
  var scope = {$on: function (ev, fn) { (handlers[ev] = handlers[ev] || []).push(fn); }};
  var loaded = G.loadSave(SAVE, function (j) { delete j.achievements[name]; if (edit) edit(j); });
  var g = loaded.game;
  var L = new (loaded.get('AchievementsListener'))(g, scope);
  return {g: g, L: L, emit: function (ev, param) { (handlers[ev] || []).forEach(function (fn) { fn({}, param); }); }};
}
var out = {};
var base = G.loadSave(SAVE).game;
base.achievementlist().forEach(function (a) {
  var req = a.type.requires[0] || {}, r = {points: a.type.points, label: a.type.label, masked: a.isMasked(),
    earnedInSave: a.isEarned(), event: req.event || null,
    visible: (a.type.visible || []).map(function (v) {
      var n = v.unittype ? (v.unittype.name || v.unittype) : (v.upgradetype.name || v.upgradetype);
      return {what: n, val: String(v.val)}; })};
  try { r.description = a.description(); } catch (e) { r.description = a.type.description; }
  var val = req.val;
  var UN = req.unittype ? (req.unittype.name || req.unittype) : null, UP = req.upgradetype ? (req.upgradetype.name || req.upgradetype) : null;
  if (UN) {
    var unit = base.unit(UN), raw = !!unit.unittype.unbuyable;
    var v = new Decimal(val), lo = v.lessThanOrEqualTo(1) ? new Decimal(0) : v.times(0.999).floor();
    var test = function (x) {
      var t = setup(a.name, function (j) {
        if (raw) j.unittypes[UN] = String(x);
        else { j.statistics.byUnit[UN] = j.statistics.byUnit[UN] || {clicks: 0, num: '0'};
          j.statistics.byUnit[UN].twinnum = String(x); j.unittypes[UN] = '0'; }
      });
      t.L.achieveUnit(UN, raw);
      return t.g.achievement(a.name).isEarned();
    };
    r.kind = raw ? 'unit count (raw, checked when ascending)' : 'units bought (statistics twinnum)';
    r.unit = UN; r.threshold = String(val); r.belowEarns = test(lo); r.atEarns = test(v);
    // owning the units without having bought them must not count
    if (!raw) {
      var t2 = setup(a.name, function (j) {
        j.statistics.byUnit[UN] = j.statistics.byUnit[UN] || {clicks: 0, num: '0'};
        j.statistics.byUnit[UN].twinnum = String(lo); j.unittypes[UN] = String(v.times(10));
      });
      t2.L.achieveUnit(UN);
      r.ownedNotBoughtEarns = t2.g.achievement(a.name).isEarned();
    }
  } else if (UP) {
    var testU = function (x) {
      var t = setup(a.name, function (j) { j.upgrades[UP] = String(x); });
      t.L.achieveUpgrade(UP);
      return t.g.achievement(a.name).isEarned();
    };
    r.kind = 'upgrade level'; r.upgrade = UP; r.threshold = String(val);
    r.belowEarns = testU(Number(val) - 1); r.atEarns = testU(Number(val));
  } else if (req.event) {
    r.kind = 'event'; r.param = val || null;
    var p = val ? JSON.parse(val) : null, wrong = p ? {success: false, name: 'nope'} : undefined;
    var t = setup(a.name);
    if (p) { t.emit(req.event, wrong); r.wrongParamEarns = t.g.achievement(a.name).isEarned(); }
    t.emit(req.event, p || {});
    r.atEarns = t.g.achievement(a.name).isEarned();
  } else {
    r.kind = 'none';
  }
  out[a.name] = r;
});
process.stdout.write(JSON.stringify({pointsPossible: base.achievementPointsPossible, pointsInSave: base.achievementPoints(), achievements: out}) + '\n');
