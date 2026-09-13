# mise — per-PROJECT runtime management (node/go/python/rust via .tool-versions
# or mise.toml). The division of labour, decided up front and worth restating:
#
#   nix   -> system tools you use everywhere (this flake)
#   mise  -> runtimes a PROJECT pins
#
# Without this rule the third manager drifts into the same overlap that
# afx/brew had.
# TODO: mise is probably gone, moving over to nix entirely at the repo level using flake + direnv
_:

{
  programs.mise = {
    enable = true;
    enableZshIntegration = true; # emits `eval "$(mise activate zsh)"`
    globalConfig = {
      # opt-in per tool (mise 2025+ default-off): node reads .nvmrc, python
      # reads .python-version, go reads go.mod's `go` directive. pyproject.toml
      # is NOT a version source for mise — python repos need .python-version
      # or a mise.toml if they want pinning.
      settings.idiomatic_version_file_enable_tools = [
        "node"
        "python"
        "go"
      ];
    };
  };
}
