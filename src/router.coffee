_ = require 'underscore'
{safeLoad} = require 'js-yaml'
{readFileSync} = require 'fs-extra'
EventEmitter = require('events').EventEmitter
util = require './util/common'
FFDS = require './provider/ffds'
WDSF = require './provider/wdsf'
PalmaresService = require './service/palmares'
HomeView = require './view/home'
CoupleView = require './view/couple'
CompetitionView = require './view/competition'
AboutView = require './view/about'
SettingsView = require './view/settings'
ui = require './util/ui'
util = require './util/common'

# The Router manage navigation between views inside th GUI
module.exports = class Router extends EventEmitter

  # i18n utility
  i18n: safeLoad readFileSync "#{__dirname}/../nls/common.yml"

  # competitions provider
  providers: []

  # Palmares service: heart of the application
  service: null

  # Router constructor: initialize services and run home view.
  constructor: ->
    # set main window title
    $('header h1').html @i18n.titles.application
    global.win.title = @i18n.titles.application
    # build providers
    @providers = [
      new FFDS util.confKey 'providers.FFDS'
      new WDSF util.confKey 'providers.WDSF'
    ]
    @service = new PalmaresService storage, @providers, _.extend {appTitle: @i18n.titles.application}, @i18n.export
    global.service = @service
    global.searchProvider = @providers[0]

    @service.on 'ready', =>
      # add configuration and credits view
      $('.parameters').addClass('btn-group').html("""
        <a class="btn dropdown-toggle" data-toggle="dropdown"><i class="icon-cog"></i><span class="caret"></span></a>
        <ul class="dropdown-menu">
          <li class="settings">#{@i18n.buttons.settings}</li>
          <li class="about"  >#{@i18n.buttons.about}</li>
        </ul>""")
        .on('click', '.settings', @_onSettings)
        .on 'click', '.about', @_onAbout
      @constructor = true
      @navigate 'home'

  # Trigger a given route, passing relevant arguments
  # Emit also a `navigate` event with executed route, after the route is executed
  #
  # @param path [String] the executed route
  # @param args [Object] arbitrary arguments of the executed route. May be as many as needed
  # @throws if the desired path does not match any known routes
  navigate: (path, args...) =>
    if path in ['home', 'couple', 'competition']
      view = (
        switch path
          when 'home' then new HomeView()
          when 'couple' then new CoupleView args[0]
          when 'competition' then new CompetitionView args[0]
      )
      $('#main').addClass 'leaving'
      _.delay =>
        @constructor = false
        $('#main').removeClass('leaving').empty().scrollTop(0).append view.$el
      , if @constructor then 0 else 500
    else
      throw new Error "unknown route #{path}"
    @emit 'navigate', path: path

  # **private**
  # Display a popup for settings.
  # Proxy is the only supported settings for now
  #
  # @param event [Event] optionnal cancelled click event
  _onSettings: (event) =>
    event?.preventDefault()
    view = new SettingsView()
    settings = ui.popup @i18n.titles.settings, view.$el, [text: @i18n.buttons.cancel,
      text: @i18n.buttons.save
      className: 'btn-primary'
      click: view.save
    ]

  # **private**
  # Display a popup for credits.
  #
  # @param event [Event] optionnal cancelled click event
  _onAbout: (event) =>
    event?.preventDefault()
    ui.popup @i18n.titles.about, new AboutView().$el