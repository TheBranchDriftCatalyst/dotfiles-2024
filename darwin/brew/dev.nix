# Development tooling that has to be a GUI app.
#
# NOT docker — Docker Desktop is replaced by colima (home/darwin.nix); the
# Desktop app and colima fight over the docker socket/context.
{
  casks = [
    "visual-studio-code"
    "jetbrains-toolbox"
    "keepingyouawake"
    # "insomnia"
    "postman"
    "dash"
    "wakatime"
    "p-arr" # own app (pr-widget): floating GitHub PR dashboard — via taps below
  ];

  # own tap: P-Arr ships through TheBranchDriftCatalyst/catalyst, so the tap
  # travels with the cask that needs it rather than being declared globally.
  taps = [ "thebranchdriftcatalyst/catalyst" ];
}
