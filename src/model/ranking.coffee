'use strict'

# Ranking wrap result of a given couple inside a competition
module.exports = class Ranking

  # the couple name
  couple: null

  # the contest kind (may contains age-category and dance-category)
  contest: null

  # dance kind: 'std', 'lat' or 'ten'
  kind: null

  # couple final ranking
  rank: 0

  # number of couples involved
  total: 0

  # Ranking constructor.
  #
  # @param attrs [Object] raw attributes, copies inside the built ranking
  # @return the build ranking
  constructor: (attrs) ->
    @[attr] = value for attr, value of attrs

  # @return a plain JSON representation of this ranking
  toJSON: =>
    couple: @couple
    kind: @kind
    contest: @contest
    rank: @rank
    total: @total