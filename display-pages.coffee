# multiple for last durations average used as alert threshold
ALERT_MULTIPLE = 2

# number of last request runs to consider for benchmarking
NUM_OF_LAST_RUNS = 7

exports.index = (req, res) ->
  db = req.db
  byTimestamp = db.get 'byTimestamp'
  query =
    limit: 1
    sort:
      _id: -1
  byTimestamp.find {}, query, (error, resultArray) ->
    timestamp = if resultArray.length then resultArray[0]['timestamp'] else ''
    res.redirect "/timestamp/#{ timestamp }"

exports.showByTimestamp = (req, res) ->
  db = req.db
  byTimestamp = db.get 'byTimestamp'
  query =
    timestamp: req.params.timestamp
  byTimestamp.findOne query, (error, timestampRecord) ->
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

exports.showByUrl = (req, res) ->
  db = req.db
  byUrl = db.get 'byUrl'
  query =
    _id: req.params._id
  byUrl.findOne query, (error, urlRecord) ->
    if error
      res.sendStatus 500
      return
    context =
      data: urlRecord
    res.render 'url-data.ejs', context

exports.showTimestamps = (req, res) ->
  db = req.db
  byTimestamp = db.get 'byTimestamp'
  byTimestamp.find {}, {}, (e, dataByTimestamp) ->
    context =
      dataByTimestamp: dataByTimestamp
    res.render 'timestamps.ejs', context

exports.showUrls = (req, res) ->
  db = req.db
  byUrl = db.get 'byUrl'
  byUrl.find {}, {}, (e, urlRecords) ->
    context =
      urlRecords: urlRecords
    res.render 'urls.ejs', context