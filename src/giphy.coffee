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
#   hubot giphy something interesting - <requests an image relating to "something interesting">
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

DEBUG = process.env.DEBUG
NODE_ENV = process.env.NODE_ENV

api = require('giphy-api')({
  https: (process.env.HUBOT_GIPHY_HTTPS is 'true') or false
  timeout: Number(process.env.HUBOT_GIPHY_TIMEOUT) or null
  apiKey: process.env.HUBOT_GIPHY_API_KEY
})

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

  @defaultEndpoint = process.env.HUBOT_GIPHY_DEFAULT_ENDPOINT or Giphy.SearchEndpointName

  constructor: (api) ->
    @api = api

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
    @log "match:", input
    Giphy.regex.exec input or ''

  getEndpoint: (state) ->
    @log "getEndpoint:", state
    match = @match state.input

    if match
      state.endpoint = match[1] or Giphy.defaultEndpoint
      state.args = match[2]
    else
      state.endpoint = state.args = ''

  getNextOption: (state) ->
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
    @log "getOptions:", state
    state.options = {}
    while @getNextOption state
      null

  getSearchUri: (state) ->
    @log "getSearchUri:", state
    if state.args and state.args.length > 0
      state.options.q = state.args
      @api.search state.options, (err, res) =>
        if err
          @error state.msg, err
        else
          @sendResponse state, res
    else
      @getRandomUri state

  getIdUri: (state) ->
  getTranslateUri: (state) ->
  getRandomUri: (state) ->
  getTrendingUri: (state) ->
  getHelp: (state) ->

  getUri: (state) ->
    @log "getUri:", state
    switch state.endpoint
      when Giphy.SearchEndpointName then @getSearchUri state
      when Giphy.IdEndpointName then @getIdUri state
      when Giphy.TranslateEndpointName then @getTranslateUri state
      when Giphy.RandomEndpointName then @getRandomUri state
      when Giphy.TrendingEndpointName then @getTrendingUri state
      when Giphy.HelpName then @getHelp state
      else @error state.msg, "Unrecognized Endpoint: #{state.endpoint}"

  sendResponse: (state, res) ->
    @log "sendResponse:", state
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

giphy = new Giphy api

module.exports = (robot) ->
  robot.respond /^giphy\s*(.*)\s*$/, (msg) ->
    giphy.respond msg

  # this allows testing to instrument the giphy instance
  ### istanbul ignore next ###
  if NODE_ENV == 'development'
    giphy
