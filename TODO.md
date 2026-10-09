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

**Stubs filled in (2026-10-09), still needs `just switch` on each host:**

- `model.default` = `hf.co/NousResearch/Hermes-4.3-36B-GGUF:Q5_K_M` — the
  Hermes weights, already pulled on catalystM5. Bare ollama tag, NOT prefixed
  `ollama/`: the id already contains slashes and `model.provider` states the
  provider, so the bare name is what has to reach ollama to match a tag.
- `model.base_url` — now PER-HOST via the new `catalyst.hermes.ollamaUrl`
  option, same pattern as `catalyst.wakatime.machineName`. catalystM5 hosts
  the models and uses loopback; teakbookM5DJ crosses the LAN to
  `http://catalystM5.local:11434/v1`. mDNS name, not an IP — both Macs roam
  and a DHCP lease is not an address. ollama already listens on `*:11434`,
  so nothing had to be exposed.
- `secrets.onepassword.env.OPENAI_API_KEY` — REMOVED rather than filled.
  That key does not exist in hermes' schema (there is no `onepassword`
  anywhere in the flake input's `nix/`), and `settings` is copied verbatim
  into config.yaml, so it would have written a dead stanza and resolved no
  key. ollama needs no credential; the client just wants the header set, so a
  literal placeholder goes through `environment` — upstream's documented lane
  for NON-secret values. A real cloud provider's key belongs in
  `environmentFiles` rendered from 1Password, like home/wakatime.nix's.

Verified: all four configs evaluate (both darwin hosts + both Linux
`homeConfigurations`), and the rendered `services.hermes-agent.settings`
carries the right per-host `base_url`. The endpoint was also checked
end-to-end — `/v1/models` lists that exact id, and a `/v1/chat/completions`
call with `Authorization: Bearer ollama` returned HTTP 200 and the model's
reply, confirming the dummy key is accepted. Cold load of the 25GB model took
~6.5 min on the first request; later ones are fast.

STILL NOT RUN on either host: `darwin-rebuild switch` / `just switch`. That
is the remaining step — it needs an interactive sudo prompt.

No `inputs.nixpkgs.follows` on the `hermes-agent` input on purpose — it
builds its Python deps via uv2nix/pyproject-nix against its own pinned
nixpkgs-unstable, and forcing a follow risks a lockfile mismatch.
