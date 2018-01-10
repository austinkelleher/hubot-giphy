// Description
//   hubot interface for giphy-api (https://github.com/austinkelleher/giphy-api)
//
// Configuration:
//   HUBOT_GIPHY_API_KEY
//   HUBOT_GIPHY_HTTPS
//   HUBOT_GIPHY_TIMEOUT
//   HUBOT_GIPHY_DEFAULT_LIMIT     default: 5
//   HUBOT_GIPHY_DEFAULT_RATING
//   HUBOT_GIPHY_INLINE_IMAGES
//   HUBOT_GIPHY_MAX_SIZE
//   HUBOT_GIPHY_DEFAULT_ENDPOINT  default: search
//
// Commands:
//   hubot giphy [endpoint] [options...] something interesting - <requests an image relating to "something interesting">
//   hubot giphy help - show giphy plugin usage
//
// Notes:
//   HUBOT_GIPHY_API_KEY: get your api key @ http://api.giphy.com/
//   HUBOT_GIPHY_HTTPS: use https mode (boolean)
//   HUBOT_GIPHY_TIMEOUT: API request timeout (number, in seconds)
//   HUBOT_GIPHY_DEFAULT_LIMIT: max results returned for collection based requests (number)
//   HUBOT_GIPHY_RATING: result rating limitation (string, one of y, g, pg, pg-13, or r)
//   HUBOT_GIPHY_INLINE_IMAGES: images are inlined. i.e. ![giphy](uri) (boolean)
//   HUBOT_GIPHY_DEFAULT_ENDPOINT: endpoint used when none is specified (string)
//
// Author:
//   Pat Sissons[patricksissons@gmail.com]
/* eslint-disable consistent-return,no-undefined */
const giphyApi = require('giphy-api');

const { DEBUG } = process.env;

// utility method for extending an object definition
function extend(object, properties) {
  object = object || { };
  const anotherObject = properties || { };

  for (const key in anotherObject) {
    const val = anotherObject[key];

    if (val || (val === '')) {
      object[key] = val;
    }
  }
  return object;
}

// utility method for merging two objects
function merge(options, overrides) {
  return extend((extend({}, options)), overrides);
}

class Giphy {
  static initClass() {
    this.SearchEndpointName = 'search';
    this.IdEndpointName = 'id';
    this.TranslateEndpointName = 'translate';
    this.RandomEndpointName = 'random';
    this.TrendingEndpointName = 'trending';
    this.HelpName = 'help';

    this.endpoints = [
      Giphy.SearchEndpointName,
      Giphy.IdEndpointName,
      Giphy.TranslateEndpointName,
      Giphy.RandomEndpointName,
      Giphy.TrendingEndpointName,
    ];

    this.regex = new RegExp(`^\\s*(${ Giphy.endpoints.join('|') }|${ Giphy.HelpName })?\\s*(.*?)$`, 'i');
  }

  constructor(robot, api) {
    this.error = this.error.bind(this);
    this.getEndpoint = this.getEndpoint.bind(this);
    this.getNextOption = this.getNextOption.bind(this);
    this.getOptions = this.getOptions.bind(this);
    this.getUriFromResultData = this.getUriFromResultData.bind(this);
    this.getSearchUri = this.getSearchUri.bind(this);
    this.getIdUri = this.getIdUri.bind(this);
    this.getTranslateUri = this.getTranslateUri.bind(this);
    this.getRandomUri = this.getRandomUri.bind(this);
    this.getTrendingUri = this.getTrendingUri.bind(this);
    this.getHelp = this.getHelp.bind(this);
    this.getUri = this.getUri.bind(this);
    this.handleResponse = this.handleResponse.bind(this);
    this.sendResponse = this.sendResponse.bind(this);
    this.respond = this.respond.bind(this);
    if (!robot) {
      throw new Error('Robot is required');
    }
    if (!api) {
      throw new Error('Giphy API is required');
    }

    this.robot = robot;
    this.api = api;
    this.defaultLimit = process.env.HUBOT_GIPHY_DEFAULT_LIMIT || '5';
    this.defaultEndpoint = process.env.HUBOT_GIPHY_DEFAULT_ENDPOINT || Giphy.SearchEndpointName;

    const match = /(~?)(\d+)/.exec((process.env.HUBOT_GIPHY_MAX_SIZE || '0'));

    this.maxSize = match ? Number(match[2]) : 0;
    this.allowLargerThanMaxSize = (match && (match[1] === '~'));

    this.helpText = `\
${ this.robot.name } giphy [endpoint] [options...] [args]

endpoints: search, id, translate, random, trending
options: rating, limit, offset, api

default endpoint is '${ this.defaultEndpoint }' if none is specified
options can be specified using /option:value
rating can be one of y,g, pg, pg-13, or r

Example:
${ this.robot.name } giphy search /limit:100 /offset:50 /rating:pg something to search for\
`.trim();
  }

  log(...args) {
    /* istanbul ignore next */
    if (DEBUG) {
      const [ msg, state, ...argsCopy ] = args;
      const stateCopy = extend({}, state);

      Reflect.deleteProperty(stateCopy, 'msg');
      args.unshift(stateCopy);
      return Reflect.apply(console.log, this, [ msg, ...argsCopy ]); // eslint-disable-line no-console
    }
  }

  error(msg, reason) {
    return msg && reason && this.sendMessage(msg, reason);
  }

  createState(msg) {
    return msg && {
      msg,
      input: msg.match[1] || '',
      endpoint: undefined,
      args: undefined,
      options: undefined,
      uri: undefined,
    };
  }

  match(input) {
    return Giphy.regex.exec(input || '');
  }

  getEndpoint(state) {
    this.log('getEndpoint:', state);
    const match = this.match(state.input);

    if (match) {
      state.endpoint = match[1] || this.defaultEndpoint;
      state.args = match[2];
      return state.args;
    }
    state.endpoint = (state.args = '');
    return state.endpoint;
  }

  getNextOption(state) {
    this.log('getNextOption:', state);
    const regex = /\/(\w+):(\w*)/;
    let optionFound = false;

    state.args = state.args.replace(regex, (match, key, val) => {
      state.options[key] = val;
      optionFound = true;
      return '';
    });
    state.args = state.args.trim();
    return optionFound;
  }

  // rating, limit, offset, api
  getOptions(state) {
    this.log('getOptions:', state);
    state.options = {};
    return (() => {
      const result = [];

      while (this.getNextOption(state)) {
        result.push(null);
      }
      return result;
    })();
  }

  getRandomResultFromCollectionData(data, callback) {
    if (data && callback && (data.length > 0)) {
      return callback(data.length === 1 ? data[0] : data[Math.floor(Math.random() * data.length)]);
    }
  }

  getUriFromResultDataWithMaxSize(images, size, allowLargerThanMaxSize) {
    if (!size) {
      size = 0;
    }
    if (!allowLargerThanMaxSize) {
      allowLargerThanMaxSize = false;
    }
    if (images && (size > 0)) {
      const imagesBySize = Object
        .keys(images)
        .map((x) => images[x])
        .sort((a, b) => a.size - b.size); // eslint-disable-line id-length

      // for whatever reason istanbul is complaining about this missing else block
      /* istanbul ignore else */
      if (imagesBySize.length > 0) {
        let image = null;
        const allowedImages = imagesBySize
          .filter((x) => x.size <= size);

        if (allowedImages && (allowedImages.length > 0)) {
          image = allowedImages[allowedImages.length - 1];
        } else if (allowLargerThanMaxSize) {
          image = imagesBySize[0];
        }

        if (image && image.url) {
          return image.url;
        }
      }
    }
  }

  getUriFromResultData(data) {
    if (data && data.images) {
      if (this.maxSize > 0) {
        return this.getUriFromResultDataWithMaxSize(data.images, this.maxSize, this.allowLargerThanMaxSize);
      } else if (data.images.original) {
        return data.images.original.url;
      }
    }
  }

  getUriFromRandomResultData(data) {
    if (data) {
      return data.url;
    }
  }

  getSearchUri(state) {
    this.log('getSearchUri:', state);
    if (state.args && (state.args.length > 0)) {
      const options = merge({
        q: state.args,
        limit: this.defaultLimit,
        rating: process.env.HUBOT_GIPHY_DEFAULT_RATING,
      }, state.options);

      return this.api.search(options, (err, res) =>
          this.handleResponse(state, err, () =>
              this.getRandomResultFromCollectionData(res.data, this.getUriFromResultData)
          )
      );
    }
    return this.getRandomUri(state);
  }

  getIdUri(state) {
    this.log('getIdUri:', state);
    if (state.args && (state.args.length > 0)) {
      const ids = state.args
        .split(' ')
        .filter((x) => x.length > 0)
        .map((x) => x.trim());

      return this.api.id(ids, (err, res) =>
          this.handleResponse(state, err, () =>
              this.getRandomResultFromCollectionData(res.data, this.getUriFromResultData)
          )
      );
    }
    return this.error(state.msg, 'No Id Provided');
  }

  getTranslateUri(state) {
    this.log('getTranslateUri:', state);
    const options = merge({
      s: state.args,
      rating: process.env.HUBOT_GIPHY_DEFAULT_RATING,
    }, state.options);

    return this.api.translate(options, (err, res) =>
        this.handleResponse(state, err, () =>
            this.getUriFromResultData(res.data)
        )
    );
  }

  getRandomUri(state) {
    this.log('getRandomUri:', state);
    const options = merge({
      tag: state.args,
      rating: process.env.HUBOT_GIPHY_DEFAULT_RATING,
    }, state.options);

    return this.api.random(options, (err, res) =>
        this.handleResponse(state, err, () =>
            this.getUriFromRandomResultData(res.data)
        )
    );
  }

  getTrendingUri(state) {
    this.log('getTrendingUri:', state);
    const options = merge({
      limit: this.defaultLimit,
      rating: process.env.HUBOT_GIPHY_DEFAULT_RATING,
    }, state.options);

    return this.api.trending(options, (err, res) =>
        this.handleResponse(state, err, () =>
            this.getRandomResultFromCollectionData(res.data, this.getUriFromResultData)
        )
    );
  }

  getHelp(state) {
    this.log('getHelp:', state);
    return this.sendMessage(state.msg, this.helpText);
  }

  getUri(state) {
    this.log('getUri:', state);
    switch (state.endpoint) {
      case Giphy.SearchEndpointName: return this.getSearchUri(state);
      case Giphy.IdEndpointName: return this.getIdUri(state);
      case Giphy.TranslateEndpointName: return this.getTranslateUri(state);
      case Giphy.RandomEndpointName: return this.getRandomUri(state);
      case Giphy.TrendingEndpointName: return this.getTrendingUri(state);
      case Giphy.HelpName: return this.getHelp(state);
      default: return this.error(state.msg, `Unrecognized Endpoint: ${ state.endpoint }`);
    }
  }

  handleResponse(state, err, uriCreator) {
    this.log('handleResponse:', state);
    if (err) {
      return this.error(state.msg, `giphy-api Error: ${ err }`);
    }
    state.uri = Reflect.apply(uriCreator, this, []);
    return this.sendResponse(state);
  }

  sendResponse(state) {
    this.log('sendResponse:', state);
    if (state.uri) {
      const message = process.env.HUBOT_GIPHY_INLINE_IMAGES ? `![giphy](${ state.uri })` : state.uri;

      return this.sendMessage(state.msg, message);
    }
    return this.error(state.msg, 'No Results Found');
  }

  sendMessage(msg, message) {
    if (msg && message) {
      return msg.send(message);
    }
  }

  respond(msg) {
    // we must check the match.length >= 2 here because just checking the value
    // match[2] could give us a false negative since empty string resolves to false
    if (msg && msg.match && (msg.match.length >= 2)) {
      const state = this.createState(msg);

      this.getEndpoint(state);
      this.getOptions(state);

      return this.getUri(state);
    }
    return this.error(msg, 'I Didn\'t Understand Your Request');
  }
}
Giphy.initClass();

module.exports = function (robot) {
  const api = giphyApi({
    https: (process.env.HUBOT_GIPHY_HTTPS === 'true') || false,
    timeout: Number(process.env.HUBOT_GIPHY_TIMEOUT) || null,
    apiKey: process.env.HUBOT_GIPHY_API_KEY,
  });

  const giphy = new Giphy(robot, api);

  robot.respond(/giphy\s*(.*?)\s*$/, (msg) => giphy.respond(msg));

  // this allows testing to instrument the giphy instance
  /* istanbul ignore next */
  if (global && global.IS_TESTING) {
    return giphy;
  }
};

// this allows testing to instrument the giphy class
/* istanbul ignore next */
if (global && global.IS_TESTING) {
  module.exports.Giphy = Giphy;
  module.exports.extend = extend;
  module.exports.merge = merge;
}
