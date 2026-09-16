# Karabiner-Elements — keyboard remapping.
#
# The app itself is a CASK, not a nix package, and always will be: it ships a
# virtual HID driver (a system extension), which nix cannot install. Declared
# alongside little-snitch in hosts/<host>/default.nix under the same heading.
#
# ── why a LIVE symlink and not a store file ─────────────────────────────────
# karabiner.json is app-WRITABLE. Karabiner-Elements rewrites it on every UI
# change and appends device entries as new keyboards are plugged in. Pointing
# it at a read-only /nix/store path makes the GUI fail to save and the daemon
# complain. So it takes the same out-of-store lane as claude/vscode/catalyst:
# the file lives in the repo and edits land back here, reviewable in git.
#
# Practical consequence: tweaking anything in the Karabiner UI dirties this
# repo. That is the intended trade — it is how a UI change becomes a commit
# instead of undocumented machine drift, which is exactly how the rule below
# got lost in the first place.
#
# ── the rule, and one deliberate change ─────────────────────────────────────
# "Swap Cmd/Option on non-Apple keyboards (for PC layout)" — swaps left/right
# command and option, gated on `device_unless vendor_id 1452` (Apple), so the
# built-in MacBook keyboard is untouched and only external PC keyboards swap.
#
# It supersedes the old etc/launchagents/com.catalyst.swap-mod-keys.plist +
# etc/scripts/swap-mod-keys.sh, both deleted in the pre-nix snapshot.
#
# ⚠ CHANGED FROM THE BACKUP: the rule was "enabled": false in the pre-nix
# config, i.e. present but inert. It is restored ENABLED here, on the grounds
# that a disabled remap is not worth carrying. If it was off on purpose, set
# "enabled": false in dotfiles/karabiner/karabiner.json — no rebuild needed,
# the symlink is live.
{ config, dotfilesRepo, ... }:

let
  repo = "${config.home.homeDirectory}/${dotfilesRepo}";
in
{
  home.file.".config/karabiner/karabiner.json".source =
    config.lib.file.mkOutOfStoreSymlink "${repo}/dotfiles/karabiner/karabiner.json";

  # NOT managed: ~/.config/karabiner/automatic_backups/ — the app's own
  # timestamped snapshots. Leaving them unmanaged keeps the app's recovery
  # path working and keeps churn out of the repo.
}
