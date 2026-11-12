// Runs Jasmine specs from swarmsim-coffee/test/spec against the real game services in Node, using the
// same stand-in injector as lib/game.js (Angular's module()/inject() are mimicked). This is not Karma.
//
// Usage: node run_specs.js test/spec/services/advisorfacts.coffee [more spec files, relative to swarmsim-coffee]
'use strict';
var path = require('path');
var G = require('./lib/game');

var current = null;
global.module = function () { return function () { current = G.injector(); }; };
global.inject = function (fn) {
  var names = fn.toString().match(/^function\s*[^(]*\(([^)]*)\)/)[1].split(',')
    .map(function (s) { return s.trim(); }).filter(Boolean);
  return function () { fn.apply(null, names.map(function (n) { return current(n.replace(/^_(.*)_$/, '$1')); })); };
};

var Jasmine = require('jasmine');
var j = new Jasmine();
j.env.clearReporters();
var counts = {passed: 0, failed: 0, pending: 0};
j.addReporter({
  specDone: function (r) {
    counts[r.status] = (counts[r.status] || 0) + 1;
    console.log((r.status === 'passed' ? 'ok   ' : r.status === 'pending' ? 'pend ' : 'FAIL ') + r.fullName);
    r.failedExpectations.forEach(function (f) { console.log('      ' + f.message); });
  },
  jasmineDone: function () {
    console.log(JSON.stringify(counts));
    process.exitCode = counts.failed ? 1 : 0;
  }
});
process.argv.slice(2).forEach(function (f) { G.loadCoffee(path.resolve(G.COFFEE, f)); });
j.execute();
