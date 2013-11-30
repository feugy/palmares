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
    storage.pop "competitions", (err, competitions) =>
      throw new Error err if err?
      return callback() unless competitions?

      length = Object.keys competitions
      cleanedLength = 0
      cleaned = {}

      # removes competition that are empty
      for id, competition of competitions 
        if competition?.contests?.length > 0
          cleaned[id] = competition
          cleanedLength++
        else if competition?
          console.info "removes empty competition #{competition.place} #{competition.date}"

      # no competition removed: let's go
      if cleanedLength is length
        return callback()

      # or store the cleaned result before going
      storage.push "competitions", cleaned, (err) =>
        throw new Error err if err?
        callback()
