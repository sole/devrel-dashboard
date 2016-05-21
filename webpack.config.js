const path = require('path');
const webpack = require('webpack');

const config = {
  entry: [
    path.join(__dirname, 'src/index.js')
  ],

  output: {
    path: path.resolve(__dirname, 'dist/'),
    publicPath: 'dist/',
    filename: 'bundle.js'
  },

  resolve: {
    moduleDirectories: ['node_modules'],
    extensions: ['', '.js', '.elm']
  },

  module: {
    loaders: [
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        loader: 'elm-hot!elm-webpack?warn=true'
      }
    ]
  },
}

if (process.env.NODE_ENV === 'production') {
  config.plugins = (config.plugins || []).concat(
    new webpack.optimize.UglifyJsPlugin({ compress: { warnings: false } }),
    new webpack.LoaderOptionsPlugin({ minimize: true })
  );
}

module.exports = config;
