'use strict'

_ = require 'underscore'
Storage = require '../service/storage'

# Provide an in-memory storage implementation
# All stored data is kept with the MemoryStorage instance and will be lost with it
module.exports = class MemoryStorage extends Storage

  # In-memory storage
  store: {}

  # Storage constructor: initialize with configuration
  # For mandatory options, @see Storage.constructor
  #
  # @param opts [Object] provider configuration. Must contains:
  # @option opts clubs [String] url to list exsting clubs
  # @option opts couples [String] url to list couples of a given club
  constructor: (opts) ->
    super opts
    @store = {}

  # @see Storage.has
  has: (key, callback = ->) =>
    return callback new Error "no key provided" unless _.isString key
    callback null, key of @store

  # @see Storage.push
  push: (key, obj, callback = ->) =>
    return callback new Error "no key provided" unless _.isString key
    return callback new Error "no value provided" unless _.isObject obj
    @store[key] = obj
    callback null


  # @see Storage.pop
  pop: (key, callback = ->) =>
    return callback new Error "no key provided" unless _.isString key
    callback null, @store[key]