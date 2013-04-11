'use strict'

_ = require 'underscore'

module.exports =

  # Displays a popup window, with relevant title, message and buttons.
  # Button handler can be specified
  #
  # @param title [String] the popup title
  # @param message [String] the popup message
  # @param buttons [Array] an array (order is significant) or buttons:
  # @option buttons text [String] the button text
  # @option buttons className [String] option button CSS class
  # @option buttons icon [String] option button icon class
  # @option buttons click [Function] the button handler. Can cancel closure if false is returned
  # @param closeIndex [Number] index in the buttons array of the handler invoked when using the popup close button, 0 by default
  # @return the generated popup dialog
  popup: (title, message, buttons = [], closeIndex = 0) ->
    # parameter validations
    throw new Error "closeIndex #{closeIndex} is not a valid index in the buttons array" unless closeIndex >= 0 and (closeIndex < buttons.length or buttons.length is 0)
    
    html = "<div class='modal hide fade'><div class='modal-header'>
      <button type='button' data-dismiss='modal' class='close'>&times;</button><h3>#{title}</h3></div>
      <div class='modal-body'>#{message}</div><div class='modal-footer'>"

    for spec, i in buttons
      html += "<a data-idx='#{i}' class='btn #{if spec.className? then spec.className else ''}' href='#''>"
      html += "<i class='#{spec.icon}'></i>" if spec.icon?
      html += "#{spec.text}</a>"

    html += "</div></div>"
    popup = $(html)

    popup.modal().on('hide', (event) -> 
      return if popup.preventClose
      # invoke close button if not prevented
      # close can be aborted if event is cancelled
      buttons[closeIndex]?.click event if _.isFunction buttons[closeIndex]?.click
    ).on('hidden', -> 
      popup.off().remove()
    ).on('click', 'a', (event) =>
      # invoke proper button behaviour
      idx = $(event.target).data 'idx'
      buttons[idx].click event if _.isFunction buttons[idx]?.click
      return if event.isDefaultPrevented()
      # now we can prevent default event behaviour
      event.preventDefault()
      # do not invoke close button
      popup.preventClose = true
      popup.modal 'hide'
    ).on 'shown', ->
      popup.find('a').first().focus()

    popup