# multiple for last durations average used as alert threshold
ALERT_MULTIPLE = 2

# upper bound constant for request time and variance
MAX_VALUE = 100000

# number of last request durations to consider for benchmarking
NUM_OF_LAST_DURATIONS = 7

# number of the most extreme durations to display
NUM_OF_MOST_EXTREME = 10

# number of requests for one URL test
NUM_OF_REQUESTS = 5

# allowed request types
REQUEST_TYPES =
  'GET': true
  'POST': true

# request timeout time in milliseconds
TIMEOUT = 10000

# library to handle sync/async
asyncLib = require 'async'
# library for finding a median in an array
medianLib = require 'median'
# library for sending HTTP requests
requestLib = require 'request'
# create application/x-www-form-urlencoded parser from request.body
urlencodedParserLib = require('body-parser').urlencoded { extended: false }
# URL parsing library
urlLib = require 'url'
# URL validation library
validUrlLib = require 'valid-url'

module.exports = (app) ->
  app.get '/', (req, res) ->
    db = req.db
    collection = db.get 'alldurations'
    collection.find {}, {}, (e, durations) ->
      context =
        'durations': durations,
        'NUM_OF_LAST_DURATIONS': NUM_OF_LAST_DURATIONS
      res.render 'index.ejs', context

  app.post '/add', urlencodedParserLib, (req, res) ->
    if not validUrlLib.isUri(req.body.url)
      res.status(500).send 'newURLErrorURL'
      return
    if not REQUEST_TYPES[req.body.type]
      res.status(500).send 'newURLErrorType'
      return

    db = req.db
    collection = db.get 'alldurations'
    collection.findOne {url: req.body.url}, (error, result) ->
      if error
        res.status(500).send 'newURLErrorSave'
        return
      if result
        res.status(500).send 'newURLErrorDuplicate'
        return
      urlEntry =
        url: req.body.url
        type: req.body.type
        durations: []
      collection.insert urlEntry, (error, result) ->
        if error
          res.status(500).send 'newURLErrorSave'
          return
        res.sendStatus 200

  app.get '/run', (req, res) ->
    timestamp = Math.floor new Date() / 1000
    runChecks req.db, timestamp
    res.sendStatus 200
    db = req.db

  app.get '/dashboard', (req, res) ->
    db = req.db
    collection = db.get 'metrics'
    collection.findOne {metric: 'duration'}, (error, slowestDurations) ->
      if error
        console.log 'ERROR: the database could not be accessed'
      collection.findOne {metric: 'variance'}, (error, mostVaryingDurations) ->
        if error
          console.log 'ERROR: the database could not be accessed'
        context =
          slowestDurations: slowestDurations
          mostVaryingDurations: mostVaryingDurations
        res.render 'dashboard.ejs', context


runChecks = (db, timestamp) ->
  # refresh the dashboards
  metrics = db.get 'metrics'
  asyncLib.series(['duration', 'variance'].map (metric) ->
      (callback) ->
        metrics.findOne {metric: metric}, (error, recordsObject) ->
          if error
            console.log 'ERROR: the database could not be updated'
            return
          recordsObject['records'] = []
          recordsObject['min'] = MAX_VALUE
          metrics.update { _id: recordsObject['_id'] }, recordsObject
          callback null
    (err, results) ->
      collection = db.get 'alldurations'
      collection.find {}, {}, (e, durations) ->
        asyncLib.series durations.map (duration) ->
          (callbackOuter) ->
            url = duration['url']
            options =
              uri: url
              time: true
              timeout: TIMEOUT
            requestType = duration['type']
            url_parts = urlLib.parse url, true
            data = url_parts.query
            if requestType is 'GET'
              requestCallerFunction = (requestCallerCallback) ->
                requestLib options, requestCallerCallback
            else if requestType is 'POST'
              requestCallerFunction = (requestCallerCallback) ->
                requestLib.post options, data, requestCallerCallback
            console.log 'executing request'
            executeRequests(requestCallerFunction,
                            db,
                            options['uri'],
                            timestamp,
                            callbackOuter))

executeRequests = (requestCallerFunction, db, uri, timestamp, callbackOuter) ->
  requestDurations = []
  asyncLib.series([1..NUM_OF_REQUESTS].map (_) ->
      (callbackInner) ->
        requestCallerFunction (error, response, body) ->
          requestDurations.push(
              if error then null else response.elapsedTime)
          if requestDurations.length is NUM_OF_REQUESTS
            addDuration(db, uri, requestDurations, timestamp)
            requestDurations = []
          callbackInner null
    (err, results) ->
      callbackOuter null)

addDuration = (db, url, durationsArray, timestamp) ->
  # update the database with new measurement
  currentDuration = medianLib(durationsArray)
  console.log url
  console.log durationsArray
  console.log currentDuration
  allDurations = db.get 'alldurations'
  allDurations.findOne {url: url}, (error, durationsObject) ->
    if error
      console.log 'ERROR: the database could be updated'
      return
    average = durationsObject['lastDurationsAverage']
    if average*ALERT_MULTIPLE < currentDuration
      console.log "ALERT FIRED: #{ url } request duration of
                   #{ currentDuration } exceeded the last
                   #{ NUM_OF_LAST_DURATIONS }-check average of #{ average } more
                   than #{ ALERT_MULTIPLE } times"
    newDuration = {}
    newDuration[timestamp] = currentDuration
    durationsObject['durations'].push newDuration
    durationsObject['lastDurations'] =
      durationsObject['durations'][-NUM_OF_LAST_DURATIONS..]

    #recalculate the moving average and recent records
    lastDurations = durationsObject['lastDurations']
    sumDurations = 0
    countDurations = 0
    for durationObject in lastDurations
      for timestamp, duration of durationObject
        if duration
          sumDurations += duration
          countDurations++
    durationsObject['lastDurationsAverage'] = sumDurations / countDurations
    allDurations.update { _id: durationsObject['_id'] }, durationsObject

    # update the 'slowest' and 'most varying' entries
    variance = currentDuration / durationsObject['lastDurationsAverage']
    metricStrings = ['duration', 'variance']
    metricValues = [currentDuration, variance]
    metrics = db.get 'metrics'
    [0, 1].map (metricIndex) ->
      metricString = metricStrings[metricIndex]
      metricValue = metricValues[metricIndex]
      metrics.findOne {metric: metricString}, (error, recordsObject) ->
        if error
          console.log 'ERROR: the database could not be updated'
          return
        min = recordsObject['min']
        newRecord = { url: url }
        newRecord[metricString] = metricValue
        if recordsObject['records'].length < NUM_OF_MOST_EXTREME and metricValue
          recordsObject['records'].push newRecord
          if min > metricValue
            recordsObject['min'] = metricValue
        else
          if min < metricValue
            newMin = MAX_VALUE
            for record, index in recordsObject['records']
              if record[metricString] is min
                recordsObject['records'][index] = newRecord
              if newMin > recordsObject['records'][index][metricString]
                newMin = recordsObject['records'][index][metricString]
            recordsObject['min'] = newMin
        console.log recordsObject
        metrics.update { _id: recordsObject['_id'] }, recordsObject