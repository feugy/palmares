_ = require 'underscore'

# Storage is an interface to store and retrieve JSON structures
# Works as a persistent hashmap.
module.exports = class Storage

  # Storage configuration options. @see constructor
  opts = {}

  # Storage constructor: initialize with configuration
  #
  # @param opts [Object] provider configuration. Must contains:
  # @option opts name [String] the storage name, for error messages
  constructor: (@opts) ->
    # check configuration options
    throw new Error "missage storage configuration" unless _.isObject @opts
    throw new Error "missing 'name' property in provider configuration" unless _.has @opts, 'name'

  # Check the existence of a given key.
  #
  # @param key [String] searched key
  # @param callback [Function] end callback, invoked with arguments:
  # @option callback err [Error] an Error object, or null if no error occured
  # @option callback exists [Boolean] true if the key exists, false otherwise
  has: (key, callback) =>
    callback new Error "#{@opts.name} does not implement the 'has' feature"

  # Store an object under a given key.
  #
  # @param key [String] storage key
  # @param obj [Object] the stored object
  # @param callback [Function] end callback, invoked with arguments:
  # @option callback err [Error] an Error object, or null if no error occured
  push: (key, obj, callback) =>
    callback new Error "#{@opts.name} does not implement the 'push' feature"

  # Retrieve an object from its key.
  #
  # @param key [String] searched key
  # @param callback [Function] end callback, invoked with arguments:
  # @option callback err [Error] an Error object, or null if no error occured
  # @option callback obj [Object] the corresponding stored object, or undefined
  pop: (key, callback) =>
    callback new Error "#{@opts.name} does not implement the 'pop' feature"

  # Removed an object by its.
  #
  # @param key [String] removed key
  # @param callback [Function] end callback, invoked with arguments:
  # @option callback err [Error] an Error object, or null if no error occured
  remove: (key, callback) =>
    callback new Error "#{@opts.name} does not implement the 'remove' feature"