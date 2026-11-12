'use strict'

# Flash storage that never becomes ready. The real one rejects its `onReady` promise with no
# value when Flash is unavailable (always, in a headless test browser); Angular 1.6 then reports
# "Possibly unhandled rejection" on the next digest and fails the spec. Specs that compile
# directives and digest should load this module.
#
# Usage:
#   beforeEach module 'swarmApp', 'mockFlashStorage'
angular.module('mockFlashStorage', []).config ($provide) ->
  $provide.factory 'flashStorage', ($q) ->
    items = {}
    isReady: false
    onReady: $q.defer().promise # never settles
    getItem: (key) -> items[key]
    setItem: (key, val) -> items[key] = val
    removeItem: (key) -> delete items[key]
    clear: -> items = {}
