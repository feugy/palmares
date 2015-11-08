'use strict'

_ = require 'underscore'
async = require 'async'
request = require 'request'
moment = require 'moment'
csv = require 'csv'
md5 = require 'md5'
cheerio = require 'cheerio'
Provider = require './provider'
Competition = require '../model/competition'
util = require '../util/common'

# Extract national competitions from the Ballroom Dancing National Federation
module.exports = class WDSFProvider extends Provider

  # Provide a custom sync method to extract competitions over the internet.
  # Only read operation is supported.
  #
  # @param callback [Function] end callback, invoked with arguments:
  # @option callback err [String] an error object or null if no error occured
  # @option callback results [Array] list of competitions extracted (may be empty).
  listResults: (callback = ->) =>
    # performs itself the request
    request
      # to avoid encoding problems
      url: _.sprintf "#{@opts.url}/#{@opts.list}", @currYear, @currYear+1
      proxy: util.confKey 'proxy', ''
    , (err, res, body) =>
      if !(err?) and res?.statusCode isnt 200
        err = new Error "failed to fetch results from '#{@opts.name}': #{res.statusCode}\n#{body}"
      return callback err if err?
      # parse csv content
      competitions = []
      parser = csv.parse()
      parser.on('readable', =>
          @_extractHeader record, competitions while record = parser.read()
        )
        .on('finish', =>
          callback null, _.sortBy competitions, 'date'
        )
        .on 'error', callback
      parser.write body.toString()
      parser.end()

  # @see Provider.getDetails()
  getDetails: (competition, callback) =>
    return callback new Error "No details url in competition '#{@opts.name} #{competition.place}'" unless competition.dataUrls?.length > 0
    urls = []
    # request contests list, for each known urls
    async.eachSeries competition.dataUrls, (url, next) =>
      request
        url: url
        proxy: util.confKey 'proxy', ''
      , (err, res, body) =>
        if !(err?) and res?.statusCode isnt 200
          err = new Error "failed to fetch contests from '#{@opts.name} #{competition.place}': #{res.statusCode}\n#{body}"
        return next err if err?
        # extract contests ranking ids
        $ = cheerio.load util.replaceUnallowed(body.toString()), decodeEntities: true
        # find competition list for the competition date only
        for day, i in $ '.competitionList > h3' when competition.date.isSame moment $(day).text(), 'D MMMM YYYY'
          urls = urls.concat ("#{@opts.url}#{$(link).attr 'href'}" for link in $ ".competitionList table:nth-of-type(#{i+1}) a" when $(link).text() isnt 'Upcoming')
        next()
    , (err) =>
      return callback err if err?
      # no contests yet
      return callback null unless urls.length
      competition.contests = []
      @emit 'progress', 'contestsRetrieved', competition: competition, total: urls.length
      # get all contests rankings
      async.eachSeries urls, (url, next) =>
        @_extractRanking competition, url, next
      , callback

  # **private**
  # Extract a competition header (place, date, url) from incoming Csv
  # Enrich the competitions array with a new competition if not already existing
  #
  # @param record [Object] object extracted from a Csv line
  # @param competitions [Array<Competition>] extracted competitions, enriched by this method
  _extractHeader: (record, competitions) =>
    # ignore header
    return if record[0] is 'Date'

    data =
      # place is city (rank 3)
      place: _.titleize util.removeAccents record[2].trim()
      # date at first rank
      date: moment record[0], @opts.dateFormat
      # url is rank 9, but removes contest specific part of the url to only keep the competition url
      url: record[8][0...record[8].lastIndexOf '/']
      provider: 'wdsf'
    # removes parenthesis information if present
    data.place = data.place.replace(/\(\s*\w+\s*\)/, '').trim()
    # id is date append to place lowercased without non-word characters.
    data.id = md5 "#{_.slugify data.place}#{data.date.format 'YYYYMMDD'}"

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
    if _.endsWith url, '/Participants'
      # only participants list ? means that results are not available...
      @emit 'progress', 'contestEnd', competition: competition, done: competition.contests.length
      return callback null

    url = "#{url}/Ranking" unless _.endsWith url, '/Ranking'
    request
      url: url
      proxy: util.confKey 'proxy', ''
    , (err, res, body) =>
      # http error for the contest detail
      if !(err?) and res?.statusCode isnt 200
        err = new Error "failed to fetch contest ranking from '#{@opts.name} #{competition.place}': #{res.statusCode}\n#{body}"
      return callback new Error "error on contest #{url}: #{err}" if err?

      # Unless contest was cancelled...
      body = body.toString()
      if @_hasResults body
        # extract ranking
        $ = cheerio.load util.replaceUnallowed(body), decodeEntities: false
        results =
          # competition's title
          title: $('h1').first().text().replace 'Ranking of ', ''
          results: {}
        subtitle = $('h1').first().next().text()
        if subtitle?
          subtitle = subtitle[0...subtitle.indexOf 'taken'].replace('The following results are from the WDSF', '').trim()
          results.title += " #{subtitle}"

        # check competition unicity
        unless _.findWhere(competition.contests, title:results.title, subtitle:results.subtitle)?
          # for each heat (first is final)
          for heat in $ '.list'
            for row in $(heat).find 'tbody > tr'
              name = $(row).find('td:nth-child(2)').text()
              rank = $(row).find('td:nth-child(1)').text()
              results.results[_.titleize util.removeAccents name] = parseInt rank
          competition.contests.push results
      else
        err = new Error "results not ready for '#{@opts.name} #{competition.place}'"

      @emit 'progress', 'contestEnd', competition: competition, done: competition.contests.length
      callback err or null

  # **private**
  # Tells if a competition contest contains rankings or not.
  #
  # @param body [String] html response text
  # @return [Boolean] true if rankings are availables
  _hasResults: (body) =>
    -1 is body.indexOf('Cancelled') and -1 is body.indexOf 'Not ranked yet'
