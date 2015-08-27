# number of last request durations to consider for benchmarking
NUM_OF_LAST_DURATIONS = 7

# allowed request types
REQUEST_TYPES =
  'GET': true
  'POST': true

# create application/x-www-form-urlencoded parser from request.body
bodyParser = require('body-parser')
urlencodedParser = bodyParser.urlencoded({ extended: false })
# URL validation library
validUrl = require('valid-url')

module.exports = (app) ->
  app.get '/', (req, res) ->
    db = req.db
    collection = db.get('alldurations')
    collection.find {}, {}, (e, durations) ->
      context =
        'durations': durations,
        'NUM_OF_LAST_DURATIONS': NUM_OF_LAST_DURATIONS
      res.render 'index.ejs', context

  app.post '/add', urlencodedParser, (req, res) ->
    if not validUrl.isUri(req.body.url)
      res.status(500).send('newURLErrorURL')
      return
    if not REQUEST_TYPES[req.body.type]
      res.status(500).send('newURLErrorType')
      return
      
    db = req.db
    collection = db.get('alldurations')
    collection.findOne {url: req.body.url}, (error, result) ->
      if error
        res.status(500).send('newURLErrorSave')
        return
      if result
        res.status(500).send('newURLErrorDuplicate')
        return
      urlEntry =
        url: req.body.url
        type: req.body.type
        durations: []
      collection.insert urlEntry, (error, result) ->
        if error
          res.status(500).send('newURLErrorSave')
          return
        res.sendStatus(200)
