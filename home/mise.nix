# mise — per-PROJECT runtime management (node/go/python/rust via .tool-versions
# or mise.toml). The division of labour, decided up front and worth restating:
#
#   nix   -> system tools you use everywhere (this flake)
#   mise  -> runtimes a PROJECT pins
#
# Without this rule the third manager drifts into the same overlap that
# afx/brew had.
# SCOPE: imported ONLY by hosts/teakbookM5DJ/home.nix, not by home/default.nix.
# Work repos pin runtimes with .nvmrc / .python-version and can't be asked to
# adopt nix, so the work machine keeps mise as the bridge. Personal machines
# stay nix-only. Adding this to home/default.nix would put mise back on every
# host — scope it per-host instead.
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
