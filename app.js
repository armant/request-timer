// MongoDB
var mongo = require('mongodb');
var monk = require('monk');
var db = monk('localhost:27017/requesttimer');

// Express
var express = require('express');
var app = express();

// Make the db accessible to the router
app.use(function(req,res,next){
    req.db = db;
    next();
});

// routes.js
require("./routes")(app);

// Server startup
var server = app.listen(3000, function () {
  var host = server.address().address;
  var port = server.address().port;
  console.log('App listening at http://%s:%s', host, port);
});
