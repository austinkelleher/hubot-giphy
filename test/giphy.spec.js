// this allows us to instrument the giphy internals
/* eslint-disable no-invalid-this,no-undefined,no-underscore-dangle */
global.IS_TESTING = true;

const chai = require('chai');
const sinon = require('sinon');
const giphyApi = require('giphy-api');
const hubotGiphy = require('../src/giphy');

const { Giphy } = hubotGiphy;
const { extend } = hubotGiphy;
const { merge } = hubotGiphy;

const should = chai.should();

chai.use(require('sinon-chai'));

const sampleUri = 'http://giphy.com/example.gif';

const sampleData = {
  images: {
    original: {
      url: sampleUri,
    },
  },
};

const sampleRandomData = {
  url: sampleUri,
};

const sampleResult = {
  data: sampleData,
};

const sampleRandomResult = {
  data: sampleRandomData,
};

const sampleCollectionResult = {
  data: [
    sampleData,
  ],
};

describe('giphy', () => {
  // keep a copy of the original environment so we can restore it
  before(() => {
    this.env = process.env;
    return this.env;
  });

  beforeEach(() => {
    // this will hold all of our fakes so we can restore everything with a single call
    this.fakes = sinon.collection;

    // clone the original environment so we can inject variables
    process.env = extend({ }, this.env);

    // create a fake robot
    const robot = { name: 'robot' };

    // create a new test giphy api
    this.api = giphyApi();
    // create a new test giphy instance
    this.giphy = new Giphy(robot, this.api);

    // protect against any real XHR attempts
    return this.fakes.stub(this.api, '_request', (options, callback) => callback('XHR Attempted', null));
  });

  afterEach(() => this.fakes.restore());

  after(() => {
    // restore original environment
    process.env = this.env;
    return process.env;
  });

  describe('test instrumentation', () => {
    it('has a valid giphy-api module and instance', () => {
      should.exist(giphyApi);
      return should.exist(this.api);
    });

    it('has a valid Giphy class definition and instance', () => {
      should.exist(Giphy);
      should.exist(this.giphy);
      should.exist(this.giphy.api);
      return this.giphy.api.should.eql(this.api);
    });

    it('should be able to access the hubot giphy instance', () => {
      const robot = { respond: this.fakes.spy() };

      should.exist(hubotGiphy);
      const giphyPluginInstance = hubotGiphy(robot);

      should.exist(giphyPluginInstance);
      return should.exist(giphyPluginInstance.api);
    });

    it('should be able to access the extend utility', () => should.exist(extend));

    it('should be able to access the merge utility', () => should.exist(merge));

    it('can simulate environment variable values', () => {
      process.env.TESTING = 'testing';
      return process.env.TESTING.should.eql('testing');
    });

    return it('does not persist environment variable changes', () => should.not.exist(process.env.TESTING));
  });

  describe('extend utility', () => {
    it('creates an empty object for null input', () => {
      const result = extend();

      should.exist(result);
      return result.should.eql({ });
    });

    it('adds properties to an empty object', () => {
      const result = extend(null, { a: 1 });

      should.exist(result);
      return result.should.eql({ a: 1 });
    });

    it('adds properties to a non-empty object', () => {
      const result = extend({ b: 2 }, { a: 1 });

      should.exist(result);
      return result.should.eql({ a: 1, b: 2 });
    });

    it('overwrites properties on a non-empty object', () => {
      const result = extend({ a: 2 }, { a: 1 });

      should.exist(result);
      return result.should.eql({ a: 1 });
    });

    it('retains empty string properties', () => {
      const result = extend({ }, { a: '' });

      should.exist(result);
      return result.should.eql({ a: '' });
    });

    return it('ignores null properties', () => {
      const result = extend({ a: 1 }, { b: null });

      should.exist(result);
      return result.should.eql({ a: 1 });
    });
  });

  describe('merge utility', () => it('has no tests yet'));

  describe('hubot script', () => {
    let giphyPluginInstance = null;
    let robot = null;

    // helper function to confirm hubot responds to the correct input
    function testHubot(spy, input, args) {
      const [ callback, other ] = Array.from(spy
        .getCalls()
        .filter((x) => x.args[0].test(input))
        .map((x) => x.args[1]));

      should.not.exist(other, `Multiple Matches for ${ input }`);

      return callback && callback(args);
    }

    beforeEach(() => {
      robot = { respond: this.fakes.spy() };
      giphyPluginInstance = hubotGiphy(robot);
      this.fakes.stub(giphyPluginInstance.api, '_request', (options, callback) => callback('XHR Attempted', null));
      return this.fakes.stub(giphyPluginInstance, 'respond');
    });

    it('api instance should default to http', () => {
      giphyPluginInstance = hubotGiphy(robot);
      return giphyPluginInstance.api.httpService.globalAgent.protocol.should.match(/^http:$/);
    });

    it('api instance supports enabling https via HUBOT_GIPHY_HTTPS', () => {
      process.env.HUBOT_GIPHY_HTTPS = 'true';
      giphyPluginInstance = hubotGiphy(robot);
      return giphyPluginInstance.api.httpService.globalAgent.protocol.should.match(/^https:$/);
    });

    it('api instance supports overriding the timeout via HUBOT_GIPHY_TIMEOUT', () => {
      process.env.HUBOT_GIPHY_TIMEOUT = '123';
      giphyPluginInstance = hubotGiphy(robot);
      return giphyPluginInstance.api.timeout.should.eql(123);
    });

    it('api instance supports setting the api key via HUBOT_GIPHY_API_KEY', () => {
      process.env.HUBOT_GIPHY_API_KEY = 'testing';
      giphyPluginInstance = hubotGiphy(robot);
      return giphyPluginInstance.api.apiKey.should.eql('testing');
    });

    it('has an active respond trigger', () => robot.respond.should.have.been.called.once);

    it('responds to giphy command without args', () => {
      testHubot(robot.respond, 'giphy', 'testing');
      return giphyPluginInstance.respond.should.have.been.calledWith('testing');
    });

    it('responds to giphy command with args', () => {
      testHubot(robot.respond, 'giphy test', 'testing');
      return giphyPluginInstance.respond.should.have.been.calledWith('testing');
    });

    it('matches giphy command args', () => {
      const match = robot.respond.lastCall.args[0].exec('giphy testing');

      should.exist(match);
      match.should.have.lengthOf(2);
      match[0].should.eql('giphy testing');
      return match[1].should.eql('testing');
    });

    return it('matches giphy command args and trims spaces', () => {
      const match = robot.respond.lastCall.args[0].exec('giphy     testing     ');

      should.exist(match);
      match.should.have.lengthOf(2);
      match[0].should.eql('giphy     testing     ');
      return match[1].should.eql('testing');
    });
  });

  describe('class', () => {
    describe('.constructor', () => {
      it('assigns the provided robot', () => {
        const giphyInstance = new Giphy('robot', 'api');

        should.exist(giphyInstance.robot);
        return giphyInstance.robot.should.eql('robot');
      });

      it('assigns the provided api', () => {
        const giphyInstance = new Giphy('robot', 'api');

        should.exist(giphyInstance.api);
        return giphyInstance.api.should.eql('api');
      });

      it('assigns a default endpoint', () => {
        const giphyInstance = new Giphy('robot', 'api');

        should.exist(giphyInstance.defaultEndpoint);
        return giphyInstance.defaultEndpoint.should.eql(Giphy.SearchEndpointName);
      });

      it('assigns a default limit', () => {
        const giphyInstance = new Giphy('robot', 'api');

        should.exist(giphyInstance.defaultLimit);
        return giphyInstance.defaultEndpoint.should.have.length.greaterThan.zero;
      });

      it('assigns a disabled max size of 0 as a default', () => {
        const giphyInstance = new Giphy('robot', 'api');

        should.exist(giphyInstance.maxSize);
        return giphyInstance.maxSize.should.eql(0);
      });

      it('allows default limit override via HUBOT_GIPHY_DEFAULT_LIMIT', () => {
        process.env.HUBOT_GIPHY_DEFAULT_LIMIT = '123';
        const giphyInstance = new Giphy('robot', 'api');

        return giphyInstance.defaultLimit.should.eql('123');
      });

      it('allows default endpoint override via HUBOT_GIPHY_DEFAULT_ENDPOINT', () => {
        process.env.HUBOT_GIPHY_DEFAULT_ENDPOINT = 'testing';
        const giphyInstance = new Giphy('robot', 'api');

        return giphyInstance.defaultEndpoint.should.eql('testing');
      });

      it('allows strict max image size configuration via HUBOT_GIPHY_MAX_SIZE', () => {
        process.env.HUBOT_GIPHY_MAX_SIZE = '123';
        const giphyInstance = new Giphy('robot', 'api');

        giphyInstance.maxSize.should.eql(123);
        return giphyInstance.allowLargerThanMaxSize.should.eql(false);
      });

      it('allows loose max image size configuration via HUBOT_GIPHY_MAX_SIZE', () => {
        process.env.HUBOT_GIPHY_MAX_SIZE = '~123';
        const giphyInstance = new Giphy('robot', 'api');

        giphyInstance.maxSize.should.eql(123);
        return giphyInstance.allowLargerThanMaxSize.should.eql(true);
      });

      it('ignores invalid configuration via HUBOT_GIPHY_MAX_SIZE', () => {
        process.env.HUBOT_GIPHY_MAX_SIZE = 'asdf';
        const giphyInstance = new Giphy('robot', 'api');

        return giphyInstance.maxSize.should.eql(0);
      });

      it('throws an error if no robot is provided', () => {
        should.throw(() => new Giphy());
        return should.throw(() => new Giphy(null, 'api'));
      });

      return it('throws an error if no api is provided', () => should.throw(() => new Giphy('robot')));
    });

    describe('.error', () => {
      beforeEach(() => this.fakes.stub(this.giphy, 'sendMessage'));

      it('sends the reason if msg and reason exist', () => {
        this.giphy.error('msg', 'test');
        this.giphy.sendMessage.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.sendMessage.should.have.been.calledWith('msg', 'test');
      });

      return it('ignores a null msg or reason', () => {
        this.giphy.error();
        this.giphy.error('msg');
        this.giphy.error('msg', null);
        this.giphy.error(null, 'test');
        return this.giphy.sendMessage.should.not.have.been.called;
      });
    });

    describe('.createState', () => {
      it('returns a valid state instance for non-empty args', () => {
        const msg = { match: [ null, 'test' ] };
        const state = this.giphy.createState(msg);

        should.exist(state);
        state.msg.should.eql(msg);
        state.input.should.eql(msg.match[1]);
        should.equal(state.endpoint, undefined);
        should.equal(state.args, undefined);
        should.equal(state.options, undefined);
        return should.equal(state.uri, undefined);
      });

      it('returns a valid state instance for empty args', () => {
        const msg = { match: [ null, null ] };
        const state = this.giphy.createState(msg);

        should.exist(state);
        state.msg.should.eql(msg);
        state.input.should.eql('');
        should.equal(state.endpoint, undefined);
        should.equal(state.args, undefined);
        should.equal(state.options, undefined);
        return should.equal(state.uri, undefined);
      });

      return it('ignores a null msg', () => {
        let state = this.giphy.createState();

        should.not.exist(state);
        state = this.giphy.createState(null);
        return should.not.exist(state);
      });
    });

    describe('.match', () => {
      it('matches empty input', () => {
        const match = this.giphy.match('');

        should.exist(match);
        should.equal(match[1], undefined);
        return match[2].should.eql('');
      });

      it('matches null input', () => {
        const match = this.giphy.match(null);

        should.exist(match);
        should.equal(match[1], undefined);
        return match[2].should.eql('');
      });

      it('matches undefined input', () => {
        const match = this.giphy.match();

        should.exist(match);
        should.equal(match[1], undefined);
        return match[2].should.eql('');
      });

      it('matches search', () => {
        const match = this.giphy.match('search');

        should.exist(match);
        match[1].should.eql('search');
        return match[2].should.eql('');
      });

      it('matches id', () => {
        const match = this.giphy.match('id');

        should.exist(match);
        match[1].should.eql('id');
        return match[2].should.eql('');
      });

      it('matches translate', () => {
        const match = this.giphy.match('translate');

        should.exist(match);
        match[1].should.eql('translate');
        return match[2].should.eql('');
      });

      it('matches random', () => {
        const match = this.giphy.match('random');

        should.exist(match);
        match[1].should.eql('random');
        return match[2].should.eql('');
      });

      it('matches trending', () => {
        const match = this.giphy.match('trending');

        should.exist(match);
        match[1].should.eql('trending');
        return match[2].should.eql('');
      });

      it('matches help', () => {
        const match = this.giphy.match('help');

        should.exist(match);
        match[1].should.eql('help');
        return match[2].should.eql('');
      });

      it('matches a single arg', () => {
        const match = this.giphy.match('help testing');

        should.exist(match);
        match[1].should.eql('help');
        return match[2].should.eql('testing');
      });

      it('matches multiple args', () => {
        const match = this.giphy.match('help testing1 testing2');

        should.exist(match);
        match[1].should.eql('help');
        return match[2].should.eql('testing1 testing2');
      });

      return it('matches only args', () => {
        const match = this.giphy.match('testing1 testing2');

        should.exist(match);
        should.equal(match[1], undefined);
        return match[2].should.eql('testing1 testing2');
      });
    });

    describe('.getEndpoint', () => {
      it('passes state input to match function', () => {
        const state = { input: 'testing' };

        this.fakes.stub(this.giphy, 'match', () => null);
        this.giphy.getEndpoint(state);
        this.giphy.match.should.be.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.match.should.be.calledWith(state.input);
      });

      it('handles null match result', () => {
        const state = { };

        this.fakes.stub(this.giphy, 'match', () => null);
        this.giphy.getEndpoint(state);
        state.endpoint.should.eql('');
        return state.args.should.eql('');
      });

      it('handles endpoint and args match', () => {
        const state = { };

        this.fakes.stub(this.giphy, 'match', () => [ null, 'test1', 'test2' ]);
        this.giphy.getEndpoint(state);
        state.endpoint.should.eql('test1');
        return state.args.should.eql('test2');
      });

      it('handles only endpoint match', () => {
        const state = { };

        this.fakes.stub(this.giphy, 'match', () => [ null, 'test1', '' ]);
        this.giphy.getEndpoint(state);
        state.endpoint.should.eql('test1');
        return state.args.should.eql('');
      });

      return it('handles only args match', () => {
        const state = { };

        this.fakes.stub(this.giphy, 'match', () => [ null, null, 'test2' ]);
        this.giphy.getEndpoint(state);
        state.endpoint.should.eql(this.giphy.defaultEndpoint);
        return state.args.should.eql('test2');
      });
    });

    describe('.getNextOption', () => {
      it('handles empty args', () => {
        const state = { args: '', options: { } };
        const optionFound = this.giphy.getNextOption(state);

        optionFound.should.be.false; // eslint-disable-line no-unused-expressions
        state.args.should.eql('');
        return state.options.should.eql({ });
      });

      it('handles a single non-switch arg', () => {
        const state = { args: 'test1', options: { } };
        const optionFound = this.giphy.getNextOption(state);

        optionFound.should.be.false; // eslint-disable-line no-unused-expressions
        state.args.should.eql('test1');
        return state.options.should.eql({ });
      });

      it('handles multiple non-switch args', () => {
        const state = { args: 'test1 test2', options: { } };
        const optionFound = this.giphy.getNextOption(state);

        optionFound.should.be.false; // eslint-disable-line no-unused-expressions
        state.args.should.eql('test1 test2');
        return state.options.should.eql({ });
      });

      it('handles a single switch', () => {
        const state = { args: '/test1:test1', options: { } };
        const optionFound = this.giphy.getNextOption(state);

        optionFound.should.be.true; // eslint-disable-line no-unused-expressions
        state.args.should.eql('');
        return state.options.should.eql({ test1: 'test1' });
      });

      it('handles a single empty switch value', () => {
        const state = { args: '/test1:', options: { } };
        const optionFound = this.giphy.getNextOption(state);

        optionFound.should.be.true; // eslint-disable-line no-unused-expressions
        state.args.should.eql('');
        return state.options.should.eql({ test1: '' });
      });

      it('handles multiple switches', () => {
        const state = { args: '/test1:test1 /test2:test2', options: { } };
        const optionFound = this.giphy.getNextOption(state);

        optionFound.should.be.true; // eslint-disable-line no-unused-expressions
        state.args.should.eql('/test2:test2');
        return state.options.should.eql({ test1: 'test1' });
      });

      it('handles switches before args', () => {
        const state = { args: '/test1:test1 test2', options: { } };
        const optionFound = this.giphy.getNextOption(state);

        optionFound.should.be.true; // eslint-disable-line no-unused-expressions
        state.args.should.eql('test2');
        return state.options.should.eql({ test1: 'test1' });
      });

      it('handles switches after args', () => {
        const state = { args: 'test1 /test2:test2', options: { } };
        const optionFound = this.giphy.getNextOption(state);

        optionFound.should.be.true; // eslint-disable-line no-unused-expressions
        state.args.should.eql('test1');
        return state.options.should.eql({ test2: 'test2' });
      });

      it('handles mixed switches and args', () => {
        const state = { args: '/test1:test1 test 2 /test3:test3', options: { } };
        const optionFound = this.giphy.getNextOption(state);

        optionFound.should.be.true; // eslint-disable-line no-unused-expressions
        state.args.should.eql('test 2 /test3:test3');
        return state.options.should.eql({ test1: 'test1' });
      });

      return it('handles empty value switches before args', () => {
        const state = { args: '/test1: test2', options: { } };
        const optionFound = this.giphy.getNextOption(state);

        optionFound.should.be.true; // eslint-disable-line no-unused-expressions
        state.args.should.eql('test2');
        return state.options.should.eql({ test1: '' });
      });
    });

    describe('.getOptions', () => {
      it('handles false result from getNextOption', () => {
        const state = { args: 'testing' };

        this.fakes.stub(this.giphy, 'getNextOption', (unused) => false); // eslint-disable-line no-unused-vars
        this.giphy.getOptions(state);
        this.giphy.getNextOption.should.be.called.once; // eslint-disable-line no-unused-expressions
        this.giphy.getNextOption.should.be.calledWith(state);
        should.exist(state.options);
        return state.options.should.eql({ });
      });

      it('handles true then false result from getNextOption', () => {
        const state = { args: 'testing' };
        let calls = 2;

        this.fakes.stub(this.giphy, 'getNextOption', (unused) => (calls--) > 0); // eslint-disable-line no-unused-vars
        this.giphy.getOptions(state);
        this.giphy.getNextOption.should.be.called.twice; // eslint-disable-line no-unused-expressions
        this.giphy.getNextOption.should.be.calledWith(state);
        should.exist(state.options);
        return state.options.should.eql({ });
      });

      return it('parses mixed switches and args', () => {
        const state = { args: '/test1:1 test 2 /test3:test3' };

        this.giphy.getOptions(state);
        state.args.should.eql('test 2');
        should.exist(state.options);
        return state.options.should.eql({ test1: '1', test3: 'test3' });
      });
    });

    describe('.getRandomResultFromCollectionData', () => {
      it('calls the callback with a single value collection', () => {
        const callback = this.fakes.stub().returns('result');
        const result = this.giphy.getRandomResultFromCollectionData([ 'testing' ], callback);

        callback.should.have.been.called.once;  // eslint-disable-line no-unused-expressions
        callback.should.have.been.calledWith('testing');
        should.exist(result);
        return result.should.eql('result');
      });

      it('calls the callback with a multiple value collection', () => {
        const callback = this.fakes.stub().returns('result');
        const result = this.giphy.getRandomResultFromCollectionData([ 'testing1', 'testing2' ], callback);

        callback.should.have.been.called.once;  // eslint-disable-line no-unused-expressions
        callback.should.have.been.calledWith(sinon.match('testing1').or(sinon.match('testing2')));
        should.exist(result);
        return result.should.eql('result');
      });

      return it('handles null or empty data', () => {
        const callback = sinon.spy();

        this.giphy.getRandomResultFromCollectionData(undefined, callback);
        this.giphy.getRandomResultFromCollectionData(null, callback);
        this.giphy.getRandomResultFromCollectionData([], callback);
        return callback.should.not.have.been.called;
      });
    });

    describe('.getUriFromResultDataWithMaxSize', () => {
      it('ignores calls with invalid or empty images', () => {
        let result = this.giphy.getUriFromResultDataWithMaxSize();

        should.not.exist(result);
        result = this.giphy.getUriFromResultDataWithMaxSize(null);
        should.not.exist(result);
        result = this.giphy.getUriFromResultDataWithMaxSize({ });
        return should.not.exist(result);
      });

      it('ignores calls without size or with size <= 0', () => {
        let result = this.giphy.getUriFromResultDataWithMaxSize({ img: null });

        should.not.exist(result);
        result = this.giphy.getUriFromResultDataWithMaxSize({ img: null }, 0);
        should.not.exist(result);
        result = this.giphy.getUriFromResultDataWithMaxSize({ img: null }, -1);
        return should.not.exist(result);
      });

      it('returns the largest allowed image in strict mode', () => {
        const images = {
          medium: { size: '500', url: 'medium' },
          small: { size: '100', url: 'small' },
          large: { size: '1000', url: 'large' },
        };
        let result = this.giphy.getUriFromResultDataWithMaxSize(images, 123, false);

        should.exist(result);
        result.should.eql(images.small.url);
        result = this.giphy.getUriFromResultDataWithMaxSize(images, 500, false);
        should.exist(result);
        result.should.eql(images.medium.url);
        result = this.giphy.getUriFromResultDataWithMaxSize(images, 999, false);
        should.exist(result);
        return result.should.eql(images.medium.url);
      });

      it('returns the smallest image when all images are too large in loose mode', () => {
        const images = {
          medium: { size: '500', url: 'medium' },
          small: { size: '100', url: 'small' },
          large: { size: '1000', url: 'large' },
        };
        const result = this.giphy.getUriFromResultDataWithMaxSize(images, 1, true);

        should.exist(result);
        return result.should.eql(images.small.url);
      });

      return it('returns nothing when all images are too large in strict mode', () => {
        const images = {
          medium: { size: '500' },
          small: { size: '100' },
          large: { size: '1000' },
        };
        const result = this.giphy.getUriFromResultDataWithMaxSize(images, 1, false);

        return should.not.exist(result);
      });
    });

    describe('.getUriFromResultData', () => {
      it('returns .images.original.url', () => {
        const uri = this.giphy.getUriFromResultData(sampleData);

        should.exist(uri);
        return uri.should.eql(sampleData.images.original.url);
      });

      it('does not return a uri for invalid input', () => {
        let uri = this.giphy.getUriFromResultData(null);

        should.not.exist(uri);
        uri = this.giphy.getUriFromResultData({ });
        should.not.exist(uri);
        uri = this.giphy.getUriFromResultData({ images: { } });
        should.not.exist(uri);
        uri = this.giphy.getUriFromResultData({ images: { original: { } } });
        return should.not.exist(uri);
      });

      return it('calls getUriFromResultDataWithMaxSize if maxSize > 0', () => {
        sinon.stub(this.giphy, 'getUriFromResultDataWithMaxSize');
        this.giphy.maxSize = 123;
        this.giphy.allowLargerThanMaxSize = true;
        this.giphy.getUriFromResultData(sampleData);
         // eslint-disable-next-line no-unused-expressions
        this.giphy.getUriFromResultDataWithMaxSize.should.have.been.called.once;
        return this.giphy.getUriFromResultDataWithMaxSize.should.have.been.calledWith(sampleData.images, 123, true);
      });
    });

    describe('.getUriFromRandomResultData', () => {
      it('returns .url', () => {
        const uri = this.giphy.getUriFromRandomResultData(sampleRandomData);

        should.exist(uri);
        return uri.should.eql(sampleRandomData.url);
      });

      return it('does not return a uri for invalid input', () => {
        let uri = this.giphy.getUriFromRandomResultData(null);

        should.not.exist(uri);
        uri = this.giphy.getUriFromRandomResultData({ });
        return should.not.exist(uri);
      });
    });

    describe('.getSearchUri', () => {
      it('gets a result using args', () => {
        const state = { args: 'testing' };

        this.fakes.stub(this.giphy.api, 'search');
        this.giphy.getSearchUri(state);
        this.giphy.api.search.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.search.should.have.been.calledWith({ limit: '5', q: 'testing' }, sinon.match.func);
      });

      it('gets a result using args and options', () => {
        const state = { args: 'testing', options: { limit: '10' } };

        this.fakes.stub(this.giphy.api, 'search');
        this.giphy.getSearchUri(state);
        this.giphy.api.search.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.search.should.have.been.calledWith({ q: 'testing', limit: '10' }, sinon.match.func);
      });

      it('uses @defaultLimit for the default limit', () => {
        const state = { args: 'testing' };

        this.giphy.defaultLimit = '123';
        this.fakes.stub(this.giphy.api, 'search');
        this.giphy.getSearchUri(state);
        this.giphy.api.search.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.search.should.have.been.calledWith({ q: 'testing', limit: '123' }, sinon.match.func);
      });

      it('uses HUBOT_GIPHY_DEFAULT_RATING for the default rating', () => {
        const state = { args: 'testing' };

        process.env.HUBOT_GIPHY_DEFAULT_RATING = 'test';
        this.fakes.stub(this.giphy.api, 'search');
        this.giphy.getSearchUri(state);
        this.giphy.api.search.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.search.should.have.been.calledWith(
          { limit: '5', q: 'testing', rating: 'test' }, sinon.match.func);
      });

      it('handles the response callback', () => {
        const state = { msg: 'msg', args: 'testing' };

        this.fakes.stub(this.giphy.api, 'search', (options, callback) => callback('error', sampleCollectionResult));
        this.fakes.stub(this.giphy, 'handleResponse', (unused, err, uriCreator) => uriCreator());
        this.fakes.stub(this.giphy, 'getRandomResultFromCollectionData');
        this.giphy.getSearchUri(state);
        this.giphy.handleResponse.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        this.giphy.handleResponse.should.have.been.calledWith(state, 'error', sinon.match.func);
         // eslint-disable-next-line no-unused-expressions
        this.giphy.getRandomResultFromCollectionData.should.have.been.called.once;
        return this.giphy.getRandomResultFromCollectionData.should.have.been.calledWith(
          sampleCollectionResult.data, this.giphy.getUriFromResultData);
      });

      return it('calls getRandomUri for empty args', () => {
        this.fakes.stub(this.giphy, 'getRandomUri');
        this.giphy.getSearchUri({ });
        this.giphy.getSearchUri({ args: null });
        this.giphy.getSearchUri({ args: '' });
        return this.giphy.getRandomUri.should.have.callCount(3);
      });
    });

    describe('.getIdUri', () => {
      it('gets a result using a single arg', () => {
        const state = { args: 'testing' };

        this.fakes.stub(this.giphy.api, 'id');
        this.giphy.getIdUri(state);
        this.giphy.api.id.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.id.should.have.been.calledWith([ 'testing' ], sinon.match.func);
      });

      it('gets a result using a multiple args', () => {
        const state = { args: 'test1 test2' };

        this.fakes.stub(this.giphy.api, 'id');
        this.giphy.getIdUri(state);
        this.giphy.api.id.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.id.should.have.been.calledWith([ 'test1', 'test2' ], sinon.match.func);
      });

      it('gets a result using a multiple args with additional spaces', () => {
        const state = { args: '   test1   test2   ' };

        this.fakes.stub(this.giphy.api, 'id');
        this.giphy.getIdUri(state);
        this.giphy.api.id.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.id.should.have.been.calledWith([ 'test1', 'test2' ], sinon.match.func);
      });

      it('handles the response callback', () => {
        const state = { msg: 'msg', args: 'testing' };

        this.fakes.stub(this.giphy.api, 'id', (ids, callback) => callback('error', sampleCollectionResult));
        this.fakes.stub(this.giphy, 'handleResponse', (unused, err, uriCreator) => uriCreator());
        this.fakes.stub(this.giphy, 'getRandomResultFromCollectionData');
        this.giphy.getIdUri(state);
        this.giphy.handleResponse.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        this.giphy.handleResponse.should.have.been.calledWith(state, 'error', sinon.match.func);
         // eslint-disable-next-line no-unused-expressions
        this.giphy.getRandomResultFromCollectionData.should.have.been.called.once;
        return this.giphy.getRandomResultFromCollectionData.should.have.been.calledWith(
          sampleCollectionResult.data, this.giphy.getUriFromResultData);
      });

      return it('sends and error when no args are provided', () => {
        const state = { };

        this.fakes.stub(this.giphy, 'error');
        this.giphy.getIdUri(state);
        state.args = null;
        this.giphy.getIdUri(state);
        state.args = '';
        this.giphy.getIdUri(state);
        this.giphy.error.should.have.callCount(3);
        return this.giphy.error.should.have.been.always.calledWith(sinon.match.any, 'No Id Provided');
      });
    });

    describe('.getTranslateUri', () => {
      it('gets a result using args', () => {
        const state = { args: 'testing' };

        this.fakes.stub(this.giphy.api, 'translate');
        this.giphy.getTranslateUri(state);
        this.giphy.api.translate.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.translate.should.have.been.calledWith({ s: 'testing' }, sinon.match.func);
      });

      it('gets a result using args and options', () => {
        const state = { args: 'testing', options: { rating: 'test' } };

        this.fakes.stub(this.giphy.api, 'translate');
        this.giphy.getTranslateUri(state);
        this.giphy.api.translate.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.translate.should.have.been.calledWith({ s: 'testing', rating: 'test' }, sinon.match.func);
      });

      it('uses HUBOT_GIPHY_DEFAULT_RATING for the default rating', () => {
        const state = { args: 'testing' };

        process.env.HUBOT_GIPHY_DEFAULT_RATING = 'test';
        this.fakes.stub(this.giphy.api, 'translate');
        this.giphy.getTranslateUri(state);
        this.giphy.api.translate.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.translate.should.have.been.calledWith({ s: 'testing', rating: 'test' }, sinon.match.func);
      });

      return it('handles the response callback', () => {
        const state = { msg: 'msg', args: 'testing' };

        this.fakes.stub(this.giphy.api, 'translate', (options, callback) => callback('error', sampleResult));
        this.fakes.stub(this.giphy, 'handleResponse', (unused, err, uriCreator) => uriCreator());
        this.fakes.stub(this.giphy, 'getUriFromResultData');
        this.giphy.getTranslateUri(state);
        this.giphy.handleResponse.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        this.giphy.handleResponse.should.have.been.calledWith(state, 'error', sinon.match.func);
        this.giphy.getUriFromResultData.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.getUriFromResultData.should.have.been.calledWith(sampleData);
      });
    });

    describe('.getRandomUri', () => {
      it('gets a result without args', () => {
        const state = { };

        this.fakes.stub(this.giphy.api, 'random');
        this.giphy.getRandomUri(state);
        this.giphy.api.random.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.random.should.have.been.calledWith({ }, sinon.match.func);
      });

      it('gets a result using args', () => {
        const state = { args: 'testing' };

        this.fakes.stub(this.giphy.api, 'random');
        this.giphy.getRandomUri(state);
        this.giphy.api.random.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.random.should.have.been.calledWith({ tag: 'testing' }, sinon.match.func);
      });

      it('gets a result using args and options', () => {
        const state = { args: 'testing', options: { rating: 'test' } };

        this.fakes.stub(this.giphy.api, 'random');
        this.giphy.getRandomUri(state);
        this.giphy.api.random.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.random.should.have.been.calledWith({ tag: 'testing', rating: 'test' }, sinon.match.func);
      });

      it('uses HUBOT_GIPHY_DEFAULT_RATING for the default rating', () => {
        const state = { args: 'testing' };

        process.env.HUBOT_GIPHY_DEFAULT_RATING = 'test';
        this.fakes.stub(this.giphy.api, 'random');
        this.giphy.getRandomUri(state);
        this.giphy.api.random.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.random.should.have.been.calledWith({ tag: 'testing', rating: 'test' }, sinon.match.func);
      });

      return it('handles the response callback', () => {
        const state = { msg: 'msg', args: 'testing' };

        this.fakes.stub(this.giphy.api, 'random', (options, callback) => callback('error', sampleRandomResult));
        this.fakes.stub(this.giphy, 'handleResponse', (unused, err, uriCreator) => uriCreator());
        this.fakes.stub(this.giphy, 'getUriFromRandomResultData');
        this.giphy.getRandomUri(state);
        this.giphy.handleResponse.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        this.giphy.handleResponse.should.have.been.calledWith(state, 'error', sinon.match.func);
         // eslint-disable-next-line no-unused-expressions
        this.giphy.getUriFromRandomResultData.should.have.been.called.once;
        return this.giphy.getUriFromRandomResultData.should.have.been.calledWith(sampleRandomData);
      });
    });

    describe('.getTrendingUri', () => {
      it('gets a result without options', () => {
        const state = { };

        this.fakes.stub(this.giphy.api, 'trending');
        this.giphy.getTrendingUri(state);
        this.giphy.api.trending.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.trending.should.have.been.calledWith({ limit: '5' }, sinon.match.func);
      });

      it('gets a result using options', () => {
        const state = { options: { limit: '123', rating: 'test' } };

        this.fakes.stub(this.giphy.api, 'trending');
        this.giphy.getTrendingUri(state);
        this.giphy.api.trending.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.trending.should.have.been.calledWith({ limit: '123', rating: 'test' }, sinon.match.func);
      });

      it('uses @defaultLimit for the default limit', () => {
        const state = { };

        this.giphy.defaultLimit = '123';
        this.fakes.stub(this.giphy.api, 'trending');
        this.giphy.getTrendingUri(state);
        this.giphy.api.trending.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.trending.should.have.been.calledWith({ limit: '123' }, sinon.match.func);
      });

      it('uses HUBOT_GIPHY_DEFAULT_RATING for the default rating', () => {
        const state = { };

        process.env.HUBOT_GIPHY_DEFAULT_RATING = 'test';
        this.fakes.stub(this.giphy.api, 'trending');
        this.giphy.getTrendingUri(state);
        this.giphy.api.trending.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.api.trending.should.have.been.calledWith({ limit: '5', rating: 'test' }, sinon.match.func);
      });

      return it('handles the response callback', () => {
        const state = { msg: 'msg' };

        this.fakes.stub(this.giphy.api, 'trending', (options, callback) => callback('error', sampleCollectionResult));
        this.fakes.stub(this.giphy, 'handleResponse', (unused, err, uriCreator) => uriCreator());
        this.fakes.stub(this.giphy, 'getRandomResultFromCollectionData');
        this.giphy.getTrendingUri(state);
        this.giphy.handleResponse.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        this.giphy.handleResponse.should.have.been.calledWith(state, 'error', sinon.match.func);
         // eslint-disable-next-line no-unused-expressions
        this.giphy.getRandomResultFromCollectionData.should.have.been.called.once;
        return this.giphy.getRandomResultFromCollectionData.should.have.been.calledWith(
          sampleCollectionResult.data, this.giphy.getUriFromResultData);
      });
    });

    describe('.getHelp', () =>
      it('send a response with help text', () => {
        const state = { };

        this.fakes.stub(this.giphy, 'sendMessage');
        this.giphy.getHelp(state);
        return this.giphy.sendMessage.should.have.been.called.once;
      })
    );

    describe('.getUri', () => {
      it('handles a null endpoint', () => {
        this.fakes.stub(this.giphy, 'error');
        this.giphy.getUri({ });
        return this.giphy.error.should.have.been.called.once;
      });

      it('handles a search endpoint', () => {
        const state = { endpoint: this.giphy.constructor.SearchEndpointName };

        this.fakes.stub(this.giphy, 'getSearchUri');
        this.giphy.getUri(state);
        this.giphy.getSearchUri.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.getSearchUri.should.have.been.calledWith(state);
      });

      it('handles an id endpoint', () => {
        const state = { endpoint: this.giphy.constructor.IdEndpointName };

        this.fakes.stub(this.giphy, 'getIdUri');
        this.giphy.getUri(state);
        this.giphy.getIdUri.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.getIdUri.should.have.been.calledWith(state);
      });

      it('handles a translate endpoint', () => {
        const state = { endpoint: this.giphy.constructor.TranslateEndpointName };

        this.fakes.stub(this.giphy, 'getTranslateUri');
        this.giphy.getUri(state);
        this.giphy.getTranslateUri.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.getTranslateUri.should.have.been.calledWith(state);
      });

      it('handles a random endpoint', () => {
        const state = { endpoint: this.giphy.constructor.RandomEndpointName };

        this.fakes.stub(this.giphy, 'getRandomUri');
        this.giphy.getUri(state);
        this.giphy.getRandomUri.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.getRandomUri.should.have.been.calledWith(state);
      });

      it('handles a trending endpoint', () => {
        const state = { endpoint: this.giphy.constructor.TrendingEndpointName };

        this.fakes.stub(this.giphy, 'getTrendingUri');
        this.giphy.getUri(state);
        this.giphy.getTrendingUri.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.getTrendingUri.should.have.been.calledWith(state);
      });

      return it('handles help', () => {
        const state = { endpoint: this.giphy.constructor.HelpName };

        this.fakes.stub(this.giphy, 'getHelp');
        this.giphy.getUri(state);
        this.giphy.getHelp.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.getHelp.should.have.been.calledWith(state);
      });
    });

    describe('.handleResponse', () => {
      it('sends a response when there is no error', () => {
        const state = { };
        const uriCreator = this.fakes.stub().returns(sampleUri);

        this.fakes.stub(this.giphy, 'sendResponse');
        this.giphy.handleResponse(state, null, uriCreator);
        uriCreator.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        this.giphy.sendResponse.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        this.giphy.sendResponse.should.have.been.calledWith({ uri: sampleUri });
        should.exist(state.uri);
        return state.uri.should.eql(sampleUri);
      });

      return it('sends an error when the state is missing a valid uri', () => {
        const state = { msg: this.msg };
        const uriCreator = this.fakes.stub().returns(sampleUri);

        this.fakes.stub(this.giphy, 'error');
        this.giphy.handleResponse(state, 'error', uriCreator);
        uriCreator.should.not.have.been.called; // eslint-disable-line no-unused-expressions
        this.giphy.error.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        this.giphy.error.should.have.been.calledWith(state.msg, 'giphy-api Error: error');
        return should.not.exist(state.uri);
      });
    });

    describe('.sendResponse', () => {
      beforeEach(() => {
        this.fakes.stub(this.giphy, 'sendMessage');
        return this.fakes.stub(this.giphy, 'error');
      });

      it('handles state with a uri', () => {
        this.giphy.sendResponse({ msg: 'msg', uri: 'uri' });
        this.giphy.sendMessage.should.be.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.sendMessage.should.be.calledWith('msg', 'uri');
      });

      it('sends an inline image response when HUBOT_GIPHY_INLINE_IMAGES is set', () => {
        process.env.HUBOT_GIPHY_INLINE_IMAGES = true;
        this.giphy.sendResponse({ msg: 'msg', uri: 'uri' });
        this.giphy.sendMessage.should.be.called.once; // eslint-disable-line no-unused-expressions
        return this.giphy.sendMessage.should.be.calledWith('msg', '![giphy](uri)');
      });

      return it('handles state without a uri', () => {
        this.giphy.sendResponse({ });
        return this.giphy.error.should.be.called.once;
      });
    });

    describe('.sendMessage', () => {
      it('sends a message when msg and message are valid', () => {
        const msg = { send: this.fakes.stub() };

        this.giphy.sendMessage(msg, 'testing');
        msg.send.should.be.called.once; // eslint-disable-line no-unused-expressions
        return msg.send.should.be.calledWith('testing');
      });

      return it('ignores calls when msg or message is null', () => {
        const msg = { send: this.fakes.stub() };

        this.giphy.sendMessage();
        this.giphy.sendMessage(msg);
        this.giphy.sendMessage(msg, null);
        this.giphy.sendMessage(undefined, 'testing');
        this.giphy.sendMessage(null, 'testing');
        return msg.send.should.not.have.been.called;
      });
    });

    return describe('.respond', () => {
      beforeEach(() => {
        this.fakes.stub(this.giphy, 'getEndpoint');
        this.fakes.stub(this.giphy, 'getOptions');
        this.fakes.stub(this.giphy, 'getUri');
        return this.fakes.stub(this.giphy, 'error');
      });

      it('handles non-empty matched args', () => {
        const msg = { match: [ null, 'testing' ] };
        const state = 'state';

        this.fakes.stub(this.giphy, 'createState', () => state);
        this.giphy.respond(msg);
        this.giphy.createState.should.have.been.calledWith(msg);
        this.giphy.getEndpoint.should.have.been.calledWith(state);
        this.giphy.getOptions.should.have.been.calledWith(state);
        return this.giphy.getUri.should.have.been.calledWith(state);
      });

      it('handles empty matched args', () => {
        const msg = { match: [ null, '' ] };
        const state = 'state';

        this.fakes.stub(this.giphy, 'createState', () => state);
        this.giphy.respond(msg);
        this.giphy.createState.should.have.been.calledWith(msg);
        this.giphy.getEndpoint.should.have.been.calledWith(state);
        this.giphy.getOptions.should.have.been.calledWith(state);
        return this.giphy.getUri.should.have.been.calledWith(state);
      });

      it('handles null msg', () => {
        this.giphy.respond();
        this.giphy.respond(null);
        this.giphy.getUri.should.not.have.been.called; // eslint-disable-line no-unused-expressions
        return this.giphy.error.should.have.been.called.twice;
      });

      return it('handles missing giphy command args', () => {
        this.giphy.respond({ });
        this.giphy.respond({ match: null });
        this.giphy.respond({ match: [] });
        this.giphy.respond({ match: [ null ] });
        this.giphy.getUri.should.not.have.been.called; // eslint-disable-line no-unused-expressions
        return this.giphy.error.should.have.callCount(4);
      });
    });
  });

  return describe('plugin api integration', () => {
    const { PassThrough } = require('stream') // eslint-disable-line global-require
      ;
    let giphyPluginInstance = null;
    let regex = null;
    let callback = null;
    let msg = null;

    function validate(done, options) {
      if (typeof options === 'function') {
        options();
      } else {
        giphyPluginInstance.api._request.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        // eslint-disable-next-line no-unused-expressions
        giphyPluginInstance.api.httpService.get.should.have.been.called.once;
        giphyPluginInstance.api._request.should.be.calledWith(sinon.match(options));
        msg.send.should.have.been.called.once; // eslint-disable-line no-unused-expressions
        msg.send.should.have.been.calledWith(sampleUri);
      }
      return done();
    }

    function testInput(done, fakes, input, result, options) {
      // create fake request and response objects
      const req = new PassThrough();
      const res = new PassThrough();

      // preload the response with the provided result
      res.write(JSON.stringify(result));
      res.end();

      // spy on the _request so we can test the options passed in
      fakes.spy(giphyPluginInstance.api, '_request');
      // stub the http.get so we don't send out any network calls
      fakes
        .stub(giphyPluginInstance.api.httpService, 'get', (requestOptions, callbackFunction) => {
          callbackFunction(res);
          res.on('end', () => validate(done, options));
          return req;
        });

      // prepare the match data and call the plugin callback
      msg.match = regex.exec(input);
      callback(msg); // eslint-disable-line callback-return

      if (typeof options === 'function') {
        options();
        return done();
      }
      // we use .callCount 0 here because the error shows us what the call args were
      return msg.send.should.have.callCount(0);
    }

    beforeEach(() => {
      const robot = { name: 'robot', respond: this.fakes.spy() };

      msg = { send: this.fakes.spy() };
      giphyPluginInstance = hubotGiphy(robot);
      [ regex, callback ] = Array.from(robot.respond.lastCall.args);
      return [ regex, callback ];
    });

    it('sends a response for "giphy search"', (done) => {
      testInput(done, this.fakes, 'giphy search', sampleRandomResult,
       { api: 'gifs', endpoint: 'random', query: { } });
    });

    it('sends a response for "giphy search test"', (done) => {
      testInput(done, this.fakes, 'giphy search test', sampleCollectionResult,
       { api: 'gifs', endpoint: 'search', query: { q: 'test' } });
    });

    it('sends a response for "giphy search test1 test2"', (done) => {
      testInput(done, this.fakes, 'giphy search test1 test2', sampleCollectionResult,
       { api: 'gifs', endpoint: 'search', query: { q: 'test1 test2' } });
    });

    it('sends a response for "giphy id"', (done) => {
      testInput(done, this.fakes, 'giphy id', null,
       () => msg.send.should.have.been.calledWith('No Id Provided'));
    });

    it('sends a response for "giphy id test"', (done) => {
      testInput(done, this.fakes, 'giphy id test', sampleCollectionResult,
       { api: 'gifs', query: { ids: 'test' } });
    });

    it('sends a response for "giphy id test1 test2"', (done) => {
      testInput(done, this.fakes, 'giphy id test1 test2', sampleCollectionResult,
       { api: 'gifs', query: { ids: 'test1,test2' } });
    });

    it('sends a response for "giphy translate"', (done) => {
      testInput(done, this.fakes, 'giphy translate', sampleResult,
       { api: 'gifs', endpoint: 'translate', query: { } });
    });

    it('sends a response for "giphy translate test"', (done) => {
      testInput(done, this.fakes, 'giphy translate test', sampleResult,
       { api: 'gifs', endpoint: 'translate', query: { s: 'test' } });
    });

    it('sends a response for "giphy translate test1 test2"', (done) => {
      testInput(done, this.fakes, 'giphy translate test1 test2', sampleResult,
       { api: 'gifs', endpoint: 'translate', query: { s: 'test1 test2' } });
    });

    it('sends a response for "giphy random"', (done) => {
      testInput(done, this.fakes, 'giphy random', sampleRandomResult,
       { api: 'gifs', endpoint: 'random', query: { } });
    });

    it('sends a response for "giphy random test"', (done) => {
      testInput(done, this.fakes, 'giphy random test', sampleRandomResult,
       { api: 'gifs', endpoint: 'random', query: { tag: 'test' } });
    });

    it('sends a response for "giphy random test1 test2"', (done) => {
      testInput(done, this.fakes, 'giphy random test1 test2', sampleRandomResult,
       { api: 'gifs', endpoint: 'random', query: { tag: 'test1 test2' } });
    });

    it('sends a response for "giphy trending"', (done) => {
      testInput(done, this.fakes, 'giphy trending', sampleCollectionResult,
       { api: 'gifs', endpoint: 'trending' });
    });

    it('sends a response for "giphy trending test"', (done) => {
      testInput(done, this.fakes, 'giphy trending test', sampleCollectionResult,
       { api: 'gifs', endpoint: 'trending' });
    });

    it('sends a response for "giphy trending test1 test2"', (done) => {
      testInput(done, this.fakes, 'giphy trending test1 test2', sampleCollectionResult,
       { api: 'gifs', endpoint: 'trending' });
    });

    it('sends a response for "giphy"', (done) => {
      testInput(done, this.fakes, 'giphy', sampleRandomResult,
       { api: 'gifs', endpoint: 'random', query: { } });
    });

    it('sends a response for "giphy test"', (done) => {
      testInput(done, this.fakes, 'giphy test', sampleCollectionResult,
       { api: 'gifs', endpoint: 'search', query: { q: 'test' } });
    });

    it('sends a response for "giphy test1 test2"', (done) => {
      testInput(done, this.fakes, 'giphy test1 test2', sampleCollectionResult,
       { api: 'gifs', endpoint: 'search', query: { q: 'test1 test2' } });
    });

    it('sends a response for "giphy search /api:stickers test"', (done) => {
      testInput(done, this.fakes, 'giphy search /api:stickers test', sampleCollectionResult,
       { api: 'stickers', endpoint: 'search', query: { api: 'stickers', q: 'test' } });
    });

    it('sends a response for "giphy search /rating:pg test"', (done) => {
      testInput(done, this.fakes, 'giphy search /rating:pg test', sampleCollectionResult,
       { api: 'gifs', endpoint: 'search', query: { rating: 'pg', q: 'test' } });
    });

    it('sends a response for "giphy search /limit:123 test"', (done) => {
      testInput(done, this.fakes, 'giphy search /limit:123 test', sampleCollectionResult,
       { api: 'gifs', endpoint: 'search', query: { limit: '123', q: 'test' } });
    });

    it('sends a response for "giphy search /limit:123 /offset:25 test"', (done) => {
      testInput(done, this.fakes, 'giphy search /limit:123 /offset:25 test', sampleCollectionResult,
       { api: 'gifs', endpoint: 'search', query: { limit: '123', offset: '25', q: 'test' } });
    });

    return it('sends help text for "giphy help"', (done) => {
      testInput(done, this.fakes, 'giphy help', null, () => {
        msg.send.should.have.been.called; // eslint-disable-line no-unused-expressions
      });
    });
  });
});
