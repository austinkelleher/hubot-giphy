chai = require 'chai'
sinon = require 'sinon'
giphy = require '../src/giphy'

should = chai.should()
chai.use require 'sinon-chai'

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
  @exampleImageUri = 'http://giphy.com/example.gif'

  beforeEach ->
    @robot =
      respond: sinon.spy()
      hear: sinon.spy()
    @msg = 
      reply: sinon.spy()
      send: sinon.spy()
    @giphy = giphy(@robot)

  it 'registers on respond', ->
    @robot.respond.should.have.been.called.once
  
  it 'responds to giphy', ->
    @robot.respond.should.have.been.called.once
    test @robot, @msg, @robot.respond, 'giphy'
    @msg.send.should.have.been.called.once
    @msg.send.should.have.been.calledWith ''
  
  it 'responds to giphy test', ->
    @robot.respond.should.have.been.called.once
    test @robot, @msg, @robot.respond, 'giphy test'
    @msg.send.should.have.been.called.once
    @msg.send.should.have.been.calledWith 'test'