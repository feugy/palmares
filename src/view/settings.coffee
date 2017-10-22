View = require '../view/view'
{safeLoad} = require 'js-yaml'
{readFileSync} = require 'fs-extra'
{confKey, saveKey} = require '../util/common'

seasonRegexp = /^(\d+)\/(\d+)$/

# Parse year from season, taking the first number
#
# @param season [String] the inputed season
# @return false if season is invalid, the current year otherwise
parseYear = (season) ->
  return false unless seasonRegexp.test season
  parsed = season.match seasonRegexp
  return false unless +parsed[1] is +parsed[2]-1
  +parsed[1]

# Displays season from configuration year
#
# @param year [Number] current year
# @return displayed season
displaySeason = (year) ->
  "#{year}/#{year+1}"

module.exports = class SettingsView extends View

  # template used to render view
  template: require '../../template/settings.html'

  # i18n object for rendering
  i18n: safeLoad readFileSync "#{__dirname}/../../nls/common.yml"

  # proxy setting, read from configuration
  proxy: ''

  # current season, read from configuration
  season: ''

  # Season validation status
  seasonValid: true

  # Settings View constructor
  # Immediately renders the view
  #
  # @return the built view
  constructor: ->
    super className: 'settings'
    @proxy = confKey 'proxy', ''
    @season = displaySeason confKey 'year'
    @render()
    # bind season validation on modification
    inputSeason = @$el.find '.season'
    inputSeason.on 'keyup', =>
      @seasonValid = parseYear(@_getSeason()) isnt false
      inputSeason.toggleClass 'error', not @seasonValid

  # save modified values into configuration, if valid
  save: =>
    # save new configuration values
    saveKey 'proxy', @$el.find('.proxy').val().trim() or undefined
    saveKey 'year', parseYear @_getSeason() if @seasonValid

  # extract season value
  #
  # @return the current inputed season value
  _getSeason: =>
    @$el.find('.season').val().trim()