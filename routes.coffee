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
# library for sending HTTP requests
requestLib = require 'request'
# create application/x-www-form-urlencoded parser from request.body
urlencodedParserLib = require('body-parser').urlencoded { extended: false }
# URL parsing library
urlLib = require 'url'
# URL validation library
validUrlLib = require 'valid-url'

module.exports = (app) ->
  app.get '/stats-by-url', (req, res) ->
    db = req.db
    allDurations = db.get 'alldurations'
    allDurations.find {}, {}, (e, durations) ->
      durationsByTimestamp = db.get 'durationsByTimestamp'
      durationsByTimestamp.find {}, {}, (e, byTimestamp) ->
        context =
          'durations': durations
          'NUM_OF_LAST_DURATIONS': NUM_OF_LAST_DURATIONS
          'byTimestamp': byTimestamp
        res.render 'by-url.ejs', context

  app.post '/add', urlencodedParserLib, (req, res) ->
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
      allDurations.insert urlEntry, (error, result) ->
        if error
          res.status(500).send 'newURLErrorSave'
          return
        res.sendStatus 200

  app.get '/run', (req, res) ->
    timestamp = "#{Math.floor new Date() / 1000}"
    runChecks req.db, timestamp
    res.redirect '/'

  app.get '/', (req, res) ->
    db = req.db
    allDurations = db.get('alldurations')
    allDurations.count {}, (error, totalCount) ->
      metrics = db.get 'metrics'
      metrics.findOne {metric: 'duration'}, (error, slowestDurations) ->
        if error
          console.log 'ERROR: the database could not be accessed'
          return
        metrics.findOne {metric: 'variance'}, (error, mostVaryingDurations) ->
          if error
            console.log 'ERROR: the database could not be accessed'
            return
          progressPercentage = Math.floor Math.min(
              slowestDurations['records'].length,
              mostVaryingDurations['records'].length) / totalCount * 100
          console.log progressPercentage
          context =
            progressPercentage: progressPercentage
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
      allDurations = db.get 'alldurations'
      allDurations.find {}, {}, (e, durations) ->
        asyncLib.series durations.map (duration) ->
          (callbackOuter) ->
            url = duration['url']
            options =
              uri: url
              time: true
              timeout: TIMEOUT
            requestType = duration['type']
            if requestType is 'GET'
              requestCallerFunction = (requestCallerCallback) ->
                requestLib options, requestCallerCallback
            else if requestType is 'POST'
              data = duration['data']
              requestCallerFunction = (requestCallerCallback) ->
                requestLib.post options, data, requestCallerCallback
            executeRequests(requestCallerFunction,
                            db,
                            url,
                            requestType,
                            timestamp,
                            callbackOuter))

executeRequests = (
    requestCallerFunction, db, url, requestType, timestamp, callbackOuter) ->
  responseRecords = []
  asyncLib.series([1..NUM_OF_REQUESTS].map (_) ->
      (callbackInner) ->
        requestCallerFunction (error, response, body) ->
          if error
            responseRecord =
              time: null
          else
            responseRecord =
              url: url
              type: requestType
              time: response.elapsedTime
              statusCode: response.statusCode
              length: body.length
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
      average = durationsObject['lastDurationsAverage']
      if average*ALERT_MULTIPLE < currentDuration
        console.log "ALERT FIRED: #{ url } request duration of
                     #{ currentDuration } exceeded the last
                     #{ NUM_OF_LAST_DURATIONS }-check average of #{ average }
                     more than #{ ALERT_MULTIPLE } times"
      newDuration = {}
      newDuration[timestamp] = responseRecord
      durationsObject['durations'].push newDuration
      durationsObject['lastDurations'] =
        durationsObject['durations'][-NUM_OF_LAST_DURATIONS..]

      #recalculate the moving average and recent records
      lastDurations = durationsObject['lastDurations']
      sumDurations = 0
      countDurations = 0
      for durationObject in lastDurations
        for timestamp, responseRecord of durationObject
          if responseRecord['time']
            sumDurations += responseRecord['time']
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
          newRecord = { url: url, type: requestType }
          newRecord[metricString] = metricValue
          recordsObject['records'].push newRecord
          ###
          Use the snippet below if it is needed to store top X URLs in the
          performance dashboard, instead of storing all like we currently do.
          The snippet below would replace the three lines above.
          ______________________________________________________________________
          min = recordsObject['min']
          newRecord = { url: url, type: requestType }
          newRecord[metricString] = metricValue
          if (recordsObject['records'].length < NUM_OF_MOST_EXTREME and
              metricValue)
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
          ###
          metrics.update { _id: recordsObject['_id'] }, recordsObject)

  # update the (timestamp -> data) collection with new measurement
  durationsByTimestamp = db.get 'durationsByTimestamp'
  durationsByTimestamp.findOne(
    {timestamp: timestamp},
    (error, durationsObject) ->
      if error
        console.log 'ERROR: the database could be updated'
        return
      if not durationsObject
        durationsObject =
          timestamp: timestamp
          durations: []
      durationsObject['durations'].push responseRecord
      if durationsObject['_id']
        durationsByTimestamp.update(
            { _id: durationsObject['_id'] }, durationsObject)
      else
        durationsByTimestamp.insert durationsObject)

findMedianRecord = (responseRecords) ->
  responseRecords.sort (a, b) ->
    a.time - b.time
  middle = Math.floor responseRecords.length / 2
  return responseRecords[middle]