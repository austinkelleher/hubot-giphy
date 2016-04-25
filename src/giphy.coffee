# Description
#   hubot interface for giphy-api
#
# Configuration:
#   LIST_OF_ENV_VARS_TO_SET
#
# Commands:
#   hubot hello - <what the respond trigger does>
#   orly - <what the hear trigger does>
#
# Notes:
#   <optional notes required for the script>
#
# Author:
#   Pat Sissons[@<org>]

api = require 'giphy-api'

class Giphy

module.exports = (robot) ->
  robot.respond /giphy\s*(.*)$/, (msg) ->
    msg.send msg.match[1]
