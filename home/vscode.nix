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
#   2. settings.json — generated from nix, so tweaks require a rebuild but
#      everything is tracked in git.
{ pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    # Allow manual extension installs for experimentation; only the list below
    # survives a fresh machine rebuild
    mutableExtensionsDir = true;

    profiles.default = {
      # Access marketplace via the overlay added in flake.nix
      extensions = with pkgs.vscode-marketplace; [
        anthropic.claude-code
        golang.go
        jnoortheen.nix-ide
        bbenoist.nix
        ms-vscode.makefile-tools
        max-ss.cyberpunk
        robbowen.synthwave-vscode
        ekelley.midnight-synth
        akamud.vscode-theme-onedark
        miguelsolorio.fluent-icons
        vscode-icons-team.vscode-icons
      ];

      userSettings = {
        "terminal.integrated.mouseWheelScrollSensitivity" = 3;
        "terminal.integrated.gpuAcceleration" = "off";
        "workbench.productIconTheme" = "fluent-icons";
        "window.density.layout" = "compact";
        "workbench.iconTheme" = "vscode-icons";
        "workbench.colorTheme" = "Retro Synth Cyan";
        "claudeCode.hideOnboarding" = true;
        "explorer.confirmDelete" = false;
        "yaml.disableSchemaDetection" = [
          "**/docker-compose.yml"
          "**/docker-compose.yaml"
          "**/docker-compose.*.yml"
          "**/docker-compose.*.yaml"
          "**/compose.yml"
          "**/compose.yaml"
          "**/compose.*.yml"
          "**/compose.*.yaml"
        ];
      };
    };
  };
}
