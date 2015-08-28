# number of requests for one URL test
NUM_OF_REQUESTS = 5

# number of last request durations to consider for benchmarking
NUM_OF_LAST_DURATIONS = 7

# allowed request types
REQUEST_TYPES =
  'GET': true
  'POST': true

# request timeout time in milliseconds
TIMEOUT = 10000

# library to handle sync/async
asyncLib = require('async')
# library for finding a median in an array
medianLib = require('median')
# library for sending HTTP requests
requestLib = require('request')
# create application/x-www-form-urlencoded parser from request.body
urlencodedParserLib = require('body-parser').urlencoded({ extended: false })
# URL parsing library
urlLib = require('url')
# URL validation library
validUrlLib = require('valid-url')

module.exports = (app) ->
  app.get '/', (req, res) ->
    db = req.db
    collection = db.get('alldurations')
    collection.find {}, {}, (e, durations) ->
      context =
        'durations': durations,
        'NUM_OF_LAST_DURATIONS': NUM_OF_LAST_DURATIONS
      res.render 'index.ejs', context

  app.post '/add', urlencodedParserLib, (req, res) ->
    if not validUrlLib.isUri(req.body.url)
      res.status(500).send('newURLErrorURL')
      return
    if not REQUEST_TYPES[req.body.type]
      res.status(500).send('newURLErrorType')
      return

    db = req.db
    collection = db.get('alldurations')
    collection.findOne {url: req.body.url}, (error, result) ->
      if error
        res.status(500).send('newURLErrorSave')
        return
      if result
        res.status(500).send('newURLErrorDuplicate')
        return
      urlEntry =
        url: req.body.url
        type: req.body.type
        durations: []
      collection.insert urlEntry, (error, result) ->
        if error
          res.status(500).send('newURLErrorSave')
          return
        res.sendStatus(200)

  app.get '/run', (req, res) ->
    console.log('run')
    runChecks(req.db)
    res.sendStatus(200)
    db = req.db

runChecks = (db) ->
  collection = db.get('alldurations')
  collection.find {}, {}, (e, durations) ->
    requestDurations = []
    asyncLib.series durations.map (duration) ->
      (callbackOuter) ->
        url = duration['url']
        options = 
          uri: url
          time: true
          timeout: TIMEOUT
        requestType = duration['type']
        requestQueue = []
        if requestType is 'GET'
          asyncLib.series([1..NUM_OF_REQUESTS].map (_) ->
              (callbackInner) ->
                requestLib options, (error, response, body) ->
                  if error
                    requestDurations.push(null)
                  else
                    requestDurations.push(response.elapsedTime)
                  console.log(options['uri'])
                  console.log(requestDurations)
                  if requestDurations.length is NUM_OF_REQUESTS
                    median = medianLib(requestDurations)
                    requestDurations = []
                    console.log(median)
                  callbackInner(null)
            (err, results) ->
              callbackOuter(null))
        else if requestType is 'POST'
          url_parts = urlLib.parse(url, true)
          data = url_parts.query
          asyncLib.series([1..NUM_OF_REQUESTS].map (_) ->
              (callbackInner) ->
                requestLib.post options, data, callbackRequest
            (err, results) ->
              callbackOuter(null))

