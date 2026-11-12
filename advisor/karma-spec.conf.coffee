# Run the swarmsim-coffee Karma unit suite with only some spec files.
# Wraps the upstream config (swarmsim-coffee/test/karma-unit.conf.coffee)
# without changing it. From swarmsim-coffee/:
#
#   SPEC=test/spec/services/unit.coffee yarn karma start ../advisor/karma-spec.conf.coffee
#
# SPEC is a file or glob relative to swarmsim-coffee/ (default: all specs).
# Mocks, app scripts, libraries and served fixtures (including
# ../advisor/sim/example_save_14h.json for the advisor spec) come from the upstream
# files list unchanged; only the 'test/spec/**/*.coffee' entry is replaced.
path = require 'path'
upstream = require '../swarmsim-coffee/test/karma-unit.conf.coffee'

module.exports = (config) ->
  upstream config
  spec = process.env.SPEC or 'test/spec/**/*.coffee'
  config.basePath = path.resolve __dirname, '../swarmsim-coffee'
  config.files = config.files.map (f) -> if f is 'test/spec/**/*.coffee' then spec else f
  config.singleRun = true
  config.autoWatch = false
