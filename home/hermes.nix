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

    contextTokens = lib.mkOption {
      type = lib.types.int;
      # 64K is hermes' FLOOR, not a preference: agent/model_metadata.py sets
      # MINIMUM_CONTEXT_LENGTH = 64_000 and refuses to start below it. 32768
      # was tried first and rejected in 2.1s with exactly that message.
      default = 65536;
      description = ''
        Context window to ask ollama for, as `model.ollama_num_ctx`.

        THIS IS LOAD-BEARING, not tuning. Without it ollama loaded the 36B at
        its native 262144-token window on 2026-10-09 and `ollama ps` reported:

          SIZE 305 GB   PROCESSOR 63%/37% CPU/GPU   CONTEXT 262144

        25.6GB of weights plus ~279GB of KV cache on a 128GB box, so most of
        the model sat on the CPU and generation effectively never finished —
        two runs were abandoned after 387s and 449s looking like a hang. It was
        not a slow load; it was running off-GPU.

        The window is NOT free to choose, though: hermes refuses to run below
        64,000 tokens (MINIMUM_CONTEXT_LENGTH in agent/model_metadata.py). So
        65536 is the smallest legal value, and the only real lever left for
        memory is the MODEL. Scaling the observed 262144 figure linearly
        suggests ~70GB of KV at 64K — about 95GB resident with weights, which
        fits 128GB but leaves little room for a second model even though the
        server allows OLLAMA_MAX_LOADED_MODELS=3.

        Check `ollama ps` after changing this: SIZE should be well under 128GB
        and PROCESSOR should read ~100% GPU. If a run ever goes back to
        splitting onto the CPU, this is the first thing to look at — and the
        fix then is a smaller model from `models`, not a smaller window.

        Also written as `model.context_length` so hermes' own token budgeting
        agrees with what it asked ollama for, which its runtime warning at
        agent/conversation_loop.py explicitly tells you to do.
      '';
    };

    models = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = ''
        Short alias -> ollama tag, for every model this node already serves.

        Rendered into config.yaml as `model_aliases`, which hermes checks
        BEFORE catalog resolution — the mechanism its own source documents for
        "endpoints outside the models.dev catalog (Ollama Cloud, local
        servers)". That ordering is the point: these tags exist in no public
        catalog, so without it hermes would pay a models.dev/OpenRouter probe
        and still not resolve them.

        Switch with `hermes -m <alias>`. Nothing is downloaded by listing one
        here — every entry below was verified present in `ollama list` on
        2026-10-09, and the set is the INTERSECTION of what is pulled with what
        mac-sdlc-node's models.yaml declares, so dotfiles cannot drift into
        naming a model the registry would delete (see the models:cleanup note
        in the header). All 29 pulled models happened to be declared there.

        base_url comes from ollamaUrl, so the aliases follow the per-host
        endpoint: on the work machine they resolve across the LAN for free.

        Not all of these are chat models — qwen3-embed-8b is an embedding
        model, nuextract*/universalner are extraction models. They are listed
        for completeness because they are served; do not expect conversation
        from them.
      '';
      default = {
        "behemoth-x" = "behemoth-x:Q4_K_M";
        "cydonia-24b" = "hf.co/TheDrummer/Cydonia-24B-v4.3-GGUF:Q8_0";
        "deepseek-r1" = "deepseek-r1:32b-qwen-distill-q8_0";
        "devstral-2" = "hf.co/unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF:Q8_0";
        "devstral-2-123b" = "devstral-2:123b";
        "gemma4" = "gemma4:e4b";
        "gemma4-26b" = "gemma4:26b-a4b-it-q8_0";
        "gemma4-31b" = "gemma4:31b";
        "glm-4.6-air-distill" = "glm-4.6-air-distill:i1-Q6_K";
        "granite4.2" = "granite4.2:30b";
        "hermes-4-70b" = "hf.co/unsloth/Hermes-4-70B-GGUF:Q5_K_M";
        "hermes-4.3-36b" = "hf.co/NousResearch/Hermes-4.3-36B-GGUF:Q5_K_M";
        "magnum-v4" = "magnum-v4:Q5_K_M";
        "nuextract1.5" = "nuextract1.5:latest";
        "nuextract2" = "nuextract2:latest";
        "phi4" = "phi4:14b-q8_0";
        "qwen3-8b" = "qwen3:8b";
        "qwen3-coder" = "qwen3-coder:30b-a3b-q8_0";
        "qwen3-coder-next" = "qwen3-coder-next:Q8_0";
        "qwen3-coder-opus" = "qwen3-coder-opus:Q8_0";
        "qwen3-coder-opus-uncensored" = "qwen3-coder-opus-uncensored:Q8_0";
        "qwen3-embed-8b" = "qwen3-embedding:8b";
        "qwen3-moe-uncensored" = "qwen3-moe-uncensored:i1-Q6_K";
        "qwen3-vl" = "qwen3-vl:latest";
        "qwen3-vl-think" = "qwen3-vl:30b-a3b-thinking-q8_0";
        "qwen3.6-opus" = "qwen3.6-opus:Q8_0";
        "qwen3.8" = "qwen3.8:27b";
        "qwen3.8-mlx" = "qwen3.8:27b-mlx";
        "universalner" = "universalner:latest";
      };
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

      settings = {
        model = {
          default = cfg.model;
          provider = "ollama";
          base_url = cfg.ollamaUrl;
          # see contextTokens — this is what keeps the model on the GPU
          ollama_num_ctx = cfg.contextTokens;
          context_length = cfg.contextTokens;
        };

        # Every alias pins model+provider+base_url explicitly rather than
        # inheriting. hermes' simpler `model.aliases` string form would take
        # the provider from the active one, which silently breaks the moment
        # the default is switched to anything non-local.
        model_aliases = lib.mapAttrs (_alias: tag: {
          model = tag;
          provider = "ollama";
          base_url = cfg.ollamaUrl;
        }) cfg.models;
      };

      # Placeholder, not a secret — see the header. `environment` is upstream's
      # documented lane for non-secret values and is readable in the store.
      environment.OPENAI_API_KEY = "ollama";
    };
  };
}
