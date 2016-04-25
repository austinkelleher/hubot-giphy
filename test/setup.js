var path = require('path');
var coffeeCoverage = require('coffee-coverage');

coffeeCoverage.register({
    instrumentor: 'istanbul',
    basePath: path.join(__dirname, '..', 'src'),
    _exclude: ['/test', '/node_modules', '/.git'],
    coverageVar: coffeeCoverage.findIstanbulVariable(),
    writeOnExit: false,
    initAll: false
});
