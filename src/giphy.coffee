# Description
#   hubot interface for giphy-api (https://github.com/austinkelleher/giphy-api)
#
# Configuration:
#   HUBOT_GIPHY_API_KEY
#   HUBOT_GIPHY_HTTPS
#   HUBOT_GIPHY_TIMEOUT
#   HUBOT_GIPHY_DEFAULT_LIMIT
#   HUBOT_GIPHY_DEFAULT_RATING
#   HUBOT_GIPHY_INLINE_IMAGES
#   HUBOT_GIPHY_DEFAULT_ENDPOINT  default: search
#
# Commands:
#   hubot giphy [endpoint] [options...] something interesting - <requests an image relating to "something interesting">
#   hubot giphy help - show giphy plugin usage
#
# Notes:
#   HUBOT_GIPHY_API_KEY: get your api key @ http://api.giphy.com/
#   HUBOT_GIPHY_HTTPS: use https mode (boolean)
#   HUBOT_GIPHY_TIMEOUT: API request timeout (number, in seconds)
#   HUBOT_GIPHY_DEFAULT_LIMIT: max results returned for collection based requests (number)
#   HUBOT_GIPHY_RATING: result rating limitation (string, one of y, g, pg, pg-13, or r)
#   HUBOT_GIPHY_INLINE_IMAGES: images are inlined. i.e. ![giphy](uri) (boolean)
#   HUBOT_GIPHY_DEFAULT_ENDPOINT: endpoint used when none is specified (string)
#
# Author:
#   Pat Sissons[patricksissons@gmail.com]

giphyApi = require 'giphy-api'

DEBUG = process.env.DEBUG

# utility method for extending an object definition
extend = (object, properties) ->
  for key, val of properties
    object[key] = val if val
  object

# utility method for merging two objects
merge = (options, overrides) ->
  extend (extend {}, options), overrides

class Giphy
  @SearchEndpointName = 'search'
  @IdEndpointName = 'id'
  @TranslateEndpointName = 'translate'
  @RandomEndpointName = 'random'
  @TrendingEndpointName = 'trending'
  @HelpName = 'help'

  @endpoints = [
    Giphy.SearchEndpointName,
    Giphy.IdEndpointName,
    Giphy.TranslateEndpointName,
    Giphy.RandomEndpointName,
    Giphy.TrendingEndpointName,
  ]

  @regex = new RegExp "^\\s*(#{Giphy.endpoints.join('|')}|#{Giphy.HelpName})?\\s*(.*?)$", 'i'

  constructor: (api) ->
    throw new Error 'Giphy API is required' if not api

    @api = api
    @defaultEndpoint = process.env.HUBOT_GIPHY_DEFAULT_ENDPOINT or Giphy.SearchEndpointName

  ### istanbul ignore next ###
  log: ->
    console.log.apply this, arguments if DEBUG

  error: (msg, reason) ->
    if msg and reason
      @sendMessage msg, reason

  createState: (msg) ->
    if msg
      state = {
        msg: msg
        input: msg.match[1]
        endpoint: undefined
        args: undefined
        options: undefined
        uri: undefined
      }

  match: (input) ->
    Giphy.regex.exec input or ''

  getEndpoint: (state) ->
    @log 'getEndpoint:', state
    match = @match state.input

    if match
      state.endpoint = match[1] or @defaultEndpoint
      state.args = match[2]
    else
      state.endpoint = state.args = ''

  getNextOption: (state) ->
    @log 'getNextOption:', state
    regex = /\/(\w+):(\w+)/
    optionFound = false
    state.args = state.args.replace regex, (match, key, val) ->
      if !isNaN(Number(val))
        val = Number(val)
      state.options[key] = val
      optionFound = true
      ''
    state.args = state.args.trim()
    optionFound

  # rating, limit, offset, api
  getOptions: (state) ->
    @log 'getOptions:', state
    state.options = {}
    while @getNextOption state
      null

  getRandomResultData: (data, callback) ->
    if data and callback and data.length > 0
      callback(if data.length == 1 then data[0] else data[Math.floor(Math.random() * data.length)])

  getUriFromResultData: (data) ->
    if data and data.images and data.images.original
      data.images.original.url

  getSearchUri: (state) ->
    @log 'getSearchUri:', state
    if state.args and state.args.length > 0
      options = merge {
        q: state.args,
        limit: process.env.HUBOT_GIPHY_DEFAULT_LIMIT
        rating: process.env.HUBOT_GIPHY_DEFAULT_RATING
      }, state.options
      @api.search options, (err, res) =>
        @handleResponse state, err, => @getRandomResultData(res.data, @getUriFromResultData)
    else
      @getRandomUri state

  getIdUri: (state) ->
    @log 'getIdUri:', state
    if state.args and state.args.length > 0
      ids = state.args
        .split(' ')
        .filter((x) -> x.length > 0)
        .map((x) -> x.trim())
      @api.id ids, (err, res) =>
        @handleResponse state, err, => @getRandomResultData(res.data, @getUriFromResultData)
    else
      @error state.msg, 'No Id Provided'

  getTranslateUri: (state) ->
    @log 'getTranslateUri:', state
    options = merge {
      s: state.args,
      rating: process.env.HUBOT_GIPHY_DEFAULT_RATING
    }, state.options
    @api.translate options, (err, res) =>
      @handleResponse state, err, => @getUriFromResultData res.data

  getRandomUri: (state) ->
    @log 'getRandomUri:', state
    options = merge {
      tag: state.args,
      rating: process.env.HUBOT_GIPHY_DEFAULT_RATING
    }, state.options
    @api.random options, (err, res) =>
      @handleResponse state, err, => @getUriFromResultData res.data

  getTrendingUri: (state) ->
    @log 'getTrendingUri:', state
    options = merge {
      limit: process.env.HUBOT_GIPHY_DEFAULT_LIMIT
      rating: process.env.HUBOT_GIPHY_DEFAULT_RATING
    }, state.options
    @api.trending options, (err, res) =>
      @handleResponse state, err, => @getRandomResultData(res.data, @getUriFromResultData)

  getHelp: (state) ->
    @log 'getHelp:', state

  getUri: (state) ->
    @log 'getUri:', state
    switch state.endpoint
      when Giphy.SearchEndpointName then @getSearchUri state
      when Giphy.IdEndpointName then @getIdUri state
      when Giphy.TranslateEndpointName then @getTranslateUri state
      when Giphy.RandomEndpointName then @getRandomUri state
      when Giphy.TrendingEndpointName then @getTrendingUri state
      when Giphy.HelpName then @getHelp state
      else @error state.msg, "Unrecognized Endpoint: #{state.endpoint}"

  handleResponse: (state, err, uriCreator) ->
    @log 'handleResponse:', state
    if err
      @error state.msg, err
    else
      state.uri = uriCreator.call this
      @sendResponse state

  sendResponse: (state) ->
    @log 'sendResponse:', state
    if state.uri
      @sendMessage state.msg, state.uri
    else
      @error state.msg, 'No Results Found'

  sendMessage: (msg, message) ->
    if msg and message
      msg.send message

  respond: (msg) ->
    if msg and msg.match and msg.match[1]
      state = @createState msg

      @getEndpoint state
      @getOptions state

      @getUri state
    else
      @error msg, "I Didn't Understand Your Request"

module.exports = (robot) ->
  api = giphyApi({
    https: (process.env.HUBOT_GIPHY_HTTPS is 'true') or false
    timeout: Number(process.env.HUBOT_GIPHY_TIMEOUT) or null
    apiKey: process.env.HUBOT_GIPHY_API_KEY
  })

  giphy = new Giphy api

  robot.respond /^giphy\s*(.*?)\s*$/, (msg) ->
    giphy.respond msg

  # this allows testing to instrument the giphy instance
  ### istanbul ignore next ###
  if global and global.IS_TESTING
    giphy

# this allows testing to instrument the giphy class
### istanbul ignore next ###
if global and global.IS_TESTING
  module.exports.Giphy = Giphy
  module.exports.extend = extend
  module.exports.merge = merge
