'use strict'

fs = require 'fs'

# Data sanitizer
module.exports = class Cleaner

  # Sanitize data.
  # Removes all empty competitions.
  #
  # @param storage [Storage] storage service
  # @param callback [Function] sanitize end callback, invoked with no arguments
  # @throws error if storage cannot pop or push competitions
  @sanitize: (storage, callback) ->

    # get competitions from storage
    storage.pop 'competitions', (err, competitions) =>
      throw new Error err if err?
      return callback() unless competitions?

      length = Object.keys(competitions).length
      cleanedLength = 0
      cleaned = {}
      idChanged = false

      for id, competition of competitions 
        # removes competition that are empty
        if competition?.contests?.length > 0
          cleaned[id] = competition
          cleanedLength++
        else if competition?
          console.info "removes empty competition #{competition.place} #{competition.date.format()}"

      end = =>
        # no competition removed: let's go
        if cleanedLength is length and not idChanged
          return callback()

        # or store the cleaned result before going
        storage.push 'competitions', cleaned, (err) =>
          throw new Error err if err?
          console.info 'saved cleaned competitions'
          callback()

      # get competitions from storage
      storage.pop 'tracked', (err, tracked) =>
        throw new Error err if err?
        coupleChanged = false

        for couple in tracked
          # remove palmares for competitions that are unknown
          for id of couple.palmares when not id of cleaned
            delete couple.palmares[id]
            coupleChanged = true

        return end() unless coupleChanged
        storage.push 'tracked', tracked, (err) =>
          throw new Error err if err?
          end()