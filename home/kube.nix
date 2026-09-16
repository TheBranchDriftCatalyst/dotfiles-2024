# kubeconfig, materialized from 1Password on every switch.
#
# ── why 1Password and not sops-nix ──────────────────────────────────────────
# sops-nix is a flake input here and wired into both hosts, but has never had
# a consumer. It was the plan when secrets lived in the @secrets repo; that
# repo is gone and the pattern with it.
#
# The deciding argument is the trust root. sops needs an age/GPG key present
# before it can decrypt, and on a fresh laptop that key has to arrive from
# somewhere — realistically 1Password. So sops would not remove 1Password from
# the chain, it would stack on top of it: encrypted blobs in git, a recipients
# file, per-machine key enrollment, and re-encryption on every machine added,
# all guarding secrets whose root key still sits in 1Password.
#
# sops earns that cost when you need offline decryption, CI/headless access,
# or git-versioned secret history. None apply to a personal laptop where `op`
# is already wired, already unlocked daily, and already renders
# ~/.catalyst/secrets.env (home/catalyst.nix) by the same mechanism.
#
# ── why the WHOLE file, not op:// field templating ──────────────────────────
# The other lane is a committed kubeconfig skeleton with op:// refs for the
# credential fields. It keeps cluster structure reviewable in git, and the
# base64 fields are single-line so injection is clean.
#
# Rejected because of how this config actually changes: 3 clusters today
# (catalyst-cluster, aws-lighthouse, k3d-catalyst-dev) across a homelab that
# gets rebuilt. Templating means editing nix every time a cluster is added,
# rotated, or torn down. As a document, that is a 1Password edit and a switch.
# The structure is not worth version-controlling separately from the creds it
# carries — a kubeconfig changes as a unit.
#
# ── setup (one time) ────────────────────────────────────────────────────────
#   op document create <merged-kubeconfig> --title kubeconfig --vault dev
# Rotate/extend by editing the document in 1Password, then `just switch`.
#
# Degrades exactly like catalystSecrets: if op is locked, absent or offline,
# an existing ~/.kube/config is LEFT ALONE and activation continues. Losing
# cluster access mid-switch because 1Password happened to be locked would be
# a worse failure than a stale config.
{
  pkgs,
  lib,
  config,
  ...
}:

let
  kubeconfig = "${config.home.homeDirectory}/.kube/config";
  # 1Password Document item holding the kubeconfig. NOTE this is a document,
  # fetched with `op document get` — NOT an op:// secret reference. A ref like
  # op://dev/kubeconfig is rejected ("too few '/'"): op read needs
  # vault/item/FIELD, and a document's payload is not a field.
  opVault = "dev";
  opItem = "kubeconfig";
in
{
  # kubectl/kubectx/helm are declared in home/packages.nix — this module owns
  # the CREDENTIALS only, not the tooling.
  home.sessionVariables.KUBECONFIG = kubeconfig;

  home.activation.kubeconfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _out=${lib.escapeShellArg kubeconfig}
    _op="${pkgs._1password-cli}/bin/op"

    _tmp=$(mktemp)
    if "$_op" document get ${lib.escapeShellArg opItem} \
         --vault ${lib.escapeShellArg opVault} --out-file "$_tmp" --force >/dev/null 2>&1; then
      if [ -s "$_tmp" ]; then
        $DRY_RUN_CMD mkdir -p "$(dirname "$_out")"
        $DRY_RUN_CMD install -m 600 "$_tmp" "$_out"
        echo "kube: config materialized from 1Password"
      else
        echo "kube: ✖ 1Password returned an empty document — keeping existing config"
      fi
    else
      if [ -e "$_out" ]; then
        echo "kube: ✖ op document get failed (locked? offline?) — keeping existing config"
      else
        echo "kube: ✖ op document get failed and no existing config — kubectl has no clusters."
        echo "kube:   unlock 1Password and re-run, or seed once with:"
        echo "kube:     op document create ~/.kube/config --title kubeconfig --vault dev"
      fi
    fi
    rm -f "$_tmp"
  '';
}
