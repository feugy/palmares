'use strict'

View = require '../view/view'
{confKey, saveKey} = require '../util/common'

module.exports = class SettingsView extends View

  # template used to render view
  template: require '../../template/settings.html'

  # i18n object for rendering
  i18n: require '../../nls/common.yml'

  # proxy setting, read from configuration
  proxy: ''

  # Settings View constructor
  # Immediately renders the view
  #
  # @return the built view
  constructor: ->
    super className: 'settings'
    @proxy = confKey 'proxy', ''
    @render()

  # save modified values into configuration
  save: =>
    # save new configuration values
    saveKey 'proxy', @$el.find('.proxy').val().trim() or undefined