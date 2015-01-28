'use strict'

_ = require 'underscore'
fs = require 'fs-extra'
{safeLoad} = require 'js-yaml'
{normalize} = require 'path'
xlsx = require 'xlsx.js'
View = require '../view/view'
util = require '../util/ui'
TrackingView = require './tracking'
ProgressView = require './progress'

# indicates wether a competition is displayable
#
# @param competition [Competition] tested competition
# @param filter [String] current filter
# @return true if competition can be displayed, false otherwise
isDisplayed = (competition, filter) ->
  # if no contests found, allow displayal to remove it.
  #return true unless competition?.contests?
  return true if filter is 'none'
  if filter is 'national'
    return competition?.provider is 'ffds'
  if filter is 'international'
    return competition?.provider is 'wdsf'
  if filter is 'couples'
    # search for at least one couple present in on e of its contest results
    for contest in competition?.contests
      return true for couple in service.tracked when couple.name of contest.results
    return false
  # displayable by default
  true

module.exports = class HomeView extends View

  # template used to render view
  template: require '../../template/home.html'

  # i18n object for rendering
  i18n: safeLoad fs.readFileSync "#{__dirname}/../../nls/common.yml"

  # couple names that have fresh results
  newly: {}

  # competition filter
  filter: null

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
    'click .export-competition': '_onExportCompetition'
    'click .export-couple': '_onExportCouple'
    'click .filter .dropdown-menu li': '_onFilter'

  # Home View constructor
  # Immediately renders the view
  #
  # @return the built view
  constructor: () ->
    super className: 'home'
    @bindTo service, 'result', @_onResult
    # read filter in local storage
    storage.pop 'home-filter', (err, filter) =>
      console.error err if err?
      @filter = filter or 'none'
      @render()

  # Extends superclass behaviour to cache often used nodes
  render: =>
    super()
    @renderTracked()
    @renderCompetitions()
    @$('.bar .export').tooltip html: true, title: @i18n.tips.exportAll, delay: 750
    @$('.bar .filter').tooltip html: true, title: @i18n.tips.filter, delay: 750
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
          <span class="pull-right">
            <a class="export-couple btn" href="#"><i class="icon-download"></i></a>
            <a class="untrack btn btn-warning" href="#"><i class="icon-trash"></i></a>
          </span>
        </li>
        """
    ).join ''

    # re-display newly couples
    @newly = {}
    storage.pop 'newly', (err, values) =>
      @_onResult couple:name for name of values
    @$('.untrack').tooltip html: true, title: @i18n.tips.untrack, delay: 750
    @$('.export-couple').tooltip html: true, title: @i18n.tips.exportCouple, delay: 750

  # refresh only the list of competitions
  renderCompetitions: =>
    competitions = _.chain(service.competitions).values().sortBy('date').value().reverse()
    # hide removal button
    @$('.remove').toggleClass 'hidden', true
    list = @$('.competitions .list')
    # indicates whether a filter is active or not
    @$('.filter .btn').toggleClass 'enabled', @filter isnt 'none'
    @$('.filter .dropdown-menu li').removeClass 'enabled'
    @$(".filter .dropdown-menu li[data-filter = #{@filter}]").addClass 'enabled'
    # hide optionnal empty message, and displays it if necessary
    @$('.no-competitions').remove()
    return $("<div class='no-competitions'>#{@i18n.msgs.noCompetitions}</div>").insertAfter list.empty() unless competitions.length
    list.empty().append (
      for competition in competitions when isDisplayed competition, @filter
        """
        <li class="competition" data-id="#{competition.id}">
          <span class="date">#{competition.date.format @i18n.dateFormat}</span>
          <span class="name">#{competition.place}</span> 
          <span class="pull-right">
            <a class="export-competition btn" href="#"><i class="icon-download"></i></a>
            <a class="remove btn btn-warning" href="#"><i class="icon-trash"></i></a>
          </span>
        </li>
        """
    ).join ''
    # warning for too restrictive filter
    list.after "<div class='no-competitions'>#{@i18n.msgs.restrictiveFilter}</div>" if list.children().length is 0
    @$('.remove').tooltip html: true, title: @i18n.tips.remove, delay: 750
    @$('.export-competition').tooltip html: true, title: @i18n.tips.exportCompetition, delay: 750

  # **private**
  # Common behaviour of export function: handle error and opens a file selection popup to write xlsx content into
  #
  # @param err [Error] optionnal export error
  # @param result [Object] exported xlsx content
  # @param name [String] exported file name
  _saveExportPopup: (err, result, name) =>
    return util.popup @i18n.titles.exportError, _.sprintf @i18n.errors.export, err.message if err?
    # display a file selection dialog
    fileDialog = $("<input style='display:none' type='file' nwsaveas='#{name}.xlsx' accept='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'>").trigger 'click'
    fileDialog.on 'change', =>
      file = fileDialog[0].files?[0]?.path
      return unless file?
      console.log "export palmares in file: #{file}"
      fs.writeFile normalize(file), new Buffer(xlsx(result).base64, 'base64'), (err) =>
        util.popup @i18n.titles.exportError, _.sprintf @i18n.errors.export, err.message if err?

  # **private**
  # Exports global palmares to xlsx format
  _onExport: (event) =>
    event?.preventDefault()
    # get xlsx content
    service.export (err, result) =>
      @_saveExportPopup err, result, @i18n.titles.application

  # **private**
  # Exports competition palmares to xlsx format
  _onExportCompetition: (event) =>
    # to avoid opening the competition
    event?.stopImmediatePropagation()
    event?.preventDefault()
    # get xlsx content
    service.exportCompetitions [$(event?.target).closest('li.competition').data 'id'], (err, result) =>
      @_saveExportPopup err, result, $(event?.target).closest('li.competition').find('.name').text()

  # **private**
  # Exports couple palmares to xlsx format
  _onExportCouple: (event) =>
    # to avoid opening the couple
    event?.stopImmediatePropagation()
    event?.preventDefault()
    # get xlsx content
    service.exportCouples [$(event?.target).closest('li.couple').data 'name'], (err, result) =>
      @_saveExportPopup err, result, $(event?.target).closest('li.couple').find('.name').text()

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
      if err?
        popup.modal 'hide'
        return util.popup @i18n.titles.refreshError, _.sprintf @i18n.errors.refresh, err.message 
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
    # to avoid opening the couple
    event.stopImmediatePropagation()
    # get couple's name
    name = $(event.target).closest('li.couple').data 'name'
    # display a confirmation popup
    util.popup @i18n.titles.confirm, _.sprintf(@i18n.msgs.untrack, name), [
      text: @i18n.buttons.no
    ,
      text: @i18n.buttons.yes
      className: 'btn-warning'
      click: =>
        service.untrack [name], @renderTracked
    ]

  # **private**
  # Remove a competition, and render the page when done.
  #
  # @param event [Event] cancelled click event
  _onRemove: (event) =>
    event.preventDefault()
    # to avoid opening the competition
    event.stopImmediatePropagation()
    # get competition's id and name
    name = $(event.target).closest('li.competition').find('.name').text()
    id = $(event.target).closest('li.competition').data 'id'
    # display a confirmation popup
    util.popup @i18n.titles.confirm, _.sprintf(@i18n.msgs.remove, name), [
      text: @i18n.buttons.no
    ,
      text: @i18n.buttons.yes
      className: 'btn-warning'
      click: =>
        service.remove [id], @renderCompetitions
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

  # **private**
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

  # **private**
  # Filter displayed competitions.
  #
  # @param event [Event] cancelled click event
  _onFilter: (event) =>
    event.preventDefault()
    @filter = $(event.target).closest('li').attr('data-filter') or 'none'
    # store in storage
    storage.push 'home-filter', @filter, (err) =>
      console.error err if err?
      @renderCompetitions()