# neovim — the config is a near-stock NvChad v2.5 starter; the user-authored
# delta is about four lines (onedark theme, two keymaps, stylua). Kept as a
# live passthrough so lazy.nvim keeps working as it does today; revisit
# whether NvChad still earns its place separately.
{ pkgs, config, dotfilesRepo, ... }:

let
  repo = "${config.home.homeDirectory}/${dotfilesRepo}";
in
{
  # NOT programs.neovim: the module generates its own init.lua, which
  # conflicts with the live-symlinked config directory below. Package only.
  home.packages = with pkgs; [
    neovim
    lua-language-server
    stylua
  ];

  home.sessionVariables.EDITOR = "nvim";
  home.shellAliases = {
    vim = "nvim";
    vi = "nvim";
  };

  # Live symlink: lazy.nvim writes into stdpath("data"), and you edit these
  # files often enough that a rebuild-per-tweak would be painful.
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/dotfiles/.config/nvim";
}
