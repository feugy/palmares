'use strict'

_ = require 'underscore'
View = require '../view/view'
util = require '../util/ui'

module.exports = class CoupleView extends View

  # template used to render view
  template: require '../../template/couple.html'

  # i18n object for rendering
  i18n: require '../../nls/common.yml'

  # Rendered couple name
  name: null

  # displayed palmares
  palmares: null

  # event map
  events: 
    'click .home': '_onHome'

  # Home View constructor
  # Immediately renders the view
  constructor: (@name) ->
    super className: 'couple container'
    # check the couple existence
    service.palmares @name, (err, palmares) =>
      @palmares = palmares unless err?
      @render()

  # **private**
  # Navigate to the home page.
  #
  # @param event [Event] cancelled click event
  _onHome: (event) =>
    event?.preventDefault()
    router.navigate 'home'