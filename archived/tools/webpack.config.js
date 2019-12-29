/* eslint-disable */
const path = require('path');
const webpack = require('webpack');
const phaser = path.join(__dirname, '/node_modules/phaser/src/phaser.js');
const { CleanWebpackPlugin } = require('clean-webpack-plugin');
const TsconfigPathsPlugin = require('tsconfig-paths-webpack-plugin');
const NodemonPlugin = require('nodemon-webpack-plugin');
const WebpackBar = require('webpackbar');
/* eslint-enable */

module.exports = env => {
  return {
    entry: './src/index.ts',
    target: 'node',
    watch: env.development,
    mode: env.production ? 'production' : 'development',
    output: {
      pathinfo: true,
      filename: 'tools.js',
      path: path.resolve(__dirname, '../dist'),
    },
    stats: 'errors-only',
    devtool: 'source-map',
    optimization: {
      nodeEnv: false,
    },
    plugins: [
      new CleanWebpackPlugin(),
      new webpack.DefinePlugin({
        WEBGL_RENDERER: true,
        CANVAS_RENDERER: true,
      }),
      new NodemonPlugin({
        nodeArgs: ['--inspect'],
        verbose: false,
        ext: 'js',
      }),
      new WebpackBar(),
      new webpack.BannerPlugin({ banner: '#!/usr/bin/env node', raw: true }),
    ],
    resolve: {
      plugins: [
        new TsconfigPathsPlugin({
          logInfoToStdOut: true,
          extensions: ['.ts', '.js'],
        }),
      ],
      extensions: ['.ts', '.js'],
      alias: {
        phaser: phaser,
      },
    },
    module: {
      rules: [
        {
          test: /\.ts$/,
          loader: 'ts-loader',
        },
      ],
    },
  };
};
