'use strict'

_ = require 'underscore'
EventEmitter = require('events').EventEmitter
util = require './util/common'
FFDS = require './provider/ffds'
WDSF = require './provider/wdsf'
Storage = require './service/localstorage'
PalmaresService = require './service/palmares'
HomeView = require './view/home'
CoupleView = require './view/couple'
CompetitionsView = require './view/competitions'

i18n = require '../nls/common.yml'

# The Router manage navigation between views inside th GUI
module.exports = class Router extends EventEmitter

  # competitions provider
  providers: []

  # Palmares service: heart of the application
  service: null

  # list of known routes and their corresponding method
  routes: 
    'home': ->
      $('#main').empty().append new HomeView().$el
    'couple': (name) ->
      $('#main').empty().append new CoupleView(name).$el
    'competitions': (name) ->
      $('#main').empty().append new CompetitionsView().$el

  # Router constructor: initialize services and run home view.
  constructor: ->
    #set main window title
    gui.Window.get().title = i18n.titles.application
    # build providers
    @providers = [
      new FFDS util.confKey 'providers.FFDS'
      new WDSF util.confKey 'providers.WDSF'
    ]
    @service = new PalmaresService new Storage(), @providers, _.extend {appTitle: i18n.titles.application}, i18n.export
    global.service = @service
    global.searchProvider = @providers[0]
    @navigate 'home'

  # Trigger a given route, passing relevant arguments
  # Emit also a `navigate` event with executed route, after the route is executed
  #
  # @param path [String] the executed route
  # @param args [Object] arbitrary arguments of the executed route. May be as many as needed
  # @throws if the desired path does not match any known routes
  navigate: (path, args...) =>
    if path of @routes
      method = @routes[path]
      method = @[method] if _.isString method
      method.apply @, args
    else 
      throw new Error "unknown route #{path}"
    @emit 'navigate', path: path