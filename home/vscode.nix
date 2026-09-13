# vscode — declared small, kept small.
#
# The app itself is a Homebrew cask (nix's vscode would mean two VS Codes).
# This module owns two things:
#
#   1. The extension BASE LIST — snapshot of the 8 actually installed on
#      2026-09-08, per the brief: "keep this small, my vscodes get bloated
#      as fuck cause im a hungry nerd". Activation installs anything missing
#      from the list; it NEVER uninstalls, so trying extensions is free —
#      but only additions to this list survive a fresh machine. The list is
#      the diet.
#
#   2. settings.json — live-linked into the repo, so tweaks made in the UI
#      land as a git diff instead of evaporating.
{
  config,
  lib,
  pkgs,
  dotfilesRepo,
  ...
}:

let
  repo = "${config.home.homeDirectory}/${dotfilesRepo}";

  extensions = [
    "anthropic.claude-code"
    "golang.go" # the catalyst devspace CLI is Go; go itself via mise
    "jnoortheen.nix-ide"
    "bbenoist.nix" # redundant with nix-ide; prune candidate
    "ms-vscode.makefile-tools"
    "max-ss.cyberpunk" # "Activate UMBRA protocol"
    "robbowen.synthwave-vscode"
    "akamud.vscode-theme-onedark"
    "miguelsolorio.fluent-icons"
  ];

  settingsPath =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "Library/Application Support/Code/User/settings.json"
    else
      ".config/Code/User/settings.json";
in
{
  # Live symlink: VS Code writes settings through it into the repo.
  home.file.${settingsPath}.source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/dotfiles/vscode/settings.json";

  home.activation.vscodeExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _code=""
    for c in "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
             "$(command -v code 2>/dev/null || true)"; do
      [ -x "$c" ] && _code="$c" && break
    done
    if [ -n "$_code" ]; then
      _have="$("$_code" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"
      for ext in ${lib.escapeShellArgs extensions}; do
        _lc=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
        case "$_have" in
          *"$_lc"*) : ;;
          *) echo "vscode: installing $ext"
             $DRY_RUN_CMD "$_code" --install-extension "$ext" --force >/dev/null 2>&1 \
               || echo "vscode: ✖ failed to install $ext" ;;
        esac
      done
    fi
  '';
}
