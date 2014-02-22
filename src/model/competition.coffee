'use strict'

moment = require 'moment'

# Competition modelize an event that may last several days and contains many contests
module.exports = class Competition

  # Competition id
  id: null

  # Competition constructor.
  # Attributes are initialized in one pass with the attrs parameter.
  #
  # @param attrs [Object] raw attributes, copies inside the built competition
  # @return the build competition
  constructor: (attrs) ->
    @[attr] = value for attr, value of attrs
    throw new Error 'no id provided for competition' unless @id?
    @date = moment @date
    @dataUrls = [@url] unless @dataUrls?.length > 0

  # @return a plain JSON representation of this competition
  toJSON: =>
    id: @id
    place: @place
    date: @date.toDate()
    url: @url
    provider: @provider
    contests: @contests
    dataUrls: @dataUrls