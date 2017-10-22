# to use _.string also
_ = require 'underscore'
util = require '../util/common'
{EventEmitter} = require 'events'

# Abstract class for providers
module.exports = class Provider extends EventEmitter

  # Current year
  currYear: null

  # Provider configuration options. @see constructor
  opts = {}

  # Provider constructor: initialize with configuration
  #
  # @param opts [Object] provider configuration. Must contains:
  # @option opts name [String] the provider name, for error messages
  # @option opts url [String] website root url
  # @option opts list [String] web page to list results
  # @option opts dateFormat [String] moment format used to extract dates
  constructor: (@opts) ->
    super()
    @setMaxListeners 0
    # check configuration options
    throw new Error "missing 'name' property in provider configuration" unless _.has @opts, 'name'
    throw new Error "missing 'url' property in #{@opts.name} configuration" unless _.has @opts, 'url'
    throw new Error "missing 'list' property in #{@opts.name} configuration" unless _.has @opts, 'list'
    throw new Error "missing 'dateFormat' property in #{@opts.name} configuration" unless _.has @opts, 'dateFormat'
    @currYear = util.confKey 'year'
    # reload year if needed
    util.on 'confChanged', => @currYear = util.confKey 'year'

  # Provide a custom sync method to extract competitions over the internet.
  # Only read operation is supported.
  #
  # @param callback [Function] end callback, invoked with arguments:
  # @option callback err [String] an error object or null if no error occured
  # @option callback results [Array] list of competitions extracted (may be empty).
  listResults: (callback = ->) =>
    callback new Error "#{@opts.name} does not implement the 'listResults' feature"

  # Load details for a given competition.
  # It list the competition's contests, and for each contests, couple ranking.
  # The competition's contests array will be filled once finished.
  #
  # @param competition [Object] the loaded competition
  # @param callback [Function] end callback, invoked with arguments:
  # @option callback err [String] an error object or null if no error occured
  getDetails: (competition, callback) =>
    callback new Error "#{@opts.name} does not implement the 'getDetails' feature"

  # Get a list (that may be empty) of group names that contains the searched string.
  # Depending on the provider, a group is a club or a country, and wildcards may be supported.
  #
  # @param searched [String] searched string
  # @param callback [Function] end callback, invoked with arguments:
  # @option callback err [Error] an error object or null if no error occured
  # @options callback couples [array] list of strings containing the club names (may be empty).
  searchGroups: (searched, callback) =>
    callback new ERror "#{@opts.name} does not implement the 'searchClubs' feature"

  # Get a list (that may be empty) of couples were one of the dancers name contains the searched string.
  # Depending on the provider, wildcards may be supported, and search may apply on fisrt name, last name or both.
  #
  # @param searched [String] searched string
  # @param callback [Function] end callback, invoked with arguments:
  # @option callback err [Error] an error object or null if no error occured
  # @options callback couples [array] list of strings containing the couple names (may be empty).
  searchCouples: (searched, callback) =>
    callback new ERror "#{@opts.name} does not implement the 'searchCouples' feature"

  # Get the list of all active couples for a given group.
  # Depending on the provider, a group may represent a club or a country.
  #
  # @param group [String] the concerned club or country.
  # @param callback [Function] end callback, invoked with arguments:
  # @option callback err [Error] an error object or null if no error occured
  # @option callback couples [Array] list of strings containing the couple names (may be empty).
  getGroupCouples: (group, callback) =>
    callback new Error "#{@opts.name} does not implement the 'getGroupCouples' feature"