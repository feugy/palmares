'use strict'

_ = require 'underscore'
{safeLoad} = require 'js-yaml'
{readFileSync} = require 'fs-extra'
View = require '../view/view'
console = require '../util/logger'

# validation regexp
coupleRegex = /^(?:[\w-]+ ){2,}-(?: [\w-]+){2,}$/gi

module.exports = class HomeView extends View

  # template used to render view
  template: require '../../template/tracking.html'

  # i18n object for rendering
  i18n: safeLoad readFileSync "#{__dirname}/../../nls/common.yml"

  # selected couples
  couples: []

  # flag indicating in-progress request
  checking:
    couple: false
    group: false

  # icons indicating couple name and club status
  status:
    couple: null
    group: null

  # textual message to indicate status
  alert:
    couple: null
    group: null

  # event map
  events:
    'keyup input': '_onCheckName'

  # Tracking View constructor
  # Immediately renders the view
  #
  # @return the built view
  constructor: ->
    super className: 'track'
    @couples = []
    @checking =
      couple: false
      group: false
    @status = {}
    @_onCheckGroup = _.debounce @_onCheckGroup, 500
    @_onCheckCouple = _.debounce @_onCheckCouple, 500
    @render()

  # Extends superclass to attach widget to rendering.
  render: =>
    super()
    # make the couple input a typeahead: display 5 result when typing at least 2 characters
    @$('.add-couple input').typeahead
      source: @_onCheckCouple
      minLength: 2
      items: 5
      # on update, test names
      updater: (item) =>
        _.defer @_onCheckName
        item
    # make the group input a typeahead: display 5 result when typing at least 2 characters
    @$('.add-group input').typeahead
      source: @_onCheckGroup
      minLength: 2
      items: 5
      # on update, get couples
      updater: (item) =>
        _.defer @_onGetCouples
        item
    # field status icon
    @status =
      couple: @$ '.add-couple .add-on i'
      group: @$ '.add-group .add-on i'
    # field status text
    @alert =
      couple: @$ '.add-couple .alert'
      group: @$ '.add-group .alert'
    @

  # **private**
  # Check group's existence with provider to provider autocompletion.
  #
  # @param input [String] text of autocompleted input field
  # @param callback [Function] completition end function. Invoked with an array (may be empty) of completion strings
  _onCheckGroup: (input, callback) =>
    # only one request allowed
    return if @checking.group
    # no name inputed
    return unless input?.length > 0

    # reset couple
    @$('.add-couple .name').val ''
    @alert.couple.hide()
    @alert.group.html(@i18n.msgs.searchInProgress)
      .removeClass('alert-success')
      .addClass('alert-info')
      .show()

    # ask service if group exists
    @checking.group = true
    console.log "search club: #{input}"
    @status.group.removeClass().addClass 'icon-refresh'
    searchProvider.searchGroups input, (err, clubs) =>
      @checking.group = false
      if err?
        console.error err
        clubs = []
      console.log "found #{clubs.length} clubs"
      @status.group.removeClass().addClass 'icon-question-sign'
      @alert.group.hide()
      # returns results
      callback clubs

  # **private**
  # Check couple's existence with provider to provider autocompletion.
  #
  # @param input [String] text of autocompleted input field
  # @param callback [Function] completition end function. Invoked with an array (may be empty) of completion strings
  _onCheckCouple: (input, callback) =>
    # only one request allowed
    return if @checking.couple
    # no name inputed
    return unless input?.length > 0

    # reset groups
    @$('.add-group .name').val ''
    @alert.couple.html(@i18n.msgs.searchInProgress)
      .removeClass('alert-success')
      .addClass('alert-info')
      .show()
    @alert.group.hide()

    # ask service if couple exists
    @checking.couple = true
    @status.couple.removeClass().addClass 'icon-refresh'
    console.log "search couple: #{input}"
    searchProvider.searchCouples input, (err, candidates) =>
      @checking.couple = false
      if err?
        console.error err
        candidates = []
      console.log "found #{candidates.length} couples"
      # change icon with checking
      @_onCheckName()
      # returns results
      callback candidates

  # **private**
  # Check couple names agains regular expression, and update the validity icon
  # Fills the `couple` attribute
  _onCheckName: =>
    couple = @$('.add-couple .name').val().trim()
    @couples = [couple]
    @alert.couple.hide()
    @status.couple.removeClass().addClass 'icon-question-sign'
    # check couple name and group status
    if coupleRegex.test couple
      @status.couple.removeClass().addClass 'icon-ok'
      @alert.couple.html(@i18n.msgs.validCouple)
        .removeClass('alert-info')
        .addClass('alert-success')
        .show()

  # **private**
  # Once a group has been selected, gets the corresponding couples
  # Fills the `couple` attribute
  _onGetCouples: =>
    # only one request allowed
    return if @checking.group
    group = @$('.add-group .name').val().trim()

    @alert.group.html(@i18n.msgs.searchInProgress)
      .removeClass('alert-success')
      .addClass('alert-info')
      .show()

    # ask service about group couples
    @checking.group = true
    @status.group.removeClass().addClass 'icon-refresh'
    @couples = []
    console.log "search group #{group} couples"
    searchProvider.getGroupCouples group, (err, couples) =>
      @checking.group = false
      if err?
        console.error err
        return @status.group.removeClass().addClass 'icon-question-sign'
      @couples = couples
      @status.group.removeClass().addClass 'icon-ok'
      @alert.group.html(_.sprintf @i18n.msgs.foundInGroup, couples.length)
        .removeClass('alert-info')
        .addClass 'alert-success'