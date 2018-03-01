module.exports = {
  extends: 'eslint:recommended',
  rules: {
    "no-console": "off",
    "no-unused-vars": "off"
  },
  parser: 'babel-eslint',
  parserOptions: {
    sourceType: 'module'
  },
  env: {
    browser: true,
    node: true
  },
  globals: {
    __static: true
  }
}