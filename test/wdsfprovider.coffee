'use strict'

_ = require 'underscore'
express = require 'express'
moment = require 'moment'
http = require 'http'
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
    app.use express.methodOverride()
    app.use app.router
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

    server = http.createServer app
    server.listen port, (err) ->
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

      expect(results).to.have.length 
      expect(results[0].place).to.equal 'San Lazzaro Di Savena (bologna) Open'
      expect(results[0].id).to.equal '50a4fe09e8017722760eae59990cd270'
      expect(results[0].toJSON().date).to.deep.equal moment('2013-01-04').toDate()
    
      expect(results[1].place).to.equal 'Moscow Open'
      expect(results[1].id).to.equal '7b2c13ad6cd1b171b39e88b5a42703f0'
      expect(results[1].toJSON().date).to.deep.equal moment('2013-01-05').toDate()

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
      expect(competition.contests).to.have.length 9
      contest = _.find competition.contests, (contest) -> contest.title is 'Junior II Latin'
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
        'Giacomo Scapinello - Martina Pasquale': 11
        'Morelli Silvio - Alessandra Benvenuto': 12
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