_ = require 'underscore'
fs = require 'fs'
moment = require 'moment'

# Format a given value as a string.
# @param value [Any] - the value formated
# @returns [String] the formated equivalent
format = (value) ->
  if _.isArray value then value.map(format).join ', '
  else if _.isError value then value.stack
  else if _.isObject value then JSON.stringify value, null, 2
  else value

# Write 'asynchronously) a trace line in log file
# @param level [String] - level output
# @param args [Array] - arguments used to output
trace = (level, args) ->
  fs.appendFile 'log.txt', "#{moment().format 'DD/MM/YYYY HH:mm:ss'} - #{level} - #{args.map(format).join ' '}\n"

# Export a console like API to output message
module.exports =
  log: (args...) -> trace 'DEBUG', args
  error: (args...) -> trace 'ERROR', args
