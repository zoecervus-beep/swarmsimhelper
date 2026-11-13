'use strict'

describe 'Controller: MainCtrl', ->

  # load the controller's module
  beforeEach module 'swarmApp'

  MainCtrl = {}
  scope = {}

  # Initialize the controller and a mock scope
  beforeEach inject ($controller, $rootScope) ->
    scope = $rootScope.$new()
    MainCtrl = $controller 'MainCtrl', {
      $scope: scope
    }

  it 'should attach a game to the scope', ->
    expect(!!scope.game).toBe true

  it 'sends old urls of renamed units to their current urls', inject ($controller, $rootScope, $location) ->
    for [params, path] in [
        [{tab:'meat', unit:'overmind II'}, '/tab/meat/unit/ascended']
        [{unit:'overmind VI'}, '/unit/endless']
      ]
      $location.path '/somewhere-else'
      $controller 'MainCtrl', {$scope: $rootScope.$new(), $routeParams: params}
      expect($location.path()).toBe path
