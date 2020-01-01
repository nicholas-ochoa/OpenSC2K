/* eslint-disable */
const path = require('path');
const webpack = require('webpack');
const { CleanWebpackPlugin } = require('clean-webpack-plugin');
const TsconfigPathsPlugin = require('tsconfig-paths-webpack-plugin');
const NodemonPlugin = require('nodemon-webpack-plugin');
const WebpackBar = require('webpackbar');
/* eslint-enable */

module.exports = env => {
  return {
    target: 'electron-main',
    mode: env.production ? 'production' : 'development',
    watch: env.development,
    entry: {
      main: path.resolve(__dirname, 'src/main/index.ts'),
    },
    output: {
      pathinfo: true,
      filename: 'main.js',
      path: path.resolve(__dirname, 'dist', 'main'),
    },
    optimization: {
      nodeEnv: false,
    },
    devtool: 'source-map',
    stats: 'errors-only',
    performance: { hints: false },
    plugins: [
      new CleanWebpackPlugin(),
      new WebpackBar(),
      new webpack.WatchIgnorePlugin([/dist/, /node_modules/]),
      new NodemonPlugin({
        nodeArgs: ['--inspect'],
        watch: ['./dist/main/'],
        verbose: false,
        exec: 'cross-env NODE_ENV=development run-electron . --inspect',
        ext: 'js,yaml',
        delay: 3,
      }),
    ],
    resolve: {
      plugins: [
        new TsconfigPathsPlugin({
          logInfoToStdOut: true,
          extensions: ['.ts', '.js'],
          baseUrl: 'src/main',
        }),
      ],
      extensions: ['.ts', '.js'],
    },
    module: {
      rules: [
        {
          test: /\.ts$/,
          loader: 'ts-loader',
          options: {
            compilerOptions: {
              baseUrl: 'src/main',
            },
          },
        },
      ],
    },
  };
};
