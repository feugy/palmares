# What is Palmares ?

Palmares is a desktop application to help french ballroom dancers to track they own results, as well as those of their friends and opponents.

It automatically crawl the french and international federation website to gather competition results, and present them into clear summaries.

Palmares can also be exported to xlsx files.

# How does it works ?

Palmares is entierly written in Javascript: NodeJS for "core" functionnalities (crawling, [xlsx](https://github.com/stephen-hardy/xlsx.js) export), and browser's JS ([jQuery](http://api.jquery.com/), [Twitter Bootstrap](http://twitter.github.io/bootstrap)) for presentation.

Thanks to [Node-webkit](https://github.com/rogerwang/node-webkit) that provides a desktop-sandalone-nodejs integrated version of the webkit browser it was very easy to reuse my web knowledge to quickly write this application (estimated at 5 working days)
  
# Release notes

v1.1.0

  - restore maximized window state between executions
  - add tooltips on export, untrack and remove buttons
  - allow export of tracked couples for given competitions
  - on home page replace checkbox+button by contextual buttons on hovered item for better ease of use
  - upgrade to node-webkit 0.5.2

v1.0.0
  
  - first working release !
  - list track couples
  - list existing competitions
  - add couples by name or by club
  - auto import competitions from providers
  - remove couples and competitions from lists
  - show a couple's palmares
  - show a competition's content
  - export in Xlsx file results of tracked couples within known competitions
  - allow to set proxy configuration
  - about dialog with developper and providers coordinates
  - fancy animations during browsing
  - NSIS installer