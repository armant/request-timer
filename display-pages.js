// Generated by CoffeeScript 1.9.3
var ALERT_MULTIPLE, NUM_OF_LAST_RUNS;

ALERT_MULTIPLE = 2;

NUM_OF_LAST_RUNS = 7;

exports.index = function(req, res) {
  var byTimestamp, db, query;
  db = req.db;
  byTimestamp = db.get('byTimestamp');
  query = {
    limit: 1,
    sort: {
      _id: -1
    }
  };
  return byTimestamp.find({}, query, function(error, resultArray) {
    var timestamp;
    timestamp = resultArray.length ? resultArray[0]['timestamp'] : '';
    return res.redirect("/timestamp/" + timestamp);
  });
};

exports.showByTimestamp = function(req, res) {
  var byTimestamp, db, query;
  db = req.db;
  byTimestamp = db.get('byTimestamp');
  query = {
    timestamp: req.params.timestamp
  };
  return byTimestamp.findOne(query, function(error, timestampRecord) {
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
};

exports.showByUrl = function(req, res) {
  var byUrl, db, query;
  db = req.db;
  byUrl = db.get('byUrl');
  query = {
    _id: req.params._id
  };
  return byUrl.findOne(query, function(error, urlRecord) {
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
};

exports.showTimestamps = function(req, res) {
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
};

exports.showUrls = function(req, res) {
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
};
