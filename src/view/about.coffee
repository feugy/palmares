'use strict'

View = require '../view/view'

module.exports = class AboutView extends View

  # template used to render view
  template: require '../../template/about.html'

  # i18n object for rendering
  i18n: require '../../nls/common.yml'

  # About View constructor
  # Immediately renders the view
  #
  # @return the built view
  constructor: () ->
    super className: 'about'
    @render()