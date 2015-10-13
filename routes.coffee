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
    byTimestamp = db.get 'byTimestamp'
    byTimestamp.find {}, {limit: 1, sort: {_id: -1}}, (error, resultArray) ->
      timestamp = if resultArray.length then resultArray[0]['timestamp'] else ''
      res.redirect "/timestamp/#{ timestamp }"

  app.get '/timestamp/:timestamp', (req, res) ->
    db = req.db
    byTimestamp = db.get 'byTimestamp'
    byTimestamp.findOne {timestamp: req.params.timestamp}, (error, timestampRecord) ->
      if error
        res.sendStatus 500
        return
      if timestampRecord
        totalUrlCount = timestampRecord['urlCount']
        currentUrlCount = timestampRecord['responseRecords'].length
        progressPercentage = Math.floor currentUrlCount / totalUrlCount * 100
      else
        progressPercentage = 100
      context =
        data: timestampRecord
        progressPercentage: progressPercentage
        NUM_OF_LAST_RUNS: NUM_OF_LAST_RUNS
        ALERT_MULTIPLE: ALERT_MULTIPLE
      res.render 'timestamp-data.ejs', context

  app.get '/url/:_id', (req, res) ->
    db = req.db
    byUrl = db.get 'byUrl'
    byUrl.findOne {_id: req.params._id}, (error, urlRecord) ->
      if error
        res.sendStatus 500
        return
      context =
        data: urlRecord
      res.render 'url-data.ejs', context

  app.get '/timestamps', (req, res) ->
    db = req.db
    byTimestamp = db.get 'byTimestamp'
    byTimestamp.find {}, {}, (e, dataByTimestamp) ->
      context =
        dataByTimestamp: dataByTimestamp
      res.render 'timestamps.ejs', context

  app.get '/urls', (req, res) ->
    db = req.db
    byUrl = db.get 'byUrl'
    byUrl.find {}, {}, (e, urlRecords) ->
      context =
        urlRecords: urlRecords
      res.render 'urls.ejs', context

  app.post '/add-url', urlencodedParserLib, (req, res) ->
    url = req.body.url
    type = req.body.type
    data = if type is 'GET' then '' else req.body.data
    _id = req.body._id
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
    byUrl = db.get 'byUrl'
    byUrl.findOne {url: url, type: type, data: data}, (error, result) ->
      if error
        res.status(500).send 'newURLErrorSave'
        return
      if result
        res.status(500).send 'newURLErrorDuplicate'
        return
      byUrl.remove {_id: _id}, (error, removed) ->
        if error
          res.status(500).send 'newURLErrorSave'
          return
      urlEntry =
        url: url
        type: type
        data: data
        durations: []
      byUrl.insert urlEntry, (error, insertedUrlObject) ->
        if error
          res.status(500).send 'newURLErrorSave'
          return
        res.send insertedUrlObject['_id']

  app.post '/delete-url', jsonParserLib, (req, res) ->
    db = req.db
    byUrl = db.get 'byUrl'
    byUrl.remove req.body, (error, removed) ->
      if error
        res.sendStatus 500
      res.sendStatus 200

  app.get '/run', (req, res) ->
    runChecks req.db
    res.redirect '/'

runChecks = (db) ->
  byUrl = db.get 'byUrl'
  byTimestamp = db.get 'byTimestamp'
  byUrl.find {}, {}, (e, urlRecords) ->
    timestamp = "#{new Date().getTime()}"
    timestampRecord =
      timestamp: timestamp
      responseRecords: []
      urlCount: urlRecords.length
    byTimestamp.insert timestampRecord
    asyncLib.series urlRecords.map (urlRecord) ->
      (callbackOuter) ->
        url = urlRecord['url']
        requestType = urlRecord['type']
        data = urlRecord['data']
        options =
          uri: url
          time: true
          timeout: TIMEOUT
        if requestType is 'GET'
          requestCallerFunction = (requestCallerCallback) ->
            requestLib options, requestCallerCallback
        else if requestType is 'POST'
          requestCallerFunction = (requestCallerCallback) ->
            requestLib.post options, data, requestCallerCallback
        executeRequests(requestCallerFunction,
                        db,
                        url,
                        requestType,
                        data,
                        timestamp,
                        callbackOuter)

executeRequests = (
    requestCallerFunction,
    db,
    url,
    requestType,
    data,
    timestamp,
    callbackOuter) ->
  responseRecords = []
  asyncLib.series([1..NUM_OF_REQUESTS].map (_) ->
      (callbackInner) ->
        requestCallerFunction (error, response, body) ->
          responseRecord =
              url: url
              type: requestType
              data: data
              statusCode: -1
              time: null
              size: null
              timestamp: timestamp
          if not error
            responseRecord['statusCode'] = response.statusCode
            responseRecord['time'] = response.elapsedTime
            responseRecord['size'] = body.length
          responseRecords.push responseRecord
          if responseRecords.length is NUM_OF_REQUESTS
            addDuration(db, url, requestType, data, responseRecords, timestamp)
            responseRecords = []
          callbackInner null
    (err, results) ->
      callbackOuter null)

addDuration = (db, url, requestType, data, responseRecords, timestamp) ->
  # update the (URLs -> data) collection with new measurement
  responseRecord = findMedianRecord responseRecords
  currentDuration = responseRecord['time']
  console.log url
  console.log responseRecords
  console.log responseRecord
  byUrl = db.get 'byUrl'
  byUrl.findOne(
    {url: url, type: requestType, data: data},
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
                     #{ NUM_OF_LAST_RUNS }-check average of
                     #{ previousTimeAverage } more than #{ ALERT_MULTIPLE }
                     times"
      durationsObject['durations'].push responseRecord
      durationsObject['lastDurations'] =
        durationsObject['durations'][-NUM_OF_LAST_RUNS..]

      #recalculate the moving averages and recent records
      lastDurations = durationsObject['lastDurations']
      sumDurations = 0
      sumSizes = 0
      recordCount = 0
      for responseRecord in lastDurations
        if responseRecord['time'] and responseRecord['size']
          sumDurations += responseRecord['time']
          sumSizes += responseRecord['size']
          recordCount++
      durationsObject['lastDurationsAverage'] = Math.floor(
          sumDurations / recordCount)
      durationsObject['lastSizesAverage'] = Math.floor sumSizes / recordCount
      byUrl.update { _id: durationsObject['_id'] }, durationsObject)

  # update the (timestamp -> data) collection with new measurement
  byTimestamp = db.get 'byTimestamp'
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