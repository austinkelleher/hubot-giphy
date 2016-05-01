chai = require 'chai'
sinon = require 'sinon'
giphy = require '../src/giphy'

should = chai.should()
chai.use require 'sinon-chai'

# this allows us to instrument the internal Giphy instance
global.EXPOSE_INSTANCE = true

sampleUri = 'http://giphy.com/example.gif'

sampleCollectionResult = {
  data: [
    {
      images: {
        original: {
          url: sampleUri
        }
      }
    },
  ]
}

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
    sinon.stub @giphy.api, '_request', (options, callback) -> callback null, null

  afterEach ->
    @giphy.api._request.restore()

  describe 'test instrumentation', ->
    it 'has a valid class instance', ->
      should.exist @giphy

  describe 'hubot script', ->
    beforeEach ->
      sinon.stub @giphy, 'respond'

    afterEach ->
      @giphy.respond.restore()

    it 'has an active respond trigger', ->
      @robot.respond.should.have.been.called.once

    it 'responds to giphy command without args', ->
      testHubot @robot.respond, 'giphy', 'testing'
      @giphy.respond.should.have.been.calledWith 'testing'

    it 'responds to giphy command with args', ->
      testHubot @robot.respond, 'giphy test', 'testing'
      @giphy.respond.should.have.been.calledWith 'testing'

    it 'does not respond to non-giphy command without args', ->
      testHubot @robot.respond, 'notgiphy'
      @giphy.respond.should.not.have.been.called

    it 'does not respond to non-giphy command with args', ->
      testHubot @robot.respond, 'notgiphy test'
      @giphy.respond.should.not.have.been.called

    it 'matches giphy command args', ->
      responder = @robot.respond.getCalls()[0]
      match = responder.args[0].exec 'giphy testing'
      should.exist match
      match.should.have.lengthOf 2
      match[0].should.eql 'giphy testing'
      match[1].should.eql 'testing'

    it 'matches giphy command args and trims spaces', ->
      responder = @robot.respond.getCalls()[0]
      match = responder.args[0].exec 'giphy     testing     '
      should.exist match
      match.should.have.lengthOf 2
      match[0].should.eql 'giphy     testing     '
      match[1].should.eql 'testing'

  describe 'class', ->
    it 'has a valid api', ->
      should.exist @giphy.api

    it 'has a valid default endpoint', ->
      should.exist @giphy.constructor.defaultEndpoint
      @giphy.constructor.defaultEndpoint.should.have.length.above 0

    describe '.error', ->
      beforeEach ->
        sinon.stub @giphy, 'sendMessage'

      afterEach ->
        @giphy.sendMessage.restore()

      it 'sends the reason if msg and reason exist', ->
        @giphy.error @msg, 'test'
        @giphy.sendMessage.should.have.been.called.once
        @giphy.sendMessage.should.have.been.calledWith @msg, 'test'

      it 'ignores a null msg or reason', ->
        @giphy.error()
        @giphy.error @msg
        @giphy.error @msg, null
        @giphy.error null, 'test'
        @giphy.sendMessage.should.not.have.been.called

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
        sinon.stub @giphy, 'match', -> null
        @giphy.getEndpoint state
        @giphy.match.restore()
        state.endpoint.should.eql ''
        state.args.should.eql ''

      it 'handles endpoint and args match', ->
        state = {}
        sinon.stub @giphy, 'match', -> [ null, 'test1', 'test2' ]
        @giphy.getEndpoint state
        @giphy.match.restore()
        state.endpoint.should.eql 'test1'
        state.args.should.eql 'test2'

      it 'handles only args match', ->
        state = {}
        sinon.stub @giphy, 'match', -> [ null, null, 'test2' ]
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
        sinon.stub @giphy, 'getNextOption', (s) -> false
        @giphy.getOptions state
        @giphy.getNextOption.should.be.called.once
        @giphy.getNextOption.should.be.calledWith state
        @giphy.getNextOption.restore()
        should.exist state.options
        state.options.should.eql {}

      it 'handles true then false result from getNextOption', ->
        state = { args: 'testing' }
        calls = 2
        sinon.stub @giphy, 'getNextOption', (state) -> (calls = calls - 1) > 0
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

    describe '.getRandomResult', ->
      it 'calls the callback with a single value collection', ->
        callback = sinon.stub().returns 'result'
        result = @giphy.getRandomResult [ 'testing' ], callback
        callback.should.have.been.called.once
        callback.should.have.been.calledWith 'testing'
        should.exist result
        result.should.be.eql 'result'

      it 'calls the callback with a multiple value collection', ->
        callback = sinon.stub().returns 'result'
        result = @giphy.getRandomResult [ 'testing1', 'testing2' ], callback
        callback.should.have.been.called.once
        callback.should.have.been.calledWith sinon.match('testing1') or sinon.match('testing2')
        should.exist result
        result.should.be.eql 'result'

      it 'handles null or empty data', ->
        callback = sinon.spy()
        @giphy.getRandomResult undefined, callback
        @giphy.getRandomResult null, callback
        @giphy.getRandomResult [], callback
        callback.should.not.have.been.called

    describe '.getSearchUri', ->
      it 'searches using args', ->
        state = { args: 'testing' }
        sinon.stub @giphy.api, 'search'
        @giphy.getSearchUri state
        @giphy.api.search.should.have.been.called.once
        @giphy.api.search.should.have.been.calledWith { q: 'testing' }, sinon.match.func
        @giphy.api.search.restore()

      it 'searches using args and options', ->
        state = { args: 'testing', options: { limit: 10 } }
        sinon.stub @giphy.api, 'search'
        @giphy.getSearchUri state
        @giphy.api.search.should.have.been.called.once
        @giphy.api.search.should.have.been.calledWith { q: 'testing', limit: 10 }, sinon.match.func
        @giphy.api.search.restore()

      it 'handles the callback response', ->
        state = { msg: 'msg', args: 'testing' }
        sinon.stub @giphy.api, 'search', (options, callback) -> callback null, sampleCollectionResult
        sinon.stub @giphy, 'sendResponse'
        sinon.spy @giphy, 'getRandomResult'
        @giphy.getSearchUri state
        @giphy.sendResponse.should.have.been.called.once
        @giphy.sendResponse.should.have.been.calledWith state
        @giphy.getRandomResult.should.have.been.called.once
        @giphy.getRandomResult.should.have.been.calledWith sampleCollectionResult.data, sinon.match.func
        @giphy.api.search.restore()
        @giphy.sendResponse.restore()
        @giphy.getRandomResult.restore()
        should.exist state.uri
        state.uri.should.eql sampleUri

      it 'calls getRandomUri for empty args', ->
        sinon.spy @giphy, 'getRandomUri'
        @giphy.getSearchUri {}
        @giphy.getSearchUri { args: null }
        @giphy.getSearchUri { args: '' }
        @giphy.getRandomUri.should.have.callCount 3
        @giphy.getRandomUri.restore()

      it 'handles errors in the callback', ->
        state = { msg: 'msg', args: 'testing' }
        sinon.stub @giphy.api, 'search', (options, callback) -> callback 'error'
        sinon.stub @giphy, 'error'
        @giphy.getSearchUri state
        @giphy.error.should.have.been.called.once
        @giphy.error.should.have.been.calledWith 'msg', 'error'
        @giphy.api.search.restore()
        @giphy.error.restore()

    describe '.getIdUri', ->
    describe '.getTranslateUri', ->
    describe '.getRandomUri', ->
    describe '.getTrendingUri', ->
    describe '.getHelp', ->
    describe '.getUri', ->
      it 'handles a null endpoint', ->
        sinon.stub @giphy, 'error'
        @giphy.getUri {}
        @giphy.error.should.have.been.called.once
        @giphy.error.restore()

      it 'handles a search endpoint', ->
        state = { endpoint: @giphy.constructor.SearchEndpointName }
        sinon.stub @giphy, 'getSearchUri'
        @giphy.getUri state
        @giphy.getSearchUri.should.have.been.called.once
        @giphy.getSearchUri.should.have.been.calledWith state
        @giphy.getSearchUri.restore()

      it 'handles an id endpoint', ->
        state = { endpoint: @giphy.constructor.IdEndpointName }
        sinon.stub @giphy, 'getIdUri'
        @giphy.getUri state
        @giphy.getIdUri.should.have.been.called.once
        @giphy.getIdUri.should.have.been.calledWith state
        @giphy.getIdUri.restore()

      it 'handles a translate endpoint', ->
        state = { endpoint: @giphy.constructor.TranslateEndpointName }
        sinon.stub @giphy, 'getTranslateUri'
        @giphy.getUri state
        @giphy.getTranslateUri.should.have.been.called.once
        @giphy.getTranslateUri.should.have.been.calledWith state
        @giphy.getTranslateUri.restore()

      it 'handles a random endpoint', ->
        state = { endpoint: @giphy.constructor.RandomEndpointName }
        sinon.stub @giphy, 'getRandomUri'
        @giphy.getUri state
        @giphy.getRandomUri.should.have.been.called.once
        @giphy.getRandomUri.should.have.been.calledWith state
        @giphy.getRandomUri.restore()

      it 'handles a trending endpoint', ->
        state = { endpoint: @giphy.constructor.TrendingEndpointName }
        sinon.stub @giphy, 'getTrendingUri'
        @giphy.getUri state
        @giphy.getTrendingUri.should.have.been.called.once
        @giphy.getTrendingUri.should.have.been.calledWith state
        @giphy.getTrendingUri.restore()

      it 'handles help', ->
        state = { endpoint: @giphy.constructor.HelpName }
        sinon.stub @giphy, 'getHelp'
        @giphy.getUri state
        @giphy.getHelp.should.have.been.called.once
        @giphy.getHelp.should.have.been.calledWith state
        @giphy.getHelp.restore()

    describe '.sendResponse', ->
      beforeEach ->
        sinon.stub @giphy, 'sendMessage'
        sinon.stub @giphy, 'error'

      afterEach ->
        @giphy.sendMessage.restore()
        @giphy.error.restore()

      it 'handles state with a uri', ->
        @giphy.sendResponse { msg: 'msg', uri: 'uri' }
        @giphy.sendMessage.should.be.called.once
        @giphy.sendMessage.should.be.calledWith 'msg', 'uri'

      it 'handles state without a uri', ->
        @giphy.sendResponse {}
        @giphy.error.should.be.called.once

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
      beforeEach ->
        sinon.stub @giphy, 'getEndpoint'
        sinon.stub @giphy, 'getOptions'
        sinon.stub @giphy, 'getUri'
        sinon.stub @giphy, 'error'

      afterEach ->
        @giphy.getEndpoint.restore()
        @giphy.getOptions.restore()
        @giphy.getUri.restore()
        @giphy.error.restore()

      it 'handles a valid msg', ->
        msg = { match: [ null, 'testing' ] }
        state = 'state'
        sinon.stub @giphy, 'createState', -> state
        @giphy.respond msg
        @giphy.createState.should.have.been.calledWith msg
        @giphy.getEndpoint.should.have.been.calledWith state
        @giphy.getOptions.should.have.been.calledWith state
        @giphy.getUri.should.have.been.calledWith state
        @giphy.createState.restore()

      it 'handles null msg', ->
        @giphy.respond()
        @giphy.respond null
        @giphy.getUri.should.not.have.been.called
        @giphy.error.should.have.been.called.twice

      it 'handles null giphy command args', ->
        @giphy.respond {}
        @giphy.respond { match: null }
        @giphy.respond { match: [] }
        @giphy.respond { match: [ null ] }
        @giphy.respond { match: [ null, null ] }
        @giphy.getUri.should.not.have.been.called
        @giphy.error.should.have.callCount 5
