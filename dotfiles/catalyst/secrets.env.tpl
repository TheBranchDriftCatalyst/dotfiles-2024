# 1Password secret REFERENCES — never values (safe to commit). Rendered to
# ~/.catalyst/secrets.env (0600) by home.activation.catalystSecrets via
# `op inject` on every switch; the installed catalyst binary loads that file
# itself at startup (config.LoadEnvFile), so it authenticates from ANY cwd.
# NOTE: `op inject` parses the reference scheme anywhere in this file,
# comments included — keep it out of prose. Rotate values in 1Password:
# vault "dev", item "catalyst-cli".
JIRA_TOKEN=op://dev/catalyst-cli/jira-token
GH_TOKEN=op://dev/catalyst-cli/gh-token
TALOS_REGISTRY_TOKEN=op://dev/catalyst-cli/talos-registry-token
