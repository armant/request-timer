// Generated by CoffeeScript 1.9.3
var NUM_OF_LAST_DURATIONS, REQUEST_TYPES, bodyParser, urlencodedParser, validUrl;

NUM_OF_LAST_DURATIONS = 7;

REQUEST_TYPES = {
  'GET': true,
  'POST': true
};

bodyParser = require('body-parser');

urlencodedParser = bodyParser.urlencoded({
  extended: false
});

validUrl = require('valid-url');

module.exports = function(app) {
  app.get('/', function(req, res) {
    var collection, db;
    db = req.db;
    collection = db.get('alldurations');
    return collection.find({}, {}, function(e, durations) {
      var context;
      context = {
        'durations': durations,
        'NUM_OF_LAST_DURATIONS': NUM_OF_LAST_DURATIONS
      };
      return res.render('index.ejs', context);
    });
  });
  return app.post('/add', urlencodedParser, function(req, res) {
    var collection, db;
    if (!validUrl.isUri(req.body.url)) {
      res.status(500).send('newURLErrorURL');
      return;
    }
    if (!REQUEST_TYPES[req.body.type]) {
      res.status(500).send('newURLErrorType');
      return;
    }
    db = req.db;
    collection = db.get('alldurations');
    return collection.findOne({
      url: req.body.url
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
      urlEntry = {
        url: req.body.url,
        type: req.body.type,
        durations: []
      };
      return collection.insert(urlEntry, function(error, result) {
        if (error) {
          res.status(500).send('newURLErrorSave');
          return;
        }
        return res.sendStatus(200);
      });
    });
  });
};
