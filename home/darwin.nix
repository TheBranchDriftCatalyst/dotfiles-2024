# macOS-only home-manager bits.
{ ... }:
{
  # Homebrew's bin dir still needs to be on PATH: nix-darwin drives brew for
  # GUI casks (it does not, and cannot, install them itself).
  home.sessionPath = [ "/opt/homebrew/bin" "/opt/homebrew/sbin" ];
}
