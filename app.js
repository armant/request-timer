// MongoDB
var mongo = require('mongodb');
var monk = require('monk');
var db = monk(process.env.MONGOLAB_URI || 'localhost:27017/requesttimer');

// Express
var express = require('express');
var app = express();

// Serve static files
app.use(express.static('static'));

// Make the db accessible to the router
app.use(function(req,res,next){
  req.db = db;
  next();
});

// Server startup
var server = app.listen(process.env.PORT || 3000, function () {
  var host = server.address().address;
  var port = server.address().port;
  console.log('App listening at http://%s:%s', host, port);
});

// Add metric objects to database if there are none
var metrics = db.get('metrics');
['duration', 'variance'].map(function(metric) {
  metrics.findOne({ metric: metric }, function(error, recordsObject) {
    if (error) {
      console.log('ERROR: the database could not be found');
      return;
    }
    if (!recordsObject) {
      metrics.insert({
        metric: metric,
        records: null,
        min: null
      });
    }
  });
});

// routes.js
require("./routes")(app);