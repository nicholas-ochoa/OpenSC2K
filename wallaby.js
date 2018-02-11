process.env.NODE_ENV = `test`

module.exports = wallaby => ({
  files: [`src/**/*.js`, `!src/**/__TEST__/*.spec.js`],

  tests: [`src/**/__TEST__/*.spec.js`],

  testFramework: `ava`,

  env: {
    type: `node`,
    runner: `node`,
    params: {}
  },

  debug: true,

  setup: () => {
    require(`babel-register`)
    require(`babel-polyfill`)
    require(`isomorphic-fetch`)
  },

  compilers: {
    "src/**/*.js": wallaby.compilers.babel()
  }
})
