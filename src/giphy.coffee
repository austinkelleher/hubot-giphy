# Description
#   hubot interface for giphy-api (search random gifs from the internet)
#
# Configuration:
#   HUBOT_GIPHY_API_KEY         default: dc6zaTOxFJmzC, the public beta api key)
#   HUBOT_GIPHY_RATING
#   HUBOT_GIPHY_SCHEME          default: http
#   HUBOT_GIPHY_INLINE_IMAGES
#
# Commands:
#   hubot hello - <what the respond trigger does>
#   orly - <what the hear trigger does>
#
# Notes:
#   HUBOT_GIPHY_API_KEY: get your api key @ http://api.giphy.com/
#   HUBOT_GIPHY_RATING: available choices are y, g, pg, pg-13, or r
#   HUBOT_GIPHY_SCHEME: choose https to rewrite all uri schemes to https
#   HUBOT_GIPHY_INLINE_IMAGES: when set, images are inlined. i.e. ![giphy](uri)
#
# Author:
#   Pat Sissons[patricksissons@gmail.com]

api = require 'giphy-api'

class Giphy

  respond: (msg) ->
    if msg and msg.match
      # TODO: implement
      msg.send msg.match[1]

giphy = new Giphy()

module.exports = (robot) ->
  robot.respond /giphy\s*(.*)$/, (msg) ->
    giphy.respond msg
