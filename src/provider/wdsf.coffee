'use strict'
  
_ = require 'underscore'
async = require 'async'
request = require 'request'
moment = require 'moment'
csv = require 'csv'
cheerio = require 'cheerio'
md5 = require('md5').digest_s
Provider = require './provider'
Competition = require '../model/competition'
util = require '../util/common'

# Extract national competitions from the Ballroom Dancing National Federation
module.exports = class WDSFProvider extends Provider

  # temporary array to store parsed competitions
  models: []

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
      url: _.sprintf "#{@opts.url}/#{@opts.list}", moment().year()-1, moment().year()
      proxy: util.confKey 'proxy', ''
    , (err, res, body) =>
      if !(err?) and res?.statusCode isnt 200
        err = new Error "failed to fetch results from '#{@opts.name}': #{res.statusCode}\n#{body}"
      return callback err if err?
      # parse csv content
      @models = []
      csv()
        .from(body.toString())
        .on('record', @_extractHeader)
        .on('end', =>
          callback null, _.sortBy @models, 'date'
        )
        .on 'error', callback

  # @see Provider.getDetails()
  getDetails: (competition, callback) =>
    return callback new Error "No details url in competition '#{@opts.name} #{competition.place}'" unless competition.url
    # request contests list
    request
      url: competition.url
      proxy: util.confKey 'proxy', ''
    , (err, res, body) =>
      if !(err?) and res?.statusCode isnt 200
        err = new Error "failed to fetch contests from '#{@opts.name} #{competition.place}': #{res.statusCode}\n#{body}"
      return callback err if err?
    
      # extract contests ranking ids
      $ = cheerio.load util.replaceUnallowed body.toString()
      urls = ("#{@opts.url}#{$(link).attr 'href'}" for link in $ '.grid td > a' when $(link).text() isnt 'Upcoming')
      competition.contests = []
      # no contests yet
      return callback null unless urls.length
      @emit 'progress', 'contestsRetrieved', competition: competition, total: urls.length
      # get all contests rankings
      return async.eachSeries urls, (url, next) =>
        @_extractRanking competition, url, next
      , callback

  # **private**
  # Extract a competition header (place, date, url) from incoming Csv
  # Enrich the current `models` array with a new competition if not already existing
  #
  # @param record [Object] object extracted from a Csv line
  _extractHeader: (record) =>
    # ignore header
    return if record[0] is 'Date'
    data = 
      place: _.titleize util.removeAccents "#{record[2].trim()} #{record[1].replace('WDSF', '')?.trim()}"
      date: moment record[0], @opts.dateFormat
      url: record[8][0...record[8].lastIndexOf '/']
      provider: 'wdsf'
    # id is url, because date+place is not unique.
    data.id = md5 data.url

    existing = _.find @models, (comp) -> comp.id is data.id
    if existing?
      # Always keep the first competition day
      existing.date = data.date if existing.date.isAfter data.date
    else
      # do not add twice the same competition
      @models.push new Competition data 

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
      url: "#{url}/Ranking"
      proxy: util.confKey 'proxy', ''
    , (err, res, body) =>
      # http error for the contest detail
      if !(err?) and res?.statusCode isnt 200
        err = new Error  new Error "failed to fetch contest ranking from '#{@opts.name} #{competition.place}': #{res.statusCode}\n#{body}"
      return callback new Error "error on contest #{url}: #{err}" if err?

      # Unless contest was cancelled...
      body = body.toString()
      if -1 is body.indexOf 'Cancelled'
        # extract ranking
        $ = cheerio.load util.replaceUnallowed body
        results = 
          # competition's title
          title: $('h1').first().text().replace 'Ranking of ', ''
          results: {}

        # for each heat (first is final)
        for heat in $ '.list'
          for row in $(heat).find 'tbody > tr'
            name = $(row).find('td:nth-child(2)').text()
            rank = $(row).find('td:nth-child(1)').text()
            results.results[_.titleize util.removeAccents name] = parseInt rank

        competition.contests.push results

      @emit 'progress', 'contestEnd', competition: competition, done: competition.contests.length
      callback null