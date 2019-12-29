/* eslint-disable */
const path = require('path');
const webpack = require('webpack');
const phaser = path.join(__dirname, '/node_modules/phaser/src/phaser.js');
const { CleanWebpackPlugin } = require('clean-webpack-plugin');
const TsconfigPathsPlugin = require('tsconfig-paths-webpack-plugin');
const WebpackBar = require('webpackbar');
/* eslint-enable */

module.exports = env => {
  return {
    target: 'electron-renderer',
    mode: env.production ? 'production' : 'development',
    watch: env.development,
    entry: {
      renderer: path.resolve(__dirname, 'src/renderer/index.ts'),
    },
    output: {
      pathinfo: true,
      filename: 'renderer.js',
      publicPath: '/',
      path: path.resolve(__dirname, 'dist', 'renderer'),
    },
    devtool: 'source-map',
    stats: 'errors-only',
    performance: { hints: false },
    plugins: [
      new CleanWebpackPlugin(),
      new WebpackBar(),
      new webpack.DllReferencePlugin({
        context: __dirname,
        manifest: require(`./dist/dlls/library.json`),
      }),
      new webpack.WatchIgnorePlugin([/dist/, /node_modules/, /src\/main/]),
      new webpack.DefinePlugin({
        WEBGL_RENDERER: true,
        CANVAS_RENDERER: true,
      }),
    ],
    resolve: {
      plugins: [
        new TsconfigPathsPlugin({
          logInfoToStdOut: true,
          extensions: ['.ts', '.js'],
          baseUrl: 'src/renderer',
        }),
      ],
      extensions: ['.ts', '.js'],
      alias: {
        phaser: path.resolve(__dirname, './lib/phaser.custom.js'),
      },
    },
    module: {
      rules: [
        {
          test: /\.ts$/,
          loader: 'ts-loader',
          options: {
            compilerOptions: {
              baseUrl: 'src/renderer',
            },
          },
        },
        {
          test: [/\.vert$/, /\.frag$/],
          loader: 'raw-loader',
        },
        {
          test: /\.(gif|png|jpe?g|svg|xml)$/i,
          use: 'file-loader',
        },
      ],
    },
    node: {
      __dirname: true,
    },
  };
};
