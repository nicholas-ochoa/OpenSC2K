/* eslint-disable */
const path = require('path');
const webpack = require('webpack');
const phaser = path.join(__dirname, '/node_modules/phaser/src/phaser.js');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const { CleanWebpackPlugin } = require('clean-webpack-plugin');
const TsconfigPathsPlugin = require('tsconfig-paths-webpack-plugin');
const WebpackBar = require('webpackbar');
/* eslint-enable */

module.exports = env => {
  return {
    mode: env.production ? 'production' : 'development',
    entry: {
      main: path.resolve(__dirname, 'src/index.ts'),
    },
    optimization: {
      splitChunks: {
        cacheGroups: {
          commons: {
            test: /[\\/]node_modules[\\/]/,
            name: 'vendors',
            chunks: 'all',
          },
        },
      },
    },
    watch: env.development,
    output: {
      pathinfo: true,
      filename: 'opensc2k.js',
      path: path.resolve(__dirname, 'dist'),
    },
    stats: 'errors-only',
    devtool: 'source-map',
    devServer: {
      contentBase: '../assets',
      port: 3000,
    },
    plugins: [
      new CleanWebpackPlugin(),
      new webpack.WatchIgnorePlugin([/dist/, /node_modules/]),
      new webpack.DefinePlugin({
        WEBGL_RENDERER: true,
        CANVAS_RENDERER: true,
      }),
      new HtmlWebpackPlugin({
        template: '../assets/html/index.html',
      }),
      //new WebpackBar(),
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
        {
          test: [/\.vert$/, /\.frag$/],
          loader: 'raw-loader',
        },
      ],
    },
  };
};
