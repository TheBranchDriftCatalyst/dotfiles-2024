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

    # weekly-prebuilt nix-index DB: command-not-found + comma, no local indexing
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # one `nix fmt` for the whole repo (nixfmt + shfmt + stylua + prettier)
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # own-your-packaging: catalyst-cli ships its own flake (binary + cy alias +
    # zsh completions + fzf-tab widget); home/catalyst.nix just consumes it.
    # git+ssh (not github:) — the repo is private; this rides the ssh agent
    # instead of needing an API token in nix.conf.
    catalyst-cli = {
      url = "git+ssh://git@github.com/TheBranchDriftCatalyst/catalyst-cli.git?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # trampoline .apps so nix-installed GUI apps index in Spotlight/Launchpad
    mac-app-util.url = "github:hraban/mac-app-util";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-darwin,
      sops-nix,
      nix-index-database,
      treefmt-nix,
      mac-app-util,
      ...
    }@inputs:
    let
      # Where this repo lives. Everything that needs a live (editable) symlink
      # resolves through here — never a hardcoded /Users/<name>.
      dotfilesRepo = ".dotfiles";

      mkArgs = system: {
        inherit inputs dotfilesRepo system;
      };

      # legacyPackages cannot carry config; zsh-abbr is unfree (HL3), so the
      # standalone HM targets need an explicit import with allowUnfree.
      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
    in
    {
      # ── macOS ──────────────────────────────────────────────────────────────
      # Named by real hostname, so `darwin-rebuild switch --flake .` picks the
      # matching config with no #target. A new Mac gets its own hosts/<name>/.
      darwinConfigurations."teakbookM5DJ" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = mkArgs "aarch64-darwin";
        modules = [
          ./hosts/teakbookM5DJ
          sops-nix.darwinModules.sops
          mac-app-util.darwinModules.default
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = mkArgs "aarch64-darwin";
              users.dj.imports = [
                ./home
                ./home/darwin.nix
                ./hosts/teakbookM5DJ/home.nix
                nix-index-database.homeModules.nix-index
              ];
              # Move aside any pre-existing file rather than failing activation.
              backupFileExtension = "hm-bak";
            };
          }
        ];
      };

      darwinConfigurations."catalystM5" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = mkArgs "aarch64-darwin";
        modules = [
          ./hosts/catalystM5
          sops-nix.darwinModules.sops
          mac-app-util.darwinModules.default
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = mkArgs "aarch64-darwin";
              users.panda.imports = [
                ./home
                ./home/darwin.nix
                ./hosts/catalystM5/home.nix
                nix-index-database.homeModules.nix-index
              ];
              # Move aside any pre-existing file rather than failing activation.
              backupFileExtension = "hm-bak";
            };
          }
        ];
      };

      # ── Linux (standalone home-manager — works on ANY distro) ──────────────
      # Generic by design: for borrowed boxes and containers, not a specific
      # machine.   home-manager switch --flake .#linux-generic
      homeConfigurations."linux-generic" = home-manager.lib.homeManagerConfiguration {
        pkgs = mkPkgs "x86_64-linux";
        extraSpecialArgs = mkArgs "x86_64-linux";
        modules = [
          ./home
          ./home/linux.nix
          ./hosts/linux-generic
          nix-index-database.homeModules.nix-index
        ];
      };

      homeConfigurations."linux-generic-arm" = home-manager.lib.homeManagerConfiguration {
        pkgs = mkPkgs "aarch64-linux";
        extraSpecialArgs = mkArgs "aarch64-linux";
        modules = [
          ./home
          ./home/linux.nix
          ./hosts/linux-generic
          nix-index-database.homeModules.nix-index
        ];
      };

      # `nix fmt` formats the whole repo; `nix fmt -- --ci` checks.
      formatter = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ] (
        system:
        (treefmt-nix.lib.evalModule (mkPkgs system) {
          projectRootFile = "flake.nix";
          # .scratch/ is an archive of retired scripts (several are zsh in .sh
          # clothing) — formatting an archive is churn, not hygiene
          settings.global.excludes = [ ".scratch/*" ];
          programs = {
            nixfmt.enable = true;
            shfmt.enable = true;
            stylua.enable = true;
            prettier.enable = true;
          };
        }).config.build.wrapper
      );
    };
}
