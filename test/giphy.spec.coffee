# this allows us to instrument the giphy internals
global.IS_TESTING = true

chai = require 'chai'
sinon = require 'sinon'
giphyApi = require 'giphy-api'
hubotGiphy = require '../src/giphy'

Giphy = hubotGiphy.Giphy
extend = hubotGiphy.extend
merge = hubotGiphy.merge

should = chai.should()
chai.use require 'sinon-chai'

sampleUri = 'http://giphy.com/example.gif'

sampleData = {
  images: {
    original: {
      url: sampleUri
    }
  }
}

sampleResult = {
  data: sampleData
}

sampleCollectionResult = {
  data: [
    sampleData,
  ]
}

describe 'giphy', ->
  before ->
    # keep a copy of the original environment so we can restore it
    @env = process.env

  beforeEach ->
    # this will hold all of our fakes so we can restore everything with a single call
    @fakes = sinon.collection

    # clone the original environment so we can inject variables
    process.env = extend { }, @env

    # create a new test giphy api
    @api = giphyApi()
    # create a new test giphy instance
    @giphy = new Giphy @api

    # protect against any real XHR attempts
    @fakes.stub @api, '_request', (options, callback) -> callback 'XHR Attempted', null

  afterEach ->
    # restore all fakes
    @fakes.restore()

  after ->
    # restore original environment
    process.env = @env

  describe 'test instrumentation', ->
    it 'has a valid giphy-api module and instance', ->
      should.exist giphyApi
      should.exist @api

    it 'has a valid Giphy class definition and instance', ->
      should.exist Giphy
      should.exist @giphy
      should.exist @giphy.api
      @giphy.api.should.eql @api

    it 'should be able to access the hubot giphy instance', ->
      robot = { respond: @fakes.spy() }
      should.exist hubotGiphy
      giphyPluginInstance = hubotGiphy robot
      should.exist giphyPluginInstance
      should.exist giphyPluginInstance.api

    it 'can simulate environment variable values', ->
      process.env.TESTING = 'testing'
      process.env.TESTING.should.eql 'testing'

    it 'does not persist environment variable changes', ->
      should.not.exist process.env.TESTING

  describe 'hubot script', ->
    giphyPluginInstance = null
    robot = null

    # helper function to confirm hubot responds to the correct input
    testHubot = (spy, input, args) ->
      [callback, other, ...] = spy
        .getCalls()
        .filter((x) -> x.args[0].test input)
        .map((x) -> x.args[1])

      should.not.exist other, "Multiple Matches for #{input}"

      if callback
        callback.call null, args

    beforeEach ->
      robot = { respond: @fakes.spy() }
      giphyPluginInstance = hubotGiphy robot
      @fakes.stub giphyPluginInstance.api, '_request', (options, callback) -> callback 'XHR Attempted', null
      @fakes.stub giphyPluginInstance, 'respond'

    it 'has an active respond trigger', ->
      robot.respond.should.have.been.called.once

    it 'responds to giphy command without args', ->
      testHubot robot.respond, 'giphy', 'testing'
      giphyPluginInstance.respond.should.have.been.calledWith 'testing'

    it 'responds to giphy command with args', ->
      testHubot robot.respond, 'giphy test', 'testing'
      giphyPluginInstance.respond.should.have.been.calledWith 'testing'

    it 'does not respond to non-giphy command without args', ->
      testHubot robot.respond, 'notgiphy'
      giphyPluginInstance.respond.should.not.have.been.called

    it 'does not respond to non-giphy command with args', ->
      testHubot robot.respond, 'notgiphy test'
      giphyPluginInstance.respond.should.not.have.been.called

    it 'does not respond to giphy command with a leading space', ->
      testHubot robot.respond, ' giphy test'
      giphyPluginInstance.respond.should.not.have.been.called

    it 'matches giphy command args', ->
      responder = robot.respond.getCalls()[0]
      match = responder.args[0].exec 'giphy testing'
      should.exist match
      match.should.have.lengthOf 2
      match[0].should.eql 'giphy testing'
      match[1].should.eql 'testing'

    it 'matches giphy command args and trims spaces', ->
      responder = robot.respond.getCalls()[0]
      match = responder.args[0].exec 'giphy     testing     '
      should.exist match
      match.should.have.lengthOf 2
      match[0].should.eql 'giphy     testing     '
      match[1].should.eql 'testing'

  describe 'class', ->
    describe '.constructor', ->
      it 'assigns the provided api', ->
        giphyInstance = new Giphy 'api'
        should.exist giphyInstance.api
        giphyInstance.api.should.eql 'api'

      it 'assigns a default endpoint', ->
        giphyInstance = new Giphy 'api'
        should.exist giphyInstance.defaultEndpoint
        giphyInstance.defaultEndpoint.should.eql Giphy.SearchEndpointName

      it 'allows default endpoint override via HUBOT_GIPHY_DEFAULT_ENDPOINT', ->
        process.env.HUBOT_GIPHY_DEFAULT_ENDPOINT = 'testing'
        giphyInstance = new Giphy 'api'
        giphyInstance.defaultEndpoint.should.eql 'testing'

      it 'throws an error if no api is provided', ->
        should.throw -> new Giphy()

    describe '.error', ->
      beforeEach ->
        @fakes.stub @giphy, 'sendMessage'

      it 'sends the reason if msg and reason exist', ->
        @giphy.error 'msg', 'test'
        @giphy.sendMessage.should.have.been.called.once
        @giphy.sendMessage.should.have.been.calledWith 'msg', 'test'

      it 'ignores a null msg or reason', ->
        @giphy.error()
        @giphy.error 'msg'
        @giphy.error 'msg', null
        @giphy.error null, 'test'
        @giphy.sendMessage.should.not.have.been.called

    describe '.createState', ->
      it 'returns a valid state instance for non-empty args', ->
        msg = { match: [ null, 'test' ] }
        state = @giphy.createState msg
        should.exist state
        state.msg.should.eql msg
        state.input.should.eql msg.match[1]
        should.equal state.endpoint, undefined
        should.equal state.args, undefined
        should.equal state.options, undefined
        should.equal state.uri, undefined

      it 'returns a valid state instance for empty args', ->
        msg = { match: [ null, null ] }
        state = @giphy.createState msg
        should.exist state
        state.msg.should.eql msg
        state.input.should.eql ''
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
        @fakes.stub @giphy, 'match', -> null
        @giphy.getEndpoint state
        @giphy.match.should.be.called.once
        @giphy.match.should.be.calledWith state.input

      it 'handles null match result', ->
        state = { }
        @fakes.stub @giphy, 'match', -> null
        @giphy.getEndpoint state
        state.endpoint.should.eql ''
        state.args.should.eql ''

      it 'handles endpoint and args match', ->
        state = { }
        @fakes.stub @giphy, 'match', -> [ null, 'test1', 'test2' ]
        @giphy.getEndpoint state
        state.endpoint.should.eql 'test1'
        state.args.should.eql 'test2'

      it 'handles only args match', ->
        state = { }
        @fakes.stub @giphy, 'match', -> [ null, null, 'test2' ]
        @giphy.getEndpoint state
        state.endpoint.should.eql @giphy.defaultEndpoint
        state.args.should.eql 'test2'

    describe '.getNextOption', ->
      it 'handles empty args', ->
        state = { args: '', options: { } }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.false
        state.args.should.eql ''
        state.options.should.eql { }

      it 'handles a single non-switch arg', ->
        state = { args: 'test1', options: { } }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.false
        state.args.should.eql 'test1'
        state.options.should.eql { }

      it 'handles multiple non-switch args', ->
        state = { args: 'test1 test2', options: { } }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.false
        state.args.should.eql 'test1 test2'
        state.options.should.eql { }

      it 'handles a single switch', ->
        state = { args: '/test1:test1', options: { } }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.true
        state.args.should.eql ''
        state.options.should.eql { test1: 'test1' }

      it 'handles multiple switches', ->
        state = { args: '/test1:test1 /test2:test2', options: { } }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.true
        state.args.should.eql '/test2:test2'
        state.options.should.eql { test1: 'test1' }

      it 'handles switches before args', ->
        state = { args: '/test1:test1 test2', options: { } }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.true
        state.args.should.eql 'test2'
        state.options.should.eql { test1: 'test1' }

      it 'handles switches after args', ->
        state = { args: 'test1 /test2:test2', options: { } }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.true
        state.args.should.eql 'test1'
        state.options.should.eql { test2: 'test2' }

      it 'handles mixed switches and args', ->
        state = { args: '/test1:test1 test 2 /test3:test3', options: { } }
        optionFound = @giphy.getNextOption state
        optionFound.should.be.true
        state.args.should.eql 'test 2 /test3:test3'
        state.options.should.eql { test1: 'test1' }

    describe '.getOptions', ->
      it 'handles false result from getNextOption', ->
        state = { args: 'testing' }
        @fakes.stub @giphy, 'getNextOption', (s) -> false
        @giphy.getOptions state
        @giphy.getNextOption.should.be.called.once
        @giphy.getNextOption.should.be.calledWith state
        should.exist state.options
        state.options.should.eql { }

      it 'handles true then false result from getNextOption', ->
        state = { args: 'testing' }
        calls = 2
        @fakes.stub @giphy, 'getNextOption', (state) -> (calls = calls - 1) > 0
        @giphy.getOptions state
        @giphy.getNextOption.should.be.called.twice
        @giphy.getNextOption.should.be.calledWith state
        should.exist state.options
        state.options.should.eql { }

      it 'parses mixed switches and args', ->
        state = { args: '/test1:1 test 2 /test3:test3' }
        @giphy.getOptions state
        state.args.should.eql 'test 2'
        should.exist state.options
        state.options.should.eql { test1: '1', test3: 'test3' }

    describe '.getRandomResultData', ->
      it 'calls the callback with a single value collection', ->
        callback = @fakes.stub().returns 'result'
        result = @giphy.getRandomResultData [ 'testing' ], callback
        callback.should.have.been.called.once
        callback.should.have.been.calledWith 'testing'
        should.exist result
        result.should.eql 'result'

      it 'calls the callback with a multiple value collection', ->
        callback = @fakes.stub().returns 'result'
        result = @giphy.getRandomResultData [ 'testing1', 'testing2' ], callback
        callback.should.have.been.called.once
        callback.should.have.been.calledWith sinon.match('testing1').or sinon.match('testing2')
        should.exist result
        result.should.eql 'result'

      it 'handles null or empty data', ->
        callback = sinon.spy()
        @giphy.getRandomResultData undefined, callback
        @giphy.getRandomResultData null, callback
        @giphy.getRandomResultData [], callback
        callback.should.not.have.been.called

    describe '.getUriFromResultData', ->
      it 'returns .data.images.original.url', ->
        uri = @giphy.getUriFromResultData sampleData
        should.exist uri
        uri.should.eql sampleData.images.original.url

      it 'does not return a uri for invalid input', ->
        uri = @giphy.getUriFromResultData null
        should.not.exist uri
        uri = @giphy.getUriFromResultData { }
        should.not.exist uri
        uri = @giphy.getUriFromResultData { images: { } }
        should.not.exist uri
        uri = @giphy.getUriFromResultData { images: { original: { } } }
        should.not.exist uri

    describe '.getSearchUri', ->
      it 'gets a result using args', ->
        state = { args: 'testing' }
        @fakes.stub @giphy.api, 'search'
        @giphy.getSearchUri state
        @giphy.api.search.should.have.been.called.once
        @giphy.api.search.should.have.been.calledWith { q: 'testing' }, sinon.match.func

      it 'gets a result using args and options', ->
        state = { args: 'testing', options: { limit: '10' } }
        @fakes.stub @giphy.api, 'search'
        @giphy.getSearchUri state
        @giphy.api.search.should.have.been.called.once
        @giphy.api.search.should.have.been.calledWith { q: 'testing', limit: '10' }, sinon.match.func

      it 'uses HUBOT_GIPHY_DEFAULT_LIMIT for the default limit', ->
        state = { args: 'testing' }
        process.env.HUBOT_GIPHY_DEFAULT_LIMIT = '123'
        @fakes.stub @giphy.api, 'search'
        @giphy.getSearchUri state
        @giphy.api.search.should.have.been.called.once
        @giphy.api.search.should.have.been.calledWith { q: 'testing', limit: '123' }, sinon.match.func

      it 'uses HUBOT_GIPHY_DEFAULT_RATING for the default rating', ->
        state = { args: 'testing' }
        process.env.HUBOT_GIPHY_DEFAULT_RATING = 'test'
        @fakes.stub @giphy.api, 'search'
        @giphy.getSearchUri state
        @giphy.api.search.should.have.been.called.once
        @giphy.api.search.should.have.been.calledWith { q: 'testing', rating: 'test' }, sinon.match.func

      it 'handles the response callback', ->
        state = { msg: 'msg', args: 'testing' }
        @fakes.stub @giphy.api, 'search', (options, callback) -> callback 'error', sampleCollectionResult
        @fakes.stub @giphy, 'handleResponse', (state, err, uriCreator) -> uriCreator()
        @fakes.stub @giphy, 'getRandomResultData'
        @giphy.getSearchUri state
        @giphy.handleResponse.should.have.been.called.once
        @giphy.handleResponse.should.have.been.calledWith state, 'error', sinon.match.func
        @giphy.getRandomResultData.should.have.been.called.once
        @giphy.getRandomResultData.should.have.been.calledWith sampleCollectionResult.data, @giphy.getUriFromResultData

      it 'calls getRandomUri for empty args', ->
        @fakes.stub @giphy, 'getRandomUri'
        @giphy.getSearchUri { }
        @giphy.getSearchUri { args: null }
        @giphy.getSearchUri { args: '' }
        @giphy.getRandomUri.should.have.callCount 3

    describe '.getIdUri', ->
      it 'gets a result using a single arg', ->
        state = { args: 'testing' }
        @fakes.stub @giphy.api, 'id'
        @giphy.getIdUri state
        @giphy.api.id.should.have.been.called.once
        @giphy.api.id.should.have.been.calledWith [ 'testing' ], sinon.match.func

      it 'gets a result using a multiple args', ->
        state = { args: 'test1 test2' }
        @fakes.stub @giphy.api, 'id'
        @giphy.getIdUri state
        @giphy.api.id.should.have.been.called.once
        @giphy.api.id.should.have.been.calledWith [ 'test1', 'test2' ], sinon.match.func

      it 'gets a result using a multiple args with additional spaces', ->
        state = { args: '   test1   test2   ' }
        @fakes.stub @giphy.api, 'id'
        @giphy.getIdUri state
        @giphy.api.id.should.have.been.called.once
        @giphy.api.id.should.have.been.calledWith [ 'test1', 'test2' ], sinon.match.func

      it 'handles the response callback', ->
        state = { msg: 'msg', args: 'testing' }
        @fakes.stub @giphy.api, 'id', (ids, callback) -> callback 'error', sampleCollectionResult
        @fakes.stub @giphy, 'handleResponse', (state, err, uriCreator) -> uriCreator()
        @fakes.stub @giphy, 'getRandomResultData'
        @giphy.getIdUri state
        @giphy.handleResponse.should.have.been.called.once
        @giphy.handleResponse.should.have.been.calledWith state, 'error', sinon.match.func
        @giphy.getRandomResultData.should.have.been.called.once
        @giphy.getRandomResultData.should.have.been.calledWith sampleCollectionResult.data, @giphy.getUriFromResultData

      it 'sends and error when no args are provided', ->
        state = { }
        @fakes.stub @giphy, 'error'
        @giphy.getIdUri state
        state.args = null
        @giphy.getIdUri state
        state.args = ''
        @giphy.getIdUri state
        @giphy.error.should.have.callCount 3
        @giphy.error.should.have.been.always.calledWith sinon.match.any, 'No Id Provided'

    describe '.getTranslateUri', ->
      it 'gets a result using args', ->
        state = { args: 'testing' }
        @fakes.stub @giphy.api, 'translate'
        @giphy.getTranslateUri state
        @giphy.api.translate.should.have.been.called.once
        @giphy.api.translate.should.have.been.calledWith { s: 'testing' }, sinon.match.func

      it 'gets a result using args and options', ->
        state = { args: 'testing', options: { rating: 'test' } }
        @fakes.stub @giphy.api, 'translate'
        @giphy.getTranslateUri state
        @giphy.api.translate.should.have.been.called.once
        @giphy.api.translate.should.have.been.calledWith { s: 'testing', rating: 'test' }, sinon.match.func

      it 'uses HUBOT_GIPHY_DEFAULT_RATING for the default rating', ->
        state = { args: 'testing' }
        process.env.HUBOT_GIPHY_DEFAULT_RATING = 'test'
        @fakes.stub @giphy.api, 'translate'
        @giphy.getTranslateUri state
        @giphy.api.translate.should.have.been.called.once
        @giphy.api.translate.should.have.been.calledWith { s: 'testing', rating: 'test' }, sinon.match.func

      it 'handles the response callback', ->
        state = { msg: 'msg', args: 'testing' }
        @fakes.stub @giphy.api, 'translate', (options, callback) -> callback 'error', sampleResult
        @fakes.stub @giphy, 'handleResponse', (state, err, uriCreator) -> uriCreator()
        @fakes.stub @giphy, 'getUriFromResultData'
        @giphy.getTranslateUri state
        @giphy.handleResponse.should.have.been.called.once
        @giphy.handleResponse.should.have.been.calledWith state, 'error', sinon.match.func
        @giphy.getUriFromResultData.should.have.been.called.once
        @giphy.getUriFromResultData.should.have.been.calledWith sampleData

    describe '.getRandomUri', ->
      it 'gets a result using args', ->
        state = { args: 'testing' }
        @fakes.stub @giphy.api, 'random'
        @giphy.getRandomUri state
        @giphy.api.random.should.have.been.called.once
        @giphy.api.random.should.have.been.calledWith { tag: 'testing' }, sinon.match.func

      it 'gets a result using args and options', ->
        state = { args: 'testing', options: { rating: 'test' } }
        @fakes.stub @giphy.api, 'random'
        @giphy.getRandomUri state
        @giphy.api.random.should.have.been.called.once
        @giphy.api.random.should.have.been.calledWith { tag: 'testing', rating: 'test' }, sinon.match.func

      it 'uses HUBOT_GIPHY_DEFAULT_RATING for the default rating', ->
        state = { args: 'testing' }
        process.env.HUBOT_GIPHY_DEFAULT_RATING = 'test'
        @fakes.stub @giphy.api, 'random'
        @giphy.getRandomUri state
        @giphy.api.random.should.have.been.called.once
        @giphy.api.random.should.have.been.calledWith { tag: 'testing', rating: 'test' }, sinon.match.func

      it 'handles the response callback', ->
        state = { msg: 'msg', args: 'testing' }
        @fakes.stub @giphy.api, 'random', (options, callback) -> callback 'error', sampleResult
        @fakes.stub @giphy, 'handleResponse', (state, err, uriCreator) -> uriCreator()
        @fakes.stub @giphy, 'getUriFromResultData'
        @giphy.getRandomUri state
        @giphy.handleResponse.should.have.been.called.once
        @giphy.handleResponse.should.have.been.calledWith state, 'error', sinon.match.func
        @giphy.getUriFromResultData.should.have.been.called.once
        @giphy.getUriFromResultData.should.have.been.calledWith sampleData

    describe '.getTrendingUri', ->
      it 'gets a result without options', ->
        state = { }
        @fakes.stub @giphy.api, 'trending'
        @giphy.getTrendingUri state
        @giphy.api.trending.should.have.been.called.once
        @giphy.api.trending.should.have.been.calledWith { }, sinon.match.func

      it 'gets a result using options', ->
        state = { options: { limit: '123', rating: 'test' } }
        @fakes.stub @giphy.api, 'trending'
        @giphy.getTrendingUri state
        @giphy.api.trending.should.have.been.called.once
        @giphy.api.trending.should.have.been.calledWith { limit: '123', rating: 'test' }, sinon.match.func

      it 'uses HUBOT_GIPHY_DEFAULT_LIMIT for the default limit', ->
        state = { }
        process.env.HUBOT_GIPHY_DEFAULT_LIMIT = '123'
        @fakes.stub @giphy.api, 'trending'
        @giphy.getTrendingUri state
        @giphy.api.trending.should.have.been.called.once
        @giphy.api.trending.should.have.been.calledWith { limit: '123' }, sinon.match.func

      it 'uses HUBOT_GIPHY_DEFAULT_RATING for the default rating', ->
        state = { }
        process.env.HUBOT_GIPHY_DEFAULT_RATING = 'test'
        @fakes.stub @giphy.api, 'trending'
        @giphy.getTrendingUri state
        @giphy.api.trending.should.have.been.called.once
        @giphy.api.trending.should.have.been.calledWith { rating: 'test' }, sinon.match.func

      it 'handles the response callback', ->
        state = { msg: 'msg' }
        @fakes.stub @giphy.api, 'trending', (options, callback) -> callback 'error', sampleCollectionResult
        @fakes.stub @giphy, 'handleResponse', (state, err, uriCreator) -> uriCreator()
        @fakes.stub @giphy, 'getRandomResultData'
        @giphy.getTrendingUri state
        @giphy.handleResponse.should.have.been.called.once
        @giphy.handleResponse.should.have.been.calledWith state, 'error', sinon.match.func
        @giphy.getRandomResultData.should.have.been.called.once
        @giphy.getRandomResultData.should.have.been.calledWith sampleCollectionResult.data, @giphy.getUriFromResultData

    describe '.getHelp', ->
      it 'send a response with help text', ->
        state = { }
        @fakes.stub @giphy, 'sendMessage'
        @giphy.getHelp state
        @giphy.sendMessage.should.have.been.called.once

    describe '.getUri', ->
      it 'handles a null endpoint', ->
        @fakes.stub @giphy, 'error'
        @giphy.getUri { }
        @giphy.error.should.have.been.called.once

      it 'handles a search endpoint', ->
        state = { endpoint: @giphy.constructor.SearchEndpointName }
        @fakes.stub @giphy, 'getSearchUri'
        @giphy.getUri state
        @giphy.getSearchUri.should.have.been.called.once
        @giphy.getSearchUri.should.have.been.calledWith state

      it 'handles an id endpoint', ->
        state = { endpoint: @giphy.constructor.IdEndpointName }
        @fakes.stub @giphy, 'getIdUri'
        @giphy.getUri state
        @giphy.getIdUri.should.have.been.called.once
        @giphy.getIdUri.should.have.been.calledWith state

      it 'handles a translate endpoint', ->
        state = { endpoint: @giphy.constructor.TranslateEndpointName }
        @fakes.stub @giphy, 'getTranslateUri'
        @giphy.getUri state
        @giphy.getTranslateUri.should.have.been.called.once
        @giphy.getTranslateUri.should.have.been.calledWith state

      it 'handles a random endpoint', ->
        state = { endpoint: @giphy.constructor.RandomEndpointName }
        @fakes.stub @giphy, 'getRandomUri'
        @giphy.getUri state
        @giphy.getRandomUri.should.have.been.called.once
        @giphy.getRandomUri.should.have.been.calledWith state

      it 'handles a trending endpoint', ->
        state = { endpoint: @giphy.constructor.TrendingEndpointName }
        @fakes.stub @giphy, 'getTrendingUri'
        @giphy.getUri state
        @giphy.getTrendingUri.should.have.been.called.once
        @giphy.getTrendingUri.should.have.been.calledWith state

      it 'handles help', ->
        state = { endpoint: @giphy.constructor.HelpName }
        @fakes.stub @giphy, 'getHelp'
        @giphy.getUri state
        @giphy.getHelp.should.have.been.called.once
        @giphy.getHelp.should.have.been.calledWith state

    describe '.handleResponse', ->
      it 'sends a response when there is no error', ->
        state = { }
        uriCreator = @fakes.stub().returns sampleUri
        @fakes.stub @giphy, 'sendResponse'
        @giphy.handleResponse state, null, uriCreator
        uriCreator.should.have.been.called.once
        @giphy.sendResponse.should.have.been.called.once
        @giphy.sendResponse.should.have.been.calledWith { uri: sampleUri }
        should.exist state.uri
        state.uri.should.eql sampleUri

      it 'sends an error when the state is missing a valid uri', ->
        state = { msg: @msg }
        uriCreator = @fakes.stub().returns sampleUri
        @fakes.stub @giphy, 'error'
        @giphy.handleResponse state, 'error', uriCreator
        uriCreator.should.not.have.been.called
        @giphy.error.should.have.been.called.once
        @giphy.error.should.have.been.calledWith state.msg, 'error'
        should.not.exist state.uri

    describe '.sendResponse', ->
      beforeEach ->
        @fakes.stub @giphy, 'sendMessage'
        @fakes.stub @giphy, 'error'

      it 'handles state with a uri', ->
        @giphy.sendResponse { msg: 'msg', uri: 'uri' }
        @giphy.sendMessage.should.be.called.once
        @giphy.sendMessage.should.be.calledWith 'msg', 'uri'

      it 'handles state without a uri', ->
        @giphy.sendResponse { }
        @giphy.error.should.be.called.once

    describe '.sendMessage', ->
      it 'sends a message when msg and message are valid', ->
        msg = { send: @fakes.stub() }
        @giphy.sendMessage msg, 'testing'
        msg.send.should.be.called.once
        msg.send.should.be.calledWith 'testing'

      it 'ignores calls when msg or message is null', ->
        msg = { send: @fakes.stub() }
        @giphy.sendMessage()
        @giphy.sendMessage msg
        @giphy.sendMessage msg, null
        @giphy.sendMessage undefined, 'testing'
        @giphy.sendMessage null, 'testing'
        msg.send.should.not.have.been.called

    describe '.respond', ->
      beforeEach ->
        @fakes.stub @giphy, 'getEndpoint'
        @fakes.stub @giphy, 'getOptions'
        @fakes.stub @giphy, 'getUri'
        @fakes.stub @giphy, 'error'

      it 'handles a valid msg', ->
        msg = { match: [ null, 'testing' ] }
        state = 'state'
        @fakes.stub @giphy, 'createState', -> state
        @giphy.respond msg
        @giphy.createState.should.have.been.calledWith msg
        @giphy.getEndpoint.should.have.been.calledWith state
        @giphy.getOptions.should.have.been.calledWith state
        @giphy.getUri.should.have.been.calledWith state

      it 'handles null msg', ->
        @giphy.respond()
        @giphy.respond null
        @giphy.getUri.should.not.have.been.called
        @giphy.error.should.have.been.called.twice

      it 'handles missing giphy command args', ->
        @giphy.respond { }
        @giphy.respond { match: null }
        @giphy.respond { match: [] }
        @giphy.respond { match: [ null ] }
        @giphy.getUri.should.not.have.been.called
        @giphy.error.should.have.callCount 4
