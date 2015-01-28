'use strict'

{safeDump, safeLoad} = require 'js-yaml'
fs = require 'fs-extra'
moment = require 'moment'
{resolve, join} = require 'path'
_ = require 'underscore'
EventEmitter = require('events').EventEmitter
_.str = require 'underscore.string'
_.mixin _.str.exports()
env = process.env.NODE_ENV?.trim()?.toLowerCase() or 'dev'

# use an event emitter to propagate configuration changes
emitter = new EventEmitter()
emitter.setMaxListeners 0

# read configuration file from application folder
conf = null

if env is 'test'
  confPath = resolve __dirname, join '..', '..', 'conf', "#{env}-conf.yml"
else
  confPath = join gui.App.dataPath, 'conf', "#{env}-conf.yml"

parseConf = ->
  try 
    conf = safeLoad fs.readFileSync confPath, 'utf-8'
  catch err
    throw new Error "Cannot read or parse configuration file '#{confPath}': #{err}"
parseConf()

# read again if file is changed
fs.watch confPath, ->
  parseConf()
  console.log 'configuration changed !'
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
# At first call, performs a synchronous disk access, because configuration is very likely to be read
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

# Save a configuration key inside the YAML configuration file (utf-8 encoded).
# Performs a synchronous disk access, because configuration changes are very likely to be blockant for the rest of the execution.
# 
# A `confChanged` event is triggered
#
# @param key [String] the path to the requested key, splited with dots.
# @param value [Object] the new value. Undefined to unset the key
# @return the expected key.
emitter.saveKey = (key, value) ->
  path = key.split '.'
  obj = conf
  last = path.length-1
  for step, i in path
    # add missing objects
    obj[step] = {} unless step of obj or i is last
      
    if i is last
      # last step: set value
      if value is undefined
        delete obj[step]
      else
        obj[step] = value
    else
      # goes deeper
      obj = obj[step]

  # synchronously save configuration
  try 
    fs.writeFileSync confPath, safeDump(conf), 'utf-8'
  catch err
    throw new Error "Cannot write configuration file '#{confPath}': #{err}"

# Lowerize and replace accentuated letters by their equivalent
#
# @param str [String] the replaced string
# @return its lowercase accent-free version
emitter.removeAccents = (str) ->
  str = str.toLowerCase().trim()
  (for char, i in str
    code = str.charCodeAt i
    # 224~230: àáâãäåæ, 257: ā, 259: ă, 261: ą
    if 224 <= code <= 230 or code in [257, 259, 261]
      char = 'a'
    # 231: ç, 263: ć, 265: ĉ, 267: ċ, 269: č,
    else if code in [231, 263, 265, 267]
      char = 'c'
    # 240: ð, 271: ď, 273: đ
    else if code in [240, 271, 273]
      char = 'd'
    # 232~235: èéêë, 275: ē, 277: ĕ, 279: ė, 281: ę, 283: ě 
    else if 232 <= code <= 235 or code in [275, 277, 279, 281, 283]
      char = 'e'
    # 285: ĝ, 287: ğ, 289: ġ, 291: ģ
    else if code in [285, 287, 289, 291]
      char = 'g'
    # 293: ĥ, 295: ħ
    else if code in [293, 295]
      char = 'h'
    # 236~239: ìíîï, 297: ĩ, 299: ī, 301: ĭ, 303: į, 305: ı
    else if 236 <= code <= 239 or code in [297, 301, 303, 305]
      char = 'i'
    # 307: ĳ, 309: ĵ
    else if code in [307, 309]
      char = 'j'
    # 311: ķ, 312: ĸ
    else if code in [311, 312]
      char = 'k'
    # 314: ĺ, 316: ļ, 318: ľ, 320: ŀ, 322: ł 
    else if code in [314, 316, 318, 320, 322]
      char = 'l'
    # 241: ñ, 324: ń, 326: ņ, 328: ň, 329: ŉ, 331: ŋ
    else if code in [241, 324, 326, 328, 329, 331]
      char = 'n'
    # 242~246: òóôõö, 333: ō, 335: ŏ, 337: ő, 339: œ
    else if 242 <= code <= 246 or code in [333, 335, 337, 339]
      char = 'o'
    # 341: ŕ, 343: ŗ, 345: ř 
    else if code in [331, 343, 345]
      char = 'r'
    # 347: ś, 349: ŝ, 351: ş, 353: š
    else if code in [347, 349, 351, 353]
      char = 's'
    # 355: ţ, 357: ť, 359: ŧ
    else if code in [355, 357, 359]
      char = 't'
    # 249~252: ùúûü, 361: ũ, 363: ū, 365: ŭ, 367: ů, 369: ű, 371: ų
    else if 249 <= code <= 252 or code in [361, 363, 365, 367, 369, 371]
      char = 'u'
    # 253: ý, 375: ŷ
    else if code in [253, 375]
      char = 'y'
    # 378: ź, 380: ż, 382: ž
    else if code in [378, 381, 383]
      char = 'z'
    char
  ).join ''
  
# Replace unallowed character from incoming http response, to avoid breaking the further storage.
# The replacement character is a space.
#
# @param body [String] analyzed body
# @return the modified body without unallowed characters
emitter.replaceUnallowed = (body) ->
  for i in [0...body.length]
    code = body.charCodeAt i
    body = "#{body[0...i]} #{body[i+1...body.length]}" if 127 <= code <= 191
  body

# Debugger function
emitter.check = (body, competition) ->
  body = body.toString()
  for i in [0...body.length]
    code = body.charCodeAt i
    continue if code in [9, 10, 13] or 192 <= code <= 255 or 32 <= code <= 126 
    console.log "> competition #{competition.id} #{competition.place}:", code, body[i]

module.exports = emitter