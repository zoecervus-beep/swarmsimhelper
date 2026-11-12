// Loads the real Swarm Simulator game services (CoffeeScript compiled on the fly) into plain Node,
// wired by a tiny stand-in for Angular's injector, and loads a decoded save into a real Game.
//
// Real: the v0.2 spreadsheet the game ships, util, spreadsheetutil, spreadsheet, effect, unit,
// upgrade, achievement, tab, game, session (with its own lz-string save codec), options, seedrand.
// Faked: Angular itself, $log, $rootScope, $timeout, $filter, storage, env, and mathjs (only
// math.factorial is used). The statistics service is not loaded (it only listens to events).
//
// Usage:
//   var G = require('./lib/game');
//   var g = G.loadSave('advisor/sim/example_save_14h.json');   // g.game is a real Game, at the save's time
//   G.advance(g.game, 3600);                                     // move game time forward 1 h
'use strict';
var fs = require('fs'), vm = require('vm'), path = require('path');
var coffee = require('coffee-script');

var REPO = path.resolve(__dirname, '..', '..', '..');
var COFFEE = process.env.SWARMSIM_COFFEE || path.join(REPO, 'swarmsim-coffee');

global.window = global;
global.name = '';
global.Decimal = require('decimal.js');
global._ = require('lodash');
global.LZString = require('lz-string');
global.moment = require('moment');
global.math = {factorial: function (n) { var r = 1; for (var i = 2; i <= n; i++) r *= i; return r; }};
global.$ = function () { return {attr: function () { return 'x'; }, 0: {}}; };
Math.seedrandom = require('seedrandom');

var registry = {};
function reg(kind) { return function (name, val) { registry[name] = {kind: kind, val: val}; return mod; }; }
var mod = {constant: reg('value'), value: reg('value'), factory: reg('factory'), service: reg('factory'),
  config: function () { return mod; }, run: function () { return mod; }, directive: function () { return mod; },
  filter: function () { return mod; }, controller: function () { return mod; }};
global.angular = {module: function () { return mod; }};

function loadCoffee(file) {
  vm.runInThisContext(coffee.compile(fs.readFileSync(file, 'utf8')), {filename: file});
}
vm.runInThisContext(fs.readFileSync(path.join(COFFEE, 'app/scripts/spreadsheetpreload/v0.2.js'), 'utf8'));
['util', 'spreadsheetutil', 'spreadsheet', 'effect', 'unit', 'upgrade', 'achievement', 'tab', 'game',
  'session', 'options', 'seedrand', 'advisor'].forEach(function (f) {
  loadCoffee(path.join(COFFEE, 'app/scripts/services', f + '.coffee'));
});

var noop = function () {};
var VERSION = JSON.parse(fs.readFileSync(path.join(COFFEE, 'package.json'))).version;
function fakes() {
  var store = {};
  return {
    $log: {debug: noop, info: noop, warn: noop, error: noop},
    $rootScope: {$broadcast: noop, $emit: noop, $on: noop},
    $timeout: noop, $animate: {}, $filter: function () { return String; },
    $location: {search: function () { return {}; }},
    env: {saveId: 'modelcheck', spreadsheetKey: 'v0.2', isDebugEnabled: true},
    version: VERSION, saveId: 'modelcheck', isKongregate: function () { return false; },
    storage: {setItem: function (k, v) { store[k] = v; }, getItem: function (k) { return store[k]; }},
    UNIT_LIMIT: '1e100000'
  };
}
function params(fn) {
  return fn.toString().match(/^function\s*[^(]*\(([^)]*)\)/)[1].split(',')
    .map(function (s) { return s.trim(); }).filter(Boolean);
}
// A fresh injector: every call gives a new set of service instances (a new session, a new game).
function injector() {
  var cache = {}, fk = fakes();
  function get(name) {
    if (name === '$injector') return {get: get};
    if (fk.hasOwnProperty(name)) return fk[name];
    if (cache.hasOwnProperty(name)) return cache[name];
    var r = registry[name];
    if (!r) throw new Error('unknown injectable ' + name);
    if (r.kind === 'value') return (cache[name] = r.val);
    return (cache[name] = r.val.apply(null, params(r.val).map(get)));
  }
  return get;
}

// Encode a decoded save the way the game exports it, then import it with the game's own codec.
function encode(json) {
  return btoa(VERSION) + '|' + btoa('Cheater :(\n\n') + LZString.compressToBase64(JSON.stringify(json));
}
function loadSave(file, edit) {
  var json = JSON.parse(fs.readFileSync(path.resolve(file), 'utf8'));
  if (edit) edit(json);
  var get = injector();
  var session = get('session');
  session.importSave(encode(json), true);
  var Game = get('Game');
  var game = new Game(session);
  // The constructor ticks to the real clock; put the game back at the moment the save was reified,
  // so counts are exactly the saved ones. Later time moves only through advance().
  game.now = new Date(session.state.date.reified.getTime());
  game.cache.onUpdate();
  return {game: game, get: get, session: session};
}
// Move game time forward by `secs` seconds, the way the game's own specs do (game.tick with a later date).
function advance(game, secs) {
  game.tick(new Date(game.now.getTime() + Math.round(secs * 1000)));
}
module.exports = {loadSave: loadSave, advance: advance, injector: injector, encode: encode,
  loadCoffee: loadCoffee, COFFEE: COFFEE, REPO: REPO};
