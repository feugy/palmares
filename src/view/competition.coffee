'use strict'

_ = require 'underscore'
View = require '../view/view'
util = require '../util/ui'

module.exports = class CompetitionView extends View

  # template used to render view
  template: require '../../template/competition.html'

  # i18n object for rendering
  i18n: require '../../nls/common.yml'

  # rendered competition
  competition: null

  # rendered competition's formated date
  date: ''

  # rendered competition's contests
  contests: []

  # event map
  events: 
    'click .home': '_onHome'
    'click li': '_onOpenCouple'

  # Competition View constructor
  # Immediately renders the view, or navigate to home if competition does not exist
  #
  # @param id [String] shown competition id
  # @return the built view
  constructor: (id) ->
    super className: 'details'
    @competition = service.competitions[id]
    return router.navigate 'home' unless @competition?
    @date = @competition.date.format @i18n.dateFormat 
    @contests = (
      for contest in @competition.contests
        title: contest.title
        results: _.sortBy (
          for name, rank of contest.results
            name: name
            rank: rank
            # keep tracked couples to add links
            tracked: _.find(service.tracked, (c) -> c.name is name)?
        ), 'rank'
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
  # Navigate the palmares page of a given couple.
  #
  # @param event [Event] cancelled click event
  _onOpenCouple: (event) =>
    event?.preventDefault()
    name = $(event.target).closest('li').data 'name'
    return unless name?
    router.navigate 'couple', name