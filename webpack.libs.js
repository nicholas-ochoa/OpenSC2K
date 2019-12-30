/* eslint-disable */
const path = require('path');
const TerserPlugin = require('terser-webpack-plugin');
const webpack = require('webpack');
const { CleanWebpackPlugin } = require('clean-webpack-plugin');
const WebpackBar = require('webpackbar');
/* eslint-enable */

module.exports = env => {
  return {
    mode: env.production ? 'production' : 'development',
    context: process.cwd(),
    resolve: {
      alias: {
        phaser: path.resolve(__dirname, './node_modules/phaser/src'),
      },
      extensions: ['.js', '.jsx', '.json', '.less', '.css'],
      modules: [path.resolve(__dirname, 'lib'), 'node_modules'],
    },
    entry: {
      library: ['phaser.custom'],
    },
    output: {
      path: path.resolve(__dirname, './dist/dlls'),
      filename: `[name].dll.js`,
      library: '[name]',
    },
    devtool: 'source-map',
    stats: 'errors-only',
    performance: { hints: false },
    plugins: [
      new CleanWebpackPlugin(),
      new WebpackBar(),
      new webpack.DllPlugin({
        name: '[name]',
        path: `./dist/dlls/[name].json`,
      }),
      new webpack.DefinePlugin({
        'process.env': {
          NODE_ENV: JSON.stringify(process.env.NODE_ENV),
        },
        CANVAS_RENDERER: JSON.stringify(true),
        WEBGL_RENDERER: JSON.stringify(true),
      }),
    ],
  };
};
