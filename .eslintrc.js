module.exports = {
  extends: [
    'eslint:recommended'
  ],
  "parserOptions": {
    "ecmaVersion": 6,
    "sourceType": 'module'
  },
  rules: {
    "no-console": 'off',
    "indent": ['error', 2],
    "quotes": ['error', 'single'],
    "semi": ['error', 'always'],
    "one-var": ['error', 'never']
  },
  parser: "babel-eslint",
  env: {
    browser: true,
    node: true,
    es6: true,
    commonjs: true,
    "shared-node-browser": true
  },
  globals: {
    __static: true
  }
}