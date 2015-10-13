# allowed request types
REQUEST_TYPES =
  'GET': true
  'POST': true

# URL validation library
validUrlLib = require 'valid-url'

exports.addUrl = (req, res) ->
  url = req.body.url
  type = req.body.type
  data = if type is 'GET' then '' else req.body.data
  _id = req.body._id
  if not validUrlLib.isUri(url)
    res.status(500).send 'newURLErrorURL'
    return
  if not REQUEST_TYPES[type]
    res.status(500).send 'newURLErrorType'
    return
  if data
    try
      JSON.parse data
    catch
      res.status(500).send 'newURLErrorData'
      return

  db = req.db
  byUrl = db.get 'byUrl'
  byUrl.findOne {url: url, type: type, data: data}, (error, result) ->
    if error
      res.status(500).send 'newURLErrorSave'
      return
    if result
      res.status(500).send 'newURLErrorDuplicate'
      return
    byUrl.remove {_id: _id}, (error, removed) ->
      if error
        res.status(500).send 'newURLErrorSave'
        return
    urlEntry =
      url: url
      type: type
      data: data
      durations: []
    byUrl.insert urlEntry, (error, insertedUrlObject) ->
      if error
        res.status(500).send 'newURLErrorSave'
        return
      res.send insertedUrlObject['_id']

exports.deleteUrl = (req, res) ->
  db = req.db
  byUrl = db.get 'byUrl'
  byUrl.remove req.body, (error, removed) ->
    if error
      res.sendStatus 500
    res.sendStatus 200