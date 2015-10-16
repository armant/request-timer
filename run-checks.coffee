# multiple for last durations average used as alert threshold
ALERT_MULTIPLE = 2

# number of last request runs to consider for benchmarking
NUM_OF_LAST_RUNS = 7

# number of requests for one URL test
NUM_OF_REQUESTS = 5

# request timeout time in milliseconds
TIMEOUT = 10000

# library to handle sync/async
asyncLib = require 'async'

# library for sending HTTP requests
requestLib = require 'request'

exports.run = (req, res) ->
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
        headers = urlRecord['headers']
        data = urlRecord['data']
        options =
          uri: url
          headers: if headers then headers else {}
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
                        headers,
                        data,
                        timestamp,
                        callbackOuter)

executeRequests = (
    requestCallerFunction,
    db,
    url,
    requestType,
    headers,
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
              headers: headers
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
            addDuration(db, responseRecords, timestamp)
            responseRecords = []
          callbackInner null
    (err, results) ->
      callbackOuter null)

addDuration = (db, responseRecords, timestamp) ->
  # update the (URLs -> data) collection with new measurement
  responseRecord = findMedianRecord responseRecords
  currentDuration = responseRecord['time']
  byUrl = db.get 'byUrl'
  query =
    url: responseRecord['url']
    type: responseRecord['type']
    headers: responseRecord['headers']
    data: responseRecord['data']
  byUrl.findOne query, (error, durationsObject) ->
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
    byUrl.update { _id: durationsObject['_id'] }, durationsObject

  # update the (timestamp -> data) collection with new measurement
  byTimestamp = db.get 'byTimestamp'
  query =
    timestamp: timestamp
  byTimestamp.findOne query, (error, timestampRecord) ->
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