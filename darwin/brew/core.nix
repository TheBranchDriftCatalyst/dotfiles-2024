# Desktop base — on every Mac, no exceptions. If a machine wouldn't feel like
# one of ours without it, it belongs here.
{
  casks = [
    "ghostty" # nixpkgs' ghostty is Linux-only
    "stats" # free open-source iStat Menus (exelban/stats)
    "alfred"
    "rectangle-pro" # window management; see catalyst.rice.tiling for the AeroSpace alternative
    "firefox"
    # MOVED from masApps: mas 7 sudo-installs + a Tahoe receipt bug made every
    # switch fail on it; Flexibits ships this direct build (cask =
    # auto_updates, brew never touches it again). The MAS lane below is for
    # cask-less apps only.
    "fantastical"
    # virtual HID driver; its config is managed in home/karabiner.nix
    "karabiner-elements"
  ];

  masApps = {
    Yoink = 457622435;
    # no cask exists and it's not in nixpkgs — MAS is the only managed lane
    PDFgear = 6469021132;
  };
}
