'use strict'

_ = require 'underscore'
Storage = require '../service/storage'
Competition = require '../model/competition'
Ranking = require '../model/ranking'

# Walk within the plain JSON and build competitions and rankings if needed
#
# @param obj [Object] plain JSON analyzed
# @return the rehydrated version
rehydrate = (obj) ->
  if _.isArray obj
    return (rehydrate value for value in obj)
  if _.isObject obj
    return new Competition obj if 'id' of obj and 'place' of obj
    return new Ranking obj if 'couple' of obj and 'rank' of obj
    obj[key] = rehydrate value for key, value of obj
  obj

# Provide storage implementation using browser's LoclaeStorage object
# All stored data is stored as string and must be parsed
module.exports = class LocaleStorage extends Storage

  # Storage constructor
  constructor: () ->
    super name: 'LocalStorage'

  # @see Storage.has
  has: (key, callback = ->) =>
    return callback new Error "no key provided" unless _.isString key
    callback null, key of window.localStorage

  # @see Storage.push
  push: (key, obj, callback = ->) =>
    return callback new Error "no key provided" unless _.isString key
    return callback new Error "no value provided" unless _.isObject obj
    window.localStorage.setItem key, if _.isFunction obj.toJSON then obj.toJSON() else JSON.stringify obj
    callback null

  # @see Storage.pop
  pop: (key, callback = ->) =>
    return callback new Error "no key provided" unless _.isString key
    obj = window.localStorage.getItem key
    obj = rehydrate JSON.parse obj if obj?
    callback null, obj