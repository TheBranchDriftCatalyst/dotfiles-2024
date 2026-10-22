# Secret REFERENCES only — safe to commit. The template-file half of the
# 1Password direnv pattern: `use_onepassword_tpl` renders this whole template
# to a gitignored .npmrc (0600) on direnv entry, because npm/pnpm/yarn read a
# registry token from a config file and will not take it from the env.
#
# NOTE: op inject templates COMMENTS too — never write a literal
# scheme-prefixed example here. Same vault conventions as .env.tpl:
#   dev/<repo-name>/<kebab-field>
#   dev/shared/<field>                  cross-project (registry creds…)

@catalyst:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=op://dev/shared/npm-registry-token
