'use strict'

_ = require 'underscore'
View = require '../view/view'
util = require '../util/ui'

module.exports = class CompetitionsView extends View

  # template used to render view
  template: require '../../template/competitions.html'

  # i18n object for rendering
  i18n: require '../../nls/common.yml'

  # event map
  events: 
    'click .home': '_onHome'
    'click .remove': '_onRemoveCompetition'

  # Home View constructor
  # Immediately renders the view
  constructor: (@name) ->
    super className: 'couple container'
    @render()

  # the render methods updates its competition list
  render: =>
    @competitions = service.getCompetitions()
    super()

  # **private**
  # Navigate to the home page.
  #
  # @param event [Event] cancelled click event
  _onHome: (event) =>
    event?.preventDefault()
    router.navigate 'home'

  # **private**
  # Remove a competition, and render the page when done.
  #
  # @param event [Event] cancelled click event
  _onRemoveCompetition: (event) =>
    event.preventDefault()
    id = $(event.target).closest('div').data 'id'
    name = $(event.target).closest('div').find('.name').text()
    # display a confirmation popup
    util.popup @i18n.titles.confirm, _.sprintf(@i18n.msgs.removeCompetition, name), [
      text: @i18n.buttons.no
    ,
      text: @i18n.buttons.yes
      className: 'btn-warning'
      click: =>
        service.removeCompetition id, @render
    ]