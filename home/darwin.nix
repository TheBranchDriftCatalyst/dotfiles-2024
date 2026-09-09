# macOS-only home-manager bits.
{ pkgs, ... }:
{
  # Container runtime: colima (replaces Docker Desktop, which self-destructed
  # mid-session). `colima start --kubernetes` gives k3s inside the VM —
  # replacing minikube/k3d from the old setup.
  home.packages = with pkgs; [
    colima
    docker          # CLI only; colima provides the daemon
    docker-buildx
    docker-compose
  ];

  # Homebrew's bin dir still needs to be on PATH: nix-darwin drives brew for
  # GUI casks (it does not, and cannot, install them itself).
  home.sessionPath = [ "/opt/homebrew/bin" "/opt/homebrew/sbin" ];
}
