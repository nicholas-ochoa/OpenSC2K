const { join, resolve } = require(`path`) // eslint-disable-line
const { DefinePlugin, /*ProvidePlugin,*/ LoaderOptionsPlugin, HotModuleReplacementPlugin, NamedModulesPlugin, NoEmitOnErrorsPlugin, IgnorePlugin, optimize } = require(`webpack`)
const ExtractTextPlugin = require(`extract-text-webpack-plugin`)
const HtmlWebpackPlugin = require(`html-webpack-plugin`)
const CopyWebpackPlugin = require(`copy-webpack-plugin`)
const LodashModuleReplacementPlugin = require(`lodash-webpack-plugin`) // https://github.com/lodash/lodash-webpack-plugin
const SWPrecacheWebpackPlugin = require(`sw-precache-webpack-plugin`)
const { BundleAnalyzerPlugin } = require(`webpack-bundle-analyzer`)
const MinifyPlugin = require(`babel-minify-webpack-plugin`)

const ENV = process.env.NODE_ENV && process.env.NODE_ENV.toLowerCase() || (process.env.NODE_ENV = `development`)
const envDev = ENV === `development`
const envProd = ENV === `production`
const envTest = ENV === `test`
const title = `OpenSC2K`
const baseURL = `/`
const host = process.env.HOST || `localhost`
const port = process.env.PORT || 9000
const rootDir = join(__dirname, ``)
const srcDir = join(__dirname, `src`)
const outDir = join(__dirname, `dist`)
const npmDir = join(__dirname, `node_modules`)

const isVendor = ({ resource }) => resource && resource.indexOf(npmDir) !== -1

const appCSS = new ExtractTextPlugin({
  filename: `[name]_[chunkhash].css`,
  allChunks: true
})

const vendorCSS = new ExtractTextPlugin({
  filename: `vendor_[chunkhash].css`,
  allChunks: true
})

module.exports = {
  context: rootDir,
  entry: {
    vendor: [
      `bootstrap/scss/bootstrap-reboot.scss`,
      `history`,
      `prop-types`,
      `preact`,
      `preact-compat`,
      `react-apollo`,
      `react-redux`,
      `react-router`,
      `react-router-dom`,
      `react-router-redux`,
      `redux`,
      `redux-logger`
    ],
    polyfills: [
      `babel-polyfill`,
      `whatwg-fetch`
    ],
    app: [
      ...(envDev
        ? [
          //`react-hot-loader/patch`,
          `webpack-dev-server/client?http://${host}:${port + 100}/`,
          `webpack/hot/only-dev-server`
        ]
        : []),
      `./src/app.js`
    ]
  },
  output: {
    path: outDir,
    publicPath: `/`,
    filename: envProd ? `[name].[chunkhash].bundle.js` : `[name].bundle.js`,
    sourceMapFilename: envProd ? `[name].[chunkhash].bundle.map` : `[name].bundle.map`,
    chunkFilename: envProd ? `[id].[chunkhash].chunk.js` : `[id].chunk.js`
  },
  stats: {
    colors: true,
    reasons: false,
    chunks: false
  },
  performance: {
    hints: false
  },
  resolve: {
    extensions: [`.js`, `.jsx`, `.json`, `.scss`, `.sass`, `.css`],
    alias: {
      // Application Aliases
      '@': srcDir,
      '@components': join(srcDir, `app/components`),
      '@routes': join(srcDir, `app/routes`),
      '@services': join(srcDir, `app/services`),
      // Module Aliases
      'react': `preact-compat/dist/preact-compat`,
      'react-dom': `preact-compat/dist/preact-compat`,
      'create-react-class': `preact-compat/lib/create-react-class`
    },
    modules: [
      srcDir,
      npmDir
    ]
  },
  module: {
    rules: [
      { test: /\.(css|s[ac]ss)$/, include: srcDir, use: appCSS.extract({ //eslint-disable-line
        fallback: `style-loader`, use: [ //eslint-disable-line
          { loader: `css-loader`, options: { //eslint-disable-line
            context: rootDir,
            modules: true,
            sourceMap: envDev,
            localIdentName: `[local]_[hash:base64:5]`,
            importLoaders: 3
          } },
          { loader: `postcss-loader`, options: { sourceMap: envDev } },
          { loader: `resolve-url-loader`, options: { sourceMap: envDev } },
          { loader: `sass-loader`, options: { sourceMap: true, precision: 8 } }
        ]
      }) },
      { test: /\.(css|s[ac]ss)$/, exclude: srcDir,  use: vendorCSS.extract({ //eslint-disable-line
        fallback: `style-loader`, use: [ //eslint-disable-line
          { loader: `css-loader`, options: { //eslint-disable-line
            modules: false,
            sourceMap: envDev,
            importLoaders: 3
          } },
          { loader: `postcss-loader`, options: { sourceMap: envDev } },
          { loader: `resolve-url-loader`, options: { sourceMap: envDev } },
          { loader: `sass-loader`, options: { sourceMap: true, precision: 8 } }
        ]
      }) },
      { test: /\.jsx?$/, exclude: npmDir, loader: `babel-loader`, options: { //eslint-disable-line
        "extends": join(rootDir, `.babelrc`),
        "plugins": [
          [`react-css-modules`, {  //eslint-disable-line
            context: rootDir,
            exclude: `node_modules`,
            filetypes: { ".scss": { syntax: `postcss-scss` } },
            generateScopedName: `[local]_[hash:base64:5]`,
            webpackHotModuleReloading: envDev
          }]  //eslint-disable-line
        ]
      } },
      { test: /\.json$/, loader: `json-loader` },
      { test: /\.(graphql|gql)$/, exclude: npmDir, loader: `graphql-tag/loader` },
      { test: /\.(mp4|mov|ogg|webm)(\?.*)?$/i, loader: `url-loader` },
      { test: /\.(png|gif|jpg|cur)$/, loader: `url-loader`, query: { limit: 8192 } },
      { test: /\.woff2(\?v=[0-9]\.[0-9]\.[0-9])?$/, loader: `url-loader`, query: { limit: 10000, mimetype: `application/font-woff2` } },
      { test: /\.woff(\?v=[0-9]\.[0-9]\.[0-9])?$/, loader: `url-loader`, query: { limit: 10000, mimetype: `application/font-woff` } },
      { test: /\.(ttf|eot|svg|otf)(\?v=[0-9]\.[0-9]\.[0-9])?$/, exclude: /\.component\.svg$/, loader: `file-loader` },
      { test: /\.component\.svg$/, loader: `svg-react-loader`, query: { classIdPrefix: `[local]_[hash:base64:5]` } },
      { test: /\src\/images$/, loader: `ignore-loader` }
    ]
  },
  devServer: {
    historyApiFallback: true,
    hot: envDev,
    port: port + 100,
    host,
    compress: true,
    inline: true,
    watchContentBase: true,
    watchOptions: {
      aggregateTimeout: 300,
      poll: 1000
    },
    stats: {
      colors: true,
      chunks: false
    }
  },
  devtool: envTest ? `inline-source-map` : `hidden-source-map`,
  plugins: [
    new HtmlWebpackPlugin({
      template: `./public/index.ejs`,
      title,
      baseURL,
      serviceWorker: envProd ? `/service-worker.js` : null,
      inject: false,
      chunksSortMode: `dependency`,
      minify: envProd ? { removeComments: true, collapseWhitespace: true } : undefined // eslint-disable-line
    }),
    ...(envProd
      ? [
        new SWPrecacheWebpackPlugin({
          minify: true,
          filepath: `${outDir}/sw.js`,
          dontCacheBustUrlsMatching: /./,
          navigateFallback: `index.html`,
          staticFileGlobsIgnorePatterns: [
            /polyfills(\..*)?\.js$/,
            /\.map$/,
            /asset-manifest\.json$/
          ]
        }),
        new LoaderOptionsPlugin({
          options: { htmlLoader: {
            minimize: true,
            removeAttributeQuotes: false,
            caseSensitive: true
          } }
        })
      ]
      : []),
    new CopyWebpackPlugin([
      { from: `_redirects` },
      //{ from: `favicon.ico`, to: `favicon.ico` },
      { context: `src/img`, from: `**/*`, to: `img` }
    ]),
    new DefinePlugin({
      '__DEV__': !envProd,
      'ENV': JSON.stringify(ENV),
      'HMR': envDev,
      'process.env': {
        ENV: JSON.stringify(ENV),
        NODE_ENV: JSON.stringify(ENV),
        HMR: envDev,
        ...(envProd ? {} : { WEBPACK_HOST: JSON.stringify(host), WEBPACK_PORT: JSON.stringify(port) })
      }
    }),
    new LodashModuleReplacementPlugin(),
    new IgnorePlugin(/^\.\/locale$/, /moment$/),
    appCSS,
    vendorCSS,
    new optimize.ModuleConcatenationPlugin(),
    new optimize.CommonsChunkPlugin({
      name: `polyfills`,
      chunks: [`polyfills`],
      minChunks: isVendor
    }),
    new optimize.CommonsChunkPlugin({
      name: `vendor`,
      chunks: [`app`, `vendor`],
      minChunks: isVendor
    }),
    ...(envDev
      ? [
        new HotModuleReplacementPlugin(),
        new NamedModulesPlugin(),
        new NoEmitOnErrorsPlugin()
      ]
      : []),
    ...(envProd
      ? [
        new MinifyPlugin({
          keepFnName: envDev,
          keepClassName: envDev,
          booleans: envProd,
          deadcode: true,
          evaluate: envProd,
          flipComparisons: envProd,
          mangle: envProd,
          memberExpressions: envProd,
          mergeVars: envProd,
          numericLiterals: envProd,
          propertyLiterals: envProd,
          removeConsole: envProd,
          removeDebugger: envProd,
          simplify: envProd,
          simplifyComparisons: envProd,
          typeConstructors: envProd,
          undefinedToVoid: envProd
        })
      ]
      : []),
    ...(envDev
      ? [
        new BundleAnalyzerPlugin({
          analyzerMode: `server`,
          analyzerPort: 8888,
          defaultSizes: `parsed`,
          openAnalyzer: false
        })
      ]
      : [])
  ].filter(nonNull => nonNull)
}
