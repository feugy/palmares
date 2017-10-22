{remote} = require 'electron'
_ = require 'underscore'

# first require: use path relative to index.html
Router = require './lib/router.js'
Cleaner = require './lib/service/cleaner.js'
Storage = require './lib/service/indexeddb.js'

win = remote.getCurrentWindow()

# stores in local storage application state
$(window).on 'unload', ->
  console.log 'close !'
  bounds = win.getBounds()
  localStorage.setItem attr, bounds[attr] for attr of bounds
  localStorage.setItem 'maximized', win.isMaximized()

console.log "running Palmares #{remote.app.getVersion()} on electron #{process.versions.electron}"

$(window).on 'keydown', (event) ->
  # opens dev tools on F12 or Command+Option+J
  win.webContents.openDevTools mode: 'detach' if event.which is 123 or event.witch is 74 and event.metaKey and event.altKey
  # reloads full app on F5
  if event.which is 116
    # must clear require cache also
    delete global.require.cache[attr] for attr of global.require.cache
    global.reload = true
    win.removeAllListeners 'close'
    win.webContents.reloadIgnoringCache()

# init storage service
global.storage = new Storage()

Cleaner.sanitize global.storage, ->
  # restore from local storage application state if possible
  if localStorage.getItem 'x'
    x = Number localStorage.getItem 'x'
    y = Number localStorage.getItem 'y'
    win.setPosition x, y
  if localStorage.getItem 'width'
    width = Number localStorage.getItem 'width'
    height = Number localStorage.getItem 'height'
    win.setSize width, height
  # local storage stores strings !
  win.maximize() if 'true' is localStorage.getItem 'maximized'

  # start main application, after window is shown
  _.delay ->
    global.router = new Router()
    _.delay ->
      # we are ready: shows it !
      win.show()
      # close splash screen
      win.getChildWindows()[0]?.close()
    , 50
  , 100
