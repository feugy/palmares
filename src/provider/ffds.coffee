_ = require 'underscore'
async = require 'async'
request = require 'request'
moment = require 'moment'
cheerio = require 'cheerio'
md5 = require 'md5'
Provider = require './provider'
Competition = require '../model/competition'
util = require '../util/common'

# Make names to begin with first name, without accentuated letters and capitalized.
#
# @param names [String] contains html text with dancers names, separated by a <br> tag
# @return the correctly formated name string
cleanNames = (names) ->
  return "couple inconnu" if /couple inconnu/.test names.toLowerCase()
  # split both dancers
  dancers = names.split '<br>'
  results = []
  for dancer in dancers
    # remove remaining html
    dancer = _.stripTags dancer
    # extract first name (always in upper cas)
    last = ''
    first = ''
    prevUpper = false
    for char, i in dancer
      code = dancer.charCodeAt i
      # Uppercase symbol
      # A: 65 Z: 90 À: 192 Ý: 221
      if 65 <= code <= 90 or 192 <= code <= 221
        last += char
        prevUpper = true
      # Separation symbol
      # ': 39 -: 45 ' ':32
      else if code in [32, 39, 45]
        if prevUpper
          last += char
        else
          first += char
        prevUpper = false
      # Lowercase symbol
      else
        if prevUpper
          last = last[0...last.length-1]
          first += dancer[i-1..i]
          prevUpper = false
        else
          first += char
    # capitalize and remove accentuated letters
    results.push "#{util.removeAccents first} #{util.removeAccents last}"
  "#{_.titleize results[0]} - #{_.titleize results[1]}"

# Remove useless information from contest titles
#
# @param original [String] original contest title
# @return its cleanned version
cleanContest = (original) ->
  original.replace('Compétition à points', '').replace('Compétition sans points', '').trim()

# Check if a date is first half of the year (before august 14th, included)
#
# @param date [Moment] checked date
# @return true if this date is before august 14th, included, false otherwise
isFirstHalf = (date) ->
  date?.month() < 7 or date?.month() is 7 and date?.date() <= 14

# Check if a given year match current season, or is archive
#
# @param year [Number] current season year, always smaller (one from september)
# @param date [Moment] checked date
# @return true if date is current year and in second half, or if date is next year and first half
isWithinSeason = (year, date) ->
  (year is date?.year() and not isFirstHalf date) or (year+1 is date?.year() and isFirstHalf date)

# Extract national competitions from the Ballroom Dancing National Federation
module.exports = class FFDSProvider extends Provider

  # Club list, to avoid asking too many time them
  clubs: null

  # Provider constructor: initialize with configuration
  # For mandatory options, @see Provider.constructor
  #
  # @param opts [Object] provider configuration. Must contains:
  # @option opts clubs [String] url to list exsting clubs
  # @option opts couples [String] url to list couples of a given club
  # @option opts details [String] url to get competition details
  # @option opts search [String] url to search for couples
  constructor: (opts) ->
    super opts
    throw new Error "missing 'clubs' property in provider configuration" unless _.has @opts, 'clubs'
    throw new Error "missing 'couples' property in provider configuration" unless _.has @opts, 'couples'
    throw new Error "missing 'details' property in provider configuration" unless _.has @opts, 'details'
    throw new Error "missing 'search' property in provider configuration" unless _.has @opts, 'search'
    @clubs = null

  # @see Provider.listResults()
  listResults: (callback = ->) =>
    url = "#{@opts.url}/#{@opts.list}#{if isWithinSeason @currYear, moment() then '' else '?Archives'}"
    # performs itself the request
    request
      # to avoid encoding problems
      encoding: 'binary'
      url: url
      proxy: util.confKey 'proxy', ''
    , (err, res, body) =>
      if !(err?) and res?.statusCode isnt 200
        err = new Error "failed to fetch results from '#{@opts.name}': #{res.statusCode}\n#{body}"
      return callback err if err?
      # extract competiton headers for each lines
      $ = cheerio.load util.replaceUnallowed(body.toString()), decodeEntities: false
      competitions = []

      for line in $ 'table#tosort > tbody > tr'
        @_extractHeader $(line), competitions
      return callback null, _.sortBy competitions, 'date'

  # @see Provider.getDetails()
  getDetails: (competition, callback) =>
    return callback new Error "No details url in competition '#{@opts.name} #{competition.place}'" unless competition.dataUrls?.length > 0
    urls = []
    # request contests list, for each known urls
    async.eachSeries competition.dataUrls, (url, next) =>
      request
        # to avoid encoding problems
        encoding: 'binary'
        url: url
        proxy: util.confKey 'proxy', ''
      , (err, res, body) =>
        if !(err?) and res?.statusCode isnt 200
          err = new Error "failed to fetch contests from '#{@opts.name} #{competition.place}': #{res.statusCode}\n#{body}"
        return next err if err?

        # extract contests ranking ids
        $ = cheerio.load util.replaceUnallowed(body.toString()), decodeEntities: false
        urls = urls.concat ("#{@opts.url}/#{$(link).attr 'href'}" for link in $ 'td > a')
        next()
    , (err) =>
      return callback err if err?
      # no contests yet
      return callback null unless urls.length
      competition.contests = []
      urls = _.uniq urls

      @emit 'progress', 'contestsRetrieved', competition: competition, total: urls.length
      # get all contests rankings
      async.eachSeries urls, (url, next) =>
        @_extractRanking competition, url, next
      , callback

  # @see Provider.searchGroups()
  searchGroups: (searched, callback) =>
    searched = searched?.trim().toLowerCase() or ''

    # once clubs were retireved, search inside
    search = =>
      # evaluate levenshtein distance for each club names
      callback null, _.chain(@clubs).filter((club) -> -1 isnt club.name.toLowerCase().indexOf searched).pluck('name').value()

    # immediately search if clubs are available
    return _.defer search if @clubs?

    # get club ids and names
    request
      # to avoid encoding problems
      encoding: 'binary'
      url: "#{@opts.url}/#{@opts.clubs}"
      proxy: util.confKey 'proxy', ''
    , (err, res, body) =>
      if !(err?) and res?.statusCode isnt 200
        err = new Error "failed to fetch club list from '#{@opts.name}': #{res.statusCode}\n#{body}"
      return callback err if err?
      # extract club ids and names and store it in memory
      $ = cheerio.load util.replaceUnallowed(body.toString()), decodeEntities: false
      @clubs = (id: $(club).attr('value'), name: $(club).text().trim() for club in $ '[name=club_id] option')
      search()

  # @see Provider.getCouples()
  getGroupCouples: (group, callback) =>
    group = group.toLowerCase().trim()

    # once clubs were retireved, search inside
    search = =>
      # get club id
      club = _.find @clubs, (club) -> club.name.toLowerCase() is group
      return callback new Error "no group found with name #{group}" unless club?
      # now get its couples
      request
        # to avoid encoding problems
        encoding: 'binary'
        url: _.sprintf "#{@opts.url}/#{@opts.couples}", club.id
        proxy: util.confKey 'proxy', ''
      , (err, res, body) =>
        if !(err?) and res?.statusCode isnt 200
          err = new Error "failed to fetch couple list from '#{@opts.name}' #{club.name}: #{res.statusCode}\n#{body}"
        return callback err if err?
        @_extractNames body, callback

    # immediately search if clubs are available, populate clubs with empty search otherwise
    return _.defer search if @clubs?
    @searchGroups '', search


  # @see Provider.searchCouples()
  searchCouples: (searched, callback) =>
    request
      # to avoid encoding problems
      encoding: 'binary'
      url: _.sprintf "#{@opts.url}/#{@opts.search}", encodeURIComponent searched.toUpperCase()
      proxy: util.confKey 'proxy', ''
    , (err, res, body) =>
      if !(err?) and res?.statusCode isnt 200
        err = new Error "failed to search couples from '#{@opts.name}': #{res.statusCode}\n#{body}"
      return callback err if err?
      @_extractNames body, callback

  # **private**
  # Extract couple names from a club or search result Html response
  #
  # @param body [String] the Html response
  # @param callback [Function] end callback, invoked with arguments:
  # @option callback err [Error] an error object or null if no error occured
  # @options callback couples [array] list of strings containing the couple names (may be empty).
  _extractNames: (body, callback) =>
    couples = []
    $ = cheerio.load util.replaceUnallowed(body.toString()), decodeEntities: false
    for couple in $ '#tosort tbody tr'
      couple = $(couple)
      # ignore inactive couples
      #if couple.find('td:last-child').text() is 'Oui'
      try
        couples.push cleanNames couple.find('td:first-child').text().trim().replace ' / ', '<br>'
      catch exc
        return callback new Error "failed to parse couple names '#{names}': #{exc}"
    # return results
    callback null, couples

  # **private**
  # Extract a competition header (place, date, url) from incoming Html
  # Ignore competitions whose date is not in current season
  # If multiple competitions are found at the same date and place, enrich existing competition to ensure uniquness
  #
  # @param line [Object] cheerio object of incoming Html
  # @param competitions [Array<Competition>] extracted competitions, enriched by this method
  _extractHeader: (line, competitions) =>
    # extract id to consult details
    id = line.find('td:last-child a')?.attr('href')?.match(/NumManif=(\d+)$/)?[1]
    return null unless id?
    data =
      place: _.titleize line.find('td').eq(0).text().trim().toLowerCase()
      date: moment line.find('td').eq(1).text(), @opts.dateFormat
      url: _.sprintf "#{@opts.url}/#{@opts.details}", id
      provider: 'ffds'
    # removes parenthesis information if present
    data.place = data.place.replace(/\(\s*\w+\s*\)/, '').trim()
    # id is date append to place lowercased without non-word characters.
    data.id = md5 "#{_.slugify data.place}#{data.date.format 'YYYYMMDD'}"
    # only keep competition in current year after mid august, or next year before mid august
    return unless isWithinSeason @currYear, data.date
    # search for existing competition with same url
    existing = _.findWhere competitions, id: data.id
    unless existing?
      # do not add twice the same competition
      competitions.push new Competition data
    else unless data.url in existing.dataUrls
      # Merge urls if needed
      existing.dataUrls.push data.url

  # **private**
  # Extract a competition's contest ranking from contest's id.
  # The competition's contests attribute will be added extracted ranking
  #
  # @param competition [Object] concerned competition
  # @param url [String] full url of the contest ranking
  # @param callback [Function] end callback, invoked with arguments:
  # @option callback err [String] an error object or null if no error occured
  _extractRanking: (competition, url, callback) =>
    request
      # to avoid encoding problems
      encoding: 'binary'
      url: url
      proxy: util.confKey 'proxy', ''
    , (err, res, body) =>
      # http error for the contest detail
      if !(err?) and res?.statusCode isnt 200
        err = new Error  new Error "failed to fetch contest ranking from '#{@opts.name} #{competition.place}': #{res.statusCode}\n#{body}"
      return callback new Error "error on contest #{url}: #{err}" if err?

      body = util.replaceUnallowed body.toString()
      # remove errored divs
      body = body.replace /<\/div><\/th>/g, '</th>'
      # extract ranking
      $ = cheerio.load body, decodeEntities: false
      results = {}
      title = cleanContest $('h3').text()
      # for each heat (first is final)
      for heat in $ '.portlet'
        for row in $(heat).find 'tbody > tr'
          try
            names = cleanNames $(row).find('td:nth-child(3)').html()
          catch exc
            return callback new Error "failed to parse '#{competition.place}' '#{title}' heat #{i*2} names '#{names}': #{exc}"
          results[names] = parseInt $(row).find('td:nth-child(1)').text() unless names of results

      competition.contests.push
        # competition's title
        title: title
        results: results
      @emit 'progress', 'contestEnd', competition: competition, done: competition.contests.length
      callback null
