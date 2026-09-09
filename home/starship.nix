# starship — the live prompt.
#
# The real config is dotfiles/starship.toml (409 lines, 23 sections, tuned
# over years). It is linked LIVE (hybrid rule: tinker files stay editable
# without a rebuild). programs.starship.settings is deliberately EMPTY —
# setting it would generate a second starship.toml and conflict.
{ config, dotfilesRepo, ... }:

let
  repo = "${config.home.homeDirectory}/${dotfilesRepo}";
in
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    # no `settings` — see header
  };

  xdg.configFile."starship.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/dotfiles/starship.toml";
}
