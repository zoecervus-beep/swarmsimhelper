'use strict'

###*
 # @ngdoc service
 # @name swarmApp.advisorView
 # @description
 # Turns the climbing advisor's records (reason codes and numbers) into what the panel and the
 # buy-box button show: the game's unit labels, its number format and links to unit pages.
 # The advisor's own render* functions are the reference wording and the fallback for any record
 # this doesn't know.
###
angular.module('swarmApp').factory 'advisorView', (game, advisor, $filter) ->
  bignum = (n, maxSmall=0) -> $filter('bignum')(n, maxSmall)
  time = advisor.formatTime

  unitOf = (name) ->
    try
      return game.unit name
    catch e
      return null
  label = (name) -> unitOf(name)?.unittype?.label ? name
  plural = (name) -> unitOf(name)?.unittype?.plural ? name
  # Link to a unit's page, or null if the unit doesn't exist or isn't visible yet (the game
  # redirects away from hidden units).
  href = (name) ->
    u = unitOf name
    if u?.tab? and u.isVisible()
      return '#' + u.url()
    return null
  upgradeLabel = (name, fallback) ->
    try
      return game.upgrade(name)?.type?.label ? fallback
    catch e
      return fallback

  action = (t) ->
    switch t.reason
      when 'tooSlow' then 'wait ' + time(t.waitSeconds)
      when 'needBelow' then 'need more ' + plural(t.below)
      when 'bank' then 'skip: bank larvae for ' + plural(t.bankFor)
      when 'cooldown' then 'done, next in ' + time(t.waitSeconds)
      when 'buy'
        ret = 'buy ' + bignum(t.buys)
        if t.twin.greaterThan 1
          ret += ' (×' + bignum(t.twin) + ' twins)'
        ret
      when 'larvaeUsedAbove' then 'skip: larvae used above'
      when 'buildUp' then 'let ' + plural(t.below) + ' build up'
      else advisor.renderAction t

  step = (s) ->
    if s.type == 'twin'
      return upgradeLabel s.unit + 'twin', 'twin ' + plural(s.unit)
    return 'hatch ' + bignum(s.count) + ' ' + (if s.count.equals(1) then label(s.unit) else plural(s.unit))

  tip = (t) ->
    text = switch t.type
      when 'faster'
        'buy ' + upgradeLabel(t.unit + 'prod', 'faster ' + plural(t.unit)) + ' (' + bignum(t.cost) + ' ' + plural(t.unit) + ')'
      when 'twin'
        'buy ' + upgradeLabel(t.unit + 'twin', 'twin ' + plural(t.unit)) + ' (' + bignum(t.cost) + ' ' + plural(t.payIn) + ')'
      when 'twinPlan'
        steps = (step(s) for s in t.steps)
        steps.push upgradeLabel(t.unit + 'twin', 'twin ' + plural(t.unit))
        'plan: ' + steps.join(' › ') + ' (pays back in ' + time(t.payback) + ')'
      else advisor.renderTip t
    return {type: t.type, unit: t.unit, text: text, href: href(t.unit)}

  saving = (rec) ->
    'save for nexus ' + rec.level + ': ' + ((bignum(m.have) + '/' + bignum(m.need) + ' ' + plural(m.unit)) for m in rec.missing).join(', ')

  energy = (rec) ->
    if not rec?
      return null
    link = 'energy'
    switch rec.type
      when 'buyNexus'
        text = 'buy nexus ' + rec.level
        link = 'nexus'
      when 'save'
        text = saving rec
        link = 'nexus'
      when 'buyMoths'
        text = 'buy ' + bignum(rec.count) + ' ' + plural('moth') + ' (' + bignum(rec.moths) + '/' + bignum(rec.target) + ')'
        if rec.then
          text += '; then ' + saving(rec.then)
        link = 'moth'
      when 'mothTarget'
        text = 'all energy into ' + plural('moth') + ' (' + bignum(rec.moths) + '/' + bignum(rec.target) + ')'
        link = 'moth'
      when 'cast'
        text = 'cast ' + rec.label + ' \u00d7' + bignum(rec.casts)
      when 'nextCast'
        text = 'next ' + rec.label + ' at ' + bignum(rec.cost) + ' energy (have ' + bignum(rec.energy) + ')'
      else
        text = advisor.renderEnergy rec
    return {type: rec.type, text: text, href: href(link)}

  errorText = (e) -> String(e?.message ? e)

  # The text the "use suggested" button writes into the buy box: a plain integer below 1e21, an
  # exact exponent form above (1.2345e+400). Both parse back to the same count through
  # `parseNumber`; the exponent form keeps huge counts short.
  buyCountString = (count) ->
    count = new Decimal count
    if count.abs().lessThan '1e21'
      return count.toFixed 0
    return count.toExponential()

  # Every digit, with thousands separators, for the button's tooltip.
  exactText = (count) ->
    if count.lessThan '1e21'
      return count.toFixed(0).replace /\B(?=(\d{3})+(?!\d))/g, ','
    return count.toExponential()

  # From `advisor.current()`'s {advice, error} to the panel's view model. Never throws.
  panel = (cur) ->
    if not cur?
      return null
    if cur.error?
      return {error: errorText cur.error}
    try
      r = cur.advice
      rows = for t in r.tiers by -1 # highest tier first
        name: t.name
        label: label t.name
        href: href t.name
        count: t.count
        H: time t.H
        kind: t.kind
        reason: t.reason
        action: action t
      buys = _.filter rows, (row) -> row.kind == 'buy'
      return {
        error: null
        header:
          age: time r.age
          horizon: time r.horizon
          larvae: bignum r.larvae
          larvaRate: bignum r.larvaRate, 1
        rows: rows
        tips: (tip(t) for t in r.tips)
        energy: energy r.energy
        summary: if buys.length then (buys[0].label + ': ' + buys[0].action) else null
      }
    catch e
      return {error: errorText e}

  # The buy-box button's view for one unit, or null when the advisor doesn't list it.
  suggestion = (cur, unitName) ->
    t = advisor.suggestionFor cur?.advice, unitName
    if not t?
      return null
    if t.kind == 'buy' and t.buys.greaterThanOrEqualTo 1
      return {
        buys: t.buys
        buyCount: buyCountString t.buys
        amount: bignum t.buys
        exact: exactText t.buys
        noun: if t.buys.equals(1) then label(unitName) else plural(unitName)
        reason: null
      }
    return {buys: null, reason: action t}

  return {
    panel: panel
    suggestion: suggestion
    buyCountString: buyCountString
    action: action
    tip: tip
    energy: energy
  }

# Re-run the advice at most this often; views are refreshed from the game's own `tick` event.
angular.module('swarmApp').constant 'ADVISOR_REFRESH_MILLIS', 1000

###*
 # @ngdoc directive
 # @name swarmApp.directive:advisorPanel
 # @description
 # The climbing advisor's panel: run age and larvae, a table of meat tiers with what to do with
 # each, upgrade tips and the energy line. Collapsible; hidden while the advisor is off.
###
angular.module('swarmApp').directive 'advisorPanel', ($rootScope, $log, advisor, advisorView, options, ADVISOR_REFRESH_MILLIS) ->
  restrict: 'E'
  scope: {}
  template: """
<div class="panel panel-default advisor-panel" ng-if="enabled()">
  <div class="panel-heading">
    <h4 class="panel-title">
      <a href="javascript:" ng-click="toggle()" aria-controls="advisor-panel-body" aria-expanded="{{!collapsed()}}">
        <span class="glyphicon" ng-class="collapsed() ? 'glyphicon-chevron-right' : 'glyphicon-chevron-down'" aria-hidden="true"></span>
        Climbing advisor
      </a>
      <small ng-if="collapsed() && view.summary" class="advisor-summary titlecase">&mdash; {{view.summary}}</small>
    </h4>
  </div>
  <div id="advisor-panel-body" ng-if="!collapsed()">
    <div class="panel-body text-danger advisor-error" ng-if="view.error">
      <span class="glyphicon glyphicon-exclamation-sign" aria-hidden="true"></span> Advisor error: {{view.error}}
    </div>
    <div class="panel-body text-muted" ng-if="!view">Working it out&hellip;</div>
    <div class="panel-body small advisor-header" ng-if="view.header">
      Run {{view.header.age}} &middot; climb if H &lt; {{view.header.horizon}} &middot;
      <span class="text-nowrap">{{view.header.larvae}} larvae (+{{view.header.larvaRate}}/sec)</span>
    </div>
    <div class="table-responsive" ng-if="view.rows">
      <table class="table table-condensed advisor-table">
        <thead><tr>
          <th>Unit</th>
          <th class="text-right">Owned</th>
          <th class="text-right" title="Break-even time: hatching this leaves you with less meat than not hatching until about this long afterward">H</th>
          <th>Now</th>
        </tr></thead>
        <tbody>
          <tr ng-repeat="row in view.rows track by row.name" ng-class="{success: row.kind == 'buy'}" class="advisor-row advisor-{{row.kind}}">
            <td class="titlecase text-nowrap"><a ng-if="row.href" ng-href="{{row.href}}">{{row.label}}</a><span ng-if="!row.href">{{row.label}}</span></td>
            <td class="text-right text-nowrap">{{row.count|bignum:0}}</td>
            <td class="text-right text-nowrap">{{row.H}}</td>
            <td ng-class="{'text-muted': row.kind != 'buy'}"><strong ng-if="row.kind == 'buy'">{{row.action}}</strong><span ng-if="row.kind != 'buy'">{{row.action}}</span></td>
          </tr>
        </tbody>
      </table>
    </div>
    <ul class="list-group" ng-if="view.tips.length || view.energy">
      <li class="list-group-item advisor-tip" ng-repeat="tip in view.tips">
        <span class="glyphicon glyphicon-circle-arrow-up" aria-hidden="true"></span>
        <a ng-if="tip.href" ng-href="{{tip.href}}">{{tip.text}}</a><span ng-if="!tip.href">{{tip.text}}</span>
      </li>
      <li class="list-group-item advisor-energy text-info" ng-if="view.energy">
        <span class="glyphicon glyphicon-flash" aria-hidden="true"></span> Energy:
        <a ng-if="view.energy.href" ng-href="{{view.energy.href}}">{{view.energy.text}}</a><span ng-if="!view.energy.href">{{view.energy.text}}</span>
      </li>
    </ul>
  </div>
</div>
"""
  link: (scope, element, attrs) ->
    scope.view = null
    scope.enabled = -> options.advisorEnabled()
    scope.collapsed = -> options.advisorCollapsed()
    scope.toggle = -> options.advisorCollapsed not options.advisorCollapsed()

    lastAt = null
    # Called on every game tick (each animation frame); `advisor.current` re-runs the rules at most
    # once per ADVISOR_REFRESH_MILLIS and the view is only rebuilt when it did. Runs while collapsed
    # too, so purchases keep being noticed. Never throws: an exception here would stop the game loop.
    scope.refresh = ->
      try
        if not options.advisorEnabled()
          scope.view = null
          lastAt = null
          return
        cur = advisor.current ADVISOR_REFRESH_MILLIS
        if cur.at != lastAt or not scope.view?
          lastAt = cur.at
          scope.view = advisorView.panel cur
      catch e
        $log.warn 'advisor panel', e
        scope.view = {error: String(e?.message ? e)}
      return
    scope.refresh()
    scope.$on '$destroy', $rootScope.$on 'tick', scope.refresh

###*
 # @ngdoc directive
 # @name swarmApp.directive:advisorSuggest
 # @description
 # Beside the buy box: when the climbing advisor suggests hatching this unit, a button that puts
 # the suggested amount into the box. It only fills the box; buying is still the game's button.
###
angular.module('swarmApp').directive 'advisorSuggest', ($rootScope, $log, advisor, advisorView, options, ADVISOR_REFRESH_MILLIS) ->
  restrict: 'E'
  scope:
    unit: '='
    form: '='
  template: """
<div class="advisor-suggest form-group" ng-if="view">
  <button type="button" class="btn btn-sm" ng-class="view.buys ? 'btn-success' : 'btn-default'" ng-disabled="!view.buys" ng-click="use()"
      title="{{view.buys ? 'Climbing advisor: put ' + view.exact + ' in the box. You still choose when to buy.' : 'The climbing advisor has no suggestion for this unit right now.'}}">
    <span class="glyphicon glyphicon-arrow-up" aria-hidden="true"></span>
    Use suggested<span ng-if="view.buys">: {{view.amount}} {{view.noun}}</span>
  </button>
  <small class="text-muted" ng-if="!view.buys">Advisor: {{view.reason}}</small>
</div>
"""
  link: (scope, element, attrs) ->
    scope.view = null
    lastAt = null
    scope.refresh = ->
      try
        if not (options.advisorEnabled() and scope.unit? and scope.unit.name in advisor.CHAIN)
          scope.view = null
          lastAt = null
          return
        cur = advisor.current ADVISOR_REFRESH_MILLIS
        if cur.at != lastAt
          lastAt = cur.at
          scope.view = advisorView.suggestion cur, scope.unit.name
      catch e
        $log.warn 'advisor suggestion', e
        scope.view = null
      return
    scope.use = ->
      if scope.view?.buys and scope.form?
        scope.form.buyCount = scope.view.buyCount
    scope.refresh()
    scope.$on '$destroy', $rootScope.$on 'tick', scope.refresh

###*
 # @ngdoc directive
 # @name swarmApp.directive:advisorOptions
 # @description
 # Climbing advisor settings on the options page.
###
angular.module('swarmApp').directive 'advisorOptions', ($log, options, advisor, ADVISOR_SETTINGS) ->
  restrict: 'E'
  scope: {}
  template: """
<div class="form-group advisor-options">
  <label class="control-label">
    <span class="glyphicon glyphicon-education"></span> Climbing advisor
    <input type="checkbox" ng-model="form.enabled" ng-change="setEnabled(form.enabled)">
  </label>
  <p>Shows a panel beside your unit list saying which meat units to hatch and how many, which upgrades are worth buying, and what to do with energy, plus a "use suggested" button by the hatch box. It only advises: nothing is bought unless you press the game's own buttons.</p>
  <div ng-if="form.enabled" class="well well-sm">
    <div class="form-group" ng-repeat="field in fields" ng-class="{'has-error': !!errors[field.key], 'has-warning': !errors[field.key] && !!notes[field.key]}">
      <label class="control-label" for="advisor-{{field.key}}">{{field.label}}</label>
      <input type="text" inputmode="decimal" class="form-control input-sm advisor-setting" id="advisor-{{field.key}}" style="max-width:10em"
        ng-model="form.values[field.key]" ng-change="setValue(field.key)" ng-blur="resync(field.key)">
      <p class="help-block">{{field.help}} Default {{defaults[field.key]}}.</p>
      <p class="help-block" ng-if="errors[field.key]">{{errors[field.key]}}</p>
      <p class="help-block" ng-if="!errors[field.key] && notes[field.key]">{{notes[field.key]}}</p>
    </div>
    <button type="button" class="btn btn-default btn-sm" ng-click="reset()">Reset advisor settings to defaults</button>
  </div>
</div>
"""
  link: (scope, element, attrs) ->
    scope.defaults = ADVISOR_SETTINGS.defaults
    scope.fields = [
      {key: 'ageMultiple', label: 'Climb multiple', help: "Start hatching a tier once its break-even time (H) is under this many times the age of your run. Use 5 for multi-day runs."}
      {key: 'share', label: 'Share per minute', help: "Fraction of the tier below that may be converted for each minute since you last hatched a unit (0.5 = half)."}
      {key: 'cooldown', label: 'Cooldown (seconds)', help: "After you hatch a unit, wait this many seconds before suggesting it again."}
      {key: 'bank', label: 'Banking threshold', help: "Stop hatching a unit, and save its larvae, once the tier above already makes this many times what larvae could."}
      {key: 'territory', label: 'Territory share', help: "Fraction of larvae held back for territory units (0.10 = 10%). Set to 0 once House of Mirrors is casting."}
      {key: 'moths', label: 'Lepidoptera target', help: "How many lepidoptera to buy with energy before House of Mirrors. 0 for runs under about two days; 2,000 to 4,000 for about four days; 4,000 for a week or two."}
    ]
    limits = ADVISOR_SETTINGS.limits

    scope.form = {enabled: options.advisorEnabled(), values: {}}
    scope.errors = {}
    scope.notes = {}
    syncAll = ->
      config = options.advisorConfig()
      for key, val of config
        scope.form.values[key] = String val
      scope.errors = {}
      scope.notes = {}
    syncAll()

    scope.setEnabled = (enabled) ->
      options.advisorEnabled !!enabled
      advisor.invalidate()

    # Save one setting from its text box. Bad input shows an error and leaves the stored value as it was.
    scope.setValue = (key) ->
      text = scope.form.values[key]
      delete scope.errors[key]
      delete scope.notes[key]
      limit = limits[key]
      range = "#{limit.min} to #{limit.max}"
      if not text? or String(text).trim() == '' or not _.isFinite Number text
        scope.errors[key] = "Enter a number from #{range}. Still using #{options.advisorSetting key}."
        return
      try
        stored = options.advisorSetting key, String(text).trim()
      catch e
        $log.debug 'advisor setting rejected', key, text, e
        scope.errors[key] = "Enter a number from #{range}. Still using #{options.advisorSetting key}."
        return
      advisor.invalidate()
      if stored != Number text
        scope.notes[key] = "Saved as #{stored} (allowed: #{range}#{if limit.integer then ', whole numbers' else ''})."
      return

    # Leaving a box shows what is actually stored.
    scope.resync = (key) ->
      scope.form.values[key] = String options.advisorSetting key
      delete scope.errors[key]
      delete scope.notes[key]

    scope.reset = ->
      options.resetAdvisorConfig()
      advisor.invalidate()
      syncAll()
