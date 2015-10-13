// Generated by CoffeeScript 1.9.3
var REQUEST_TYPES, validUrlLib;

REQUEST_TYPES = {
  'GET': true,
  'POST': true
};

validUrlLib = require('valid-url');

exports.addUrl = function(req, res) {
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
};

exports.deleteUrl = function(req, res) {
  var byUrl, db;
  db = req.db;
  byUrl = db.get('byUrl');
  return byUrl.remove(req.body, function(error, removed) {
    if (error) {
      res.sendStatus(500);
    }
    return res.sendStatus(200);
  });
};
