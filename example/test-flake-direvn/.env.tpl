# Secret REFERENCES only — safe to commit. Values live in 1Password.
# Dev-side analog of an ExternalSecret manifest: declare what this repo
# needs; `use_onepassword` (direnv, from home-manager) materializes env.
#
# NOTE: op inject templates COMMENTS too — never write a literal
# scheme-prefixed example here. Convention (scheme omitted on purpose):
#   dev/<repo-name>/<kebab-field>       per-project secret
#   dev/<repo-name>/<section>/<field>   optional grouping
#   dev/shared/<field>                  cross-project (registry creds…)
# dev is the LAPTOP vault. catalyst-eso is the cluster's — External Secrets
# Operator reads it via 1Password Connect, and nothing here should point at
# it: same pattern either side, separate vaults, so a local experiment can
# never reach into what the cluster is running on.

DEMO_SECRET="op://dev/test-flake-direvn/demo-secret"
DATABASE_URL="op://dev/test-flake-direvn/db/url"
