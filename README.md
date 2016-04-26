[![Build Status](https://img.shields.io/travis/patsissons/hubot-giphy.svg?branch=develop)](https://travis-ci.org/patsissons/hubot-giphy)
[![Coverage Status](https://img.shields.io/coveralls/patsissons/hubot-giphy/develop.svg)](https://coveralls.io/github/patsissons/hubot-giphy?branch=develop)
[![npm Version](https://img.shields.io/npm/v/hubot-giphy.svg)](https://www.npmjs.com/package/hubot-giphy)
[![npm Downloads](https://img.shields.io/npm/dt/hubot-giphy.svg)](https://www.npmjs.com/package/hubot-giphy)
[![npm License](https://img.shields.io/npm/l/hubot-giphy.svg)](https://www.npmjs.com/package/hubot-giphy)
[![Dependency Status](https://img.shields.io/versioneye/d/nodejs/hubot-giphy.svg)](https://www.versioneye.com/nodejs/hubot-giphy)
[![eslint-strict-style](https://img.shields.io/badge/code%20style-strict-117D6B.svg)](https://github.com/keithamus/eslint-config-strict)

# hubot-giphy

hubot interface for [giphy-api](https://github.com/austinkelleher/giphy-api)

See [`src/giphy.coffee`](src/giphy.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install hubot-giphy --save`

Then add **hubot-giphy** to your `external-scripts.json`:

```json
[
  "hubot-giphy"
]
```

## Sample Interaction

```
user1>> hubot giphy something interesting
hubot>> <random image uri relating to 'something interesting'>
```
