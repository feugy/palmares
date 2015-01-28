'use strict'

_ = require 'underscore'
express = require 'express'
methodOverride = require 'method-override'
moment = require 'moment'
fs = require 'fs-extra'
{join} = require 'path'
expect = require('chai').expect
WDSFProvider = require '../src/provider/wdsf'
Competition = require '../src/model/competition'

describe 'WDSF provider tests', ->

  port = 9123
  service = null
  server = null

  before (done) ->
    app = express()
    app.use methodOverride()
    app.get /^\/Calendar\/Competition\/Results/, (req, res, next) ->
      fs.createReadStream(join 'test', 'fixtures', 'wdsf-result.csv').pipe res
    app.get '/Event/Competition/Open-San_Lazzaro_di_Savena_\\(Bologna\\)-18979', (req, res, next) ->
      fs.createReadStream(join 'test', 'fixtures', '18979-details.html').pipe res
    app.get '/Event/Competition/Open-San_Lazzaro_di_Savena_\\(Bologna\\)-18979/Youth-Standard-43974/Ranking', (req, res, next) ->
      fs.createReadStream(join 'test', 'fixtures', '18979-Yo-Std.html').pipe res
    app.get '/Event/Competition/Open-San_Lazzaro_di_Savena_\\(Bologna\\)-18979/Junior_II-Standard-44643/Ranking', (req, res, next) ->
      fs.createReadStream(join 'test', 'fixtures', '18979-J2-Std.html').pipe res
    app.get '/Event/Competition/Open-San_Lazzaro_di_Savena_\\(Bologna\\)-18979/Senior_I-Standard-43976/Ranking', (req, res, next) ->
      fs.createReadStream(join 'test', 'fixtures', '18979-S1-Std.html').pipe res
    app.get '/Event/Competition/Open-San_Lazzaro_di_Savena_\\(Bologna\\)-18979/Senior_II-Standard-43978/Ranking', (req, res, next) ->
      fs.createReadStream(join 'test', 'fixtures', '18979-S2-Std.html').pipe res
    app.get '/Event/Competition/Open-San_Lazzaro_di_Savena_\\(Bologna\\)-18979/Senior_III-Standard-44642/Ranking', (req, res, next) ->
      fs.createReadStream(join 'test', 'fixtures', '18979-S3-Std.html').pipe res
    app.get '/Event/Competition/Open-San_Lazzaro_di_Savena_\\(Bologna\\)-18979/Youth-Latin-43973/Ranking', (req, res, next) ->
      fs.createReadStream(join 'test', 'fixtures', '18979-Yo-Lat.html').pipe res
    app.get '/Event/Competition/Open-San_Lazzaro_di_Savena_\\(Bologna\\)-18979/Junior_II-Latin-44644/Ranking', (req, res, next) ->
      fs.createReadStream(join 'test', 'fixtures', '18979-J2-Lat.html').pipe res
    app.get '/Event/Competition/Open-San_Lazzaro_di_Savena_\\(Bologna\\)-18979/Senior_I-Latin-43975/Ranking', (req, res, next) ->
      fs.createReadStream(join 'test', 'fixtures', '18979-S1-Lat.html').pipe res
    app.get '/Event/Competition/Open-San_Lazzaro_di_Savena_\\(Bologna\\)-18979/Senior_II-Latin-43977/Ranking', (req, res, next) ->
      fs.createReadStream(join 'test', 'fixtures', '18979-S2-Lat.html').pipe res
    # Kiev championship, with multiple references
    app.get '/Event/Competition/World_Championship-Kiev-18507/Adult-Standard-42617/Ranking', (req, res, next) ->
      fs.createReadStream(join 'test', 'fixtures', '5255-Ch-Std.html').pipe res
    app.get '/Event/Competition/World_Open-Kiev-19282/Adult-Latin-44881/Ranking', (req, res, next) ->
      fs.createReadStream(join 'test', 'fixtures', '5255-Ad-Lat.html').pipe res
    app.get '/Event/Competition/World_Open-Kiev-19282/Adult-Standard-44882/Ranking', (req, res, next) ->
      fs.createReadStream(join 'test', 'fixtures', '5255-Ad-Std.html').pipe res
    app.get '/Event/Competition/Open-Kiev-19283/Youth-Latin-44883/Ranking', (req, res, next) ->
      fs.createReadStream(join 'test', 'fixtures', '5255-Yo-Lat.html').pipe res
    app.get '/Event/Competition/Open-Kiev-19283/Youth-Standard-44884/Ranking', (req, res, next) ->
      fs.createReadStream(join 'test', 'fixtures', '5255-Yo-Std.html').pipe res

    server = app.listen port, (err) ->
      return done "failed to initialize fake server: #{err}" if err?

      service = new WDSFProvider 
        name: 'WDSF'
        url: "http://localhost:#{port}"
        list: 'Calendar/Competition/Results?format=csv&downloadFromDate=01/01/%1$s&downloadToDate=31/12/%1$s&kindFilter=Competition'
        dateFormat: 'YYYY/MM/DD'
      done()

  after -> server?.close()

  it 'should competition list be retrieved', (done) ->

    service.listResults (err, results) ->
      return done "failed to get result list: #{err}" if err?
      expect(results).to.have.length 77
      
      # should competition with different names on same days and place have been merged
      expect(results[0].place).to.equal 'San Lazzaro Di Savena'
      expect(results[0].id).to.equal 'b38521030e81c5ddcc7cdeebbe4fe14f'
      expect(results[0].toJSON().date).to.deep.equal moment('2013-01-04').toDate()
      
      # should competition on several days have been merged
      expect(results[2].place).to.equal 'Moscow'
      expect(results[2].id).to.equal '7d00c5480c303ae032043495a6cc7d26'
      expect(results[2].toJSON().date).to.deep.equal moment('2013-01-05').toDate()

      # should Kiev World Open, Kiev World Standard and Kiev Open have been merged into one competition
      expect(results[76].place).to.equal 'Kiev'
      expect(results[76].id).to.equal '4aee29e66d0644c811b8babaf30e3be8'
      expect(results[76].toJSON().date).to.deep.equal moment('2013-11-24').toDate()
      done()

  it 'should simple competition contest list be retrieved', (done) ->

    competition = new Competition 
      place: 'San Lazzaro Di Savena (bologna)'
      id: '7a217757907283d497436854677adabd'
      date: moment '2013-01-04'
      url: "http://127.0.0.1:#{port}/Event/Competition/Open-San_Lazzaro_di_Savena_(Bologna)-18979"

    service.getDetails competition, (err) ->
      return done "failed to get competition details: #{err}" if err?

      expect(competition).to.have.property 'contests'
      expect(competition.contests).to.have.length 2
      contest = _.find competition.contests, (contest) -> contest.title is 'Junior II Latin Open'
      expect(contest).to.exist
      expect(contest.results).to.deep.equal
        'Leonardo Lini - Mia Gabusi': 1
        'Samuel Santarelli - Alexandra Leone': 2
        'Alessio Russo - Antonella Carrieri': 3
        'Leonardo Marinelli - Aurora Pacetti': 4
        'Rodolfo Gentilini - Beatrice Fabi': 5
        'Leonardo Aiuti - Cecilia Bruni': 6
        'Massimiliano Domenico Proietto - Cinziana Palumbo': 7
        'Klevis Shera - Cristiana Pasquale': 8
        'Gilbert Lucas Bugeja - Kelsey Borg': 9
        'Emanuele Nucciotti - Erika Straccali': 10
        'Scapinello Giacomo - Martina Pasquale': 11
        'Silvio Morelli - Alessandra Benvenuto': 12
        'Monti Daniele - Gaia Cirillo': 13
        'Daniele Sciretti - Laura Sciretti': 14
        'Andrea Fornasiere - Elisa Brunetti': 15
        'Michal Prochazka - Katerina Srostlikova': 16
        'Nicola Pellegrino - Manuela Venturi': 17
        'Michel Peloux - Alessandra Bufano': 18
        'Daniele Sciolino - Giorgia Caldarera': 19
        'Mirco Boccaletti - Gaia Serpini': 20
        'Nicholas Fiorini - Elena Lamieri': 21
        'Domenico Maggi - Beatrice Righi': 22
        'Mirco Ranieri - Sofia Beltrandi': 22

      done()