// Generated by CoffeeScript 1.9.3
var ALERT_MULTIPLE, MAX_VALUE, NUM_OF_LAST_RUNS, NUM_OF_REQUESTS, REQUEST_TYPES, TIMEOUT, addDuration, asyncLib, executeRequests, findMedianRecord, jsonParserLib, requestLib, runChecks, urlLib, urlencodedParserLib, validUrlLib;

ALERT_MULTIPLE = 2;

MAX_VALUE = 100000;

NUM_OF_LAST_RUNS = 7;

NUM_OF_REQUESTS = 5;

REQUEST_TYPES = {
  'GET': true,
  'POST': true
};

TIMEOUT = 10000;

asyncLib = require('async');

requestLib = require('request');

urlencodedParserLib = require('body-parser').urlencoded({
  extended: false
});

jsonParserLib = require('body-parser').urlencoded({
  extended: false
});

urlLib = require('url');

validUrlLib = require('valid-url');

module.exports = function(app) {
  app.get('/', function(req, res) {
    var byTimestamp, db;
    db = req.db;
    byTimestamp = db.get('byTimestamp');
    return byTimestamp.find({}, {
      limit: 1,
      sort: {
        _id: -1
      }
    }, function(error, resultArray) {
      var timestamp;
      if (resultArray.length) {
        timestamp = resultArray[0]['timestamp'];
      } else {
        timestamp = 'no-records';
      }
      return res.redirect("/timestamp/" + timestamp);
    });
  });
  app.get('/timestamp/:timestamp', function(req, res) {
    var byTimestamp, db;
    db = req.db;
    byTimestamp = db.get('byTimestamp');
    return byTimestamp.findOne({
      timestamp: req.params.timestamp
    }, function(error, timestampRecord) {
      var context, currentUrlCount, progressPercentage, totalUrlCount;
      if (error) {
        res.sendStatus(500);
        return;
      }
      if (timestampRecord) {
        totalUrlCount = timestampRecord['urlCount'];
        currentUrlCount = timestampRecord['responseRecords'].length;
        progressPercentage = Math.floor(currentUrlCount / totalUrlCount * 100);
      } else {
        progressPercentage = 100;
      }
      context = {
        data: timestampRecord,
        progressPercentage: progressPercentage,
        NUM_OF_LAST_RUNS: NUM_OF_LAST_RUNS,
        ALERT_MULTIPLE: ALERT_MULTIPLE
      };
      return res.render('timestamp-data.ejs', context);
    });
  });
  app.get('/url/:_id', function(req, res) {
    var byUrl, db;
    db = req.db;
    byUrl = db.get('byUrl');
    return byUrl.findOne({
      _id: req.params._id
    }, function(error, urlRecord) {
      var context;
      if (error) {
        res.sendStatus(500);
        return;
      }
      context = {
        data: urlRecord
      };
      return res.render('url-data.ejs', context);
    });
  });
  app.get('/timestamps', function(req, res) {
    var byTimestamp, db;
    db = req.db;
    byTimestamp = db.get('byTimestamp');
    return byTimestamp.find({}, {}, function(e, dataByTimestamp) {
      var context;
      context = {
        dataByTimestamp: dataByTimestamp
      };
      return res.render('timestamps.ejs', context);
    });
  });
  app.get('/urls', function(req, res) {
    var byUrl, db;
    db = req.db;
    byUrl = db.get('byUrl');
    return byUrl.find({}, {}, function(e, urlRecords) {
      var context;
      context = {
        urlRecords: urlRecords
      };
      return res.render('urls.ejs', context);
    });
  });
  app.post('/add-url', urlencodedParserLib, function(req, res) {
    var _id, byUrl, data, db, type, url;
    url = req.body.url;
    type = req.body.type;
    data = type === 'GET' ? '' : req.body.data;
    _id = req.body._id;
    if (!validUrlLib.isUri(url)) {
      res.status(500).send('newURLErrorURL');
      return;
    }
    if (!REQUEST_TYPES[type]) {
      res.status(500).send('newURLErrorType');
      return;
    }
    if (data) {
      try {
        JSON.parse(data);
      } catch (_error) {
        res.status(500).send('newURLErrorData');
        return;
      }
    }
    db = req.db;
    byUrl = db.get('byUrl');
    return byUrl.findOne({
      url: url,
      type: type,
      data: data
    }, function(error, result) {
      var urlEntry;
      if (error) {
        res.status(500).send('newURLErrorSave');
        return;
      }
      if (result) {
        res.status(500).send('newURLErrorDuplicate');
        return;
      }
      byUrl.remove({
        _id: _id
      }, function(error, removed) {
        if (error) {
          res.status(500).send('newURLErrorSave');
        }
      });
      urlEntry = {
        url: url,
        type: type,
        data: data,
        durations: []
      };
      return byUrl.insert(urlEntry, function(error, insertedUrlObject) {
        if (error) {
          res.status(500).send('newURLErrorSave');
          return;
        }
        return res.send(insertedUrlObject['_id']);
      });
    });
  });
  app.post('/delete-url', jsonParserLib, function(req, res) {
    var byUrl, db;
    db = req.db;
    byUrl = db.get('byUrl');
    return byUrl.remove(req.body, function(error, removed) {
      if (error) {
        res.sendStatus(500);
      }
      return res.sendStatus(200);
    });
  });
  return app.get('/run', function(req, res) {
    runChecks(req.db);
    return res.redirect('/');
  });
};

runChecks = function(db) {
  var byTimestamp, byUrl;
  byUrl = db.get('byUrl');
  byTimestamp = db.get('byTimestamp');
  return byUrl.find({}, {}, function(e, urlRecords) {
    var timestamp, timestampRecord;
    timestamp = "" + (new Date().getTime());
    timestampRecord = {
      timestamp: timestamp,
      responseRecords: [],
      urlCount: urlRecords.length
    };
    byTimestamp.insert(timestampRecord);
    return asyncLib.series(urlRecords.map(function(urlRecord) {
      return function(callbackOuter) {
        var data, options, requestCallerFunction, requestType, url;
        url = urlRecord['url'];
        requestType = urlRecord['type'];
        data = urlRecord['data'];
        options = {
          uri: url,
          time: true,
          timeout: TIMEOUT
        };
        if (requestType === 'GET') {
          requestCallerFunction = function(requestCallerCallback) {
            return requestLib(options, requestCallerCallback);
          };
        } else if (requestType === 'POST') {
          requestCallerFunction = function(requestCallerCallback) {
            return requestLib.post(options, data, requestCallerCallback);
          };
        }
        return executeRequests(requestCallerFunction, db, url, requestType, data, timestamp, callbackOuter);
      };
    }));
  });
};

executeRequests = function(requestCallerFunction, db, url, requestType, data, timestamp, callbackOuter) {
  var i, responseRecords, results1;
  responseRecords = [];
  return asyncLib.series((function() {
    results1 = [];
    for (var i = 1; 1 <= NUM_OF_REQUESTS ? i <= NUM_OF_REQUESTS : i >= NUM_OF_REQUESTS; 1 <= NUM_OF_REQUESTS ? i++ : i--){ results1.push(i); }
    return results1;
  }).apply(this).map(function(_) {
    return function(callbackInner) {
      return requestCallerFunction(function(error, response, body) {
        var responseRecord;
        responseRecord = {
          url: url,
          type: requestType,
          data: data,
          statusCode: -1,
          time: null,
          size: null,
          timestamp: timestamp
        };
        if (!error) {
          responseRecord['statusCode'] = response.statusCode;
          responseRecord['time'] = response.elapsedTime;
          responseRecord['size'] = body.length;
        }
        responseRecords.push(responseRecord);
        if (responseRecords.length === NUM_OF_REQUESTS) {
          addDuration(db, url, requestType, data, responseRecords, timestamp);
          responseRecords = [];
        }
        return callbackInner(null);
      });
    };
  }), function(err, results) {
    return callbackOuter(null);
  });
};

addDuration = function(db, url, requestType, data, responseRecords, timestamp) {
  var byTimestamp, byUrl, currentDuration, responseRecord;
  responseRecord = findMedianRecord(responseRecords);
  currentDuration = responseRecord['time'];
  console.log(url);
  console.log(responseRecords);
  console.log(responseRecord);
  byUrl = db.get('byUrl');
  byUrl.findOne({
    url: url,
    type: requestType,
    data: data
  }, function(error, durationsObject) {
    var i, lastDurations, len, previousSizeAverage, previousTimeAverage, recordCount, sumDurations, sumSizes, variance;
    if (error) {
      console.log('ERROR: the database could be updated');
      return;
    }
    previousTimeAverage = durationsObject['lastDurationsAverage'];
    previousSizeAverage = durationsObject['lastSizesAverage'];
    variance = (currentDuration / durationsObject['lastDurationsAverage']).toFixed(2);
    responseRecord['previousTimeAverage'] = previousTimeAverage;
    responseRecord['previousSizeAverage'] = previousSizeAverage;
    responseRecord['variance'] = variance;
    if (previousTimeAverage * ALERT_MULTIPLE < currentDuration) {
      console.log("ALERT FIRED: " + url + " request duration of " + currentDuration + " exceeded the last " + NUM_OF_LAST_RUNS + "-check average of " + previousTimeAverage + " more than " + ALERT_MULTIPLE + " times");
    }
    durationsObject['durations'].push(responseRecord);
    durationsObject['lastDurations'] = durationsObject['durations'].slice(-NUM_OF_LAST_RUNS);
    lastDurations = durationsObject['lastDurations'];
    sumDurations = 0;
    sumSizes = 0;
    recordCount = 0;
    for (i = 0, len = lastDurations.length; i < len; i++) {
      responseRecord = lastDurations[i];
      if (responseRecord['time'] && responseRecord['size']) {
        sumDurations += responseRecord['time'];
        sumSizes += responseRecord['size'];
        recordCount++;
      }
    }
    durationsObject['lastDurationsAverage'] = Math.floor(sumDurations / recordCount);
    durationsObject['lastSizesAverage'] = Math.floor(sumSizes / recordCount);
    return byUrl.update({
      _id: durationsObject['_id']
    }, durationsObject);
  });
  byTimestamp = db.get('byTimestamp');
  return byTimestamp.findOne({
    timestamp: timestamp
  }, function(error, timestampRecord) {
    if (error) {
      console.log('ERROR: the database could be updated');
      return;
    }
    timestampRecord['responseRecords'].push(responseRecord);
    return byTimestamp.update({
      _id: timestampRecord['_id']
    }, timestampRecord);
  });
};

findMedianRecord = function(responseRecords) {
  var middle;
  responseRecords.sort(function(a, b) {
    return a.time - b.time;
  });
  middle = Math.floor(responseRecords.length / 2);
  return responseRecords[middle];
};
