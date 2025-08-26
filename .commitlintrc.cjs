module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always', [
      'feat', 'fix', 'refactor', 'perf', 'test', 'docs',
      'chore', 'build', 'ci', 'style', 'revert'
    ]],
    'scope-enum': [2, 'always', [
      'auth','user','file','share','gateway','worker','frontend','web','ml','inference',
      'storage','db','search','analytics','billing','payments','notifications','admin',
      'security','api','contracts','perf','infra','deploy','charts','ci','repo','docs',
      'tooling','scripts',
      'go'
    ]],
    'scope-empty': [2, 'never'],
    'header-max-length': [2, 'always', 100],
    'subject-case': [0],
    'subject-empty': [2, 'never'],
    'type-empty': [2, 'never'],
    'footer-leading-blank': [1, 'always'],
    'body-leading-blank': [1, 'always'],
    'subject-full-stop': [2, 'never', '.']
  },
};
