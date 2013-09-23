# What is Palmares ?

Palmares is a desktop application to help french ballroom dancers to track they own results, as well as those of their friends and opponents.

It automatically crawl the [french](www.ffddansesportive.com) and [international](www.worlddancesport.org) federation website to gather competition results, and present them into clear summaries.

Palmares can also be exported to xlsx files.

# How does it works ?

Palmares is entierly written in Javascript: NodeJS for "core" functionnalities (crawling, [xlsx](https://github.com/stephen-hardy/xlsx.js) export), and browser's JS ([jQuery](http://api.jquery.com/), [Twitter Bootstrap](http://twitter.github.io/bootstrap)) for presentation.

Thanks to Node-webkit that provides a desktop-sandalone-nodejs integrated version of the webkit browser it was very easy to reuse my web knowledge to quickly write this application (estimated at 5 working days).

# Users: how to install

Download the last installer [here](https://drive.google.com/folderview?id=0ByVTTZ_jn2IsYmc5b3p3ZDlLNG8&usp=sharing), and follow installation steps.

Only windows is supported for now. For other OS, please contact me or try to build it.

# Developpers: how to building

This project isn't purely Javascript: it's [Coffee Script](http://coffeescript.org/) a javascript preprocessor (i.e. a langage that compiles into plain javascript).
Same story with [Stylus](http://learnboost.github.io/stylus/), a css preprocessor.

So, all sources are under `src` folder, and are compiled into `lib` folder, after copying vendor js and css (ones from bootstrap and jquery).

1. install [NodeJS](http://nodejs.org/download/) if not already the case.
2. clone this repository: `git clone https://github.com/feugy/palmares`
3. enter the palmares folder with your shell.
4. globally install Coffeescript: `npm install -g coffee-script@1.6.2`
5. intsall palmares dependencies: `npm install`
6. download [node-webkit binaries](https://github.com/rogerwang/node-webkit) into a `bin` folder
7. launch your app from shell: `cake start`

If you change stuff under src, don't forget to compile before launching the application with the shell command `cake build`

To build the windows installer, download [NSIS](http://nsis.sourceforge.net/Main_Page), and compile the `installer/installer.nsi` with it.

# Release notes

v1.4.1

  - fix WDSF provider to automatically use the proper year range when getting competition list

v1.4.0
  
  - take in account international dance sport pages change that prevent result extraction
  - use new french dance sport website

v1.3.0
  
  - allow export all competitions of a given couple
  - fix proxy settings that were not saved

v1.2.0

  - add filtering buttons on competition list
  - fix accent bug on some contest titles

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

--

Licenced under MIT

Copyright © 2013, Damien Feugas

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

The Software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders X be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the Software.

Except as contained in this notice, the name of the <copyright holders> shall not be used in advertising or otherwise to promote the sale, use or other dealings in this Software without prior written authorization from Damien Feugas.