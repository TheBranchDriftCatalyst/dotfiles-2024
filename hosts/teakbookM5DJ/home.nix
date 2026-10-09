# Livery for teakbookM5DJ.
# (Devspace root and org layout are machine-agnostic now — ~/devspace with
# per-org subdirs, defaults in home/catalyst.nix; identity per org dir in
# home/contexts.nix. Nothing devspace-flavored left to override here.)
_:

{
  # mise — HOST-SCOPED on purpose. Only the work machine needs it: work repos
  # pin runtimes with .nvmrc / .python-version and must not be asked to adopt
  # nix. Personal machines stay nix-only; see the header in mise.nix.
  imports = [ ../../home/mise.nix ];

  # values live in palette.nix (plain attrset) so rice.nix — a darwin-layer
  # module that can't see HM config — colors the bar/borders from the same file
  catalyst.palette = import ./palette.nix;

  # This is the machine catalyst-cli is developed on: run the working copy,
  # not origin/main, so a fix is usable the moment `task build` finishes.
  # Flip to false to go back to the flake-pinned build (see home/catalyst.nix).
  catalyst.devspace.useLocalCatalystCLI = true;

  # wakatime: the label this box reports to the receiver. Per-host on purpose
  # — it is the only field in home/wakatime.nix that differs by machine, and
  # the receiver's dashboard has no other way to tell the two Macs apart.
  # Free-form: rename it and the receiver follows on the next heartbeat (old
  # heartbeats keep the old name in history).
  catalyst.wakatime.machineName = "teakbook-work";
}
