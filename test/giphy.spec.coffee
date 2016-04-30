chai = require 'chai'
sinon = require 'sinon'
giphy = require '../src/giphy'

should = chai.should()
chai.use require 'sinon-chai'

exampleImageUri = 'http://giphy.com/example.gif'

testHubot = (spy, input, args) ->
  [callback, other, ...] = spy
    .getCalls()
    .filter((x) -> x.args[0].test input)
    .map((x) -> x.args[1])

  should.not.exist other, "Multiple Matches for #{input}"

  if callback
    callback.call null, args

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

  describe 'test instrumentation', ->
    it 'has a valid class instance', ->
      should.exist @giphy

  describe 'hubot script', ->
    it 'has an active respond trigger', ->
      @robot.respond.should.have.been.called.once

    it 'responds to giphy command without args', ->
      sinon.stub @giphy, 'respond'
      testHubot @robot.respond, 'giphy', 'testing'
      @giphy.respond.should.have.been.calledWith 'testing'
      @giphy.respond.restore()

    it 'responds to giphy command with args', ->
      sinon.stub @giphy, 'respond'
      testHubot @robot.respond, 'giphy test', 'testing'
      @giphy.respond.should.have.been.calledWith 'testing'
      @giphy.respond.restore()

    it 'does not respond to non-giphy command without args', ->
      sinon.stub @giphy, 'respond'
      testHubot @robot.respond, 'notgiphy'
      @giphy.respond.should.not.have.been.called
      @giphy.respond.restore()

    it 'does not respond to non-giphy command with args', ->
      sinon.stub @giphy, 'respond'
      testHubot @robot.respond, 'notgiphy test'
      @giphy.respond.should.not.have.been.called
      @giphy.respond.restore()

  describe 'class', ->
    it 'has a valid api', ->
      should.exist @giphy.api

    it 'has a valid default endpoint', ->
      should.exist @giphy.constructor.defaultEndpoint
      @giphy.constructor.defaultEndpoint.should.have.length.above 0

    describe '.error', ->
      it 'sends the reason if msg and reason exist', ->
        sinon.stub @giphy, 'sendMessage'
        @giphy.error @msg, 'test'
        @giphy.sendMessage.should.have.been.called.once
        @giphy.sendMessage.should.have.been.calledWith @msg, 'test'
        @giphy.sendMessage.restore()

      it 'ignores a null msg or reason', ->
        sinon.stub @giphy, 'sendMessage'
        @giphy.error()
        @giphy.error @msg
        @giphy.error @msg, null
        @giphy.error null, 'test'
        @giphy.sendMessage.should.not.have.been.called
        @giphy.sendMessage.restore()

    describe '.createState', ->
      it 'returns a valid state instance', ->
        msg = { match: [ null, 'test' ] }
        state = @giphy.createState msg
        should.exist state
        state.msg.should.eql msg
        state.input.should.eql msg.match[1]
        should.equal state.endpoint, undefined
        should.equal state.args, undefined
        should.equal state.options, undefined
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

      it 'matches only args', ->
        match = @giphy.match 'testing1 testing2'
        should.exist match
        should.equal match[1], undefined
        match[2].should.eql 'testing1 testing2'

    describe '.getEndpoint', ->
      it 'passes state input to match function', ->
        state = { input: 'testing' }
        sinon.stub @giphy, 'match', ->
          null
        @giphy.getEndpoint state
        @giphy.match.should.be.called.once
        @giphy.match.should.be.calledWith state.input
        @giphy.match.restore()

      it 'handles null match result', ->
        state = {}
        sinon.stub @giphy, 'match', ->
          null
        @giphy.getEndpoint state
        @giphy.match.restore()
        state.endpoint.should.eql ''
        state.args.should.eql ''

      it 'handles endpoint and args match', ->
        state = {}
        sinon.stub @giphy, 'match', ->
          [ null, 'test1', 'test2' ]
        @giphy.getEndpoint state
        @giphy.match.restore()
        state.endpoint.should.eql 'test1'
        state.args.should.eql 'test2'

      it 'handles only args match', ->
        state = {}
        sinon.stub @giphy, 'match', ->
          [ null, null, 'test2' ]
        @giphy.getEndpoint state
        @giphy.match.restore()
        state.endpoint.should.eql @giphy.constructor.defaultEndpoint
        state.args.should.eql 'test2'

    describe '.getNextOption', ->
      it 'handles empty args', ->
        state = { args: '', options: {} }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.false
        state.args.should.eql ''
        state.options.should.eql {}

      it 'handles a single non-switch arg', ->
        state = { args: 'test1', options: {} }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.false
        state.args.should.eql 'test1'
        state.options.should.eql {}

      it 'handles multiple non-switch args', ->
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

      it 'handles switches before args', ->
        state = { args: '/test1:1 test2', options: {} }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.true
        state.args.should.eql 'test2'
        state.options.should.eql { test1: 1 }

      it 'handles switches after args', ->
        state = { args: 'test1 /test2:2', options: {} }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.true
        state.args.should.eql 'test1'
        state.options.should.eql { test2: 2 }

      it 'handles mixed switches and args', ->
        state = { args: '/test1:1 test 2 /test3:test3', options: {} }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.true
        state.args.should.eql 'test 2 /test3:test3'
        state.options.should.eql { test1: 1 }

    describe '.getOptions', ->
      it 'handles false result from getNextOption', ->
        state = { args: 'testing' }
        sinon.stub @giphy, 'getNextOption', (s) ->
          false
        @giphy.getOptions state
        @giphy.getNextOption.should.be.called.once
        @giphy.getNextOption.should.be.calledWith state
        @giphy.getNextOption.restore()
        should.exist state.options
        state.options.should.eql {}

      it 'handles true then false result from getNextOption', ->
        state = { args: 'testing' }
        calls = 2
        sinon.stub @giphy, 'getNextOption', (state) ->
          if --calls == 0
            false
          else
            true
        @giphy.getOptions state
        @giphy.getNextOption.should.be.called.twice
        @giphy.getNextOption.should.be.calledWith state
        @giphy.getNextOption.restore()
        should.exist state.options
        state.options.should.eql {}

      it 'parses mixed switches and args', ->
        state = { args: '/test1:1 test 2 /test3:test3' }
        @giphy.getOptions state
        state.args.should.eql 'test 2'
        should.exist state.options
        state.options.should.eql { test1: 1, test3: 'test3' }

    describe '.getSearchUri', ->
    describe '.getIdUri', ->
    describe '.getTranslateUri', ->
    describe '.getRandomUri', ->
    describe '.getTrendingUri', ->
    describe '.getHelp', ->
    describe '.getUri', ->
    describe '.sendResponse', ->
    describe '.sendMessage', ->
      it 'sends a message when msg and message are valid', ->
        @giphy.sendMessage @msg, 'testing'
        @msg.send.should.be.called.once
        @msg.send.should.be.calledWith 'testing'

      it 'ignores calls when msg or message is null', ->
        @giphy.sendMessage()
        @giphy.sendMessage @msg
        @giphy.sendMessage @msg, null
        @giphy.sendMessage undefined, 'testing'
        @giphy.sendMessage null, 'testing'
        @msg.send.should.not.have.been.called

    describe '.respond', ->
