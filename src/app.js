const express = require('express');
const path = require('path');
const cors = require('cors');
const morgan = require('morgan');
const helmet = require('helmet');

const routes = require('./routes');
const { errorHandler, notFound } = require('./middleware');

const app = express();

app.set('views', path.join(__dirname, '../templates'));
app.set('view engine', 'html');

app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, '../static')));
app.use('/client', express.static(path.join(__dirname, '../client/public')));

app.use('/api', routes);

app.use(notFound);
app.use(errorHandler);

module.exports = app;
