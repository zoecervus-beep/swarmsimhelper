// How the game keeps time across a swarmwarp (advisor/NO-MIRRORS.md, "Game time"): casts one swarmwarp on the 20.1 h
// save (nexus 5, energy 100,000, 2,000 bats, warp and bat mutations at 1e10) and reports game.now, game.skippedMillis,
// session.state.skippedMillis, the run's dates and the swarmwarp count, then the same after an export and re-import of
// the save, a second cast, and an ascension.
// Usage: node swarmwarp_clock.js     (prints JSON)
'use strict';
var path = require('path');
var G = require('./lib/game');
var SAVE = path.join(__dirname, '..', 'sim', 'example_save_20h.json');
var S = function (d) { return d === undefined || d === null ? null : String(d); };
function edit(j) {
  Object.assign(j.unittypes, {nexus: '5', energy: '100000', bat: '2000', moth: '30000', mutantswarmwarp: '1e10', mutantbat: '1e10'});
  Object.assign(j.upgrades, {nexus5: '1', mutateswarmwarp: '1', mutatebat: '1', clonearmy: '400'});   // 400 casts: the ascension costs ~1
}
function look(g, tag) {
  var st = g.session.state;
  return {at: tag, now: g.now.toISOString(), skippedMillis_game: g.skippedMillis, skippedMillis_saved: st.skippedMillis,
    restarted: new Date(st.date.restarted).toISOString(), reified: new Date(st.date.reified).toISOString(),
    swarmwarp_casts: g.upgrade('swarmwarp').count().toNumber(), drones: S(g.unit('drone').count()), energy: S(g.unit('energy').count()),
    warp_power: S(g.upgrade('swarmwarp').effect[0].power()), warp_seconds: S(g.upgrade('swarmwarp').effect[0].output()),
    run_age_wall_s: (g.now.getTime() - new Date(st.date.restarted).getTime()) / 1000, ascensions: S(g.unit('ascension').count())};
}
var out = [];
var L = G.loadSave(SAVE, edit), g = L.game;
out.push(look(g, 'loaded'));
g.upgrade('swarmwarp').buy(1);
out.push(look(g, 'after one swarmwarp'));
G.advance(g, 60);
out.push(look(g, 'after 60 s of wall time'));
// export and re-import (a reload)
var enc = L.session.exportSave();
var get = G.injector(), session = get('session'); session.importSave(enc, true);
var Game = get('Game'), g2 = new Game(session); g2.now = new Date(session.state.date.reified.getTime()); g2.cache.onUpdate();
out.push(look(g2, 'after export and re-import'));
g2.upgrade('swarmwarp').buy(1);
out.push(look(g2, 'after a second swarmwarp'));
g2.ascend();
out.push(look(g2, 'after ascending'));
process.stdout.write(JSON.stringify(out, null, 1) + '\n');
