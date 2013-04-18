'use strict'

_ = require 'underscore'
fs = require 'fs-extra'
{normalize} = require 'path'
xlsx = require 'xlsx.js'
View = require '../view/view'
util = require '../util/ui'
TrackingView = require './tracking'
ProgressView = require './progress'

module.exports = class HomeView extends View

  # template used to render view
  template: require '../../template/home.html'

  # i18n object for rendering
  i18n: require '../../nls/common.yml'

  # couple names that have fresh results
  newly: {}

  # event map
  events: 
    'click .track': '_onTrackPopup'
    'click .couple': '_onOpenCouple'
    'click .result': '_onOpenCouple'
    'click .untrack': '_onUntrack'
    'click .refresh': '_onRefreshPopup'
    'click .competition': '_onOpenCompetition'
    'click .remove': '_onRemove'
    'click .export': '_onExport'

  # Home View constructor
  # Immediately renders the view
  #
  # @return the built view
  constructor: () ->
    super className: 'home'
    @bindTo service, 'result', @_onResult
    @render()

  # Extends superclass behaviour to cache often used nodes
  render: =>
    super()
    @renderTracked()
    @renderCompetitions()
    @

  # refresh only the list of tracked couples
  renderTracked: =>
    tracked = service.tracked
    # hide removal button
    @$('.untrack').toggleClass 'hidden', true
    list = @$('.tracked .list')
    # hide optionnal empty message, and displays it if necessary
    @$('.no-tracked').remove()
    return $("<div class='no-tracked'>#{@i18n.msgs.noTracked}</div>").insertAfter list.empty() unless tracked.length
    list.empty().append (
      for couple in tracked
        """
        <li class="couple" data-name="#{couple.name}">
          <span class="name">#{couple.name}</span>
          <input type="checkbox" class="pull-right">
        </li>
        """
    ).join ''

    # re-display newly couples
    @newly = {}
    storage.pop 'newly', (err, values) =>
      @_onResult couple:name for name of values

  # refresh only the list of competitions
  renderCompetitions: =>
    competitions = _.chain(service.competitions).values().sortBy('date').value().reverse()
    # hide removal button
    @$('.remove').toggleClass 'hidden', true
    list = @$('.competitions .list')
    # hide optionnal empty message, and displays it if necessary
    @$('.no-competitions').remove()
    return $("<div class='no-competitions'>#{@i18n.msgs.noCompetitions}</div>").insertAfter list.empty() unless competitions.length
    list.empty().append (
      for competition in competitions
        """
        <li class="competition" data-id="#{competition.id}">
          <span class="date">#{competition.date.format @i18n.dateFormat}</span>
          <span class="name">#{competition.place}</span> 
          <input type="checkbox" class="pull-right">
        </li>
        """
    ).join ''

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
      click: (event) =>
        # only add selected couples if necessary
        if tracking.couples?.length > 0
          # display progress inside the same popup
          event.preventDefault()
          popup.find('.modal-body').empty().append(@i18n.msgs.updateInProgress).append new ProgressView().$el
          popup.find('.modal-footer .btn').remove()
          # add the tracked couples
          service.track tracking.couples,  (err, summary) =>
            if err?
              popup.modal 'hide'
              return util.popup @i18n.titles.trackError, _.sprintf @i18n.errors.track, err.message 
            # render list with newly added couples
            @renderTracked()
            # close popup with a slight delay to show progress
            _.delay ->
              popup.modal 'hide'
            , 1000
    ]
    # insert a tracking view inside
    popup.find('.modal-body').append tracking.$el

    # and focus on opening
    popup.on 'shown', => tracking.$('input').first().focus()

  # **private**
  # Search for providers updates.
  # Displays progress inside a popup
  #
  # @param event [Event] cancelled click event
  _onRefreshPopup: (event) =>
    event?.preventDefault()

    # display progress in a popup
    popup = util.popup @i18n.titles.update, @i18n.msgs.updateInProgress
    popup.find('.modal-body').append new ProgressView().$el

    # trigger update and render competitions
    service.update (err, results) =>
      console.log 'new results found:', results
      @renderCompetitions()
      # close popup with a slight delay to show progress
      _.delay ->
        popup.modal 'hide'
      , 1000

  # **private**
  # Remove a tracked couple, and render the page when done.
  #
  # @param event [Event] cancelled click event
  _onUntrack: (event) =>
    event.preventDefault()
    # select all checked couples
    selected = ($(selected).closest('li').data 'name' for selected in @$ '.tracked :checked')
    return unless selected.length > 0
    # display a confirmation popup
    util.popup @i18n.titles.confirm, _.sprintf(@i18n.msgs.untrack, selected.join('<br>')), [
      text: @i18n.buttons.no
    ,
      text: @i18n.buttons.yes
      className: 'btn-warning'
      click: =>
        service.untrack selected, @renderTracked
    ]

  # **private**
  # Remove a competition, and render the page when done.
  #
  # @param event [Event] cancelled click event
  _onRemove: (event) =>
    event.preventDefault()
     # select all checked competitions
    ids = []
    names = []
    for selected in @$ '.competitions :checked'
      competition = $(selected).closest 'li'
      names.push competition.find('.name').text()
      ids.push competition.data 'id'

    return unless ids.length > 0
    # display a confirmation popup
    util.popup @i18n.titles.confirm, _.sprintf(@i18n.msgs.remove, names.join('<br>')), [
      text: @i18n.buttons.no
    ,
      text: @i18n.buttons.yes
      className: 'btn-warning'
      click: =>
        service.remove ids, @renderCompetitions
    ]

  # **private**
  # Navigate to the Couple details page.
  #
  # @param event [Event] cancelled click event
  _onOpenCouple: (event) =>
    # ignore checkbox selection
    if $(event?.target).is ':checkbox'
      return @$('.untrack').toggleClass 'hidden', @$('.tracked :checked').length is 0
    event.preventDefault()
    name = $(event.target).closest('li').data 'name'
    # update storage
    if name of @newly
      delete @newly[name]
      storage.push 'newly', @newly
    router.navigate 'couple', name

  # **private**
  # Navigate to the Competition details page.
  #
  # @param event [Event] cancelled click event
  _onOpenCompetition: (event) =>
    # ignore checkbox selection
    if $(event?.target).is ':checkbox'
      return @$('.remove').toggleClass 'hidden', @$('.competitions :checked').length is 0
    event.preventDefault()
    router.navigate 'competition', $(event.target).closest('li').data 'id'

  # Display new results while they are retrieved
  # A special class is added to corresponding result
  #
  # @param ranking [Object] the new ranking, with the concerned couple name
  _onResult: (ranking) =>
    return if ranking.couple of @newly
    # toggle class on rendering
    @$(".couple[data-name='#{ranking.couple}']").addClass 'newly', true
    # keep in storage
    @newly[ranking.couple] = true
    storage.push 'newly', @newly