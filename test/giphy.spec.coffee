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
    @robot = {
      respond: sinon.spy()
    }

    @msg = {
      send: sinon.spy()
    }

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
    it 'has a valid api', ->
      should.exist @giphy.api

    describe '.error', ->
      it 'sends the reason if msg and reason exist', ->
        @giphy.error @msg, 'test'
        @msg.send.should.have.been.calledWith 'test'

      it 'ignores a null reason', ->
        @giphy.error @msg
        @giphy.error @msg, null
        @msg.send.should.not.have.been.called

      it 'ignores a null msg', ->
        @giphy.error null, 'test'
        # we just expect to get to this point and not fail for a null msg

    describe '.createState', ->
      it 'returns a valid state instance', ->
        @msg.match = [ null, 'test' ]
        state = @giphy.createState @msg
        should.exist state
        state.msg.should.eql @msg
        state.input.should.eql 'test'
        should.equal state.endpoint, undefined
        should.equal state.argText, undefined
        should.equal state.args, undefined
        should.equal state.uri, undefined

      it 'ignores a null msg', ->
        state = @giphy.createState()
        should.not.exist state
        state = @giphy.createState null
        should.not.exist state

    describe '.match', ->
      it 'matches empty input', ->
        match = @giphy.match ''
        should.exist match
        should.equal match[1], undefined
        match[2].should.eql ''

      it 'matches null input', ->
        match = @giphy.match null
        should.exist match
        should.equal match[1], undefined
        match[2].should.eql ''

      it 'matches undefined input', ->
        match = @giphy.match()
        should.exist match
        should.equal match[1], undefined
        match[2].should.eql ''

      it 'matches search', ->
        match = @giphy.match 'search'
        should.exist match
        match[1].should.eql 'search'
        match[2].should.eql ''

      it 'matches id', ->
        match = @giphy.match 'id'
        should.exist match
        match[1].should.eql 'id'
        match[2].should.eql ''

      it 'matches translate', ->
        match = @giphy.match 'translate'
        should.exist match
        match[1].should.eql 'translate'
        match[2].should.eql ''

      it 'matches random', ->
        match = @giphy.match 'random'
        should.exist match
        match[1].should.eql 'random'
        match[2].should.eql ''

      it 'matches trending', ->
        match = @giphy.match 'trending'
        should.exist match
        match[1].should.eql 'trending'
        match[2].should.eql ''

      it 'matches help', ->
        match = @giphy.match 'help'
        should.exist match
        match[1].should.eql 'help'
        match[2].should.eql ''

      it 'matches a single arg', ->
        match = @giphy.match 'help testing'
        should.exist match
        match[1].should.eql 'help'
        match[2].should.eql 'testing'

      it 'matches multiple args', ->
        match = @giphy.match 'help testing1 testing2'
        should.exist match
        match[1].should.eql 'help'
        match[2].should.eql 'testing1 testing2'

    describe '.parseEndpoint', ->
      it 'parses empty input', ->
        @msg.match = [ null, '' ]
        state = @giphy.createState @msg
        result = @giphy.parseEndpoint state
        result.should.be.true
        state.endpoint.should.eql 'search'
        state.argText.should.eql ''

      it 'parses an endpoint without args', ->
        @msg.match = [ null, 'search' ]
        state = @giphy.createState @msg
        result = @giphy.parseEndpoint state
        result.should.be.true
        state.endpoint.should.eql 'search'
        state.argText.should.eql ''

      it 'parses an endpoint with a single arg', ->
        @msg.match = [ null, 'search testing' ]
        state = @giphy.createState @msg
        result = @giphy.parseEndpoint state
        result.should.be.true
        state.endpoint.should.eql 'search'
        state.argText.should.eql 'testing'

      it 'parses an endpoint with multiple args', ->
        @msg.match = [ null, 'search for stuff' ]
        state = @giphy.createState @msg
        result = @giphy.parseEndpoint state
        result.should.be.true
        state.endpoint.should.eql 'search'
        state.argText.should.eql 'for stuff'

    describe '.parseArgs', ->
    describe '.respond', ->
