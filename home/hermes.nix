# Hermes Agent — CLI on PATH + declarative model config, no gateway/backend
# daemon. The upstream module (hermes-agent.homeManagerModules.default) is
# imported per-host in flake.nix; THIS file is the configuration for it, and
# is imported from home/default.nix so both Macs get the same agent.
#
# The upstream module never touches ~/.zshrc — it exports HERMES_HOME via
# home.sessionVariables, which home-manager's zsh integration already sources.
#
# services.hermes-agent.enable (not just programs.*) is what makes activation
# render $HERMES_HOME/config.yaml and .env. gateway.enable and backend.mode
# are left at their upstream "none"/false defaults, so this registers no
# launchd agent — see nix/homeManagerModules.nix in the hermes-agent flake.
#
# ── Where the model actually runs ────────────────────────────────────────
# ollama runs on catalystM5 (the MacBook Pro) and already serves the Hermes
# weights. It listens on *:11434, not loopback, so the work machine can reach
# it across the LAN by mDNS name — hence ollamaUrl is PER-HOST below rather
# than a single baked-in string.
#
# ollama is DELIBERATELY NOT nix-managed (DJ's call, 2026-10-09), because it is
# already owned elsewhere and that existing system is the one we use:
#
#   ~/catalyst-devspace/workspace/mac-sdlc-node
#
# That project is the node's model plane. launchd/com.ollama.server.plist there
# is the SOURCE of the agent installed at ~/Library/LaunchAgents (verified
# identical 2026-10-09), and models.yaml is its single source of truth for
# which models this box serves. So nix declares the CLIENT only; the server,
# its tuning and its model set belong to that repo.
#
# Two things from the agent that this module silently depends on:
#
#   OLLAMA_HOST=0.0.0.0:11434   the reason teakbookM5DJ can reach it at all;
#                               on loopback the LAN ollamaUrl above is dead
#   OLLAMA_KEEP_ALIVE=30m       how long a loaded model stays resident
#   (also OLLAMA_MAX_LOADED_MODELS=3, NUM_PARALLEL=4, FLASH_ATTENTION=1)
#
# The model string below is EXACTLY the `name:` of the registry's
# `alias: hermes-4.3-36b` entry — audited there on 2026-09-24 and matched
# byte-for-byte on 2026-10-09. Use that raw tag, NOT the alias: aliases are
# LiteLLM/dashboard routing names, and this module speaks to ollama directly.
#
# COUPLING, so a future reader is not surprised: `task models:cleanup` in that
# repo DELETES any installed ollama tag models.yaml stops declaring. If the
# hermes-4.3-36b entry is ever retired there, the weights this module points at
# go with it. Change the model here and in models.yaml together.
#
# Practical consequence of keep-alive, not a fault: the model below is 25GB, so
# the FIRST request after 30 idle minutes spends ~6.5 min loading before a
# single token appears (measured twice on 2026-10-09 — 387s by curl, and a
# hermes run abandoned at 449s that was still loading). Everything inside the
# keep-alive window is fast. If interactive snappiness matters more than this
# model, `model` below is a one-line change and 17-18GB options are pulled.
#
# ── No 1Password block here, deliberately ───────────────────────────────
# An earlier draft of this file carried
#   settings.secrets.onepassword.env.OPENAI_API_KEY = "op://…";
# which would NOT have worked: `settings` is a free-form deep attrset that the
# module copies verbatim into config.yaml, and there is no secrets.onepassword
# key in hermes' schema (grep the flake input: nix/ has no `onepassword`
# anywhere). It would have written a dead stanza and silently resolved no key.
#
# Nothing is lost by dropping it, because ollama needs no credential. Its
# OpenAI-compatible endpoint ignores the bearer token, but the client library
# still insists SOMETHING is set, so a literal placeholder goes in through
# `environment` — the option upstream documents for NON-secret values (it
# lands in $HERMES_HOME/.env). hermes' own local-server evals use exactly this
# shape, e.g. OPENAI_API_KEY=local-fixture. The moment a real cloud provider
# is added, that key belongs in `environmentFiles` rendered from 1Password —
# the same lane as home/wakatime.nix's api key — and NOT in `environment`,
# which is world-readable in the nix store.
{ lib, config, ... }:

let
  cfg = config.catalyst.hermes;
in
{
  options.catalyst.hermes = {
    ollamaUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:11434/v1";
      description = ''
        The OpenAI-compatible ollama endpoint this machine should talk to.

        Per-host for the same reason catalyst.wakatime.machineName is: it is
        the only field here that differs by machine. catalystM5 hosts the
        models and talks to itself over loopback; the work machine crosses the
        LAN. Must include the /v1 suffix — hermes appends paths, not versions.
      '';
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "hf.co/NousResearch/Hermes-4.3-36B-GGUF:Q5_K_M";
      description = ''
        Model id as ollama itself reports it in `ollama list`.

        NOT prefixed with "ollama/". hermes supports a provider-prefixed form
        (hermes_constants.py documents keys like "ollama-local/qwen3:27b"), but
        this id already contains slashes, and `model.provider` below states the
        provider explicitly — so the bare name is what has to reach ollama's
        API for it to match a pulled tag.
      '';
    };
  };

  config = {
    programs.hermes-agent.enable = true;

    services.hermes-agent = {
      enable = true;

      settings.model = {
        default = cfg.model;
        provider = "ollama";
        base_url = cfg.ollamaUrl;
      };

      # Placeholder, not a secret — see the header. `environment` is upstream's
      # documented lane for non-secret values and is readable in the store.
      environment.OPENAI_API_KEY = "ollama";
    };
  };
}
