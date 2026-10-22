# Secrets, keys, and the network perimeter.
{
  casks = [
    "gpg-suite"
    # Kernel/system extension — this can NEVER be a Nix package.
    # "little-snitch"
    # NOT 1password — same root-owned-app wall as google-chrome (hosts' own
    # comment), but self-inflicted by the app rather than MDM: 1Password 8
    # installs /Applications/1Password.app owned by root on purpose (it
    # refuses to launch from a user-writable bundle, anti-tamper hardening).
    # brew bundle runs as the primary user during activation, so it can never
    # replace that bundle — `brew upgrade --cask 1password` fails, brew
    # bundle exits nonzero, and the WHOLE darwin switch fails with it. The
    # cask is auto_updates anyway: 1Password ships its own updater. The app
    # stays installed (cleanup = "none" removes nothing); brew just stops
    # trying to drive it. `op` is unaffected — it comes from nixpkgs
    # (home/packages.nix).
  ];
}
