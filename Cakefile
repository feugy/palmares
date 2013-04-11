# Cakefile used to provide a portable build and test system.
# The only requirement is to have Coffee-script globally installed, 
# and to have retrieved the npm dependencies with `npm install`
#
# Available tasks: 
# * start - starts the application
# * build - compiles coffee-script from data/src to data/content
# * test - runs all tests with mocha (configuration in test/mocha.opts)
# * clean - removed lib folder
fs = require 'fs-extra'
_ = require 'underscore'
{join} = require 'path'
{spawn} = require 'child_process'
isWin = process.platform.match(/^win/)?

task 'start', 'start the application', -> 
  return console.error "Only supported on windows for now... :-(" unless isWin
  app = spawn join('bin', 'nw.exe'), [__dirname], stdio: 'inherit'
  app.on 'exit', process.exit

task 'build', 'compile source files', ->
  # moves vendor files
  fs.copy 'vendor', 'lib' , ->
    # compiles coffee-script
    _launch 'coffee', ['-c', '-b', '-o', 'lib', 'src'], {}, ->
      fs.remove '-p' if isWin
      # compiles stylus
      _launch 'stylus', ['-o', 'lib', 'style']

task 'test', 'run tests with mocha', -> 
  _launch 'mocha', [], {NODE_ENV: 'test'}

task 'clean', 'removes lib folder', -> 
  fs.remove 'lib'

_launch = (cmd, options=[], env={}, callback) ->
  # look into node_modules to find the command
  cmd = "#{cmd}.cmd" if isWin
  cmd = join 'node_modules', '.bin', cmd
  # spawn it now, useing modified environement variables and caller process's standard input/output/error
  app = spawn cmd, options, stdio: 'inherit', env: _.extend({}, process.env, env)
  # invoke optionnal callback if command succeed
  app.on 'exit', (code) -> 
    return callback() if code is 0 and callback?
    process.exit code