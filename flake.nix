{
  description = "catalyst dotfiles — one config, macOS + any Linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-darwin moved from LnL7/ to the nix-darwin org.
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nix-darwin, sops-nix, ... }@inputs:
    let
      # Where this repo lives. Everything that needs a live (editable) symlink
      # resolves through here — never a hardcoded /Users/<name>.
      dotfilesRepo = "catalyst-devspace/catalyst/@dotfiles";

      mkArgs = system: {
        inherit inputs dotfilesRepo system;
      };

      # legacyPackages cannot carry config; zsh-abbr is unfree (HL3), so the
      # standalone HM targets need an explicit import with allowUnfree.
      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      # ── macOS ──────────────────────────────────────────────────────────────
      #   darwin-rebuild switch --flake .#dj-mac
      darwinConfigurations."dj-mac" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = mkArgs "aarch64-darwin";
        modules = [
          ./hosts/dj-mac
          sops-nix.darwinModules.sops
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = mkArgs "aarch64-darwin";
              users.dj.imports = [ ./home ./home/darwin.nix ./hosts/dj-mac/home.nix ];
              # Move aside any pre-existing file rather than failing activation.
              backupFileExtension = "hm-bak";
            };
          }
        ];
      };

      # ── Linux (standalone home-manager — works on ANY distro) ──────────────
      #   home-manager switch --flake .#dj-linux
      homeConfigurations."dj-linux" = home-manager.lib.homeManagerConfiguration {
        pkgs = mkPkgs "x86_64-linux";
        extraSpecialArgs = mkArgs "x86_64-linux";
        modules = [ ./home ./home/linux.nix ./hosts/dj-linux ];
      };

      homeConfigurations."dj-linux-arm" = home-manager.lib.homeManagerConfiguration {
        pkgs = mkPkgs "aarch64-linux";
        extraSpecialArgs = mkArgs "aarch64-linux";
        modules = [ ./home ./home/linux.nix ./hosts/dj-linux ];
      };
    };
}
