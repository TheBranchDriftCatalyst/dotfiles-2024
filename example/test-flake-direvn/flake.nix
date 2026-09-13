{
  description = "Dev shell: Python backend + React frontend";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      # one dev shell per platform, so it works on your mac and on linux CI
      forEachSystem =
        f:
        nixpkgs.lib.genAttrs [
          "aarch64-darwin"
          "x86_64-darwin"
          "x86_64-linux"
          "aarch64-linux"
        ] (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forEachSystem (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            # backend
            python312
            uv # python package/venv manager

            # frontend
            nodejs_22
            pnpm

            # local k8s dev loop
            tilt
            kubectl
            kind
          ];

          shellHook = ''
            echo "⚗️  dev shell: python $(python --version | cut -d' ' -f2) · node $(node --version)"
          '';
        };
      });
    };
}
