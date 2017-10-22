_ = require 'underscore'
Storage = require '../service/storage'
Competition = require '../model/competition'
Ranking = require '../model/ranking'

storeName = 'storage'

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
module.exports = class IndexedDB extends Storage

  # Inner database
  db: null

  # Storage constructor
  constructor: () ->
    super name: 'IndexedDB'

  # **private**
  # Run a given process function that need database to be initialize.
  # Opens and initialize the database before if needed.
  #
  # @param process [Function] processing function, without any arguments
  # @param callback [Function] processing end function, invoked with arguments:
  # @option callback err [Error] an error object, or null if no error occured
  _runOrOpen: (process, callback) =>
    return process() if @db?
    request = window.indexedDB.open 'palmares'

    request.onsuccess = =>
      @db = request.result
      process()

    request.onerror = (event) =>
      @db =null
      callback request.error

    request.onupgradeneeded = =>
      @db = request.result
      objectStore = @db.createObjectStore storeName

  # @see Storage.has
  has: (key, callback = ->) =>
    # opens databse before if needed
    @_runOrOpen =>
      return callback new Error "no key provided" unless _.isString key
      # opens a read-only transaction
      tx = @db.transaction [storeName]

      # count number of object with this key (may be 0 or 1)
      request = tx.objectStore(storeName).count key

      # handle errors and success
      tx.onerror = -> callback tx.error
      tx.oncomplete = -> callback null, request.result isnt 0
    , callback

  # @see Storage.push
  push: (key, obj, callback = ->) =>
    # opens databse before if needed
    @_runOrOpen =>
      return callback new Error "no key provided" unless _.isString key
      return callback new Error "no value provided" unless obj?
      # opens a read-write transaction
      tx = @db.transaction [storeName], 'readwrite'

      # set the value for a given key
      request = tx.objectStore(storeName).put JSON.parse(JSON.stringify obj), key

      # handle errors and success
      tx.onerror = -> callback tx.error
      tx.oncomplete = -> callback null
    , callback

  # @see Storage.pop
  pop: (key, callback = ->) =>
    # opens databse before if needed
    @_runOrOpen =>
      return callback new Error "no key provided" unless _.isString key
      # opens a read-only transaction
      tx = @db.transaction [storeName]

      # get the value of a given key
      request = tx.objectStore(storeName).get key

      # handle errors and success
      tx.onerror = -> callback tx.error
      tx.oncomplete = -> callback null, rehydrate request.result
    , callback

  # @see Storage.remove
  remove: (key, callback = ->) =>
    # opens databse before if needed
    @_runOrOpen =>
      return callback new Error "no key provided" unless _.isString key
      # opens a read-only transaction
      tx = @db.transaction [storeName], 'readwrite'

      # get the value of a given key
      request = tx.objectStore(storeName).delete key

      # handle errors and success
      tx.onerror = -> callback tx.error
      tx.oncomplete = -> callback null
    , callback