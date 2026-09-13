# Secret REFERENCES only — safe to commit. Values live in 1Password.
# Dev-side analog of an ExternalSecret manifest: declare what this repo
# needs; `use_onepassword` (direnv, from home-manager) materializes env.
#
# NOTE: op inject templates COMMENTS too — never write a literal
# scheme-prefixed example here. Convention (scheme omitted on purpose):
#   catalyst-eso/<repo-name>/<kebab-field>       per-project secret
#   catalyst-eso/<repo-name>/<section>/<field>   optional grouping
#   catalyst-eso/shared/<field>                  cross-project (registry creds…)
# catalyst-eso is THE cluster ESO vault — laptop and cluster consume the
# same items. vault ≙ ClusterSecretStore · item ≙ ExternalSecret · field ≙ key

DEMO_SECRET="op://catalyst-eso/test-flake-direvn/demo-secret"
DATABASE_URL="op://catalyst-eso/test-flake-direvn/db/url"
