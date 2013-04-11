'use strict'

yaml = require 'js-yaml'
fs = require 'fs-extra'
pathUtils = require 'path'
_ = require 'underscore'
EventEmitter = require('events').EventEmitter
_.str = require 'underscore.string'
_.mixin _.str.exports()

# use an event emitter to propagate configuration changes
emitter = new EventEmitter()
emitter.setMaxListeners 0

# read configuration file
conf = null
confPath = pathUtils.resolve __dirname, pathUtils.join '..', '..', 'conf', "#{if process.env.NODE_ENV then process.env.NODE_ENV else 'dev'}-conf.yml"
parseConf = ->
  try 
    conf = yaml.load fs.readFileSync confPath, 'utf-8'
  catch err
    throw new Error "Cannot read or parse configuration file '#{confPath}': #{err}"
parseConf()

# read again if file is changed
fs.watch confPath, ->
  parseConf()
  emitter.emit 'confChanged'

# This method is intended to replace the broken typeof() Javascript operator.
#
# @param obj [Object] any check object
# @return the string representation of the object type. One of the following:
# object, boolean, number, string, function, array, date, regexp, undefined, null
#
# @see http://bonsaiden.github.com/JavaScript-Garden/#types.typeof
emitter.type = (obj) -> Object::toString.call(obj).slice(8, -1)?.toLowerCase() or 'undefined'

# isA() is an utility method that check if an object belongs to a certain class, or to one 
# of it's subclasses. Uses the classes names to performs the test.
#
# @param obj [Object] the object which is tested
# @param clazz [Class] the class against which the object is tested
# @return true if this object is a the specified class, or one of its subclasses. false otherwise
emitter.isA = (obj, clazz) ->
  return false if not (obj? and clazz?)
  currentClass = obj.constructor
  while currentClass?
    return true if currentClass.name.toLowerCase() is clazz.name.toLowerCase()
    currentClass = currentClass.__super__?.constructor
  false

# Read a configuration key inside the YAML configuration file (utf-8 encoded).
# At first call, performs a synchronous disk access, because configuraiton is very likely to be read
# before any other operation. The configuration is then cached.
# 
# The configuration file read is named 'xxx-conf.yaml', where xxx is the value of NODE_ENV (dev if not defined) 
# and located in a "conf" folder under the execution root.
#
# @param key [String] the path to the requested key, splited with dots.
# @param def [Object] the default value, used if key not present. 
# If undefined, and if the key is missing, an error is thrown.
# @return the expected key.
emitter.confKey = (key, def) -> 
  path = key.split '.'
  obj = conf
  last = path.length-1
  for step, i in path
    unless step of obj
      # missing key or step
      throw new Error "The #{key} key is not defined in the configuration file #{confPath}" if def is undefined
      return def
    unless i is last
      # goes deeper
      obj = obj[step]
    else 
      # last step: returns value
      return obj[step]

module.exports = emitter