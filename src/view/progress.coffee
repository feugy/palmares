'use strict'

_ = require 'underscore'
moment = require 'moment'
View = require '../view/view'

animDuration = 300
rankingDelay = 5000

module.exports = class ProgressView extends View

  # template used to render view
  template: require '../../template/progress.html'

  # i18n object for rendering
  i18n: require '../../nls/common.yml'

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

  # indicate whether the operation was started
  started: false

  # Progress View constructor
  # Binds to service progression events and immediately renders the view
  #
  # @return the built view
  constructor: () ->
    super className: 'progress-view'
    @started = false
    @bindTo service, 'progress', @_onProgress
    @render()

  # Extends superclass behaviour to cache often used nodes
  render: =>
    super()
    @progress = @$ '.progress .bar'
    @details = @$ '.details'
    @

  # Tracking progress handler
  # Display tracking progression while events are comming
  _onProgress: (state, details) =>
    unless @started
      @started = true
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

    pos = @details.scrollTop()
    height = @details[0].scrollHeight - @details.outerHeight()
    lineHeight = @details.children().first().outerHeight()
    # scroll to bottom, only if the scroller is already at bottom
    @details.scrollTop height+lineHeight if pos+lineHeight >= height