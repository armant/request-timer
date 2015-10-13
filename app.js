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

// Route handlers
var displayPages = require("./display-pages");
var manageUrls = require("./manage-urls");
var runChecks = require("./run-checks");

// Library for application/x-www-form-urlencoded parser from request.body
urlencodedParserLib = require('body-parser').urlencoded({ extended: false });
// Library for JSON parser from request.body
jsonParserLib = require('body-parser').urlencoded({ extended: false });

// Routes
app.get('/', displayPages.index);
app.get('/timestamp', displayPages.showTimestamps);
app.get('/timestamp/:timestamp', displayPages.showByTimestamp);
app.get('/url', displayPages.showUrls);
app.get('/url/:_id', displayPages.showByUrl);



app.post('/url', urlencodedParserLib, manageUrls.addUrl);
app.delete('/url', jsonParserLib, manageUrls.deleteUrl);

app.get('/run', runChecks.run);

// Server startup
var server = app.listen(process.env.PORT || 3000, function () {
  var host = server.address().address;
  var port = server.address().port;
  console.log('App listening at http://%s:%s', host, port);
});