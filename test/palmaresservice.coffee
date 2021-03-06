'use strict'

_ = require 'underscore'
express = require 'express'
methodOverride = require 'method-override'
moment = require 'moment'
http = require 'http'
fs = require 'fs-extra'
{join} = require 'path'
iconv = require 'iconv-lite'
expect = require('chai').expect
FFDSProvider = require '../src/provider/ffds'
MemoryStorage = require '../src/service/memory'
PalmaresService = require '../src/service/palmares'

describe 'Palmares service tests', ->

  port = 9123
  service = null
  server = null
  storage = new MemoryStorage name: 'in-memory'
  couples = [
    'Kylian Da Costa - Romane Tourral-Ferjoux'
    'Damien Feugas - Laeticia Simonin Feugas'
    'Jonathan Bouchard - Sophie Thomas'
  ]
  withNew = false
  progressEvts = []
  resultEvts = []
  i18n = 
    appTitle: 'Palmarès'
    globalSheet: 'Par compétitions'
    dateFormat: 'DD/MM/YYYY'
    couple: 'Couple'
    contest: 'Catégorie'
    result: 'Résultat'
    lat: 'Latines'
    std: 'Standards'

  before (done) ->
    app = express()
    app.use methodOverride()
    app.get '/compet-resultats.php', (req, res, next) ->
      res.charset = 'iso-8859-1'
      res.type 'html'
      file = if withNew then 'ffds-result-light2.html' else 'ffds-result-light.html'
      switch req.query.NumManif 
        when '1254' 
          file = '1254-details.html'
          switch req.query.Compet
            when 'Champ-N-A-ABC-S' then file = '1254-A-Std.html'
        when '1262' 
          file = '1262-details.html'
          switch req.query.Compet
            when 'Comp-N-C-E-L' then file = '1262-J2-E-Lat.html'
            when 'Comp-N-A-E-L' then file = '1262-A-E-Lat.html'
            when 'Open-N-JA-ABCDE-L' then file = '1262-A-O-Lat.html'
            when 'Open-N-PBMC-CDE-L' then file = '1262-J-O-Lat.html'
        when '1263' 
          file = '1263-details.html'
          switch req.query.Compet
            when 'Comp-N-C-E-L' then file = '1263-J2-E-Lat.html'
            when 'Comp-N-A-E-S' then file = '1263-A-E-Std.html'
        when '1273' 
          file = '1273-details.html'
          switch req.query.Compet
            when 'Comp-N-C-E-L' then file = '1273-J2-E-Lat.html'
            when 'Comp-N-A-E-L' then file = '1273-A-E-Lat.html'

      fs.readFile join('test', 'fixtures', file), (err, content) ->
        return res.send 404, err if err?
        res.send iconv.encode content, res.charset

    server = http.createServer app
    server.listen port, (err) ->
      return done "failed to initialize fake server: #{err}" if err?

      ffds = new FFDSProvider 
        name: 'FFDS'
        url: "http://127.0.0.1:#{port}"
        list: 'compet-resultats.php'
        details: 'compet-resultats.php?NumManif=%1$s'
        contest: 'compet-resultats.php?NumManif=%1$s&Compt=%2$s'
        clubs: 'compet-situation.php'
        couples: 'compet-situation.php?club_id=%1s&Recherche_Club='
        search: 'compet-situation.php?couple_name=%1$s&Recherche_Nom='
        dateFormat: 'DD/MM/YYYY'

      service = new PalmaresService storage, [ffds], i18n
      # bind a listener on events
      service.on 'progress', (args...) -> progressEvts.push args
      service.on 'result', (args...) -> resultEvts.push args
      done()

  beforeEach -> 
    progressEvts = []
    resultEvts = []

  after -> server?.close()

  it 'should palmares be added for new couples', (done) ->
    # when tracking new couples
    service.track couples[..1], (err, results) ->
      return done "failed to get result list: #{err}" if err?
      expect(results).to.have.length 2

      # then one competition was found related to both couples
      competition = _.find results, (r) -> r.competition.id is 'a281637604e1ac8ffd1eeb51e58e7adf'
      expect(competition).to.exist.and.to.have.property('results').that.has.lengthOf 2
      res = _.find competition.results, (r) -> r.couple is couples[0]
      expect(res).to.be.defined
      expect(res.toJSON()).to.deep.equal
        couple: couples[0]
        kind: 'lat'
        contest: 'Juniors II E Latines'
        rank: 5
        total: 14
      res = _.find competition.results, (r) -> r.couple is couples[1]
      expect(res).to.be.defined
      expect(res.toJSON()).to.deep.equal
        couple: couples[1]
        kind: 'lat',
        contest: 'Adultes E Latines',
        rank: 4,
        total: 9

      # then one competition was found related to one couple with two occurences
      competition = _.find results, (r) -> r.competition.id is 'ba26f16638b950fa938e423a34fc7305'
      expect(competition).to.exist.and.to.have.property('results').that.has.lengthOf 2
      res = _.find competition.results, (r) -> r.contest is 'Juniors II E Latines'
      expect(res).to.be.defined
      expect(res.toJSON()).to.deep.equal
        couple: couples[0]
        kind: 'lat'
        contest: 'Juniors II E Latines'
        rank: 5
        total: 28 
      res = _.find competition.results, (r) -> r.contest is 'Open Juvéniles I Juvéniles II Juniors I Juniors II C D E Latines'
      expect(res).to.be.defined
      expect(res.toJSON()).to.deep.equal
        couple: couples[0]
        kind: 'lat'
        contest: 'Open Juvéniles I Juvéniles II Juniors I Juniors II C D E Latines'
        rank: 30
        total: 70

      # then couples palmares were stores in storage service
      storage.pop 'tracked', (err, value) ->
        return done "failed to read couples in storage: #{err}" if err?
        expect(value[1].name).to.equal couples[0]
        expect(value[1].palmares).to.have.property 'a281637604e1ac8ffd1eeb51e58e7adf'
        expect(JSON.parse JSON.stringify value[1].palmares.a281637604e1ac8ffd1eeb51e58e7adf).to.deep.equal [ 
          couple: couples[0]
          kind: 'lat'
          contest: 'Juniors II E Latines'
          rank: 5
          total: 14
        ]
        expect(value[1].palmares).to.have.property 'ba26f16638b950fa938e423a34fc7305'
        expect(value[1].palmares.ba26f16638b950fa938e423a34fc7305).to.have.length 2 
        res = _.find value[1].palmares.ba26f16638b950fa938e423a34fc7305, (r) -> r.contest is 'Juniors II E Latines'
        expect(res.toJSON()).to.deep.equal 
          couple: couples[0]
          kind: 'lat'
          contest: 'Juniors II E Latines'
          rank: 5
          total: 28 
        res = _.find value[1].palmares.ba26f16638b950fa938e423a34fc7305, (r) -> r.contest is 'Open Juvéniles I Juvéniles II Juniors I Juniors II C D E Latines'
        expect(res.toJSON()).to.deep.equal 
          couple: couples[0]
          kind: 'lat'
          contest: 'Open Juvéniles I Juvéniles II Juniors I Juniors II C D E Latines'
          rank: 30
          total: 70

        expect(value[0].name).to.equal couples[1]
        expect(JSON.parse JSON.stringify value[0].palmares).to.deep.equal 
          a281637604e1ac8ffd1eeb51e58e7adf: [ 
            couple: couples[1]
            kind: 'lat',
            contest: 'Adultes E Latines',
            rank: 4,
            total: 9
          ]
        # then progress and result events were issued
        events = ('compEnd' for i in [0..2]).concat ['compRetrieved'], 
          ('compStart' for i in [0..2]), 
          ('contestEnd' for i in [0..6]), 
          ('contestsRetrieved' for i in [0..2]),
          ['end', 'start']
        expect(progressEvts).to.have.length events.length
        expect(_.pluck(progressEvts, 0).sort()).to.deep.equal events
        expect(resultEvts).to.have.length 4
        expect(_.chain(resultEvts).pluck(0).pluck('couple').value().sort()).to.deep.equal [
          couples[1]
          couples[0]
          couples[0]
          couples[0]
        ]
        done()

  it 'should palmares for new couples be established', (done) ->
    # when tracking new couples while results were already retireved
    service.track couples[2..], (err, results) ->
      return done "failed to get result list: #{err}" if err?
      expect(results).to.have.length 1

      # then one competition was found related to new couple
      expect(results[0].competition.id).to.equal '670df6fb520ef609820ed2920828eb10'
      expect(results[0].results).to.have.length 1
      expect(results[0].results[0].toJSON()).to.deep.equal
        couple: couples[2]
        kind: 'std'
        contest: 'Championnat de France Adultes A B C Standard'
        rank: 3
        total: 18

      # then couples palmares were stores in storage service
      storage.pop 'tracked', (err, value) ->
        return done "failed to read couples in storage: #{err}" if err?
        expect(value).to.have.length 3
        expect(value[2].name).to.equal couples[0]
        expect(value[0].name).to.equal couples[1]
        expect(value[1].name).to.equal couples[2]
        expect(JSON.parse JSON.stringify value[1].palmares).to.deep.equal 
          '670df6fb520ef609820ed2920828eb10': [ 
            couple: couples[2]
            kind: 'std'
            contest: 'Championnat de France Adultes A B C Standard'
            rank: 3
            total: 18
          ]
        # then progress and result events were issued
        events = ('compEnd' for i in [0..2]).concat ['compRetrieved'], 
          ('compStart' for i in [0..2]), 
          ['end', 'start']
        expect(progressEvts).to.have.length events.length
        expect(_.pluck(progressEvts, 0).sort()).to.deep.equal events
        expect(resultEvts).to.have.length 1
        expect(resultEvts[0][0].couple).to.equal couples[2]
        done()

  it 'should not detect updates without new competitions', (done) ->
    # when seeking updates while no new competition available
    service.update (err, results) ->
      return done "failed to seek updates: #{err}" if err?
      # then no new results found nor event issued
      expect(results).to.have.length 0
      expect(resultEvts).to.have.length 0
      done()

  it 'should updates be detected with new competitions', (done) ->
    # given a competition update
    withNew = true
    # when seeking updates while new competitions available
    service.update (err, results) ->
      return done "failed to seek updates: #{err}" if err?
      expect(results).to.have.length 1
      
      # then the new competition match two tracked couples
      expect(results[0].competition.id).to.equal 'da84f7326d92212d7cd5c58c89c6c6b6'
      expect(results[0].competition.place).to.equal 'Bagnols-Sur-Cèze'
      expect(results[0].competition.date.unix()).to.equal moment('2013-03-31').unix()
      expect(results[0].results).to.have.length 2
      res = _.find results[0].results, (r) -> r.contest is 'Juniors II E Latines'
      expect(res.toJSON()).to.deep.equal 
        couple: couples[0]
        kind: 'lat',
        contest: 'Juniors II E Latines',
        rank: 8,
        total: 21

      res = _.find results[0].results, (r) -> r.contest is 'Adultes E Standard'
      expect(res.toJSON()).to.deep.equal 
        couple: couples[1]
        kind: 'std',
        contest: 'Adultes E Standard',
        rank: 4,
        total: 7

      # then couples palmares were updates in storage service
      storage.pop 'tracked', (err, value) ->
        return done "failed to read couples in storage: #{err}" if err?
        expect(value).to.have.length 3
        expect(value[2].name).to.equal couples[0]
        expect(value[2].palmares).to.have.property 'a281637604e1ac8ffd1eeb51e58e7adf'
        expect(value[2].palmares).to.have.property 'ba26f16638b950fa938e423a34fc7305'
        expect(value[2].palmares).to.have.property 'da84f7326d92212d7cd5c58c89c6c6b6'
        expect(value[0].name).to.equal couples[1]
        expect(value[0].palmares).to.have.property 'a281637604e1ac8ffd1eeb51e58e7adf'
        expect(value[0].palmares).to.have.property 'da84f7326d92212d7cd5c58c89c6c6b6'

        # then some result events were issued
        events = ['compEnd', 'compRetrieved', 'compStart', 'contestEnd', 'contestEnd', 'contestsRetrieved', 'end', 'start']
        expect(progressEvts).to.have.length events.length
        expect(_.pluck(progressEvts, 0).sort()).to.deep.equal events
        expect(resultEvts).to.have.length 2
        expect(_.chain(resultEvts).pluck(0).pluck('couple').value().sort()).to.deep.equal [
          couples[1]
          couples[0]
        ]
        done()

  it 'should global palmares be exported', (done) ->
    service.export (err, xlsx) ->
      return done "failed to export global palmares: #{err}" if err?
      expect(xlsx).to.have.property 'creator', i18n.appTitle
      expect(xlsx).to.have.property 'lastModifiedBy', i18n.appTitle
      expect(xlsx).to.have.property 'worksheets'
      expect(xlsx.worksheets).to.have.length 1
      sheet = xlsx.worksheets[0]
      expect(sheet).to.have.property 'name', i18n.globalSheet
      data = JSON.stringify sheet.data, null, 2
      expect(data).to.include 'Bourg En Bresse 19/01/2013'
      expect(data).to.include 'Bourg En Bresse 02/03/2013'
      expect(data).to.include 'Bagnols-Sur-Cèze 30/03/2013'
      expect(data).to.include 'Bagnols-Sur-Cèze 31/03/2013'
      expect(data).to.include couples[0]
      expect(data).to.include couples[1]
      expect(data).to.include couples[2]
      expect(data).to.include '5/28'
      expect(data).to.include '30/70'
      expect(data).to.include '4/7'
      expect(data).to.include '8/21'
      expect(data).to.include '4/9'
      expect(data).to.include '5/14'
      expect(data).to.include '3/18'
      expect(data).to.include 'Adultes E Latines'
      expect(data).to.include 'Adultes E Standard'
      expect(data).to.include 'Juniors II E Latines'
      expect(data).to.include 'Open Juvéniles I Juvéniles II Juniors I Juniors II C D E Latines'
      expect(data).to.include 'Championnat de France Adultes A B C Standard'
      done()

  it 'should some competitions palmares be exported', (done) ->
    service.exportCompetitions ['a281637604e1ac8ffd1eeb51e58e7adf', 'ba26f16638b950fa938e423a34fc7305'], (err, xlsx) ->
      return done "failed to export competitions palmares: #{err}" if err?
      expect(xlsx).to.have.property 'creator', i18n.appTitle
      expect(xlsx).to.have.property 'lastModifiedBy', i18n.appTitle
      expect(xlsx).to.have.property 'worksheets'
      expect(xlsx.worksheets).to.have.length 1
      sheet = xlsx.worksheets[0]
      expect(sheet).to.have.property 'name', i18n.globalSheet
      data = JSON.stringify sheet.data, null, 2
      expect(data).to.include 'Bourg En Bresse 19/01/2013'
      expect(data).not.to.include 'Bourg En Bresse 02/03/2013'
      expect(data).to.include 'Bagnols-Sur-Cèze 30/03/2013'
      expect(data).not.to.include 'Bagnols-Sur-Cèze 31/03/2013'
      expect(data).to.include couples[0]
      expect(data).to.include couples[1]
      expect(data).not.to.include couples[2]
      expect(data).to.include '5/28'
      expect(data).to.include '30/70'
      expect(data).not.to.include '4/7'
      expect(data).not.to.include '8/21'
      expect(data).to.include '4/9'
      expect(data).to.include '5/14'
      expect(data).not.to.include '3/18'
      expect(data).to.include 'Adultes E Latines'
      expect(data).not.to.include 'Adultes E Standard'
      expect(data).to.include 'Juniors II E Latines'
      expect(data).to.include 'Open Juvéniles I Juvéniles II Juniors I Juniors II C D E Latines'
      expect(data).not.to.include 'Championnat de France Adultes A B C Standard'
      done()

  it 'should some couple palmares be exported', (done) ->
    service.exportCouples [couples[1], couples[2]], (err, xlsx) ->
      return done "failed to export couple palmares: #{err}" if err?
      expect(xlsx).to.have.property 'creator', i18n.appTitle
      expect(xlsx).to.have.property 'lastModifiedBy', i18n.appTitle
      expect(xlsx).to.have.property 'worksheets'
      expect(xlsx.worksheets).to.have.length 1
      sheet = xlsx.worksheets[0]
      expect(sheet).to.have.property 'name', i18n.globalSheet
      data = JSON.stringify sheet.data, null, 2
      expect(data).to.include 'Bourg En Bresse 19/01/2013'
      expect(data).to.include 'Bourg En Bresse 02/03/2013'
      expect(data).not.to.include 'Bagnols-Sur-Cèze 30/03/2013'
      expect(data).to.include 'Bagnols-Sur-Cèze 31/03/2013'
      expect(data).not.to.include couples[0]
      expect(data).to.include couples[1]
      expect(data).to.include couples[2]
      expect(data).to.include '4/7'
      expect(data).to.include '4/9'
      expect(data).to.include '3/18'
      expect(data).not.to.include '5/28'
      expect(data).not.to.include '30/70'
      expect(data).not.to.include '8/21'
      expect(data).not.to.include '5/14'
      expect(data).to.include 'Adultes E Latines'
      expect(data).to.include 'Adultes E Standard'
      expect(data).not.to.include 'Juniors II E Latines'
      expect(data).not.to.include 'Open Juvéniles I Juvéniles II Juniors I Juniors II C D E Latines'
      expect(data).to.include 'Championnat de France Adultes A B C Standard'
      done()

  it 'should existing couple palmares be returned', (done) ->
    # when consulting palmares of existing couple
    service.palmares couples[1], (err, results) ->
      return done "failed to get palmares: #{err}" if err?
      expect(results).to.have.length 2
      # then first competition is last added
      expect(results[0].competition.id).to.equal 'da84f7326d92212d7cd5c58c89c6c6b6'
      expect(results[0].competition.place).to.equal 'Bagnols-Sur-Cèze'
      expect(results[0].results).to.have.length 1
      expect(results[0].results[0].toJSON()).to.deep.equal  
        couple: couples[1]
        kind: 'std',
        contest: 'Adultes E Standard',
        rank: 4,
        total: 7
      # then palmares contains all details
      expect(results[1].competition.id).to.equal 'a281637604e1ac8ffd1eeb51e58e7adf'
      expect(results[1].competition.place).to.equal 'Bourg En Bresse'
      expect(results[1].results).to.have.length 1
      expect(results[1].results[0].toJSON()).to.deep.equal 
        couple: couples[1]
        kind: 'lat',
        contest: 'Adultes E Latines',
        rank: 4,
        total: 9
      done()

  it 'should unexisting couple palmares fail', (done) ->
    couple = "Jean Petit - Petit Jean"
    service.palmares couple, (err, results) ->
      expect(err).to.be.an.instanceof Error
      expect(err.message).to.include "couple #{couple} is not tracked"
      expect(results).not.to.be.defined
      done()
  
  it 'should competitions be removed', (done) ->
    expect(_.keys(service.competitions).sort()).to.deep.equal [
      '670df6fb520ef609820ed2920828eb10'
      'a281637604e1ac8ffd1eeb51e58e7adf'
      'ba26f16638b950fa938e423a34fc7305'
      'da84f7326d92212d7cd5c58c89c6c6b6'
    ]
    service.remove ['unknown', '670df6fb520ef609820ed2920828eb10'], (err) =>
      return done "failed to remove competition: #{err}" if err?
      # then competition storage does not contain removed competition anymore
      storage.pop 'competitions', (err, value) ->
        return done "failed to read competitions in storage: #{err}" if err?
        expect(_.keys(value).sort()).to.deep.equal [
          'a281637604e1ac8ffd1eeb51e58e7adf'
          'ba26f16638b950fa938e423a34fc7305'
          'da84f7326d92212d7cd5c58c89c6c6b6'
        ]
        # then couple storage does not contain competition anymore
        storage.pop 'tracked', (err, value) ->
          return done "failed to read tracked in storage: #{err}" if err?
          expect(value).to.have.length 3
          expect(value[1].name).to.equal couples[2]
          expect(value[1].palmares).not.to.have.property '670df6fb520ef609820ed2920828eb10'
          done()
        
  it 'should existing couple be untrack', (done) ->
    service.untrack [couples[1]], (err) ->
      return done "failed to untrack couples: #{err}" if err?
      # then couples palmares were updates in storage service
      storage.pop 'tracked', (err, value) ->
        return done "failed to read couples in storage: #{err}" if err?
        expect(value).to.have.length 2
        expect(value[1].name).to.equal couples[0]
        expect(value[1].palmares).to.have.property 'a281637604e1ac8ffd1eeb51e58e7adf'
        expect(value[1].palmares).to.have.property 'ba26f16638b950fa938e423a34fc7305'
        expect(value[1].palmares).to.have.property 'da84f7326d92212d7cd5c58c89c6c6b6'
        expect(value[0].name).to.equal couples[2]
        expect(value[0].palmares).to.be.empty
        done()

  it 'should unexisting couple untrack not fail', (done) ->
    service.untrack ["Jean Petit - Petit Jean"], (err) ->
      return done "failed to untrack couples: #{err}" if err?
      # palmares storage is still untouched
      storage.pop 'tracked', (err, value) ->
        return done "failed to read couples in storage: #{err}" if err?
        expect(value).to.have.length 2
        expect(value[1].name).to.equal couples[0]
        expect(value[1].palmares).to.have.property 'a281637604e1ac8ffd1eeb51e58e7adf'
        expect(value[1].palmares).to.have.property 'ba26f16638b950fa938e423a34fc7305'
        expect(value[1].palmares).to.have.property 'da84f7326d92212d7cd5c58c89c6c6b6'
        expect(value[0].name).to.equal couples[2]
        expect(value[0].palmares).to.be.empty
        done()