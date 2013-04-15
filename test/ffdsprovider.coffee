'use strict'

_ = require 'underscore'
express = require 'express'
moment = require 'moment'
http = require 'http'
fs = require 'fs-extra'
{join} = require 'path'
iconv = require 'iconv-lite'
expect = require('chai').expect
FFDSProvider = require '../src/provider/ffds'
Competition = require '../src/model/competition'

describe 'FFDS provider tests', ->

  port = 9123
  service = null
  server = null

  before (done) ->
    app = express()
    app.use express.methodOverride()
    app.use app.router
    app.get '/compet-situation.php', (req, res, next) ->
      res.charset = 'iso-8859-1'
      res.type 'html'
      file = 'ffds-clubs.html'
      switch req.query.club_id
        when '1118' then file = 'ffds-aix-en-provence-auc-ds.html'
        when '391' then file = 'ffds-abbeville.html'
      file = 'ffds-search.html' if req.query.couple_name?.toLowerCase() is 'simon'
      file = 'ffds-search-empty.html' if req.query.couple_name?.toLowerCase() is 'toto'
        
      fs.readFile join('test', 'fixtures', file), (err, content) ->
        return res.send 404, err if err?
        res.send iconv.encode content, res.charset

    app.get '/compet-resultats.php', (req, res, next) ->
      res.charset = 'iso-8859-1'
      res.type 'html'
      file = 'ffds-result.html'
      switch req.query.NumManif 
        when '1313' 
          file = '1313-details.html'
          switch req.query.Compet
            when 'Champ-R-A-EDCBA-L' then file = '1313-Ad-Lat.html'
            when 'Champ-R-C-EDC-L' then file = '1313-J2-Lat.html'
            when 'Champ-R-J-EDCB-L' then file = '1313-Yo-Lat.html'
            when 'Champ-R-P-ED-L' then file = '1313-J1-Lat.html'
            when 'Champ-R-VW-EDCBA-L' then file = '1313-Se-Lat.html'
        when '1248'
          file = '1248-details.html'
          switch req.query.Compet
            when 'Comp-N-B-E-L' then file = '1248-E2-E-Lat.html'
            when 'Comp-N-C-E-L' then file = '1248-J2-E-Lat.html'
            when 'Comp-N-C-D-L' then file = '1248-J2-D-Lat.html'
            when 'Comp-N-C-E-S' then file = '1248-J2-E-Std.html'
            when 'Comp-N-C-D-S' then file = '1248-J2-D-Std.html'
            when 'Coms-N-PBMC-F-L' then file = '1248-J-F-Lat.html'
            when 'Coms-N-PBMC-F-S' then file = '1248-J-F-Std.html'
            when 'Open-N-PBMC-CDE-L' then file = '1248-J-O-Lat.html'
            when 'Open-N-PBMC-CDE-S' then file = '1248-J-O-Std.html'

      fs.readFile join('test', 'fixtures', file), (err, content) ->
        return res.send 404, err if err?
        res.send iconv.encode content, res.charset

    server = http.createServer app
    server.listen port, (err) ->
      return done "failed to initialize fake server: #{err}" if err?

      service = new FFDSProvider 
          name: 'FFDS'
          url: "http://127.0.0.1:#{port}"
          list: 'compet-resultats.php'
          details: 'compet-resultats.php?NumManif=%1$s'
          clubs: 'compet-situation.php'
          couples: 'compet-situation.php?club_id=%1s&Recherche_Club='
          search: 'compet-situation.php?couple_name=%1$s&Recherche_Nom='
          dateFormat: 'DD/MM/YYYY'
      done()

  after -> server?.close()

  it 'should competition list be retrieved', (done) ->

    service.listResults (err, results) ->
      return done "failed to get result list: #{err}" if err?

      expect(results).to.have.length 26
      expect(results[25].place).to.equal 'Marseille'
      expect(results[25].id).to.equal '21f4eb195bc7de2678b1fb8665d79a28'
      expect(results[25].toJSON().date).to.deep.equal moment('2013-03-23').toDate()
    
      expect(results[21].place).to.equal 'Illzach (mulhouse)'
      expect(results[21].id).to.equal '200e916279fd5ba0f52e61b71b4b2b43'
      expect(results[21].toJSON().date).to.deep.equal moment('2013-02-17').toDate()

      expect(results[18].place).to.equal 'Vénissieux'
      expect(results[18].id).to.equal 'a486d8b5adb8513ea86df8678ff6b225'
      expect(results[18].toJSON().date).to.deep.equal moment('2013-02-09').toDate()
  
      expect(results[0].place).to.equal 'Rouen'
      expect(results[0].id).to.equal '5c7841d62a598afa46e9e931d0112733'
      expect(results[0].toJSON().date).to.deep.equal moment('2012-10-06').toDate()

      done()

  it 'should simple competition contest list be retrieved', (done) ->

    competition = new Competition 
      id: '200e916279fd5ba0f52e61b71b4b2b43'
      place: 'Illzach (mulhouse)'
      date: moment '2013-02-17'
      url: "http://127.0.0.1:#{port}/compet-resultats.php?NumManif=1313"

    service.getDetails competition, (err) ->
      return done "failed to get competition details: #{err}" if err?

      expect(competition).to.have.property 'contests'
      expect(competition.contests).to.have.length 5
      contest = _.find competition.contests, (contest) -> contest.title is 'Championnat Régional Séniors II Séniors III E D C B A Latines'
      expect(contest).to.exist
      expect(contest.results).to.deep.equal 
        'Antoine Mauceri - Pascale Mauceri': 1
        'Serge Le Poittevin - Christine Schmitt': 2
        'Daniel Scaravella - Isabelle Scaravella': 3
        'Marc Blanchard - Chantal Blanchard': 4
        'Patrick Schwarzentruber - Elisabeth Schwarzentruber': 5

      done()

  it 'should complex competition contest list be retrieved', (done) ->

    competition = new Competition 
      id: '21f4eb195bc7de2678b1fb8665d79a28'
      place: 'Marseille'
      date: moment '2013-03-23'
      url: "http://127.0.0.1:#{port}/compet-resultats.php?NumManif=1248"

    service.getDetails competition, (err) ->
      return done "failed to get competition details: #{err}" if err?

      expect(competition).to.have.property 'contests'
      expect(competition.contests).to.have.length 9
      contest = _.find competition.contests, (contest) -> contest.title is 'Juvéniles II E Latines'
      expect(contest).to.exist
      expect(contest.results).to.deep.equal
        'Danny Huck - Louise Jamm': 1
        'Leon Amiel - Lea Blanchon': 2
        'Theo Noguera - Eva Gulemirian': 3
        'Alan Sappa - Louane Piazza': 4
      
      contest = _.find competition.contests, (contest) -> contest.title is 'Open Juvéniles I Juvéniles II Juniors I Juniors II C D E Latines'
      expect(contest).to.exist
      expect(contest.results).to.deep.equal
        'Nicolas Constancia - Romane Rousselot': 1
        'Mathias Monier - Pauline Adries': 2
        'Mael Legrain - Joana Grosset Janin': 3
        'Baptiste Olivero - Maelys Michelin': 4
        'Gracia Porzio - Stelantha Porzio': 5
        'Cameron Frutuoso - Marion Moriana': 6
        'Thomas Moriana - Carla Frutuoso': 7
        'Tristan Arnaud - Emma Prats': 8
        'Melvin Chauliaguet - Alicia Charbit': 9
        'Alexis Lopez - Anaelle Belmont': 9
        'Damien Colombet - Laurianne Moullard': 11
        'Leo Bretagne - Camille Monachino': 12
        'Danny Huck - Louise Jamm': 13
        'Leon Amiel - Lea Blanchon': 14
        'Lucas Gonzalez - Deborah Carpentier': 14
        'Theo Noguera - Eva Gulemirian': 16
        'Kilian Bonastre - Maelys Meneveaux': 16
        'Audric Goursolle - Justine Esperandieu': 18
        'Arnaud Latrasse - Pauline Latrasse': 19
        'Alan Sappa - Louane Piazza': 19
      done()

  it 'should groups be searched', (done) ->
    service.searchGroups 'VilleurbannE', (err, results) ->
      return done "failed to search group Villeurbanne: #{err}" if err?

      expect(results).to.deep.equal [
        'Villeurbanne/CVDS'
        'Villeurbanne/RASDS'
        'Villeurbanne/TDC'
        'Villeurbanne/TS'
      ]
      done()

  it 'should search groups return empty results', (done) ->
    service.searchGroups 'Toto', (err, results) ->
      return done "failed to search group Toto: #{err}" if err?

      expect(results).to.have.length 0
      done()

  it 'should search known couples return results', (done) ->
    service.searchCouples 'SimOn', (err, results) ->
      return done "failed to search couples with simon: #{err}" if err?

      expect(results).to.deep.equal [
        'Jean Marc Brunel - Noella Simon'
        'Damien Feugas - Laeticia Simonin Feugas'
        'Gilles Picard - Cecile Simon-juarez'
        'Florent Simon - Justine Ernult'
      ]
      done()

  it 'should search unknown couples return results', (done) ->
    service.searchCouples 'toto', (err, results) ->
      return done "failed to search couples with simon: #{err}" if err?

      expect(results).to.deep.equal []
      done()

  it 'should group couples failed on unkwnown club', (done) ->
    service.getGroupCouples 'AUC-DS', (err, results) ->
      expect(err).to.be.an.instanceof Error
      expect(err.message).to.contain 'no group found'
      expect(results).not.to.be.defined
      done()

  it 'should group couples return couples of empty club', (done) ->
    service.getGroupCouples 'Abbeville/sca', (err, results) ->
      return done "failed to get couples of Abbeville: #{err}" if err?
      expect(results).to.have.length 0
      done()

  it 'should all couples of a club be retrieved', (done) ->
    service.getGroupCouples 'Aix-en-Provence/AUC- DS', (err, results) ->
      return done "failed to get couples of AUC- DS: #{err}" if err?

      expect(results).to.deep.equal [
        'Patrick Duong - Chau Bui Thi Huyen'
        'Alain Fauqueux - Anne-marie Fauqueux'
        'Jean Claude Fumat - Genevieve Legier'
        'Henri Muller - Miroslawa Muller'
        'Roger Nogier - Pascale Nogier'
        'Alain Roux - Maryse Jenna'
        'Daniel Savarino - Claire Morris'
        'Stephane Vaillant - Audrey Lambinet' 
      ]
      done()