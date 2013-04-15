'use strict'

gui = require 'nw.gui'

# register window globals inside NodeJS's global space
global.gui = gui
global.$ = $
# first require: use path relative to index.html
Router = require './lib/router.js'

# 'win' is Node-Webkit's window
# 'window' is DOM's window
win = gui.Window.get()

# stores in local storage application state
win.on 'close', ->
  console.log 'close !'
  for attr in ['x', 'y', 'width', 'height']
    localStorage.setItem attr, win[attr]
  @close true

# Display on dev tools the caught error and do not crash
process.on 'uncaughtException', (err) ->
  console.error err.stack

# DOM is ready
win.on 'loaded', ->

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

  # start main application
  global.router = new Router()

  # we are ready: shows it !
  win.show()