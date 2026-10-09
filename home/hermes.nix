# Hermes Agent — CLI on PATH + declarative model config, no gateway/backend
# daemon. The module (hermes-agent.homeManagerModules.default, imported per-
# host in flake.nix) never touches ~/.zshrc — it exports HERMES_HOME via
# home.sessionVariables, which home-manager's zsh integration already sources.
#
# services.hermes-agent.enable (not just programs.*) is what makes activation
# render $HERMES_HOME/config.yaml and .env. gateway.enable and backend.mode
# are left at their upstream "none"/false defaults, so this registers no
# launchd agent — see nix/homeManagerModules.nix in the hermes-agent flake.
#
# STUB — fill these in once found, then `just switch`:
#   - model.default / base_url: the real ollama host + model name
#   - secrets.onepassword.env: the real op:// reference for the token
# No sops-nix here on purpose — 1Password is this repo's secrets trust root
# (see home/kube.nix's header for why), and hermes has native 1Password
# support (secrets.onepassword, resolved with `op read` at hermes startup —
# no home-manager activation script needed, unlike kube.nix's materialized
# file).
_:
{
  programs.hermes-agent.enable = true;

  services.hermes-agent = {
    enable = true;

    settings = {
      model = {
        default = "ollama/CHANGEME"; # TODO(dj): e.g. "ollama/llama3.1:70b"
        provider = "ollama"; # alias for "custom" — OpenAI-compatible wire
        base_url = "http://CHANGEME:11434/v1"; # TODO(dj): MacBook Pro's ollama endpoint
      };

      secrets.onepassword = {
        enabled = true;
        env.OPENAI_API_KEY = "op://CHANGEME-vault/CHANGEME-item/CHANGEME-field"; # TODO(dj)
      };
    };
  };
}
