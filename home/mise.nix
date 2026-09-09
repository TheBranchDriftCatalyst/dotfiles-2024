# mise — per-PROJECT runtime management (node/go/python/rust via .tool-versions
# or mise.toml). The division of labour, decided up front and worth restating:
#
#   nix   -> system tools you use everywhere (this flake)
#   mise  -> runtimes a PROJECT pins
#
# Without this rule the third manager drifts into the same overlap that
# afx/brew had.
{ ... }:

{
  programs.mise = {
    enable = true;
    enableZshIntegration = true;   # emits `eval "$(mise activate zsh)"`
    globalConfig = {
      settings.idiomatic_version_file_enable_tools = [ "node" ];
    };
  };
}
