_ = require 'underscore'
Hogan = require 'hogan.js'
fs = require 'fs-extra'
{sep} = require 'path'
{EventEmitter} = require 'events'

# enhance NodeJS's require to synchronously load files
require.extensions['.html'] = (module, filename) ->
  module.exports = fs.readFileSync filename.replace(new RegExp('/','g'), sep), 'utf8'

delegateEventSplitter = /^(\S+)\s*(.*)$/

# overload $.cleanData  to trigger 'remove' event when DOM node is removed
_cleanData = $.cleanData
$.cleanData = (elems) ->
  for elem in elems when elem?
    try
      $(elem).triggerHandler 'remove'
    catch err
      # http://bugs.jquery.com/ticket/8235
  _cleanData elems

module.exports = class View extends EventEmitter

  # view node: jQuery element of the highest DOM node within the view
  $el: null

  # tag used when building the view node. default to 'div'
  tagName: 'div'

  # optionnal CSS classes that may be affected to current view node
  className: null

  # optionnal DOM id that may be affected to current view node.
  id: null

  # For views that wants templating, put their the string version of a mustache template,
  # that will be compiled with Hogan
  template: null

  # Events table: an associative array containing:
  #   {"event selector": "callback"}
  #
  # For exemple:
  #
  #    {
  #      'mousedown .title':  'edit',
  #      'click .button':     'save'
  #      'click .open':       function(e) { ... }
  #    }
  events: null

  # **private**
  # Array of bounds between targets and the view, that are unbound by `destroy`
  _bounds: []

  # View constructor.
  # Create view element, and binds events if specified.
  constructor: (attrs) ->
    super()
    @[key] = value for key, value of attrs
    @setMaxListeners 0
    # creates element with relevant attributes
    attrs = {}
    attrs.id = @id if @id?
    attrs.class = @className if @className?
    @$el = $("<#{@tagName}>").attr attrs

    # initialize to avoid static behaviour
    @_bounds = []
    # auto dispose when removing
    @$el.on 'remove', @dispose

    # bound specified events
    if @events?
      for key, method of @events
        method = @[method] unless _.isFunction method
        match = key.match delegateEventSplitter
        eventName = match[1]
        selector = match[2]

        if selector is ''
          @bindTo @$el, eventName, method
        else
          # bindTo does not handle delegate
          @$el.on eventName, selector, method
          @_bounds.push [@$el, key, method]

  # jQuery delegate for element lookup, scoped to DOM elements within the current view.
  #
  # @param selector [String] jQuery selector, scoped to view
  # @return the selected jQuery elements
  $: (selector) =>
    @$el.find selector

  # The `render()` method is invoked by backbone to display view content at screen.
  # if a template is defined, use it
  render: () =>
    # template rendering
    @$el.empty()
    if @template?
      # first compilation if necessary
      @template = Hogan.compile @template if _.isString @template
      # then rendering
      @$el.append @template.render @getRenderData()
    # for chaining purposes
    @

  # This method is intended to by overloaded by subclass to provide template data for rendering
  #
  # @return an object used as template data (this by default)
  getRenderData: =>
    @

  # Allows to bound a callback of this view to the specified emitter
  # bounds are keept and automatically unbound by the `destroy` method.
  #
  # @param emitter [Backbone.Event] the emitter on which callback is bound
  # @param events [String] events on which the callback is bound (space delimitted)
  # @parma callback [Function] the bound callback
  bindTo: (emitter, events, callback) =>
    evts = events.split ' '
    for evt in evts
      emitter.on evt, callback
      @_bounds.push [emitter, evt, callback]

  # Unbounds a callback of this view from the specified emitter
  #
  # @param emitter [Backbone.Event] the emitter on which callback is unbound
  # @param events [String] event on which the callback is unbound
  unboundFrom: (emitter, event) =>
    for spec, i in @_bounds when spec[0] is emitter and spec[1] is event
      method = if 'off' of spec[0] then 'off' else 'removeListener'
      spec[0][method] spec[1], spec[2]
      @_bounds.splice i, 1
      break

  # The destroy method correctly free DOM  and event handlers
  # It must be overloaded by subclasses to unsubsribe events.
  dispose: =>
    # automatically remove bound callback
    for spec in @_bounds
      method = if 'off' of spec[0] then 'off' else 'removeListener'
      spec[0][method] spec[1], spec[2]
    # unbind DOM callback
    @$el.unbind()
    # trigger dispose event
    @trigger 'dispose', @