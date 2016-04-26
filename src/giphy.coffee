# Description
#   hubot interface for giphy-api (https://github.com/austinkelleher/giphy-api)
#
# Configuration:
#   HUBOT_GIPHY_API_KEY           default: dc6zaTOxFJmzC, the public beta api key)
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

api = require('giphy-api')({
  https: (process.env.HUBOT_GIPHY_HTTPS is 'true') or false
  timeout: Number(process.env.HUBOT_GIPHY_TIMEOUT) or null
  apiKey: process.env.HUBOT_GIPHY_API_KEY or 'dc6zaTOxFJmzC'
})

class Giphy

  @endpoints = [
    'search',
    'id',
    'translate',
    'random',
    'trending',
    'help',
  ]

  @regex = new RegExp "^\\s*(#{Giphy.endpoints.join('|')})?\\s*(.*?)$", 'i'

  @defaultEndpoint = process.env.HUBOT_GIPHY_DEFAULT_ENDPOINT or 'search'

  constructor: (api) ->
    @api = api

  error: (msg, reason) ->
    if msg and reason
      msg.send reason

  createState: (msg) ->
    if msg
      state = {
        msg: msg
        input: msg.match[1]
        endpoint: undefined
        argText: undefined
        args: undefined
        uri: undefined
      }

  match: (input) ->
    Giphy.regex.exec input or ''

  parseEndpoint: (state) ->
    match = @match state.input

    # match should never be null
    ### istanbul ignore else ###
    if match
      state.endpoint = match[1] or Giphy.defaultEndpoint
      state.argText = match[2]
      true
    else
      false

  parseArgs: (state) ->
    if state.argText
      state.args = []
      true
    else
      false

  respond: (msg) ->
    if msg and msg.match and msg.match[1]
      state = @createState msg

      @parseEndpoint state and @parseArgs state

      if state.uri
        state.msg.send state.uri
      else
        @error state.msg, 'No Results Found'
    else
      @error msg, "I Didn't Understand Your Request"

giphy = new Giphy api

module.exports = (robot) ->
  robot.respond /giphy\s*(.*)$/, (msg) ->
    giphy.respond msg

  # this allows testing to instrument the giphy instance
  giphy
