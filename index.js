/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const fs = require('fs'); // eslint-disable-line id-length
const path = require('path');

module.exports = function (robot, scripts) {
  const scriptsPath = path.resolve(__dirname, 'src');

  return fs.exists(scriptsPath, (exists) => { // eslint-disable-line consistent-return
    if (exists) {
      return (() => {
        const result = [];

        for (const script of Array.from(fs.readdirSync(scriptsPath))) { // eslint-disable-line no-sync
          if ((scripts !== null) && !Array.from(scripts).includes('*')) {
            if (Array.from(scripts).includes(script)) {
              result.push(robot.loadFile(scriptsPath, script));
            }
          } else {
            result.push(robot.loadFile(scriptsPath, script));
          }
        }
        return result;
      })();
    }
  });
};
