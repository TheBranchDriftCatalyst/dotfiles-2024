# The portable tool layer.
#
# This single list replaces BOTH afx's 81 packages and Brewfile.core — the
# overlap that started this rewrite. Everything here works identically on
# macOS and Linux, including tmux and eza, which afx could never supply
# (tmux ships source only; eza publishes no darwin release assets).
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # ── modern CLI replacements ──────────────────────────────────────────
    bat eza fd ripgrep delta tree sd grex

    # ── data wrangling ───────────────────────────────────────────────────
    jq yq-go fx gron xan jless   # xan = maintained xsv fork (xsv was dropped from nixpkgs)

    # ── git & code ───────────────────────────────────────────────────────
    lazygit gh ghq git-lfs difftastic
    colordiff diff-so-fancy git-open
    shellcheck shfmt

    # ── shell UX ─────────────────────────────────────────────────────────
    fzy zoxide gomi

    # ── containers & k8s ─────────────────────────────────────────────────
    kubectl kubectx kubernetes-helm kustomize k9s stern
    kubetail kubeval kubesec kubectl-view-secret   # ketall: dropped from nixpkgs; use `kubectl get all -A`
    lazydocker ctop dive

    # ── cloud & IaC ──────────────────────────────────────────────────────
    awscli2 terraform-docs hcl2json conftest open-policy-agent

    # ── secrets ──────────────────────────────────────────────────────────
    sops age mkcert

    # ── net & inspection ─────────────────────────────────────────────────
    curl wget nmap socat testssl   # httpstat: build broken on py3.14/unstable; use `curl -w`

    # ── general ──────────────────────────────────────────────────────────
    coreutils findutils gnused gnugrep gawk moreutils
    p7zip pigz unzip htop procs dust duf watch
    act glow hyperfine
    just            # runs the repo justfile — the post-bootstrap control panel
    nvd             # generation diffs for `just diff`
    nix-output-monitor

    # ── fonts (these do NOT need a Homebrew cask) ────────────────────────
    nerd-fonts.hack
    nerd-fonts._3270
  ];

  # DROPPED from the old afx manifest — unused, unmaintained, or superseded.
  # Recorded here so the decision is visible rather than silently lost:
  #   exa      -> eza (upstream deprecated exa)
  #   hub      -> gh
  #   ack      -> ripgrep
  #   prok, red, bow, slit, arth, cob, jsonfmt, rargs, ktop, dockfmt, gkill,
  #   changed-objects, mmv, fillin, kail, dry, air
  #     -> niche one-offs, none referenced by any config in this repo.
  #        Re-add individually if you actually miss one.
}
