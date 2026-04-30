'use strict';

const server = require('server');

server.get('Register', function (req, res, next) {
    res.render('account/register');
    next();
});

module.exports = server.exports();