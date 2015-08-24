NUM_OF_LAST_DURATIONS = 7;

module.exports = function (app) {
  app.get("/", function (req, res) {
    db = req.db;
    var collection = db.get('alldurations');
    collection.find({}, {}, function(e, durations){
      res.render('index.ejs', {
        "durations" : durations,
        "NUM_OF_LAST_DURATIONS": NUM_OF_LAST_DURATIONS
      });
    });
  });
};