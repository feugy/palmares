'use strict'

_ = require 'underscore'
async = require 'async'
{EventEmitter} = require 'events'
Ranking = require '../model/ranking'

# This service follows result of tracked couples
# For a given couple, it parsed all known competitions, and establish a list of rankings
# When a new competition is added, it updates if necessary results for the tracked couples
#
# The storage service is decoupled and provided within constructor.
# It triggers events `progress` while tracking couples with following arguments:
# @param state [String] `start`, `compRetrieved`, `compStart`, `compEnd`, `end`, depending on the state.
# @param details [Object] for `compRetrieved` the number of competitions, for `compStart` and `compEnd` the concerned competition. 
#
# The event `result` is also triggered when a new results are found, with arguments:
# @param ranking [Object] a Ranking model object
# @param competition [Object] a Competition modek object
module.exports = class PalmaresService extends EventEmitter

  # labels used inside the export. Expect to contains properties:
  # - appTitle: name of the application
  # - globalSheet: name used as sheet title for global export
  # - dateFormat: momentJS format used to export competition dates
  # - couple: Column title for couple names
  # - result: Column title for result
  # - contest: Column title for contest name
  # - lat: Column title for latine dances indicator
  # - std: Column title for standards dances indicator
  i18n: null

  # Storage service used. @see Storage
  storage: null

  # Array of competition providers used. @see Provider
  providers: []

  # list of tracked couples
  # for each couples, kept the following object:
  # - name [Sting] the couple name
  # - palmares [Object] associative array of competitions (competition id as key) that store the competition ranking array
  tracked: []

  # list of known competitions, were competition id is used as key
  competitions: {}

  # number of competition retreived in parallel, per providers
  limit: 3

  # Build a new service instance from a given storage service
  #
  # @param storage [Object] a Storage service instance.
  # @param providers [Array] array of providers used to get competitions. 
  # @param i18n [Object] labels used inside the export.
  constructor: (@storage, @providers, @i18n) ->
    # restore state from storage
    @storage.pop 'tracked', (err, value) =>
      console.error "failed to restore tracked couples: #{err}" if err?
      @tracked = value or []
    @storage.pop 'competitions', (err, value) =>
      console.error "failed to restore competitions: #{err}" if err?
      @competitions = value or {}
    # relay providers events 
    for provider in @providers
      provider.on 'progress', (args...) => @emit.apply @, ['progress'].concat args

  # Track new couples.
  # Will retrieve all known competitions to get the couple's result.
  # This heavy operation may takes some time
  #
  # @param couples [Array] array of new couples tracked. Couples that are already tracked are ignored
  # @param callback [Function] end callback. Invoked with arguments:
  # @option callback error [Error] an Error object, or null if no error occured
  # @option callback summary [Array] for each competition were tracked couples were involved, contains an object with fields:
  # - competition: the Competition object
  # - results: an array of Ranking objects, one for each involved couple
  track: (couples, callback) =>
    # remove already tracked couples
    couples = _.difference couples, _.pluck @tracked, 'name'
    return callback null, [] if couples.length is 0

    for couple, i in couples
      couples[i] = 
        name: couple
        palmares: {}
      @tracked.push couples[i]
    @tracked = _.sortBy @tracked, 'name'

    results = []

    end = (err) =>
      @emit 'progress', 'end', err
      return callback err if err?
      # Update storage
      @storage.push 'tracked', @tracked, (err) =>
        console.error "failed to add new tracked couples: #{err}" if err?
        callback null, results


    @emit 'progress', 'start'
    # reuse stored competitions if possible
    available = _.keys(@competitions)?.length
    if available > 0
      @emit 'progress', 'compRetrieved', num: available, name:(provider.opts.name for provider in @providers).join ' / '
      for id, competition of @competitions
        @emit 'progress', 'compStart', competition
        @_analyze couples, competition, results 
        @emit 'progress', 'compEnd', competition
      return _.defer end

    # or fetch all competition results of all providers
    async.each @providers, (provider, next) =>
      # get all competitions
      provider.listResults (err, competitions) =>
        return next err if err?
        @emit 'progress', 'compRetrieved', name: provider.opts.name, num: competitions.length
        # get all results
        async.eachLimit competitions, @limit, (competition, next) =>
          @emit 'progress', 'compStart', competition
          provider.getDetails competition, (err) =>
            return next err if err?
            # add competition for further reuse and analyze it
            @competitions[competition.id] = competition
            @_analyze couples, competition, results
            @emit 'progress', 'compEnd', competition
            next()
        , next
    , (err) =>
      return end err if err?
      # store competitions for further reuse
      @storage.push 'competitions', @competitions, (err) =>
        console.error "failed to update stored competitions: #{err}" if err?
        end()

  # Seek for new competitions.
  # If so, will search for tracked couples results.
  #
  # @param callback [Function] end callback. Invoked with arguments:
  # @option callback error [Error] an Error object, or null if no error occured
  # @option callback summary [Array] for each new competition were tracked couples were involved, contains an object with fields:
  # - competition: the Competition object
  # - results: an array of Ranking objects, one for each involved couple
  seekUpdates: (callback) =>
    # ids of already analyzed competitions
    existing = _.keys @competitions
    results = []
    newCompetitions = []
    @emit 'progress', 'start'
    # fetch all competition results of all providers
    async.each @providers, (provider, next) =>
      # get all competitions
      provider.listResults (err, competitions) =>
        return next err if err?
        # only keeps new competitions
        ids = _.difference _.pluck(competitions, 'id'), existing
        return next() unless ids.length
        # analyse the remaining competitions
        newCompetitions = _.filter(competitions, (c) -> c.id in ids)
        @emit 'progress', 'compRetrieved', name: provider.opts.name, num: newCompetitions.length
        async.eachLimit newCompetitions, @limit, (competition, next2) =>
          # get details
          @emit 'progress', 'compStart', competition
          provider.getDetails competition, (err) =>
            return next2 err if err?
            # keep competition
            @_analyze @tracked, competition, results 
            @emit 'progress', 'compEnd', competition
            next2()
        , next
    , (err) =>
      @emit 'progress', 'end', err
      return callback err if err?
      # nothing new.
      return callback null, [] if newCompetitions.length is 0

      # Update storage for new competitions
      @competitions[competition.id] = competition for competition in newCompetitions
      @storage.push 'competitions', @competitions, (err) =>
        console.error "failed to add new tracked couples: #{err}" if err?
        return callback null, [] if results.length is 0

        # Update storage for new couples results
        @storage.push 'tracked', @tracked, (err) =>
          console.error "failed to add new tracked couples: #{err}" if err?
          callback null, results

  # Return palmares of track couple, sort by competition date
  #
  # @param couple [String] concerned couple name
  # @param callback [Function] end callback. Invoked with arguments:
  # @option callback error [Error] an Error object, or null if no error occured
  # @option callback summary [Array] for each competition were the couple is involved, contains an object with fields:
  # - competition: the Competition object
  # - results: an array of one Ranking object.
  palmares: (couple, callback) =>
    details = _.find @tracked, (c) -> c.name is couple
    return callback new Error "couple #{couple} is not tracked" unless details?
    # enrich stored palmares with competitions data
    palmares = []
    for id, results of details.palmares
      palmares.push 
        competition: @competitions[id]
        results: results
    callback null, palmares.sort (r1, r2) -> r2.competition.date.unix() - r1.competition.date.unix()

  # Returns available competitions
  #
  # @return available competitions
  getCompetitions: =>
    _.chain(@competitions).values().sortBy('date').value().reverse()

  # Removes a competition from provider, making it elligible to further updates
  #
  # @param id [String] removed competition's id
  # @param callback [Function] end callback. Invoked with arguments:
  # @option callback error [Error] an Error object, or null if no error occured
  removeCompetition: (id, callback) =>
    return callback null unless id of @competitions
    delete @competitions[id]
    @storage.push 'competitions', @competitions, (err) =>
      console.error "failed to remove competition #{id}: #{err}" if err?
      return callback null

  # Export global palmares to XlsX.js compliant format.
  # Each competition is summarized with all related couples and their rankings
  #
  # @param callback [Function] end callback. Invoked with arguments:
  # @option callback error [Error] an Error object, or null if no error occured
  # @option callback xlsx [Array] XlsX.js compliant content, with global palmares
  export: (callback) =>
    # takes all tracked details
    couples = @tracked

    xlsx = 
      creator: @i18n.appTitle
      lastModifiedBy: @i18n.appTitle
      worksheets: []

    # creates the global sheet
    sheet = 
      name: @i18n.globalSheet
      data: []
    xlsx.worksheets.push sheet

    # list competition by date
    for competition in _.values(@competitions).sort((c1, c2) -> c1.date.unix() - c2.date.unix())
      # is their any related couples ?
      results = _.flatten (couple.palmares[competition.id] for couple in couples when competition.id of couple.palmares)
      if results.length
        results = _.sortBy results, 'contest'
        sheet.data.push ['', competition.place, competition.date.format @i18n.dateFormat], [], ['', @i18n.couple, @i18n.result, @i18n.contest, @i18n.lat, @i18n.std]
        for result in results
          [lat, std] = ['', 'x']
          [lat, std] = ['x', ''] if result.kind is 'lat'
          sheet.data.push ['', result.couple, "#{result.rank}/#{result.total}", result.contest, lat, std]
        sheet.data.push []

    callback null, xlsx

  # Remove couples from the tracked list.
  # If some couple was not track, does not fail.
  #
  # @param names [Array] concerned couple names
  # @param callback [Function] end callback. Invoked with arguments:
  # @option callback error [Error] an Error object, or null if no error occured
  untrack: (names, callback) =>
    for name in names
      for couple, i in @tracked when couple.name is name
        @tracked.splice i, 1
        break
    # Update storage
    @storage.push 'tracked', @tracked, (err) =>
      console.error "failed to remove tracked couples: #{err}" if err?
      callback null

  # **private**
  # Analyze a given competition to enrich the specified couples' palmared
  # 
  # @param couples [Array] array of couples, contains for each of them an object with:
  # @option couples name [String] the couple name
  # @option couples palmares [Object] associative array of competitions (competition id as key) that store the competition ranking array
  # @param competition [Object] the analyzed competition with its contests valued
  # @param results [Object] array of results, enrich (if at least one ranking is found) with an object containing:
  # @option results competition [Object] the analysed competition
  # @option results results [Array] array of found rankings
  _analyze: (couples, competition, results) =>
    rankings = []
    # search for couples involvment within competition's contest
    for contest in competition.contests
      # look into the last heat result, where all contest's competitors are listed
      total = _.keys(contest.results).length
      continue if total is 0
      kind = if /standard/i.test contest.title then 'std' else 'lat'
      for couple in couples when couple.name of contest.results
        # to find rank, walk down from the final
        couple.palmares[competition.id] = [] unless competition.id of couple.palmares
        ranking = new Ranking 
          couple: couple.name
          kind: kind
          contest: contest.title
          rank: contest.results[couple.name]
          total: total
        couple.palmares[competition.id].push ranking
        @emit 'result', ranking, competition
        # keep track of new rankings
        rankings.push ranking 
    results.push competition: competition, results: rankings unless rankings.length is 0