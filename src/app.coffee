'use strict'

gui = require 'nw.gui'
fs = require 'fs-extra'
moment = require 'moment'
{version} = require './package.json'

console.log "running Palmares #{version} on node-webkit v#{process.versions['node-webkit']}"

# register window globals inside NodeJS's global space
global.gui = gui
global.$ = $
# first require: use path relative to index.html
Router = require './lib/router.js'
Cleaner = require './lib/service/cleaner.js'
Storage = require './lib/service/indexeddb.js'
_ = require 'underscore'
isMaximized = false

splash = gui.Window.open 'template/splash.html',
  position: 'center'
  toolbar: false
  resizable: false
  frame: false
  show: true
  'always-on-top': true
  height: 200
  width: 400

# 'win' is Node-Webkit's window
# 'window' is DOM's window
win = gui.Window.get()

# stores in local storage application state
win.on 'close', ->
  console.log 'close !'
  for attr in ['x', 'y', 'width', 'height']
    localStorage.setItem attr, win[attr]

  localStorage.setItem 'maximized', isMaximized
  @close true

win.on 'maximize', -> isMaximized = true
win.on 'unmaximize', -> isMaximized = false
win.on 'minimize', -> isMaximized = false

# Display on dev tools the caught error and do not crash
process.on 'uncaughtException', errorHandler = (err, file, line) ->
  if file?
    err = "#{err} (#{file}:#{line})"
  else if err instanceof Error
    err = err.stack
  console.error err
  fs.appendFileSync 'error.txt', "------\n#{moment().format 'DD/MM/YYYY HH:mm:ss'}\n#{err}\n"
  process.exit() unless global.router?

# DOM is ready
win.once 'loaded', ->
  global.console = window.console
  window.onerror = errorHandler

  # opens dev tools on F12 or Command+Option+J
  $(window).on 'keyup', (event) ->
    win.showDevTools() if event.which is 123 or event.witch is 74 and event.metaKey and event.altKey

  # restore from local storage application state if possible
  if localStorage.getItem 'x'
    x = Number localStorage.getItem 'x'
    y = Number localStorage.getItem 'y'
    win.moveTo x, y
  if localStorage.getItem 'width'
    width = Number localStorage.getItem 'width'
    height = Number localStorage.getItem 'height'
    win.resizeTo width, height
  else
    infos = require './package.json'
    win.resizeTo infos.window.min_width, infos.window.min_height,

  # init storage service
  global.storage = new Storage()
  Cleaner.sanitize global.storage, ->

    # we are ready: shows it !
    win.show()
    # local storage stores strings !
    win.maximize() if 'true' is localStorage.getItem 'maximized'

    # start main application, after window is shown
    _.delay ->
      global.router = new Router()
      _.delay ->
        splash.close true
      , 50
    , 100