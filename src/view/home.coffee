'use strict'

_ = require 'underscore'
moment = require 'moment'
fs = require 'fs-extra'
{normalize} = require 'path'
xlsx = require 'xlsx.js'
View = require '../view/view'
util = require '../util/ui'
TrackingView = require './tracking'

animDuration = 300
rankingDelay = 5000

module.exports = class HomeView extends View

  # template used to render view
  template: require '../../template/home.html'

  # i18n object for rendering
  i18n: require '../../nls/common.yml'

  # event map
  events: 
    'click .track.btn': '_onTrackPopup'
    'click .couple': '_onDisplayCouple'
    'click .untrack': '_onUntrackCouple'
    'click .export': '_onExport'
    'click .refresh': '_onRefresh'
    'click .competitions': '_onCompetitions'

  # while tracking, the number of competitions to analyze
  totalComps: null

  # while tracking, the number of analyzed competitions
  currentComp: null

  # rendering's progress bar
  progress: null

  # rendering's details popup
  details: null

  # timeout before automatically close the new results alert
  resultTimeout: null

  # Home View constructor
  # Immediately renders the view
  constructor: () ->
    super className: 'home container'
    @bindTo service, 'progress', @_onProgress
    @bindTo service, 'result', @_onResult
    @render()

  # Extends superclass behaviour to cache often used nodes
  render: =>
    super()
    @progress = @$ '.progress .bar'
    @details = @$ '.progress-panel > .alert'
    @renderList()
    @

  # refresh only the list of tracked couples
  renderList: =>
    tracked = service.tracked
    @$('.no-tracked').remove()
    return $("<p class='no-tracked'>#{@i18n.msgs.noTracked}</p>").insertAfter @$('.list').empty() unless tracked.length
    html = (
      for couple in tracked
        "<li data-name='#{couple.name}'><a class='couple' href='#'>#{couple.name}</a><a class='untrack btn' href='#'><i class='icon-remove'></i></a></li>"
    )
    @$('.list').empty().append html.join ''

  # **private**
  # Exports global palmares to xlsx format
  _onExport: (event) =>
    event?.preventDefault()
    # get xlsx content
    service.export (err, result) =>
      return util.popup @i18n.titles.exportError, _.sprintf @i18n.errors.export, err.message if err?
      # display a file selection dialog
      fileDialog = $("<input style='display:none' type='file' accept='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' nwsaveas>").trigger 'click'
      fileDialog.on 'change', =>
        file = fileDialog[0].files?[0]?.path
        console.log fileDialog[0].files?[0]
        return unless file?
        console.log "export palmares in file: #{file}"
        fs.writeFile normalize(file), new Buffer(xlsx(result).base64, 'base64'), (err) =>
          util.popup @i18n.titles.exportError, _.sprintf @i18n.errors.export, err.message if err?

  # **private**
  # Display a popup to select new tracked couples
  #
  # @param event [Event] cancelled click event
  _onTrackPopup: (event) =>
    event?.preventDefault()

    tracking = new TrackingView()

    # opens a popup that will track selected couples
    popup = util.popup @i18n.titles.trackCouples, '', [
      text: @i18n.buttons.cancel
    ,
      text: @i18n.buttons.add
      className: 'btn-primary'
      click: =>
        # only add selected couples if necessary
        if tracking.couples?.length > 0
          service.track tracking.couples,  (err, summary) =>
            # render list with newly added couples
            util.popup @i18n.titles.trackError, _.sprintf @i18n.errors.track, err.message if err?
            @renderList()
    ]
    # insert a tracking view inside
    popup.find('.modal-body').append tracking.$el

    # and focus on opening
    popup.on 'shown', => tracking.$('input').first().focus()

  # **private**
  # Search for providers updates
  #
  # @param event [Event] cancelled click event
  _onRefresh: (event) =>
    event?.preventDefault()
    service.seekUpdates (err, results) =>
      console.log 'new results found:', results

  # Tracking progress handler
  # Display tracking progression while events are comming
  _onProgress: (state, details) =>
    panel = @$ '.progress-panel'
    unless panel.hasClass 'in'
      panel.addClass 'in'
      @progress.css width: 0
      @details.empty().append @i18n.msgs.trackingStart

    switch state
      when 'start'
        console.log "tracking starts !"
        @totalComps = null
        @currentComp = 0
      when 'compRetrieved'
        console.log "retrieved #{details.num} competitions"
        # arbitrary add 5% 
        width = 0.5
        unless @totalComps?
          @totalComps = details.num
        else
          @totalComps += details.num
          # expand the total number of competitions + 5%
          width += @currentComp
        @progress.css width: "#{width*100/@totalComps}%"
        @details.append _.sprintf @i18n.msgs.competitionRetrieved, details.name, details.num,
      when 'compStart'
        console.log "analyse of #{details.place} begins"
        @details.append _.sprintf @i18n.msgs.competitionInProgress, details.id, details.place, details.date.format @i18n.dateFormat
      when 'contestsRetrieved'
        console.log "retrieved #{details.total} contests in #{details.competition.place}"
        @details.find(".#{details.competition.id} .total").html details.total
      when 'contestEnd'
        console.log "analyzed #{details.done} contests in #{details.competition.place}"
        @details.find(".#{details.competition.id} .done").html details.done
      when 'compEnd'
        console.log "analyse of #{details.place} ends"
        @currentComp++
        @progress.css width: "#{@currentComp*100/@totalComps}%"
        @details.find(".#{details.id}").replaceWith _.sprintf @i18n.msgs.competitionAnalyzed, details.place, details.date.format @i18n.dateFormat
      when 'end'
        console.log "tracking ends !"
        @progress.css width: '100%'
        @details.append @i18n.msgs.trackingEnd
        _.delay =>
          @$('.progress-panel').removeClass 'in'
        , 1000

    pos = @details.scrollTop()
    height = @details[0].scrollHeight - @details.outerHeight()
    lineHeight = @details.children().first().outerHeight()
    # scroll to bottom, only if the scroller is already at bottom
    @details.scrollTop height+lineHeight if pos+lineHeight >= height

  # Display new results while they are retrieved
  #
  # @param ranking [Object] the new ranking, with the concerned couple name
  # @param competition [Object] the concerned competition
  _onResult: (ranking, competition) =>
    panel = @$('.results-panel')
    console.log "new result for #{ranking.couple} in #{competition.place}: #{ranking.rank}/#{ranking.total}"
    # previous alert removal
    clearTimeout @resultTimeout if @resultTimeout
    panel.children().alert 'close'
    panel.empty().append "<div class='alert alert-success fade in'>#{_.sprintf @i18n.msgs.newResult, ranking.couple, competition.place}</div>"
    # auto closure
    @resultTimeout = _.delay ->
      panel.children().alert 'close'
    , rankingDelay

  # **private**
  # Remove a tracked couple, and render the page when done.
  #
  # @param event [Event] cancelled click event
  _onUntrackCouple: (event) =>
    event.preventDefault()
    name = $(event.target).closest('li').data 'name'
    # display a confirmation popup
    util.popup @i18n.titles.confirm, _.sprintf(@i18n.msgs.untrack, name), [
      text: @i18n.buttons.no
    ,
      text: @i18n.buttons.yes
      className: 'btn-warning'
      click: =>
        service.untrack [name], @renderList
    ]

  # **private**
  # Navigate to the Couple details page.
  #
  # @param event [Event] cancelled click event
  _onDisplayCouple: (event) =>
    event.preventDefault()
    router.navigate 'couple', $(event.target).closest('li').data 'name'

  # **private**
  # Navigate to the Competitions details page.
  #
  # @param event [Event] cancelled click event
  _onCompetitions: (event) =>
    event.preventDefault()
    router.navigate 'competitions'