Random Operator Notes for AI Shortly

- Need to add brew postico
- need to add the only desktop widgets are
  - reminders, notes and fantastical calendar
  - ideally pull them from the current ones i have on my desktop

## Handoff: Hermes Agent + ollama (2026-10-09)

Added the `hermes-agent` flake (github:NousResearch/hermes-agent) and its
`homeManagerModules.default`, wired into both darwin hosts (teakbookM5DJ/dj,
catalystM5/panda). New `home/hermes.nix` (imported from `home/darwin.nix` —
darwin-only, since the module isn't in the Linux `homeConfigurations`):
`programs.hermes-agent.enable` puts `hermes` on PATH; `services.hermes-agent.enable`
makes activation render `config.yaml`/`.env`, but `gateway.enable`/`backend.mode`
are left at their upstream off/"none" defaults — so no launchd daemon.

Why no zshrc edit: the module exports `HERMES_HOME` via `home.sessionVariables`,
which home-manager's zsh integration already sources — unlike hermes' own
installer script, which tries to append to `~/.zshrc` and fails there because
it's a read-only nix-store symlink. Don't use that installer; this module is
the whole fix.

**Still stubbed in `home/hermes.nix` — fill these in, then `just switch`:**
- `model.default` — the real model name pulled on the MacBook Pro's ollama
- `model.base_url` — the real ollama endpoint (host:port, maybe a tailnet name)
- `secrets.onepassword.env.OPENAI_API_KEY` — the real `op://vault/item/field`
  reference (1Password is this repo's secrets trust root, see `home/kube.nix`'s
  header for why there's no sops-nix here)

Verified `nix eval .#darwinConfigurations.teakbookM5DJ.config.home-manager.users.dj.services.hermes-agent.settings`
evaluates cleanly — confirms the wiring. NOT yet run on either host:
`darwin-rebuild switch` / `just switch`. Do that after the CHANGEME values
are in.

No `inputs.nixpkgs.follows` on the `hermes-agent` input on purpose — it
builds its Python deps via uv2nix/pyproject-nix against its own pinned
nixpkgs-unstable, and forcing a follow risks a lockfile mismatch.
