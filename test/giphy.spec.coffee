chai = require 'chai'
sinon = require 'sinon'
giphy = require '../src/giphy'

should = chai.should()
chai.use require 'sinon-chai'

exampleImageUri = 'http://giphy.com/example.gif'

test = (robot, msg, spy, input) ->
  [callback, other, ...] = spy
    .getCalls()
    .filter((x) -> msg.match = x.args[0].exec input)
    .map((x) -> x.args[1])

  if other
    should.not.exist other, "Multiple Matches for #{input}"

  if callback
    callback.call robot, msg

describe 'giphy', ->
  beforeEach ->
    @robot =
      respond: sinon.spy()
    @msg =
      send: sinon.spy()
    @giphy = giphy @robot

  it 'has a valid class instance', ->
    should.exist @giphy

  it 'has an active respond trigger', ->
    @robot.respond.should.have.been.called.once

  describe 'hubot script', ->
    it 'responds to giphy', ->
      test @robot, @msg, @robot.respond, 'giphy'
      @msg.send.should.have.been.called.once

    it 'responds to giphy test', ->
      test @robot, @msg, @robot.respond, 'giphy test'
      @msg.send.should.have.been.called.once

  describe 'class', ->
