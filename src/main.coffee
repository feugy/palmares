require('source-map-support').install({environment: 'node'})
{app, BrowserWindow, nativeImage} = require 'electron'
{resolve} = require 'path'
{format} = require 'url'

# global reference of the window object
win = null

createWindow = () =>

  # main window
  win = new BrowserWindow
    width: 900
    minWidth: 900
    height: 600
    show: false
    icon: nativeImage.createFromPath resolve __dirname, '..', 'style', 'ribas-icon.png'

  win.setMenu null

  # splash window
  new BrowserWindow(
    width: 400
    height: 200
    center: true
    resizable: false
    frame: false
    alwaysOnTop: true
    parent: win
    modal: true
    backgroundColor: '#c6c6c6'
  ).loadURL format
    pathname: resolve __dirname, '..', 'template', 'splash.html'
    protocol: 'file:'
    slashes: true

  # loads the index.html of the app.
  win.loadURL format
    pathname: resolve __dirname, '..', 'index.html'
    protocol: 'file:'
    slashes: true

  # emitted when the window is closed.
  win.on 'closed', () =>
    # Dereference the window object
    win = null

app.on 'ready', createWindow

# quit when all windows are closed.
app.on 'window-all-closed', () =>
  # on macOS it is common for applications and their menu bar
  # to stay active until the user quits explicitly with Cmd + Q
  app.quit() unless process.platform is 'darwin'

app.on 'activate', () =>
  # On macOS it's common to re-create a window in the app when the
  # dock icon is clicked and there are no other windows open.
  createWindow() unless win?
