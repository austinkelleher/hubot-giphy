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
    sinon.stub @giphy.api, '_request', (options, callback) ->
      callback null, exampleImageUri

  afterEach ->
    @giphy.api._request.restore()

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

    describe '.getEndpoint', ->
      it 'handles empty input', ->
        @msg.match = [ null, '' ]
        state = @giphy.createState @msg
        @giphy.getEndpoint state
        should.exist state.endpoint
        state.endpoint.should.eql @giphy.constructor.defaultEndpoint
        state.args.should.eql ''

      it 'handles an endpoint without args', ->
        @msg.match = [ null, 'search' ]
        state = @giphy.createState @msg
        @giphy.getEndpoint state
        should.exist state.endpoint
        state.endpoint.should.eql 'search'
        state.args.should.eql ''

      it 'handles an endpoint with a single arg', ->
        @msg.match = [ null, 'search testing' ]
        state = @giphy.createState @msg
        @giphy.getEndpoint state
        should.exist state.endpoint
        state.endpoint.should.eql 'search'
        state.args.should.eql 'testing'

      it 'handles an endpoint with multiple args', ->
        @msg.match = [ null, 'search for stuff' ]
        state = @giphy.createState @msg
        @giphy.getEndpoint state
        should.exist state.endpoint
        state.endpoint.should.eql 'search'
        state.args.should.eql 'for stuff'

    describe '.getNextOption', ->
      it 'handles empty args', ->
        state = { args: '', options: {} }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.false
        state.args.should.eql ''
        state.options.should.eql {}

      it 'handles a single non-switch word', ->
        state = { args: 'test1', options: {} }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.false
        state.args.should.eql 'test1'
        state.options.should.eql {}

      it 'handles multiple non-switch words', ->
        state = { args: 'test1 test2', options: {} }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.false
        state.args.should.eql 'test1 test2'
        state.options.should.eql {}

      it 'handles a single numerical switch', ->
        state = { args: '/test1:1', options: {} }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.true
        state.args.should.eql ''
        state.options.should.eql { test1: 1 }

      it 'handles a single non-numerical switch', ->
        state = { args: '/test1:test1', options: {} }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.true
        state.args.should.eql ''
        state.options.should.eql { test1: 'test1' }

      it 'handles multiple switches', ->
        state = { args: '/test1:1 /test2:2', options: {} }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.true
        state.args.should.eql '/test2:2'
        state.options.should.eql { test1: 1 }

      it 'handles switches before words', ->
        state = { args: '/test1:1 test2', options: {} }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.true
        state.args.should.eql 'test2'
        state.options.should.eql { test1: 1 }

      it 'handles switches after words', ->
        state = { args: 'test1 /test2:2', options: {} }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.true
        state.args.should.eql 'test1'
        state.options.should.eql { test2: 2 }

    describe '.getOptions', ->
      it 'handles empty args', ->
        state = { args: '' }
        @giphy.getOptions state
        state.args.should.eql ''
        should.exist state.options
        state.options.should.eql {}

      it 'handles non-empty args', ->
        state = { args: '/test1:1 test 2 /test3:test3' }
        @giphy.getOptions state
        state.args.should.eql 'test 2'
        should.exist state.options
        state.options.should.eql { test1: 1, test3: 'test3' }

    describe '.respond', ->
