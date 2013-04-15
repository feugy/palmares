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
    'click h3': '_onOpenCompetition'

  # Couple View constructor
  # Immediately renders the view, after havin g established the couple palmares.
  #
  # @param name [String] shown couple name
  # @return the built view
  constructor: (@name) ->
    super className: 'details couple'
    # check the couple existence
    service.palmares @name, (err, palmares) =>
      @name = @name.replace ' - ', '<br/>'
      unless err?
        @palmares = (
          for detail in palmares
            name: detail.competition.place
            date: detail.competition.date.format @i18n.dateFormat
            id: detail.competition.id
            results: detail.results
        )
      @render()

  # **private**
  # Navigate to the home page.
  #
  # @param event [Event] cancelled click event
  _onHome: (event) =>
    event?.preventDefault()
    router.navigate 'home'  

  # **private**
  # Navigate to the Competition details page.
  #
  # @param event [Event] cancelled click event
  _onOpenCompetition: (event) =>
    event.preventDefault()
    router.navigate 'competition', $(event.target).closest('h3').data 'id'