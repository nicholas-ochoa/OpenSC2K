module.exports = {
  parser: '@typescript-eslint/parser',
  extends: [
    'plugin:@typescript-eslint/recommended',
    //'prettier/@typescript-eslint',
    'plugin:json/recommended',
    //'plugin:prettier/recommended', // must be the last entry
  ],
  parserOptions: {
    ecmaVersion: 6,
    sourceType: 'module',
  },
  env: {
    browser: true,
    node: true,
  },
  globals: {
    __static: true,
  },
  plugins: ['json', 'html'],
  ignorePatterns: ['dist/*', 'node_modules/*'],
  rules: {
    'no-console': 'off',
    indent: ['error', 2, { SwitchCase: 1 }],
    quotes: ['error', 'single', { avoidEscape: true, allowTemplateLiterals: true }],
    semi: ['error', 'always'],
    'one-var': ['error', 'never'],
    'array-bracket-spacing': ['error', 'never', { singleValue: false }],
    'space-before-function-paren': ['error', { anonymous: 'ignore', named: 'ignore', asyncArrow: 'ignore' }],
    'linebreak-style': ['error', 'unix'],
    '@typescript-eslint/explicit-function-return-type': 'off',
    '@typescript-eslint/no-use-before-define': 'off',
    '@typescript-eslint/no-inferrable-types': 'off',
    '@typescript-eslint/no-explicit-any': 'off',
    '@typescript-eslint/no-implicit-any': 'off',
    '@typescript-eslint/class-name-casing': 'off',
    '@typescript-eslint/camelcase': 'off',
    '@typescript-eslint/no-unused-vars': ['error', { args: 'none' }],
  },
};
