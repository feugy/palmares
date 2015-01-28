'use strict'

{safeLoad} = require 'js-yaml'
{readFileSync} = require 'fs-extra'
View = require '../view/view'

module.exports = class AboutView extends View

  # template used to render view
  template: require '../../template/about.html'

  # i18n object for rendering
  i18n: safeLoad readFileSync "#{__dirname}/../../nls/common.yml"

  # version udisplayed, read from package.json
  version: ''

  # About View constructor
  # Immediately renders the view
  #
  # @return the built view
  constructor: () ->
    super className: 'about'
    infos = require '../../package.json'
    @version = "Version #{infos.version}, #{infos.releaseDate}"
    @render()