# multiple for last durations average used as alert threshold
ALERT_MULTIPLE = 2

# upper bound constant for request time and variance
MAX_VALUE = 100000

# number of last request runs to consider for benchmarking
NUM_OF_LAST_RUNS = 7

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
# library for sending HTTP requests
requestLib = require 'request'
# library for application/x-www-form-urlencoded parser from request.body
urlencodedParserLib = require('body-parser').urlencoded { extended: false }
# library for JSON parser from request.body
jsonParserLib = require('body-parser').urlencoded { extended: false }
# URL parsing library
urlLib = require 'url'
# URL validation library
validUrlLib = require 'valid-url'

module.exports = (app) ->
  app.get '/', (req, res) ->
    db = req.db
    allDurations = db.get 'alldurations'
    allDurations.count {}, (error, totalCount) ->
      db.get('dataByTimestamp').find(
        {},
        {limit: 1, sort: {_id: -1}},
        (error, resultArray) ->
          lastRecord = resultArray[0]
          progressPercentage = Math.floor(
              lastRecord['responseRecords'].length / totalCount * 100)
          context =
            data: lastRecord
            progressPercentage: progressPercentage
            NUM_OF_LAST_RUNS: NUM_OF_LAST_RUNS
          res.render 'latest.ejs', context)

  app.get '/data-by-url', (req, res) ->
    db = req.db
    allDurations = db.get 'alldurations'
    allDurations.find {}, {}, (e, urlRecords) ->
      context =
        'urlRecords': urlRecords
        'NUM_OF_LAST_RUNS': NUM_OF_LAST_RUNS
      res.render 'by-url.ejs', context

  app.get '/data-by-timestamp', (req, res) ->
    db = req.db
    byTimestamp = db.get 'dataByTimestamp'
    byTimestamp.find {}, {}, (e, dataByTimestamp) ->
      context =
        'dataByTimestamp': dataByTimestamp
      res.render 'by-timestamp.ejs', context

  app.get '/crud', (req, res) ->
    db = req.db
    allDurations = db.get 'alldurations'
    allDurations.find {}, {}, (e, urlRecords) ->
      context =
        urlRecords: urlRecords
      res.render 'crud.ejs', context

  app.post '/add-url', urlencodedParserLib, (req, res) ->
    url = req.body.url
    type = req.body.type
    data = req.body.data
    if not validUrlLib.isUri(url)
      res.status(500).send 'newURLErrorURL'
      return
    if not REQUEST_TYPES[type]
      res.status(500).send 'newURLErrorType'
      return
    if data
      try
        JSON.parse data
      catch
        res.status(500).send 'newURLErrorData'
        return

    db = req.db
    allDurations = db.get 'alldurations'
    allDurations.findOne {url: url, type: type}, (error, result) ->
      if error
        res.status(500).send 'newURLErrorSave'
        return
      if result
        res.status(500).send 'newURLErrorDuplicate'
        return
      urlEntry =
        url: url
        type: type
        data: data
        durations: []
      allDurations.insert urlEntry, (error, insertedUrlObject) ->
        if error
          res.status(500).send 'newURLErrorSave'
          return
        res.send insertedUrlObject['_id']

  app.post '/delete-url', jsonParserLib, (req, res) ->
    db = req.db
    allDurations = db.get 'alldurations'
    allDurations.remove req.body, (error, removed) ->
      if error
        res.sendStatus 500
      res.sendStatus 200

  app.get '/run', (req, res) ->
    timestamp = "#{Math.floor new Date() / 1000}"
    runChecks req.db, timestamp
    res.redirect '/'

runChecks = (db, timestamp) ->
  byTimestamp = db.get 'dataByTimestamp'
  timestampRecord =
    timestamp: timestamp
    responseRecords: []
  byTimestamp.insert timestampRecord

  allDurations = db.get 'alldurations'
  allDurations.find {}, {}, (e, urlRecords) ->
    asyncLib.series urlRecords.map (urlRecords) ->
      (callbackOuter) ->
        url = urlRecords['url']
        options =
          uri: url
          time: true
          timeout: TIMEOUT
        requestType = urlRecords['type']
        if requestType is 'GET'
          requestCallerFunction = (requestCallerCallback) ->
            requestLib options, requestCallerCallback
        else if requestType is 'POST'
          data = urlRecords['data']
          requestCallerFunction = (requestCallerCallback) ->
            requestLib.post options, data, requestCallerCallback
        executeRequests(requestCallerFunction,
                        db,
                        url,
                        requestType,
                        timestamp,
                        callbackOuter)

executeRequests = (
    requestCallerFunction, db, url, requestType, timestamp, callbackOuter) ->
  responseRecords = []
  asyncLib.series([1..NUM_OF_REQUESTS].map (_) ->
      (callbackInner) ->
        requestCallerFunction (error, response, body) ->
          if error
            responseRecord =
              url: url
              type: requestType
              time: null
              statusCode: null
              size: null
          else
            responseRecord =
              url: url
              type: requestType
              time: response.elapsedTime
              statusCode: response.statusCode
              size: body.length
          responseRecords.push responseRecord
          if responseRecords.length is NUM_OF_REQUESTS
            addDuration(db, url, requestType, responseRecords, timestamp)
            responseRecords = []
          callbackInner null
    (err, results) ->
      callbackOuter null)

addDuration = (db, url, requestType, responseRecords, timestamp) ->
  # update the (URLs -> data) collection with new measurement
  responseRecord = findMedianRecord responseRecords
  currentDuration = responseRecord['time']
  console.log url
  console.log responseRecords
  console.log responseRecord
  allDurations = db.get 'alldurations'
  allDurations.findOne(
    {url: url, type: requestType},
    (error, durationsObject) ->
      if error
        console.log 'ERROR: the database could be updated'
        return
      previousTimeAverage = durationsObject['lastDurationsAverage']
      previousSizeAverage = durationsObject['lastSizesAverage']
      variance = (currentDuration / durationsObject['lastDurationsAverage'])
          .toFixed(2)
      responseRecord['previousTimeAverage'] = previousTimeAverage
      responseRecord['previousSizeAverage'] = previousSizeAverage
      responseRecord['variance'] = variance
      if previousTimeAverage*ALERT_MULTIPLE < currentDuration
        console.log "ALERT FIRED: #{ url } request duration of
                     #{ currentDuration } exceeded the last
                     #{ NUM_OF_LAST_RUNS }-check average of #{ average }
                     more than #{ ALERT_MULTIPLE } times"
      newDuration = {}
      newDuration[timestamp] = responseRecord
      durationsObject['durations'].push newDuration
      durationsObject['lastDurations'] =
        durationsObject['durations'][-NUM_OF_LAST_RUNS..]

      #recalculate the moving averages and recent records
      lastDurations = durationsObject['lastDurations']
      sumDurations = 0
      sumSizes = 0
      recordCount = 0
      for durationObject in lastDurations
        for timestamp, responseRecord of durationObject
          if responseRecord['time'] and responseRecord['size']
            sumDurations += responseRecord['time']
            sumSizes += responseRecord['size']
            recordCount++
      durationsObject['lastDurationsAverage'] = Math.floor(
          sumDurations / recordCount)
      durationsObject['lastSizesAverage'] = Math.floor sumSizes / recordCount
      allDurations.update { _id: durationsObject['_id'] }, durationsObject)

  # update the (timestamp -> data) collection with new measurement
  byTimestamp = db.get 'dataByTimestamp'
  byTimestamp.findOne {timestamp: timestamp}, (error, timestampRecord) ->
    if error
      console.log 'ERROR: the database could be updated'
      return
    timestampRecord['responseRecords'].push responseRecord
    byTimestamp.update({_id: timestampRecord['_id']}, timestampRecord)

findMedianRecord = (responseRecords) ->
  responseRecords.sort (a, b) ->
    a.time - b.time
  middle = Math.floor responseRecords.length / 2
  return responseRecords[middle]